#!/bin/bash
# PostToolUse(Edit|Write) — remind to verify before claiming done.
# Fires after code edits. Silent for non-edit tools.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

# Match Edit / Write / NotebookEdit
echo "$TOOL" | grep -qE '^(Edit|Write|NotebookEdit)$' || exit 0

FILE=$(echo "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin).get('tool_input',{});print(d.get('file_path','') or d.get('notebook_path',''))" 2>/dev/null || echo "")

# Skip docs / config-only / non-code
[[ "$FILE" =~ \.(md|txt|json|yml|yaml|toml)$ ]] && exit 0

# Code edit — emit reminder
python3 -c "
import json
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PostToolUse',
    'additionalContext': '✓ Edit applied. Before claiming done: (1) Read file to confirm change, (2) run relevant test/build/lint, (3) state evidence per verification.md. Skip = false confidence.'
  }
}))
" 2>/dev/null || echo '{}'

exit 0
