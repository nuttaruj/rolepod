#!/usr/bin/env bash
# rolepod / Gemini BeforeTool hook — verify-first reminder for write/replace/edit.
#
# Contract: stdout = single JSON, stderr for debug, exit 0 on success.
# Reference: https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/reference.md

set -euo pipefail

MSG=$'rolepod verify-first: Read or git-diff the file before claiming what it contains. '
MSG+=$'Memory + pattern-match are unreliable. '
MSG+=$'GATE CHECK: Q1(>1 file?) Q2(run tests?) Q3(design judgment?) Q4(>3 tool calls?) — any yes → delegate. '
MSG+=$'Reviewer (qa-tester floor) planned? Skipping any → state reason. flow-state ≠ gate skip. '
MSG+=$'For high-risk surface (auth/billing/migrations/locks), /careful first.'

python3 -c 'import json,sys; print(json.dumps({"systemMessage": sys.stdin.read()}))' <<EOF
$MSG
EOF
