#!/bin/bash
# plan-lint — proves the write-plan loop-runnable lint catches a plan whose
# tasks lack a runnable Command or whose Failure policy is missing, and
# passes a properly filled plan. Sibling of spec-lint.sh (write-spec).
#
# The lint (as documented in write-plan SKILL.md self-review):
#   grep -q '^## Failure policy' <plan> && every `### Task` block carries its
#   own Command: line (per block — write-plan's scripts/plan-lint.sh and the inline awk).
set -euo pipefail

# Most brief assertions exercise Standard review routing; pin that profile
# explicitly so the global Lite default does not alter their seam.
export ROLEPOD_SESSION_MODE=standard ROLEPOD_SESSION_SOURCE=default

fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# --brief now resolves the cross-family pool's review tier (spec D1) through
# the runner beside scripts/plan-lint.sh — HOME is pointed at an empty
# fixture for the whole file so the machine's own ~/.rolepod/config.json
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
after 2 failed fixes for the same criterion, consult once, then allow up to 4
informed attempts; stop sooner without an advisor, or on oscillation.
EOF

if plan_lint "$TMP/clean.md"; then
  echo "  ✓ lint passes a properly filled plan"
else
  echo "  ✗ lint rejected a clean plan"
  fail=$((fail+1))
fi

# ── write-plan's scripts/plan-lint.sh — ownership completeness on parallel plans ─────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LINT="${PLAN_LINT_UNDER_TEST:-$REPO_DIR/core/skills/write-plan/scripts/plan-lint.sh}"
cat > "$TMP/par-plan.md" <<'EOF'
# Par Plan
## Files to touch
- `api/users.py` — endpoint
- `ui/form.tsx` — form
### Task 1: api
- [ ] Files: api/users.py
- [ ] Command: pytest api/
### Task 2: ui
- [ ] Files: ui/form.tsx
- [ ] Command: pytest ui/
## Parallel layout
Two tracks per `par-contract.md`; merge order: api → ui.
## Failure policy
Default: debug-issue; after 2 failures consult once; allow 4 informed fixes.
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

# ── lint path (not --brief): a backticked token inside a `( … )` note on a
# Files-to-touch bullet is commentary, never a second file — reuses the
# same cleanfiles() rule --brief already applies (always-on-core-lean
# follow-up: `agent-frontmatter/` inside the note was flagged unowned).
cat > "$TMP/note-plan.md" <<'EOF'
# Note Plan
## Files to touch
- `adapters/antigravity/agent-frontmatter/` (moved from the old `agent-frontmatter/` dir)
### Task 1: move dir
- [ ] Files: adapters/antigravity/agent-frontmatter/
- [ ] Command: true
## Parallel layout
One track per `note-contract.md`.
## Failure policy
Default: debug-issue; after 2 failures consult once; allow 4 informed fixes.
EOF
cat > "$TMP/note-contract.md" <<'EOF'
# Note Contract
## File ownership
- `devops-sre`: `adapters/antigravity/agent-frontmatter/`
EOF
if bash "$LINT" "$TMP/note-plan.md" "$TMP/note-contract.md" >/dev/null; then
  echo "  ✓ plan-lint.sh drops a backticked note token from Files to touch, not just --brief"
else
  echo "  ✗ plan-lint.sh flagged the note's backticked token as an unowned file"; fail=$((fail+1))
fi

