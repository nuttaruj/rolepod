#!/bin/bash
# PreToolUse(Edit|Write|MultiEdit) — inject gate reminder + (when warranted)
# HARD-block edits that violate the discipline rules.
#
# Default tiering (sub-agent calls and high-risk edits get progressively
# stricter; ad-hoc Lead exploration stays unimpeded):
#
#   Trivial path (docs/configs/lockfiles)
#                                  → silent pass
#   Schema-bound NEW file          → soft warn (verify official spec FIRST)
#   Normal code edit               → soft warn (Q1-Q4 + reviewer + flow-state)
#   High-risk path, 1st code edit  → soft warn + auto-Careful banner
#   High-risk path, 2nd+ code edit, 0 test edits in session
#                                  → HARD block (Fix 5: RED-test discipline)
#   High-risk path edit, 0 reviewer agents dispatched in session
#                                  → HARD block (Fix 3: reviewer floor)
#                                    [opt-out: ROLEPOD_GATES_SOFT=1 env]
#
# Bypass for legit one-off cases:
#   ROLEPOD_GATES_SOFT=1   — degrade ALL hard blocks back to warnings
#   ROLEPOD_GATES_PASSED=1 — single-session bypass (clear before commit)
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

# Match Edit / Write / MultiEdit / NotebookEdit
echo "$TOOL" | grep -qE '^(Edit|Write|MultiEdit|NotebookEdit)$' || exit 0

FILE=$(echo "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin).get('tool_input',{});print(d.get('file_path','') or d.get('notebook_path',''))" 2>/dev/null || echo "")

# Schema-bound NEW file detection — emit STRONG verify-doc reminder FIRST.
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

# High-risk path flag. Tight pattern — match on path segments only, not
# substrings inside arbitrary identifiers. (Earlier looser pattern matched
# things like `session_state.py` for the hooks helper.)
HIGH_RISK=""
if [[ "$FILE" =~ (/|^)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices)(/|\.|$|_) ]]; then
  HIGH_RISK="⚠️  HIGH-RISK path detected → mandatory: qa-tester + security-engineer review BEFORE commit. "
fi

# Session-state inspection (Fixes 3 / 4 / 5).
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

# Bypass: explicit env flag downgrades all hard blocks to warnings.
SOFT_MODE=0
[ "${ROLEPOD_GATES_SOFT:-0}" = "1" ] && SOFT_MODE=1
[ "${ROLEPOD_GATES_PASSED:-0}" = "1" ] && SOFT_MODE=1

# Decide whether to HARD block. Only fires on high-risk path AND when
# discipline metrics show drift — never on neutral edits.
BLOCK_REASON=""
if [ -n "$HIGH_RISK" ] && [ "$SOFT_MODE" -eq 0 ]; then
  # Fix 5: RED-test discipline — 2nd+ high-risk code edit without a test
  # edit anywhere in the session = TDD bypass.
  if [ "$HIGH_RISK_EDITS" -ge 1 ] && [ "$TEST_EDITS" -eq 0 ]; then
    BLOCK_REASON="HARD BLOCK: editing high-risk path '$FILE' but session has 0 test edits. Write a failing test FIRST (RED), then implement. Session: $HIGH_RISK_EDITS high-risk edits / $TEST_EDITS tests / $REVIEWERS reviewers. Bypass for one edit: ROLEPOD_GATES_PASSED=1 (clears once you commit)."
  # Fix 3: reviewer floor — high-risk path edits without any
  # qa-tester / security-engineer / universal-reviewer dispatch yet.
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

# Fix 4: auto-Careful banner — on high-risk paths inject stronger gate
# wording even when not blocking, so Lead can't shrug it off as advisory.
CAREFUL_BANNER=""
if [ -n "$HIGH_RISK" ]; then
  CAREFUL_BANNER="⚠️  AUTO-CAREFUL MODE (high-risk path, session: $HIGH_RISK_EDITS high-risk edits / $TEST_EDITS tests / $REVIEWERS reviewers). MANDATORY before more edits: (1) test file exists or is being written this session, (2) qa-tester dispatched (security-engineer for auth/billing/crypto), (3) S1-S5 + T1-T6 checklist run before commit. Soft-mode opt-out: ROLEPOD_GATES_SOFT=1. "
fi

# Emit reminder as additionalContext
python3 -c "
import json
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'additionalContext': '${SCHEMA_BOUND}${CAREFUL_BANNER}${HIGH_RISK}GATE CHECK before edit: Q1(>1 file?) Q2(run tests?) Q3(design judgment?) Q4(>3 tool calls?) — any yes → delegate via Agent. GitNexus_impact run on target symbol? Reviewer (qa-tester floor) planned? Skipping any → state reason explicitly. flow-state ≠ gate skip.'
  }
}))
" 2>/dev/null || echo '{}'

exit 0
