#!/bin/bash
# bug-fix-workflow — structural fixture.
# Asserts the bug-fix workflow path is wired end-to-end:
#   systematic-debugging → test-driven-development → post-change-verify
# Plus router row, hook backstops, regression-test expectation.
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

# Canonical skills present
check "systematic-debugging skill exists" "[ -f core/skills/systematic-debugging/SKILL.md ]"
check "test-driven-development skill exists" "[ -f core/skills/test-driven-development/SKILL.md ]"
check "post-change-verify skill exists" "[ -f core/skills/post-change-verify/SKILL.md ]"

# systematic-debugging body has the required loop steps
check "systematic-debugging covers reproduce step" "grep -qi 'reproduc' core/skills/systematic-debugging/SKILL.md"
check "systematic-debugging covers root-cause tracing" "grep -qi 'root cause\|upstream' core/skills/systematic-debugging/SKILL.md"
check "systematic-debugging covers failing-test step" "grep -qi 'failing test\|regression test' core/skills/systematic-debugging/SKILL.md"
check "systematic-debugging covers minimal-fix expectation" "grep -qi 'minimal fix\|smallest fix\|root, not symptom' core/skills/systematic-debugging/SKILL.md"
check "systematic-debugging covers verify step" "grep -qi 'verify\|regression-clean\|symptom: gone' core/skills/systematic-debugging/SKILL.md"

# Router routes bug intent to systematic-debugging
check "using-rolepod router routes 'fix bug' → systematic-debugging" "grep -qE 'fix.*bug|failing test|broken' core/skills/using-rolepod/SKILL.md && grep -q 'systematic-debugging' core/skills/using-rolepod/SKILL.md"

# Compat shims redirect legacy triggers
check "debugging-and-error-recovery shim points to systematic-debugging" "grep -q 'systematic-debugging' core/skills/debugging-and-error-recovery/SKILL.md"
check "root-cause-tracing shim points to systematic-debugging" "grep -q 'systematic-debugging' core/skills/root-cause-tracing/SKILL.md"

if [ $fail -eq 0 ]; then echo "bug-fix-workflow: pass"; exit 0; fi
echo "bug-fix-workflow: $fail failure(s)"
exit 1
