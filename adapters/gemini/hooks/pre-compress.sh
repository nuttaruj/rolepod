#!/usr/bin/env bash
# rolepod / Gemini PreCompress hook — preserve open-gate state across history
# summarization.
#
# Gemini fires PreCompress before auto/manual `/compress`. Without a reminder,
# Lead may lose track of: active task, gates still open (S/T/F), reviewer
# dispatches still pending, /careful mode status. Injecting these as
# additionalContext makes them survive the summary step.
#
# Contract: stdout = single JSON, stderr for debug, exit 0 on success.
# Reference: https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/reference.md

set -euo pipefail

MSG=$'rolepod pre-compress checkpoint. Carry these forward across summary:\n'
MSG+=$'- Active task + acceptance criteria (don\'t lose scope).\n'
MSG+=$'- Open gates: S1-S5 (simplicity), T1-T6 (tests), F1-F6 (failure-mode).\n'
MSG+=$'- Reviewer dispatches still pending (qa-tester floor + Codex/Gemini if available).\n'
MSG+=$'- /careful mode status (high-risk surface in flight?).\n'
MSG+=$'- mempalace_kg_add for architectural decisions made this session.\n'
MSG+=$'After summary: state which gates remain open + next concrete action.'

ESCAPED="$(printf '%s' "$MSG" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
printf '{"hookSpecificOutput": {"hookEventName": "PreCompress", "additionalContext": %s}}\n' "$ESCAPED"
