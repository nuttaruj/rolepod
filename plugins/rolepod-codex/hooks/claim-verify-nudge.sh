#!/bin/bash
# UserPromptSubmit — soft nudge on the CLAIM/ANSWER path.
#
# Every other rolepod hook fires only on a tool call (PreToolUse Edit|Write|
# Bash|Agent) or a lifecycle event (SessionStart, Stop). A turn that answers an
# analysis / diagnosis / "how does X work" / "what's the gap" / status question
# in plain text is none of those, so it reaches the user with ZERO verification.
# That is the path where a confident-but-unverified claim ships wrong and the
# user has to correct it over several rounds.
#
# This hook injects ONE reminder — read a primary source + cite file:line before
# claiming — when the prompt looks like a claim-about-real-code/state request.
#
# Soft by construction: emits additionalContext only, NEVER blocks. A pure-text
# claim is structurally un-hookable to hard-enforce (no tool call to gate on),
# so the honest ceiling here is to raise the cost of guessing and prompt a
# read-first habit — not to make a wrong claim impossible.
#
# Heuristic trigger: keyword-shaped, deliberately broad. A false positive costs
# one extra context line; a miss just restores today's behaviour. Tune the regex
# below, not the consumers.
#
# Context-bloat check (v2.49.0) — same event, no new registration. Measured on
# a real project: a 12-day session ran every turn at 350-900k tokens of
# context; each turn re-reads all of it (cache read) BEFORE doing anything —
# a 14-command grep sweep cost 31 turns × 558k = 17.3M tokens ≈ $9 at
# opus, and the Lead's own re-reads were ~90% of the project's spend. No
# hook watched it because none looked at `usage`. This one reads the last
# turn's context size from the transcript and, on crossing 500k, tells the
# Lead via additionalContext (v2.119.1 — 200k per 200k bucket until then,
# picked as the long-context pricing knee; Claude 4.6+ bill the full 1M
# window at one rate, so the knee is gone, and the owner asked for one note
# at half the window, repeated only after a /compact brings the context back
# under the line and it crosses again): delegate reads to a
# scout, and propose /compact or a fresh session to the user when the task
# is done. Lead-facing only (v2.49.1): the user-facing systemMessage was
# removed on request — a nag on every bucket is friction, and the Lead
# can raise it in its own words at a natural pause. Edge-triggered: the
# state file says "fired" while the context sits above the line and is
# removed on the first reading below it, so one crossing = one note.
# Measured 2026-09-11 over 7 days: the hook fired 2x in one session and the
# Lead relayed "/compact" 43x, because "when the task is done" read as every
# turn's end — the line now binds the relay to THIS turn's close and forbids
# a repeat until a new context-check line arrives.
#
# Opt-out for a session: ROLEPOD_NUDGE_OFF=1
set -euo pipefail

[ "${ROLEPOD_NUDGE_OFF:-0}" = "1" ] && exit 0

