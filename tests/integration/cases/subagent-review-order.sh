#!/bin/bash
# subagent-review-order — structural fixture (Core 10).
# Asserts the bounded-delegation + fresh-context reviewer pattern is
# documented + wired:
#   implementer subagent writes code (bounded scope) →
#     fresh-context reviewer reads the diff with no prior chat →
#     reject COMPLETED with failing tests or scope creep →
#     subagent NEVER commits (Lead commits after both pass).
#
# The doctrine lives inside `implement-plan` (the bounded delegation section
# + the fresh-reviewer pattern). The old standalone subagent skill is gone.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

I="core/skills/implement-plan/SKILL.md"

# Core 10 skill owns the doctrine
check "implement-plan skill exists" "[ -f $I ]"
check "implement-plan names the bounded-delegation pattern" "grep -qiE 'bounded delegation|bounded scope|task scope' $I"
check "implement-plan describes the implementer stage" "grep -qiE 'implementer|subagent|delegate' $I"
check "implement-plan describes the fresh-context reviewer pattern" "grep -qiE 'fresh.context|fresh reviewer|two-stage' $I"
check "implement-plan caps subagent tool use" "grep -qiE '12 tool uses|tool cap|tool[- ]uses' $I"
check "implement-plan bans subagent commits (Lead commits)" "grep -qiE 'subagents? NEVER commit|never commit|Lead commits' $I"
check "implement-plan rejects COMPLETED with failing tests or scope creep" "grep -qiE 'reject.*COMPLETED|COMPLETED.*reject|scope creep' $I"

check "legacy subagent-task-execution skill absent" "[ ! -d core/skills/subagent-task-execution ]"

# Universal reviewer agent backstop
check "universal-reviewer agent exists" "[ -f core/agents/universal-reviewer.md ]"
check "universal-reviewer at strong tier (adversarial review)" "grep -q '^tier: strong' adapters/claude/agent-frontmatter/universal-reviewer.yml"

# Sub-agent commit ban prevents implementer from shipping
check "block-subagent-commit hook prevents sub-agent commits" "[ -x hooks/block-subagent-commit.sh ] && grep -q 'agent_id' hooks/block-subagent-commit.sh"

if [ $fail -eq 0 ]; then echo "subagent-review-order: pass"; exit 0; fi
echo "subagent-review-order: $fail failure(s)"
exit 1
