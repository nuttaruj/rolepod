#!/bin/bash
# install-idempotency — structural fixture.
#
# Asserts that the install.sh hook registration is idempotent against
# pre-existing duplicate no-matcher groups in settings.json. PR 5 fallout:
# real ~/.claude/settings.json had two no-matcher Stop groups (one from
# mempalace + orca, one from rolepod) — original upsert added the rolepod
# unlock cmd to BOTH groups, leaving stale duplicates after every install.
#
# Test:
#   1. Seed settings.json with two no-matcher Stop groups, both containing
#      a session-lifecycle.sh --unlock entry (mimics the observed broken state).
#   2. Inline the python consolidate_no_matcher + upsert logic from
#      install.sh.
#   3. Assert: after one pass, Stop has exactly 1 no-matcher group with
#      exactly 1 unlock entry, AND the unrelated mempalace / orca hooks
#      are preserved.
#   4. Run upsert a SECOND time. Assert: no change (true idempotency).
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
HOOK_DIR="$TMP/hooks"
mkdir -p "$HOOK_DIR"
SETTINGS="$TMP/settings.json"
UNLOCK_CMD="$HOOK_DIR/session-lifecycle.sh --unlock"

# Seed: two no-matcher Stop groups, both with the rolepod unlock command.
cat > "$SETTINGS" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {"type":"command","command":"$UNLOCK_CMD","timeout":3},
          {"type":"command","command":"mempalace hook stop","timeout":10}
        ]
      },
      {
        "hooks": [
          {"type":"command","command":"orca hook"},
          {"type":"command","command":"$UNLOCK_CMD","timeout":3}
        ]
      }
    ]
  }
}
EOF

# Inline the same python logic that install.sh uses (extracted to keep
# the test self-contained and version-pinned to the current install.sh
# implementation). If install.sh's upsert logic diverges from this copy,
# the test surfaces the divergence in code review.
run_upsert() {
  python3 - "$SETTINGS" "$HOOK_DIR" <<'PY'
import json, sys, os
path, hook_dir = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
hooks = data.setdefault("hooks", {})

def consolidate_no_matcher(event):
    arr = hooks.get(event) or []
    no_matcher = [g for g in arr if not g.get("matcher")]
    if len(no_matcher) <= 1:
        return
    seen = set()
    merged_hooks = []
    for g in no_matcher:
        for h in g.get("hooks", []):
            cmd = h.get("command")
            if cmd not in seen:
                seen.add(cmd)
                merged_hooks.append(h)
    rest = [g for g in arr if g.get("matcher")]
    if merged_hooks:
        rest.append({"hooks": merged_hooks})
    hooks[event] = rest

def upsert(event, matcher, cmd, timeout):
    consolidate_no_matcher(event)
    arr = hooks.setdefault(event, [])
    for g in arr:
        g["hooks"] = [h for h in g.get("hooks", []) if h.get("command") != cmd]
    arr[:] = [g for g in arr if g.get("hooks")]
    if matcher is None:
        group = next((g for g in arr if not g.get("matcher")), None)
    else:
        group = next((g for g in arr if g.get("matcher") == matcher), None)
    if group is None:
        group = {"hooks": []} if matcher is None else {"matcher": matcher, "hooks": []}
        arr.append(group)
    group.setdefault("hooks", []).append({"type": "command", "command": cmd, "timeout": timeout})

life = os.path.join(hook_dir, "session-lifecycle.sh")
upsert("Stop", None, f"{life} --unlock", 3)

with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY
}

# Pass 1 — should consolidate.
# Read counts via file (mixing `--arg` substitution and plain `$()` capture
# of jq on the same shell line has produced an environment-specific bash
# substitution glitch that returned wrong digits; the file path is solid).
run_upsert
jq --arg cmd "$UNLOCK_CMD" '[.hooks.Stop[].hooks[] | select(.command == $cmd)] | length' "$SETTINGS" > "$TMP/unlock"
jq '[.hooks.Stop[] | select((.matcher // "") == "")] | length' "$SETTINGS" > "$TMP/groups"
jq '[.hooks.Stop[].hooks[] | select(.command | test("mempalace"))] | length' "$SETTINGS" > "$TMP/mp"
jq '[.hooks.Stop[].hooks[] | select(.command | test("orca"))] | length' "$SETTINGS" > "$TMP/orca"
UNLOCK_COUNT=$(cat "$TMP/unlock")
NO_MATCHER_COUNT=$(cat "$TMP/groups")
MEMPALACE=$(cat "$TMP/mp")
ORCA=$(cat "$TMP/orca")

check "Pass 1: exactly 1 session-lifecycle.sh --unlock entry (was 2)" "[ $UNLOCK_COUNT -eq 1 ]"
check "Pass 1: exactly 1 no-matcher Stop group (was 2)" "[ $NO_MATCHER_COUNT -eq 1 ]"
check "Pass 1: mempalace hook preserved" "[ $MEMPALACE -eq 1 ]"
check "Pass 1: orca hook preserved" "[ $ORCA -eq 1 ]"

# Snapshot before pass 2 for byte-diff.
cp "$SETTINGS" "$SETTINGS.snap"

# Pass 2 — should be a no-op.
run_upsert
jq --arg cmd "$UNLOCK_CMD" '[.hooks.Stop[].hooks[] | select(.command == $cmd)] | length' "$SETTINGS" > "$TMP/unlock2"
jq '[.hooks.Stop[] | select((.matcher // "") == "")] | length' "$SETTINGS" > "$TMP/groups2"
UNLOCK_COUNT2=$(cat "$TMP/unlock2")
NO_MATCHER_COUNT2=$(cat "$TMP/groups2")

check "Pass 2: still exactly 1 unlock entry (idempotent)" "[ $UNLOCK_COUNT2 -eq 1 ]"
check "Pass 2: still exactly 1 no-matcher group" "[ $NO_MATCHER_COUNT2 -eq 1 ]"

# Byte-level idempotency check on the relevant Stop slice (canonicalize
# via jq to avoid spurious key-order diffs).
jq '.hooks.Stop' "$SETTINGS.snap" > "$SETTINGS.snap.norm"
jq '.hooks.Stop' "$SETTINGS"       > "$SETTINGS.norm"
check "Pass 2: byte-identical Stop slice (true idempotency)" "diff -q $SETTINGS.snap.norm $SETTINGS.norm >/dev/null 2>&1"

if [ $fail -eq 0 ]; then echo "install-idempotency: pass"; exit 0; fi
echo "install-idempotency: $fail failure(s)"
exit 1
