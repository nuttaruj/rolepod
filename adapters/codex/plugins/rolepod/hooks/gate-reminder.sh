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

# Claude edit tools + Codex's apply_patch (the Codex adapter registers this
# same script on matcher "apply_patch" — without it here the hook is inert
# on Codex: disjoint tool-name sets).
echo "$TOOL" | grep -qE '^(Edit|Write|MultiEdit|NotebookEdit|apply_patch)$' || exit 0

# file_path (Claude tools) → notebook_path → path → apply_patch body markers
# (Codex patches carry "*** Add/Update/Delete File: <path>" lines, no field).
FILE=$(echo "$INPUT" | python3 -c "
import sys, json, re
d = json.load(sys.stdin).get('tool_input', {})
p = d.get('file_path', '') or d.get('notebook_path', '') or d.get('path', '')
if not p:
    body = d.get('input', '') or d.get('patch', '') or ''
    m = re.search(r'\*\*\* (?:Add|Update|Delete) File: (.+)', body)
    p = m.group(1).strip() if m else ''
print(p)
" 2>/dev/null || echo "")

# Schema-bound NEW file → emit STRONG verify-doc reminder.
SCHEMA_BOUND=""
if [ ! -e "$FILE" ] && [[ "$FILE" =~ (\.claude-plugin/|\.codex-plugin/|/extensions/|marketplace\.json$|plugin\.json$|manifest\.json$|hooks\.json$|-extension\.(json|yaml|yml)$|\.mcp\.json$|gemini-extension\.json$|claude-extension\.json$) ]]; then
  SCHEMA_BOUND="⚠️  SCHEMA-BOUND new file. Before writing: WebFetch the official spec for this surface (not training-cached recall). State the source URL in your reasoning. Wrong schema = silent install failure later. "
fi

# Test files are exempt: writing the RED test on a high-risk path is the very
# action the hard block demands, so flagging it would deadlock. Mirrors
# session_state.py's TEST_FILE exclusion.
IS_TEST=0
if [[ "$FILE" =~ (^|/)(test|tests|__tests__|spec|specs|e2e)(/|$) ]] \
   || [[ "$FILE" =~ \.(test|spec)\.(ts|tsx|js|jsx|py|go|rs|rb|java|kt|swift|cs|php)$ ]] \
   || [[ "$FILE" =~ (^|/)(test_|_test|.*_test)\.(py|go|rs)$ ]]; then
  IS_TEST=1
fi

# High-risk path flag — match on path segments only, not substrings.
HIGH_RISK=""
if [ "$IS_TEST" -eq 0 ] && [[ "$FILE" =~ (/|^)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices)(/|\.|$|_) ]]; then
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
  # Pass via env, NOT string interpolation — a quote in the reason must not
  # break the JSON emitter (silent-failure bug caught by hook-behavior.sh).
  ROLEPOD_HOOK_MSG="$BLOCK_REASON" python3 -c "
import json, os
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'permissionDecision': 'deny',
    'permissionDecisionReason': os.environ.get('ROLEPOD_HOOK_MSG', '')
  }
}))
" 2>/dev/null || echo '{}'
  exit 0
fi

# auto-Careful banner — high-risk path, no hard-block trigger. External
# adversarial reviewers listed Lead-relative: every installed CLI EXCEPT
# the one running this session (Iron Rule 2 — the adversarial pass runs on
# a model different from the Lead's). This same script ships on all CLIs,
# so it must never nudge a Lead toward its own model.
CAREFUL_BANNER=""
if [ -n "$HIGH_RISK" ]; then
  # Self-identification: ROLEPOD_LEAD_CLI (set by the adapter's hooks.json
  # command), else CLAUDE_PLUGIN_ROOT (Claude hook runtime). Unknown → list
  # all; the exclusion sentence carries the discipline. Do NOT sniff shell
  # env like CODEX_HOME — it leaks from the user's rc files.
  SELF_CLI="${ROLEPOD_LEAD_CLI:-}"
  [ -z "$SELF_CLI" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && SELF_CLI="claude"
  REVIEWER_LIST="qa-tester"
  [ "$SELF_CLI" != "codex" ]  && command -v codex  >/dev/null 2>&1 && REVIEWER_LIST="$REVIEWER_LIST + Codex (\`codex exec\`, depth/security)"
  [ "$SELF_CLI" != "claude" ] && command -v claude >/dev/null 2>&1 && REVIEWER_LIST="$REVIEWER_LIST + Claude (\`claude -p\`, architecture/quality)"
  if [ "$SELF_CLI" != "gemini" ] && [ "$SELF_CLI" != "antigravity" ]; then
    if command -v gemini >/dev/null 2>&1; then
      REVIEWER_LIST="$REVIEWER_LIST + Gemini (\`gemini -m pro -p\`, breadth/cross-file)"
    elif command -v agy >/dev/null 2>&1; then
      REVIEWER_LIST="$REVIEWER_LIST + Antigravity (\`agy -p\`, breadth/cross-file — Gemini family)"
    fi
  fi
  CAREFUL_BANNER="⚠️  AUTO-CAREFUL MODE (high-risk path, session: $HIGH_RISK_EDITS high-risk edits / $TEST_EDITS tests / $REVIEWERS reviewers). MANDATORY before more edits: (1) test file exists or is being written this session, (2) reviewers dispatched — use ≥2 when available (${REVIEWER_LIST}; security-engineer for auth/billing/crypto). Exclude this session's own CLI — the adversarial pass runs on a DIFFERENT model (gemini and agy are the same model family). (3) S1-S5 + T1-T6 checklist run before commit. Soft-mode opt-out: ROLEPOD_GATES_SOFT=1. "
fi

# Emit reminder ONLY when schema-bound or high-risk — no generic Q1-Q4 nag.
# Env-passed (see deny path) so apostrophes in the banner cannot break it.
ROLEPOD_HOOK_MSG="${SCHEMA_BOUND}${CAREFUL_BANNER}${HIGH_RISK}" python3 -c "
import json, os
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')
  }
}))
" 2>/dev/null || echo '{}'

exit 0
