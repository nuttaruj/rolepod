#!/usr/bin/env bash
# rolepod / Gemini AfterTool hook — verify-after evidence reminder.
#
# Contract: stdout = single JSON, stderr for debug, exit 0 on success.
# Reference: https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/reference.md

set -euo pipefail

MSG=$'rolepod verify-after: every change needs evidence — test output / curl / screenshot / log. '
MSG+=$'No evidence = state risk explicitly. Pre-commit gate: S1-S5 simplicity + T1-T6 tests + F1-F6 failure-mode.'

python3 -c 'import json,sys; print(json.dumps({"systemMessage": sys.stdin.read()}))' <<EOF
$MSG
EOF
