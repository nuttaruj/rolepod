#!/bin/bash
# PostToolUse(Bash) — after ship cmd, suggest reindex if many files changed. Silent otherwise.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
CMD=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[ -z "$CMD" ] && exit 0

# Match ship commands
echo "$CMD" | grep -qE '(gh pr merge|git push.*\b(main|master)\b|git merge.*\b(main|master)\b)' || exit 0

CWD=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || echo "$PWD")
REPO=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0
N=$(git -C "$REPO" diff --name-only HEAD~5..HEAD 2>/dev/null | wc -l | tr -d ' ')

[ "$N" -lt 5 ] && exit 0

python3 -c "
import json
print(json.dumps({'hookSpecificOutput':{'hookEventName':'PostToolUse','additionalContext':'**Reindex recommended**: $N files in last 5 commits. Suggest user run \`cd $REPO && npx gitnexus analyze\`'}}))
" 2>/dev/null || echo '{}'
