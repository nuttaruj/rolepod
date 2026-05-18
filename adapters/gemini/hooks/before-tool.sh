#!/usr/bin/env bash
# rolepod / Gemini BeforeTool hook — targeted verify-first reminder.
#
# Parses stdin (tool_name + tool_input.file_path) to skip read-only tools
# and tailor reminder to the actual file being edited. High-risk paths
# (auth/billing/migrations/etc.) get a stronger /rolepod nudge.
#
# Contract: stdout = single JSON, stderr for debug, exit 0 on success.
# Reference: https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/reference.md

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

# Pull tool_name + file_path from stdin. write_file / replace / edit each pass
# a file_path under tool_input; fall back to empty if shape differs.
read TOOL FILE <<< "$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    tool = d.get("tool_name", "") or ""
    fp = (d.get("tool_input", {}) or {}).get("file_path", "") or ""
    print(f"{tool} {fp}")
except Exception:
    print(" ")
' 2>/dev/null || echo " ")"

# Skip read-only tools (matcher in hooks.json should already filter, but
# Gemini regex matching is fuzzy — defense in depth).
case "$TOOL" in
  read_file|glob|list_directory|search_file_content) exit 0 ;;
esac

# High-risk path detection — segment-anchored to avoid false positives
# (e.g. `session_state.py` shouldn't match `session`).
HIGH_RISK=0
if printf '%s' "$FILE" | grep -qE '(^|/|_|\.)(auth|authn|authz|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices)(/|\.|_|$)'; then
  HIGH_RISK=1
fi

MSG=$'rolepod verify-first: Read or git-diff the file before claiming what it contains. '
MSG+=$'Memory + pattern-match are unreliable. '
MSG+=$'GATE CHECK: Q1(>1 file?) Q2(run tests?) Q3(design judgment?) Q4(>3 tool calls?) — any yes → delegate. '
MSG+=$'Reviewer (qa-tester floor) planned? Skipping any → state reason. flow-state ≠ gate skip.'

if [ -n "$FILE" ]; then
  MSG+=$'\n\nTarget: '"$FILE"
fi

if [ "$HIGH_RISK" -eq 1 ]; then
  MSG+=$'\n\n⚠️ HIGH-RISK PATH DETECTED. Run /rolepod BEFORE the edit. Dispatch ≥2 reviewers (qa-tester + Codex/Gemini/security-engineer) before commit.'
fi

python3 -c 'import json,sys; print(json.dumps({"systemMessage": sys.stdin.read()}))' <<EOF
$MSG
EOF
