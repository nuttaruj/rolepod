#!/usr/bin/env bash
# rolepod / Gemini AfterTool hook — targeted verify-after evidence reminder.
#
# Parses stdin (tool_name + tool_response.error) to escalate when a tool
# actually errored and to skip read-only tools.
#
# Contract: stdout = single JSON, stderr for debug, exit 0 on success.
# Reference: https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/reference.md

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

read TOOL ERROR FILE <<< "$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    tool = d.get("tool_name", "") or ""
    resp = d.get("tool_response", {}) or {}
    err = resp.get("error", "") or ""
    fp = (d.get("tool_input", {}) or {}).get("file_path", "") or ""
    # Collapse error to single token: "1" if non-empty, "0" otherwise (avoid
    # shell-quoting hassle when error contains newlines/spaces).
    err_flag = "1" if err else "0"
    print(f"{tool} {err_flag} {fp}")
except Exception:
    print("  0 ")
' 2>/dev/null || echo "  0 ")"

# Skip read-only tools.
case "$TOOL" in
  read_file|glob|list_directory|search_file_content) exit 0 ;;
esac

if [ "$ERROR" = "1" ]; then
  MSG=$'⚠️ Tool errored. Investigate root cause BEFORE next step. '
  MSG+=$'debug-issue: reproduce → trace upstream → fix root, not symptom. '
  MSG+=$'Don\'t paper over with workaround. State error + risk explicitly.'
  if [ -n "$FILE" ]; then
    MSG+=$'\n\nFailed target: '"$FILE"
  fi
else
  MSG=$'rolepod verify-after: every change needs evidence — test output / curl / screenshot / log. '
  MSG+=$'No evidence = state risk explicitly. Pre-commit gate: S1-S5 simplicity + T1-T6 tests + F1-F6 failure-mode.'
  if [ -n "$FILE" ]; then
    MSG+=$'\n\nChanged: '"$FILE"
  fi
fi

python3 -c 'import json,sys; print(json.dumps({"systemMessage": sys.stdin.read()}))' <<EOF
$MSG
EOF
