#!/bin/bash
# multi-agent-contract — structural check.
# Asserts the parallel-agent + cohesion-contract path is wired:
#   - Core 10 skill `write-plan` owns agent routing + the contract pattern
#   - hook `cohesion-contract-check.sh` is registered for PreToolUse Agent
#   - using-rolepod router has a row for multi-agent intent
#   - legacy shims are gone, so Core 10 carries the trigger surface directly
#
# Static fixture: proves routing wiring (skill + hook + router refs).
# Rolepod does not ship `claude -p` headless behavior tests — interactive
# workflow verification happens by using Rolepod for real work.
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
check "legacy team-routing skill absent" "[ ! -d core/skills/team-routing ]"
check "legacy parallel-contract-orchestration skill absent" "[ ! -d core/skills/parallel-contract-orchestration ]"

if [ $fail -eq 0 ]; then echo "multi-agent-contract: pass"; exit 0; fi
echo "multi-agent-contract: $fail failure(s)"
exit 1
