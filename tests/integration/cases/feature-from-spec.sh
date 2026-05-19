#!/bin/bash
# feature-from-spec — structural fixture (Core 10).
# Asserts the feature-from-spec workflow path is wired end-to-end:
#   write-spec → write-plan → implement-plan → check-work
# Plus router row, approval gate, parallel cohesion contract requirement.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

# Core 10 skills present
for s in write-spec write-plan implement-plan check-work; do
  check "skill $s exists" "[ -f core/skills/$s/SKILL.md ]"
done

# write-spec must gate Build behind user approval + self-review
check "write-spec gates Build behind user approval" "grep -qiE 'approval|approve' core/skills/write-spec/SKILL.md"
check "write-spec includes self-review of the draft" "grep -qiE 'self.review' core/skills/write-spec/SKILL.md"

# write-plan must produce verifiable tasks (test plan per task, not 'add tests')
check "write-plan documents per-task test plan" "grep -qiE 'test plan per task|test or evidence per task|test plan' core/skills/write-plan/SKILL.md"
check "write-plan covers cohesion contract before parallel spawn" "grep -qiE 'cohesion contract|contract.*before' core/skills/write-plan/SKILL.md"

# implement-plan must describe bounded delegation + fresh reviewer pattern
check "implement-plan describes bounded delegation" "grep -qiE 'bounded delegation|bounded scope|task scope' core/skills/implement-plan/SKILL.md"
check "implement-plan describes fresh-context reviewer pattern" "grep -qiE 'fresh.context|fresh reviewer|two-stage' core/skills/implement-plan/SKILL.md"

# Router routes vague feature into the canonical Core 10 path
check "using-rolepod routes vague feature → write-spec" "grep -qE 'vague target.*write-spec|write-spec.*vague target' core/skills/using-rolepod/SKILL.md"
check "using-rolepod routes spec-backed feature → write-plan" "grep -qE 'spec exists.*write-plan|write-plan.*spec exists' core/skills/using-rolepod/SKILL.md"
check "using-rolepod routes plan execution → implement-plan" "grep -qE 'implement plan.*implement-plan|implement-plan.*execute plan' core/skills/using-rolepod/SKILL.md"

# Deleted legacy shims must stay absent; Core 10 skills own those trigger phrases.
check "legacy spec-driven-development skill absent" "[ ! -d core/skills/spec-driven-development ]"
check "legacy planning-and-task-breakdown skill absent" "[ ! -d core/skills/planning-and-task-breakdown ]"
check "legacy subagent-task-execution skill absent" "[ ! -d core/skills/subagent-task-execution ]"
check "legacy post-change-verify skill absent" "[ ! -d core/skills/post-change-verify ]"

if [ $fail -eq 0 ]; then echo "feature-from-spec: pass"; exit 0; fi
echo "feature-from-spec: $fail failure(s)"
exit 1
