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
#   High-risk path                                    → auto-Careful banner, and when
#     the evidence window (since last commit, Lead + subagent transcripts)
#     shows 0 test edits / 0 strong reviewers, the banner NAMES what the
#     commit gate will require. Never a deny (v2.47.0): edit-time HARD
#     blocks were the measured reason users set ROLEPOD_GATES_SOFT for
#     good (CourtBook: 33 high-risk edits in one day, 116 unreasoned
#     bypasses) — which then silenced the commit gate too. One hard
#     checkpoint, at commit (precommit-gate.sh); this hook informs.
#
# Bypass envs (user-set only):
#   ROLEPOD_GATES_SOFT=1   — silence the would-block wording (banner stays)
set -euo pipefail

# Per-repo risk-path override: <git-root>/.rolepod/risk-paths — one ERE per
# line; bare/+ lines ADD high-risk patterns, - lines EXCLUDE paths from the
# built-in match, # comments. Absent file = built-ins only (fail-open).
# stdin: candidate paths (one per line); $1: built-in ERE → stdout: hits.
risk_filter() {
  _rf_cfg="$(git rev-parse --show-toplevel 2>/dev/null)/.rolepod/risk-paths"
  _rf_add=""; _rf_excl=""
  if [ -f "$_rf_cfg" ]; then
    _rf_add=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e '/^-/d' -e 's/^+//' "$_rf_cfg" 2>/dev/null | paste -sd'|' - 2>/dev/null || true)
    _rf_excl=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$_rf_cfg" 2>/dev/null | grep '^-' 2>/dev/null | sed 's/^-//' | paste -sd'|' - 2>/dev/null || true)
  fi
  _rf_in=$(cat)
  _rf_hits=$(printf '%s\n' "$_rf_in" | grep -iE "$1" 2>/dev/null || true)
  if [ -n "$_rf_add" ]; then
    _rf_hits="$_rf_hits
$(printf '%s\n' "$_rf_in" | grep -iE "$_rf_add" 2>/dev/null || true)"
  fi
  _rf_hits=$(printf '%s\n' "$_rf_hits" | sed '/^$/d' | sort -u)
  if [ -n "$_rf_excl" ]; then
    _rf_hits=$(printf '%s\n' "$_rf_hits" | grep -ivE "$_rf_excl" 2>/dev/null || true)
  fi
  printf '%s\n' "$_rf_hits" | sed '/^$/d'
}

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

