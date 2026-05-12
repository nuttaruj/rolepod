#!/bin/bash
# PreToolUse(Edit|Write|MultiEdit) — inject gate reminder BEFORE edit fires.
# Catches workflow drift: Lead about to edit without Q1-Q4 / GitNexus / reviewer plan.
# Soft reminder (exit 0). Blocking variant requires explicit opt-in.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

# Match Edit / Write / MultiEdit / NotebookEdit
echo "$TOOL" | grep -qE '^(Edit|Write|MultiEdit|NotebookEdit)$' || exit 0

FILE=$(echo "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin).get('tool_input',{});print(d.get('file_path','') or d.get('notebook_path',''))" 2>/dev/null || echo "")

# Skip docs / config / lockfiles — low-risk edits
[[ "$FILE" =~ \.(md|txt|json|yml|yaml|toml|lock|gitignore)$ ]] && exit 0
[[ "$FILE" =~ (README|CHANGELOG|LICENSE)$ ]] && exit 0

# High-risk path flag
HIGH_RISK=""
if [[ "$FILE" =~ (auth|billing|payment|migration|credit|permission|secret|crypto|token) ]]; then
  HIGH_RISK="⚠️  HIGH-RISK path detected → mandatory: qa-tester + security-engineer review BEFORE commit. "
fi

# Emit reminder as additionalContext
python3 -c "
import json
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'additionalContext': '${HIGH_RISK}GATE CHECK before edit: Q1(>1 file?) Q2(run tests?) Q3(design judgment?) Q4(>3 tool calls?) — any yes → delegate via Agent. GitNexus_impact run on target symbol? Reviewer (qa-tester floor) planned? Skipping any → state reason explicitly. flow-state ≠ gate skip.'
  }
}))
" 2>/dev/null || echo '{}'

exit 0
