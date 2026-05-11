#!/bin/bash
# PreToolUse(Bash) — block `git commit` unless gates explicitly passed.
# Mechanical enforcement of S1-S5 / T1-T6 / F1-F5 — Lead must consciously
# acknowledge gates instead of skipping via flow-state rationalization.
#
# Bypass mechanisms (intentional — friction = conscious step):
# 1. Set ROLEPOD_GATES_PASSED=1 inline: `ROLEPOD_GATES_PASSED=1 git commit ...`
# 2. Include marker `[gates: pass]` in commit message body
# 3. Soft mode: ROLEPOD_GATES_SOFT=1 → warn only, don't block
#
# Skip criteria (auto-pass — no gate friction for trivial changes):
# - diff ≤5 lines, 1 file, zero logic-bearing lines, no high-risk path
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
[ "$TOOL" = "Bash" ] || exit 0

CMD=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Match git commit (allow flags, env prefix, heredoc syntax)
echo "$CMD" | grep -qE '(^|[;&|]|[[:space:]])git[[:space:]]+commit\b' || exit 0

# Allow if explicit bypass present in command itself (env prefix or marker)
if echo "$CMD" | grep -qE 'ROLEPOD_GATES_PASSED=1'; then exit 0; fi
if echo "$CMD" | grep -qE '\[gates:[[:space:]]*pass\]'; then exit 0; fi
if [ "${ROLEPOD_GATES_SOFT:-0}" = "1" ]; then
  python3 -c "
import json
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': '⚠️  precommit-gate SOFT mode: gates skipped (ROLEPOD_GATES_SOFT=1). Re-enable hard gate by unsetting env.'}}))
" 2>/dev/null
  exit 0
fi

# Compute diff stats — skip gate if trivial
DIFF_STAT=$(git diff --cached --numstat 2>/dev/null || echo "")
if [ -z "$DIFF_STAT" ]; then
  # No staged changes — let git's own error fire
  exit 0
fi

FILES_CHANGED=$(echo "$DIFF_STAT" | wc -l | tr -d ' ')
LINES_CHANGED=$(echo "$DIFF_STAT" | awk '{a+=$1; b+=$2} END {print a+b}')
LINES_CHANGED=${LINES_CHANGED:-0}

# High-risk path detection
HIGH_RISK=$(echo "$DIFF_STAT" | awk '{print $3}' | grep -iE '(auth|billing|payment|migration|credit|permission|secret|crypto|token)' | head -1 || true)

# Logic-bearing line count — non-comment, non-blank, non-pure-rename lines
LOGIC_LINES=$(git diff --cached -U0 2>/dev/null | grep -E '^[+-]' | grep -vE '^[+-]{3}' | grep -vE '^[+-][[:space:]]*$' | grep -vE '^[+-][[:space:]]*(#|//|/\*|\*/?|--|;)' || true)
LOGIC_COUNT=$(echo -n "$LOGIC_LINES" | grep -c '^' 2>/dev/null || echo 0)

# Auto-skip path: trivial commit
if [ "$FILES_CHANGED" -eq 1 ] && [ "$LINES_CHANGED" -le 5 ] && [ "$LOGIC_COUNT" -eq 0 ] && [ -z "$HIGH_RISK" ]; then
  exit 0
fi

# Build deny reason
REASON="precommit-gate BLOCKED. "
REASON+="Diff: $FILES_CHANGED files / $LINES_CHANGED lines / $LOGIC_COUNT logic lines. "
[ -n "$HIGH_RISK" ] && REASON+="HIGH-RISK path: $HIGH_RISK → mandatory qa-tester + security-engineer review. "
REASON+="Run gates explicitly: S1-S5 (simplicity) + T1-T6 (tests) + F1-F5 (failure-mode). "
REASON+="After passing, bypass with: prefix \`ROLEPOD_GATES_PASSED=1 git commit ...\` OR include \`[gates: pass]\` in commit message. "
REASON+="Soft mode for incremental rollout: ROLEPOD_GATES_SOFT=1 in env."

python3 -c "
import json
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'permissionDecision': 'deny',
    'permissionDecisionReason': '''$REASON'''
  }
}))
" 2>/dev/null || echo "{}"

# Exit 2 = block tool call (belt-and-suspenders alongside permissionDecision)
exit 2
