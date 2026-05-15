#!/bin/bash
# subagent-review-order — structural fixture.
# Asserts the two-stage subagent review pattern is documented + wired:
#   implementer subagent writes code →
#     spec-compliance reviewer (fresh context) →
#     code-quality reviewer (fresh context) →
#     mark done only when both pass.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

S="core/skills/subagent-task-execution/SKILL.md"

check "subagent-task-execution skill exists" "[ -f $S ]"
check "skill names the implementer stage" "grep -qiE 'implementer|stage 1' $S"
check "skill names two distinct reviewers (spec + code-quality)" "grep -qiE 'spec.compliance|spec reviewer' $S && grep -qiE 'code.quality|quality reviewer' $S"
check "skill requires independent reviewer contexts (not implementer)" "grep -qiE 'fresh|independent context|separate context' $S"
check "skill requires both reviewers pass before marking done" "grep -qiE 'both.*pass|both reviewers|only when both|until.*pass' $S"
check "skill caps cycle rounds to prevent infinite loops" "grep -qiE 'round|bounded|cap|3 cycles|3 rounds' $S"

# Universal reviewer agent backstop
check "universal-reviewer agent exists" "[ -f core/agents/universal-reviewer.md ]"
check "universal-reviewer at opus tier (adversarial review)" "grep -q '^model: opus' adapters/claude/agent-frontmatter/universal-reviewer.yml"

# Sub-agent commit ban prevents implementer from shipping
check "block-subagent-commit hook prevents sub-agent commits" "[ -x hooks/block-subagent-commit.sh ] && grep -q 'agent_id' hooks/block-subagent-commit.sh"

if [ $fail -eq 0 ]; then echo "subagent-review-order: pass"; exit 0; fi
echo "subagent-review-order: $fail failure(s)"
exit 1
