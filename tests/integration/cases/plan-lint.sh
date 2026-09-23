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
# --brief now resolves the cross-family pool's review tier (spec D1) through
# the runner beside scripts/plan-lint.sh — HOME is pointed at an empty
# fixture for the whole file so the machine's own ~/.rolepod/cross-family
# (if any) never leaks into a --brief assertion below; the runner itself
# still comes from beside the script (dirname "$0"), never from here.
export HOME="$TMP/home"; mkdir -p "$HOME"

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

# ── every blocker on the line, and a field is a field line only (t2) ────
# Three blockers each with their own (why) aside must ALL resolve — a
# truncate-at-first-paren bug keeps only the FIRST ref (Task 1) and drops
# Task 3 and Task 4 entirely. Task 3 shares src/shared3.sh and Task 4
# shares src/shared4.sh with Task 5; the Blocked-by edge is what connects
# each pair in the prefactor-smell graph, so a dropped ref shows up as a
# false "no edge" advisory on the file the dropped ref should have wired.
cat > "$TMP/asides-all.md" <<'EOF'
# Asides Plan
### Task 1: a
- **Files:** `src/a.sh`
- **Blocked by:** none
- [ ] Command: true
### Task 2: b
- **Files:** `src/b.sh`
- **Blocked by:** none
- [ ] Command: true
### Task 3: c
- **Files:** `src/shared3.sh`
- **Blocked by:** none
- [ ] Command: true
### Task 4: d
- **Files:** `src/shared4.sh`
- **Blocked by:** none
- [ ] Command: true
### Task 5: e
- **Files:** `src/shared3.sh` `src/shared4.sh`
- **Blocked by:** Task 1 (why), Task 3 (why), Task 4 (why)
- [ ] Command: true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/asides-all.md" 2>&1) || RC=$?
[ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q 'prefactor smell' \
  && echo "  ✓ plan-lint.sh resolves every blocker on a line with three parenthesised asides" \
  || { echo "  ✗ plan-lint.sh dropped a blocker behind an aside: $OUT"; fail=$((fail+1)); }

# A cycle hidden behind an aside must still be caught, not swallowed by the
# aside strip.
cat > "$TMP/asides-cycle.md" <<'EOF'
# Asides Cycle Plan
### Task 1: a
- **Blocked by:** Task 2 (why)
- [ ] Command: true
### Task 2: b
- **Blocked by:** Task 1 (why)
- [ ] Command: true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUT=$(bash "$LINT" "$TMP/asides-cycle.md" 2>&1) && RC=0 || RC=$?
[ "$RC" -ne 0 ] && echo "$OUT" | grep -q 'cycle among Tasks 1, 2' \
  && echo "  ✓ plan-lint.sh catches a Blocked-by cycle hidden behind asides" \
  || { echo "  ✗ plan-lint.sh missed a cycle behind asides: $OUT"; fail=$((fail+1)); }

# An em-dash aside with no parens ("Task 3 — landed in v2.90.0") must
# resolve to {3} only — the per-aside paren strip does nothing here, so the
# version numbers after the dash must not be read as Tasks 2/90/0.
cat > "$TMP/em-dash-aside.md" <<'EOF'
# Em Dash Aside Plan
### Task 1: a
- **Blocked by:** none
- [ ] Command: true
### Task 2: b
- **Blocked by:** none
- [ ] Command: true
### Task 3: c
- **Blocked by:** none
- [ ] Command: true
### Task 4: d
- **Blocked by:** Task 3 — landed in v2.90.0
- [ ] Command: true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/em-dash-aside.md" 2>&1) || RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'graph resolves, no cycle (4 tasks)' \
  && echo "  ✓ plan-lint.sh strips a trailing em-dash aside instead of reading its digits" \
  || { echo "  ✗ plan-lint.sh read digits out of an em-dash aside: $OUT"; fail=$((fail+1)); }

# "NONE" (any casing) means no blockers too, not just "None"/"none" — the
# same tolower() parity ticket.sh's readiness parser already had (T-5). A
# bare "NONE" alone is not discriminating (no digits either side of the
# fix), so the trailing "v2" (no parens, no em-dash — neither aside strip
# would rescue it) must NOT become a phantom Task 2 reference.
cat > "$TMP/none-uppercase.md" <<'EOF'
# None Uppercase Plan
### Task 1: a
- **Blocked by:** NONE - flagged for v2 already
- [ ] Command: true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/none-uppercase.md" 2>&1) || RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'graph resolves, no cycle (1 tasks)' \
  && echo "  ✓ plan-lint.sh treats Blocked by: NONE as no blockers" \
  || { echo "  ✗ plan-lint.sh did not treat NONE as no blockers: $OUT"; fail=$((fail+1)); }

# A task whose Test / evidence prose quotes the LITERAL field labels
# `- **Blocked by:**` / `- **Owner:**` (as the t2 handoff plan itself did,
# referencing a Task 4 that does not exist here), sitting ABOVE the task's
# real `- **Blocked by:**` / `- **Owner:**` bullets, must not be read as
# those fields itself, and must not have its own content swallowed by
# them — only the real bullets feed the graph, and the prose stays intact
# in --brief's Test / evidence section.
cat > "$TMP/prose-quotes-fields.md" <<'EOF'
# Prose Quotes Fields Plan
### Task 1: a
- **Blocked by:** none
- **Owner:** Lead
- [ ] Command: true
### Task 2: b
- **Test / evidence:** the graph must not read `- **Blocked by:** Task 4 (why)` or `- **Owner:** devops-sre` out of this prose
- **Blocked by:** Task 1
- **Owner:** devops-sre
- [ ] Command: true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/prose-quotes-fields.md" 2>&1) || RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'graph resolves, no cycle (2 tasks)' \
  && echo "  ✓ plan-lint.sh does not read a Blocked-by/Owner mention inside prose as the field" \
  || { echo "  ✗ plan-lint.sh let prose fool the graph scan: $OUT"; fail=$((fail+1)); }
BOUT=$(bash "$LINT" --brief 2 "$TMP/prose-quotes-fields.md" 2>/dev/null)
BB=$(printf '%s\n' "$BOUT" | awk '/^## Blocked by/{f=1;next} /^## /{f=0} f')
TE=$(printf '%s\n' "$BOUT" | awk '/^## Test \/ evidence/{f=1;next} /^## /{f=0} f')
printf '%s' "$BB" | grep -qxF 'Task 1' \
  && printf '%s' "$TE" | grep -qF 'must not read' \
  && echo "  ✓ --brief keeps the prose in Test / evidence and Blocked by from the real field line only" \
  || { echo "  ✗ --brief let the prose line swallow or leak a field: Blocked by=$BB / Test-evidence=$TE"; fail=$((fail+1)); }

# A task with no real Command bullet, but whose Test / evidence prose
# quotes the literal word "Command:", must still be flagged missing — a
# bare substring match on the whole line would let the prose mention
# stand in for the field.
cat > "$TMP/prose-quotes-command.md" <<'EOF'
# Prose Quotes Command Plan
### Task 1: a
- Blocked by: none
- Command: true
### Task 2: b
- Blocked by: Task 1
- Test / evidence: run the Command: listed in Task 1 first
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/prose-quotes-command.md" 2>&1) || RC=$?
[ "$RC" -ne 0 ] && echo "$OUT" | grep -q 'missing Command: Task 2' \
  && echo "  ✓ plan-lint.sh does not read a prose mention of Command: as the field" \
  || { echo "  ✗ plan-lint.sh let prose fool the Command check: rc=$RC $OUT"; fail=$((fail+1)); }

# A field written with the bold markers OUTSIDE the label but the colon
# inside them ("- **Owner**: value") must parse to the bare value, not to
# the raw bulleted/bolded line — the strip regex must match stars on
# either side of the colon.
cat > "$TMP/bold-colon-outside.md" <<'EOF'
# Bold Colon Outside Plan
### Task 1: a
- **Delivers**: a working thing
- **Blocked by**: none
- **Owner**: devops-sre
- Command: true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
BOUT=$(bash "$LINT" --brief 1 "$TMP/bold-colon-outside.md" 2>/dev/null)
GOALLINE=$(printf '%s\n' "$BOUT" | awk '/^## Goal/{f=1;next} /^## /{f=0} f')
printf '%s' "$GOALLINE" | grep -qxF 'a working thing' \
  && echo "  ✓ --brief strips a \`- **Label**: value\` field to the bare value" \
  || { echo "  ✗ --brief left the raw bulleted line as the field value: $GOALLINE"; fail=$((fail+1)); }

# An asterisk-bulleted field ("* Command: ..." instead of "- Command: ...")
# must be recognized — the gate must not require a dash bullet specifically.
cat > "$TMP/star-bullet.md" <<'EOF'
# Star Bullet Plan
### Task 1: a
* Blocked by: none
* Command: true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
RC=0; OUT=$(bash "$LINT" "$TMP/star-bullet.md" 2>&1) || RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'every task carries a Command (1/1)' \
  && echo "  ✓ plan-lint.sh accepts an asterisk-bulleted field line" \
  || { echo "  ✗ plan-lint.sh missed an asterisk-bulleted Command: rc=$RC $OUT"; fail=$((fail+1)); }

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
for needle in '\*\*Delivers:\*\*' '\*\*Blocked by:\*\*' '\*\*Proof:\*\*' '^## Changes during build' '^## Follow-ups'; do
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

# ── --brief <N> (v2.145.0) — assembles a task brief from a filled plan ──
# Regression guard: the plain lint output on an existing fixture must stay
# byte-identical to before --brief existed (one-each.md, already built above).
EXPECTED_PLAIN='  ✓ Failure policy present
  ✓ every task carries a Command (2/2)
  · no Blocked by fields — order is prose only; add one per task
  ✓ sequential layout — ownership check not applicable
plan-lint: PASS'
OUT=$(bash "$LINT" "$TMP/one-each.md")
if [ "$OUT" = "$EXPECTED_PLAIN" ]; then
  echo "  ✓ plain plan-lint.sh output is unchanged by --brief (byte-identical)"
else
  echo "  ✗ plain plan-lint.sh output changed:"; diff <(printf '%s' "$EXPECTED_PLAIN") <(printf '%s' "$OUT"); fail=$((fail+1))
fi

cat > "$TMP/brief-plan.md" <<'EOF'
# Brief Plan

## Source spec
docs/specs/brief-2026-09-17.md

## Files to touch
- `api/users.py` — endpoint
- `ui/form.tsx` — form
- `docs/readme.md` — docs

## Tasks

### Task 1: api endpoint
- **Delivers:** users can list via API.
- **Blocked by:** none
- [ ] **Files:** `api/users.py`
- [ ] **Change:** add GET /users
- [ ] **Test / evidence:** pytest api/
- [ ] **Command:** pytest api/
- **Owner:** backend-developer
- **Done when:** pytest passes

### Task 2: form UI
- **Delivers:** users can submit the form.
- **Blocked by:** Task 1
- [ ] **Read first:** ui/existing-form.tsx for the pattern
- [ ] **Files:** `ui/form.tsx`
- [ ] **Change:** wire form to API
- [ ] **Test / evidence:** vitest ui/
- [ ] **Command:** npm test
- **Owner:** frontend-developer
- **Done when:** npm test passes

### Task 3: docs
- **Delivers:** docs describe the endpoint.
- **Blocked by:** Task 1
- [ ] **Files:** `docs/readme.md`
- [ ] **Change:** write docs
- [ ] **Command:** true
- **Owner:** content-strategist (dev)
- **Done when:** docs read fine

## Parallel layout
Parallel — contract: `brief-contract.md`

## Failure policy
Default: stop.
EOF
cat > "$TMP/brief-contract.md" <<'EOF'
# Brief Contract

## File ownership
- `backend-developer (T1)`: `api/users.py`
- `frontend-developer (T2)`: `ui/form.tsx`, `ui/existing-form.tsx`
- `content-strategist (T3)`: `docs/readme.md`

## Do-not-touch list
`scripts/release.sh`, `core/secrets.env`
EOF

# (1) --brief 2 with a contract: headings in order, Goal/Command verbatim,
# Files allowed = task Files ∪ contract slice, Files forbidden = the rest.
OUT=$(bash "$LINT" --brief 2 "$TMP/brief-plan.md" "$TMP/brief-contract.md")
RC=$?
EXPECTED_HEADINGS='## Worktree
## Goal
## Tier
## Blocked by
## Read first
## Files allowed
## Files forbidden
## Change
## Test / evidence
## Command
## Proof
## Done when
## Write
## Reviewers
## Bounds'
GOT_HEADINGS=$(printf '%s\n' "$OUT" | grep '^## ')
if [ "$RC" -eq 0 ] && [ "$GOT_HEADINGS" = "$EXPECTED_HEADINGS" ]; then
  echo "  ✓ plan-lint.sh --brief prints every heading in order"
else
  echo "  ✗ --brief heading order wrong: rc=$RC"; diff <(printf '%s' "$EXPECTED_HEADINGS") <(printf '%s' "$GOT_HEADINGS"); fail=$((fail+1))
fi
if printf '%s\n' "$OUT" | grep -q '^# Task 2: form UI$' \
  && printf '%s\n' "$OUT" | grep -A1 '^## Goal' | grep -q 'users can submit the form\.' \
  && printf '%s\n' "$OUT" | grep -A1 '^## Command' | grep -q '^npm test$'; then
  echo "  ✓ plan-lint.sh --brief prints the title and Goal/Command verbatim"
else
  echo "  ✗ --brief title/Goal/Command wrong: $OUT"; fail=$((fail+1))
fi
if printf '%s\n' "$OUT" | grep -A1 '^## Read first' | grep -q 'ui/existing-form.tsx for the pattern'; then
  echo "  ✓ plan-lint.sh --brief prints a Read first field when the task has one"
else
  echo "  ✗ --brief missed the Read first field: $OUT"; fail=$((fail+1))
fi
ALLOWED=$(printf '%s\n' "$OUT" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$ALLOWED" | grep -qF -- '- ui/form.tsx' && printf '%s\n' "$ALLOWED" | grep -qF -- '- ui/existing-form.tsx'; then
  echo "  ✓ plan-lint.sh --brief unions the task Files with the contract owner slice"
else
  echo "  ✗ --brief Files allowed missing the contract slice: $ALLOWED"; fail=$((fail+1))
fi
FORBIDDEN=$(printf '%s\n' "$OUT" | awk '/^## Files forbidden/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$FORBIDDEN" | grep -qF -- '- api/users.py' \
  && printf '%s\n' "$FORBIDDEN" | grep -qF -- '- docs/readme.md' \
  && printf '%s\n' "$FORBIDDEN" | grep -qF -- '- scripts/release.sh' \
  && printf '%s\n' "$FORBIDDEN" | grep -qF -- '- core/secrets.env' \
  && printf '%s\n' "$FORBIDDEN" | grep -qF -- '- everything else'; then
  echo "  ✓ plan-lint.sh --brief lists the other tasks' paths + do-not-touch as forbidden"
else
  echo "  ✗ --brief Files forbidden wrong: $FORBIDDEN"; fail=$((fail+1))
fi

# (2) prose-only task (Task 3, docs/readme.md only) → Reviewers = none.
OUT3=$(bash "$LINT" --brief 3 "$TMP/brief-plan.md" "$TMP/brief-contract.md")
if printf '%s\n' "$OUT3" | grep -A1 '^## Reviewers' | grep -qF '`none`'; then
  echo "  ✓ plan-lint.sh --brief sets Reviewers to none on a prose-only task"
else
  echo "  ✗ --brief prose-only Reviewers wrong: $OUT3"; fail=$((fail+1))
fi
if printf '%s\n' "$OUT3" | grep -A1 '^## Tier' | grep -qF 'R1 (docs-only)'; then
  echo "  ✓ plan-lint.sh --brief sets Tier to R1 (docs-only) on a prose-only task"
else
  echo "  ✗ --brief prose-only Tier wrong: $OUT3"; fail=$((fail+1))
fi

# (3) a task whose Files include src/auth/login.ts → security-engineer appended.
cat > "$TMP/brief-auth.md" <<'EOF'
### Task 1: auth
- **Delivers:** users can log in.
- **Blocked by:** none
- [ ] **Files:** `src/auth/login.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTA=$(bash "$LINT" --brief 1 "$TMP/brief-auth.md")
if printf '%s\n' "$OUTA" | grep -A1 '^## Reviewers' | grep -qF '`security-engineer`'; then
  echo "  ✓ plan-lint.sh --brief appends security-engineer for an auth path"
else
  echo "  ✗ --brief security-engineer match missed: $OUTA"; fail=$((fail+1))
fi
if printf '%s\n' "$OUTA" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)'; then
  echo "  ✓ plan-lint.sh --brief sets Tier to R4 (high-risk) on a risk path"
else
  echo "  ✗ --brief risk-path Tier wrong: $OUTA"; fail=$((fail+1))
fi
if printf '%s\n' "$OUTA" | grep -A1 '^## Reviewers' | grep -qF 'rolepod-cross-family --kind review'; then
  echo "  ✓ plan-lint.sh --brief names the external review command on an R4 task"
else
  echo "  ✗ --brief R4 Reviewers missing the external instruction: $OUTA"; fail=$((fail+1))
fi

# (3a) the repo's .rolepod/risk-paths override tiers the brief the way the commit
# gate tiers the commit: a `-` line excludes a path the built-in words would flag
# (an agent definition named billing-engineer.yml is no billing code), a bare / `+`
# line adds one.
RPR="$TMP/risk-repo"; mkdir -p "$RPR/.rolepod" "$RPR/plans"
( cd "$RPR" && git init -q . )
cat > "$RPR/plans/p.md" <<'EOF'
### Task 1: preloads
- **Delivers:** slimmer preloads.
- **Blocked by:** none
- [ ] **Files:** `adapters/claude/agent-frontmatter/billing-engineer.yml`, `tests/static/pin.sh`
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** true
### Task 2: ledger
- **Delivers:** a ledger.
- **Blocked by:** none
- [ ] **Files:** `src/ledger/post.ts`, `src/ledger/sum.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTRP0=$(bash "$LINT" --brief 1 "$RPR/plans/p.md")
printf -- '-agent-frontmatter/\n+src/ledger/\n' > "$RPR/.rolepod/risk-paths"
OUTRP1=$(bash "$LINT" --brief 1 "$RPR/plans/p.md")
OUTRP2=$(bash "$LINT" --brief 2 "$RPR/plans/p.md")
if printf '%s\n' "$OUTRP0" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)' \
   && printf '%s\n' "$OUTRP1" | grep -A1 '^## Tier' | grep -qF 'R3 (multi-file)'; then
  echo "  ✓ plan-lint.sh --brief honours a '-' line in .rolepod/risk-paths (R4 by file name → R3)"
else
  echo "  ✗ --brief ignores the risk-paths exclusion: $(printf '%s\n' "$OUTRP1" | grep -A1 '^## Tier' | tail -1)"; fail=$((fail+1))
fi
if printf '%s\n' "$OUTRP2" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)'; then
  echo "  ✓ plan-lint.sh --brief honours a '+' line in .rolepod/risk-paths (project risk path → R4)"
else
  echo "  ✗ --brief ignores the risk-paths addition: $(printf '%s\n' "$OUTRP2" | grep -A1 '^## Tier' | tail -1)"; fail=$((fail+1))
fi
# A malformed ERE in the override fails open (built-ins only), like the gate — never a truncated brief.
printf -- '+src/[a\n' > "$RPR/.rolepod/risk-paths"
OUTRP3=$(bash "$LINT" --brief 1 "$RPR/plans/p.md" 2>/dev/null) && RC3=0 || RC3=$?
if [ "$RC3" -eq 0 ] && printf '%s\n' "$OUTRP3" | grep -q '^## Bounds' \
   && printf '%s\n' "$OUTRP3" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)'; then
  echo "  ✓ plan-lint.sh --brief survives a malformed risk-paths pattern (built-ins only, whole brief printed)"
