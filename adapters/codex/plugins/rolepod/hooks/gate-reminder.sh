#!/bin/bash
# PreToolUse(Edit|Write|MultiEdit) — HARD-block edits that violate
# discipline rules + soft-warn on schema-bound new files + high-risk path
# edits. Normal code edits are silent (Q1-Q4 reminder moved out — it
# lives in CLAUDE.md / AGENTS.md / using-rolepod skill where Lead reads
# it once per session, not per-edit).
#
# Default tiering:
#   Trivial path (docs/configs/lockfiles)             → silent
#   Schema-bound NEW file                             → soft warn (WebFetch spec FIRST)
#   Normal code edit                                  → silent
#   High-risk path, 1st edit                          → soft warn + auto-Careful banner
#   High-risk path, 2nd+ edit, 0 test edits           → HARD block (RED-test discipline)
#   High-risk path, ≥ 2 edits, 0 reviewers dispatched → HARD block (reviewer floor)
#
# Bypass for one-off legit cases:
#   ROLEPOD_GATES_SOFT=1   — degrade ALL hard blocks back to warnings
#   ROLEPOD_GATES_PASSED=1 — single-session bypass (clear before commit)
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

echo "$TOOL" | grep -qE '^(Edit|Write|MultiEdit|NotebookEdit)$' || exit 0

FILE=$(echo "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin).get('tool_input',{});print(d.get('file_path','') or d.get('notebook_path',''))" 2>/dev/null || echo "")

# Schema-bound NEW file → emit STRONG verify-doc reminder.
SCHEMA_BOUND=""
if [ ! -e "$FILE" ] && [[ "$FILE" =~ (\.claude-plugin/|\.codex-plugin/|/extensions/|marketplace\.json$|plugin\.json$|manifest\.json$|hooks\.json$|-extension\.(json|yaml|yml)$|\.mcp\.json$|gemini-extension\.json$|claude-extension\.json$) ]]; then
  SCHEMA_BOUND="⚠️  SCHEMA-BOUND new file. Before writing: WebFetch the official spec for this surface (not training-cached recall). State the source URL in your reasoning. Wrong schema = silent install failure later. "
fi

# High-risk path flag — match on path segments only, not substrings.
HIGH_RISK=""
if [[ "$FILE" =~ (/|^)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices)(/|\.|$|_) ]]; then
  HIGH_RISK="⚠️  HIGH-RISK path detected → mandatory: qa-tester + security-engineer review BEFORE commit. "
fi

# Silent pass when nothing is risky. Normal code / docs / config edits
# never see a reminder from this hook — the Q1-Q4 doctrine lives in
# CLAUDE.md / AGENTS.md and using-rolepod skill, read once per session.
if [ -z "$SCHEMA_BOUND" ] && [ -z "$HIGH_RISK" ]; then
  exit 0
fi

# Session-state inspection (used by hard-block + Careful banner).
SESSION_STATE="$(dirname "$0")/lib/session_state.py"
TEST_EDITS=0
HIGH_RISK_EDITS=0
REVIEWERS=0
if [ -f "$SESSION_STATE" ] && command -v python3 >/dev/null 2>&1; then
  TEST_EDITS=$(printf '%s' "$INPUT" | python3 "$SESSION_STATE" count-test-edits 2>/dev/null || echo 0)
  HIGH_RISK_EDITS=$(printf '%s' "$INPUT" | python3 "$SESSION_STATE" count-high-risk-edits 2>/dev/null || echo 0)
  REVIEWERS=$(printf '%s' "$INPUT" | python3 "$SESSION_STATE" count-reviewers-dispatched 2>/dev/null || echo 0)
fi
TEST_EDITS=${TEST_EDITS:-0}
HIGH_RISK_EDITS=${HIGH_RISK_EDITS:-0}
REVIEWERS=${REVIEWERS:-0}

SOFT_MODE=0
[ "${ROLEPOD_GATES_SOFT:-0}" = "1" ] && SOFT_MODE=1
[ "${ROLEPOD_GATES_PASSED:-0}" = "1" ] && SOFT_MODE=1

# Decide whether to HARD block. Only fires on high-risk path + discipline drift.
BLOCK_REASON=""
if [ -n "$HIGH_RISK" ] && [ "$SOFT_MODE" -eq 0 ]; then
  if [ "$HIGH_RISK_EDITS" -ge 1 ] && [ "$TEST_EDITS" -eq 0 ]; then
    BLOCK_REASON="HARD BLOCK: editing high-risk path '$FILE' but session has 0 test edits. Write a failing test FIRST (RED), then implement. Session: $HIGH_RISK_EDITS high-risk edits / $TEST_EDITS tests / $REVIEWERS reviewers. Bypass for one edit: ROLEPOD_GATES_PASSED=1 (clears once you commit)."
  elif [ "$HIGH_RISK_EDITS" -ge 2 ] && [ "$REVIEWERS" -eq 0 ]; then
    BLOCK_REASON="HARD BLOCK: $HIGH_RISK_EDITS high-risk path edits this session, 0 reviewer agents dispatched. Spawn qa-tester (and security-engineer for auth/billing/crypto/secret paths) via the Agent tool BEFORE more edits. Bypass: ROLEPOD_GATES_SOFT=1."
  fi
fi

if [ -n "$BLOCK_REASON" ]; then
  python3 -c "
import json
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'permissionDecision': 'deny',
    'permissionDecisionReason': '''$BLOCK_REASON'''
  }
}))
" 2>/dev/null || echo '{}'
  exit 0
fi

# auto-Careful banner — high-risk path, no hard-block trigger. Adversarial
# reviewers (Codex / Gemini) added to recommended list when their CLI
# binaries are present.
CAREFUL_BANNER=""
if [ -n "$HIGH_RISK" ]; then
  HAS_CODEX_BIN=0; HAS_GEMINI_BIN=0
  command -v codex  >/dev/null 2>&1 && HAS_CODEX_BIN=1
  command -v gemini >/dev/null 2>&1 && HAS_GEMINI_BIN=1
  REVIEWER_LIST="qa-tester"
  [ "$HAS_CODEX_BIN" -eq 1 ] && REVIEWER_LIST="$REVIEWER_LIST + Codex (\`codex exec\`, depth/security)"
  [ "$HAS_GEMINI_BIN" -eq 1 ] && REVIEWER_LIST="$REVIEWER_LIST + Gemini (\`gemini -m pro -p\`, breadth/cross-file)"
  BOTH_RULE=""
  if [ "$HAS_CODEX_BIN" -eq 1 ] && [ "$HAS_GEMINI_BIN" -eq 1 ]; then
    BOTH_RULE=" Both Codex AND Gemini installed → use BOTH on high-risk (not Codex alone — that's the documented drift)."
  fi
  CAREFUL_BANNER="⚠️  AUTO-CAREFUL MODE (high-risk path, session: $HIGH_RISK_EDITS high-risk edits / $TEST_EDITS tests / $REVIEWERS reviewers). MANDATORY before more edits: (1) test file exists or is being written this session, (2) reviewers dispatched — use ≥2 when available (${REVIEWER_LIST}; security-engineer for auth/billing/crypto).${BOTH_RULE} (3) S1-S5 + T1-T6 checklist run before commit. Soft-mode opt-out: ROLEPOD_GATES_SOFT=1. "
fi

# Emit reminder ONLY when schema-bound or high-risk — no generic Q1-Q4 nag.
python3 -c "
import json
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'additionalContext': '${SCHEMA_BOUND}${CAREFUL_BANNER}${HIGH_RISK}'
  }
}))
" 2>/dev/null || echo '{}'

exit 0
