#!/bin/bash
# Cursor beforeShellExecution — path-aware gate on `git commit`.
#
# Cursor stdin for beforeShellExecution provides `command` directly (not nested
# under tool_input), plus `cwd` and a `sandbox` flag. Output keys:
#   permission: "allow" | "deny" | "ask"
#   user_message: str           — shown to user (reason for deny/ask)
#   agent_message: str          — visible to agent
#
# Same tiering as the Claude version:
#   Trivial diff (≤5 lines, 1 file, 0 logic lines, no risky path) → silent pass
#   Normal code (logic but no high-risk path)                     → SOFT warn
#   High-risk path matched                                         → HARD block
#
# Env overrides (parity with Claude):
#   ROLEPOD_GATES_HARD=1   — escalate normal code from SOFT to HARD
#   ROLEPOD_GATES_SOFT=1   — suppress ALL warnings (silent)
#   [gates: pass]          — bypass marker inside commit message body.
#   ROLEPOD_GATES_PASSED=1 — legacy inline bypass; still honored but no longer
#                            prescribed — an env-prefixed git commit is a
#                            command shape permission layers read as gate
#                            circumvention. (Cursor provides no session
#                            transcript, so the Claude version's evidence
#                            auto-pass has no equivalent here; the marker
#                            stays the release valve.)
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
CMD=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo "")

echo "$CMD" | grep -qE '(^|[;&|]|[[:space:]])git[[:space:]]+commit\b' || exit 0

if echo "$CMD" | grep -qE 'ROLEPOD_GATES_PASSED=1'; then exit 0; fi
if echo "$CMD" | grep -qE '\[gates:[[:space:]]*pass\]'; then exit 0; fi
if [ "${ROLEPOD_GATES_SOFT:-0}" = "1" ]; then
  exit 0
fi

CWD=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || echo "")
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || true

DIFF_STAT=$(git diff --cached --numstat 2>/dev/null || echo "")
if [ -z "$DIFF_STAT" ]; then
  exit 0
fi

FILES_CHANGED=$(echo "$DIFF_STAT" | wc -l | tr -d ' ')
LINES_CHANGED=$(echo "$DIFF_STAT" | awk '{a+=$1; b+=$2} END {print a+b}')
LINES_CHANGED=${LINES_CHANGED:-0}

HIGH_RISK=$(echo "$DIFF_STAT" | awk '{print $3}' | grep -iE '(^|/|_)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices)(/|\.|_|$)' | head -1 || true)

LOGIC_LINES=$(git diff --cached -U0 2>/dev/null | grep -E '^[+-]' | grep -vE '^[+-]{3}' | grep -vE '^[+-][[:space:]]*$' | grep -vE '^[+-][[:space:]]*(#|//|/\*|\*/?|--|;)' || true)
if [ -z "$LOGIC_LINES" ]; then
  LOGIC_COUNT=0
else
  LOGIC_COUNT=$(printf '%s\n' "$LOGIC_LINES" | wc -l | tr -d ' ')
fi

if [ "$FILES_CHANGED" -eq 1 ] && [ "$LINES_CHANGED" -le 5 ] && [ "$LOGIC_COUNT" -eq 0 ] && [ -z "$HIGH_RISK" ]; then
  exit 0
fi

REASON="precommit-gate BLOCKED. "
REASON+="Diff: $FILES_CHANGED files / $LINES_CHANGED lines / $LOGIC_COUNT logic lines. "
[ -n "$HIGH_RISK" ] && REASON+="HIGH-RISK path: $HIGH_RISK → mandatory qa-tester + security-engineer review. "
REASON+="Run gates explicitly: S1-S5 (simplicity) + T1-T6 (tests) + F1-F5 (failure-mode). "
REASON+="After passing, include \`[gates: pass]\` in the commit message body — do NOT env-prefix the git command. "
REASON+="Soft mode for incremental rollout: ROLEPOD_GATES_SOFT=1 in env."

HARD_BLOCK=0
if [ -n "$HIGH_RISK" ]; then
  HARD_BLOCK=1
elif [ "${ROLEPOD_GATES_HARD:-0}" = "1" ]; then
  HARD_BLOCK=1
fi

if [ "$HARD_BLOCK" -eq 1 ]; then
  ROLEPOD_HOOK_MSG="$REASON" python3 -c "
import json, os
print(json.dumps({'permission':'deny','user_message':os.environ.get('ROLEPOD_HOOK_MSG','')}))
" 2>/dev/null || echo "{}"
  exit 2
fi

WARN="precommit-gate SOFT warn. "
WARN+="Diff: $FILES_CHANGED files / $LINES_CHANGED lines / $LOGIC_COUNT logic lines (normal code, no high-risk path). "
WARN+="Recommend running S1-S5 (simplicity) + T1-T6 (tests) + F1-F5 (failure-mode) before commit. "
WARN+="Set ROLEPOD_GATES_HARD=1 to enforce blocking on normal diffs."

ROLEPOD_HOOK_MSG="$WARN" python3 -c "
import json, os
print(json.dumps({'permission':'allow','agent_message':os.environ.get('ROLEPOD_HOOK_MSG','')}))
" 2>/dev/null || true

exit 0
