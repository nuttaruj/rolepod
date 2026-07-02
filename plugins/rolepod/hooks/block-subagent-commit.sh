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

# Detect destructive git ops by walking the argv tokens — NOT substring
# match. Substring missed flag-separated forms (`git -C . commit`,
# `git -c k=v commit`), which a blocked agent can trivially discover.
# Token walk skips git's pre-subcommand options (and their values) so the
# real subcommand is what gets matched.
BLOCKED=$(printf '%s' "$CMD" | python3 -c "
import sys, shlex
cmd = sys.stdin.read()
try:
    toks = shlex.split(cmd)
except ValueError:
    toks = cmd.split()
VALUE_OPTS = {'-C', '--git-dir', '--work-tree', '--namespace', '--exec-path'}
blocked = ''
for i, t in enumerate(toks):
    if t == 'git':
        j = i + 1
        while j < len(toks) and toks[j].startswith('-'):
            if toks[j] in VALUE_OPTS:
                j += 2
            elif toks[j] == '-c' and j + 1 < len(toks) and '=' in toks[j + 1]:
                j += 2
            else:
                j += 1
        if j < len(toks):
            sub = toks[j]
            rest = toks[j:]
            if sub == 'commit':
                blocked = 'git commit'
            elif sub == 'push':
                blocked = 'git push --force' if ('--force' in rest or '-f' in rest) else 'git push'
            elif sub == 'reset' and '--hard' in rest:
                blocked = 'git reset --hard'
    elif t == 'gh' and i + 2 < len(toks) and toks[i + 1] == 'pr' and toks[i + 2] in ('merge', 'create'):
        blocked = 'gh pr ' + toks[i + 2]
    if blocked:
        break
print(blocked)
" 2>/dev/null || echo "")

[ -z "$BLOCKED" ] && exit 0

# Block via PreToolUse deny JSON. Claude Code surfaces `reason` back to the
# agent so it knows WHY the call failed and what to do next. Fields are
# env-passed — a quote inside agent_type/command must not break (or inject
# into) the JSON emitter.
RP_AGENT_TYPE="$AGENT_TYPE" RP_BLOCKED="$BLOCKED" python3 -c "
import json, os
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'permissionDecision': 'deny',
    'permissionDecisionReason': (
      'BLOCKED: sub-agent %r attempted %r. '
      'Sub-agents NEVER commit, push, or merge directly — that is the Lead '
      'responsibility after qa-tester + universal-reviewer verify. '
      'Return COMPLETED status with file list and verification evidence; '
      'Lead will commit. '
      'See the Agent protocol section in your agent file — sub-agent commit ban.'
    ) % (os.environ.get('RP_AGENT_TYPE', ''), os.environ.get('RP_BLOCKED', ''))
  }
}))
" 2>/dev/null

exit 0