cat > "$TMP/seq-plan.md" <<'EOF'
# Seq Plan
## Files to touch
- `api/users.py` — endpoint
### Task 1: api
- [ ] Files: api/users.py
- [ ] Command: pytest api/
## Parallel layout
Sequential — single owner.
## Failure policy
Default: debug-issue; after 2 failures consult once; allow 4 informed fixes.
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
- [ ] Files: api/users.py
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
- [ ] Files: api/users.py
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
- [ ] Files: api/users.py
- [ ] Command: pytest api/
- [ ] Command: pytest api/ -k smoke
### Task 2: ui
- [ ] Files: ui/form.tsx
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
- [ ] Files: api/users.py
- [ ] Command: pytest api/
### Task 2: ui
- [ ] Files: ui/form.tsx
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
# without the field once any task has it; a `### T1 —` heading (a user plan
# from a user project) counts as a task — the lint rejected that plan wholesale.
mk() { # $1 = file, $2.. = task blocks (heading + Blocked by), one arg each
  local f="$1" n=0; shift
  { echo "# G"; for blk in "$@"; do n=$((n+1)); printf '%s\n- [ ] Files: f/%s.sh\n- [ ] Command: true\n' "$blk" "$n"; done
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
- **Files:** f/a.sh
- **Blocked by:** Task 2 (why)
- [ ] Command: true
### Task 2: b
- **Files:** f/b.sh
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
- **Files:** f/a.sh
- **Blocked by:** none
- [ ] Command: true
### Task 2: b
- **Files:** f/b.sh
- **Blocked by:** none
- [ ] Command: true
### Task 3: c
- **Files:** f/c.sh
- **Blocked by:** none
- [ ] Command: true
### Task 4: d
- **Files:** f/d.sh
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
- **Files:** f/a.sh
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
- **Files:** f/a.sh
- **Blocked by:** none
- **Owner:** Lead
- [ ] Command: true
### Task 2: b
- **Files:** f/b.sh
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
- Files: f/a.sh
- Blocked by: none
- Command: true
### Task 2: b
- Files: f/b.sh
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
- **Files**: f/a.sh
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
* Files: f/a.sh
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
- Files: f/a.sh
- Blocked by: none
- [ ] Command: true
- Owner: Lead
### Task 2: b
- Files: f/b.sh
- Blocked by: Task 1
- [ ] Command: true
- Owner: Lead (self-do)
### Task 3: c
- Files: f/c.sh
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
- Files: f/a.sh
- Blocked by: none
- [ ] Command: true
- Owner: Lead
### Task 2: b
- Files: f/b.sh
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
- [ ] Files: `scripts/z.sh`
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
- Files: f/a.sh
- Blocked by: none
- [ ] Command: true
- Owner: Lead
### Task 2: b
- Files: f/b.sh
- Blocked by: Task 1
- [ ] Command: true
### Task 3: c
- Files: f/c.sh
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
## Reviewers
## Bounds
## Failure policy'
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

# ── --brief Files forbidden: a do-not-touch entry with an exception clause
# keeps the clause with its glob, instead of printing the bare glob (which
# contradicts Files allowed for the task the exception carves out) —
# always-on-core-lean follow-up, real case `core/skills/**` except Task 4's
# four files (docs/rolepod/plans/always-on-core-lean-cohesion-2026-09-25.md:163).
EX=$(mktemp -d)
cat > "$EX/plan.md" <<'PLAN'
# Exception Plan

## Tasks

### Task 1: touch nothing under skills
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `scripts/plan-lint.sh`
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** done

## Failure policy
Default: stop.
PLAN
cat > "$EX/contract.md" <<'EOF'
# Exception Contract

## File ownership
- `devops-sre`: `scripts/plan-lint.sh`

## Do-not-touch list
`core/agents/**`, `core/skills/**` except Task 4's four files, `hooks/precommit-gate.sh`, `docs/plans/**`.
EOF
OUT_EX=$(cd "$EX" && bash "$LINT" --brief 1 plan.md contract.md 2>/dev/null) || true
FORBIDDEN_EX=$(printf '%s\n' "$OUT_EX" | awk '/^## Files forbidden/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$FORBIDDEN_EX" | grep -qxF -- "- core/skills/** except Task 4's four files" \
  && printf '%s\n' "$FORBIDDEN_EX" | grep -qxF -- '- core/agents/**' \
  && printf '%s\n' "$FORBIDDEN_EX" | grep -qxF -- '- hooks/precommit-gate.sh' \
  && printf '%s\n' "$FORBIDDEN_EX" | grep -qxF -- '- docs/plans/**' \
  && ! printf '%s\n' "$FORBIDDEN_EX" | grep -qxF -- '- core/skills/**'; then
  echo "  ✓ --brief Files forbidden keeps a do-not-touch exception clause with its glob"
else
  echo "  ✗ --brief Files forbidden dropped the exception clause: $FORBIDDEN_EX"; fail=$((fail+1))
fi
rm -rf "$EX"

# ── --brief Files forbidden (review fix, MAJOR): an entry whose parenthetical
# aside itself carries a backtick before any comma or sentence-ending period
# is NOT an "except ..." clause — it prints bare rather than a fragment cut
# mid-sentence (real repo line: `plugins/**` and every rendered adapter
# output (an owner never runs `make render`), ...). A genuine exception
# clause survives a mid-token period (`SKILL.md`) intact — only a period
# followed by whitespace/end-of-line ends the clause.
EY=$(mktemp -d)
cat > "$EY/plan.md" <<'PLAN'
# Exception Edge Plan

## Tasks

### Task 1: touch nothing listed
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `scripts/plan-lint.sh`
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** done

## Failure policy
Default: stop.
PLAN
cat > "$EY/contract.md" <<'EOF'
# Exception Edge Contract

## File ownership
- `devops-sre`: `scripts/plan-lint.sh`

## Do-not-touch list
`plugins/**` and every rendered file (an owner never runs `make render`), `hooks/precommit-gate.sh`, `core/skills/**` except SKILL.md.
EOF
OUT_EY=$(cd "$EY" && bash "$LINT" --brief 1 plan.md contract.md 2>/dev/null) || true
FORBIDDEN_EY=$(printf '%s\n' "$OUT_EY" | awk '/^## Files forbidden/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$FORBIDDEN_EY" | grep -qxF -- '- plugins/**' \
  && printf '%s\n' "$FORBIDDEN_EY" | grep -qxF -- '- core/skills/** except SKILL.md' \
  && printf '%s\n' "$FORBIDDEN_EY" | grep -qxF -- '- hooks/precommit-gate.sh' \
  && ! printf '%s\n' "$FORBIDDEN_EY" | grep -qF -- 'an owner never runs' \
  && ! printf '%s\n' "$FORBIDDEN_EY" | grep -qxF -- '- core/skills/** except SKILL'; then
  echo "  ✓ --brief Files forbidden never truncates an exception clause mid-sentence at a stray backtick"
else
  echo "  ✗ --brief Files forbidden mangled an exception clause: $FORBIDDEN_EY"; fail=$((fail+1))
fi
rm -rf "$EY"

# ── --brief Files forbidden (round-2 MINOR 1): an unmatched `)` ends the
# clause — the do-not-touch line below is copied verbatim from the
# lean-workflow-dedupe cohesion contract (a private working doc, never
# read directly — docs/rolepod/ is untracked and may be archived or
# deleted, so the fixture is a synthetic contract instead): `plugins/**`
# and every rendered adapter output (an owner never runs `make render`),
# ... — the `)` after "make render" closes the ENCLOSING note, not
# anything opened by "make render" itself.
EZ=$(mktemp -d)
cat > "$EZ/plan.md" <<'PLAN'
# Unmatched Paren Plan

## Tasks

### Task 1: repro
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `scripts/plan-lint.sh`
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** done

## Failure policy
Default: stop.
PLAN
cat > "$EZ/contract.md" <<'EOF'
# Unmatched Paren Contract

## File ownership
- `devops-sre`: `scripts/plan-lint.sh`

## Do-not-touch list
`plugins/**` and every rendered adapter output (the Lead renders at integration — an owner never runs `make render`), `hooks/always-on-core.md.tmpl`, `core/fragments/verify-first.md`, `core/fragments/decision-protocol.md`, `core/fragments/hard-stops.md`, `scripts/plan-lint.sh` (already states C1), commit-gate logic (message text only), the `CAPS` values in `tests/static/lean-surface.sh`.
EOF
OUT_EZ=$(cd "$EZ" && bash "$LINT" --brief 1 plan.md contract.md 2>/dev/null) || true
FORBIDDEN_EZ=$(printf '%s\n' "$OUT_EZ" | awk '/^## Files forbidden/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$FORBIDDEN_EZ" | grep -qxF -- '- make render' \
  && ! printf '%s\n' "$FORBIDDEN_EZ" | grep -qxF -- '- make render )'; then
  echo "  ✓ --brief Files forbidden ends a clause at an unmatched close-paren (was: - make render ))"
else
  echo "  ✗ --brief Files forbidden kept a stray close-paren: $FORBIDDEN_EZ"; fail=$((fail+1))
fi
rm -rf "$EZ"

# ── --brief Files forbidden (round-2 MINOR 2): a `;` ends a clause like a
# `,` — the do-not-touch line below is copied verbatim from the
# write-prototype cohesion contract (same reason as above — a synthetic
# fixture, never a read of the private working doc): `hooks/`, `adapters/`;
# the rendered trees ... must not glue onto `adapters/`.
FA=$(mktemp -d)
cat > "$FA/plan.md" <<'PLAN'
# Semicolon Plan

## Tasks

### Task 1: repro
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `scripts/plan-lint.sh`
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** done

## Failure policy
Default: stop.
PLAN
cat > "$FA/contract.md" <<'EOF'
# Semicolon Contract

## File ownership
- `devops-sre`: `scripts/plan-lint.sh`

## Do-not-touch list
`hooks/`, `adapters/`; the rendered trees under plugins/ and core/fragments/ change only through the render step inside the task Command; every other core/skills file not listed above.
EOF
OUT_FA=$(cd "$FA" && bash "$LINT" --brief 1 plan.md contract.md 2>/dev/null) || true
FORBIDDEN_FA=$(printf '%s\n' "$OUT_FA" | awk '/^## Files forbidden/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$FORBIDDEN_FA" | grep -qxF -- '- adapters/' \
  && ! printf '%s\n' "$FORBIDDEN_FA" | grep -qF -- 'rendered trees'; then
  echo "  ✓ --brief Files forbidden ends a clause at a semicolon like a comma (was: - adapters/ ; the rendered trees ...)"
else
  echo "  ✗ --brief Files forbidden kept the semicolon prose: $FORBIDDEN_FA"; fail=$((fail+1))
fi
rm -rf "$FA"

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
# Workflow intensity is carried by the active session environment, not read
# from config again by a later plan-lint invocation.
OUTSTD=$(cd "$TMP" && ROLEPOD_SESSION_MODE=standard ROLEPOD_SESSION_SOURCE=default bash "$LINT" --brief 1 "$TMP/brief-auth.md")
HOME_FULL="$TMP/home-full"; mkdir -p "$HOME_FULL/.rolepod"
printf '{"workflow":{"mode":"full"}}\n' > "$HOME_FULL/.rolepod/config.json"
OUTA=$(cd "$TMP" && HOME="$HOME_FULL" ROLEPOD_SESSION_MODE=full ROLEPOD_SESSION_SOURCE=global bash "$LINT" --brief 1 "$TMP/brief-auth.md")
STD_REV=$(printf '%s\n' "$OUTSTD" | awk '/^## Reviewers/{on=1; next} /^## /{on=0} on')
FULL_REV=$(printf '%s\n' "$OUTA" | awk '/^## Reviewers/{on=1; next} /^## /{on=0} on')
if ! printf '%s\n' "$STD_REV" | grep -qi 'adversarial' \
  && ! printf '%s\n' "$OUTSTD" | grep -qi 'adversarial pass' \
  && printf '%s\n' "$STD_REV" | sed -n '1p' | grep -qF '`rolepod-reviewer` `lens: security` (depth: checklist' \
  && printf '%s\n' "$STD_REV" | grep -qF 'lens: spec' && printf '%s\n' "$STD_REV" | grep -qF 'lens: standards' \
  && [ "$(printf '%s\n' "$STD_REV" | grep -c .)" -eq 1 ] \
  && ! printf '%s\n' "$STD_REV" | grep -q 'Round 2+' \
  && ! printf '%s\n' "$STD_REV" | grep -q 'Default to reject' \
  && printf '%s\n' "$OUTSTD" | grep -qxF 'Workflow mode: standard (default)'; then
  echo "  ✓ plan-lint.sh --brief R4 in standard: one Reviewers line — checklist security + two lenses, no adversarial, mode line"
else
  echo "  ✗ --brief R4 standard Reviewers wrong: $STD_REV"; fail=$((fail+1))
fi
if printf '%s\n' "$FULL_REV" | grep -qF '`rolepod-reviewer` `lens: security` (depth: full' \
  && printf '%s\n' "$FULL_REV" | grep -qF 'the adversarial pass' \
  && [ "$(printf '%s\n' "$FULL_REV" | grep -c .)" -eq 1 ] \
  && ! printf '%s\n' "$FULL_REV" | grep -q 'Round 2+' \
  && ! printf '%s\n' "$FULL_REV" | grep -q 'Default to reject' \
  && printf '%s\n' "$OUTA" | grep -qxF 'Workflow mode: full (global)'; then
  echo "  ✓ plan-lint.sh --brief R4 in full mode: one Reviewers line — depth full, adversarial, mode line"
else
  echo "  ✗ --brief R4 full Reviewers wrong: $FULL_REV"; fail=$((fail+1))
fi
# Mode order: env, then the session profile (CLAUDE_CODE_SESSION_ID), then
# workflow.mode from config, then lite — in the repo layout and in an installed
# layout (the readers bundled beside the script).
ROOT_REPO="$(cd "$(dirname "$LINT")/../../../.." && pwd)"
RM_COPY="$TMP/lintcopy"; mkdir -p "$RM_COPY/write-plan/scripts"
cp "$LINT" "$RM_COPY/write-plan/scripts/plan-lint.sh"
cp "$ROOT_REPO/hooks/lib/session-mode.sh" "$ROOT_REPO/hooks/lib/rolepod_config.py" "$RM_COPY/write-plan/scripts/"
HOME_NONE="$TMP/home-none"; mkdir -p "$HOME_NONE"
HOME_STD="$TMP/home-std"; mkdir -p "$HOME_STD/.rolepod"
printf '{"workflow":{"mode":"standard"}}\n' > "$HOME_STD/.rolepod/config.json"
HOME_PROF="$TMP/home-prof"; mkdir -p "$HOME_PROF/.rolepod/session-profiles/claude"
printf 'full\nglobal\n' > "$HOME_PROF/.rolepod/session-profiles/claude/sess-A1.mode"
brief_in() { # <script> <home> [env...] -> brief of the auth task
  local s=$1 h=$2; shift 2
  ( cd "$TMP" && env -u ROLEPOD_SESSION_MODE -u ROLEPOD_SESSION_SOURCE -u ROLEPOD_SESSION_CLI -u CLAUDE_CODE_SESSION_ID -u CODEX_THREAD_ID -u CLAUDE_PLUGIN_ROOT HOME="$h" "$@" bash "$s" --brief 1 "$TMP/brief-auth.md" 2>/dev/null )
}
OUTNR=$(brief_in "$RM_COPY/write-plan/scripts/plan-lint.sh" "$HOME_NONE")
OUTPROF=$(brief_in "$LINT" "$HOME_PROF" CLAUDE_CODE_SESSION_ID=sess-A1)
OUTPROF_I=$(brief_in "$RM_COPY/write-plan/scripts/plan-lint.sh" "$HOME_PROF" CLAUDE_CODE_SESSION_ID=sess-A1)
OUTCFG=$(brief_in "$LINT" "$HOME_STD" CLAUDE_CODE_SESSION_ID=sess-none)
OUTCFG_I=$(brief_in "$RM_COPY/write-plan/scripts/plan-lint.sh" "$HOME_STD")
if printf '%s\n' "$OUTNR" | grep -qxF 'Workflow mode: lite (default)' || printf '%s\n' "$OUTNR" | grep -qxF 'Workflow mode: lite (uncaptured)'; then
  echo "  ✓ plan-lint.sh --brief falls back to lite with no env, profile or config"
else
  echo "  ✗ --brief without profile or config: $(printf '%s\n' "$OUTNR" | grep -A2 '^## Tier')"; fail=$((fail+1))
fi
if printf '%s\n' "$OUTPROF" | grep -qxF 'Workflow mode: full (global)' \
  && printf '%s\n' "$OUTPROF" | grep -qF '`lens: security` (depth: full' \
  && printf '%s\n' "$OUTPROF" | grep -qF 'the adversarial pass' \
  && [ "$(printf '%s\n' "$OUTPROF_I" | /usr/bin/grep -c '^Workflow mode: full (global)')" -eq 1 ]; then
  echo "  ✓ plan-lint.sh --brief reads the CLAUDE_CODE_SESSION_ID profile (repo + installed layout): full R4 set"
else
  echo "  ✗ --brief profile mode: $(printf '%s\n' "$OUTPROF" | grep -A2 '^## Tier')"; fail=$((fail+1))
fi
if printf '%s\n' "$OUTCFG" | grep -q '^Workflow mode: standard (' \
  && printf '%s\n' "$OUTCFG_I" | grep -q '^Workflow mode: standard (' \
  && printf '%s\n' "$OUTCFG" | grep -qF '`lens: security` (depth: checklist' \
  && ! printf '%s\n' "$OUTCFG" | grep -qF 'the adversarial pass'; then
  echo "  ✓ plan-lint.sh --brief with no profile reads workflow.mode from config (standard R4 set)"
else
  echo "  ✗ --brief config mode: $(printf '%s\n' "$OUTCFG" | grep -A2 '^## Tier')"; fail=$((fail+1))
fi
if printf '%s\n' "$OUTA" | grep -A1 '^## Reviewers' | grep -qF '`lens: security`'; then
  echo "  ✓ plan-lint.sh --brief appends the security lens for an auth path"
else
  echo "  ✗ --brief security lens match missed: $OUTA"; fail=$((fail+1))
fi
if printf '%s\n' "$OUTA" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)'; then
  echo "  ✓ plan-lint.sh --brief sets Tier to R4 (high-risk) on a risk path"
else
  echo "  ✗ --brief risk-path Tier wrong: $OUTA"; fail=$((fail+1))
fi
if printf '%s\n' "$OUTA" | grep -A1 '^## Reviewers' | grep -qF 'cross-family.sh --kind review'; then
  echo "  ✓ plan-lint.sh --brief names the external review command on an R4 task"
else
  echo "  ✗ --brief R4 Reviewers missing the external instruction: $OUTA"; fail=$((fail+1))
fi

# v2.180.10 — Task 5: the R4 Reviewers line lists the full round-1 set
# (security-engineer, both universal-reviewer lenses, and the adversarial
# pass via --adversarial on the cross-family runner) in ONE message.
R4LINE=$(printf '%s\n' "$OUTA" | grep -A1 '^## Reviewers')
if printf '%s' "$R4LINE" | grep -qF '`lens: security`' \
  && printf '%s' "$R4LINE" | grep -qF 'lens: spec' \
  && printf '%s' "$R4LINE" | grep -qF 'lens: standards' \
  && printf '%s' "$R4LINE" | grep -qF -- '--adversarial'; then
  echo "  ✓ plan-lint.sh --brief R4 Reviewers names the security lens, both lenses and --adversarial"
else
  echo "  ✗ --brief R4 Reviewers missing the full round-1 set: $R4LINE"; fail=$((fail+1))
fi

# The carried Lite session profile takes precedence over a later configured Full value.
mkdir -p "$TMP/.rolepod"
printf '{"workflow":{"mode":"full"},"review":{"mode":"full"}}\n' > "$TMP/.rolepod/config.json"
OUTLITE=$(cd "$TMP" && HOME="$HOME_FULL" ROLEPOD_SESSION_MODE=lite ROLEPOD_SESSION_SOURCE=global bash "$LINT" --brief 1 "$TMP/brief-auth.md")
LITE_REV=$(printf '%s\n' "$OUTLITE" | awk '/^## Reviewers/{on=1; next} /^## /{on=0} on')
C60='`rolepod-reviewer` `lens: spec` + `rolepod-reviewer` `lens: standards`'
if printf '%s\n' "$OUTLITE" | grep -qxF 'Workflow mode: lite (global)' \
  && [ "$LITE_REV" = "$C60" ] \
  && ! printf '%s\n' "$LITE_REV" | grep -qF 'lens: security' \
  && ! printf '%s\n' "$LITE_REV" | grep -qi 'adversarial'; then
  echo "  ✓ plan-lint.sh --brief R4 keeps carried Lite despite configured Full: Reviewers = exactly the two lenses"
else
  echo "  ✗ --brief R4 Lite Reviewers contract wrong: $LITE_REV"; fail=$((fail+1))
fi
if [ "$(printf '%s\n' "$OUTLITE" | grep -c '^Workflow mode: lite (global)')" -eq 1 ] \
  && ! printf '%s\n' "$OUTLITE" | grep -qF "Cadence:"; then
  echo "  ✓ --brief emits active mode once and no Cadence line"
else
  echo "  ✗ --brief mode compactness: mode-lines=$(printf '%s\n' "$OUTLITE" | grep -c '^Workflow mode: lite (global)'), cadence-present-or-mode-duplicated"; fail=$((fail+1))
fi
rm -rf "$TMP/.rolepod"

# A12: a `## Failure policy (...)` heading with trailing words still reaches the
# brief, and a plan path with a backslash survives (ENVIRON, never awk -v).
BSDIR="$TMP/bs\\dir"; mkdir -p "$BSDIR"
sed 's/^## Failure policy$/## Failure policy (default)/' "$TMP/brief-auth.md" > "$BSDIR/plan.md"
OUTBS=$(cd "$TMP" && ROLEPOD_SESSION_MODE=lite ROLEPOD_SESSION_SOURCE=global bash "$LINT" --brief 1 "$BSDIR/plan.md" 2>&1)
if printf '%s\n' "$OUTBS" | grep -qxF '## Failure policy' \
  && printf '%s\n' "$OUTBS" | grep -qF 'Default: stop.' \
  && printf '%s\n' "$OUTBS" | grep -qF "Plan: $BSDIR/plan.md"; then
  echo "  ✓ plan-lint.sh --brief keeps a suffixed Failure policy heading and a backslash path"
else
  echo "  ✗ --brief suffixed Failure policy / backslash path: $(printf '%s\n' "$OUTBS" | sed -n '1,3p;/Failure policy/,$p' | head -8)"; fail=$((fail+1))
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

# (3d) adversarial-review-split follow-up: a prose path must never count as
# a risk hit — neither via is_security's word match nor via a
# .rolepod/risk-paths add pattern — mirroring the HIGH_RISK= prose filter in
# hooks/precommit-gate.sh, which drops docs before its risk filter. A task
# whose Files are a prose path that names a
# risk word (`core/agents/security-engineer.md`) plus an unrelated companion
# (`tests/static/agent-frontmatter-caps.sh` — a shell script naming no risk
# word of its own; this repo's is_test() only recognises the
# .test./.spec./test_*.py/conftest.py/_test.<go|rs|rb|ex|exs> conventions,
# so a .sh script is NOT is_test) must tier by that other file: neither of
# the two is prose+test together, so it falls to R3 (multi-file), never R2
# or R4, once the prose path is excluded from the risk scan. Before the
# fix, is_security matched "security" inside the prose filename and forced
# R4.
cat > "$TMP/brief-prose-risk.md" <<'EOF'
### Task 1: security doc plus script
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `core/agents/security-engineer.md`, `tests/static/agent-frontmatter-caps.sh`
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTPR=$(bash "$LINT" --brief 1 "$TMP/brief-prose-risk.md")
if printf '%s\n' "$OUTPR" | grep -A1 '^## Tier' | grep -qF 'R3 (multi-file)'; then
  echo "  ✓ plan-lint.sh --brief never tiers R4 on a prose path's risk word alone (is_security exemption)"
else
  echo "  ✗ --brief let a prose path's filename force R4: $(printf '%s\n' "$OUTPR" | grep -A1 '^## Tier' | tail -1)"; fail=$((fail+1))
fi

# Same exemption on the .rolepod/risk-paths add pattern side: a repo-level
# `+` pattern that matches the prose path's text must not tier it R4 either.
RPR2="$TMP/risk-repo-prose"; mkdir -p "$RPR2/.rolepod" "$RPR2/plans"
( cd "$RPR2" && git init -q . )
printf -- '+security-engineer\n' > "$RPR2/.rolepod/risk-paths"
cat > "$RPR2/plans/p.md" <<'EOF'
### Task 1: security doc plus script
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `core/agents/security-engineer.md`, `tests/static/agent-frontmatter-caps.sh`
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTPR2=$(bash "$LINT" --brief 1 "$RPR2/plans/p.md")
if printf '%s\n' "$OUTPR2" | grep -A1 '^## Tier' | grep -qF 'R3 (multi-file)'; then
  echo "  ✓ plan-lint.sh --brief never tiers R4 via a risk-paths add pattern matching a prose path"
else
  echo "  ✗ --brief let a risk-paths add pattern hit a prose path: $(printf '%s\n' "$OUTPR2" | grep -A1 '^## Tier' | tail -1)"; fail=$((fail+1))
fi

# (3e) F7/Desired-6 — plan-lint's is_security must carry every one of the
# gate's 37 terms, not just the 20 it used to know. src/oauth/callback.ts,
# src/api/invoices.ts and src/authentication/login.ts used to brief R2
# (multi-... no, R1/R2) but block as high-risk at commit; now R4.
for f in src/oauth/callback.ts src/api/invoices.ts src/authentication/login.ts; do
  cat > "$TMP/brief-f7.md" <<EOF
### Task 1: risky
- **Delivers:** x.
- **Blocked by:** none
- [ ] **Files:** \`$f\`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
  OUTF7=$(bash "$LINT" --brief 1 "$TMP/brief-f7.md")
  if printf '%s\n' "$OUTF7" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)'; then
    echo "  ✓ plan-lint.sh --brief tiers $f R4 (high-risk) (F7 term coverage)"
  else
    echo "  ✗ $f did not brief R4: $(printf '%s\n' "$OUTF7" | grep -A1 '^## Tier' | tail -1)"; fail=$((fail+1))
  fi
done

# (3f) F11/Desired-6 — plan-lint's is_prose must match the gate's prose rule:
# .mdc and a trailing .tmpl count as prose (docs-only), not code.
for f in .cursor/rules/auth.mdc docs/x.md.tmpl; do
  cat > "$TMP/brief-f11.md" <<EOF
### Task 1: docs
- **Delivers:** x.
- **Blocked by:** none
- [ ] **Files:** \`$f\`
- [ ] **Command:** true
- **Owner:** content-strategist (dev)
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
  OUTF11=$(bash "$LINT" --brief 1 "$TMP/brief-f11.md")
  if printf '%s\n' "$OUTF11" | grep -A1 '^## Tier' | grep -qF 'R1 (docs-only)'; then
    echo "  ✓ plan-lint.sh --brief tiers $f R1 (docs-only) (F11 prose parity)"
  else
    echo "  ✗ $f did not brief R1 (docs-only): $(printf '%s\n' "$OUTF11" | grep -A1 '^## Tier' | tail -1)"; fail=$((fail+1))
  fi
done

# security review 2026-09-24 (final cut before release): is_prose's
# extension / basename test is case-sensitive exactly like the gate —
# auth/README.MD is NOT prose (a literal uppercase .MD extension misses the
# lowercase-only pattern), so it tiers on its own risk term (auth) instead.
cat > "$TMP/brief-caseprose.md" <<'EOF'
### Task 1: readme
- **Delivers:** x.
- **Blocked by:** none
- [ ] **Files:** `auth/README.MD`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTCASEPROSE=$(bash "$LINT" --brief 1 "$TMP/brief-caseprose.md")
if printf '%s\n' "$OUTCASEPROSE" | grep -A1 '^## Tier' | grep -qF 'R1 (docs-only)'; then
  echo "  ✗ auth/README.MD briefed R1 (docs-only) — is_prose is case-insensitive again"; fail=$((fail+1))
else
  echo "  ✓ auth/README.MD is NOT prose (case-sensitive, matches the gate): $(printf '%s\n' "$OUTCASEPROSE" | grep -A1 '^## Tier' | tail -1)"
fi

# (3b) two non-test source files, no risk path → R3 (multi-file), no reviewer
# in the loop (the track-end review covers it — spec lean-loop-
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
OUTR3=$(cd "$TMP" && bash "$LINT" --brief 1 "$TMP/brief-tier-r3.md")
if printf '%s\n' "$OUTR3" | grep -A1 '^## Tier' | grep -qF 'R3 (multi-file)' \
  && printf '%s\n' "$OUTR3" | grep -A1 '^## Reviewers' | tail -1 | grep -qF '`rolepod-reviewer` `lens: spec` + `rolepod-reviewer` `lens: standards`'; then
  echo "  ✓ plan-lint.sh --brief sets Tier to R3 (multi-file); a one-code-task track gets its own review-set cell (both lenses)"
else
  echo "  ✗ --brief two-file Tier/Reviewers wrong: $OUTR3"; fail=$((fail+1))
fi
# (a2) a Lead-owned sibling is not a code task: Task 1 is still the only one.
cat > "$TMP/brief-tier-r3-lead.md" <<'EOF'
### Task 1: two files
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `src/a.py`, `src/b.py`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
### Task 2: lead edit
- **Delivers:** y
- **Blocked by:** 1
- [ ] **Files:** `src/c.py`, `src/d.py`
- [ ] **Command:** true
- **Owner:** Lead
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
if bash "$LINT" --brief 1 "$TMP/brief-tier-r3-lead.md" | grep -A1 '^## Reviewers' | tail -1 | grep -qF 'lens: standards`'; then
  echo "  ✓ plan-lint.sh --brief: a Lead-owned sibling does not count as a code task (lenses line stays)"
else
  echo "  ✗ --brief Lead-owned sibling counted as a code task"; fail=$((fail+1))
fi
# (b) two code tasks in the one Sequential track → none (track-end review).
cat > "$TMP/brief-tier-r3-two.md" <<'EOF'
### Task 1: two files
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `src/a.py`, `src/b.py`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
### Task 2: two more files
- **Delivers:** y
- **Blocked by:** 1
- [ ] **Files:** `src/c.py`, `src/d.py`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUTR3B=$(bash "$LINT" --brief 1 "$TMP/brief-tier-r3-two.md")
if printf '%s\n' "$OUTR3B" | grep -A1 '^## Reviewers' | tail -1 | grep -qF '`none` — the track-end review covers this task'; then
  echo "  ✓ plan-lint.sh --brief: two code tasks in one track → Reviewers none (the track-end review covers them)"
else
  echo "  ✗ --brief two-code-task track Reviewers wrong: $(printf '%s\n' "$OUTR3B" | grep -A1 '^## Reviewers' | tail -1)"; fail=$((fail+1))
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

# (3d) external-pool-review-only: pool on + an R3/R4 task -> the C2 line under
# the lens line (lite / standard / full R4, only-code R3); an R2 task or pool off
# never prints it; the brief has no ## Write section.
HOME_XP="$TMP/home-xpool"; mkdir -p "$HOME_XP/.rolepod"
printf '{"pool":{"reviewer":{"review":"codex"}}}\n' > "$HOME_XP/.rolepod/config.json"
HOME_NOXP="$TMP/home-noxpool"; mkdir -p "$HOME_NOXP/.rolepod"
C2_TXT='Pool on → each lens runs external instead: `bash <cross-family skill folder>/scripts/cross-family.sh --kind review --lens spec --brief <this brief> --attach <diff> --detach`, the same with `--lens standards`, then `--collect <job> --timeout 540` for each in the foreground (exit 6 = still running: run it again); a lens whose run fails, comes back weak or is refused → `rolepod-reviewer` with that lens, same round.'
xp_brief() { # <home> <mode> <plan>
  ( cd "$TMP" && HOME="$1" ROLEPOD_SESSION_MODE="$2" ROLEPOD_SESSION_SOURCE=global bash "$LINT" --brief 1 "$3" )
}
xp_ok=1
for m in lite standard full; do
  o=$(xp_brief "$HOME_XP" "$m" "$TMP/brief-auth.md")
  printf '%s\n' "$o" | grep -qxF "$C2_TXT" || { xp_ok=0; echo "  . pool on $m R4: C2 missing"; }
  o=$(xp_brief "$HOME_NOXP" "$m" "$TMP/brief-auth.md")
  printf '%s\n' "$o" | grep -qF -- '--lens' && { xp_ok=0; echo "  . pool off $m R4: --lens printed"; }
done
o=$(xp_brief "$HOME_XP" lite "$TMP/brief-tier-r3.md")
printf '%s\n' "$o" | grep -qxF "$C2_TXT" || { xp_ok=0; echo "  . pool on only-code R3: C2 missing"; }
o=$(xp_brief "$HOME_NOXP" lite "$TMP/brief-tier-r3.md")
printf '%s\n' "$o" | grep -qF -- '--lens' && { xp_ok=0; echo "  . pool off only-code R3: --lens printed"; }
o=$(xp_brief "$HOME_XP" lite "$TMP/brief-tier-r2.md")
printf '%s\n' "$o" | grep -qF -- '--lens' && { xp_ok=0; echo "  . pool on only-code R2: --lens printed"; }
printf '%s\n' "$o" | grep -q '^## Write' && { xp_ok=0; echo "  . ## Write still printed"; }
if [ "$xp_ok" = 1 ]; then
  echo "  ✓ plan-lint.sh --brief prints the external lens line only with pool on and R3/R4 (lite/standard/full R4, only-code R3); R2 and pool off print none; no ## Write"
else
  echo "  ✗ --brief external lens line wrong"; fail=$((fail+1))
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
ALLOWEDT1=$(printf '%s\n' "$OUTT1" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f && $0 !~ /^- Canonical task receipt /')
# Round shape sits where the owner picks its reviewers (2026-09-21: two owners in a
# row ran round 2 as a message to the finished reviewer — the answer landed at the
# Lead — while the rule sat at the end of a long Bounds line). Pinned on the R4
# auth brief (2026-09-23, lean-loop T2): R2/R3 carries no reviewer in the loop
# any more, so it carries no round-2 line either — only R4 still has one.
A4_REV=$(printf '%s\n' "$OUTA" | awk '/^## Reviewers/{on=1; next} /^## /{on=0} on')
A4_BND=$(printf '%s\n' "$OUTA" | awk '/^## Bounds/{on=1; next} /^## /{on=0} on')
if [ "$(printf '%s\n' "$A4_REV" | grep -c .)" -eq 1 ] \
  && ! printf '%s\n' "$A4_REV" | grep -q 'Round 2+' \
  && ! printf '%s\n' "$A4_BND" | grep -qE 'Foreground|run_in_background|WAITING|ound 2' \
  && printf '%s\n' "$A4_BND" | grep -qE 'review/[A-Za-z0-9-]+-task1-<lens>\.md, <lens> one of spec'; then
  echo "  ✓ plan-lint.sh --brief R4 Reviewers is one line; Bounds hold no round or dispatch-mechanism text and name the report files"
else
  echo "  ✗ --brief R4 Reviewers/Bounds wrong — Reviewers: $A4_REV | Bounds: $A4_BND"; fail=$((fail+1))
fi
OUTR3F=$(cd "$TMP" && HOME="$HOME_FULL" ROLEPOD_SESSION_MODE=full ROLEPOD_SESSION_SOURCE=global bash "$LINT" --brief 1 "$TMP/brief-tier-r3.md")
if [ "$(printf '%s\n' "$OUTR3" | /usr/bin/grep -v '^Workflow mode:')" = "$(printf '%s\n' "$OUTR3F" | /usr/bin/grep -v '^Workflow mode:')" ] \
  && ! printf '%s\n' "$OUTR3" | grep -q '^Review mode:' \
  && ! printf '%s\n' "$OUTR3F" | grep -q '^Review mode:'; then
  echo "  ✓ plan-lint.sh --brief R2/R3 reviewer assignment is stable across workflow intensities"
else
  echo "  ✗ --brief R2/R3 differs between modes"; fail=$((fail+1))
fi
R3_REV=$(printf '%s\n' "$OUTR3" | awk '/^## Reviewers/{on=1; next} /^## /{on=0} on')
R3_BND=$(printf '%s\n' "$OUTR3" | awk '/^## Bounds/{on=1; next} /^## /{on=0} on')
if [ "$(printf '%s\n' "$R3_REV" | grep -c .)" -eq 1 ] && printf '%s\n' "$R3_REV" | sed -n '1p' | grep -qF 'lens: perf' && printf '%s\n' "$R3_REV" | grep -qF 'lens: ui' && printf '%s\n' "$R3_REV" | grep -qF 'lens: arch' && ! printf '%s\n' "$R3_REV" | grep -q 'Round 2+'; then
  echo "  ✓ plan-lint.sh --brief prints one Reviewers line for an only-code R2/R3 task (standard: lenses + matched specialists)"
else
  echo "  ✗ --brief R2/R3 Reviewers wrong: $R3_REV"; fail=$((fail+1))
fi
# ONE test field (2026-09-23, lean-loop T2): the generated Bounds send the
# owner to the Command once, last before returning.
if printf '%s\n' "$R3_BND" | grep -qF 'Return with passing scoped Command evidence; run the repo commit check once' \
  && ! printf '%s\n' "$R3_BND" | grep -q 'Run the Check'; then
  echo "  ✓ --brief Bounds send the owner to the Command, never the Check"
else
  echo "  ✗ --brief Bounds still point the owner at the Check — Bounds: $R3_BND"; fail=$((fail+1))
fi
if printf '%s\n' "$R3_BND" | grep -qF 'Return with passing scoped Command evidence' \
  && ! printf '%s\n' "$R3_BND" | grep -qF 'never the whole suite' \
  && ! printf '%s\n' "$R3_BND" | grep -qF 'only the checks covering the file'; then
  echo "  ✓ --brief Bounds send the owner to the narrowest check, never the whole suite"
else
  echo "  ✗ --brief Bounds lack the narrowest-check wording — Bounds: $R3_BND"; fail=$((fail+1))
fi
if printf '%s\n' "$R3_BND" | grep -qF 'Never `git stash`.'; then
  echo "  ✓ --brief Bounds forbid git stash"
else
  echo "  ✗ --brief Bounds lack the git stash ban — Bounds: $R3_BND"; fail=$((fail+1))
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

# adversarial-review-split follow-up: a task tag written AFTER the backticked role
# and before the colon (`` `devops-sre` (Task 1): `path` ``) must be read as
# part of the label, exactly like a tag written inside the backticks
# (`` `devops-sre (Task 1)`: `path` `` — the T1/T4 case just above). Before
# the fix, the label was only the first backticked token ("devops-sre"), the
# "(Task 1)" tag was lost, and both owner lines matched Task 1 by role name
# alone — leaking Task 2's file into Task 1's brief.
cat > "$TMP/brief-tagout-plan.md" <<'EOF'
## Files to touch
- `hooks/a.sh`
- `hooks/b.sh`
### Task 1: hook a
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `hooks/a.sh`
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** true
### Task 2: hook b
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `hooks/b.sh`
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** true
## Parallel layout
Parallel — contract: `brief-tagout-contract.md`
## Failure policy
Default: stop.
EOF
cat > "$TMP/brief-tagout-contract.md" <<'EOF'
## File ownership
- `devops-sre` (Task 1): `hooks/a.sh`
- `devops-sre` (Task 2): `hooks/b.sh`
EOF
OUTTAG=$(bash "$LINT" --brief 1 "$TMP/brief-tagout-plan.md" "$TMP/brief-tagout-contract.md")
ALLOWEDTAG=$(printf '%s\n' "$OUTTAG" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f && $0 !~ /^- Canonical task receipt /')
if [ "$ALLOWEDTAG" = "- hooks/a.sh" ]; then
  echo "  ✓ plan-lint.sh --brief reads a task tag sitting outside the backticks, before the colon"
else
  echo "  ✗ --brief lost the outside-backtick task tag, leaked via role fallback: $ALLOWEDTAG"; fail=$((fail+1))
fi

# Budget line: the generated brief carries the tool budget (mechanism, not prose).
printf '%s\n' "$OUT" | grep -q '^- Budget: build <= 40 tool calls' \
  && echo "  ✓ --brief Bounds carry the tool budget" \
  || { echo "  ✗ --brief Bounds missing the Budget line"; fail=$((fail+1)); }

# Worktree fence: the Bounds name the task's worktree as the only place to edit
# (2026-09-19: two task owners edited the main checkout's copy before their worktree).
printf '%s\n' "$OUT" | grep -qE '^- Edit only Files allowed under \.\./[A-Za-z0-9._-]+-wt-[a-z0-9-]+-t[0-9]+-[a-z0-9-]+, except update the canonical receipt at .+ in the base checkout; no other base-checkout path is allowed\.' \
  && echo "  ✓ --brief Bounds fence every edit inside the task's worktree" \
  || { echo "  ✗ --brief Bounds do not name the worktree as the only place to edit"; fail=$((fail+1)); }

# Worktree line: the brief names the worktree after the task (mechanism).
printf '%s\n' "$OUT" | grep -q '^## Worktree' \
  && printf '%s\n' "$OUT" | grep -qE '^`git worktree add -b [a-z0-9-]+/t[0-9]+-[a-z0-9-]+ \.\./[A-Za-z0-9._-]+-wt-[a-z0-9-]+-t[0-9]+-[a-z0-9-]+`' \
  && echo "  ✓ --brief prints a task-named worktree command" \
  || { echo "  ✗ --brief Worktree line missing or malformed"; fail=$((fail+1)); }

# A repo dir with a space: the worktree name is slugged, so ticket.sh start can
# parse the command by whitespace (a plain name stays byte-identical, above).
SPACE_REPO="$TMP/Has Space Repo"
mkdir -p "$SPACE_REPO"
( cd "$SPACE_REPO" && git init -q . )
cat > "$SPACE_REPO/plan.md" <<'EOF'
# Space Plan

### Task 1: build it
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `src/a.py`
- [ ] **Command:** pytest src/
- **Owner:** backend-developer
EOF
SPOUT=$(bash "$LINT" --brief 1 "$SPACE_REPO/plan.md" 2>&1)
if printf '%s\n' "$SPOUT" | grep -qE '^`git worktree add -b [a-z0-9-]+/t1-[a-z0-9-]+ \.\./Has-Space-Repo-wt-[a-z0-9-]+-t1-[a-z0-9-]+`' \
  && printf '%s\n' "$SPOUT" | grep -qE 'under \.\./Has-Space-Repo-wt-.*except update the canonical receipt at .+ in the base checkout'; then
  echo "  ✓ --brief slugs a repo dir with a space into the worktree name"
else
  echo "  ✗ --brief left a space in the worktree name: $(printf '%s\n' "$SPOUT" | grep 'git worktree add')"; fail=$((fail+1))
fi

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
## Proof
the fix holds
`pytest -k "test_a" | tee /tmp/out.log`'
if [ "$CMD_TO_DW" = "$EXPECTED_CMD_TO_DW" ]; then
  echo "  ✓ plan-lint.sh --brief prints ## Proof right after ## Command, pipe + quoted string byte-for-byte"
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
DW1=$(printf '%s\n' "$OUTCK1" | awk '/^## Done when/{f=1;next} /^## /{f=0} /^Canonical task receipt:/{f=0} f')
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
- [ ] **Files:** `src/b.sh`, `Makefile`, `README` — bumps `v2.147.0`, reads `KIND`, flips `FLAG=1`, drops `--all`
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
! printf '%s\n' "$OUT" | grep -q '^## Files forbidden' \
  && echo "  ✓ --brief without a cohesion contract prints no Files forbidden heading" \
  || { echo "  ✗ --brief no-contract Files forbidden present: $FB"; fail=$((fail+1)); }
printf '# Contract\n\n## File ownership\n- `Lead`: `src/a.sh`\n' > "$BF/contract.md"
OUTC=$(cd "$BF" && bash "$LINT" --brief 1 plan.md contract.md 2>/dev/null)
FBC=$(printf '%s\n' "$OUTC" | awk '/^## Files forbidden/{f=1;next} /^## /{f=0} f')
printf '%s\n' "$FBC" | grep -qxF -- '- Makefile' && printf '%s\n' "$FBC" | grep -qxF -- '- src/b.sh' \
  && ! printf '%s\n' "$FBC" | grep -q 'FLAG=1\|v2\.147\.0\|KIND\|--all' \
  && echo "  ✓ --brief with a contract: Files forbidden paths carry no backticked commentary (FLAG=1, v2.147.0, KIND)" \
  || { echo "  ✗ --brief contract Files forbidden commentary: $FBC"; fail=$((fail+1)); }
RV1=$(printf '%s\n' "$OUT" | grep -A1 '^## Reviewers' | tail -1)
[ "$RV1" = '`none` — the track-end review covers this task' ] \
  && echo "  ✓ --brief Reviewers default = none (two R2/R3 code tasks: the track-end review covers them)" \
  || { echo "  ✗ --brief Reviewers default: $RV1"; fail=$((fail+1)); }
OUT2=$(cd "$BF" && bash "$LINT" --brief 2 plan.md 2>/dev/null)
RV2=$(printf '%s\n' "$OUT2" | grep -A1 '^## Reviewers' | tail -1)
[ "$RV2" = '`none` — the track-end review covers this task' ] \
  && echo "  ✓ --brief Reviewers never adds qa-tester (E2E), even when the Test line names a user-visible flow" \
  || { echo "  ✗ --brief Reviewers no E2E append: $RV2"; fail=$((fail+1)); }
rm -rf "$BF"

# ── --brief --main (rule a): a task that runs on the main checkout ──────
BM=$(mktemp -d)
cat > "$BM/plan.md" <<'PLAN'
# Main Flag Plan

## Tasks

### Task 1: solo task
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `src/only.sh`
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** Lead
- **Done when:** done

## Failure policy
Default: stop.
PLAN
OUT_NOFLAG=$(cd "$BM" && bash "$LINT" --brief 1 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_NOFLAG" | grep -q '^## Worktree$' && ! printf '%s\n' "$OUT_NOFLAG" | grep -q '^## Checkout$'; then
  echo "  ✓ --brief with no --main is unchanged: still prints ## Worktree"
else
  echo "  ✗ --brief with no --main changed: $OUT_NOFLAG"; fail=$((fail+1))
fi
OUT_MAIN=$(cd "$BM" && bash "$LINT" --brief 1 plan.md --main 2>/dev/null) || true
CHECKOUT=$(printf '%s\n' "$OUT_MAIN" | awk '/^## Checkout/{f=1;next} /^## /{f=0} f')
if [ "$CHECKOUT" = "main checkout — no worktree; run every command in the main checkout" ]; then
  echo "  ✓ --brief --main prints ## Checkout with the main-checkout line"
else
  echo "  ✗ --brief --main Checkout section wrong: $CHECKOUT"; fail=$((fail+1))
fi
if printf '%s\n' "$OUT_MAIN" | grep -q '^## Worktree$'; then
  echo "  ✗ --brief --main still prints ## Worktree"; fail=$((fail+1))
else
  echo "  ✓ --brief --main drops ## Worktree"
fi
BOUNDS_MAIN=$(printf '%s\n' "$OUT_MAIN" | awk '/^## Bounds/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$BOUNDS_MAIN" | grep -qi 'worktree'; then
  echo "  ✗ --brief --main leaves worktree-only wording in Bounds: $BOUNDS_MAIN"; fail=$((fail+1))
else
  echo "  ✓ --brief --main has no worktree-only wording in Bounds"
fi
OUT_MAIN2=$(cd "$BM" && bash "$LINT" --brief --main 1 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_MAIN2" | grep -q '^## Checkout$'; then
  echo "  ✓ --main is recognized in any position after --brief"
else
  echo "  ✗ --main before <N> not recognized: $OUT_MAIN2"; fail=$((fail+1))
fi
# NIT: the header usage / section list and the contract-not-found usage both name --main and ## Checkout.
HEADER=$(sed -n '1,21p' "$LINT")
if printf '%s\n' "$HEADER" | grep -qF -- '--main' && printf '%s\n' "$HEADER" | grep -q 'Checkout'; then
  echo "  ✓ the header usage + section list name --main and ## Checkout"
else
  echo "  ✗ header usage/section list missing --main or Checkout"; fail=$((fail+1))
fi
CNF_ERR=$(cd "$BM" && bash "$LINT" --brief 1 plan.md nope-contract.md 2>&1 >/dev/null) || true
if printf '%s\n' "$CNF_ERR" | grep -qF -- '--main'; then
  echo "  ✓ the contract-not-found usage names --main"
else
  echo "  ✗ contract-not-found usage missing --main: $CNF_ERR"; fail=$((fail+1))
fi
rm -rf "$BM"

# ── --brief Files field (rule b): a backticked token inside a ( … ) parenthetical is a note, never a path ──
BN=$(mktemp -d)
cat > "$BN/plan.md" <<'PLAN'
# Parenthetical Notes Plan

## Tasks

### Task 1: shell writes
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `hooks/block-subagent-commit.sh`, `hooks/lib/session_state.py` (`bash_write_paths` and the helpers only it uses), `hooks/subagent-write-scope.sh` (the synthesized `tool_name: Bash` input path, if it has one), `build/render.sh` (Codex no longer bundles `subagent-write-scope.sh`)
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** Lead
- **Done when:** done

## Failure policy
Default: stop.
PLAN
OUT_N=$(cd "$BN" && bash "$LINT" --brief 1 plan.md 2>/dev/null) || true
ALLOWED_N=$(printf '%s\n' "$OUT_N" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$ALLOWED_N" | grep -qF -- '- hooks/block-subagent-commit.sh' \
  && printf '%s\n' "$ALLOWED_N" | grep -qF -- '- hooks/lib/session_state.py' \
  && printf '%s\n' "$ALLOWED_N" | grep -qF -- '- hooks/subagent-write-scope.sh' \
  && printf '%s\n' "$ALLOWED_N" | grep -qF -- '- build/render.sh' \
  && ! printf '%s\n' "$ALLOWED_N" | grep -qF -- '- bash_write_paths' \
  && ! printf '%s\n' "$ALLOWED_N" | grep -qF -- '- tool_name: Bash'; then
  echo "  ✓ --brief Files allowed drops backticked notes inside a ( … ) parenthetical"
else
  echo "  ✗ --brief Files allowed picked up a parenthetical note: $ALLOWED_N"; fail=$((fail+1))
fi
rm -rf "$BN"

# ── --brief Files field (r1 fix, MAJOR): parens are counted only OUTSIDE backtick spans — a route-group path survives ──
BP=$(mktemp -d)
cat > "$BP/plan.md" <<'PLAN'
# Route Group Plan

## Tasks

### Task 1: route group
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `app/(auth)/login/page.tsx`, `lib/a.ts`
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** Lead
- **Done when:** done

## Failure policy
Default: stop.
PLAN
OUT_P=$(cd "$BP" && bash "$LINT" --brief 1 plan.md 2>/dev/null) || true
ALLOWED_P=$(printf '%s\n' "$OUT_P" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$ALLOWED_P" | grep -qF -- '- app/(auth)/login/page.tsx' \
  && printf '%s\n' "$ALLOWED_P" | grep -qF -- '- lib/a.ts' \
  && ! printf '%s\n' "$ALLOWED_P" | grep -qF -- '- app//login/page.tsx'; then
  echo "  ✓ --brief Files allowed keeps a route-group path intact (parens inside a backtick span are not a note)"
else
  echo "  ✗ --brief Files allowed mangled a route-group path: $ALLOWED_P"; fail=$((fail+1))
fi
rm -rf "$BP"

# ── --brief Files field (r2 fix, rule 1): a ( opens a note only at the start of the value, after whitespace, or after a comma — a ( right after / or a word char is part of a bare path ──
BR=$(mktemp -d)
cat > "$BR/plan.md" <<'PLAN'
# Bare Route Group Plan

## Tasks

### Task 1: bare route group
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** app/(auth)/login/page.tsx, `src/a.py`, app/(tabs)/index.tsx
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** Lead
- **Done when:** done

## Failure policy
Default: stop.
PLAN
OUT_R=$(cd "$BR" && bash "$LINT" --brief 1 plan.md 2>/dev/null) || true
ALLOWED_R=$(printf '%s\n' "$OUT_R" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$ALLOWED_R" | grep -qF -- 'app/(auth)/login/page.tsx' \
  && printf '%s\n' "$ALLOWED_R" | grep -qF -- 'app/(tabs)/index.tsx' \
  && printf '%s\n' "$ALLOWED_R" | grep -qF -- '- src/a.py' \
  && ! printf '%s\n' "$ALLOWED_R" | grep -qF -- 'app//login/page.tsx' \
  && ! printf '%s\n' "$ALLOWED_R" | grep -qF -- 'app//index.tsx'; then
  echo "  ✓ --brief Files allowed keeps a BARE (non-backticked) route-group path intact"
else
  echo "  ✗ --brief Files allowed mangled a bare route-group path: $ALLOWED_R"; fail=$((fail+1))
fi
rm -rf "$BR"

# ── --brief Files field (r2 fix, rule 1): a ( at the very start of the value, or right after a comma with no space, still opens a note ──
BS=$(mktemp -d)
cat > "$BS/plan.md" <<'PLAN'
# Note At Start Plan

## Tasks

### Task 1: note edges
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `a.ts`,(see docs/notes.md)
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** Lead
- **Done when:** done

## Failure policy
Default: stop.
PLAN
OUT_S=$(cd "$BS" && bash "$LINT" --brief 1 plan.md 2>/dev/null) || true
ALLOWED_S=$(printf '%s\n' "$OUT_S" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$ALLOWED_S" | grep -qF -- '- a.ts' && ! printf '%s\n' "$ALLOWED_S" | grep -qF -- 'docs/notes.md'; then
  echo "  ✓ --brief a ( right after a comma with no space still opens a note"
else
  echo "  ✗ --brief comma-adjacent note wrong: $ALLOWED_S"; fail=$((fail+1))
fi
rm -rf "$BS"

# ── --brief Files field (r1 fix, rule 2): a backticked note counts as a path only with a slash; a bare token never counts ──
BQ=$(mktemp -d)
cat > "$BQ/plan.md" <<'PLAN'
# Note Slash Rule Plan

## Tasks

### Task 1: mixed notes
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `lib/a.ts` (+ `tests/static/x.sh`), `src/a.py` (see docs/notes.md)
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** Lead
- **Done when:** done

## Failure policy
Default: stop.
PLAN
OUT_Q=$(cd "$BQ" && bash "$LINT" --brief 1 plan.md 2>/dev/null) || true
ALLOWED_Q=$(printf '%s\n' "$OUT_Q" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$ALLOWED_Q" | grep -qF -- '- lib/a.ts' \
  && printf '%s\n' "$ALLOWED_Q" | grep -qF -- '- tests/static/x.sh' \
  && printf '%s\n' "$ALLOWED_Q" | grep -qF -- '- src/a.py' \
  && ! printf '%s\n' "$ALLOWED_Q" | grep -qF -- '- docs/notes.md'; then
  echo "  ✓ --brief a slash-bearing backticked note is kept, a bare token in a note never counts"
else
  echo "  ✗ --brief note slash rule wrong: $ALLOWED_Q"; fail=$((fail+1))
fi
rm -rf "$BQ"

# ── --brief contract labels (rule c): a label naming several tasks tags each but contributes no files ──
BC=$(mktemp -d)
cat > "$BC/plan.md" <<'PLAN'
# Multi Task Label Plan

## Files to touch
- `hooks/a.sh` — task 1
- `hooks/b.sh` — task 2

## Tasks

### Task 1: first
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `hooks/a.sh`
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** done

### Task 2: second
- **Delivers:** d
- **Blocked by:** Task 1
- [ ] **Files:** `hooks/b.sh`
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** done

## Parallel layout
Parallel — contract: `contract.md`

## Failure policy
Default: stop.
PLAN
cat > "$BC/contract.md" <<'CONTRACT'
# Multi Task Label Contract

## File ownership
- `devops-sre (Tasks 1-4)`: `hooks/a.sh`, `hooks/b.sh`, `hooks/c.sh`, `hooks/d.sh`
CONTRACT
OUT_C=$(cd "$BC" && bash "$LINT" --brief 2 plan.md contract.md 2>/dev/null) || true
ALLOWED_C=$(printf '%s\n' "$OUT_C" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$ALLOWED_C" | grep -qF -- '- hooks/b.sh' \
  && ! printf '%s\n' "$ALLOWED_C" | grep -qF -- '- hooks/a.sh' \
  && ! printf '%s\n' "$ALLOWED_C" | grep -qF -- '- hooks/c.sh' \
  && ! printf '%s\n' "$ALLOWED_C" | grep -qF -- '- hooks/d.sh'; then
  echo "  ✓ --brief a multi-task contract label ('Tasks 1-4') adds none of its files to Files allowed"
else
  echo "  ✗ --brief multi-task label leaked files into Files allowed: $ALLOWED_C"; fail=$((fail+1))
fi
FORBIDDEN_C=$(printf '%s\n' "$OUT_C" | awk '/^## Files forbidden/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$FORBIDDEN_C" | grep -qF -- '- hooks/a.sh'; then
  echo "  ✓ --brief the other owner's path from a multi-task label still lands in Files forbidden"
else
  echo "  ✗ --brief multi-task label path missing from Files forbidden: $FORBIDDEN_C"; fail=$((fail+1))
fi
# A single-task tag, and a role-only label, both keep today's behavior.
cat > "$BC/contract-single.md" <<'CONTRACT'
# Single Task Label Contract

## File ownership
- `devops-sre (T2)`: `hooks/a.sh`, `hooks/b.sh`
CONTRACT
OUT_CS=$(cd "$BC" && bash "$LINT" --brief 2 plan.md contract-single.md 2>/dev/null) || true
ALLOWED_CS=$(printf '%s\n' "$OUT_CS" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$ALLOWED_CS" | grep -qF -- '- hooks/a.sh' && printf '%s\n' "$ALLOWED_CS" | grep -qF -- '- hooks/b.sh'; then
  echo "  ✓ --brief a single-task label (T2) still contributes its files"
else
  echo "  ✗ --brief single-task label regressed: $ALLOWED_CS"; fail=$((fail+1))
fi
cat > "$BC/contract-role.md" <<'CONTRACT'
# Role-only Label Contract

## File ownership
- `devops-sre`: `hooks/a.sh`, `hooks/b.sh`
CONTRACT
OUT_CR=$(cd "$BC" && bash "$LINT" --brief 2 plan.md contract-role.md 2>/dev/null) || true
ALLOWED_CR=$(printf '%s\n' "$OUT_CR" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$ALLOWED_CR" | grep -qF -- '- hooks/a.sh' && printf '%s\n' "$ALLOWED_CR" | grep -qF -- '- hooks/b.sh'; then
  echo "  ✓ --brief a role-only label (no task tag) still contributes its files"
else
  echo "  ✗ --brief role-only label regressed: $ALLOWED_CR"; fail=$((fail+1))
fi
rm -rf "$BC"

# ── --brief contract labels (r1 fix, rule 3): a multi-task label IS a tag for each task it names — tagfound=1, contributes nothing, and the role fallback never runs for those tasks ──
BE=$(mktemp -d)
cat > "$BE/plan.md" <<'PLAN'
# Multi Task Tagfound Plan

## Files to touch
- `lib/a.ts` — task 1
- `lib/b.ts` — task 2
- `lib/c.ts` — task 3
- `lib/secret-c-only.ts` — task 3

## Tasks

### Task 1: first
- **Files:** `lib/a.ts`
- **Command:** true
- **Owner:** backend-developer
- **Done when:** done

### Task 2: second
- **Files:** `lib/b.ts`
- **Command:** true
- **Owner:** backend-developer
- **Done when:** done

### Task 3: third
- **Files:** `lib/c.ts`
- **Command:** true
- **Owner:** backend-developer
- **Done when:** done

## Parallel layout
Parallel — contract: `contract.md`

## Failure policy
Default: stop.
PLAN
cat > "$BE/contract.md" <<'CONTRACT'
# Multi Task Tagfound Contract

## File ownership
- `backend-developer (Tasks 1, 2)`: `lib/a.ts`, `lib/b.ts`
- `backend-developer (T3)`: `lib/c.ts`, `lib/secret-c-only.ts`
CONTRACT
OUT_E1=$(cd "$BE" && bash "$LINT" --brief 1 plan.md contract.md 2>/dev/null) || true
ALLOWED_E1=$(printf '%s\n' "$OUT_E1" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
OUT_E2=$(cd "$BE" && bash "$LINT" --brief 2 plan.md contract.md 2>/dev/null) || true
ALLOWED_E2=$(printf '%s\n' "$OUT_E2" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if ! printf '%s\n' "$ALLOWED_E1" | grep -qF -- 'secret-c-only' \
  && ! printf '%s\n' "$ALLOWED_E1" | grep -qF -- '- lib/c.ts' \
  && ! printf '%s\n' "$ALLOWED_E2" | grep -qF -- 'secret-c-only' \
  && ! printf '%s\n' "$ALLOWED_E2" | grep -qF -- '- lib/c.ts'; then
  echo "  ✓ --brief a same-role multi-task label (Tasks 1, 2) tags its tasks and never leaks a different task label's files via role fallback"
else
  echo "  ✗ --brief multi-task tagfound leak: T1=$ALLOWED_E1 / T2=$ALLOWED_E2"; fail=$((fail+1))
fi
rm -rf "$BE"

# ── --brief contract labels (r1 fix, rule 3): the role fallback never takes a label tagged for a DIFFERENT single task ──
BF2=$(mktemp -d)
cat > "$BF2/plan.md" <<'PLAN'
# Single Task Role Leak Plan

## Tasks

### Task 1: first
- **Files:** `lib/one.ts`
- **Command:** true
- **Owner:** backend-developer
- **Done when:** done

### Task 2: second
- **Files:** `only/t2.py`
- **Command:** true
- **Owner:** backend-developer
- **Done when:** done

### Task 4: fourth
- **Files:** `lib/four.ts`
- **Command:** true
- **Owner:** backend-developer
- **Done when:** done

## Parallel layout
Parallel — contract: `contract.md`

## Failure policy
Default: stop.
PLAN
cat > "$BF2/contract.md" <<'CONTRACT'
# Single Task Role Leak Contract

## File ownership
- `backend-developer (T2)`: `only/t2.py`
CONTRACT
OUT_F1=$(cd "$BF2" && bash "$LINT" --brief 1 plan.md contract.md 2>/dev/null) || true
ALLOWED_F1=$(printf '%s\n' "$OUT_F1" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
OUT_F4=$(cd "$BF2" && bash "$LINT" --brief 4 plan.md contract.md 2>/dev/null) || true
ALLOWED_F4=$(printf '%s\n' "$OUT_F4" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if ! printf '%s\n' "$ALLOWED_F1" | grep -qF -- 'only/t2.py' && ! printf '%s\n' "$ALLOWED_F4" | grep -qF -- 'only/t2.py'; then
  echo "  ✓ --brief backend-developer (T2) never reaches the Task 1 or Task 4 role-fallback brief"
else
  echo "  ✗ --brief single-task label leaked via role fallback: T1=$ALLOWED_F1 / T4=$ALLOWED_F4"; fail=$((fail+1))
fi
rm -rf "$BF2"

# ── --brief contract labels (r1 fix, rule 4): is_multitask covers T1-4, an en dash, and, /, and T1-then-T2 connectors ──
BG=$(mktemp -d)
cat > "$BG/plan.md" <<'PLAN'
# Connector Coverage Plan

## Tasks

### Task 1: first
- **Files:** `hooks/a.sh`
- **Command:** true
- **Owner:** devops-sre
- **Done when:** done

### Task 2: second
- **Files:** `hooks/b.sh`
- **Command:** true
- **Owner:** devops-sre
- **Done when:** done

## Failure policy
Default: stop.
PLAN
for variant in 'devops-sre (T1-4)' 'devops-sre (Tasks 1–4)' 'devops-sre (Tasks 1 and 2)' 'devops-sre (T1/T2)' 'devops-sre (T1, then T2)' 'devops-sre (Tasks 1-4 shared)' 'devops-sre (Tasks 1 and 2 only)' 'devops-sre (T2 — T3 hooks)'; do
  printf '# Connector Contract\n\n## File ownership\n- `%s`: `hooks/range-leak.py`\n' "$variant" > "$BG/contract.md"
  OUT_G1=$(cd "$BG" && bash "$LINT" --brief 1 plan.md contract.md 2>/dev/null) || true
  OUT_G2=$(cd "$BG" && bash "$LINT" --brief 2 plan.md contract.md 2>/dev/null) || true
  A_G1=$(printf '%s\n' "$OUT_G1" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
  A_G2=$(printf '%s\n' "$OUT_G2" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
  if printf '%s\n' "$A_G1" | grep -qF -- 'range-leak.py' || printf '%s\n' "$A_G2" | grep -qF -- 'range-leak.py'; then
    echo "  ✗ --brief is_multitask missed connector [$variant]: T1=$A_G1 / T2=$A_G2"; fail=$((fail+1))
  else
    echo "  ✓ --brief is_multitask catches connector [$variant]"
  fi
done
rm -rf "$BG"

# ── --brief contract labels (a bare count after a connector, followed by whitespace + a letter, is a count not a task number) ──
BCNT=$(mktemp -d)
cat > "$BCNT/plan.md" <<'PLAN'
# Count Not Task Plan

## Tasks

### Task 2: second
- **Files:** `hooks/b.sh`
- **Command:** true
- **Owner:** devops-sre
- **Done when:** done

### Task 3: third
- **Files:** `hooks/c.sh`
- **Command:** true
- **Owner:** devops-sre
- **Done when:** done

## Failure policy
Default: stop.
PLAN
cat > "$BCNT/contract.md" <<'CONTRACT'
# Count Not Task Contract

## File ownership
- `devops-sre (T2 — 3 hooks)`: `hooks/count-x.sh`
CONTRACT
OUT_CNT2=$(cd "$BCNT" && bash "$LINT" --brief 2 plan.md contract.md 2>/dev/null) || true
OUT_CNT3=$(cd "$BCNT" && bash "$LINT" --brief 3 plan.md contract.md 2>/dev/null) || true
A_CNT2=$(printf '%s\n' "$OUT_CNT2" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
A_CNT3=$(printf '%s\n' "$OUT_CNT3" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$A_CNT2" | grep -qF -- 'hooks/count-x.sh' && ! printf '%s\n' "$A_CNT3" | grep -qF -- 'hooks/count-x.sh'; then
  echo "  ✓ --brief a bare count after a connector ('T2 — 3 hooks') is not read as task 3"
else
  echo "  ✗ --brief 'T2 — 3 hooks' misread the count as a task span: T2=$A_CNT2 / T3=$A_CNT3"; fail=$((fail+1))
fi
rm -rf "$BCNT"

# ── --brief contract labels (r2 fix, rule 2): tagspan chains every number in a list/range, not just one further number ──
# A multi-task label never contributes its own files (by design), so the
# only way to observe the chain-length bug is a SECOND, bare same-role
# label in the same contract: a task the multi-task label correctly names
# gets tagfound=1 (role fallback off, the bare label never reaches it); a
# task the chain fails to reach falls through to the role fallback and
# incorrectly picks up the bare label's file. Every task the multi-task
# label lists must behave the same way (none of them get the bare file).
BH=$(mktemp -d)
cat > "$BH/plan.md" <<'PLAN'
# Chained Numbers Plan

## Tasks

### Task 1: first
- **Files:** `lib/t1.ts`
- **Command:** true
- **Owner:** backend-developer
- **Done when:** done

### Task 2: second
- **Files:** `lib/t2.ts`
- **Command:** true
- **Owner:** backend-developer
- **Done when:** done

### Task 3: third
- **Files:** `lib/t3.ts`
- **Command:** true
- **Owner:** backend-developer
- **Done when:** done

### Task 5: fifth
- **Files:** `lib/t5.ts`
- **Command:** true
- **Owner:** backend-developer
- **Done when:** done

## Failure policy
Default: stop.
PLAN
cat > "$BH/contract-list.md" <<'CONTRACT'
# Three-way List Contract

## File ownership
- `backend-developer (T1, T3, T5)`: `shared/three.py`
- `backend-developer`: `shared/bare.py`
CONTRACT
cat > "$BH/contract-mixed.md" <<'CONTRACT'
# Range Plus List Contract

## File ownership
- `backend-developer (T1-T2, T5)`: `shared/mixed.py`
- `backend-developer`: `shared/bare2.py`
CONTRACT
LIST_OK=1
for t in 1 3 5; do
  OUT_H=$(cd "$BH" && bash "$LINT" --brief "$t" plan.md contract-list.md 2>/dev/null) || true
  A_H=$(printf '%s\n' "$OUT_H" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
  printf '%s\n' "$A_H" | grep -qF -- 'shared/bare.py' && { LIST_OK=0; echo "  ✗ --brief (T1, T3, T5) left Task $t untagged, leaking the bare same-role label: $A_H"; fail=$((fail+1)); }
done
[ "$LIST_OK" -eq 1 ] && echo "  ✓ --brief a 3-way list (T1, T3, T5) tags every task it lists, including the third, so none fall through to the bare role label"
MIXED_OK=1
for t in 1 2 5; do
  OUT_H2=$(cd "$BH" && bash "$LINT" --brief "$t" plan.md contract-mixed.md 2>/dev/null) || true
  A_H2=$(printf '%s\n' "$OUT_H2" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
  printf '%s\n' "$A_H2" | grep -qF -- 'shared/bare2.py' && { MIXED_OK=0; echo "  ✗ --brief (T1-T2, T5) left Task $t untagged, leaking the bare same-role label: $A_H2"; fail=$((fail+1)); }
done
[ "$MIXED_OK" -eq 1 ] && echo "  ✓ --brief a range plus a further list entry (T1-T2, T5) tags every task, including the trailing T5"
rm -rf "$BH"

# ── --brief Expected failing signal / On fail: both print verbatim, right
# after Test / evidence and Done when respectively, continuation lines
# kept; a task without either field prints neither heading; an undeleted
# template placeholder (a value starting "<") prints neither heading
# either — same guard as Proof.
EF=$(mktemp -d)
cat > "$EF/plan.md" <<'EOF'
### Task 1: with both fields
- **Delivers:** d1
- **Blocked by:** none
- [ ] **Files:** `src/a.ts`
- [ ] **Change:** c1
- [ ] **Test / evidence:** t1
- [ ] **Expected failing signal:** TypeError: x is not defined
  at line 12, before the guard is added
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done1
- **On fail:** revert the migration
  and notify on-call

### Task 2: neither field
- **Delivers:** d2
- **Blocked by:** none
- [ ] **Files:** `src/b.ts`
- [ ] **Change:** c2
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done2

### Task 3: undeleted placeholders
- **Delivers:** d3
- **Blocked by:** none
- [ ] **Files:** `src/c.ts`
- [ ] **Change:** c3
- [ ] **Expected failing signal:** <the error the failing test throws>
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done3
- **On fail:** <what to do when the fix does not stick>

## Parallel layout
Sequential — single owner.
## Failure policy
Default: stop.
EOF
OUT_EF1=$(cd "$EF" && bash "$LINT" --brief 1 plan.md 2>/dev/null) || true
NEXT_HEAD_EFS=$(printf '%s\n' "$OUT_EF1" | awk '/^## Expected failing signal/{f=1;next} f && /^## /{print;exit}')
if printf '%s\n' "$OUT_EF1" | grep -A2 '^## Expected failing signal' | grep -qF 'TypeError: x is not defined' \
  && printf '%s\n' "$OUT_EF1" | grep -A2 '^## Expected failing signal' | grep -qF 'at line 12, before the guard is added' \
  && [ "$NEXT_HEAD_EFS" = "## Command" ]; then
  echo "  ✓ --brief prints Expected failing signal verbatim (with its continuation) right after Test / evidence"
else
  echo "  ✗ --brief Expected failing signal wrong: $OUT_EF1"; fail=$((fail+1))
fi
NEXT_HEAD_OF=$(printf '%s\n' "$OUT_EF1" | awk '/^## On fail/{f=1;next} f && /^## /{print;exit}')
if printf '%s\n' "$OUT_EF1" | grep -A2 '^## On fail' | grep -qF 'revert the migration' \
  && printf '%s\n' "$OUT_EF1" | grep -A2 '^## On fail' | grep -qF 'and notify on-call' \
  && [ "$NEXT_HEAD_OF" = "## Reviewers" ]; then
  echo "  ✓ --brief prints On fail verbatim (with its continuation) right after Done when"
else
  echo "  ✗ --brief On fail wrong: $OUT_EF1"; fail=$((fail+1))
fi
OUT_EF2=$(cd "$EF" && bash "$LINT" --brief 2 plan.md 2>/dev/null) || true
if ! printf '%s\n' "$OUT_EF2" | grep -q '^## Expected failing signal' && ! printf '%s\n' "$OUT_EF2" | grep -q '^## On fail'; then
  echo "  ✓ --brief prints neither heading for a task that carries neither field"
else
  echo "  ✗ --brief printed a heading for a field the task never had: $OUT_EF2"; fail=$((fail+1))
fi
OUT_EF3=$(cd "$EF" && bash "$LINT" --brief 3 plan.md 2>/dev/null) || true
if ! printf '%s\n' "$OUT_EF3" | grep -q '^## Expected failing signal' && ! printf '%s\n' "$OUT_EF3" | grep -q '^## On fail'; then
  echo "  ✓ --brief prints neither heading when the value is an undeleted template placeholder"
else
  echo "  ✗ --brief printed an undeleted placeholder as a real field: $OUT_EF3"; fail=$((fail+1))
fi
rm -rf "$EF"

# ── --brief Tier: a "## High-risk surfaces touched" line naming a task
# counts as a risk hit exactly like a risk-path file, same precedence —
# a generic (non-risk-word) path named "-> Task 2" tiers Task 2 to R4 with
# security-engineer while Task 1 (not named anywhere) keeps its own tier.
# A line naming several tasks must tag EVERY one it names, including a
# task named only in the LATER position — a comma list and an "and" list
# both use the full word "Task N" there, which tagspan's own chaining
# does not recognize (the bug this round fixes), so each case below names
# its later task ONLY in the later slot, never also via a range or
# another line, so a naive single label_names_task(line, want) call would
# fail it. The tag decides, not the word: a "None - ..." line that still
# names a task tiers it; a task tag appearing after the section's next "## " heading is
# outside High-risk surfaces touched and must not tier its task; a
# prose-only named task stays R1 (same precedence as a risk-path file).
HR=$(mktemp -d)
cat > "$HR/plan.md" <<'EOF'
### Task 1: unrelated
- **Delivers:** d1
- **Blocked by:** none
- [ ] **Files:** `src/lib/other.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done1

### Task 2: named generic path
- **Delivers:** d2
- **Blocked by:** none
- [ ] **Files:** `src/lib/request-guard.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done2

### Task 3: comma list, later position
- **Delivers:** d3
- **Blocked by:** none
- [ ] **Files:** `src/lib/other3.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done3

### Task 4: and list, earlier position
- **Delivers:** d4
- **Blocked by:** none
- [ ] **Files:** `src/lib/other4.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done4

### Task 5: and list, later position
- **Delivers:** d5
- **Blocked by:** none
- [ ] **Files:** `src/lib/other5.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done5

### Task 6: outside the section, must not tier
- **Delivers:** d6
- **Blocked by:** none
- [ ] **Files:** `src/lib/other6.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done6

### Task 7: None line, tagged, later position
- **Delivers:** d7
- **Blocked by:** none
- [ ] **Files:** `src/lib/other7.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done7

### Task 8: not named anywhere, prose-only
- **Delivers:** d8
- **Blocked by:** none
- [ ] **Files:** `docs/readme8.md`
- [ ] **Command:** true
- **Owner:** content-strategist
- **Done when:** done8

## High-risk surfaces touched
- `src/lib/request-guard.ts` → Task 2
- session cookie → Task 2, Task 3
- auth → Task 4 and billing → Task 5
- None — a note that also reads Task 7
- docs → Task 8

## Parallel layout
Sequential — Task 6 gets a passing mention here, outside the section above.
## Failure policy
Default: stop.
EOF
OUT_HR1=$(cd "$HR" && bash "$LINT" --brief 1 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_HR1" | grep -A1 '^## Tier' | grep -qF 'R2 (one file + test)'; then
  echo "  ✓ --brief Task 1 (not named in High-risk) keeps its own tier"
else
  echo "  ✗ --brief Task 1 tier changed by an unrelated High-risk line: $OUT_HR1"; fail=$((fail+1))
fi
OUT_HR2=$(cd "$HR" && bash "$LINT" --brief 2 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_HR2" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)' \
  && [ "$(printf '%s\n' "$OUT_HR2" | grep -A1 '^## Reviewers' | tail -1)" = '`none` — the track-end review covers this task' ]; then
  echo "  ✓ --brief a generic path named -> Task 2 in High-risk surfaces tiers it R4; Reviewers none (another code task shares the track)"
else
  echo "  ✗ --brief High-risk-named generic path did not tier R4: $OUT_HR2"; fail=$((fail+1))
fi
OUT_HR3=$(cd "$HR" && bash "$LINT" --brief 3 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_HR3" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)'; then
  echo "  ✓ --brief a comma list (-> Task 2, Task 3) tags the LATER task too, not just the first"
else
  echo "  ✗ --brief comma list missed the later task (Task 3): $OUT_HR3"; fail=$((fail+1))
fi
OUT_HR4=$(cd "$HR" && bash "$LINT" --brief 4 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_HR4" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)'; then
  echo "  ✓ --brief an and list (auth -> Task 4 and billing -> Task 5) tags the earlier task"
else
  echo "  ✗ --brief and list missed the earlier task (Task 4): $OUT_HR4"; fail=$((fail+1))
fi
OUT_HR5=$(cd "$HR" && bash "$LINT" --brief 5 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_HR5" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)'; then
  echo "  ✓ --brief an and list (auth -> Task 4 and billing -> Task 5) tags the LATER task too, not just the first"
else
  echo "  ✗ --brief and list missed the later task (Task 5): $OUT_HR5"; fail=$((fail+1))
fi
OUT_HR6=$(cd "$HR" && bash "$LINT" --brief 6 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_HR6" | grep -A1 '^## Tier' | grep -qF 'R2 (one file + test)'; then
  echo "  ✓ --brief a task tag after the section's next ## heading (Parallel layout) never tiers its task — hrsec closes"
else
  echo "  ✗ --brief a mention outside High-risk surfaces touched still tiered Task 6: $OUT_HR6"; fail=$((fail+1))
fi
OUT_HR7=$(cd "$HR" && bash "$LINT" --brief 7 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_HR7" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)'; then
  echo "  ✓ --brief a line reading 'None' still tiers a task it names by tag (the tag decides, not the word)"
else
  echo "  ✗ --brief a None line with a real task tag failed to tier Task 7: $OUT_HR7"; fail=$((fail+1))
fi
OUT_HR8=$(cd "$HR" && bash "$LINT" --brief 8 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_HR8" | grep -A1 '^## Tier' | grep -qF 'R1 (docs-only)'; then
  echo "  ✓ --brief a prose-only task named in High-risk surfaces still stays R1 (same precedence as a risk-path file)"
else
  echo "  ✗ --brief prose-only task tier changed by a High-risk mention: $OUT_HR8"; fail=$((fail+1))
fi
rm -rf "$HR"

# ── --brief Tier: the "High-risk surfaces touched" heading match is
# case-insensitive — a plan headed "## High-Risk Surfaces Touched" still
# tiers a task it names, same as the exact-case heading above. Task 1 is
# named inside the mixed-case section and must tier R4; Task 2 is named
# only after the section's next "## " heading and must not tier; Task 3 is
# named but prose-only (docs path) and stays R1, same precedence as the
# exact-case fixture. The plain structural lint (no --brief) must stay
# clean on this fixture too — the heading match only feeds tiering.
HRC=$(mktemp -d)
cat > "$HRC/plan.md" <<'EOF'
### Task 1: named in mixed-case heading section
- **Delivers:** d1
- **Blocked by:** none
- [ ] **Files:** `src/lib/other-mc.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done1

### Task 2: outside the section, must not tier
- **Delivers:** d2
- **Blocked by:** none
- [ ] **Files:** `src/lib/other-mc2.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done2

### Task 3: named but prose-only
- **Delivers:** d3
- **Blocked by:** none
- [ ] **Files:** `docs/readme-mc.md`
- [ ] **Command:** true
- **Owner:** content-strategist
- **Done when:** done3

## High-Risk Surfaces Touched
- `src/lib/other-mc.ts` → Task 1
- docs → Task 3

## Parallel layout
Sequential — Task 2 gets a passing mention here, outside the section above.
## Failure policy
Default: stop.
EOF
OUT_HRC1=$(cd "$HRC" && bash "$LINT" --brief 1 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_HRC1" | grep -A1 '^## Tier' | grep -qF 'R4 (high-risk)' \
  && [ "$(printf '%s\n' "$OUT_HRC1" | grep -A1 '^## Reviewers' | tail -1)" = '`none` — the track-end review covers this task' ]; then
  echo "  ✓ --brief a mixed-case '## High-Risk Surfaces Touched' heading tiers its named task R4; Reviewers none (track-end review)"
else
  echo "  ✗ --brief mixed-case High-Risk heading did not tier Task 1: $OUT_HRC1"; fail=$((fail+1))
fi
OUT_HRC2=$(cd "$HRC" && bash "$LINT" --brief 2 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_HRC2" | grep -A1 '^## Tier' | grep -qF 'R2 (one file + test)'; then
  echo "  ✓ --brief a mention after the mixed-case section's next ## heading never tiers Task 2"
else
  echo "  ✗ --brief a mention outside the mixed-case High-Risk section still tiered Task 2: $OUT_HRC2"; fail=$((fail+1))
fi
OUT_HRC3=$(cd "$HRC" && bash "$LINT" --brief 3 plan.md 2>/dev/null) || true
if printf '%s\n' "$OUT_HRC3" | grep -A1 '^## Tier' | grep -qF 'R1 (docs-only)'; then
  echo "  ✓ --brief a prose-only task named in the mixed-case High-Risk section still stays R1"
else
  echo "  ✗ --brief prose-only task tier changed by the mixed-case High-Risk mention: $OUT_HRC3"; fail=$((fail+1))
fi
if OUT_HRCS=$(cd "$HRC" && bash "$LINT" plan.md 2>&1); then
  echo "  ✓ plan-lint.sh structural lint stays clean on the mixed-case High-Risk fixture"
else
  echo "  ✗ plan-lint.sh structural lint unexpectedly failed on the mixed-case High-Risk fixture: $OUT_HRCS"; fail=$((fail+1))
fi
rm -rf "$HRC"

# ── Fence rule (2026-09-28 plan-fence Task 1): a fenced block is literal —
# it never becomes a phantom task, cuts a brief, or counts as a path/field.
cat > "$TMP/fence-a.md" <<'EOF'
# Fence Plan A

## Tasks

### Task 1: build with a fenced edit spec
- **Delivers:** d1
- **Blocked by:** none
- [ ] **Files:** `app/service.rb`
- [ ] **Change:**
```
OLD:
### Task 9: x
## Not a section
- [ ] **Files:** y
NEW:
replaced
```
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done1

### Task 2: second real task
- **Delivers:** d2
- **Blocked by:** Task 1
- [ ] **Files:** `app/other.rb`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done2

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop.
EOF
if OUT_FA=$(bash "$LINT" "$TMP/fence-a.md" 2>&1); then
  if printf '%s\n' "$OUT_FA" | grep -qF 'every task carries a Command (2/2)'; then
    echo "  ✓ plan-lint.sh: a fenced phantom '### Task 9' never becomes a real task (2/2)"
  else
    echo "  ✗ plan-lint.sh miscounted tasks with a fenced phantom heading: $OUT_FA"; fail=$((fail+1))
  fi
else
  echo "  ✗ plan-lint.sh failed a valid plan whose Task 1 carries a fenced edit spec: $OUT_FA"; fail=$((fail+1))
fi
OUT_FA_BRIEF=$(bash "$LINT" --brief 1 "$TMP/fence-a.md" 2>&1)
if printf '%s\n' "$OUT_FA_BRIEF" | grep -qF '### Task 9: x' \
  && printf '%s\n' "$OUT_FA_BRIEF" | grep -qF '## Not a section' \
  && printf '%s\n' "$OUT_FA_BRIEF" | grep -qF -- '- [ ] **Files:** y' \
  && printf '%s\n' "$OUT_FA_BRIEF" | grep -qF 'NEW:'; then
  echo "  ✓ plan-lint.sh --brief 1 prints every fenced line through the closing fence"
else
  echo "  ✗ plan-lint.sh --brief 1 cut the brief at the fenced content: $OUT_FA_BRIEF"; fail=$((fail+1))
fi
# Round-2: the CLOSING fence delimiter itself is printed, and parsing
# resumes correctly after it — the real Command field (never swallowed by
# the fence) still shows as "true".
if printf '%s\n' "$OUT_FA_BRIEF" | grep -qF -- '```' \
  && printf '%s\n' "$OUT_FA_BRIEF" | grep -A1 '^## Command' | grep -qF 'true'; then
  echo "  ✓ plan-lint.sh --brief 1 prints the closing fence and resumes the real Command after it"
else
  echo "  ✗ plan-lint.sh --brief 1 lost the closing fence or the Command after it: $OUT_FA_BRIEF"; fail=$((fail+1))
fi
# Round-2: a fenced line never widens Files allowed with a phantom path —
# put the fence right after the Files bullet instead of Change, holding a
# backticked path that must never surface in Files allowed.
cat > "$TMP/fence-files.md" <<'EOF'
# Fence Files Plan

## Tasks

### Task 1: files then a fence
- **Delivers:** d1
- **Blocked by:** none
- [ ] **Files:** `app/real.rb`
```
`app/leaked.rb`
```
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done1

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop.
EOF
OUT_FF_BRIEF=$(bash "$LINT" --brief 1 "$TMP/fence-files.md" 2>&1)
ALLOWED_FF=$(printf '%s\n' "$OUT_FF_BRIEF" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$ALLOWED_FF" | grep -qF -- '- app/real.rb' \
  && ! printf '%s\n' "$ALLOWED_FF" | grep -qF -- 'app/leaked.rb'; then
  echo "  ✓ plan-lint.sh --brief 1: a fenced line right after Files never widens Files allowed"
else
  echo "  ✗ plan-lint.sh --brief 1 leaked a fenced path into Files allowed: $ALLOWED_FF"; fail=$((fail+1))
fi
# Round-3 (review round 2, both lenses): a fenced line while Files is the
# open field is not a prose field, so it never joins Command (or any other
# parsed field) either — it lands in its own `## Plan text` section, right
# after `## Change`, never under `## Command` and never under
# `## Files allowed`.
PLANTEXT_FF=$(printf '%s\n' "$OUT_FF_BRIEF" | awk '/^## Plan text/{f=1;next} /^## /{f=0} f')
COMMAND_FF=$(printf '%s\n' "$OUT_FF_BRIEF" | awk '/^## Command/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$PLANTEXT_FF" | grep -qF -- '`app/leaked.rb`' \
  && ! printf '%s\n' "$COMMAND_FF" | grep -qF -- '`app/leaked.rb`' \
  && ! printf '%s\n' "$ALLOWED_FF" | grep -qF -- 'app/leaked.rb'; then
  echo "  ✓ plan-lint.sh --brief 1: a fenced line right after Files prints under '## Plan text', never Command or Files allowed"
else
  echo "  ✗ plan-lint.sh --brief 1 misplaced the fenced line after Files: PLANTEXT=[$PLANTEXT_FF] COMMAND=[$COMMAND_FF]"; fail=$((fail+1))
fi

# ── Round-3: Files is the LAST field before the next task heading — the
# fenced line right after it still has to print (as '## Plan text'),
# never silently dropped just because no field follows it in this task.
cat > "$TMP/fence-files-last.md" <<'EOF'
# Fence Files Last Plan

## Tasks

### Task 1: files is the last field
- **Delivers:** d1
- **Blocked by:** none
- [ ] **Command:** true
- [ ] **Files:** `app/real2.rb`
```
`app/leaked2.rb`
```
### Task 2: second task
- **Delivers:** d2
- **Blocked by:** Task 1
- [ ] **Files:** `app/other.rb`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done2

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop.
EOF
OUT_FFL_BRIEF=$(bash "$LINT" --brief 1 "$TMP/fence-files-last.md" 2>&1)
if printf '%s\n' "$OUT_FFL_BRIEF" | grep -A5 '^## Plan text' | grep -qF -- '`app/leaked2.rb`'; then
  echo "  ✓ plan-lint.sh --brief 1: a fenced line after the task's LAST field still prints under '## Plan text'"
else
  echo "  ✗ plan-lint.sh --brief 1 dropped a fenced line after the task's last field: $OUT_FFL_BRIEF"; fail=$((fail+1))
fi

# ── Fence rule: a fenced line BEFORE the task's first field is buffered and
# still printed in the brief, never silently dropped.
cat > "$TMP/fence-pre.md" <<'EOF'
# Fence Pre Plan

## Tasks

### Task 1: a fence before any field
```
pre-field fenced note
```
- **Delivers:** d1
- **Blocked by:** none
- [ ] **Files:** `app/pre.rb`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done1

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop.
EOF
OUT_PRE_BRIEF=$(bash "$LINT" --brief 1 "$TMP/fence-pre.md" 2>&1)
if printf '%s\n' "$OUT_PRE_BRIEF" | grep -qF 'pre-field fenced note'; then
  echo "  ✓ plan-lint.sh --brief 1 keeps a fence that opens before the first field"
else
  echo "  ✗ plan-lint.sh --brief 1 dropped a fence that opened before the first field: $OUT_PRE_BRIEF"; fail=$((fail+1))
fi

# ── Fence rule: a fenced '## Failure policy' heading never satisfies the
# real-heading check — this plan's ONLY '## Failure policy' is inside a fence.
cat > "$TMP/fence-failpolicy.md" <<'EOF'
# Fence Failure Policy Plan

## Tasks

### Task 1: only task
- **Delivers:** d1
- **Blocked by:** none
- [ ] **Files:** `app/x.rb`
- [ ] **Change:**
```
## Failure policy
Default: stop.
```
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done1

## Parallel layout
Sequential — single owner.
EOF
if OUT_FP=$(bash "$LINT" "$TMP/fence-failpolicy.md" 2>&1); then
  echo "  ✗ plan-lint.sh passed a plan whose only '## Failure policy' is fenced: $OUT_FP"; fail=$((fail+1))
else
  if printf '%s\n' "$OUT_FP" | grep -qF "missing '## Failure policy'"; then
    echo "  ✓ plan-lint.sh: a fenced '## Failure policy' heading never satisfies the check"
  else
    echo "  ✗ plan-lint.sh failed for the wrong reason on the fenced Failure-policy plan: $OUT_FP"; fail=$((fail+1))
  fi
fi

# ── Fence rule: a fenced '## File ownership' section inside a contract is
# ignored by both --brief and the lint ownership check — the fenced copy
# duplicate-owns the same path under a different label, which would (if not
# fence-aware) either dual-own it in the plain lint or leak a second file
# into --brief's Files allowed union.
cat > "$TMP/fence-own-plan.md" <<'EOF'
# Fence Ownership Plan

## Files to touch
- `app/real.rb` — real file

## Tasks

### Task 1: only task
- **Delivers:** d1
- **Blocked by:** none
- [ ] **Files:** `app/real.rb`
- [ ] **Command:** true
- **Owner:** backend-developer (T1)
- **Done when:** done1

## Parallel layout
Parallel — contract: `fence-own-contract.md`

## Failure policy
Default: stop.
EOF
cat > "$TMP/fence-own-contract.md" <<'EOF'
# Fence Ownership Contract

## File ownership
- `backend-developer (T1)`: `app/real.rb`

## Notes
```
## File ownership
- `frontend-developer (T1)`: `app/real.rb`, `app/fake.rb`
```
EOF
if OUT_FOWN=$(bash "$LINT" "$TMP/fence-own-plan.md" "$TMP/fence-own-contract.md" 2>&1); then
  if printf '%s\n' "$OUT_FOWN" | grep -qF 'every touched file has exactly one owner'; then
    echo "  ✓ plan-lint.sh: a fenced duplicate '## File ownership' section never dual-owns a path"
  else
    echo "  ✗ plan-lint.sh passed but without the expected ownership line: $OUT_FOWN"; fail=$((fail+1))
  fi
else
  echo "  ✗ plan-lint.sh rejected a plan whose only ownership conflict is fenced: $OUT_FOWN"; fail=$((fail+1))
fi
OUT_FOWN_BRIEF=$(bash "$LINT" --brief 1 "$TMP/fence-own-plan.md" "$TMP/fence-own-contract.md" 2>&1)
ALLOWED_FOWN=$(printf '%s\n' "$OUT_FOWN_BRIEF" | awk '/^## Files allowed/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$ALLOWED_FOWN" | grep -qF -- '- app/real.rb' \
  && ! printf '%s\n' "$ALLOWED_FOWN" | grep -qF -- 'app/fake.rb'; then
  echo "  ✓ plan-lint.sh --brief 1: a fenced '## File ownership' entry never leaks into Files allowed"
else
  echo "  ✗ plan-lint.sh --brief 1 leaked a fenced ownership entry into Files allowed: $ALLOWED_FOWN"; fail=$((fail+1))
fi

# ── Fence rule: a 4-backtick fence wrapping a 3-backtick fence stays literal
# the whole way through (the inner 3-backtick run never closes the outer one).
cat > "$TMP/fence-b.md" <<'EOF'
# Fence Plan B

## Tasks

### Task 1: nested fence body
- **Delivers:** d1
- **Blocked by:** none
- [ ] **Files:** `app/nested.rb`
- [ ] **Change:**
````
outer fence
```
### Task 9: still nested
```
more outer
````
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done1

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop.
EOF
if OUT_FB=$(bash "$LINT" "$TMP/fence-b.md" 2>&1); then
  if printf '%s\n' "$OUT_FB" | grep -qF 'every task carries a Command (1/1)'; then
    echo "  ✓ plan-lint.sh: a 3-backtick fence nested inside a 4-backtick fence stays literal"
  else
    echo "  ✗ plan-lint.sh miscounted tasks with a nested fence: $OUT_FB"; fail=$((fail+1))
  fi
else
  echo "  ✗ plan-lint.sh failed a valid plan with a nested fence: $OUT_FB"; fail=$((fail+1))
fi

# ── Fence rule: an unclosed fence fails lint, naming the line it opened on.
cat > "$TMP/fence-c.md" <<'EOF'
# Fence Plan C

## Tasks

### Task 1: unclosed fence
- **Delivers:** d1
- **Blocked by:** none
- [ ] **Files:** `app/broken.rb`
- [ ] **Change:**
```
OLD: never closes

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop.
EOF
FENCE_C_LINE=$(grep -n '^```$' "$TMP/fence-c.md" | head -1 | cut -d: -f1)
if OUT_FC=$(bash "$LINT" "$TMP/fence-c.md" 2>&1); then
  echo "  ✗ plan-lint.sh passed a plan with an unclosed code fence: $OUT_FC"; fail=$((fail+1))
else
  if printf '%s\n' "$OUT_FC" | grep -qF "unclosed code fence opened at line $FENCE_C_LINE"; then
    echo "  ✓ plan-lint.sh: an unclosed code fence fails, naming its opening line ($FENCE_C_LINE)"
  else
    echo "  ✗ plan-lint.sh did not name the unclosed fence's opening line: $OUT_FC"; fail=$((fail+1))
  fi
fi

# ── R2/R3 reviewers: every R2/R3 task is `none` (the track-end review covers it) ──
# however many R2/R3 tasks the plan holds or how they depend on each other;
# R1 stays none; the R4 Round 2 line names the widened class list.
mkplan_rc() { # $1 = out file, then task blocks on stdin
  { printf '# RC Plan\n\n## Tasks\n'; cat; printf '## Parallel layout\nSequential — single owner.\n## Failure policy\nDefault: stop.\n'; } > "$1"
}
NOTEXT='`none` — the track-end review covers this task'
rv() { bash "$LINT" --brief "$1" "$2" | grep -A1 '^## Reviewers' | tail -1; }
mkplan_rc "$TMP/rc-one.md" <<'EOF'
### Task 1: two files
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `src/a.py`, `src/b.py`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
### Task 2: auth
- **Delivers:** y
- **Blocked by:** none
- [ ] **Files:** `src/auth/login.ts`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
### Task 3: docs
- **Delivers:** z
- **Blocked by:** none
- [ ] **Files:** `docs/readme.md`
- [ ] **Command:** true
- **Owner:** content-strategist
- **Done when:** true
EOF
RC1=$(rv 1 "$TMP/rc-one.md")
if [ "$RC1" = "$NOTEXT" ] && ! printf '%s' "$RC1" | grep -qF 'lens: spec'; then
  echo "  ✓ --brief: the plan's only R2/R3 code task (R4 + docs tasks beside it) is none, no in-task lenses"
else
  echo "  ✗ --brief one R2/R3 task Reviewers wrong: $RC1"; fail=$((fail+1))
fi
RC3=$(rv 3 "$TMP/rc-one.md")
if [ "$RC3" = '`none`' ]; then echo "  ✓ --brief: a docs-only task stays none and is not counted"
else echo "  ✗ --brief docs-only Reviewers: $RC3"; fail=$((fail+1)); fi
RC2=$(cd "$TMP" && HOME="$HOME_FULL" ROLEPOD_SESSION_MODE=full ROLEPOD_SESSION_SOURCE=global bash "$LINT" --brief 2 "$TMP/rc-one.md" | grep -A1 '^## Reviewers' | tail -1)
if [ "$RC2" = "$NOTEXT" ]; then
  echo "  ✓ --brief an R4 task that shares its track with another code task (Full) → none, the track-end review takes the R4 set"
else echo "  ✗ --brief R4 Reviewers: $RC2"; fail=$((fail+1)); fi
mkplan_rc "$TMP/rc-two.md" <<'EOF'
### Task 1: two files
- **Delivers:** x
- **Blocked by:** none
- [ ] **Files:** `src/a.py`, `src/b.py`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
### Task 2: one file
- **Delivers:** y
- **Blocked by:** none
- [ ] **Files:** `src/c.py`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** true
### Task 3: docs
- **Delivers:** z
- **Blocked by:** none
- [ ] **Files:** `docs/readme.md`
- [ ] **Command:** true
- **Owner:** content-strategist
- **Done when:** true
EOF
if [ "$(rv 1 "$TMP/rc-two.md")" = "$NOTEXT" ] && [ "$(rv 2 "$TMP/rc-two.md")" = "$NOTEXT" ]; then
  echo "  ✓ --brief: two R2/R3 code tasks both get none (the track-end review text)"
else
  echo "  ✗ --brief two R2/R3 tasks: $(rv 1 "$TMP/rc-two.md") / $(rv 2 "$TMP/rc-two.md")"; fail=$((fail+1))
fi
# Blocked-by makes no difference: a chain A -> B -> C, three independent
# tasks, a multi-ref Blocked by and an R4 dependent are all none for R2/R3.
rc_task() { # $1 num, $2 blocked by, $3 file
  printf '### Task %s: t%s\n- **Delivers:** x\n- **Blocked by:** %s\n- [ ] **Files:** `%s`\n- [ ] **Command:** true\n- **Owner:** backend-developer\n- **Done when:** true\n' "$1" "$1" "$2" "$3"
}
{ rc_task 1 none src/a1.py; rc_task 2 "Task 1" src/a2.py; rc_task 3 "Task 2" src/a3.py; } | mkplan_rc "$TMP/rc-chain.md"
{ rc_task 1 none src/a1.py; rc_task 2 none src/a2.py; rc_task 3 none src/a3.py; } | mkplan_rc "$TMP/rc-three.md"
{ rc_task 1 none src/a1.py; rc_task 2 none src/a2.py; rc_task 3 "Task 1" src/auth/x.ts; rc_task 4 none src/a4.py; } | mkplan_rc "$TMP/rc-r4dep.md"
CH_OK=1
for n in 1 2 3; do [ "$(rv "$n" "$TMP/rc-chain.md")" = "$NOTEXT" ] || CH_OK=0; done
TH_OK=1
for n in 1 2 3; do [ "$(rv "$n" "$TMP/rc-three.md")" = "$NOTEXT" ] || TH_OK=0; done
{ rc_task 1 none src/a1.py; rc_task 2 none src/a2.py; rc_task 3 "Tasks 1 and 2 (T4 is unrelated)" src/a3.py; rc_task 4 none src/a4.py; } | mkplan_rc "$TMP/rc-multi.md"
if [ "$(rv 1 "$TMP/rc-multi.md")" = "$NOTEXT" ] && [ "$(rv 2 "$TMP/rc-multi.md")" = "$NOTEXT" ] \
  && [ "$(rv 3 "$TMP/rc-multi.md")" = "$NOTEXT" ] && [ "$(rv 4 "$TMP/rc-multi.md")" = "$NOTEXT" ]; then
  echo "  ✓ --brief: a multi-ref Blocked by leaves every R2/R3 task none"
else echo "  ✗ --brief multi-ref Blocked by: $(rv 1 "$TMP/rc-multi.md") / $(rv 3 "$TMP/rc-multi.md")"; fail=$((fail+1)); fi
if [ "$CH_OK" = 1 ]; then echo "  ✓ --brief: a chain of R2/R3 tasks is none at every link"
else echo "  ✗ --brief chain not none everywhere"; fail=$((fail+1)); fi
if [ "$TH_OK" = 1 ]; then echo "  ✓ --brief: three independent R2/R3 tasks are all none"
else echo "  ✗ --brief three independent tasks not all none"; fail=$((fail+1)); fi
# no in-task line survives: none of the R2/R3 outputs names a lens or a combined review
if ! rv 1 "$TMP/rc-chain.md" | grep -qi 'lens\|combined\|in-task'; then
  echo "  ✓ --brief: an R2/R3 Reviewers line names no in-task lens and no combined review"
else echo "  ✗ --brief in-task text survives: $(rv 1 "$TMP/rc-chain.md")"; fail=$((fail+1)); fi

# ── Thai prose plan: field labels English, content Thai → lint PASS and --brief keeps the Thai ──
cat > "$TMP/thai-plan.md" <<'EOF'
# แผนงานภาษาไทย

## Tasks

### Task 1: ปรับสคริปต์ให้พิมพ์ข้อความภาษาไทย
- **Delivers:** สคริปต์ที่อ่านแผนภาษาไทยได้ครบ
- **Blocked by:** none
- [ ] **Files:** `src/a.py`
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** คำสั่งผ่านและไฟล์ถูกแก้ตามที่ตกลง

## Parallel layout
Sequential — ทำตามลำดับ เจ้าของงานคนเดียว

## Failure policy
Default: stop.
EOF
TRC=0; TOUT=$(bash "$LINT" "$TMP/thai-plan.md" 2>&1) || TRC=$?
TBRIEF=$(bash "$LINT" --brief 1 "$TMP/thai-plan.md" 2>/dev/null)
TGOAL=$(printf '%s\n' "$TBRIEF" | awk '/^## Goal/{f=1;next} /^## /{f=0} f')
TDONE=$(printf '%s\n' "$TBRIEF" | awk '/^## Done when/{f=1;next} /^## /{f=0} f')
if [ "$TRC" -eq 0 ] && printf '%s' "$TOUT" | grep -q 'plan-lint: PASS' \
  && printf '%s' "$TGOAL" | grep -qxF 'สคริปต์ที่อ่านแผนภาษาไทยได้ครบ' \
  && printf '%s\n' "$TBRIEF" | grep -qxF '# Task 1: ปรับสคริปต์ให้พิมพ์ข้อความภาษาไทย' \
  && printf '%s' "$TDONE" | grep -qxF 'คำสั่งผ่านและไฟล์ถูกแก้ตามที่ตกลง'; then
  echo "  ✓ Thai-prose plan (English field labels): lint PASS and --brief 1 prints the Thai Goal + Done when"
else
  echo "  ✗ Thai-prose plan: rc=$TRC lint=$TOUT | Goal=$TGOAL | Done=$TDONE"; fail=$((fail+1))
fi

if [ "$(rv 1 "$TMP/rc-r4dep.md")" = "$NOTEXT" ] && [ "$(rv 2 "$TMP/rc-r4dep.md")" = "$NOTEXT" ] && [ "$(rv 4 "$TMP/rc-r4dep.md")" = "$NOTEXT" ]; then
  echo "  ✓ --brief: an R2/R3 task an R4 task is Blocked by is none, like the independent ones"
else echo "  ✗ --brief R4 dependent: $(rv 1 "$TMP/rc-r4dep.md") / $(rv 2 "$TMP/rc-r4dep.md")"; fail=$((fail+1)); fi

# ── --brief: ## Canonical sentences (cited contract Shared-interfaces ids) ──
cat > "$TMP/cs-plan.md" <<'EOF'
# Canon Plan

## Source spec
docs/specs/canon.md

## Tasks
### Task 1: quote the rules
- Delivers: a brief with canon
- Blocked by: none
- Files: `src/a.sh`
- Owner: devops-sre
- Change: apply C3 here, then C1 (C1x and C_1 are not cites).
- Test / evidence: none
- Command: `true`
- Done when: ok

### Task 2: no citations
- Delivers: plain
- Blocked by: none
- Files: `src/b.sh`
- Owner: devops-sre
- Change: nothing cited.
- Test / evidence: none
- Command: `true`
- Done when: ok

## Failure policy
Default: stop.
EOF
cat > "$TMP/cs-contract.md" <<'EOF'
# Canon contract

## File ownership
- `devops-sre`: `src/a.sh`, `src/b.sh`

## Shared interfaces — Canonical sentences
C1 (round 2+, Task 1):
> First quoted rule with `code`.

C3 (depth, Task 1):
> Third rule line one.
> Third rule line two.

C10 (other, Task 9):
> Tenth rule must stay out.
EOF
CSB=$(bash "$LINT" --brief 1 "$TMP/cs-plan.md" "$TMP/cs-contract.md" 2>/dev/null)
CSSEC=$(printf '%s\n' "$CSB" | awk '/^## Canonical sentences/{f=1;next} /^## /{f=0} f')
CSNEXT=$(printf '%s\n' "$CSB" | awk '/^## Change/{getline; getline; print; exit}')
if printf '%s\n' "$CSB" | grep -qxF '## Canonical sentences' \
  && [ "$CSSEC" = "$(printf 'C1:\n> First quoted rule with `code`.\nC3:\n> Third rule line one.\n> Third rule line two.')" ] \
  && ! printf '%s' "$CSB" | grep -qF 'Tenth rule' \
  && [ "$CSNEXT" = "## Canonical sentences" ]; then
  echo "  ✓ --brief: cited C1 + C3 quoted in id order right after Change; uncited C10 absent"
else echo "  ✗ --brief canonical sentences: $CSSEC"; fail=$((fail+1)); fi
CS2=$(bash "$LINT" --brief 2 "$TMP/cs-plan.md" "$TMP/cs-contract.md" 2>/dev/null)
CS1N=$(bash "$LINT" --brief 1 "$TMP/cs-plan.md" 2>/dev/null)
if ! printf '%s' "$CS2" | grep -qF 'Canonical sentences' && ! printf '%s' "$CS1N" | grep -qF 'Canonical sentences'; then
  echo "  ✓ --brief: no cited id, or no contract, prints no Canonical sentences section"
else echo "  ✗ --brief printed a Canonical sentences section without a cite or contract"; fail=$((fail+1)); fi

# A multi-line entry stays whole: `> ` lines plus indented wrapped / bullet
# continuations run until the next C<n> label, a top-level plain line or a
# heading; a one-line entry and an entry before a heading are unchanged.
cat > "$TMP/cm-plan.md" <<'EOF'
# Canon Multi Plan

## Tasks
### Task 1: quote multi
- Delivers: multi
- Blocked by: none
- Files: `src/a.sh`
- Owner: devops-sre
- Change: apply C1 and C2 and C4 and C5 and C6.
- Test / evidence: none
- Command: `true`
- Done when: ok

## Failure policy
Default: stop.
EOF
cat > "$TMP/cm-contract.md" <<'EOF'
# Canon multi contract

## File ownership
- `devops-sre`: `src/a.sh`

## Shared interfaces
C1 (round 2+, Task 1):
> First sentence of the rule.
  wrapped tail of the first sentence
  - a bullet continuation
C2 (one line, Task 1):
> Only line.
Plain top-level prose ends the entry.
C3 (never cited, Task 9):
> Stays out.
C4 (before heading, Task 1):
> Last rule.
  its wrapped tail
C5 (bare quote line, Task 1):
> a
>
> b
C6 (lead-in line, Task 1):
Lead-in sentence.
> the rule

## Merge order
Not part of C4.
EOF
CMB=$(bash "$LINT" --brief 1 "$TMP/cm-plan.md" "$TMP/cm-contract.md" 2>/dev/null)
CMSEC=$(printf '%s\n' "$CMB" | awk '/^## Canonical sentences/{f=1;next} /^## /{f=0} f')
CMWANT="C1:
> First sentence of the rule.
  wrapped tail of the first sentence
  - a bullet continuation
C2:
> Only line.
C4:
> Last rule.
  its wrapped tail
C5:
> a
> b
C6:
> the rule"
if [ "$CMSEC" = "$CMWANT" ]; then
  echo "  ✓ --brief: a multi-line C<n> entry keeps every line; one-line and before-heading entries unchanged"
else echo "  ✗ --brief multi-line canonical entry: $CMSEC"; fail=$((fail+1)); fi

# A `> ` line before the first label of a LATER Shared-interfaces section must
# not attach to the previous section's last id (cid resets at a heading).
cat > "$TMP/cr-plan.md" <<'EOF'
# Canon Reset Plan

## Tasks
### Task 1: quote reset
- Delivers: reset
- Blocked by: none
- Files: `src/a.sh`
- Owner: devops-sre
- Change: apply C1.
- Test / evidence: none
- Command: `true`
- Done when: ok

## Failure policy
Default: stop.
EOF
cat > "$TMP/cr-contract.md" <<'EOF'
# Canon reset contract

## Shared interfaces
C1 (Task 1):
> The real rule.

## Notes
Prose.

## Shared interfaces
> stray quote before any label
C2 (Task 9):
> Other rule.
EOF
CRSEC=$(bash "$LINT" --brief 1 "$TMP/cr-plan.md" "$TMP/cr-contract.md" 2>/dev/null | awk '/^## Canonical sentences/{f=1;next} /^## /{f=0} f')
if [ "$CRSEC" = "C1:
> The real rule." ]; then
  echo "  ✓ --brief: a > line before the first label of a later Shared-interfaces section stays out of the previous id"
else echo "  ✗ --brief stray quote attached to the previous id: $CRSEC"; fail=$((fail+1)); fi

# ── Tracks (worktree-track spec): ## Tracks + **Track:** ────────────────
mk_tracks_plan() { # $1 = file; $2 = Task 3 Files; $3 = Task 3 Blocked by; $4 = Task 4 Blocked by; $5 = Task 2 Track
  cat > "$1" <<EOF
# Demo Feat Plan

## Parallel layout
Sequential — two tracks, one owner per track.

## Tracks
- A — first lane: Task 1, Task 2 · branch demo-feat/a-first-lane
- B — second lane: Task 3, Task 4 · branch demo-feat/b-second-lane

## Tasks

### Task 1: build alpha
- **Track:** A
- **Blocked by:** none
- **Files:** \`src/alpha.sh\`
- **Command:** \`bash -n src/alpha.sh\`

### Task 2: build beta
- **Track:** ${5:-A}
- **Blocked by:** Task 1
- **Files:** \`src/beta.sh\`, \`docs/beta.md\`
- **Command:** \`bash -n src/beta.sh\`

### Task 3: build gamma
- **Track:** B
- **Blocked by:** ${3:-Task 1}
- **Files:** ${2:-\`src/gamma.sh\`}
- **Command:** \`bash -n src/gamma.sh\`

### Task 4: build delta
- **Track:** B
- **Blocked by:** ${4:-Task 3}
- **Files:** \`src/delta.sh\`, \`docs/delta.md\`
- **Command:** \`bash -n src/delta.sh\`

## Failure policy
After 2 failed fixes, consult once; stop after 4 informed attempts.
EOF
}
TP="$TMP/2026-09-30-demo-feat.md"
mk_tracks_plan "$TP"
TRC=0; TOUT=$(bash "$LINT" "$TP" 2>&1) || TRC=$?
if [ "$TRC" -eq 0 ] && printf '%s' "$TOUT" | grep -q 'PASS'; then
  echo "  ✓ tracks: a valid two-track plan passes"
else echo "  ✗ tracks: valid two-track plan failed: $TOUT"; fail=$((fail+1)); fi

mk_tracks_plan "$TMP/2026-09-30-same-file.md" '`src/alpha.sh`'
TRC=0; TOUT=$(bash "$LINT" "$TMP/2026-09-30-same-file.md" 2>&1) || TRC=$?
if [ "$TRC" -ne 0 ] && printf '%s' "$TOUT" | grep -q 'src/alpha.sh' && printf '%s' "$TOUT" | grep -q 'plan-lint: FAIL'; then
  echo "  ✓ tracks: one file edited in two tracks fails and names the file"
else echo "  ✗ tracks: cross-track shared file passed or unnamed (rc=$TRC): $TOUT"; fail=$((fail+1)); fi

mk_tracks_plan "$TMP/2026-09-30-mid-cross.md" '`src/gamma.sh`' 'Task 1' 'Task 1'
TRC=0; TOUT=$(bash "$LINT" "$TMP/2026-09-30-mid-cross.md" 2>&1) || TRC=$?
if [ "$TRC" -ne 0 ] && printf '%s' "$TOUT" | grep -q 'Task 4.*Task 1'; then
  echo "  ✓ tracks: Blocked by across tracks at a mid-track task fails"
else echo "  ✗ tracks: mid-track cross Blocked by passed (rc=$TRC): $TOUT"; fail=$((fail+1)); fi

mk_tracks_plan "$TMP/2026-09-30-wrap-cross.md" '`src/gamma.sh`' 'Task 1' "Task 3,
  Task 1"
TRC=0; TOUT=$(bash "$LINT" "$TMP/2026-09-30-wrap-cross.md" 2>&1) || TRC=$?
if [ "$TRC" -ne 0 ] && printf '%s' "$TOUT" | grep -q 'Task 4.*Task 1'; then
  echo "  ✓ tracks: a cross-track ref on a wrapped Blocked by line fails too"
else echo "  ✗ tracks: wrapped cross-track ref passed (rc=$TRC): $TOUT"; fail=$((fail+1)); fi

# non-Sequential layout, no ## Tracks: a shared file or a Blocked-by edge FAILs.
mk_notracks_plan() { # $1 = file; $2 = layout line; $3 = Task 2 Files; $4 = Task 2 Blocked by; $5 = Tracks block
  cat > "$1" <<EOF
# Demo Feat Plan

## Parallel layout
$2

${5:+$5

}## Tasks

### Task 1: build alpha
- **Blocked by:** none
- **Files:** \`src/alpha.sh\`
- **Command:** \`bash -n src/alpha.sh\`

### Task 2: build beta
- **Blocked by:** ${4:-none}
- **Files:** ${3:-\`src/beta.sh\`}
- **Command:** \`bash -n src/beta.sh\`

## Failure policy
After 2 failed fixes, consult once; stop after 4 informed attempts.
EOF
}
NT_LAYOUT='Two lanes run in parallel, one owner each.'
NT_MSG='non-Sequential layout with no ## Tracks, and Task'
mk_notracks_plan "$TMP/2026-09-30-nt-share.md" "$NT_LAYOUT" '`src/alpha.sh`'
TRC=0; TOUT=$(bash "$LINT" "$TMP/2026-09-30-nt-share.md" 2>&1) || TRC=$?
if [ "$TRC" -ne 0 ] && printf '%s' "$TOUT" | grep -qF "  ✗ $NT_MSG 1 and Task 2 share src/alpha.sh — add ## Tracks (write-plan step 2)"; then
  echo "  ✓ no-Tracks: a Parallel plan whose two tasks share a file fails with the add-Tracks message"
else echo "  ✗ no-Tracks: shared file not failed (rc=$TRC): $TOUT"; fail=$((fail+1)); fi

mk_notracks_plan "$TMP/2026-09-30-nt-block.md" "$NT_LAYOUT" '' 'Task 1'
TRC=0; TOUT=$(bash "$LINT" "$TMP/2026-09-30-nt-block.md" 2>&1) || TRC=$?
if [ "$TRC" -ne 0 ] && printf '%s' "$TOUT" | grep -qF "  ✗ $NT_MSG 2 is Blocked by Task 1 — add ## Tracks (write-plan step 2)"; then
  echo "  ✓ no-Tracks: a Parallel plan with a Blocked-by edge fails with the add-Tracks message"
else echo "  ✗ no-Tracks: Blocked-by edge not failed (rc=$TRC): $TOUT"; fail=$((fail+1)); fi

NT_TRACKS='## Tracks
- A — first lane: Task 1 · branch demo-feat/a-first-lane
- B — second lane: Task 2 · branch demo-feat/b-second-lane'
mk_notracks_plan "$TMP/2026-09-30-nt-tracks.md" "$NT_LAYOUT" '' 'Task 1' "$NT_TRACKS"
nt_tracks_body=$(awk '/^### Task 1/{print; print "- **Track:** A"; next} /^### Task 2/{print; print "- **Track:** B"; next} {print}' "$TMP/2026-09-30-nt-tracks.md")
printf '%s\n' "$nt_tracks_body" > "$TMP/2026-09-30-nt-tracks.md"
TRC=0; TOUT=$(bash "$LINT" "$TMP/2026-09-30-nt-tracks.md" 2>&1) || TRC=$?
if ! printf '%s' "$TOUT" | grep -qF "$NT_MSG" && printf '%s' "$TOUT" | grep -qF 'tracks: 2 tracks'; then
  echo "  ✓ no-Tracks: the same Parallel plan with ## Tracks gets no add-Tracks message"
else echo "  ✗ no-Tracks: a plan with ## Tracks still got the message (rc=$TRC): $TOUT"; fail=$((fail+1)); fi

mk_notracks_plan "$TMP/2026-09-30-nt-seq.md" 'Sequential — single owner.' '`src/alpha.sh`' 'Task 1'
TRC=0; TOUT=$(bash "$LINT" "$TMP/2026-09-30-nt-seq.md" 2>&1) || TRC=$?
if [ "$TRC" -eq 0 ] && ! printf '%s' "$TOUT" | grep -qF "$NT_MSG"; then
  echo "  ✓ no-Tracks: a Sequential plan sharing a file and a Blocked-by edge passes"
else echo "  ✗ no-Tracks: Sequential plan wrongly failed (rc=$TRC): $TOUT"; fail=$((fail+1)); fi

# --brief carries every indented `- [ ]` step of a Change block, in order.
cat > "$TMP/2026-09-30-steps.md" <<'EOF'
# Steps Plan

## Parallel layout
Sequential — single owner.

## Tasks

### Task 1: build steps
- **Blocked by:** none
- **Files:** `src/alpha.sh`
- **Change:**
  - [ ] first step alpha
  - [ ] second step beta
  - [ ] third step gamma
- **Command:** `bash -n src/alpha.sh`

## Failure policy
After 2 failed fixes, consult once; stop after 4 informed attempts.
EOF
TRC=0; TOUT=$(bash "$LINT" "$TMP/2026-09-30-steps.md" 2>&1) || TRC=$?
SB=$(bash "$LINT" --brief 1 "$TMP/2026-09-30-steps.md" --main 2>/dev/null)
SB_ORDER=$(printf '%s\n' "$SB" | grep -oE 'first step alpha|second step beta|third step gamma' | tr '\n' '|')
if [ "$TRC" -eq 0 ] && [ "$SB_ORDER" = 'first step alpha|second step beta|third step gamma|' ]; then
  echo "  ✓ --brief: three indented Change steps lint clean and all reach the brief in order"
else echo "  ✗ --brief: indented steps (lint rc=$TRC, order=[$SB_ORDER]): $TOUT"; fail=$((fail+1)); fi

mk_tracks_plan "$TMP/2026-09-30-bad-id.md" '`src/gamma.sh`' 'Task 1' 'Task 3' 'Z'
TRC=0; TOUT=$(bash "$LINT" "$TMP/2026-09-30-bad-id.md" 2>&1) || TRC=$?
if [ "$TRC" -ne 0 ] && printf '%s' "$TOUT" | grep -q 'Task 2.*Z'; then
  echo "  ✓ tracks: a task naming a track absent from ## Tracks fails"
else echo "  ✗ tracks: unknown track id passed (rc=$TRC): $TOUT"; fail=$((fail+1)); fi

mk_tracks_plan "$TMP/2026-09-30-unlisted.md" '`src/gamma.sh`' 'Task 1' 'Task 3' 'B'
TRC=0; TOUT=$(bash "$LINT" "$TMP/2026-09-30-unlisted.md" 2>&1) || TRC=$?
if [ "$TRC" -ne 0 ] && printf '%s' "$TOUT" | grep -q 'Task 2 names track B but the ## Tracks line for B does not list it'; then
  echo "  ✓ tracks: a task whose Track field disagrees with the ## Tracks member list fails"
else echo "  ✗ tracks: Track field vs member list mismatch passed (rc=$TRC): $TOUT"; fail=$((fail+1)); fi

# Task 2 loses its Track line (the second **Track:** in the file)
awk '/^- \*\*Track:\*\*/ { n++; if (n == 2) next } { print }' "$TP" > "$TMP/2026-09-30-no-track.md"
TRC=0; TOUT=$(bash "$LINT" "$TMP/2026-09-30-no-track.md" 2>&1) || TRC=$?
if [ "$TRC" -ne 0 ] && printf '%s' "$TOUT" | grep -q 'Task 2.*no Track'; then
  echo "  ✓ tracks: a task with no Track fails when the plan has ## Tracks"
else echo "  ✗ tracks: Track-less task passed (rc=$TRC): $TOUT"; fail=$((fail+1)); fi

# --brief: a task in a track gets the track worktree; tier R2/R3 gets no in-task review
TB=$(bash "$LINT" --brief 2 "$TP" 2>/dev/null)
if printf '%s\n' "$TB" | grep -qE '^`git worktree add -b demo-feat/a-first-lane \.\./[A-Za-z0-9._-]+-wt-demo-feat-a-first-lane` — cd there' \
  && printf '%s\n' "$TB" | grep -qE '^- Edit only Files allowed under \.\./[A-Za-z0-9._-]+-wt-demo-feat-a-first-lane, except update the canonical receipt at .+ in the base checkout' \
  && ! printf '%s\n' "$TB" | grep -q -- '-t2-'; then
  echo "  ✓ --brief: a track task prints the track branch and worktree path"
else echo "  ✗ --brief track worktree: $(printf '%s\n' "$TB" | sed -n '/^## Worktree/,/^## Goal/p')"; fail=$((fail+1)); fi
TB5=$(bash "$LINT" --brief 2 "$TP" 2>/dev/null | awk '/^## Bounds/{on=1; next} /^## /{on=0} on')
if printf '%s\n' "$TB5" | grep -qE 'review/[A-Za-z0-9-]+-task2-<lens>\.md, <lens> one of spec' \
  && ! printf '%s\n' "$TB5" | grep -q -- '-t2-'; then
  echo "  ✓ --brief Bounds name the report <plan-slug>-task<N>-<lens>.md"
else echo "  ✗ --brief Bounds report name wrong: $TB5"; fail=$((fail+1)); fi
TB3=$(bash "$LINT" --brief 3 "$TP" 2>/dev/null)
if printf '%s\n' "$TB3" | grep -qE '^`git worktree add -b demo-feat/b-second-lane '; then
  echo "  ✓ --brief: the second track names its own branch"
else echo "  ✗ --brief second track: $(printf '%s\n' "$TB3" | sed -n '/^## Worktree/,/^## Goal/p')"; fail=$((fail+1)); fi
PWB=$(bash "$LINT" --brief 2 "$TP" --plan-worktree 2>/dev/null)
PWR=$(printf '%s\n' "$PWB" | awk '/^## Reviewers/{f=1;next} /^## /{f=0} f')
PWTIER=$(printf '%s\n' "$PWB" | awk '/^## Tier/{getline; print substr($0,1,2); exit}')
if printf '%s\n' "$PWB" | grep -qE '^`git worktree add -b demo-feat/plan \.\./[A-Za-z0-9._-]+-wt-demo-feat` — ' \
  && printf '%s\n' "$PWB" | grep -qE '^- Edit only Files allowed under \.\./[A-Za-z0-9._-]+-wt-demo-feat, except update the canonical receipt at .+ in the base checkout' \
  && ! printf '%s\n' "$PWB" | grep -q -- '-t2-' \
  && { [ "$PWTIER" = R4 ] || [ "$PWR" = '`none` — the track-end review covers this task' ]; }; then
  echo "  ✓ --brief --plan-worktree: Worktree, Bounds and Reviewers name the plan worktree"
else echo "  ✗ --brief --plan-worktree: $(printf '%s\n' "$PWB" | sed -n '/^## Worktree/,/^## Goal/p') / $PWR"; fail=$((fail+1)); fi
TBR=$(printf '%s\n' "$TB" | awk '/^## Reviewers/{f=1;next} /^## /{f=0} f')
TIER=$(printf '%s\n' "$TB" | awk '/^## Tier/{getline; print substr($0,1,2); exit}')
case "$TIER" in
  R2|R3) [ "$TBR" = '`none` — the track-end review covers this task' ] \
    && echo "  ✓ --brief: an R2/R3 track task gets the track-end Reviewers line" \
    || { echo "  ✗ --brief track Reviewers ($TIER): $TBR"; fail=$((fail+1)); } ;;
  *) echo "  ✗ --brief track fixture tier is $TIER, expected R2/R3"; fail=$((fail+1)) ;;
esac

# a plan without ## Tracks: worktree per task; Reviewers is the same track-end line
NT="$TMP/2026-09-30-plain-feat.md"
awk '/^## Tracks$/ { skip = 1; next } skip && /^## / { skip = 0 } skip { next } /^- \*\*Track:\*\*/ { next } { print }' "$TP" > "$NT"
NB=$(bash "$LINT" --brief 2 "$NT" 2>/dev/null)
if printf '%s\n' "$NB" | grep -qE '^`git worktree add -b [a-z0-9-]+/t2-build-beta \.\./[A-Za-z0-9._-]+-wt-[a-z0-9-]+-t2-build-beta` — cd there for every command; the name says which task it holds$' \
  && printf '%s\n' "$NB" | grep -qF '`none` — the track-end review covers this task'; then
  echo "  ✓ --brief: a plan with no ## Tracks keeps the per-task worktree line; Reviewers is the track-end none"
else echo "  ✗ --brief plain plan drifted: $(printf '%s\n' "$NB" | sed -n '/^## Worktree/,/^## Goal/p')"; fail=$((fail+1)); fi
NRC=0; NOUT=$(bash "$LINT" "$NT" 2>&1) || NRC=$?
NEXP=$(printf '%s\n' "  ✓ Failure policy present" "  ✓ every task carries a Command (4/4)" "  ✓ Blocked-by graph resolves, no cycle (4 tasks)" "  ✓ sequential layout — ownership check not applicable" "plan-lint: PASS")
NGOT=$(printf '%s\n' "$NOUT" | sed -n '/Failure policy present/,$p')
if [ "$NRC" -eq 0 ] && [ "$NGOT" = "$NEXP" ]; then
  echo "  ✓ tracks: a plan with no ## Tracks prints the four check lines and no track line"
else echo "  ✗ tracks: plain plan output changed (rc=$NRC): $NOUT"; fail=$((fail+1)); fi

# ── A task with no Files line FAILs lint; --brief refuses it ─────────────
NF="$TMP/nofiles"; mkdir -p "$NF"
cat > "$NF/plan.md" <<'EOF'
# Nofiles Plan

## Failure policy
After 2 failed fixes, consult once; stop after 4 informed attempts.

## Parallel layout
Sequential — single owner.

## Tasks

### Task 1: has files
- **Blocked by:** none
- **Files:** `a/one.sh`
- **Command:** `bash a/one.sh`

### Task 2: no files line
- **Blocked by:** none
- **Change:** something
- **Command:** `bash a/two.sh`
EOF
NFRC=0; NFOUT=$(bash "$LINT" "$NF/plan.md" 2>&1) || NFRC=$?
if [ "$NFRC" -eq 1 ] && printf '%s\n' "$NFOUT" | grep -qF '✗ missing Files: Task 2: no files line' \
  && ! printf '%s\n' "$NFOUT" | grep -qF 'Task 1: has files'; then
  echo "  ✓ lint FAILs a task with no Files line, naming only that task"
else echo "  ✗ Files-less task lint (rc=$NFRC): $NFOUT"; fail=$((fail+1)); fi
NBRC=0; NBOUT=$(bash "$LINT" --brief 2 "$NF/plan.md" 2>"$NF/err") || NBRC=$?
if [ "$NBRC" -ne 0 ] && [ -z "$NBOUT" ] && grep -qF 'missing Files: Task 2: no files line' "$NF/err"; then
  echo "  ✓ --brief on a Files-less task exits non-zero with the lint message, no brief"
else echo "  ✗ Files-less task --brief (rc=$NBRC): $NBOUT / $(cat "$NF/err")"; fail=$((fail+1)); fi

# ── Do-not-touch prose lines never become forbidden paths ────────────────
DP="$TMP/dnt"; mkdir -p "$DP"
cat > "$DP/plan.md" <<'EOF'
# Dnt Plan

## Failure policy
After 2 failed fixes, consult once; stop after 4 informed attempts.

## Tasks

### Task 1: one
- **Blocked by:** none
- **Files:** `a/one.sh`
- **Command:** `bash a/one.sh`
EOF
cat > "$DP/contract.md" <<'EOF'
# Dnt Contract

## File ownership
- `devops-sre`: `a/one.sh`

## Do-not-touch list

- Each task: every file owned by the other task. A needed change there is a `NEEDS:` line in the decision brief.
- Both: `migrations/` (a migration need stops the task; reserve in `docs/migration-reservations.md` first).
- Nobody: see docs/guide.md for the rest, and more prose.
- Nobody: only prose here with no path at all.
- Nobody: e.g. the release notes, v2.1 and read/write access.
NEEDS: a bare label line with nothing else.
- Skills: `core/skills/**` (except SKILL.md).
- Hooks: `hooks/**` Except the gate file.
- Docs: `docs/**` except README.md, and more.
EOF
DPF=$(bash "$LINT" --brief 1 "$DP/plan.md" "$DP/contract.md" 2>/dev/null | awk '/^## Files forbidden/{f=1;next} /^## /{f=0} f')
DPX=$(printf '%s\n' '- migrations/' '- docs/migration-reservations.md' '- docs/guide.md' '- core/skills/** (except SKILL.md)' '- hooks/** Except the gate file' '- docs/** except README.md' '- everything else (an unowned path: touch it and add an Also touched line; a path another owner holds: a NEEDS line, never an edit)')
if [ "$DPF" = "$DPX" ]; then
  echo "  ✓ --brief do-not-touch: a backticked token is the path, prose-only lines print nothing"
else echo "  ✗ --brief do-not-touch prose leaked: $DPF"; fail=$((fail+1)); fi

# ── --brief task records (C4): each Blocked-by task's record file joins Read
# first; every brief carries the one generated "Write your decision brief" line.
TR2=$(bash "$LINT" --brief 2 "$TMP/brief-plan.md" "$TMP/brief-contract.md" 2>/dev/null)
sed 's/^Default: stop\.$/After two red attempts, consult once before a third./' "$TMP/brief-plan.md" > "$TMP/brief-plan-recovery.md"
TR_RECOVERY=$(bash "$LINT" --brief 2 "$TMP/brief-plan-recovery.md" "$TMP/brief-contract.md" 2>/dev/null | awk '/^## Failure policy$/{f=1;next} /^## /{f=0} f')
if [ "$TR_RECOVERY" = "After two red attempts, consult once before a third." ]; then
  echo "  ✓ --brief carries the custom plan recovery policy"
else
  echo "  ✗ --brief custom recovery policy wrong: [$TR_RECOVERY]"; fail=$((fail+1))
fi
TR_POLICY_LINES=$(printf '%s\n' '```sh' "printf '%s\\n' '\\[x\\]'" '```')
TR_POLICY_LINES="$TR_POLICY_LINES" awk '
  /^Default: stop\.$/ {
    n = split(ENVIRON["TR_POLICY_LINES"], lines, "\n")
    for (i = 1; i <= n; i++) print lines[i]
    next
  }
  { print }
' "$TMP/brief-plan.md" > "$TMP/brief-plan-literal-recovery.md"
TR_LITERAL_OUTPUT=$(bash "$LINT" --brief 2 "$TMP/brief-plan-literal-recovery.md" "$TMP/brief-contract.md" 2>&1 || true)
TR_LITERAL_RECOVERY=$(printf '%s\n' "$TR_LITERAL_OUTPUT" | awk '/^## Failure policy$/{f=1;next} /^## /{f=0} f')
TR_LITERAL_EXPECTED=$(printf '%s\n' '```sh' "printf '%s\\n' '\\[x\\]'" '```')
if [ "$TR_LITERAL_RECOVERY" = "$TR_LITERAL_EXPECTED" ]; then
  echo "  ✓ --brief preserves literal backslashes and fenced custom recovery policy"
else
  echo "  ✗ --brief changed literal/fenced recovery policy: [$TR_LITERAL_RECOVERY] output=[$TR_LITERAL_OUTPUT]"; fail=$((fail+1))
fi
TR2_READ=$(printf '%s\n' "$TR2" | awk '/^## Read first/{f=1;next} /^## /{f=0} f')
TR1_READ=$(bash "$LINT" --brief 1 "$TMP/brief-plan.md" "$TMP/brief-contract.md" 2>/dev/null | awk '/^## Read first/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$TR2_READ" | grep -qxF "$REPO_DIR/docs/rolepod/tasks/brief-plan/task-01.md" \
  && printf '%s\n' "$TR2_READ" | grep -qF 'ui/existing-form.tsx' \
  && ! printf '%s\n' "$TR1_READ" | grep -qF 'docs/rolepod/tasks/'; then
  echo "  ✓ --brief adds the Blocked-by task record file to Read first (none for a task with no blockers)"
else
  echo "  ✗ --brief task-record Read first wrong: T2=[$TR2_READ] T1=[$TR1_READ]"; fail=$((fail+1))
fi
sed 's/^- \*\*Blocked by:\*\* Task 1$/- **Blocked by:** Task 1, Task 2/' "$TMP/brief-plan.md" > "$TMP/brief-plan-multi.md"
TR3_READ=$(bash "$LINT" --brief 3 "$TMP/brief-plan-multi.md" "$TMP/brief-contract.md" 2>/dev/null | awk '/^## Read first/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$TR3_READ" | grep -qxF "$REPO_DIR/docs/rolepod/tasks/brief-plan-multi/task-01.md" \
  && printf '%s\n' "$TR3_READ" | grep -qxF "$REPO_DIR/docs/rolepod/tasks/brief-plan-multi/task-02.md"; then
  echo "  ✓ --brief lists every Blocked-by task record file, zero-padded, in the plan-named folder"
else
  echo "  ✗ --brief multi-blocker records wrong: [$TR3_READ]"; fail=$((fail+1))
fi
TR_WRITE="- Write your decision brief to $REPO_DIR/docs/rolepod/tasks/brief-plan/task-02.md on the base checkout; its Handoff section is at most ~15 lines, only what a Blocked-by task consumes (signatures, invariants). Never edit the plan file."
if printf '%s\n' "$TR2" | grep -qxF -- "$TR_WRITE"; then
  echo "  ✓ --brief carries the generated decision-brief write line"
else
  echo "  ✗ --brief missed the decision-brief write line"; fail=$((fail+1))
fi

# Canonical receipt pointer is absolute and rooted at the base checkout.
TR_RECEIPT=$(printf '%s\n' "$TR2" | grep '^Canonical task receipt: ' | sed 's/^Canonical task receipt: //' || true)
TR_EXPECTED_RECEIPT="$(git -C "$REPO_DIR" rev-parse --show-toplevel)/docs/rolepod/tasks/brief-plan/task-02.md"
if [ "$TR_RECEIPT" = "$TR_EXPECTED_RECEIPT" ]; then
  echo "  ✓ --brief names the absolute canonical task receipt on base"
else
  echo "  ✗ --brief canonical receipt path wrong: [$TR_RECEIPT] expected [$TR_EXPECTED_RECEIPT]"; fail=$((fail+1))
fi
TR_BOUNDS=$(printf '%s\n' "$TR2" | awk '/^## Bounds$/{f=1;next} /^## /{f=0} f')
TR_ALLOWED=$(printf '%s\n' "$TR2" | awk '/^## Files allowed$/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$TR_BOUNDS" | grep -qF "except update the canonical receipt at $TR_EXPECTED_RECEIPT in the base checkout; no other base-checkout path is allowed" \
  && printf '%s\n' "$TR_ALLOWED" | grep -qxF -- "- Canonical task receipt $TR_EXPECTED_RECEIPT (base checkout only)"; then
  echo "  ✓ --brief aligns the canonical base receipt with Files allowed and worktree bounds"
else
  echo "  ✗ --brief receipt bounds/allow-list wrong: bounds=[$TR_BOUNDS] allowed=[$TR_ALLOWED]"; fail=$((fail+1))
fi

# Blocked-by Handoff inline (lean-skill-layer T20): a throwaway git repo under
# $TMP so the receipts never land in the real repo.
HO="$TMP/ho-repo"; mkdir -p "$HO/docs/rolepod/tasks/ho-plan-2026-10-05"
git -C "$HO" init -q
cat > "$HO/ho-plan-2026-10-05.md" <<'EOF'
# Ho Plan

## Tasks

### Task 1: first
- **Blocked by:** none
- [ ] **Files:** `a.sh`
- [ ] **Change:** a
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** ok

### Task 2: second
- **Blocked by:** Task 1
- [ ] **Files:** `b.sh`
- [ ] **Change:** b
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** ok
EOF
HO_RCPT="$HO/docs/rolepod/tasks/ho-plan-2026-10-05/task-01.md"
HO_REAL=$(cd "$HO" && pwd -P)
ho_brief() { (cd "$HO" && bash "$LINT" --brief 2 "$HO/ho-plan-2026-10-05.md" 2>/dev/null | awk '/^## Blocked by/{f=1;next} /^## Read first/{f=0} f'); }
ho_rd() { (cd "$HO" && bash "$LINT" --brief 2 "$HO/ho-plan-2026-10-05.md" 2>/dev/null | awk '/^## Read first/{f=1;next} /^## Files allowed/{f=0} f'); }

# (a) a filled Handoff prints "Handoff of Task 1 (full receipt <abs>):" and its lines.
printf '# T1\n\n## Handoff (for Blocked-by tasks)\n- sig: foo(a, b)\n- invariant: bar\n\n## Reviews\nnot this\n' > "$HO_RCPT"
HO_A=$(ho_rd)
if printf '%s\n' "$HO_A" | grep -qF "Handoff of Task 1 (full receipt $HO_REAL/docs/rolepod/tasks/ho-plan-2026-10-05/task-01.md):" \
  && printf '%s\n' "$HO_A" | grep -qxF -- '- sig: foo(a, b)' \
  && printf '%s\n' "$HO_A" | grep -qxF -- '- invariant: bar' \
  && ! printf '%s\n' "$HO_A" | grep -qF 'not this'; then
  echo "  ✓ --brief inlines a Blocked-by task's Handoff lines under a header with the receipt path"
else
  echo "  ✗ --brief Handoff block wrong: [$HO_A]"; fail=$((fail+1))
fi

# (b) a skeleton Handoff (blank / <placeholder> only) falls back to the bare path.
printf '# T1\n\n## Handoff\n\n<signatures, invariants>\n\n## Reviews\n' > "$HO_RCPT"
HO_B=$(ho_rd | grep -v '^$\|^(Lead' || true)
if [ "$HO_B" = "$HO_REAL/docs/rolepod/tasks/ho-plan-2026-10-05/task-01.md" ]; then
  echo "  ✓ --brief prints the bare receipt path for a skeleton Handoff"
else
  echo "  ✗ --brief skeleton Handoff not a bare path: [$HO_B]"; fail=$((fail+1))
fi

# (c) over 600 chars -> whole lines only, then the cut marker.
{ printf '# T1\n\n## Handoff\n'; for i in 1 2 3 4 5 6 7 8; do printf -- '- line %s %0100d\n' "$i" 0; done; printf '\n## Reviews\n'; } > "$HO_RCPT"
HO_C=$(ho_rd)
HO_C_LINES=$(printf '%s\n' "$HO_C" | grep -c '^- line ' || true)
if printf '%s\n' "$HO_C" | grep -qxF '(cut - the rest is in the receipt)' && [ "$HO_C_LINES" -ge 1 ] && [ "$HO_C_LINES" -lt 8 ]; then
  echo "  ✓ --brief cuts an over-long Handoff at whole lines with the cut marker"
else
  echo "  ✗ --brief long Handoff not cut: lines=$HO_C_LINES [$HO_C]"; fail=$((fail+1))
fi

# (d) a fenced "## x" inside the Handoff does not close the section.
printf '# T1\n\n## Handoff\n- before\n```\n## x\n- inside\n```\n- after\n\n## Reviews\n' > "$HO_RCPT"
HO_D=$(ho_rd)
if printf '%s\n' "$HO_D" | grep -qxF -- '- inside' && printf '%s\n' "$HO_D" | grep -qxF -- '- after'; then
  echo "  ✓ --brief keeps a fenced ## heading inside the Handoff section"
else
  echo "  ✗ --brief fenced heading closed the Handoff: [$HO_D]"; fail=$((fail+1))
fi

# (e) the heading "## Handoff (for Blocked-by tasks)" matches (covered by (a)); no receipt -> bare path.
rm -f "$HO_RCPT"
HO_E=$(ho_rd | grep -v '^$\|^(Lead' || true)
if [ "$HO_E" = "$HO_REAL/docs/rolepod/tasks/ho-plan-2026-10-05/task-01.md" ]; then
  echo "  ✓ --brief prints the bare receipt path when the receipt is missing"
else
  echo "  ✗ --brief missing receipt not a bare path: [$HO_E]"; fail=$((fail+1))
fi

# F4: the Return line carries the chat reply cap.
if printf '%s\n' "$TR2" | grep -q 'chat reply stays within 12 lines'; then
  echo "  ✓ --brief Return line caps the chat reply at 12 lines"
else
  echo "  ✗ --brief Return line lacks the 12-line reply cap"; fail=$((fail+1))
fi

# ── review-set (C61 / C63): one cell, printed by --review-set and --brief ──
# Facts only: role names, lens names, depth, line counts.
RS_LENS='`rolepod-reviewer` `lens: spec` + `rolepod-reviewer` `lens: standards`'
RS_SPEC='each matched specialist (`rolepod-reviewer` `lens: perf` · `lens: ui` · `lens: arch`, when its row matches)'
RS_SK="$(cd "$(dirname "$LINT")/../.." && pwd)"
rs() { bash "$LINT" --review-set "$@" 2>/dev/null; }
rs_ok=1
for m in lite standard full; do
  [ "$(rs --tier R1 --mode $m)" = 'Review: `none`' ] || { rs_ok=0; echo "  . $m R1"; }
  for t in R2 R3 R4; do
    got=$(rs --tier $t --mode $m); want="$RS_LENS"
    case "$m/$t" in
      standard/R3|full/R3) want="$RS_LENS + $RS_SPEC" ;;
      standard/R4) want='`rolepod-reviewer` `lens: security` (depth: checklist, model: strong, skill: `'"$RS_SK"'/security-review/SKILL.md`) + '"$RS_LENS" ;;
      full/R4) printf '%s\n' "$got" | grep -qF '`rolepod-reviewer` `lens: security` (depth: full, model: strong, skill: `'"$RS_SK"'/security-review/SKILL.md`) + '"$RS_LENS"' + the adversarial pass' && printf '%s\n' "$got" | grep -qF 'else `rolepod-reviewer` `lens: adversarial` (model: strong, skill: `'"$RS_SK"'/adversarial-review/SKILL.md`;' && want="${got#Review: }" ;;
    esac
    printf '%s\n' "$got" | grep -qE 'universal-reviewer|security-engineer|adversarial-reviewer|performance-engineer|ui-ux-designer|system-architect' && { rs_ok=0; echo "  . $m $t: old role name"; }
    printf '%s\n' "$got" | grep -qF 'lens:' || { rs_ok=0; echo "  . $m $t: no lens:"; }
    [ "$got" = "Review: $want" ] && [ "$(printf '%s\n' "$got" | grep -c .)" -eq 1 ] || { rs_ok=0; echo "  . $m $t: $got"; }
  done
done
if [ "$rs_ok" = 1 ]; then echo "  ✓ --review-set: lite / standard / full x R1-R4 print one line each, the C61 cell"
else echo "  ✗ --review-set cells wrong"; fail=$((fail+1)); fi
if [ "$(rs --tier R2 --mode standard --match ui)" = "Review: $RS_LENS + \`rolepod-reviewer\` \`lens: ui\`" ] \
  && [ "$(rs --tier R3 --mode full --match perf,arch)" = "Review: $RS_LENS + \`rolepod-reviewer\` \`lens: perf\` + \`rolepod-reviewer\` \`lens: arch\`" ] \
  && [ "$(rs --tier R2 --mode lite --match ui)" = "Review: $RS_LENS" ] \
  && [ "$(rs --tier R3 --mode lite --match ui,perf)" = "Review: $RS_LENS" ] \
  && ! rs --tier R4 --mode standard --match ui | grep -qF 'lens: ui'; then
  echo "  ✓ --review-set --match: Standard / Full R2 and R3 add the role to the lenses; Lite and R4 ignore it"
else echo "  ✗ --review-set --match wrong"; fail=$((fail+1)); fi
# A15: every skill path --review-set prints at R4 exists from the repo, a .worktrees checkout and the installed plugin copy.
a15_paths() { # <script> -> the skill SKILL.md paths printed at Standard and Full R4
  local s="$1" m
  for m in standard full; do
    bash "$s" --review-set --tier R4 --mode $m 2>/dev/null | grep -o '[^` ]*/SKILL\.md' || true
  done
}
a15_ok=1; a15_n=0
A15_WT="$REPO_DIR/.worktrees/a15-$$"
mkdir -p "$REPO_DIR/.worktrees"
if git -C "$REPO_DIR" worktree add --detach "$A15_WT" HEAD >/dev/null 2>&1; then
  cp "$LINT" "$A15_WT/core/skills/write-plan/scripts/plan-lint.sh"
  A15_SCRIPTS="$LINT|$A15_WT/core/skills/write-plan/scripts/plan-lint.sh"
else A15_SCRIPTS="$LINT"; fi
[ -f "$REPO_DIR/plugins/rolepod/skills/write-plan/scripts/plan-lint.sh" ] && A15_SCRIPTS="$A15_SCRIPTS|$REPO_DIR/plugins/rolepod/skills/write-plan/scripts/plan-lint.sh"
IFS='|' read -r -a A15_ARR <<< "$A15_SCRIPTS"
for s in "${A15_ARR[@]}"; do
  a15_got=$(cd "$(dirname "$s")" && a15_paths "$s")
  [ "$(printf '%s\n' "$a15_got" | grep -c 'security-review/SKILL.md')" -ge 2 ] && [ "$(printf '%s\n' "$a15_got" | grep -c 'adversarial-review/SKILL.md')" -ge 1 ] || a15_ok=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    a15_n=$((a15_n+1))
    pn="$(cd "$(dirname "$p")" 2>/dev/null && pwd)/$(basename "$p")"
    [ -f "$pn" ] || { a15_ok=0; echo "  . A15 missing: $p ($s)"; }
  done <<< "$a15_got"
done
git -C "$REPO_DIR" worktree remove --force "$A15_WT" >/dev/null 2>&1 || true
if [ "$a15_ok" = 1 ] && [ "${#A15_ARR[@]}" -ge 2 ]; then echo "  ✓ --review-set R4 skill paths exist from ${#A15_ARR[@]} script locations ($a15_n paths)"
else echo "  ✗ --review-set R4 skill paths broken (locations: ${#A15_ARR[@]})"; fail=$((fail+1)); fi
# ── role-reduction s2a T4: R2 matched row adds the role; B1 report names; L1 untagged owner lines ──
if r2=$(ROLEPOD_SESSION_MODE=standard ROLEPOD_SESSION_SOURCE=default bash "$LINT" --review-set --tier R2 --match perf 2>/dev/null) \
  && printf '%s' "$r2" | grep -qF 'lens: spec' && printf '%s' "$r2" | grep -qF 'lens: standards' && printf '%s' "$r2" | grep -qF '`rolepod-reviewer` `lens: perf`'; then
  echo "  ✓ --review-set R2 --match perf prints both lenses and the perf lens"
else echo "  ✗ --review-set R2 --match perf missing a lens or the role: $r2"; fail=$((fail+1)); fi
b1=$(bash "$LINT" --brief 1 "$TMP/brief-auth.md" 2>/dev/null)
if printf '%s\n' "$b1" | grep -qF -- '-<lens>.md, <lens> one of spec · standards · security · adversarial · perf · ui · arch.'; then
  echo "  ✓ --brief Bounds names <lens>.md with the lens list (B1)"
else echo "  ✗ --brief Bounds lacks the B1 report line"; fail=$((fail+1)); fi
cat > "$TMP/l1-plan.md" <<'EOF'
# L1 Plan
## Files to touch
- `api/a.py`
- `api/b.py`
## Tasks
### Task 1: a
- [ ] Files: api/a.py
- [ ] Command: true
### Task 2: b
- [ ] Files: api/b.py
- [ ] Command: true
## Parallel layout
Two tracks per `l1-contract.md`.
## Failure policy
Default: debug-issue; after 2 failures consult once; allow 4 informed fixes.
EOF
printf '# C\n## File ownership\n- `backend-developer`: `api/a.py`\n- `backend-developer`: `api/b.py`\n' > "$TMP/l1-contract.md"
printf '# C\n## File ownership\n- `backend-developer` (T1): `api/a.py`\n- `backend-developer` (T2): `api/b.py`\n' > "$TMP/l1-tagged.md"
l1rc=0; l1out=$(bash "$LINT" "$TMP/l1-plan.md" "$TMP/l1-contract.md" 2>&1) || l1rc=$?
if [ "$l1rc" -ne 0 ] && printf '%s' "$l1out" | grep -qF 'two owner lines for `backend-developer` carry no task tag' \
  && bash "$LINT" "$TMP/l1-plan.md" "$TMP/l1-tagged.md" >/dev/null 2>&1; then
  echo "  ✓ plan-lint L1: two untagged owner lines for one role FAIL; tagged (T1)/(T2) PASS"
else echo "  ✗ plan-lint L1 wrong (rc=$l1rc): $l1out"; fail=$((fail+1)); fi
# L1 reads labels as --brief does: a tag inside the backticks counts; a prose bullet with no backticked token is no role.
printf '# C\n## File ownership\n- `backend-developer (T1)`: `api/a.py`\n- `backend-developer (T1)`: `api/b.py`\n' > "$TMP/l1-inner.md"
printf '# C\n## File ownership\n- `backend-developer` (T1): `api/a.py`\n- `frontend-developer`: `api/b.py`\n- Note: shared fixture\n- Note: merge order\n' > "$TMP/l1-prose.md"
if bash "$LINT" "$TMP/l1-plan.md" "$TMP/l1-inner.md" >/dev/null 2>&1 \
  && bash "$LINT" "$TMP/l1-plan.md" "$TMP/l1-prose.md" >/dev/null 2>&1; then
  echo "  ✓ plan-lint L1: an in-backtick tag and prose Note lines never false-FAIL"
else echo "  ✗ plan-lint L1 false FAIL on an in-backtick tag or prose Note lines"; fail=$((fail+1)); fi
RS_HOME="$TMP/rs-home"; mkdir -p "$RS_HOME"
rs_bare() { ( cd "$TMP" && env -u ROLEPOD_SESSION_MODE -u ROLEPOD_SESSION_SOURCE -u ROLEPOD_SESSION_CLI -u CLAUDE_CODE_SESSION_ID -u CODEX_THREAD_ID -u CLAUDE_PLUGIN_ROOT HOME="$RS_HOME" bash "$LINT" "$@" 2>/dev/null ); }
if [ "$(rs --tier R3 --mode bogus)" = "Review: $RS_LENS" ] \
  && [ "$(rs_bare --review-set --tier R3)" = "Review: $RS_LENS" ] \
  && [ "$(rs_bare --brief 1 "$TMP/brief-auth.md" | grep -c '^Workflow mode: lite (default)$')" -eq 1 ]; then
  echo "  ✓ --review-set: an unknown or unresolved mode is lite; --brief names the same default"
else echo "  ✗ --review-set unknown-mode fallback wrong"; fail=$((fail+1)); fi
# Parity: the --brief Reviewers line 1 (R4 task, only-code R3 task) == --review-set.
par_ok=1
for m in lite standard full; do
  for pair in "brief-auth.md:R4" "brief-tier-r3.md:R3"; do
    pf=${pair%%:*}; pt=${pair##*:}
    b=$(cd "$TMP" && ROLEPOD_SESSION_MODE=$m ROLEPOD_SESSION_SOURCE=global bash "$LINT" --brief 1 "$TMP/$pf" | awk '/^## Reviewers/{getline; print; exit}')
    [ "Review: $b" = "$(rs --tier $pt --mode $m)" ] || { par_ok=0; echo "  . parity $m $pt"; }
  done
done
if [ "$par_ok" = 1 ]; then echo "  ✓ --brief Reviewers line 1 == --review-set cell (lite / standard / full; R4 and only-code R3)"
else echo "  ✗ --brief / --review-set parity broken"; fail=$((fail+1)); fi
# Usage errors: exit 2, one stderr line, empty stdout.
us_ok=1
for args in "" "--tier R5" "--tier R2 --match db" "--tier R2 --match perf," "--tier" "--tier R2 --bogus"; do
  rc=0; o=$(bash "$LINT" --review-set $args 2>"$TMP/rs.err") || rc=$?
  [ "$rc" -eq 2 ] && [ -z "$o" ] && [ "$(grep -c . "$TMP/rs.err")" -eq 1 ] || { us_ok=0; echo "  . usage [$args] rc=$rc"; }
done
if [ "$us_ok" = 1 ]; then echo "  ✓ --review-set usage errors exit 2 with one stderr line and empty stdout"
else echo "  ✗ --review-set usage handling wrong"; fail=$((fail+1)); fi
# A brief of a task no longer carries the round or dispatch mechanics.
if ! grep -rqE 'Foreground only|run_in_background|WAITING' "$LINT"; then
  echo "  ✓ plan-lint.sh holds no foreground / run_in_background / WAITING mechanism text"
else echo "  ✗ plan-lint.sh still holds dispatch mechanism text"; fail=$((fail+1)); fi

# ── check 3c: an R4 task (by a risk path) must be named under ## High-risk surfaces touched ──
mk3c() { # $1 = out file, $2 = Files of Task 1, $3 = the section body, [$4 = Task 2 Files]
  { printf '# Plan\n\n## High-risk surfaces touched\n%s\n\n## Parallel layout\nSequential — single owner.\n\n## Tasks\n\n' "$3"
    printf '### Task 1: one\n- **Blocked by:** none\n- [ ] **Files:** %s\n- [ ] **Command:** true\n- **Owner:** Lead\n\n' "$2"
    [ -z "${4:-}" ] || printf '### Task 2: two\n- **Blocked by:** none\n- [ ] **Files:** %s\n- [ ] **Command:** true\n- **Owner:** Lead\n\n' "$4"
    printf '## Failure policy\nDefault: stop.\n'; } > "$1"
}
c3() { rc=0; C3OUT=$(cd "$TMP" && bash "$LINT" "$1" 2>&1) || rc=$?; }
mk3c "$TMP/h1.md" '`src/auth/login.ts`' 'None'
c3 "$TMP/h1.md"
if [ "$rc" -eq 1 ] && printf '%s\n' "$C3OUT" | grep -qF '✗ R4 task without a high-risk line: Task 1 — name it under ## High-risk surfaces touched with its surface'; then
  echo "  ✓ plain lint FAILs an R4 task (risk path) with no high-risk line (H1)"
else echo "  ✗ H1 wrong rc=$rc: $C3OUT"; fail=$((fail+1)); fi
mk3c "$TMP/h2.md" '`src/auth/login.ts`' '- Task 1 — login token check'
c3 "$TMP/h2.md"
if [ "$rc" -eq 0 ] && printf '%s\n' "$C3OUT" | grep -qF '✓ every R4 task is named under ## High-risk surfaces touched'; then
  echo "  ✓ plain lint passes once a line names the R4 task and prints the ✓ line (H2)"
else echo "  ✗ H2 wrong rc=$rc: $C3OUT"; fail=$((fail+1)); fi
mk3c "$TMP/h3.md" '`docs/auth.md`' 'None'
c3 "$TMP/h3.md"
if [ "$rc" -eq 0 ] && ! printf '%s\n' "$C3OUT" | grep -qE 'R4 task|every R4'; then
  echo "  ✓ a prose-only task prints no 3c line (H3)"
else echo "  ✗ H3 wrong rc=$rc: $C3OUT"; fail=$((fail+1)); fi
mkdir -p "$TMP/h4root/.rolepod" "$TMP/h4root/plans"
git -C "$TMP/h4root" init -q
printf '+src/money/\n' > "$TMP/h4root/.rolepod/risk-paths"
mk3c "$TMP/h4root/plans/h4.md" '`src/money/split.ts`' 'None'
rc=0; C3OUT=$(cd "$TMP/h4root" && bash "$LINT" plans/h4.md 2>&1) || rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$C3OUT" | grep -qF 'R4 task without a high-risk line: Task 1'; then
  echo "  ✓ a .rolepod/risk-paths path makes the task R4 for 3c (H4)"
else echo "  ✗ H4 wrong rc=$rc: $C3OUT"; fail=$((fail+1)); fi
mk3c "$TMP/h5.md" '`src/auth/login.ts`' '- Task 2 — webhook signature' '`src/webhook/sign.ts`'
c3 "$TMP/h5.md"
if [ "$rc" -eq 1 ] && printf '%s\n' "$C3OUT" | grep -qF 'Task 1 —' && ! printf '%s\n' "$C3OUT" | grep -qF 'without a high-risk line: Task 2'; then
  echo "  ✓ two R4 tasks, one named: only the unnamed task is reported (H5)"
else echo "  ✗ H5 wrong rc=$rc: $C3OUT"; fail=$((fail+1)); fi
mk3c "$TMP/h6.md" '`src/auth/login.ts`' '- auth is touched'
c3 "$TMP/h6.md"
if [ "$rc" -eq 1 ] && printf '%s\n' "$C3OUT" | grep -qF 'R4 task without a high-risk line: Task 1'; then
  echo "  ✓ a section line with no task tag does not satisfy 3c (H6)"
else echo "  ✗ H6 wrong rc=$rc: $C3OUT"; fail=$((fail+1)); fi
# --brief never FAILs on this rule: an R4 task without a line still prints its brief.
rc=0; B3=$(cd "$TMP" && bash "$LINT" --brief 1 "$TMP/h1.md") || rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$B3" | grep -A1 '^## Tier' | grep -qF 'R4'; then
  echo "  ✓ --brief prints an R4 task without a high-risk line (exit 0)"
else echo "  ✗ --brief on an unnamed R4 task wrong rc=$rc"; fail=$((fail+1)); fi

# ── F2: no "## Files to touch" section — check 5 and Files forbidden read the union of every task's Files ──
NS=$(mktemp -d)
cat > "$NS/plan.md" <<'PLAN'
# No Section Plan

## Tasks

### Task 1: first
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `hooks/a.sh`
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** devops-sre
- **Done when:** done

### Task 2: second
- **Delivers:** d
- **Blocked by:** none
- [ ] **Files:** `hooks/b.sh`, `Makefile` — reads `KIND`
  and `tests/b.sh`
- [ ] **Change:** c
- [ ] **Command:** true
- **Owner:** backend-developer
- **Done when:** done

## Parallel layout
Parallel — contract: `contract.md`

## Failure policy
Default: stop.
PLAN
cat > "$NS/contract.md" <<'CONTRACT'
# No Section Contract

## File ownership
- `devops-sre`: `hooks/a.sh`
- `backend-developer`: `hooks/b.sh`, `Makefile`, `tests/b.sh`
CONTRACT
NSOUT=$(cd "$NS" && bash "$LINT" plan.md contract.md 2>&1) && NSRC=0 || NSRC=$?
if [ "$NSRC" -eq 0 ] && ! printf '%s\n' "$NSOUT" | grep -q 'no backticked paths'; then
  echo "  ✓ plan-lint.sh check 5 passes a parallel plan with no Files to touch section"
else
  echo "  ✗ plan-lint.sh check 5 rc=$NSRC without the section: $NSOUT"; fail=$((fail+1))
fi
printf '# No Section Contract\n\n## File ownership\n- `devops-sre`: `hooks/a.sh`\n- `backend-developer`: `hooks/b.sh`, `Makefile`\n' > "$NS/contract-gap.md"
NSGAP=$(cd "$NS" && bash "$LINT" plan.md contract-gap.md 2>&1) && NSGRC=0 || NSGRC=$?
if [ "$NSGRC" -ne 0 ] && printf '%s\n' "$NSGAP" | grep -qF 'unowned file: `tests/b.sh`' \
  && ! printf '%s\n' "$NSGAP" | grep -qF 'KIND'; then
  echo "  ✓ plan-lint.sh check 5 flags a task Files path with no owner (no section needed)"
else
  echo "  ✗ plan-lint.sh check 5 missed an unowned task Files path rc=$NSGRC: $NSGAP"; fail=$((fail+1))
fi
NSB=$(cd "$NS" && bash "$LINT" --brief 1 plan.md contract.md 2>/dev/null)
NSF=$(printf '%s\n' "$NSB" | awk '/^## Files forbidden/{f=1;next} /^## /{f=0} f')
if printf '%s\n' "$NSF" | grep -qxF -- '- hooks/b.sh' && printf '%s\n' "$NSF" | grep -qxF -- '- Makefile' \
  && printf '%s\n' "$NSF" | grep -qxF -- '- tests/b.sh' && ! printf '%s\n' "$NSF" | grep -qF 'KIND' \
  && ! printf '%s\n' "$NSF" | grep -qxF -- '- hooks/a.sh'; then
  echo "  ✓ --brief Files forbidden is the other tasks' Files when the plan has no Files to touch section"
else
  echo "  ✗ --brief Files forbidden without the section: $NSF"; fail=$((fail+1))
fi
rm -rf "$NS"

if [ "$fail" -eq 0 ]; then
  echo "  ✓ pass"
  exit 0
else
  echo "  ✗ fail ($fail)"
  exit 1
fi
