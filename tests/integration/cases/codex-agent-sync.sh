#!/bin/bash
# codex-agent-sync — the Codex SessionStart hook that makes
# `codex plugin marketplace upgrade rolepod` a complete update (v2.75.0).
# The Codex manifest has no agents component, so the plugin bundles
# agents/rolepod-*.toml + agents/AGENTS.rolepod.md and this hook installs
# them into $CODEX_HOME. Sandboxed: HOME / CODEX_HOME point at a temp dir —
# the real ~/.codex is never touched.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"
PLUGIN="$REPO_DIR/plugins/rolepod-codex"
HOOK="$PLUGIN/hooks/agent-sync.sh"
VER=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN/.codex-plugin/plugin.json" | head -1)
FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT
A="$FIX/.codex/agents"; MD="$FIX/.codex/AGENTS.md"

fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=1; fi
}
run() {  # the way Codex invokes it: ${PLUGIN_ROOT} resolved, hook JSON on stdin
  echo '{"hook_event_name":"SessionStart"}' | HOME="$FIX" PLUGIN_ROOT="$PLUGIN" bash "$HOOK" 2>/dev/null
}
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }  # GNU first: on Linux `stat -f %m` prints the mount point (non-numeric) and succeeds

check "hook is bash -n clean" "bash -n '$HOOK'"
check "plugin bundles 16 agents + the AGENTS.md block" \
  "[ \$(ls '$PLUGIN'/agents/rolepod-*.toml | wc -l) -eq 16 ] && [ -s '$PLUGIN/agents/AGENTS.rolepod.md' ]"
check "plugin version resolved" "[ -n '$VER' ]"

# 1. Fresh HOME (plugin added, never installed)
OUT=$(run)
check "fresh: 16 agents land in ~/.codex/agents/" "[ \$(ls '$A'/rolepod-*.toml | wc -l) -eq 16 ]"
check "fresh: agents byte-exact vs bundle" \
  "for f in '$PLUGIN'/agents/rolepod-*.toml; do cmp -s \"\$f\" '$A'/\$(basename \"\$f\") || exit 1; done"
check "fresh: AGENTS.md created block-only" \
  "head -1 '$MD' | grep -qx '<!-- rolepod:start -->' && tail -1 '$MD' | grep -qx '<!-- rolepod:end -->'"
check "fresh: stamp = plugin version" "[ \"\$(cat '$A/.rolepod-agents-version')\" = '$VER' ]"
check "fresh: reports via SessionStart additionalContext" \
  "printf '%s' \"\$OUT\" | grep -q '\"hookEventName\": \"SessionStart\"' && printf '%s' \"\$OUT\" | grep -q 'synced to plugin v$VER'"
check "fresh: lock released" "[ ! -d '$A/.rolepod-sync.lock' ]"

# 2. Same version again → silent no-op, nothing rewritten
touch -t 202001010000 "$A/rolepod-scout.toml" "$MD"
OUT=$(run)
check "same version: silent" "[ -z \"\$OUT\" ]"
check "same version: agent + AGENTS.md untouched (mtime kept)" \
  "[ \$(mtime '$A/rolepod-scout.toml') -lt 1600000000 ] && [ \$(mtime '$MD') -lt 1600000000 ]"

# 3. Upgrade shape: stale stamp, user content everywhere
printf '%s\n' "0.0.1" > "$A/.rolepod-agents-version"
printf 'name = "retired"\n' > "$A/rolepod-retired.toml"
printf 'name = "mine"\n' > "$A/mine.toml"
printf 'name = "tampered"\n' > "$A/rolepod-scout.toml"
printf '<!-- CODEGRAPH_START -->\nuser tool block\n<!-- CODEGRAPH_END -->\n\n<!-- rolepod:start -->\nOLD ROLEPOD BODY\n<!-- rolepod:end -->\n\n# My notes\nkeep me\n' > "$MD"
OUT=$(run)
check "upgrade: retired rolepod-*.toml pruned" "[ ! -e '$A/rolepod-retired.toml' ]"
check "upgrade: user agent without the prefix untouched" "[ -e '$A/mine.toml' ]"
check "upgrade: tampered rolepod agent restored byte-exact" "cmp -s '$PLUGIN/agents/rolepod-scout.toml' '$A/rolepod-scout.toml'"
check "upgrade: content outside our block preserved" \
  "grep -q 'user tool block' '$MD' && grep -q 'CODEGRAPH_START' '$MD' && grep -q 'keep me' '$MD'"