INPUT=$(cat 2>/dev/null || echo '{}')
PROMPT=$(printf '%s' "$INPUT" | python3 -I -c "import sys,json;print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null || echo "")

CTX_MSG=""
SESSION_STATE="$(dirname "$0")/lib/session_state.py"
if [ -f "$SESSION_STATE" ]; then
  CTX=$(printf '%s' "$INPUT" | python3 "$SESSION_STATE" context-tokens 2>/dev/null || echo 0)
  CTX=${CTX:-0}
  CTX_LINE=500000
  SID=$(printf '%s' "$INPUT" | python3 -I -c "import sys,json;print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "")
  SID=$(printf '%s' "$SID" | tr -cd 'A-Za-z0-9._-')   # the id names a file under ~/.rolepod — nothing else may
  case "$SID" in .|..) SID="" ;; esac
  STATE_DIR="$HOME/.rolepod/ctx-nudge"
  if [ -n "$SID" ] && [ "$CTX" -ge "$CTX_LINE" ] 2>/dev/null; then   # no session id = no throttle = no note
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    LAST=$(cat "$STATE_DIR/$SID" 2>/dev/null || echo "")
    if [ "$LAST" != "fired" ]; then   # a pre-v2.119.1 bucket number reads as "armed" — one note, then "fired"
      printf 'fired' > "$STATE_DIR/$SID" 2>/dev/null || true
      CTX_K=$((CTX / 1000))
      CTX_MSG="context-check: last turn carried ${CTX_K}k tokens of context — every turn re-reads all of it. Fix: sweeps / many-file reads → dispatch rolepod:scout and read its report; in THIS turn's closing line tell the user once that /compact or a fresh session cuts per-turn cost (manage-context) — then never mention context again until a new context-check line arrives. "
    fi
  elif [ "$CTX" -gt 0 ] 2>/dev/null && [ -n "$SID" ]; then
    # Below the line with a real reading → re-arm, so the next crossing (after
    # /compact or a fresh start) gets its one note again. 0 = unknown, not small.
    rm -f "$STATE_DIR/$SID" 2>/dev/null || true
  fi
fi

# Nothing more to gauge without a prompt.
if [ -z "$PROMPT" ]; then
  if [ -n "$CTX_MSG" ]; then
    ROLEPOD_HOOK_MSG="$CTX_MSG" python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput':{'hookEventName':'UserPromptSubmit','additionalContext':os.environ.get('ROLEPOD_HOOK_MSG','')}}))
" 2>/dev/null || echo '{}'
  fi
  exit 0
fi

# Claim-shaped verbs: analysis / diagnosis / explanation / audit / status about
# real code or state. Case-insensitive, BSD-grep-safe (no \b — explicit spacing
# matches the convention in gate-reminder.sh). Leans claim-specific rather than
# matching every "what/how" so the nudge does not become per-turn wallpaper.
CLAIM_RX='(gap|gaps|root cause|diagnos|analy[sz]|audit|how does|how do|how is|how are|why (is|does|do|are|did|isn|doesn|wasn|won|can|would)|what.?s the|where (is|are|does|do)|is (it|this|that) (safe|correct|right|true|broken|working|wrong)|what would break|impact of|explain (how|why|what)|why not|status of|does (it|this|that) (work|handle|support|cause|break))'

MSG=""
if printf '%s' "$PROMPT" | grep -qiE "$CLAIM_RX"; then
  # v2.118.1: no tool named — the old text prescribed Read / Grep / file:line
  # for every question shape, so a question about a vendor, a library or the
  # world sent the Lead grepping the repo for a fact that does not live there.
  # The Lead picks the source (Verify-first in the always-on names them).
  MSG="claim-check: verify before you answer — primary source, never memory; cite it (file:line, command output, or URL). (off: ROLEPOD_NUDGE_OFF=1)"
fi

# Route nudge (v2.98.0): a commission-shaped prompt with no tier logged
# since the previous request. Measured: one project, 199 requests over a
# week, the router skill fired 0 times — a high-risk change to an existing
# feature went straight to build and six review rounds drew its seam map.
# Claim-shaped prompts (analysis) are R0 and skip this. Freshness = the
# newest `route` line in the repo phase-log is newer than the previous user
# prompt (transcript tail); no transcript → within 30 min. Not a git repo →
# silent. Prompt shape + freshness live in lib/route_check.py (ASCII-only source).
# v2.105.0: the same checker RECORDS the tier from the previous turn's assistant
# text (fallback to the Stop hook in session-lifecycle.sh), so the log fills
# itself — the manual append was measured at 0 lines in every product repo.
ROUTE_MSG=""
ROUTE_CHECK="$(dirname "$0")/lib/route_check.py"
if [ -z "$MSG" ] && [ -f "$ROUTE_CHECK" ]; then   # commission / question shape is decided inside the checker (Thai words live there as \u escapes)
  if [ "$(printf '%s' "$INPUT" | python3 "$ROUTE_CHECK" 2>/dev/null || true)" = "stale" ]; then
    ROUTE_MSG="⟂ route: a commission with no tier stated since your last request. Fix: one line before the first edit — Route: R2 (one file + test) → <skill> · <reason> — where R0 answer only · R1 trivial edit · R2 one file + test · R3 multi-file · R4 high-risk; R3/R4 → using-rolepod (Define → Plan first). The hook records it; blast radius sets the tier, not feature age. Exception: a literal follow-up inside an already-routed task → say 'same task' and continue. (off: ROLEPOD_NUDGE_OFF=1) "
  fi
fi

# Breaker state (v2.99.0): a breaker ledger newer than the last commit means
# the review→fix loop on this tree is closed until the user decides — an
# auto-resume prompt ("Please continue") must not reopen it; 3+ rounds with
# no ledger asks for the ledger first. Reader = the runner\x27s --rounds.
# Auto-resume (v2.100.0): after a usage-limit pause the harness sends
# "Please continue from where you left off" — a resume, not a user decision.
# Measured: two such prompts carried an 11-round review loop through the night.
AUTO_MSG=""
if printf '%s' "$PROMPT" | grep -qi 'please continue from where you left off'; then
  AUTO_MSG="↩ auto-resume: this prompt is the harness after a usage limit, not a user decision. Fix: the last turn ended at a question / breaker / decision brief → restate it and stop; otherwise continue the same task at the same tier — no new scope, no new review round. "
fi
BREAKER_MSG=""
XFAM_RUNNER="$(dirname "$0")/../scripts/cross-family.sh"; [ -f "$XFAM_RUNNER" ] || XFAM_RUNNER="$HOME/.rolepod/bin/cross-family.sh"
if [ -f "$XFAM_RUNNER" ] && git rev-parse --show-toplevel >/dev/null 2>&1; then
  RR=$(bash "$XFAM_RUNNER" --rounds 2>/dev/null || true)
  LP=$(printf '%s' "$RR" | sed -n 's/.*ledger=\([^ ]*\).*/\1/p'); RN=$(printf '%s' "$RR" | sed -n 's/.*rounds=\([0-9]*\).*/\1/p')
  if [ -n "$LP" ] && [ "$LP" != "-" ]; then
    BREAKER_MSG="⏹ breaker open: $LP — the review→fix loop on this tree is closed until the user decides. Fix: restate the decision brief (rounds · class · options) and stop; act only on the user\x27s pick. Exception: this message IS the pick → do it. "
  elif [ "${RN:-0}" -ge 3 ]; then
    BREAKER_MSG="⏹ review-rounds: $RN rounds on one uncommitted tree, no breaker ledger. Fix: before any fix or review — docs/rolepod/handoffs/<feature>-breaker-<date>.md (## Rounds · ## Class · ## Decision), then the class fix once (review-code §5). "
  fi
fi

if [ -n "$MSG$CTX_MSG$ROUTE_MSG$AUTO_MSG$BREAKER_MSG" ]; then
  # Env-passed (never interpolated) so quotes in either message cannot break the JSON.
  ROLEPOD_HOOK_MSG="${CTX_MSG}${MSG}${ROUTE_MSG}${AUTO_MSG}${BREAKER_MSG}" python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput':{'hookEventName':'UserPromptSubmit','additionalContext':os.environ.get('ROLEPOD_HOOK_MSG','')}}))
" 2>/dev/null || echo '{}'
fi

exit 0
