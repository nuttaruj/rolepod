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
  count-all "0 0 1 1" "Workflow reviewer (no model = frontmatter opus) counts as strong in count-all"

run '{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''security-engineer'\'', model: '\''haiku'\''})"}}' \
  count-all "0 0 1 0" "Workflow reviewer pinned haiku is not strong"

# v2.104.0 — a Workflow agentType strong reviewer with no explicit model runs its
# frontmatter pin (opus): strong under ANY Lead. From v2.74.0 to v2.103 it rendered
# inherit and counted only under a strong Lead (CourtBook technician review fleet
# had cleared the commit gate with a sonnet security-engineer). Explicit opus counts anywhere.
wf_tu='{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''rolepod:security-engineer'\''})"}}'
wf_tu_opus='{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''rolepod:security-engineer'\'', model: '\''opus'\''})"}}'
lead_sonnet='{"type":"assistant","message":{"model":"claude-sonnet-5","content":[]}}'
lead_opus='{"type":"assistant","message":{"model":"claude-opus-5","content":[]}}'
run "$lead_sonnet"$'\n'"$wf_tu"      count-all "0 0 1 1" "v2.104: Workflow reviewer (frontmatter opus) under a sonnet Lead IS strong"
run "$lead_opus"$'\n'"$wf_tu"        count-all "0 0 1 1" "v2.104: Workflow reviewer (frontmatter opus) under an opus Lead is strong"
run "$lead_sonnet"$'\n'"$wf_tu_opus" count-all "0 0 1 1" "v2.74: Workflow reviewer pinned opus under a sonnet Lead is strong"

# v2.88.0 — TIER_PINNED_AGENTS must mirror the tier overlays: every role whose
# Claude tier renders a real model pin (cheap -> haiku, balanced -> sonnet) is
# in the set, every `strong` role (renders opus; the hook floors it) is in STRONG_ROLE_AGENTS and
# NOT in it. Drift here silently re-opens the gate hole a general-purpose
# agentType used to punch (v2.88.0).
drift=$(python3 - <<'PYEOF'
import re, pathlib, sys
sys.path.insert(0, "hooks/lib")
import session_state as ss
bad = []
for y in sorted(pathlib.Path("adapters/claude/agent-frontmatter").glob("*.yml")):
    m = re.search(r"^tier:\s*(\S+)", y.read_text(), re.M)
    if not m:
        bad.append("%s: no tier:" % y.name); continue
    tier, name = m.group(1), y.stem
    if tier in ("cheap", "balanced"):
        if name not in ss.TIER_PINNED_AGENTS:
            bad.append("%s (%s) missing from TIER_PINNED_AGENTS" % (name, tier))
    elif tier == "strong":
        if name not in ss.STRONG_ROLE_AGENTS:
            bad.append("%s (strong) missing from STRONG_ROLE_AGENTS" % name)
        if name in ss.TIER_PINNED_AGENTS:
            bad.append("%s (strong, floored via STRONG_ROLE_AGENTS) must NOT be in TIER_PINNED_AGENTS" % name)
    else:
        bad.append("%s: unknown tier %s" % (name, tier))
known = {y.stem for y in pathlib.Path("adapters/claude/agent-frontmatter").glob("*.yml")}
for extra in sorted(ss.TIER_PINNED_AGENTS - known):
    bad.append("%s in TIER_PINNED_AGENTS but has no tier overlay" % extra)
print("; ".join(bad))
PYEOF
)
if [ -z "$drift" ]; then
  echo "  ✓ TIER_PINNED_AGENTS matches the tier overlays (no drift)"
else
  echo "  ✗ tier-set drift — $drift"
  fail=$((fail+1))
fi

echo ""
if [ $fail -eq 0 ]; then
  echo "hook-agent-matching: pass"
  exit 0
fi
echo "hook-agent-matching: $fail failure(s)"
exit 1