# ONE python3 pass for tool_name + file path (was 2 spawns — ~16ms on
# every edit). tool first via read -r; path LAST, slurped with $(cat) so
# an empty trailing field cannot EOF-fail the read under set -e.
# file_path (Claude tools) → notebook_path → path → apply_patch body markers
# (Codex patches carry "*** Add/Update/Delete File: <path>" lines, no field).
PARSED=$(printf '%s' "$INPUT" | python3 -c "
import json, re, sys
tool = ''
p = ''
try:
    d = json.load(sys.stdin)
    tool = d.get('tool_name', '') or ''
    ti = d.get('tool_input', {}) or {}
    p = ti.get('file_path', '') or ti.get('notebook_path', '') or ti.get('path', '') or ''
    if not p:
        body = ti.get('input', '') or ti.get('patch', '') or ''
        m = re.search(r'\*\*\* (?:Add|Update|Delete) File: (.+)', body)
        p = m.group(1).strip() if m else ''
except Exception:
    pass
print(tool)
print(p)
" 2>/dev/null) || exit 0
{ read -r TOOL; FILE=$(cat); } <<EOF
$PARSED
EOF

# Claude edit tools + Codex's apply_patch (the Codex adapter registers this
# same script on matcher "apply_patch" — without it here the hook is inert
# on Codex: disjoint tool-name sets).
echo "$TOOL" | grep -qE '^(Edit|Write|MultiEdit|NotebookEdit|apply_patch)$' || exit 0

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
# Canonical high-risk regex — byte-for-byte the same segment/anchor set as
# precommit-gate.sh:78 and session_state.py's HIGH_RISK_PATH, so a file cannot
# pass at edit time and then block at commit time.
_RISK_HIT=$(printf '%s\n' "$FILE" | risk_filter '(^|/|_)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices|deletion|deletions|erasure|gdpr|security)(/|\.|_|$)' | head -1 || true)
MONEY_RISK=""
if [ "$IS_TEST" -eq 0 ] && [ -n "$_RISK_HIT" ]; then
  HIGH_RISK="⚠️  HIGH-RISK path detected → mandatory: qa-tester + security-engineer review BEFORE commit. "
  # money / auth subset (v2.78.0) — with an enabled cross-family pool this
  # surface needs BOTH the external pass and the internal strong reviewer.
  MONEY_RISK=$(printf '%s\n' "$FILE" | grep -iE '(^|/|_)(auth|authn|authz|authentication|authorization|billing|payment|payments|credit|credits|secret|secrets|crypto|cryptography|oauth|jwt|sso|saml|stripe|paypal|charge|charges|invoice|invoices|deletion|deletions|erasure|gdpr)(/|\.|_|$)' | head -1 || true)
fi

# Silent pass when nothing is risky. Normal code / docs / config edits
# never see a reminder from this hook — the Q1-Q4 doctrine lives in
# CLAUDE.md / AGENTS.md and using-rolepod skill, read once per session.
if [ -z "$SCHEMA_BOUND" ] && [ -z "$HIGH_RISK" ]; then
  exit 0
fi

# Session-state inspection (Careful banner + would-block wording). Same
# window as precommit-gate: since the last commit, Lead + subagent transcripts.
SESSION_STATE="$(dirname "$0")/lib/session_state.py"
TEST_EDITS=0
HIGH_RISK_EDITS=0
REVIEWERS=0
STRONG_REVIEWERS=0
SINCE_EPOCH=$(git log -1 --format=%ct 2>/dev/null || true)
if [ -f "$SESSION_STATE" ] && command -v python3 >/dev/null 2>&1; then
  # ONE transcript scan for all four counts — separate calls each re-read
  # the whole transcript and blew the hook timeout on long sessions.
  COUNTS=$(printf '%s' "$INPUT" | python3 "$SESSION_STATE" count-all "$SINCE_EPOCH" 2>/dev/null || echo "0 0 0 0")
  read -r TEST_EDITS HIGH_RISK_EDITS REVIEWERS STRONG_REVIEWERS <<< "$COUNTS"
fi
TEST_EDITS=${TEST_EDITS:-0}
HIGH_RISK_EDITS=${HIGH_RISK_EDITS:-0}
REVIEWERS=${REVIEWERS:-0}
STRONG_REVIEWERS=${STRONG_REVIEWERS:-0}

SOFT_MODE=0
[ "${ROLEPOD_GATES_SOFT:-0}" = "1" ] && { SOFT_MODE=1; rolepod_log_bypass "gate-reminder" "ROLEPOD_GATES_SOFT"; }

# Would-block wording — what precommit-gate WILL require for this path. Warn
# only, never deny (see header). SOFT silences the wording, not the banner.
WOULD_BLOCK=""
if [ -n "$HIGH_RISK" ] && [ "$SOFT_MODE" -eq 0 ]; then
  if [ "$TEST_EDITS" -eq 0 ]; then
    WOULD_BLOCK+="⛔ COMMIT WILL BLOCK — 0 test edits since the last commit while editing high-risk path '$FILE'. Write the failing test FIRST (RED), then implement. "
  fi
  if [ "$HIGH_RISK_EDITS" -ge 1 ] && [ "$STRONG_REVIEWERS" -eq 0 ]; then
    WOULD_BLOCK+="⛔ COMMIT WILL BLOCK — high-risk edits since the last commit with no strong adversarial reviewer. Satellite-first: run the cross-family runner (\`rolepod-cross-family --kind review --brief <file> --attach <diff>\`; it invokes the first usable different-family CLI read-only on its default model and anchors the pass under .rolepod/evidence/external/ + the reviewer:external phase-log line); while a usable pool exists an internal strong reviewer does NOT clear the commit — only after the runner reports every member failed (exit 3) or the pool is empty (exit 4) → dispatch rolepod:universal-reviewer or rolepod:security-engineer via the Agent tool (the dispatch hook runs them at strong class whatever the Lead is; qa-tester is the test floor, not the review). Reviewer dispatch impossible (user forbade agents / no subagent support)? SURFACE that conflict to the user — fallback: Lead cold self-review recorded as a LIMITATION. Bypass envs are user-set only — never set one yourself. "
  fi
fi

# auto-Careful banner — every high-risk edit (would-block wording prepended). External
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
  # v2.76.0: the cross-family runner owns pool detection (config file +
  # installed + Lead-family exclusion). Its --pool-names output IS the list;
  # the pre-runner detection below is the fallback when the runner is absent.
  XFAM_RUNNER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/cross-family.sh"
  [ -f "$XFAM_RUNNER" ] || XFAM_RUNNER="$HOME/.rolepod/bin/cross-family.sh"
  XFAM_POOL=""
  if [ -f "$XFAM_RUNNER" ]; then
    XFAM_POOL=$(bash "$XFAM_RUNNER" --lead "${SELF_CLI:-claude}" --pool-names 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
    if [ -n "$XFAM_POOL" ]; then
      REVIEWER_LIST="$REVIEWER_LIST + cross-family runner → $XFAM_POOL (\`rolepod-cross-family --kind review --brief <file> --attach <diff>\` — one command: default model, read-only, anchored)"
      [ -n "$MONEY_RISK" ] && REVIEWER_LIST="$REVIEWER_LIST + rolepod:security-engineer — money / auth surface needs BOTH passes (external + internal strong, same dispatch)"
    else
      REVIEWER_LIST="$REVIEWER_LIST + rolepod:universal-reviewer / rolepod:security-engineer (cross-family is opt-in and not enabled here — \`rolepod-cross-family --pool\` shows candidates; ask the user before enabling)"
    fi
  else
    [ "$SELF_CLI" != "codex" ]  && command -v codex  >/dev/null 2>&1 && REVIEWER_LIST="$REVIEWER_LIST + Codex (\`codex exec\`, depth/security)"
    [ "$SELF_CLI" != "claude" ] && command -v claude >/dev/null 2>&1 && REVIEWER_LIST="$REVIEWER_LIST + Claude (\`claude -p\`, architecture/quality)"
    if [ "$SELF_CLI" != "gemini" ] && [ "$SELF_CLI" != "antigravity" ] && command -v agy >/dev/null 2>&1; then
      REVIEWER_LIST="$REVIEWER_LIST + Antigravity (\`agy -p\`, breadth/cross-file — Google family)"
    fi
  fi
  CAREFUL_BANNER="${WOULD_BLOCK}⚠️  AUTO-CAREFUL MODE (high-risk path; since last commit: $HIGH_RISK_EDITS high-risk edits / $TEST_EDITS tests / $REVIEWERS reviewers, $STRONG_REVIEWERS strong). MANDATORY before commit: (1) test file exists or is being written this session, (2) reviewers dispatched — use ≥2 when available (${REVIEWER_LIST}; security-engineer for auth/billing/crypto). Exclude this session's own CLI — the adversarial pass runs on a DIFFERENT model (gemini and agy are the same model family). (3) S1-S5 + T1-T6 checklist (finish-work §1) run before commit. Reviewer path blocked by a user instruction? Surface it — fallback: Lead cold self-review + limitation note. Bypass envs are user-set only, never model-set. "
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
