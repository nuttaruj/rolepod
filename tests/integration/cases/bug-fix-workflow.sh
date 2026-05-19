#!/bin/bash
# bug-fix-workflow — structural fixture (Core 10).
# Asserts the bug-fix workflow path is wired end-to-end:
#   debug-issue → check-work
# Plus router row, no legacy shim dependency, regression-test expectation.
#
# This is STRUCTURAL — proves wiring without needing a live `claude -p`.
# Live behavior verification of "does Lead reproduce before patching" lives
# in tests/workflow-behavior/cases/case-02-bug-fix.yml (gated by
# ROLEPOD_RUN_LIVE=1).
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

# Core 10 skills present
check "debug-issue skill exists" "[ -f core/skills/debug-issue/SKILL.md ]"
check "check-work skill exists" "[ -f core/skills/check-work/SKILL.md ]"

# debug-issue body has the required loop steps
check "debug-issue covers reproduce step" "grep -qi 'reproduc' core/skills/debug-issue/SKILL.md"
check "debug-issue covers root-cause tracing" "grep -qi 'root cause\|trace upstream\|upstream' core/skills/debug-issue/SKILL.md"
check "debug-issue covers failing-test step" "grep -qi 'failing test\|regression test' core/skills/debug-issue/SKILL.md"
check "debug-issue covers minimal-fix expectation" "grep -qi 'minimal fix\|smallest fix\|smallest change' core/skills/debug-issue/SKILL.md"
check "debug-issue covers verify step (regression-clean)" "grep -qi 'verify\|regression-clean\|symptom: gone' core/skills/debug-issue/SKILL.md"

# Router routes bug intent through the canonical Core 10 skill
check "using-rolepod router sends bug intent → debug-issue" "grep -qE 'fix bug.*debug-issue|failing test.*debug-issue|debug-issue.*failing test' core/skills/using-rolepod/SKILL.md"

# Deleted legacy shims must stay absent; Core 10 router/frontmatter carries
# the old phrases directly.
check "legacy systematic-debugging skill absent" "[ ! -d core/skills/systematic-debugging ]"
check "legacy debugging-and-error-recovery skill absent" "[ ! -d core/skills/debugging-and-error-recovery ]"
check "legacy root-cause-tracing skill absent" "[ ! -d core/skills/root-cause-tracing ]"

if [ $fail -eq 0 ]; then echo "bug-fix-workflow: pass"; exit 0; fi
echo "bug-fix-workflow: $fail failure(s)"
exit 1
