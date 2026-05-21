#!/bin/bash
# PreToolUse Bash hook — block sub-agents from running destructive git ops.
#
# Rationale: real-world failure observed. A backend-developer sub-agent ran
# `git commit` after marking tasks COMPLETED, bypassing the qa-tester floor
# and Lead's verify step. Soft reminder hooks already in place were ignored
# because agent saw success signals (tsc=0, imports OK) and committed.
#
# Mechanism: Claude Code PreToolUse hook input includes `agent_id` +
# `agent_type` ONLY when the call originates from a sub-agent. Main Lead
# conversation has neither field. We check command + agent context, block
# with exit 2 + JSON deny message so the agent sees a hard stop instead of
# soft advisory text.
#
# Blocks: git commit, git push, gh pr merge, gh pr create
# Allows: every other Bash use (tests, build, lint, grep, etc.)
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

# Extract fields. agent_id absent → Lead conversation → allow.
AGENT_ID=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('agent_id', '') or '')
except Exception:
    print('')
" 2>/dev/null || echo "")

[ -z "$AGENT_ID" ] && exit 0

AGENT_TYPE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('agent_type', '') or '')
except Exception:
    print('')
" 2>/dev/null || echo "")

CMD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', '') or '')
except Exception:
    print('')
" 2>/dev/null || echo "")

# Detect destructive git ops. Match the command boundary so `git committed`
# in a comment string doesn't false-positive, but `git commit -m ...` does.
BLOCKED=""
case "$CMD" in
  *"git commit"*|*"git commit --"*) BLOCKED="git commit" ;;
  *"git push"*) BLOCKED="git push" ;;
  *"gh pr merge"*) BLOCKED="gh pr merge" ;;
  *"gh pr create"*) BLOCKED="gh pr create" ;;
  *"git reset --hard"*) BLOCKED="git reset --hard" ;;
  *"git push --force"*|*"git push -f"*) BLOCKED="git push --force" ;;
esac

[ -z "$BLOCKED" ] && exit 0

# Block via PreToolUse deny JSON. Claude Code surfaces `reason` back to the
# agent so it knows WHY the call failed and what to do next.
python3 -c "
import json
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'permissionDecision': 'deny',
    'permissionDecisionReason': (
      'BLOCKED: sub-agent \\'$AGENT_TYPE\\' attempted \\'$BLOCKED\\'. '
      'Sub-agents NEVER commit, push, or merge directly — that is the Lead '
      'responsibility after qa-tester + universal-reviewer verify. '
      'Return COMPLETED status with file list and verification evidence; '
      'Lead will commit. '
      'See the Agent protocol section in your agent file — sub-agent commit ban.'
    )
  }
}))
" 2>/dev/null

exit 0
