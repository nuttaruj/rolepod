#!/bin/bash
# plan-lint — proves the write-plan loop-runnable lint catches a plan whose
# tasks lack a runnable Command or whose Failure policy is missing, and
# passes a properly filled plan. Sibling of spec-lint.sh (write-spec).
#
# The lint (as documented in write-plan SKILL.md self-review):
#   grep -q '^## Failure policy' <plan> && every `### Task` block carries its
#   own Command: line (per block — scripts/plan-lint.sh and the inline awk).
set -euo pipefail

fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

plan_lint() { # $1 = plan file; returns 0 = lint pass
  grep -q '^## Failure policy' "$1" \
    && awk '/^### (Task ?|T)[0-9]/{t++;c[t]=0;i=1;next} /^## /{i=0} i&&/Command:/{c[t]=1} END{if(!t)exit 1;for(k=1;k<=t;k++)if(!c[k])exit 1}' "$1"
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
after 2 failed attempts on one task (never a 4th), or on oscillation.
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
Default: debug-issue; stop after 2 failed attempts (never a 4th).
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
Default: debug-issue; stop after 2 failed attempts (never a 4th).
EOF
bash "$LINT" "$TMP/seq-plan.md" >/dev/null \
  && echo "  ✓ plan-lint.sh skips ownership on a sequential plan" \
  || { echo "  ✗ plan-lint.sh failed a clean sequential plan"; fail=$((fail+1)); }

# ── v2.42.0 false-pass regression guards (run the SCRIPT, not plan_lint) ──
# Bug 1: 'Command:' in Failure-policy prose covered for a Command-less task.
cat > "$TMP/prose-cmd.md" <<'EOF'
# Prose Plan
### Task 1: api
- [ ] Files: api/users.py
## Parallel layout
Sequential — single owner.
## Failure policy
On a failing Command: re-run once, then stop and report.
EOF
if bash "$LINT" "$TMP/prose-cmd.md" >/dev/null; then
  echo "  ✗ plan-lint.sh passed a Command-less task covered by prose 'Command:'"; fail=$((fail+1))
else
  echo "  ✓ plan-lint.sh counts Command: inside task blocks only"
fi

# Bug 2: 'Not sequential — …' was classified sequential, skipping ownership.
cat > "$TMP/notseq-plan.md" <<'EOF'
# NotSeq Plan
## Files to touch
- `api/users.py` — endpoint
### Task 1: api
- [ ] Command: pytest api/
## Parallel layout
Not sequential — two tracks run concurrently. Contract: `missing-contract.md`
## Failure policy
Default: stop.
EOF
if bash "$LINT" "$TMP/notseq-plan.md" >/dev/null; then
  echo "  ✗ plan-lint.sh treated 'Not sequential' as sequential (ownership check skipped)"; fail=$((fail+1))
else
  echo "  ✓ plan-lint.sh requires a contract when layout is not sequential"
fi

# Anchored regex must still accept a bullet-prefixed sequential declaration.
cat > "$TMP/bullet-seq.md" <<'EOF'
# Bullet Seq Plan
### Task 1: api
- [ ] Command: pytest api/
## Parallel layout
- Sequential — single owner.
## Failure policy
Default: stop.
EOF
bash "$LINT" "$TMP/bullet-seq.md" >/dev/null \
  && echo "  ✓ plan-lint.sh accepts a bullet-prefixed Sequential declaration" \
  || { echo "  ✗ plan-lint.sh rejected '- Sequential — single owner.'"; fail=$((fail+1)); }

# Bug 3 (v2.81.0, WP-01): the Command check was an aggregate — Task 1's extra
# Commands covered for Task 2's none, and a plan with zero tasks passed (0>=0).
cat > "$TMP/padded.md" <<'EOF'
# Padded Plan
### Task 1: api
- [ ] Command: pytest api/
- [ ] Command: pytest api/ -k smoke
### Task 2: ui
- [ ] Test / evidence: view the page
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUT=$(bash "$LINT" "$TMP/padded.md" || true)
if printf '%s' "$OUT" | grep -q 'missing Command: Task 2'; then
  echo "  ✓ plan-lint.sh names the Command-less task even when a sibling has extras"
else
  echo "  ✗ plan-lint.sh let Task 1's extra Commands cover for Task 2"; fail=$((fail+1))
fi
cat > "$TMP/one-each.md" <<'EOF'
# One Each Plan
### Task 1: api
- [ ] Command: pytest api/
### Task 2: ui
- [ ] Command: npm test
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
bash "$LINT" "$TMP/one-each.md" >/dev/null \
  && echo "  ✓ plan-lint.sh passes one Command per task" \
  || { echo "  ✗ plan-lint.sh rejected a plan with one Command per task"; fail=$((fail+1)); }
cat > "$TMP/no-tasks.md" <<'EOF'
# Empty Plan
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
if bash "$LINT" "$TMP/no-tasks.md" >/dev/null; then
  echo "  ✗ plan-lint.sh passed a plan with zero tasks"; fail=$((fail+1))
else
  echo "  ✓ plan-lint.sh rejects a plan with no ### Task blocks"
fi

# ── Blocked-by graph (v2.90.0) ──────────────────────────────────────────
# The graph IS the plan's order. Refs must resolve, no cycle, no task left
# without the field once any task has it; a `### T1 —` heading (real
# CourtBook plan) counts as a task — the lint rejected that plan wholesale.
mk() { # $1 = file, $2.. = task blocks (heading + Blocked by), one arg each
  local f="$1"; shift
  { echo "# G"; for blk in "$@"; do printf '%s\n- [ ] Command: true\n' "$blk"; done
    printf '## Parallel layout\nSequential — single owner.\n## Failure policy\nDefault: stop.\n'; } > "$f"
}
mk "$TMP/g-good.md" $'### Task 1: a\n- **Blocked by:** none' $'### Task 2: b\n- **Blocked by:** Task 1' \
   $'### Task 3: c\n- **Blocked by:** none — builds against the mock (T2 does not gate it)' $'### Task 4: d\n- **Blocked by:** Task 2, Task 3'
RC=0; OUT=$(bash "$LINT" "$TMP/g-good.md" 2>&1) || RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'graph resolves, no cycle (4 tasks)' \
  && echo "  ✓ plan-lint.sh resolves a Blocked-by graph" \
  || { echo "  ✗ plan-lint.sh rejected a valid Blocked-by graph: $OUT"; fail=$((fail+1)); }
echo "$OUT" | grep -q 'parallel candidates: Tasks 1, 3' \
  && echo "  ✓ plan-lint.sh names the roots as parallel candidates (aside after none ignored)" \
  || { echo "  ✗ plan-lint.sh missed the parallel-candidate advisory: $OUT"; fail=$((fail+1)); }

mk "$TMP/g-ref.md" $'### Task 1: a\n- Blocked by: none' $'### Task 2: b\n- Blocked by: Task 7'
RC=0; OUT=$(bash "$LINT" "$TMP/g-ref.md" 2>&1) || RC=$?
[ "$RC" -ne 0 ] && echo "$OUT" | grep -q 'blocked by Task 7 — no such task' && ! echo "$OUT" | grep -q 'cycle' \
  && echo "  ✓ plan-lint.sh catches an unresolved Blocked-by ref (and does not call it a cycle)" \
  || { echo "  ✗ unresolved ref handling: rc=$RC $OUT"; fail=$((fail+1)); }

mk "$TMP/g-cycle.md" $'### Task 1: a\n- Blocked by: Task 3' $'### Task 2: b\n- Blocked by: Task 1' $'### Task 3: c\n- Blocked by: Task 2'
RC=0; OUT=$(bash "$LINT" "$TMP/g-cycle.md" 2>&1) || RC=$?
if echo "$OUT" | grep -q 'cycle among Tasks 1, 2, 3'; then
  echo "  ✓ plan-lint.sh catches a Blocked-by cycle"
else echo "  ✗ plan-lint.sh missed a 3-task cycle"; fail=$((fail+1)); fi

mk "$TMP/g-mixed.md" $'### T1 — a\n- Blocked by: none' $'### T2 — b'
RC=0; OUT=$(bash "$LINT" "$TMP/g-mixed.md" 2>&1) || RC=$?
if echo "$OUT" | grep -q 'Task 2 has no Blocked by (other tasks do)'; then
  echo "  ✓ plan-lint.sh flags a task missing Blocked by once any task has it"
else echo "  ✗ plan-lint.sh passed a half-graphed plan"; fail=$((fail+1)); fi

mk "$TMP/g-theads.md" $'### T1 — a\n- Blocked by: none' $'### T2 — b\n- Blocked by: T1'
RC=0; OUT=$(bash "$LINT" "$TMP/g-theads.md" 2>&1) || RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'Command (2/2)' \
  && echo "  ✓ plan-lint.sh accepts ### TN — headings as tasks" \
  || { echo "  ✗ plan-lint.sh still rejects ### TN — headings: $OUT"; fail=$((fail+1)); }

mk "$TMP/g-dup.md" $'### Task 1: a\n- Blocked by: none' $'### Task 1: a again\n- Blocked by: none'
RC=0; OUT=$(bash "$LINT" "$TMP/g-dup.md" 2>&1) || RC=$?
if echo "$OUT" | grep -q 'duplicate task id 1'; then
  echo "  ✓ plan-lint.sh catches a duplicate task id"
else echo "  ✗ plan-lint.sh passed two tasks numbered 1"; fail=$((fail+1)); fi

mk "$TMP/g-none.md" $'### Task 1: a' $'### Task 2: b'
RC=0; OUT=$(bash "$LINT" "$TMP/g-none.md" 2>&1) || RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'no Blocked by fields' \
  && echo "  ✓ plan-lint.sh advises (not fails) a pre-v2.90.0 plan with no Blocked by at all" \
  || { echo "  ✗ legacy plan handling: rc=$RC $OUT"; fail=$((fail+1)); }

# ── Template + examples carry the human line and the graph field ────────
for needle in '\*\*Delivers:\*\*' '\*\*Blocked by:\*\*' '^## Changes during build' '^## Follow-ups'; do
  grep -qE "$needle" "$REPO_DIR/core/skills/write-plan/templates/plan-template.md" \
    && echo "  ✓ template carries $needle" \
    || { echo "  ✗ template missing $needle"; fail=$((fail+1)); }
done
N_TASK=$(grep -cE '^### Task [0-9]' "$REPO_DIR/core/skills/write-plan/examples/plan-examples.md" || true)
N_BB=$(grep -c '^- Blocked by:' "$REPO_DIR/core/skills/write-plan/examples/plan-examples.md" || true)
N_DL=$(grep -c '^- Delivers:' "$REPO_DIR/core/skills/write-plan/examples/plan-examples.md" || true)
[ "$N_BB" -eq "$N_TASK" ] && [ "$N_DL" -eq "$N_TASK" ] \
  && echo "  ✓ every example task carries Delivers + Blocked by ($N_TASK)" \
  || { echo "  ✗ example tasks=$N_TASK Delivers=$N_DL Blocked-by=$N_BB"; fail=$((fail+1)); }
grep -q 'Task 1 → 2 → 3' "$REPO_DIR/core/skills/write-plan/examples/plan-examples.md" \
  && { echo "  ✗ example still restates the order in prose"; fail=$((fail+1)); } \
  || echo "  ✓ examples no longer restate the order outside Blocked by"

# ── Follow-ups have one home and leave with a destination (v2.91.0) ─────
grep -q '## Follow-ups' "$REPO_DIR/core/skills/implement-plan/SKILL.md" \
  && echo "  ✓ implement-plan parks new scope under the plan's ## Follow-ups" \
  || { echo "  ✗ implement-plan still says 'write it down' with no home"; fail=$((fail+1)); }
grep -q '^## Follow-ups carried' "$REPO_DIR/core/skills/finish-work/templates/finish-menu.md" \
  && echo "  ✓ finish menu carries the plan's Follow-ups out with a destination" \
  || { echo "  ✗ finish menu has no Follow-ups section"; fail=$((fail+1)); }
grep -q -- '-v2.md' "$REPO_DIR/core/skills/write-plan/SKILL.md" \
  && { echo "  ✗ write-plan still versions plans as -v2.md (spec uses a new date)"; fail=$((fail+1)); } \
  || echo "  ✓ plan re-planning uses the spec's dated-file convention"

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

# ── Advisories (v2.144.0) — prefactor smell + nothing to dispatch ────────
# Both are ADVISORY: never fail, exit code unchanged either way.
mkf() { # $1 = file, $2.. = task blocks (heading, Blocked by, Files, Owner)
  local f="$1"; shift
  { echo "# G"; for blk in "$@"; do printf '%s\n- [ ] Command: true\n' "$blk"; done
    printf '## Parallel layout\nSequential — single owner.\n## Failure policy\nDefault: stop.\n'; } > "$f"
}

# (a) 3 tasks, same file, no edges between any pair → advisory, still PASS/rc0.
mkf "$TMP/pf-no-edge.md" \
  $'### Task 1: a\n- Blocked by: none\n- [ ] Files: `scripts/x.sh`' \
  $'### Task 2: b\n- Blocked by: none\n- [ ] Files: `scripts/x.sh`' \
  $'### Task 3: c\n- Blocked by: none\n- [ ] Files: `scripts/x.sh`'
RC=0; OUT=$(bash "$LINT" "$TMP/pf-no-edge.md" 2>&1) || RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'prefactor smell: `scripts/x.sh` in Task 1 and Task 2 with no edge' \
  && echo "$OUT" | grep -q 'plan-lint: PASS'; then
  echo "  ✓ plan-lint.sh advises a prefactor smell for a shared file with no edge (exit 0)"
else
  echo "  ✗ prefactor-smell advisory missing or wrong exit: rc=$RC $OUT"; fail=$((fail+1))
fi

# Same file, same tasks, now chained 1→2→3 → every pair connected, silent.
mkf "$TMP/pf-chained.md" \
  $'### Task 1: a\n- Blocked by: none\n- [ ] Files: `scripts/x.sh`' \
  $'### Task 2: b\n- Blocked by: Task 1\n- [ ] Files: `scripts/x.sh`' \
  $'### Task 3: c\n- Blocked by: Task 2\n- [ ] Files: `scripts/x.sh`'
RC=0; OUT=$(bash "$LINT" "$TMP/pf-chained.md" 2>&1) || RC=$?
if [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q 'prefactor smell'; then
  echo "  ✓ plan-lint.sh stays silent once the shared-file tasks are chained"
else
  echo "  ✗ plan-lint.sh still flagged a prefactor smell once tasks were chained: rc=$RC $OUT"; fail=$((fail+1))
fi

# (b) 3 tasks, every Owner: names Lead (plain / aside / role-tagged) → advisory.
cat > "$TMP/lead-3.md" <<'EOF'
# G
### Task 1: a
- Blocked by: none
- [ ] Command: true
- Owner: Lead
### Task 2: b
- Blocked by: Task 1
- [ ] Command: true
- Owner: Lead (self-do)
### Task 3: c
- Blocked by: Task 2
- [ ] Command: true
- Owner: devops-sre (Lead self-do)
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/lead-3.md" 2>&1) || RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'every Owner is Lead (3 tasks) — nothing to dispatch' \
  && echo "$OUT" | grep -q 'plan-lint: PASS'; then
  echo "  ✓ plan-lint.sh advises nothing-to-dispatch when every Owner is Lead (exit 0)"
else
  echo "  ✗ nothing-to-dispatch advisory missing or wrong exit: rc=$RC $OUT"; fail=$((fail+1))
fi

# 2 tasks, both Lead → below the ≥3-task floor, silent.
cat > "$TMP/lead-2.md" <<'EOF'
# G
### Task 1: a
- Blocked by: none
- [ ] Command: true
- Owner: Lead
### Task 2: b
- Blocked by: Task 1
- [ ] Command: true
- Owner: Lead
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/lead-2.md" 2>&1) || RC=$?
if [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q 'nothing to dispatch'; then
  echo "  ✓ plan-lint.sh stays silent on a 2-task all-Lead plan (below the floor)"
else
  echo "  ✗ plan-lint.sh flagged nothing-to-dispatch below the 3-task floor: rc=$RC $OUT"; fail=$((fail+1))
fi

# ── Shaped like the shipped ticket-runner-cohesion plan: 8 tasks, 5 of them
# sharing `scripts/cross-family.sh`, edges 1→2,2→3,2→4,2→5,3→6,5→7,{6,7}→8,
# every Owner devops-sre (Lead self-do) or Lead → BOTH advisories fire.
cat > "$TMP/shipped-shape.md" <<'EOF'
# G
### Task 1: setup
- Blocked by: none
- [ ] Command: true
- [ ] Files: `scripts/setup.sh`
- Owner: devops-sre (Lead self-do)
### Task 2: core
- Blocked by: Task 1
- [ ] Command: true
- [ ] Files: `scripts/cross-family.sh`
- Owner: devops-sre (Lead self-do)
### Task 3: track-a
- Blocked by: Task 2
- [ ] Command: true
- [ ] Files: `scripts/cross-family.sh`
- Owner: devops-sre (Lead self-do)
### Task 4: track-b
- Blocked by: Task 2
- [ ] Command: true
- [ ] Files: `docs/foo.md`
- Owner: Lead
### Task 5: track-c
- Blocked by: Task 2
- [ ] Command: true
- [ ] Files: `scripts/cross-family.sh`
- Owner: devops-sre (Lead self-do)
### Task 6: from-a
- Blocked by: Task 3
- [ ] Command: true
- [ ] Files: `scripts/cross-family.sh`
- Owner: devops-sre (Lead self-do)
### Task 7: from-c
- Blocked by: Task 5
- [ ] Command: true
- [ ] Files: `scripts/cross-family.sh`
- Owner: devops-sre (Lead self-do)
### Task 8: join
- Blocked by: Task 6, Task 7
- [ ] Command: true
- [ ] Files: `scripts/join.sh`
- Owner: Lead
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/shipped-shape.md" 2>&1) || RC=$?
if [ "$RC" -eq 0 ] \
  && echo "$OUT" | grep -q 'prefactor smell: `scripts/cross-family.sh` in Task 3 and Task 5' \
  && echo "$OUT" | grep -q 'every Owner is Lead (8 tasks) — nothing to dispatch' \
  && echo "$OUT" | grep -q 'plan-lint: PASS'; then
  echo "  ✓ plan-lint.sh fires both advisories on a shipped-shaped 8-task plan (exit 0)"
else
  echo "  ✗ shipped-shaped plan missed an advisory or changed exit code: rc=$RC $OUT"; fail=$((fail+1))
fi
# The same fixture must NOT flag a connected pair (Task 2 reaches everything).
if echo "$OUT" | grep -qE 'prefactor smell: `scripts/cross-family\.sh` in Task 2 and'; then
  echo "  ✗ plan-lint.sh flagged Task 2, which blocks every other file-sharing task"; fail=$((fail+1))
else
  echo "  ✓ plan-lint.sh does not flag a task pair the graph already connects"
fi

# Review round 1 regression: a legacy plan with NO Blocked-by field anywhere
# used to `exit 0` before either advisory ran. Both must still fire — the
# graph being empty means no dependency path exists, so the file-sharing
# pair below is correctly a prefactor-smell candidate too.
cat > "$TMP/legacy-no-graph.md" <<'EOF'
# G
### Task 1: a
- [ ] Command: true
- [ ] Files: `scripts/x.sh`
- Owner: Lead
### Task 2: b
- [ ] Command: true
- [ ] Files: `scripts/x.sh`
- Owner: Lead
### Task 3: c
- [ ] Command: true
- Owner: Lead
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/legacy-no-graph.md" 2>&1) || RC=$?
if [ "$RC" -eq 0 ] \
  && echo "$OUT" | grep -q 'no Blocked by fields' \
  && echo "$OUT" | grep -q 'prefactor smell: `scripts/x.sh` in Task 1 and Task 2' \
  && echo "$OUT" | grep -q 'every Owner is Lead (3 tasks)' \
  && echo "$OUT" | grep -q 'plan-lint: PASS'; then
  echo "  ✓ plan-lint.sh fires both advisories on a plan with no Blocked-by graph at all"
else
  echo "  ✗ a legacy plan with no Blocked-by field lost one or both advisories: rc=$RC $OUT"; fail=$((fail+1))
fi

# A missing Owner: line (not just a non-Lead one) must also suppress (b) —
# a mutated "always call it Lead" implementation would pass without this.
cat > "$TMP/missing-owner-line.md" <<'EOF'
# G
### Task 1: a
- Blocked by: none
- [ ] Command: true
- Owner: Lead
### Task 2: b
- Blocked by: Task 1
- [ ] Command: true
### Task 3: c
- Blocked by: Task 2
- [ ] Command: true
- Owner: Lead
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/missing-owner-line.md" 2>&1) || RC=$?
if [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q 'nothing to dispatch'; then
  echo "  ✓ plan-lint.sh stays silent when one task carries no Owner: line at all"
else
  echo "  ✗ plan-lint.sh advised nothing-to-dispatch despite a Owner-less task: rc=$RC $OUT"; fail=$((fail+1))
fi

# A path repeated twice on the SAME Files: line must not double the advisory.
cat > "$TMP/dup-path-one-line.md" <<'EOF'
# G
### Task 1: a
- Blocked by: none
- [ ] Command: true
- [ ] Files: `scripts/x.sh`, `scripts/x.sh`
### Task 2: b
- Blocked by: none
- [ ] Command: true
- [ ] Files: `scripts/x.sh`
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/dup-path-one-line.md" 2>&1) || RC=$?
N_LINES=$(printf '%s\n' "$OUT" | grep -c 'prefactor smell: `scripts/x.sh` in Task 1 and Task 2')
if [ "$RC" -eq 0 ] && [ "$N_LINES" -eq 1 ]; then
  echo "  ✓ plan-lint.sh de-dupes a path repeated twice on one Files: line"
else
  echo "  ✗ a repeated Files: path produced $N_LINES advisory lines (want 1): rc=$RC $OUT"; fail=$((fail+1))
fi

# Bare (non-backticked) Files: paths — the shape real plans actually write
# (template + examples list Files as a plain comma-separated line; the
# external-implement plan that motivated this check, 2026-09-16, does too).
# A backtick-only parse was a no-op on them — this is the exact shipped
# shape: 8 tasks, 5 sharing scripts/cross-family.sh, edges
# 1→2,2→3,2→4,2→5,3→6,5→7,{6,7}→8, every Owner devops-sre (Lead self-do).
cat > "$TMP/bare-shipped-shape.md" <<'EOF'
# G
### Task 1: setup
- Blocked by: none
- [ ] Command: true
- [x] **Files:** scripts/setup.sh
- Owner: devops-sre (Lead self-do)
### Task 2: core
- Blocked by: Task 1
- [ ] Command: true
- [x] **Files:** scripts/cross-family.sh, tests/integration/cases/cross-family-implement.sh
- Owner: devops-sre (Lead self-do)
### Task 3: track-a
- Blocked by: Task 2
- [ ] Command: true
- [x] **Files:** scripts/cross-family.sh
- Owner: devops-sre (Lead self-do)
### Task 4: track-b
- Blocked by: Task 2
- [ ] Command: true
- [x] **Files:** docs/foo.md
- Owner: Lead
### Task 5: track-c
- Blocked by: Task 2
- [ ] Command: true
- [x] **Files:** scripts/cross-family.sh
- Owner: devops-sre (Lead self-do)
### Task 6: from-a
- Blocked by: Task 3
- [ ] Command: true
- [x] **Files:** scripts/cross-family.sh
- Owner: devops-sre (Lead self-do)
### Task 7: from-c
- Blocked by: Task 5
- [ ] Command: true
- [x] **Files:** scripts/cross-family.sh
- Owner: devops-sre (Lead self-do)
### Task 8: join
- Blocked by: Task 6, Task 7
- [ ] Command: true
- [x] **Files:** scripts/join.sh
- Owner: Lead
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/bare-shipped-shape.md" 2>&1) || RC=$?
if [ "$RC" -eq 0 ] \
  && echo "$OUT" | grep -q 'prefactor smell: `scripts/cross-family.sh` in Task 3 and Task 5' \
  && echo "$OUT" | grep -q 'every Owner is Lead (8 tasks) — nothing to dispatch' \
  && echo "$OUT" | grep -q 'plan-lint: PASS'; then
  echo "  ✓ plan-lint.sh reads bare (non-backticked) Files: paths — both advisories fire"
else
  echo "  ✗ bare-path shipped-shaped plan missed an advisory: rc=$RC $OUT"; fail=$((fail+1))
fi

# The same bare-path shape, but fully chained → every pair connected, silent.
# Also exercises the filler-word / narrative-Files ignore rule ("and its
# spec") and the placeholder-token ignore rule alongside real bare paths.
cat > "$TMP/bare-chained.md" <<'EOF'
# G
### Task 1: a
- Blocked by: none
- [ ] Command: true
- [ ] Files: scripts/x.sh, app/service.rb and its spec
- Owner: backend-developer
### Task 2: b
- Blocked by: Task 1
- [ ] Command: true
- [ ] Files: scripts/x.sh
- Owner: backend-developer
### Task 3: c
- Blocked by: Task 2
- [ ] Command: true
- [ ] Files: scripts/x.sh
- Owner: backend-developer
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/bare-chained.md" 2>&1) || RC=$?
if [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q 'prefactor smell'; then
  echo "  ✓ plan-lint.sh stays silent on chained bare-path tasks (filler words ignored)"
else
  echo "  ✗ plan-lint.sh flagged a prefactor smell on chained bare-path tasks: rc=$RC $OUT"; fail=$((fail+1))
fi

# A slashless bare token (extension only, e.g. a root-level script) must
# still be caught by the dot+extension branch on its own — coverage for the
# mawk-safe `/\.[[:alnum:]]+$/` (an interval like `{1,5}` is unreliable
# across awk implementations; this repo targets the one-true-awk dialect).
cat > "$TMP/bare-slashless.md" <<'EOF'
# G
### Task 1: a
- Blocked by: none
- [ ] Command: true
- [ ] Files: foo.sh
- Owner: backend-developer
### Task 2: b
- Blocked by: none
- [ ] Command: true
- [ ] Files: foo.sh
- Owner: backend-developer
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/bare-slashless.md" 2>&1) || RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'prefactor smell: `foo.sh` in Task 1 and Task 2'; then
  echo "  ✓ plan-lint.sh catches a slashless bare path via the extension branch alone"
else
  echo "  ✗ a slashless extension-only bare path was not caught: rc=$RC $OUT"; fail=$((fail+1))
fi

if [ "$fail" -eq 0 ]; then
  echo "  ✓ pass"
  exit 0
else
  echo "  ✗ fail ($fail)"
  exit 1
fi