else
  echo "  ✗ --brief broke on a malformed risk-paths pattern (rc=$RC3)"; fail=$((fail+1))
fi

# (3b) two non-test source files, no risk path → R3 (multi-file), no reviewer
# in the loop (the Lead's ONE combined review covers it — spec lean-loop-
# 2026-09-23 Task 2).
cat > "$TMP/brief-tier-r3.md" <<'EOF'
### Task 1: two files
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `src/a.py`, `src/b.py`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTR3=$(bash "$LINT" --brief 1 "$TMP/brief-tier-r3.md")
if printf '%s\n' "$OUTR3" | grep -A1 '^## Tier' | grep -qF 'R3 (multi-file)' \
  && [ "$(printf '%s\n' "$OUTR3" | grep -A1 '^## Reviewers' | tail -1)" = '`none` in the loop — the Lead runs ONE combined review over the plan diff before release' ]; then
  echo "  ✓ plan-lint.sh --brief sets Tier to R3 (multi-file) with no reviewer in the loop"
else
  echo "  ✗ --brief two-file Tier/Reviewers wrong: $OUTR3"; fail=$((fail+1))
fi
if ! printf '%s\n' "$OUTR3" | grep -q '^## Check$'; then
  echo "  ✓ plan-lint.sh --brief prints no ## Check heading on an R3 task"
