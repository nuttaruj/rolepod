#!/bin/bash
# bug-fix-workflow — structural fixture (Core 10).
# Asserts the bug-fix workflow path is wired end-to-end:
#   debug-issue → check-work
# Plus router row, shim redirect, hook backstops, regression-test expectation.
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

# Router routes bug intent through phase model
check "using-rolepod router covers bug-fix trigger" "grep -qE 'fix.*bug|failing test|broken|debug' core/skills/using-rolepod/SKILL.md"

# Tier 3 shims redirect legacy triggers to debug-issue
check "systematic-debugging shim redirects to debug-issue" "grep -q '^redirect_to: debug-issue' core/skills/systematic-debugging/SKILL.md"
check "debugging-and-error-recovery shim redirects to debug-issue" "grep -q '^redirect_to: debug-issue' core/skills/debugging-and-error-recovery/SKILL.md"
check "root-cause-tracing shim redirects to debug-issue" "grep -q '^redirect_to: debug-issue' core/skills/root-cause-tracing/SKILL.md"

if [ $fail -eq 0 ]; then echo "bug-fix-workflow: pass"; exit 0; fi
echo "bug-fix-workflow: $fail failure(s)"
exit 1