check "upgrade: old block body gone, new body in" \
  "! grep -q 'OLD ROLEPOD BODY' '$MD' && grep -qF \"\$(head -1 '$PLUGIN/agents/AGENTS.rolepod.md')\" '$MD'"
check "upgrade: exactly one rolepod block" \
  "[ \$(grep -c '<!-- rolepod:start -->' '$MD') -eq 1 ] && [ \$(grep -c '<!-- rolepod:end -->' '$MD') -eq 1 ]"
check "upgrade: user content stays above our block" \
  "awk '/keep me/{k=NR} /rolepod:start/{s=NR} END{exit !(k && s && k < s)}' '$MD'"
check "upgrade: reports agents + retired + block refresh" \
  "printf '%s' \"\$OUT\" | grep -q 'retired' && printf '%s' \"\$OUT\" | grep -q 'block refreshed'"
check "upgrade: stamp advanced" "[ \"\$(cat '$A/.rolepod-agents-version')\" = '$VER' ]"

# 4. AGENTS.md without markers → block appended, original kept on top
printf '%s\n' "0.0.1" > "$A/.rolepod-agents-version"
printf '# Personal rules\nno markers here\n' > "$MD"
run >/dev/null
check "no-markers: original content kept first" "head -1 '$MD' | grep -q 'Personal rules'"
check "no-markers: block appended once" "[ \$(grep -c '<!-- rolepod:start -->' '$MD') -eq 1 ]"

# 5. Off switch
printf '%s\n' "0.0.1" > "$A/.rolepod-agents-version"
printf 'name = "tampered"\n' > "$A/rolepod-scout.toml"
OUT=$(echo '{}' | HOME="$FIX" PLUGIN_ROOT="$PLUGIN" ROLEPOD_AGENT_SYNC_OFF=1 bash "$HOOK" 2>/dev/null)
check "ROLEPOD_AGENT_SYNC_OFF=1: nothing touched, silent" \
  "grep -q tampered '$A/rolepod-scout.toml' && [ \"\$(cat '$A/.rolepod-agents-version')\" = 0.0.1 ] && [ -z \"\$OUT\" ]"

# 6. PLUGIN_ROOT fallback (dirname/..) + CODEX_HOME honored
mkdir -p "$FIX/alt"
OUT=$(echo '{}' | HOME="$FIX" CODEX_HOME="$FIX/alt" bash "$HOOK" 2>/dev/null)
check "CODEX_HOME + PLUGIN_ROOT fallback: syncs there" \
  "[ \$(ls '$FIX/alt/agents'/rolepod-*.toml | wc -l) -eq 16 ] && [ -s '$FIX/alt/AGENTS.md' ]"

# 7. Locks: a stale (crash) lock is taken over; a live one yields silently
printf '%s\n' "0.0.1" > "$A/.rolepod-agents-version"
mkdir -p "$A/.rolepod-sync.lock"; touch -t 202001010000 "$A/.rolepod-sync.lock"
run >/dev/null
check "stale lock taken over; sync proceeds" \
  "[ \"\$(cat '$A/.rolepod-agents-version')\" = '$VER' ] && [ ! -d '$A/.rolepod-sync.lock' ]"
printf '%s\n' "0.0.1" > "$A/.rolepod-agents-version"; mkdir -p "$A/.rolepod-sync.lock"
OUT=$(run); rmdir "$A/.rolepod-sync.lock"
check "live lock: yields, stamp untouched" "[ -z \"\$OUT\" ] && [ \"\$(cat '$A/.rolepod-agents-version')\" = 0.0.1 ]"

# 8. Missing bundle → fail-open (exit 0, no output, nothing written)
OUT=$(echo '{}' | HOME="$FIX/none" PLUGIN_ROOT="$FIX/no-plugin" bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "no bundle: exits 0 silently" "[ \"\$OUT\" = 'rc=0' ] && [ ! -d '$FIX/none' ]"

# 9. Installer parity — install.sh writes the same stamp path
check "install.sh writes the agent-sync stamp" "grep -q '\.rolepod-agents-version' install.sh"

exit $fail
