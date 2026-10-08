#!/bin/bash
# Behavioral test — precommit-gate's HARD evidence path is Claude-native only
# (spec Desired 10, 2026-09-25): ROLEPOD_LEAD_CLI unset (real Claude Code
# never sets it) or "claude" runs the full evidence tally; any other value
# gets only the private-docs deny, then passes. The old dispatch-proof /
# edit-ledger "lib-less" fallback this file used to lock is REMOVED — there
# is no fallback branch left to test.
#
# Runs the real hook (hooks/lib/session_state.py sits alongside it, as every
# real render ships it now) in a throwaway git repo with a staged high-risk
# diff and zero session evidence.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

fail=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
mkdir -p "$HOME/.rolepod"
printf '{"workflow":{"mode":"full"}}\n' > "$HOME/.rolepod/config.json"

# Throwaway repo with one commit, then a staged high-risk diff with logic.
mkdir -p "$tmp/repo" && cd "$tmp/repo"
git init -q . && git config user.email t@t && git config user.name t
echo base > base.txt && git add base.txt && git commit -qm init
mkdir -p auth
printf 'def check(tok):\n    if tok is None:\n        return False\n    return len(tok) > 8\n\n\ndef issue(uid):\n    return f"tk-{uid}"\n' > auth/login.py
git add auth/login.py

INPUT='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"add auth check\""}}'
GATE="$REPO_DIR/hooks/precommit-gate.sh"

# run <label> <expect: deny|pass> <env prefix, e.g. "ROLEPOD_LEAD_CLI=codex", or "">
run() {
  local out
  if [ -n "$3" ]; then
    out=$(printf '%s' "$INPUT" | env -u CLAUDE_PLUGIN_ROOT -u ROLEPOD_LEAD_CLI ROLEPOD_SESSION_MODE=full ROLEPOD_SESSION_SOURCE=global ROLEPOD_SESSION_CLI=claude $3 bash "$GATE" 2>/dev/null)
  else
    out=$(printf '%s' "$INPUT" | env -u CLAUDE_PLUGIN_ROOT -u ROLEPOD_LEAD_CLI ROLEPOD_SESSION_MODE=full ROLEPOD_SESSION_SOURCE=global ROLEPOD_SESSION_CLI=claude bash "$GATE" 2>/dev/null)
  fi
  local verdict=pass
  echo "$out" | grep -q '"permissionDecision": *"deny"' && verdict=deny
  if [ "$verdict" = "$2" ]; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1 — expected $2, got $verdict"
    fail=$((fail+1))
  fi
}

echo "── phase-log-fallback (Claude-only HARD evidence path, spec Desired 10) ──"

# 1. No ROLEPOD_LEAD_CLI at all (real Claude Code) → full evidence path → deny.
run "no ROLEPOD_LEAD_CLI (real Claude Code), high-risk diff, 0 evidence → deny" deny ""

# 2. ROLEPOD_LEAD_CLI=claude → same as unset → deny.
run "ROLEPOD_LEAD_CLI=claude, high-risk diff, 0 evidence → deny" deny "ROLEPOD_LEAD_CLI=claude"

# 3. Any other CLI → HARD evidence path never runs → passes with 0 evidence.
run "ROLEPOD_LEAD_CLI=codex, high-risk diff, 0 evidence → passes" pass "ROLEPOD_LEAD_CLI=codex"
run "ROLEPOD_LEAD_CLI=cursor, high-risk diff, 0 evidence → passes" pass "ROLEPOD_LEAD_CLI=cursor"

# 4. The private-docs deny still applies to every CLI, run first.
mkdir -p docs/rolepod
echo "plan" > docs/rolepod/plan.md
git add docs/rolepod/plan.md
run "ROLEPOD_LEAD_CLI=codex, staged docs/rolepod/ path → still denies" deny "ROLEPOD_LEAD_CLI=codex"

echo ""
if [ $fail -eq 0 ]; then
  echo "phase-log-fallback: pass"
  exit 0
fi
echo "phase-log-fallback: $fail failure(s)"
exit 1
