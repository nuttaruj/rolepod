#!/bin/bash
# ship-gate — structural check.
# Asserts the pre-merge gate is wired and the right reviewer-floor logic
# is in place.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

check "pre-merge-gate skill exists" "[ -f core/skills/pre-merge-gate/SKILL.md ]"
check "skill has gate checklist (S+T+F)" "grep -qE '(S1-S5|T1-T6|F1-F5|S[1-9]:|T[1-9]:|F[1-9]:)' core/skills/pre-merge-gate/SKILL.md"
check "using-rolepod routes ship/merge/push" "grep -qE 'ship.*merge.*push.*PR' core/skills/using-rolepod/SKILL.md"
check "precommit-gate hook exists" "[ -x hooks/precommit-gate.sh ]"
check "block-subagent-commit denies push/merge" "grep -qE 'git push|gh pr merge' hooks/block-subagent-commit.sh"
check "reviewer-flow skill exists" "[ -f core/skills/reviewer-flow/SKILL.md ]"
check "finishing-a-development-branch skill exists" "[ -f core/skills/finishing-a-development-branch/SKILL.md ]"

if [ $fail -eq 0 ]; then echo "ship-gate: pass"; exit 0; fi
echo "ship-gate: $fail failure(s)"
exit 1