else
  echo "  ✗ --brief still prints ## Check on an R3 task"; fail=$((fail+1))
fi

# (3c) one source file plus its own test file → R2 (one file + test).
cat > "$TMP/brief-tier-r2.md" <<'EOF'
### Task 1: file plus test
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `src/x.py`, `tests/test_x.py`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTR2=$(bash "$LINT" --brief 1 "$TMP/brief-tier-r2.md")
if printf '%s\n' "$OUTR2" | grep -A1 '^## Tier' | grep -qF 'R2 (one file + test)'; then
  echo "  ✓ plan-lint.sh --brief sets Tier to R2 (one file + test) on a file + its own test"
else
  echo "  ✗ --brief file+test Tier wrong: $OUTR2"; fail=$((fail+1))
fi

# (3d) superseded (spec lean-loop-2026-09-23 Task 2): the pool-tier-driven
# external clause for R2/R3 is gone — an R2 task's Reviewers line ignores
# .rolepod/cross-family's `tier =` line entirely now (no per-task reviewer
# at all in the loop for R2/R3; the Lead's ONE combined review covers it).
TRR="$TMP/tier-repo"; mkdir -p "$TRR/.rolepod" "$TRR/plans"
( cd "$TRR" && git init -q . )
cp "$TMP/brief-tier-r2.md" "$TRR/plans/p.md"
printf '[reviewer]\nreview = codex\ntier = R2\n' > "$TRR/.rolepod/cross-family"
OUTT2=$(bash "$LINT" --brief 1 "$TRR/plans/p.md")
if [ "$(printf '%s\n' "$OUTT2" | grep -A1 '^## Reviewers' | tail -1)" = '`none` in the loop — the Lead runs ONE combined review over the plan diff before release' ]; then
  echo "  ✓ plan-lint.sh --brief ignores a pool tier = R2 line on an R2 task (no per-task external clause)"
