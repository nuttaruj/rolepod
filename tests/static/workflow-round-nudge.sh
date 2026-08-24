#!/bin/bash
# Behavioral test — dispatch-auto-log workflow-round counter (v2.64.0).
#
# Gap (real case 2026-08-24): a fix-fleet looped the SAME workflow six
# rounds (defect count 16→5→3→6) and no hook fired — fix-loop-breaker only
# counts identical failing Bash commands. The counter added to
# dispatch-auto-log.sh must nudge (additionalContext, never block) at the
# 3rd same-name Workflow dispatch per session, stay silent below that,
# count names independently, skip unnamed scripts, and keep appending the
# phase-log line unchanged.
#
# Runs the real hook in a throwaway git repo. Wired into `make test-static`.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

fail=0
tmp="$(mktemp -d)"
SID="wfroundtest$$"
trap 'rm -rf "$tmp"; rm -f "${TMPDIR:-/tmp}/rolepod-wfrounds-${SID}.json" "/tmp/rolepod-wfrounds-${SID}.json"' EXIT

mkdir -p "$tmp/repo" && cd "$tmp/repo"
git init -q . && git config user.email t@t && git config user.name t

HOOK="$REPO_DIR/hooks/dispatch-auto-log.sh"

# mkinput <name-or-empty> → JSON on stdout
mkinput() {
  if [ -n "$1" ]; then
    printf '{"session_id":"%s","tool_name":"Workflow","tool_input":{"script":"export const meta = { name: \\u0027%s\\u0027 }\\nawait agent(1)"}}' "$SID" "$1"
  else
    printf '{"session_id":"%s","tool_name":"Workflow","tool_input":{"script":"await agent(1)"}}' "$SID"
  fi
}

# run <label> <input> <expect: nudge|silent>
run() {
  local out verdict=silent
  out=$(printf '%s' "$2" | bash "$HOOK" 2>/dev/null)
  echo "$out" | grep -q additionalContext && verdict=nudge
  if [ "$verdict" = "$3" ]; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1 — expected $3, got $verdict"
    fail=$((fail+1))
  fi
}

echo "── workflow-round-nudge ──"

run "1st dispatch of a workflow is silent" "$(mkinput coach-fix)" silent
run "2nd dispatch of the same workflow is silent" "$(mkinput coach-fix)" silent
run "3rd dispatch of the same workflow nudges" "$(mkinput coach-fix)" nudge
run "different workflow name counts independently (silent)" "$(mkinput other-wf)" silent
run "4th dispatch of the looping workflow keeps nudging" "$(mkinput coach-fix)" nudge
run "unnamed workflow script never nudges" "$(mkinput '')" silent
run "unnamed workflow script never nudges (repeat 2)" "$(mkinput '')" silent
run "unnamed workflow script never nudges (repeat 3)" "$(mkinput '')" silent

# Agent dispatches are logged but never counted as rounds.
AGENT_IN=$(printf '{"session_id":"%s","tool_name":"Agent","tool_input":{"subagent_type":"general-purpose"}}' "$SID")
run "Agent dispatch never nudges" "$AGENT_IN" silent

# Nudge text must point at the clean-room cross-family consult.
OUT=$(printf '%s' "$(mkinput coach-fix)" | bash "$HOOK" 2>/dev/null)
if echo "$OUT" | grep -q ROLEPOD_BRAIN_SILENT; then
  echo "  ✓ nudge names the clean-room consult invocation"
else
  echo "  ✗ nudge is missing the ROLEPOD_BRAIN_SILENT consult pointer"
  fail=$((fail+1))
fi

# The phase-log line must still be appended for every dispatch above
# (6 named workflows + 3 unnamed + 2 agent + the text-check run = 12).
N=$(grep -c 'hook-auto' .rolepod/evidence/phase-log.jsonl 2>/dev/null || echo 0)
if [ "$N" -ge 10 ]; then
  echo "  ✓ phase-log lines still appended ($N)"
else
  echo "  ✗ phase-log lines missing — got $N, expected >= 10"
  fail=$((fail+1))
fi

# No session_id → counter skipped, log still written, exit 0.
NOSID=$(printf '{"tool_name":"Workflow","tool_input":{"script":"export const meta = { name: \\u0027coach-fix\\u0027 }"}}')
run "missing session_id is silent (fail-open)" "$NOSID" silent

# Malformed JSON → exit 0, no output.
OUT=$(printf 'not-json' | bash "$HOOK" 2>/dev/null); RC=$?
if [ "$RC" -eq 0 ] && [ -z "$OUT" ]; then
  echo "  ✓ malformed JSON is fail-open"
else
  echo "  ✗ malformed JSON: rc=$RC out=${OUT:0:40}"
  fail=$((fail+1))
fi

echo ""
if [ $fail -eq 0 ]; then
  echo "workflow-round-nudge: pass"
  exit 0
fi
echo "workflow-round-nudge: $fail failure(s)"
exit 1
