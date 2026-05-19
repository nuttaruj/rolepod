#!/bin/bash
# install-codex-mempalace — structural fixture.
#
# Asserts the optional Codex × MemPalace SessionStart bridge wiring:
#
#   1. Fake mempalace binary in PATH + Codex install →
#      cache hooks.json gets the SessionStart entry pointing at
#      optional/mempalace/codex-session-start.sh.
#   2. Reinstall with same fake mempalace → still exactly 1 entry
#      (idempotent — no duplicate).
#   3. No mempalace in PATH → no SessionStart entry added.
#   4. Hook script invoked without mempalace on PATH → exit 0 silently.
#
# This is a STATIC fixture — it exercises the inline python upsert
# logic from install.sh against a temp Codex cache layout. Live Codex
# CLI is not required.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not on PATH"; exit 0; }
command -v jq      >/dev/null 2>&1 || { echo "SKIP: jq not on PATH"; exit 0; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

HOOK_REL="hooks/optional/mempalace/codex-session-start.sh"

# Stage 1 — fake mempalace + bridge registration ──────────────────────────
CACHE_A="$TMP/stage1/cache"
mkdir -p "$CACHE_A/hooks/optional/mempalace"
cp "$REPO_DIR/$HOOK_REL" "$CACHE_A/$HOOK_REL"
chmod +x "$CACHE_A/$HOOK_REL"
cat > "$CACHE_A/hooks/hooks.json" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      {"matcher": "startup|resume", "hooks": [
        {"type": "command", "command": "bash ${PLUGIN_ROOT}/hooks/project-context-loader.sh"}
      ]}
    ]
  }
}
JSON

# Inline the same python upsert install.sh uses, run twice (pass 1 + 2).
run_upsert() {
  python3 - "$1/hooks/hooks.json" "$HOOK_REL" <<'PY'
import json, sys
path, hook_rel = sys.argv[1], sys.argv[2]
cmd = "bash ${PLUGIN_ROOT}/" + hook_rel
with open(path) as f:
    data = json.load(f)
hooks = data.setdefault("hooks", {})
arr = hooks.setdefault("SessionStart", [])
for g in arr:
    g["hooks"] = [h for h in g.get("hooks", []) if hook_rel not in h.get("command", "")]
arr[:] = [g for g in arr if g.get("hooks")]
grp = next((g for g in arr if g.get("matcher") == "startup|resume"), None)
if grp is None:
    grp = {"matcher": "startup|resume", "hooks": []}
    arr.append(grp)
grp.setdefault("hooks", []).append({
    "type": "command", "command": cmd, "timeout": 10,
    "statusMessage": "MemPalace: recalling cross-session decisions"
})
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

# Pass 1.
run_upsert "$CACHE_A"
COUNT_A1=$(jq --arg rel "$HOOK_REL" '[.hooks.SessionStart[].hooks[] | select(.command | contains($rel))] | length' "$CACHE_A/hooks/hooks.json")
check "Pass 1: bridge entry registered exactly once" "[ $COUNT_A1 -eq 1 ]"

# Pass 2 — idempotent.
run_upsert "$CACHE_A"
COUNT_A2=$(jq --arg rel "$HOOK_REL" '[.hooks.SessionStart[].hooks[] | select(.command | contains($rel))] | length' "$CACHE_A/hooks/hooks.json")
check "Pass 2: still exactly one entry (idempotent)" "[ $COUNT_A2 -eq 1 ]"

# Pre-existing project-context-loader untouched.
PCL_COUNT=$(jq '[.hooks.SessionStart[].hooks[] | select(.command | test("project-context-loader"))] | length' "$CACHE_A/hooks/hooks.json")
check "Pass 2: existing project-context-loader entry preserved" "[ $PCL_COUNT -eq 1 ]"

# Stage 2 — no mempalace, no upsert ──────────────────────────────────────
# Mimic install.sh's gate: when `command -v mempalace` fails, the upsert
# block is skipped entirely. Confirm: an untouched hooks.json with no
# MemPalace entry stays that way.
CACHE_B="$TMP/stage2/cache"
mkdir -p "$CACHE_B/hooks/optional/mempalace"
cp "$REPO_DIR/$HOOK_REL" "$CACHE_B/$HOOK_REL"
chmod +x "$CACHE_B/$HOOK_REL"
cat > "$CACHE_B/hooks/hooks.json" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      {"matcher": "startup|resume", "hooks": [
        {"type": "command", "command": "bash ${PLUGIN_ROOT}/hooks/project-context-loader.sh"}
      ]}
    ]
  }
}
JSON

# Simulate install.sh's gate (no fake mempalace in PATH → skip).
FAKE_PATH="/nonexistent-only"
if PATH="$FAKE_PATH" command -v mempalace >/dev/null 2>&1; then
  run_upsert "$CACHE_B"
fi

COUNT_B=$(jq --arg rel "$HOOK_REL" '[.hooks.SessionStart[].hooks[] | select(.command | contains($rel))] | length' "$CACHE_B/hooks/hooks.json")
check "No mempalace: bridge NOT registered" "[ $COUNT_B -eq 0 ]"

# Stage 3 — hook script self-guard at runtime ─────────────────────────────
# Even if the entry somehow gets registered against a host without
# mempalace, the script itself exits 0 silently.
HOOK_PATH="$REPO_DIR/$HOOK_REL"
HOOK_RC=0
# Subshell with PATH limited to system /usr/bin so bash + mempalace
# detection both work without picking up host's mempalace.
PATH="/usr/bin:/bin" bash "$HOOK_PATH" >/dev/null 2>&1 || HOOK_RC=$?
check "Script self-guards exit 0 when mempalace absent (rc=$HOOK_RC)" "[ $HOOK_RC -eq 0 ]"

# Stage 4 — fake mempalace, script invokes it with codex harness ──────────
FAKE_BIN="$TMP/fakebin"
mkdir -p "$FAKE_BIN"
TRACE="$TMP/mp-trace.log"
cat > "$FAKE_BIN/mempalace" <<EOF
#!/bin/bash
echo "ARGS=\$*" >> "$TRACE"
exit 0
EOF
chmod +x "$FAKE_BIN/mempalace"
PATH="$FAKE_BIN:/usr/bin:/bin" bash "$HOOK_PATH" >/dev/null 2>&1
check "Script invokes mempalace with --harness codex first" "grep -q 'hook run --hook session-start --harness codex' '$TRACE'"

if [ $fail -eq 0 ]; then echo "install-codex-mempalace: pass"; exit 0; fi
echo "install-codex-mempalace: $fail failure(s)"
exit 1
