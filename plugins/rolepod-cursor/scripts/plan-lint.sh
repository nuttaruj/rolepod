#!/bin/bash
# plan-lint — deterministic lint of a filled plan artifact, plus the
# cohesion contract when the plan declares a parallel layout. The
# mechanical arm of write-plan §7 self-review.
#
# Usage: scripts/plan-lint.sh <plan.md> [contract.md]
#   The contract argument is optional — when omitted, the script looks for
#   a backticked *.md path inside the plan's "## Parallel layout" section
#   (resolved against the plan's directory, then the repo root). A plan
#   whose Parallel layout says "Sequential" skips the ownership check.
#
# Checks:
#   1. `## Failure policy` section present (the loop's circuit breaker).
#   2. Every `### Task` carries a `Command:` (loop-runnable).
#   3. Parallel plans only: every backticked path under "## Files to touch"
#      appears under EXACTLY one owner in the contract's "## File ownership"
#      — an unowned file is unplannable work; a dual-owned file is a merge
#      conflict on schedule.
#
# Exit 0 = pass. Exit 1 = fail, every violation named on stdout.
set -uo pipefail

PLAN="${1:-}"
CONTRACT="${2:-}"

if [ -z "$PLAN" ] || [ ! -f "$PLAN" ]; then
  echo "usage: plan-lint.sh <plan.md> [contract.md]" >&2
  exit 2
fi

fail=0

# ── 1. Failure policy ────────────────────────────────────────────────────
if grep -q '^## Failure policy' "$PLAN"; then
  echo "  ✓ Failure policy present"
else
  echo "  ✗ missing '## Failure policy' — the build loop has no circuit breaker"
  fail=1
fi

# ── 2. Command per task ──────────────────────────────────────────────────
TASKS=$(grep -c '^### Task' "$PLAN" || true)
# Count Command: lines inside task blocks only — a whole-file grep let
# 'Command:' in Failure-policy prose cover for a Command-less task.
CMDS=$(awk '/^### Task/{f=1} /^## /{f=0} f' "$PLAN" | grep -c 'Command:' || true)
if [ "${CMDS:-0}" -ge "${TASKS:-0}" ]; then
  echo "  ✓ every task carries a Command ($CMDS/$TASKS)"
else
  echo "  ✗ $TASKS tasks but only $CMDS Command lines — a Command-less task cannot be verified by the loop"
  fail=1
fi

# ── 3. Parallel ownership completeness ───────────────────────────────────
# Extract the Parallel layout section; "Sequential" → nothing to check.
# Anchored to a line START (optional bullet) — a bare substring grep let
# 'Not sequential — two tracks run concurrently' skip the ownership check.
LAYOUT=$(awk '/^## Parallel layout/{f=1;next} /^## /{f=0} f' "$PLAN")
if printf '%s' "$LAYOUT" | grep -qiE '^[[:space:]]*([-*][[:space:]]*)?sequential'; then
  echo "  ✓ sequential layout — ownership check not applicable"
  echo "plan-lint: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
  exit "$fail"
fi

# Resolve the contract file.
if [ -z "$CONTRACT" ]; then
  REL=$(printf '%s' "$LAYOUT" | grep -oE '`[^`]+\.md`' | head -1 | tr -d '`')
  if [ -n "$REL" ]; then
    PLAN_DIR="$(cd "$(dirname "$PLAN")" && pwd)"
    ROOT="$(git -C "$PLAN_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$PLAN_DIR")"
    for cand in "$PLAN_DIR/$REL" "$ROOT/$REL" "$REL"; do
      [ -f "$cand" ] && CONTRACT="$cand" && break
    done
  fi
fi

if [ -z "$CONTRACT" ] || [ ! -f "$CONTRACT" ]; then
  if [ -n "$LAYOUT" ]; then
    echo "  ✗ parallel layout declared but no cohesion contract found — Iron Rule 2: no parallel agents without a contract"
    fail=1
  else
    echo "  ✗ no '## Parallel layout' section — declare 'Sequential — single owner.' or the contract path"
    fail=1
  fi
  echo "plan-lint: FAIL"
  exit 1
fi

OWNERSHIP=$(awk '/^## File ownership/{f=1;next} /^## /{f=0} f' "$CONTRACT")
if [ -z "$OWNERSHIP" ]; then
  echo "  ✗ contract has no '## File ownership' section"
  echo "plan-lint: FAIL"
  exit 1
fi

# Every backticked path in the plan's Files-to-touch must appear under
# exactly one owner line.
FILES=$(awk '/^## Files to touch/{f=1;next} /^## /{f=0} f' "$PLAN" \
        | grep -oE '`[^`]+`' | tr -d '`' | sort -u)
if [ -z "$FILES" ]; then
  echo "  ✗ parallel plan has no backticked paths under '## Files to touch'"
  fail=1
fi

OWN_OK=1
while IFS= read -r f; do
  [ -n "$f" ] || continue
  # Count OWNER LINES that mention the exact backticked path.
  N=$(printf '%s\n' "$OWNERSHIP" | grep -cF "\`$f\`" || true)
  if [ "${N:-0}" -eq 0 ]; then
    echo "  ✗ unowned file: \`$f\` — in Files-to-touch but under no owner in the contract"
    OWN_OK=0; fail=1
  elif [ "${N:-0}" -gt 1 ]; then
    echo "  ✗ dual-owned file: \`$f\` — appears under $N owner lines; a path belongs to exactly one owner"
    OWN_OK=0; fail=1
  fi
done <<EOF
$FILES
EOF
[ "$OWN_OK" -eq 1 ] && [ -n "$FILES" ] && echo "  ✓ every touched file has exactly one owner"

echo "plan-lint: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
exit "$fail"
