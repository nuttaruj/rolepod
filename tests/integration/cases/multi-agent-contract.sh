#!/bin/bash
# multi-agent-contract — structural check.
# Asserts the parallel-agent + cohesion-contract path is wired:
#   - skill `parallel-contract-orchestration` exists with the contract pattern
#   - hook `cohesion-contract-check.sh` is registered for PreToolUse Agent
#   - using-rolepod router has a row for multi-agent intent
#   - team-routing skill documents the agent picker
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

check "parallel-contract-orchestration skill exists" "[ -f core/skills/parallel-contract-orchestration/SKILL.md ]"
check "skill mentions cohesion contract" "grep -q 'cohesion contract' core/skills/parallel-contract-orchestration/SKILL.md"
check "cohesion-contract-check hook exists" "[ -x hooks/cohesion-contract-check.sh ]"
check "hook checks for contract artifact" "grep -q 'contract\.md\|SPEC\.md\|cohesion\.md' hooks/cohesion-contract-check.sh"
check "using-rolepod routes multi-agent" "grep -qi 'multi-agent\|parallel' core/skills/using-rolepod/SKILL.md"
check "team-routing exists" "[ -f core/skills/team-routing/SKILL.md ]"

if [ $fail -eq 0 ]; then echo "multi-agent-contract: pass"; exit 0; fi
echo "multi-agent-contract: $fail failure(s)"
exit 1
