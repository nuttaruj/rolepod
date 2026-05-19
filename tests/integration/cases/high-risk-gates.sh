#!/bin/bash
# high-risk-gates — structural check.
# Asserts the high-risk path enforcement is wired:
#   - gate-reminder.sh blocks on high-risk + no test edits
#   - precommit-gate.sh escalates to HARD on high-risk + 0 tests in session
#   - block-subagent-commit.sh denies sub-agent commits
#   - security-engineer agent + Core 10 review-code skill exist
#   - model-tier-policy.md marks security-engineer / billing-engineer as strong
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

check "gate-reminder hook exists" "[ -x hooks/gate-reminder.sh ]"
check "gate-reminder enforces RED-test on high-risk" "grep -q 'HARD BLOCK\|RED-test' hooks/gate-reminder.sh"
check "precommit-gate hook exists" "[ -x hooks/precommit-gate.sh ]"
check "precommit-gate escalates on high-risk + 0 tests" "grep -q 'HIGH_RISK_EDITS.*TEST_EDITS\|NO TEST EDITS' hooks/precommit-gate.sh"
check "block-subagent-commit hook exists" "[ -x hooks/block-subagent-commit.sh ]"
check "hook checks agent_id field" "grep -q 'agent_id' hooks/block-subagent-commit.sh"
check "session_state helper exists" "[ -f hooks/lib/session_state.py ]"
check "review-code skill exists" "[ -f core/skills/review-code/SKILL.md ]"
check "security-and-hardening shim redirects to review-code" "grep -q '^redirect_to: review-code' core/skills/security-and-hardening/SKILL.md"
check "using-rolepod routes high-risk work through review-code" "grep -qE 'security.*review-code|auth.*review-code|billing.*review-code|payment.*review-code|migration.*review-code' core/skills/using-rolepod/SKILL.md"
check "security-engineer agent exists" "[ -f core/agents/security-engineer.md ]"
check "billing-engineer at opus tier" "grep -q '^model: opus' adapters/claude/agent-frontmatter/billing-engineer.yml"
check "security-engineer at opus tier" "grep -q '^model: opus' adapters/claude/agent-frontmatter/security-engineer.yml"
check "model-tier-policy fragment present" "[ -f core/fragments/model-tier-policy.md ]"

if [ $fail -eq 0 ]; then echo "high-risk-gates: pass"; exit 0; fi
echo "high-risk-gates: $fail failure(s)"
exit 1
