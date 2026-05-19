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

# Router routes vague feature into Define phase
check "using-rolepod routes vague feature → Define phase" "grep -qE 'build.*add.*create|vague target' core/skills/using-rolepod/SKILL.md"

# Legacy shims still route to Core 10 targets
check "spec-driven-development shim redirects to write-spec" "grep -q '^redirect_to: write-spec' core/skills/spec-driven-development/SKILL.md"
check "planning-and-task-breakdown shim redirects to write-plan" "grep -q '^redirect_to: write-plan' core/skills/planning-and-task-breakdown/SKILL.md"
check "subagent-task-execution shim redirects to implement-plan" "grep -q '^redirect_to: implement-plan' core/skills/subagent-task-execution/SKILL.md"
check "post-change-verify shim redirects to check-work" "grep -q '^redirect_to: check-work' core/skills/post-change-verify/SKILL.md"

if [ $fail -eq 0 ]; then echo "feature-from-spec: pass"; exit 0; fi
echo "feature-from-spec: $fail failure(s)"
exit 1
