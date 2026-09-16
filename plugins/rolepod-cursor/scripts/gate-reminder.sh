#!/bin/bash
# Cursor gate-reminder — registered twice on the same tools (Write|Edit|MultiEdit):
#
#   preToolUse  → the deny path only: a high-risk NEW file without prior
#                 verification is blocked ({"permission":"deny", user_message,
#                 agent_message} + exit 2). Everything else: no output (allow).
#   postToolUse → the soft reminders (schema-bound file written / high-risk
#                 path edited) as {"additional_context": "..."}.
#
# Why split: Cursor feeds `agent_message` to the model only when the action is
# denied — on `permission: allow` it is dropped, and `additional_context` is not
# a preToolUse output field (sessionStart / postToolUse only). Live-verified on
# agent CLI 2026.09.10 / IDE 3.20.21 (2026-09-16). Mirrors the Claude version's
# tiering, adapted to Cursor's I/O contract (stdin JSON, stdout JSON, exit code).
#
# Env overrides match the Claude script for cross-CLI parity:
#   ROLEPOD_GATES_SOFT=1   — degrade the hard block back to a reminder (logged)
#   ROLEPOD_GATES_PASSED=1 — single-session bypass
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bypass accountability: a used bypass is recorded to .rolepod/evidence/bypass.log
# (reason via ROLEPOD_BYPASS_REASON), never blocked. Fail-open on any error.
rolepod_log_bypass() {
  _rlb_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  [ -n "$_rlb_root" ] || return 0
  mkdir -p "$_rlb_root/.rolepod/evidence" 2>/dev/null || return 0
  _rlb_reason="${ROLEPOD_BYPASS_REASON:-unreasoned}"
  _rlb_reason="${_rlb_reason//\"/ }"
  printf '{"ts":"%s","hook":"%s","var":"%s","reason":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$_rlb_reason" \
    >> "$_rlb_root/.rolepod/evidence/bypass.log" 2>/dev/null || true
}

INPUT=$(cat 2>/dev/null || echo '{}')
IFS=$'\t' read -r EVENT TOOL WS CONV <<< "$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
roots = d.get('workspace_roots') or []
print('\t'.join([d.get('hook_event_name', 'preToolUse') or 'preToolUse', d.get('tool_name', '') or '-', roots[0] if roots else '', d.get('conversation_id') or d.get('session_id') or '']))
" 2>/dev/null || printf 'preToolUse\t-\t\t')"

echo "$TOOL" | grep -qE '^(Write|Edit|MultiEdit)$' || exit 0

FILE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin).get('tool_input', {}) or {}
    print(d.get('file_path', '') or d.get('path', '') or d.get('target_file', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
[ -n "$FILE" ] || exit 0
BASE="${FILE##*/}"

# Edit ledger (v2.134.0): after the edit landed, record it for the commit gate.
if [ "$EVENT" = "postToolUse" ] && [ -f "$HERE/shared/edit-ledger.py" ]; then
  python3 -I "$HERE/shared/edit-ledger.py" append cursor "$FILE" --cwd "${WS:-$PWD}" --agent "" >/dev/null 2>&1 || true
fi

SCHEMA_RX='(\.claude-plugin/|\.codex-plugin/|\.cursor-plugin/|/extensions/|marketplace\.json$|plugin\.json$|manifest\.json$|hooks\.json$|-extension\.(json|yaml|yml)$|\.mcp\.json$|gemini-extension\.json$|claude-extension\.json$)'
RISK_RX='(^|/|_)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices|deletion|deletions|erasure|gdpr|security)(/|\.|_|$)'

SCHEMA_BOUND=0; HIGH_RISK=0
[[ "$FILE" =~ $SCHEMA_RX ]] && SCHEMA_BOUND=1
[[ "$FILE" =~ $RISK_RX ]] && HIGH_RISK=1
[ "$SCHEMA_BOUND" -eq 1 ] || [ "$HIGH_RISK" -eq 1 ] || exit 0

emit() {  # $1 = JSON object built from env ROLEPOD_HOOK_MSG by the python line in $2
  ROLEPOD_HOOK_MSG="$1" python3 -c "$2" 2>/dev/null || echo '{}'
}

if [ "$EVENT" = "preToolUse" ]; then
  # Deny path only: a high-risk NEW file without prior verification.
  [ "$HIGH_RISK" -eq 1 ] && [ ! -e "$FILE" ] || exit 0
  SOFT_MODE=0
  [ "${ROLEPOD_GATES_SOFT:-0}" = "1" ] && { SOFT_MODE=1; rolepod_log_bypass "gate-reminder" "ROLEPOD_GATES_SOFT"; }
  [ "${ROLEPOD_GATES_PASSED:-0}" = "1" ] && SOFT_MODE=1
  [ "$SOFT_MODE" -eq 0 ] || exit 0
  REASON="HARD BLOCK: high-risk new file $BASE without prior verification. Fix: spawn qa-tester (and security-engineer for auth/billing/crypto/secret paths) BEFORE writing. Exception: ROLEPOD_GATES_PASSED=1."
  emit "$REASON" "
import json, os
m = os.environ.get('ROLEPOD_HOOK_MSG', '')
print(json.dumps({'permission': 'deny', 'user_message': m, 'agent_message': m}))
"
  exit 2
fi

# postToolUse: the soft reminders, delivered where Cursor lets them reach the model.
MSG=""
[ "$SCHEMA_BOUND" -eq 1 ] && MSG="SCHEMA-BOUND file written: $BASE. Fix: verify it against the official spec (WebFetch, not recall) and name the source URL before moving on; a wrong schema fails silently at install. "
[ "$HIGH_RISK" -eq 1 ] && MSG="${MSG}HIGH-RISK path edited: $BASE. Fix: qa-tester + security-engineer review before commit."
emit "${MSG% }" "
import json, os
print(json.dumps({'additional_context': os.environ.get('ROLEPOD_HOOK_MSG', '')}))
"
exit 0