else
  echo "  ✗ --brief pool tier = R2 still changed Reviewers: $(printf '%s\n' "$OUTT2" | grep -A1 '^## Reviewers' | tail -1)"; fail=$((fail+1))
fi

# (4) Owner line with write: external → Write external.
cat > "$TMP/brief-ext.md" <<'EOF'
### Task 1: external draft
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `scripts/foo.sh`
- [ ] **Command:** true
- **Owner:** backend-developer · write: external
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTE=$(bash "$LINT" --brief 1 "$TMP/brief-ext.md")
if printf '%s\n' "$OUTE" | grep -A1 '^## Write' | grep -qF '`external`'; then
  echo "  ✓ plan-lint.sh --brief reads write: external off the Owner line"
else
  echo "  ✗ --brief Write field wrong: $OUTE"; fail=$((fail+1))
fi

# (5) --brief 9 on a 3-task plan → exit 2, one stderr line, empty stdout.
RC9=0
OUT9=$(bash "$LINT" --brief 9 "$TMP/brief-plan.md" 2>"$TMP/brief9.err") || RC9=$?
ERRLINES=$(wc -l < "$TMP/brief9.err" | tr -d ' ')
if [ "$RC9" -eq 2 ] && [ -z "$OUT9" ] && [ "$ERRLINES" -eq 1 ]; then
  echo "  ✓ plan-lint.sh --brief on a missing task exits 2 with empty stdout + one stderr line"
