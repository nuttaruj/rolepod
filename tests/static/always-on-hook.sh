#!/usr/bin/env bash
# Static smoke test — Slice 1 of the clean-plugin redesign.
#
# Proves the SessionStart always-on hook works end-to-end:
#   - hooks/always-on-loader.sh emits valid JSON SessionStart additionalContext
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

fail=0
pass() { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1"; fail=$((fail + 1)); }

echo "always-on-hook:"

# 1. Hook emits valid JSON with the SessionStart additionalContext shape
#    (a missing hook or empty core file fails here too — bash "$HOOK" then
#    emits nothing and the JSON parse below fails).
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

  # 3. Round-trip: additionalContext is the core file byte-for-byte (UTF-8
  #     emitted raw, not \uXXXX-escaped — v2.83.1 saved 153 B of budget), and
  #     the emission does not depend on the hook shell's locale.
  if printf '%s' "$OUT" | python3 -c '
import sys, json
d = json.load(sys.stdin)
assert d["hookSpecificOutput"]["additionalContext"] == open(sys.argv[1], encoding="utf-8").read(), "context != core file"
' "$CORE" 2>/dev/null && ! printf '%s' "$OUT" | grep -q '\\u20'; then
    pass "additionalContext round-trips to the core file with raw UTF-8"
  else
    bad "additionalContext is mangled or \\u-escaped"
  fi
  OUT_C=$(echo '{}' | LC_ALL=C LANG=C bash "$HOOK" 2>/dev/null || echo "")
  if [ "$OUT_C" = "$OUT" ]; then
    pass "identical payload under LC_ALL=C"
  else
    bad "payload differs under LC_ALL=C (locale-dependent emission)"
  fi
else
  bad "plugins/rolepod/hooks/always-on-loader.sh missing"
fi

# 4. hooks.json wires the loader into the SessionStart array.
if [ -f "$HOOKS_JSON" ]; then
  if python3 -c '
import sys, json
d = json.load(open(sys.argv[1]))
ss = d["hooks"]["SessionStart"]
cmds = [h["command"] for grp in ss for h in grp["hooks"]]
assert len(cmds) == 1 and "session-start.sh" in cmds[0], "combined startup not wired"
assert "always-on-loader.sh" in open(sys.argv[2]).read(), "startup does not invoke the core loader"
' "$HOOKS_JSON" "$REPO_DIR/hooks/session-start.sh" 2>/dev/null; then
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
