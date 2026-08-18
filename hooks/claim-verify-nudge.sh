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
# turn's context size from the transcript and, past 200k (the long-context
# pricing knee), tells the Lead via additionalContext: delegate reads to a
# scout, and propose /compact or a fresh session to the user when the task
# is done. Lead-facing only (v2.49.1): the user-facing systemMessage was
# removed on request — a nag on every 200k bucket is friction, and the Lead
# can raise it in its own words at a natural pause. Fires once per 200k
# bucket per session (state file), not every prompt.
#
# Opt-out for a session: ROLEPOD_NUDGE_OFF=1
set -euo pipefail

[ "${ROLEPOD_NUDGE_OFF:-0}" = "1" ] && exit 0

INPUT=$(cat 2>/dev/null || echo '{}')
PROMPT=$(printf '%s' "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null || echo "")

CTX_MSG=""
SESSION_STATE="$(dirname "$0")/lib/session_state.py"
if [ -f "$SESSION_STATE" ]; then
  CTX=$(printf '%s' "$INPUT" | python3 "$SESSION_STATE" context-tokens 2>/dev/null || echo 0)
  CTX=${CTX:-0}
  if [ "$CTX" -ge 200000 ] 2>/dev/null; then
    SID=$(printf '%s' "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "")
    BUCKET=$((CTX / 200000))
    STATE_DIR="$HOME/.rolepod/ctx-nudge"
    LAST=""
    if [ -n "$SID" ]; then
      mkdir -p "$STATE_DIR" 2>/dev/null || true
      LAST=$(cat "$STATE_DIR/$SID" 2>/dev/null || echo "")
    fi
    if [ "$LAST" != "$BUCKET" ]; then
      [ -n "$SID" ] && { printf '%s' "$BUCKET" > "$STATE_DIR/$SID" 2>/dev/null || true; }
      CTX_K=$((CTX / 1000))
      CTX_MSG="🧠 rolepod context-check: this session's last turn carried ${CTX_K}k tokens of context — every turn re-reads ALL of it before doing anything (cache read is not free; past 200k long-context pricing may apply). Before sweeping or reading many files yourself, dispatch a rolepod:scout (cheap class) and read only its report; when the current task is done, mention ONCE to the user that /compact or a fresh session would cut per-turn cost 3-5× (skill: manage-context) — do not repeat it every turn. "
    fi
  fi
fi

# Nothing more to gauge without a prompt.
if [ -z "$PROMPT" ]; then
  if [ -n "$CTX_MSG" ]; then
    ROLEPOD_HOOK_MSG="$CTX_MSG" python3 -c "
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
  MSG="🔍 rolepod claim-check: this asks for an analysis/diagnosis/explanation/status about real code or state. Apply Verify-first: READ the primary source (Read / Grep / run the command) and cite file:line — never state it from memory. (off: ROLEPOD_NUDGE_OFF=1)"
fi

if [ -n "$MSG$CTX_MSG" ]; then
  # Env-passed (never interpolated) so quotes in either message cannot break the JSON.
  ROLEPOD_HOOK_MSG="${CTX_MSG}${MSG}" python3 -c "
import json, os
print(json.dumps({'hookSpecificOutput':{'hookEventName':'UserPromptSubmit','additionalContext':os.environ.get('ROLEPOD_HOOK_MSG','')}}))
" 2>/dev/null || echo '{}'
fi

exit 0