else
  echo "  ✗ --brief missing-task handling wrong: rc=$RC9 stdout=[$OUT9] errlines=$ERRLINES"; fail=$((fail+1))
fi

# (6) round-2 fixes: a Command/Files value containing literal asterisks must
# reproduce byte-exact (a bare gsub on the value, not just the leading bold
# marker, corrupted `pytest -k "test_brief*"` / `grep -E 'foo.*bar'` /
# `src/**/*.ts`), and a same-role contract split across two tasks (T1/T4)
# must use only the T-tagged slice, never the role-name match.
cat > "$TMP/brief-glob.md" <<'EOF'
### Task 1: glob test
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `src/**/*.ts`
- [ ] **Command:** pytest -k "test_brief*"
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTG=$(bash "$LINT" --brief 1 "$TMP/brief-glob.md")
if printf '%s\n' "$OUTG" | grep -qF -- '- src/**/*.ts' \
  && printf '%s\n' "$OUTG" | grep -A1 '^## Command' | grep -qF 'pytest -k "test_brief*"'; then
  echo "  ✓ plan-lint.sh --brief reproduces asterisk-bearing Files/Command byte-exact"
else
  echo "  ✗ --brief corrupted an asterisk-bearing value: $OUTG"; fail=$((fail+1))
fi

