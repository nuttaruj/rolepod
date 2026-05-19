#!/bin/bash
# multi-agent-contract — structural check.
# Asserts the parallel-agent + cohesion-contract path is wired:
#   - Core 10 skill `write-plan` owns agent routing + the contract pattern
#   - hook `cohesion-contract-check.sh` is registered for PreToolUse Agent
#   - using-rolepod router has a row for multi-agent intent
#   - legacy shims redirect to write-plan instead of acting as active routers
#
# This is a STATIC fixture — proves the routing wiring exists. Live behavior
# verification of "does Lead actually write SPEC.md before 2nd spawn" lives
# in tests/workflow-behavior/cases/case-04-multi-agent.yml (gated by
# ROLEPOD_RUN_LIVE=1).
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

check "write-plan skill exists" "[ -f core/skills/write-plan/SKILL.md ]"
check "write-plan mentions cohesion contract" "grep -q 'cohesion contract' core/skills/write-plan/SKILL.md"
check "write-plan owns agent routing" "grep -qiE 'Route to agents|agent routing|Route specialist work' core/skills/write-plan/SKILL.md"
check "cohesion-contract-check hook exists" "[ -x hooks/cohesion-contract-check.sh ]"
check "hook checks for contract artifact" "grep -q 'contract\.md\|SPEC\.md\|cohesion\.md' hooks/cohesion-contract-check.sh"
check "using-rolepod routes multi-agent → write-plan" "grep -qiE 'multi-agent.*write-plan|write-plan.*cohesion contract|parallel.*write-plan' core/skills/using-rolepod/SKILL.md"
check "team-routing shim redirects to write-plan" "grep -q '^redirect_to: write-plan' core/skills/team-routing/SKILL.md"
check "parallel-contract-orchestration shim redirects to write-plan" "grep -q '^redirect_to: write-plan' core/skills/parallel-contract-orchestration/SKILL.md"

if [ $fail -eq 0 ]; then echo "multi-agent-contract: pass"; exit 0; fi
echo "multi-agent-contract: $fail failure(s)"
exit 1
