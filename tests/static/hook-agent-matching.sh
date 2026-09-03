#!/bin/bash
# Regression test — hooks must count plugin-namespaced reviewer agents.
#
# Bug: session_state.count_reviewers_dispatched matched bare agent names
# only. A plugin-installed reviewer is dispatched as 'rolepod:qa-tester';
# it counted as 0, so precommit-gate false-blocked a commit even after
# qa-tester + security-engineer had actually reviewed and APPROVED.
#
# Wired into `make test-static`.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"

SS="hooks/lib/session_state.py"
fail=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# run <transcript-jsonl> <query> <expected> <label>
run() {
  printf '%s\n' "$1" > "$tmp"
  local got
  got=$(printf '{"transcript_path":"%s"}' "$tmp" | python3 "$SS" "$2" 2>/dev/null || echo ERR)
  if [ "$got" = "$3" ]; then
    echo "  ✓ $4 (got $got)"
  else
    echo "  ✗ $4 — expected $3, got $got"
    fail=$((fail+1))
  fi
}

echo "── hook-agent-matching ──"

# The bug: a plugin-namespaced reviewer must count.
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:qa-tester"}}' \
  count-reviewers-dispatched 1 "rolepod:qa-tester counts as a reviewer"

# The 'Task' tool name must count too (CLI-version variance).
run '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer"}}' \
  count-reviewers-dispatched 1 "Task tool + rolepod:security-engineer counts"

# A bare (un-namespaced) name must still count — no regression.
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"qa-tester"}}' \
  count-reviewers-dispatched 1 "bare qa-tester still counts"

# A non-reviewer agent must NOT count.
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:backend-developer"}}' \
  count-reviewers-dispatched 0 "rolepod:backend-developer is not a reviewer"

# Workflow-run reviewers (agent() agentType calls) must count — a workflow
# that already reviewed must not force a duplicate Agent-tool dispatch.
run '{"type":"tool_use","name":"Workflow","input":{"script":"const r = await agent(prompt, {agentType: '\''rolepod:universal-reviewer'\''})"}}' \
  count-reviewers-dispatched 1 "Workflow agentType universal-reviewer counts"

run '{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''rolepod:backend-developer'\''})"}}' \
  count-reviewers-dispatched 0 "Workflow agentType backend-developer does not count"

# count-all strong split: inherit → strong; explicit low model → reviewer only.
run '{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''security-engineer'\''})"}}' \
  count-all "0 0 1 1" "Workflow reviewer (inherit) counts as strong in count-all"

run '{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''security-engineer'\'', model: '\''haiku'\''})"}}' \
  count-all "0 0 1 0" "Workflow reviewer pinned haiku is not strong"

# v2.74.0 — a Workflow agentType strong reviewer with no explicit model inherits
# the Lead: strong under an opus Lead, NOT under a sonnet Lead (the Agent-tool
# floor does not reach agent() calls; observed: CourtBook technician-payout-review
# cleared the commit gate with a sonnet security-engineer). Explicit opus counts anywhere.
wf_tu='{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''rolepod:security-engineer'\''})"}}'
wf_tu_opus='{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''rolepod:security-engineer'\'', model: '\''opus'\''})"}}'
lead_sonnet='{"type":"assistant","message":{"model":"claude-sonnet-5","content":[]}}'
lead_opus='{"type":"assistant","message":{"model":"claude-opus-5","content":[]}}'
run "$lead_sonnet"$'\n'"$wf_tu"      count-all "0 0 1 0" "v2.74: Workflow reviewer (inherit) under a sonnet Lead is NOT strong"
run "$lead_opus"$'\n'"$wf_tu"        count-all "0 0 1 1" "v2.74: Workflow reviewer (inherit) under an opus Lead is strong"
run "$lead_sonnet"$'\n'"$wf_tu_opus" count-all "0 0 1 1" "v2.74: Workflow reviewer pinned opus under a sonnet Lead is strong"

echo ""
if [ $fail -eq 0 ]; then
  echo "hook-agent-matching: pass"
  exit 0
fi
echo "hook-agent-matching: $fail failure(s)"
exit 1
