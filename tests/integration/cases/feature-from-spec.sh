#!/bin/bash
# feature-from-spec — structural fixture.
# Asserts the feature-from-spec workflow path is wired end-to-end:
#   spec-driven-development → planning-and-task-breakdown →
#     subagent-task-execution → test-driven-development → post-change-verify
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

# Skills present
for s in spec-driven-development planning-and-task-breakdown subagent-task-execution test-driven-development post-change-verify; do
  check "skill $s exists" "[ -f core/skills/$s/SKILL.md ]"
done

# spec-driven-development should gate Build-phase skills behind a written spec
check "spec-driven-development gates Build behind written spec" "grep -qiE 'spec required|written spec|spec exists|spec before|hard.?gate' core/skills/spec-driven-development/SKILL.md"

# planning-and-task-breakdown should produce verifiable tasks
check "planning-and-task-breakdown documents per-task verify command" "grep -qiE 'verify command|acceptance|done condition' core/skills/planning-and-task-breakdown/SKILL.md"

# subagent-task-execution should describe two-stage review
check "subagent-task-execution describes implementer + reviewer split" "grep -qiE 'implementer|two-stage|spec-compliance|code-quality reviewer' core/skills/subagent-task-execution/SKILL.md"

# Router routes feature intent into Define / Plan
check "using-rolepod routes vague feature → spec-driven-development" "grep -qE 'build.*add.*create|vague target' core/skills/using-rolepod/SKILL.md && grep -q 'spec-driven-development' core/skills/using-rolepod/SKILL.md"
check "using-rolepod routes 'execute plan' → planning-and-task-breakdown" "grep -qE 'execute plan|work the plan|implement plan' core/skills/using-rolepod/SKILL.md"

if [ $fail -eq 0 ]; then echo "feature-from-spec: pass"; exit 0; fi
echo "feature-from-spec: $fail failure(s)"
exit 1
