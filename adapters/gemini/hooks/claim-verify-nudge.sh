#!/usr/bin/env bash
# rolepod / Gemini BeforeAgent hook — soft nudge on the CLAIM/ANSWER path.
#
# Gemini's other rolepod hooks fire only on a tool call (BeforeTool / AfterTool)
# or a lifecycle event (SessionStart / PreCompress). A turn that answers an
# analysis / diagnosis / "how does X work" / "what's the gap" / status question
# in plain text is none of those, so it reaches the user with ZERO verification —
# the path where a confident-but-unverified claim ships wrong and costs rework.
#
# BeforeAgent fires after the user submits a prompt but before the agent plans,
# and its hookSpecificOutput.additionalContext is appended to the prompt for that
# turn only — so this injects ONE read-first reminder when the prompt is
# claim-shaped. Soft by construction: additionalContext only, never blocks.
#
# This is the Gemini counterpart of the Claude/Codex UserPromptSubmit hook. The
# event name (BeforeAgent, NOT UserPromptSubmit) and the JSON-only injection
# (bare stdout is NOT picked up) are Gemini-specific — verified against
# https://geminicli.com/docs/hooks/reference/ .
#
# Heuristic trigger: keyword-shaped, deliberately broad. A false positive costs
# one extra context line; a miss just restores today's behaviour.
#
# Opt-out for a session: ROLEPOD_NUDGE_OFF=1
set -euo pipefail

[ "${ROLEPOD_NUDGE_OFF:-0}" = "1" ] && exit 0

INPUT=$(cat 2>/dev/null || echo '{}')
PROMPT=$(printf '%s' "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null || echo "")

# Nothing to gauge.
[ -n "$PROMPT" ] || exit 0

# Claim-shaped verbs: analysis / diagnosis / explanation / audit / status about
# real code or state. Case-insensitive, BSD-grep-safe (no \b). Kept in sync with
# the Claude/Codex hooks/claim-verify-nudge.sh trigger.
CLAIM_RX='(gap|gaps|root cause|diagnos|analy[sz]|audit|how does|how do|how is|how are|why (is|does|do|are|did|isn|doesn|wasn|won|can|would)|what.?s the|where (is|are|does|do)|is (it|this|that) (safe|correct|right|true|broken|working|wrong)|what would break|impact of|explain (how|why|what)|why not|status of|does (it|this|that) (work|handle|support|cause|break))'

if printf '%s' "$PROMPT" | grep -qiE "$CLAIM_RX"; then
  MSG="🔍 rolepod claim-check: this asks for an analysis/diagnosis/explanation/status about real code or state. Before stating it: READ the primary source (read_file / search_file_content / run the command) and cite file:line — do NOT answer from memory or pattern-match. Cannot verify? Label it 'Assuming: X. Risk: Y. Verify by: Z' — never present a guess as fact. (off: ROLEPOD_NUDGE_OFF=1)"
  python3 -c "
import json
print(json.dumps({'hookSpecificOutput':{'hookEventName':'BeforeAgent','additionalContext':'''$MSG'''}}))
" 2>/dev/null || echo '{}'
fi

exit 0
