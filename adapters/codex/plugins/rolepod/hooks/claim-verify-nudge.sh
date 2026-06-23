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
# Opt-out for a session: ROLEPOD_NUDGE_OFF=1
set -euo pipefail

[ "${ROLEPOD_NUDGE_OFF:-0}" = "1" ] && exit 0

INPUT=$(cat 2>/dev/null || echo '{}')
PROMPT=$(printf '%s' "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null || echo "")

# Nothing to gauge.
[ -n "$PROMPT" ] || exit 0

# Claim-shaped verbs: analysis / diagnosis / explanation / audit / status about
# real code or state. Case-insensitive, BSD-grep-safe (no \b — explicit spacing
# matches the convention in gate-reminder.sh). Leans claim-specific rather than
# matching every "what/how" so the nudge does not become per-turn wallpaper.
CLAIM_RX='(gap|gaps|root cause|diagnos|analy[sz]|audit|how does|how do|how is|how are|why (is|does|do|are|did|isn|doesn|wasn|won|can|would)|what.?s the|where (is|are|does|do)|is (it|this|that) (safe|correct|right|true|broken|working|wrong)|what would break|impact of|explain (how|why|what)|why not|status of|does (it|this|that) (work|handle|support|cause|break))'

if printf '%s' "$PROMPT" | grep -qiE "$CLAIM_RX"; then
  MSG="🔍 rolepod claim-check: this asks for an analysis/diagnosis/explanation/status about real code or state. Before stating it: READ the primary source (Read / Grep / run the command) and cite file:line — do NOT answer from memory or pattern-match. Cannot verify? Label it 'Assuming: X. Risk: Y. Verify by: Z' — never present a guess as fact. (off: ROLEPOD_NUDGE_OFF=1)"
  python3 -c "
import json
print(json.dumps({'hookSpecificOutput':{'hookEventName':'UserPromptSubmit','additionalContext':'''$MSG'''}}))
" 2>/dev/null || echo '{}'
fi

exit 0
