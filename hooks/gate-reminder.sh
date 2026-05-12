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

# Schema-bound NEW file detection — emit STRONG verify-doc reminder FIRST.
# Catches the most common silent-fail: writing manifest/plugin/extension
# files against assumed (training-cached) schema instead of WebFetched
# official spec. Fires only when file doesn't exist yet (new file).
SCHEMA_BOUND=""
if [ ! -e "$FILE" ] && [[ "$FILE" =~ (\.claude-plugin/|\.codex-plugin/|/extensions/|marketplace\.json$|plugin\.json$|manifest\.json$|hooks\.json$|-extension\.(json|yaml|yml)$|\.mcp\.json$|gemini-extension\.json$|claude-extension\.json$) ]]; then
  SCHEMA_BOUND="⚠️  SCHEMA-BOUND new file. Before writing: WebFetch the official spec for this surface (not training-cached recall). State the source URL in your reasoning. Wrong schema = silent install failure later. "
fi

# Skip docs / lockfiles / git config — pure low-risk edits
[[ "$FILE" =~ \.(md|txt|lock|gitignore)$ ]] && [ -z "$SCHEMA_BOUND" ] && exit 0
[[ "$FILE" =~ (README|CHANGELOG|LICENSE)$ ]] && [ -z "$SCHEMA_BOUND" ] && exit 0

# Skip routine config/data edits (existing settings.json updates, package.json,
# Cargo.toml, pyproject.toml etc.) when not schema-bound new file.
if [ -z "$SCHEMA_BOUND" ] && [[ "$FILE" =~ \.(yml|yaml|toml)$ || "$FILE" =~ /(settings|package|tsconfig)\.json$ ]]; then
  exit 0
fi

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
    'additionalContext': '${SCHEMA_BOUND}${HIGH_RISK}GATE CHECK before edit: Q1(>1 file?) Q2(run tests?) Q3(design judgment?) Q4(>3 tool calls?) — any yes → delegate via Agent. GitNexus_impact run on target symbol? Reviewer (qa-tester floor) planned? Skipping any → state reason explicitly. flow-state ≠ gate skip.'
  }
}))
" 2>/dev/null || echo '{}'

exit 0