cat > "$TMP/brief-grepcmd.md" <<'EOF'
### Task 1: grep test
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `a.txt`
- [ ] **Command:** grep -E 'foo.*bar' a.txt
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTGR=$(bash "$LINT" --brief 1 "$TMP/brief-grepcmd.md")
if printf '%s\n' "$OUTGR" | grep -A1 '^## Command' | grep -qF "grep -E 'foo.*bar' a.txt"; then
  echo "  ✓ plan-lint.sh --brief reproduces a regex Command byte-exact"
else
  echo "  ✗ --brief corrupted a regex Command: $OUTGR"; fail=$((fail+1))
fi

cat > "$TMP/brief-t1t4-plan.md" <<'EOF'
## Files to touch
- `a/one.py`
- `b/two.py`
### Task 1: t1
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `a/one.py`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Parallel — contract: `brief-t1t4-contract.md`
## Failure policy
Default: stop.
EOF
cat > "$TMP/brief-t1t4-contract.md" <<'EOF'
## File ownership
- `backend-developer (T1)`: `a/one.py`
- `backend-developer (T4)`: `b/two.py`
EOF
OUTT1=$(bash "$LINT" --brief 1 "$TMP/brief-t1t4-plan.md" "$TMP/brief-t1t4-contract.md")
ALLOWEDT1=$(printf '%s\n' "$OUTT1" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
# Round shape sits where the owner picks its reviewers (2026-09-21: two owners in a
# row ran round 2 as a message to the finished reviewer — the answer landed at the
# Lead — while the rule sat at the end of a long Bounds line). Pinned on the R4
# auth brief (2026-09-23, lean-loop T2): R2/R3 carries no reviewer in the loop
# any more, so it carries no round-2 line either — only R4 still has one.
A4_REV=$(printf '%s\n' "$OUTA" | awk '/^## Reviewers/{on=1; next} /^## /{on=0} on')
A4_BND=$(printf '%s\n' "$OUTA" | awk '/^## Bounds/{on=1; next} /^## /{on=0} on')
if [ "$(printf '%s\n' "$A4_REV" | sed -n '2p' | grep -c '^Round 2 = ONE new foreground dispatch')" -eq 1 ] \
  && ! printf '%s\n' "$A4_BND" | grep -q 'ound 2'; then
  echo "  ✓ plan-lint.sh --brief states the round-2 shape under Reviewers (line 2) on an R4 task, once, not in Bounds"
else
  echo "  ✗ --brief round-2 shape misplaced — Reviewers: $A4_REV | Bounds: $A4_BND"; fail=$((fail+1))
fi
R3_REV=$(printf '%s\n' "$OUTR3" | awk '/^## Reviewers/{on=1; next} /^## /{on=0} on')
R3_BND=$(printf '%s\n' "$OUTR3" | awk '/^## Bounds/{on=1; next} /^## /{on=0} on')
if [ "$(printf '%s\n' "$R3_REV" | grep -c .)" -eq 1 ] && ! printf '%s\n' "$R3_REV" | grep -q 'ound 2'; then
  echo "  ✓ plan-lint.sh --brief prints no round-2 line under Reviewers on an R2/R3 task"
else
  echo "  ✗ --brief R2/R3 Reviewers carries an unexpected round-2 line: $R3_REV"; fail=$((fail+1))
fi
# ONE test field (2026-09-23, lean-loop T2): the generated Bounds send the
# owner to the Command, after each edit and last before returning.
if printf '%s\n' "$R3_BND" | grep -qF 'Run the Command after each edit and last before returning' \
  && ! printf '%s\n' "$R3_BND" | grep -q 'Run the Check'; then
  echo "  ✓ --brief Bounds send the owner to the Command, never the Check"
else
  echo "  ✗ --brief Bounds still point the owner at the Check — Bounds: $R3_BND"; fail=$((fail+1))
fi
if [ "$(printf '%s\n' "$OUT3" | awk '/^## Reviewers/{on=1; next} /^## /{on=0} on' | grep -c .)" -eq 1 ]; then
  echo "  ✓ plan-lint.sh --brief prose-only task: Reviewers is the single line none (no round shape)"
else
  echo "  ✗ --brief prose-only Reviewers carries extra lines: $OUT3"; fail=$((fail+1))
fi

if [ "$ALLOWEDT1" = "- a/one.py" ]; then
  echo "  ✓ plan-lint.sh --brief uses only the T-tagged slice on a same-role contract split"
else
  echo "  ✗ --brief T1/T4 same-role split leaked files: $ALLOWEDT1"; fail=$((fail+1))
fi

# Budget line: the generated brief carries the tool budget (mechanism, not prose).
printf '%s\n' "$OUT" | grep -q '^- Budget: build <= 40 tool calls' \
  && echo "  ✓ --brief Bounds carry the tool budget" \
  || { echo "  ✗ --brief Bounds missing the Budget line"; fail=$((fail+1)); }

# Worktree fence: the Bounds name the task's worktree as the only place to edit
# (2026-09-19: two task owners edited the main checkout's copy before their worktree).
printf '%s\n' "$OUT" | grep -qE '^- Edit only Files allowed, and only under \.\./[A-Za-z0-9._-]+-wt-[a-z0-9-]+-t[0-9]+-[a-z0-9-]+ ' \
  && echo "  ✓ --brief Bounds fence every edit inside the task's worktree" \
  || { echo "  ✗ --brief Bounds do not name the worktree as the only place to edit"; fail=$((fail+1)); }

# Worktree line: the brief names the worktree after the task (mechanism).
printf '%s\n' "$OUT" | grep -q '^## Worktree' \
  && printf '%s\n' "$OUT" | grep -qE '^`git worktree add -b [a-z0-9-]+/t[0-9]+-[a-z0-9-]+ \.\./[A-Za-z0-9._-]+-wt-[a-z0-9-]+-t[0-9]+-[a-z0-9-]+`' \
  && echo "  ✓ --brief prints a task-named worktree command" \
  || { echo "  ✗ --brief Worktree line missing or malformed"; fail=$((fail+1)); }

# ── --brief: ## Proof (spec R3) — a task's Proof field, right after Command ──
cat > "$TMP/brief-proof.md" <<'EOF'
### Task 1: with proof
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `src/a.py`
- [ ] **Test / evidence:** pytest src/
- **Proof:** the fix holds :: `pytest -k "test_a" | tee /tmp/out.log`
- [ ] **Command:** pytest src/
- **Owner:** backend-developer
- **Done when:** true

### Task 2: without proof
- **Delivers:** y
- **Blocked by:** none
- [ ] **Files:** `src/b.py`
- [ ] **Command:** pytest src/b
- **Owner:** backend-developer
- **Done when:** true

### Task 3: undeleted placeholder
- **Delivers:** z
- **Blocked by:** none
- [ ] **Files:** `src/c.py`
- [ ] **Command:** pytest src/c
- **Proof:** <the one claim a reviewer of this task would check by hand> :: `<the command that proves it>`
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTP1=$(bash "$LINT" --brief 1 "$TMP/brief-proof.md")
CMD_TO_DW=$(printf '%s\n' "$OUTP1" | awk '/^## Command/{f=1;next} /^## Done when/{f=0} f')
EXPECTED_CMD_TO_DW='pytest src/
Test levels — each runs at ONE point:
1. Command — the tests covering this task; the owner runs it after each edit and last before returning.
2. Release — the whole-repo suite; runs ONCE per release, by the Lead.
## Proof
the fix holds
`pytest -k "test_a" | tee /tmp/out.log`'
if [ "$CMD_TO_DW" = "$EXPECTED_CMD_TO_DW" ]; then
  echo "  ✓ plan-lint.sh --brief prints the Test levels block then ## Proof right after ## Command, pipe + quoted string byte-for-byte"
else
  echo "  ✗ --brief Proof field wrong:"; diff <(printf '%s' "$EXPECTED_CMD_TO_DW") <(printf '%s' "$CMD_TO_DW"); fail=$((fail+1))
fi
OUTP2=$(bash "$LINT" --brief 2 "$TMP/brief-proof.md")
PROOF2=$(printf '%s\n' "$OUTP2" | awk '/^## Proof/{f=1;next} /^## /{f=0} f')
if [ "$PROOF2" = "none" ]; then
  echo "  ✓ plan-lint.sh --brief prints Proof: none for a task without the field"
else
  echo "  ✗ --brief Proof missing-field wrong: $PROOF2"; fail=$((fail+1))
fi
OUTP3=$(bash "$LINT" --brief 3 "$TMP/brief-proof.md")
PROOF3=$(printf '%s\n' "$OUTP3" | awk '/^## Proof/{f=1;next} /^## /{f=0} f')
if [ "$PROOF3" = "none" ]; then
  echo "  ✓ plan-lint.sh --brief treats an undeleted template placeholder as no Proof"
else
  echo "  ✗ --brief undeleted-placeholder Proof wrong: $PROOF3"; fail=$((fail+1))
fi

# ── --brief: a Check: field from an older plan (superseded 2026-09-23, lean-
# loop T2: ONE test field, the Command) is parsed and ignored — no ## Check
# heading, and it never glues onto a later field ──
cat > "$TMP/brief-check.md" <<'EOF'
### Task 1: with check
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `src/a.py`
- [ ] **Command:** pytest src/
- **Check:** `pytest src/a_test.py::test_a`
- **Owner:** backend-developer
- **Done when:** true

### Task 2: without check
- **Delivers:** y
- **Blocked by:** none
- [ ] **Files:** `src/b.py`
- [ ] **Command:** pytest src/b
- **Owner:** backend-developer
- **Done when:** true
  the Check for this stays with backend-developer, not a new field

### Task 3: prose quoting Check
- **Delivers:** z
- **Blocked by:** none
- [ ] **Files:** `src/c.py`
- [ ] **Command:** pytest src/c
- **Test / evidence:** run the Check: command by hand once, then automate
- **Owner:** backend-developer
- **Done when:** true

### Task 4: undeleted backticked placeholder
- **Delivers:** w
- **Blocked by:** none
- [ ] **Files:** `src/d.py`
- [ ] **Command:** pytest src/d
- **Check:** `<the narrowest command that covers this task's edits — one case file, one test name; the loop runs this, the Command runs once>`
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
for n in 1 2 3 4; do
  OUTCK=$(bash "$LINT" --brief "$n" "$TMP/brief-check.md")
  if printf '%s\n' "$OUTCK" | grep -q '^## Check$'; then
    echo "  ✗ --brief Task $n still prints ## Check"; fail=$((fail+1))
  else
    echo "  ✓ --brief Task $n prints no ## Check heading (an old Check: field is ignored)"
  fi
done
OUTCK1=$(bash "$LINT" --brief 1 "$TMP/brief-check.md")
DW1=$(printf '%s\n' "$OUTCK1" | awk '/^## Done when/{f=1;next} /^## /{f=0} f')
if [ "$DW1" = "true" ]; then
  echo "  ✓ --brief a task's Check: field never glues onto a later field (Done when intact)"
else
  echo "  ✗ --brief Check: field corrupted a later field — Done when: $DW1"; fail=$((fail+1))
fi

# ── --brief: an indented Change sub-bullet is the Change; a backticked flag on a Files-to-touch line is not a path ──
BF=$(mktemp -d)
cat > "$BF/plan.md" <<'PLAN'
# Brief Fields Plan

**Goal:** g
**Architecture:** a
**Stack:** s

## Source spec
`docs/spec.md`

## Files to touch
- `src/a.sh` — flips `FLAG=1` and drops `--all`
- `src/b.sh` — the other owner
- `Makefile` — a bare capitalised file is a path too; bumps `v2.147.0`, reads `KIND`
- `README` — a known all-caps root file is a path

## Tasks

### Task 1: first
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `src/a.sh`
- **Read first:** `src/a.sh`
- [ ] **Change:**
  - first sub-bullet of the change
  - second sub-bullet
- [ ] **Test / evidence:** t
- [ ] **Command:** `make test`
- **Owner:** Lead
- **Done when:** done

### Task 2: second
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `src/b.sh`
- [ ] **Change:** c
- [ ] **Test / evidence:** end-to-end browser flow through the login page
- [ ] **Command:** `make test`
- **Owner:** Lead
- **Done when:** done

## Parallel layout
Sequential — single owner.

## Failure policy
Default: a failing **Command** → debug-issue.
PLAN
OUT=$(cd "$BF" && bash "$LINT" --brief 1 plan.md 2>/dev/null)
CH=$(printf '%s\n' "$OUT" | awk '/^## Change/{f=1;next} /^## /{f=0} f')
printf '%s' "$CH" | grep -q 'first sub-bullet' && printf '%s' "$CH" | grep -q 'second sub-bullet' && ! printf '%s' "$CH" | grep -q 'not in plan' \
  && echo "  ✓ --brief Change carries the indented sub-bullets (was: not in plan)" \
  || { echo "  ✗ --brief Change from sub-bullets: $CH"; fail=$((fail+1)); }
FB=$(printf '%s\n' "$OUT" | awk '/^## Files forbidden/{f=1;next} /^## /{f=0} f')
printf '%s' "$FB" | grep -q 'src/b.sh' && printf '%s' "$FB" | grep -q '^- Makefile$' && printf '%s' "$FB" | grep -q '^- README$' && ! printf '%s' "$FB" | grep -q '^- KIND$' && ! printf '%s' "$FB" | grep -q 'v2.147.0' && ! printf '%s' "$FB" | grep -q 'FLAG=1' && ! printf '%s' "$FB" | grep -q -- '--all' \
  && echo "  ✓ --brief Files forbidden lists paths only (a backticked flag on the line is commentary)" \
  || { echo "  ✗ --brief Files forbidden: $FB"; fail=$((fail+1)); }
RV1=$(printf '%s\n' "$OUT" | grep -A1 '^## Reviewers' | tail -1)
[ "$RV1" = '`none` in the loop — the Lead runs ONE combined review over the plan diff before release' ] \
  && echo "  ✓ --brief Reviewers default = none in the loop (the Lead's combined review is the floor)" \
  || { echo "  ✗ --brief Reviewers default: $RV1"; fail=$((fail+1)); }
OUT2=$(cd "$BF" && bash "$LINT" --brief 2 plan.md 2>/dev/null)
RV2=$(printf '%s\n' "$OUT2" | grep -A1 '^## Reviewers' | tail -1)
printf '%s' "$RV2" | grep -qF '`qa-tester` (E2E)' && printf '%s' "$RV2" | grep -qF 'none' \
  && echo "  ✓ --brief Reviewers adds qa-tester (E2E) when the Test line names a user-visible flow" \
  || { echo "  ✗ --brief Reviewers E2E append: $RV2"; fail=$((fail+1)); }
rm -rf "$BF"

if [ "$fail" -eq 0 ]; then
  echo "  ✓ pass"
  exit 0
else
  echo "  ✗ fail ($fail)"
  exit 1
fi
