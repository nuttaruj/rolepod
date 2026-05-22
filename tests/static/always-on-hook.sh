#!/usr/bin/env bash
# Static smoke test — Slice 1 of the clean-plugin redesign.
#
# Proves the SessionStart always-on hook works end-to-end:
#   - hooks/always-on-loader.sh emits valid JSON SessionStart additionalContext
#   - the emitted payload stays within the ~5KB docs-safe budget
#   - the judgment-core content file exists and is non-empty
#   - adapters/claude/hooks.json wires the loader into the SessionStart array
#
# Run directly: bash tests/static/always-on-hook.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Exercise the SHIPPED artifact: the rendered plugin tree. hooks/always-on-core
# is a .md.tmpl source ({{INCLUDE}} unresolved) — the loader reads the rendered
# always-on-core.md next to it, which here is the committed plugin copy.
HOOK="$REPO_DIR/plugins/rolepod/hooks/always-on-loader.sh"
CORE="$REPO_DIR/plugins/rolepod/hooks/always-on-core.md"
HOOKS_JSON="$REPO_DIR/adapters/claude/hooks.json"
BUDGET=5120

fail=0
pass() { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1"; fail=$((fail + 1)); }

echo "always-on-hook:"

# 1. Hook script + content file present.
[ -f "$HOOK" ]  && pass "plugin always-on-loader.sh exists" || bad "plugin always-on-loader.sh missing"
[ -f "$CORE" ]  && pass "plugin always-on-core.md exists"   || bad "plugin always-on-core.md missing"
[ -s "$CORE" ]  && pass "judgment core is non-empty"        || bad "judgment core is empty"

# 2. Hook emits valid JSON with the SessionStart additionalContext shape.
if [ -f "$HOOK" ]; then
  OUT=$(echo '{}' | bash "$HOOK" 2>/dev/null || echo "")
  if printf '%s' "$OUT" | python3 -c '
import sys, json
d = json.load(sys.stdin)
o = d["hookSpecificOutput"]
assert o["hookEventName"] == "SessionStart", "wrong hookEventName"
assert o["additionalContext"].strip(), "empty additionalContext"
' 2>/dev/null; then
    pass "emits valid SessionStart additionalContext JSON"
  else
    bad "did not emit valid SessionStart additionalContext JSON"
  fi

  # 3. Payload within the docs-safe budget.
  SIZE=$(printf '%s' "$OUT" | wc -c | tr -d ' ')
  if [ "${SIZE:-999999}" -le "$BUDGET" ]; then
    pass "payload ${SIZE}B within ${BUDGET}B budget"
  else
    bad "payload ${SIZE}B exceeds ${BUDGET}B budget"
  fi
fi

# 4. hooks.json wires the loader into the SessionStart array.
if [ -f "$HOOKS_JSON" ]; then
  if python3 -c '
import sys, json
d = json.load(open(sys.argv[1]))
ss = d["hooks"]["SessionStart"]
cmds = [h["command"] for grp in ss for h in grp["hooks"]]
assert any("always-on-loader.sh" in c for c in cmds), "loader not wired"
' "$HOOKS_JSON" 2>/dev/null; then
    pass "hooks.json SessionStart array wires always-on-loader.sh"
  else
    bad "hooks.json SessionStart array does not wire always-on-loader.sh"
  fi
else
  bad "adapters/claude/hooks.json missing"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "always-on-hook: pass"
  exit 0
else
  echo "always-on-hook: FAIL ($fail)"
  exit 1
fi
