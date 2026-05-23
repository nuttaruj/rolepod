#!/bin/bash
# Cursor preToolUse(Write|Edit|MultiEdit) — soft warn on schema-bound + high-risk
# paths; hard-block when high-risk diff drift accumulates without test edits or
# reviewer dispatch this session. Mirrors the Claude version's tiering, adapted
# for Cursor's I/O contract (stdin JSON, stdout JSON, exit code).
#
# Output keys (Cursor preToolUse):
#   permission: "allow" | "deny"   — required when blocking
#   user_message: str              — shown to user; reason for deny
#   agent_message: str             — visible to the agent; soft reminder
#
# Env overrides match the Claude script for cross-CLI parity:
#   ROLEPOD_GATES_SOFT=1   — degrade ALL hard blocks back to warnings
#   ROLEPOD_GATES_PASSED=1 — single-session bypass
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

echo "$TOOL" | grep -qE '^(Write|Edit|MultiEdit)$' || exit 0

FILE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin).get('tool_input', {}) or {}
    print(d.get('file_path', '') or d.get('path', '') or d.get('target_file', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

SCHEMA_BOUND=""
if [ ! -e "$FILE" ] && [[ "$FILE" =~ (\.claude-plugin/|\.codex-plugin/|\.cursor-plugin/|/extensions/|marketplace\.json$|plugin\.json$|manifest\.json$|hooks\.json$|-extension\.(json|yaml|yml)$|\.mcp\.json$|gemini-extension\.json$|claude-extension\.json$) ]]; then
  SCHEMA_BOUND="⚠️  SCHEMA-BOUND new file. Before writing: WebFetch the official spec for this surface (not training-cached recall). State the source URL in your reasoning. Wrong schema = silent install failure later. "
fi

HIGH_RISK=""
if [[ "$FILE" =~ (/|^)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices)(/|\.|$|_) ]]; then
  HIGH_RISK="⚠️  HIGH-RISK path detected → mandatory: qa-tester + security-engineer review BEFORE commit. "
fi

if [ -z "$SCHEMA_BOUND" ] && [ -z "$HIGH_RISK" ]; then
  exit 0
fi

SOFT_MODE=0
[ "${ROLEPOD_GATES_SOFT:-0}" = "1" ] && SOFT_MODE=1
[ "${ROLEPOD_GATES_PASSED:-0}" = "1" ] && SOFT_MODE=1

# Cursor doesn't ship the session_state.py helper (it inspects Claude transcript
# format). Treat all sessions as 0-edit/0-reviewer baseline — soft warn only on
# the first high-risk touch; hard block only when schema-bound is missing too.
# A future Cursor-native session-state helper can re-introduce the harder block.
MSG="${SCHEMA_BOUND}${HIGH_RISK}"

if [ "$SOFT_MODE" -eq 0 ] && [ -n "$HIGH_RISK" ] && [ ! -e "$FILE" ]; then
  REASON="HARD BLOCK: editing high-risk new file '$FILE' without prior verification. Spawn qa-tester (and security-engineer for auth/billing/crypto/secret paths) BEFORE writing. Bypass: ROLEPOD_GATES_PASSED=1."
  python3 -c "
import json
print(json.dumps({'permission':'deny','user_message':'''$REASON'''}))
" 2>/dev/null || echo '{}'
  exit 2
fi

python3 -c "
import json
print(json.dumps({'permission':'allow','agent_message':'''$MSG'''}))
" 2>/dev/null || echo '{}'

exit 0
