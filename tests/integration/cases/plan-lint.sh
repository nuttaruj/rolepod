#!/bin/bash
# plan-lint — proves the write-plan loop-runnable lint catches a plan whose
# tasks lack a runnable Command or whose Failure policy is missing, and
# passes a properly filled plan. Sibling of spec-lint.sh (write-spec).
#
# The lint (as documented in write-plan SKILL.md self-review):
#   grep -q '^## Failure policy' <plan> &&
#   [ "$(grep -c 'Command:' <plan>)" -ge "$(grep -c '^### Task' <plan>)" ]
set -euo pipefail

fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

plan_lint() { # $1 = plan file; returns 0 = lint pass
  grep -q '^## Failure policy' "$1" \
    && [ "$(grep -c 'Command:' "$1")" -ge "$(grep -c '^### Task' "$1")" ]
}

# ── Dirty plan: 2 tasks, 1 Command, no Failure policy → must FAIL lint ──
cat > "$TMP/dirty.md" <<'EOF'
# Feature Plan

## Tasks

### Task 1: build the service
- [ ] Files: app/service.rb
- [ ] Command: bundle exec rspec spec/service_spec.rb

### Task 2: wire the controller
- [ ] Files: app/controller.rb
- [ ] Test / evidence: request spec

## Done criteria
All green.
EOF

if plan_lint "$TMP/dirty.md"; then
  echo "  ✗ lint passed a plan with a Command-less task and no Failure policy"
  fail=$((fail+1))
else
  echo "  ✓ lint catches missing Command + missing Failure policy"
fi

# ── Clean plan: Command per task + Failure policy → must PASS lint ──────
cat > "$TMP/clean.md" <<'EOF'
# Feature Plan

## Tasks

### Task 1: build the service
- [ ] Files: app/service.rb
- [ ] Command: bundle exec rspec spec/service_spec.rb

### Task 2: wire the controller
- [ ] Files: app/controller.rb
- [ ] Command: bundle exec rspec spec/requests/controller_spec.rb

## Done criteria
All green.

## Failure policy
Default: a failing Command → debug-issue → re-run the same Command; stop
after 3 failed attempts on one task, or on oscillation.
EOF

if plan_lint "$TMP/clean.md"; then
  echo "  ✓ lint passes a properly filled plan"
else
  echo "  ✗ lint rejected a clean plan"
  fail=$((fail+1))
fi

# ── The canonical example plans must themselves pass the lint ───────────
# (the audit caught the "good" examples teaching a lint-failing shape).
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EXAMPLES="$REPO_DIR/core/skills/write-plan/examples/plan-examples.md"
GOOD_COUNT=$(grep -c '^### Good' "$EXAMPLES")
FP_COUNT=$(grep -c '^## Failure policy' "$EXAMPLES")
if [ "$FP_COUNT" -ge "$GOOD_COUNT" ]; then
  echo "  ✓ every Good example plan carries a Failure policy ($FP_COUNT/$GOOD_COUNT)"
else
  echo "  ✗ Good example plans missing Failure policy ($FP_COUNT/$GOOD_COUNT)"
  fail=$((fail+1))
fi
grep -q '\- \[ \] Command:' "$EXAMPLES" \
  && echo "  ✓ example plans carry checkbox Command fields" \
  || { echo "  ✗ example plans missing checkbox Command fields"; fail=$((fail+1)); }

# ── scripts/plan-lint.sh — ownership completeness on parallel plans ─────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LINT="$REPO_DIR/scripts/plan-lint.sh"
cat > "$TMP/par-plan.md" <<'EOF'
# Par Plan
## Files to touch
- `api/users.py` — endpoint
- `ui/form.tsx` — form
### Task 1: api
- [ ] Command: pytest api/
## Parallel layout
Two tracks per `par-contract.md`; merge order: api → ui.
## Failure policy
Default: debug-issue; stop after 3.
EOF
cat > "$TMP/par-contract.md" <<'EOF'
# Par Contract
## File ownership
- `backend-developer`: `api/users.py`
- `frontend-developer`: `ui/form.tsx`
EOF
bash "$LINT" "$TMP/par-plan.md" "$TMP/par-contract.md" >/dev/null \
  && echo "  ✓ plan-lint.sh passes a fully-owned parallel plan" \
  || { echo "  ✗ plan-lint.sh rejected a fully-owned parallel plan"; fail=$((fail+1)); }

sed 's|- `frontend-developer`: `ui/form.tsx`||' "$TMP/par-contract.md" > "$TMP/par-unowned.md"
if bash "$LINT" "$TMP/par-plan.md" "$TMP/par-unowned.md" >/dev/null; then
  echo "  ✗ plan-lint.sh passed a plan with an unowned file"; fail=$((fail+1))
else
  echo "  ✓ plan-lint.sh catches an unowned file"
fi

printf -- '- `frontend-developer`: `ui/form.tsx`, `api/users.py`\n' >> "$TMP/par-contract.md"
if bash "$LINT" "$TMP/par-plan.md" "$TMP/par-contract.md" >/dev/null; then
  echo "  ✗ plan-lint.sh passed a dual-owned file"; fail=$((fail+1))
else
  echo "  ✓ plan-lint.sh catches a dual-owned file"
fi

cat > "$TMP/seq-plan.md" <<'EOF'
# Seq Plan
## Files to touch
- `api/users.py` — endpoint
### Task 1: api
- [ ] Command: pytest api/
## Parallel layout
Sequential — single owner.
## Failure policy
Default: debug-issue; stop after 3.
EOF
bash "$LINT" "$TMP/seq-plan.md" >/dev/null \
  && echo "  ✓ plan-lint.sh skips ownership on a sequential plan" \
  || { echo "  ✗ plan-lint.sh failed a clean sequential plan"; fail=$((fail+1)); }

# ── Session-split protocol is documented where the contract points ──────
grep -q '^## Session split' "$REPO_DIR/core/skills/write-plan/templates/cohesion-contract-template.md" \
  && echo "  ✓ contract template carries the Session split section" \
  || { echo "  ✗ contract template missing Session split section"; fail=$((fail+1)); }
grep -q '^## Session-split tracks' "$REPO_DIR/core/skills/implement-plan/references/subagent-dispatch.md" \
  && echo "  ✓ subagent-dispatch documents session-split execution" \
  || { echo "  ✗ subagent-dispatch missing session-split protocol"; fail=$((fail+1)); }

# ── Template default policy must be body text, not a delete-me hint ─────
TEMPLATE="$REPO_DIR/core/skills/write-plan/templates/plan-template.md"
awk '/^## Failure policy/{f=1;next} /^## /{f=0} f' "$TEMPLATE" | grep -q '^Default:' \
  && echo "  ✓ template Failure policy default survives hint deletion" \
  || { echo "  ✗ template Failure policy default is hint-only (vanishes when filled)"; fail=$((fail+1)); }

if [ "$fail" -eq 0 ]; then
  echo "  ✓ pass"
  exit 0
else
  echo "  ✗ fail ($fail)"
  exit 1
fi
