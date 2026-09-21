#!/bin/bash
# ticket — proves scripts/ticket.sh's start/integrate/finish/log against
# fixture repos, per spec lead-cost-no-pause-2026-09-22 acceptance 1-3 + R2
# (integrate never commits) + R1 (idempotent, fail-closed). Each fixture is
# its own throwaway git repo so no scenario leaks state into another.
set -uo pipefail

fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TICKET="$REPO_DIR/scripts/ticket.sh"

mkrepo() { # $1 = dir — a throwaway repo with an initial empty commit
  mkdir -p "$1"
  ( cd "$1" && git init -q . && git config user.email t@t && git config user.name t \
    && git commit -q --allow-empty -m init )
}

# ═══════════════════════════════════════════════════════════════════════
# start — acceptance 1: dispatch line, idempotency
# ═══════════════════════════════════════════════════════════════════════

FR="$TMP/fixture-repo"
mkdir -p "$FR"
( cd "$FR" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$FR/plan.md" <<'EOF'
# Sample Feature Plan

## Tasks

### Task 1: build the widget
- **Delivers:** the widget exists.
- **Blocked by:** none
- [ ] **Files:** `widget.txt`
- [ ] **Change:** create widget.txt
- [ ] **Test / evidence:** cat widget.txt
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "$FR" && git add -A && git commit -q -m init )

OUT=$(bash "$TICKET" start "$FR/plan.md" 1 2>"$TMP/start.err")
RC=$?
BRIEF_PATH=$(printf '%s\n' "$OUT" | awk '{print $1}')
WT_PATH=$(printf '%s\n' "$OUT" | awk '{print $2}')
NFIELDS=$(printf '%s\n' "$OUT" | awk '{print NF}')

if [ "$RC" -eq 0 ] && [ "$NFIELDS" -eq 2 ] && [ ${#OUT} -le 600 ] \
  && [ -f "$BRIEF_PATH" ] && [ -d "$WT_PATH" ]; then
  echo "  ✓ start prints one line <=600 chars holding exactly two paths (brief, worktree)"
else
  echo "  ✗ start dispatch line wrong: rc=$RC len=${#OUT} nfields=$NFIELDS out=[$OUT]"; fail=$((fail+1))
  cat "$TMP/start.err" >&2
fi

if grep -q '^## Worktree' "$BRIEF_PATH" 2>/dev/null && grep -q '^## Command' "$BRIEF_PATH" 2>/dev/null; then
  echo "  ✓ start's brief file is a real plan-lint --brief assembly"
else
  echo "  ✗ start's brief file missing expected sections"; fail=$((fail+1))
fi

WT_COUNT_1=$(git -C "$FR" worktree list | wc -l | tr -d ' ')
OUT2=$(bash "$TICKET" start "$FR/plan.md" 1 2>>"$TMP/start.err")
RC2=$?
WT_COUNT_2=$(git -C "$FR" worktree list | wc -l | tr -d ' ')
if [ "$RC2" -eq 0 ] && [ "$OUT2" = "$OUT" ] && [ "$WT_COUNT_2" = "$WT_COUNT_1" ]; then
  echo "  ✓ start re-run on an existing worktree reprints the same line and creates nothing new"
else
  echo "  ✗ start is not idempotent: rc2=$RC2 wt1=$WT_COUNT_1 wt2=$WT_COUNT_2 out=[$OUT2] vs [$OUT]"; fail=$((fail+1))
fi

# A FAILing plan (no Failure policy) must stop start before anything is written.
cat > "$FR/bad-plan.md" <<'EOF'
# Bad Plan
### Task 1: x
- [ ] Command: true
EOF
if bash "$TICKET" start "$FR/bad-plan.md" 1 >/dev/null 2>"$TMP/bad.err"; then
  echo "  ✗ start proceeded past a plan-lint FAIL"; fail=$((fail+1))
else
  echo "  ✓ start stops on a plan-lint FAIL, before writing a brief or a worktree"
fi

# ── --base: the worktree branches off the NAMED base, not the current HEAD
BBR="$TMP/base-repo"
mkdir -p "$BBR"
( cd "$BBR" && git init -q . && git config user.email t@t && git config user.name t )
echo main-only > "$BBR/main-file.txt"
( cd "$BBR" && git add -A && git commit -q -m "main commit" )
( cd "$BBR" && git checkout -q -b feature-base )
echo feature-only > "$BBR/feature-file.txt"
( cd "$BBR" && git add -A && git commit -q -m "feature-base commit" )
( cd "$BBR" && git checkout -q main 2>/dev/null || git checkout -q master )
cat > "$BBR/plan.md" <<'EOF'
# Base Feature Plan

## Tasks

### Task 1: build the base widget
- **Delivers:** the widget exists.
- **Blocked by:** none
- [ ] **Files:** `widget.txt`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "$BBR" && git add -A && git commit -q -m "add plan" )
BOUT=$(bash "$TICKET" start "$BBR/plan.md" 1 --base feature-base 2>"$TMP/base.err")
BWT=$(printf '%s\n' "$BOUT" | awk '{print $2}')
if [ -f "$BWT/feature-file.txt" ]; then
  echo "  ✓ start --base branches the worktree off the named base, not the current HEAD"
else
  echo "  ✗ start --base wrong: worktree=[$BWT]"; ls "$BWT" 2>&1; cat "$TMP/base.err" >&2; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# integrate — acceptance 2 + R2 (never commits) + docs/rolepod exclusion
# ═══════════════════════════════════════════════════════════════════════

# ── green path: ok steps, <=40 lines, ends in the commit command, no commit made
IR="$TMP/integrate-repo"
mkrepo "$IR"
( cd "$IR" && git worktree add -q -b task-branch "$TMP/integrate-wt" )
echo widget > "$TMP/integrate-wt/widget.txt"
LOG_BEFORE=$(git -C "$IR" log --oneline --all)
cat > "$TMP/brief-ok.md" <<'EOF'
## Command
`test -f widget.txt`
## Proof
widget is non-empty
`test -s widget.txt`
EOF
OUT=$(bash "$TICKET" integrate "$TMP/integrate-wt" --brief "$TMP/brief-ok.md" 2>&1)
RC=$?
LOG_AFTER=$(git -C "$IR" log --oneline --all)
LINES=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
if [ "$RC" -eq 0 ] && [ "$LINES" -le 40 ] \
  && printf '%s\n' "$OUT" | grep -q '^merge: ok' \
  && printf '%s\n' "$OUT" | grep -q '^command: ok' \
  && printf '%s\n' "$OUT" | grep -q '^proof: ok' \
  && printf '%s\n' "$OUT" | tail -1 | grep -q 'commit -m'; then
  echo "  ✓ integrate green path: <=40 lines, ok per step, ends with the commit command"
else
  echo "  ✗ integrate green path wrong (rc=$RC lines=$LINES): $OUT"; fail=$((fail+1))
fi
if [ "$LOG_BEFORE" = "$LOG_AFTER" ]; then
  echo "  ✓ integrate never creates a commit"
else
  echo "  ✗ integrate created a commit — git log changed"; fail=$((fail+1))
fi

# ── failing Command: non-zero + failing tail, Proof never runs
cat > "$TMP/brief-fail.md" <<'EOF'
## Command
`false`
## Proof
should never run
`false`
EOF
OUT=$(bash "$TICKET" integrate "$TMP/integrate-wt" --brief "$TMP/brief-fail.md" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && printf '%s\n' "$OUT" | grep -q '^command: FAIL' \
  && ! printf '%s\n' "$OUT" | grep -q '^proof:'; then
  echo "  ✓ integrate: a failing Command exits non-zero, prints a failing tail, never reaches Proof"
else
  echo "  ✗ integrate failing-Command handling wrong (rc=$RC): $OUT"; fail=$((fail+1))
fi

# ── a failing Proof (Command itself green) also exits non-zero
PFR="$TMP/proof-repo"
mkrepo "$PFR"
( cd "$PFR" && git worktree add -q -b proof-branch "$TMP/proof-wt" )
cat > "$TMP/brief-proof-fail.md" <<'EOF'
## Command
`true`
## Proof
a false claim
`false`
EOF
OUT=$(bash "$TICKET" integrate "$TMP/proof-wt" --brief "$TMP/brief-proof-fail.md" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && printf '%s\n' "$OUT" | grep -q '^command: ok' && printf '%s\n' "$OUT" | grep -q '^proof: FAIL'; then
  echo "  ✓ integrate: a failing Proof command exits non-zero after a green Command"
else
  echo "  ✗ integrate failing-Proof handling wrong (rc=$RC): $OUT"; fail=$((fail+1))
fi

# ── --gate: runs last, after a green Command/Proof; failing it exits non-zero
GTR="$TMP/gate-repo"
mkrepo "$GTR"
( cd "$GTR" && git worktree add -q -b gate-branch "$TMP/gate-wt" )
cat > "$TMP/brief-gate.md" <<'EOF'
## Command
`true`
## Proof
trivially true
`true`
EOF
OUT=$(bash "$TICKET" integrate "$TMP/gate-wt" --brief "$TMP/brief-gate.md" --gate 'false' 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && printf '%s\n' "$OUT" | grep -q '^command: ok' \
  && printf '%s\n' "$OUT" | grep -q '^proof: ok' && printf '%s\n' "$OUT" | grep -q '^gate: FAIL' \
  && ! printf '%s\n' "$OUT" | grep -q 'commit -m'; then
  echo "  ✓ integrate: a failing --gate exits non-zero after green Command/Proof, no commit command printed"
else
  echo "  ✗ integrate --gate handling wrong (rc=$RC): $OUT"; fail=$((fail+1))
fi

# ── --pre runs BEFORE the ff-merge: without it a conflicting local edit
# blocks the merge; with it (discarding the edit first) the merge succeeds.
PRR="$TMP/pre-repo"
mkrepo "$PRR"
echo old > "$PRR/render.txt"
( cd "$PRR" && git add -A && git commit -q -m "add render.txt" )
( cd "$PRR" && git worktree add -q -b pre-branch-a "$TMP/pre-wt-a" )
( cd "$PRR" && git worktree add -q -b pre-branch-b "$TMP/pre-wt-b" )
echo new > "$PRR/render.txt"
( cd "$PRR" && git commit -aqm "advance base" )
echo dirty-local > "$TMP/pre-wt-a/render.txt"
echo dirty-local > "$TMP/pre-wt-b/render.txt"
cat > "$TMP/brief-pre.md" <<'EOF'
## Command
`true`
EOF
OUT_A=$(bash "$TICKET" integrate "$TMP/pre-wt-a" --brief "$TMP/brief-pre.md" --pre 'git checkout -- render.txt' 2>&1)
RC_A=$?
OUT_B=$(bash "$TICKET" integrate "$TMP/pre-wt-b" --brief "$TMP/brief-pre.md" 2>&1)
RC_B=$?
if [ "$RC_B" -ne 0 ] && printf '%s\n' "$OUT_B" | grep -q '^merge: FAIL'; then
  echo "  ✓ without --pre, a conflicting local edit blocks the ff-merge (control case)"
else
  echo "  ✗ control case did not reproduce a blocked merge (rc=$RC_B): $OUT_B"; fail=$((fail+1))
fi
if [ "$RC_A" -eq 0 ] && printf '%s\n' "$OUT_A" | grep -q '^pre: ok' && printf '%s\n' "$OUT_A" | grep -q '^merge: ok'; then
  echo "  ✓ --pre runs before the ff-merge (clears the conflict the control case hit)"
else
  echo "  ✗ --pre did not run before the merge (rc=$RC_A): $OUT_A"; fail=$((fail+1))
fi

# ── docs/rolepod/ is never staged, even when it holds an uncommitted file
SR="$TMP/stage-repo"
mkrepo "$SR"
( cd "$SR" && git worktree add -q -b stage-branch "$TMP/stage-wt" )
mkdir -p "$TMP/stage-wt/docs/rolepod"
echo secret > "$TMP/stage-wt/docs/rolepod/private.md"
echo public > "$TMP/stage-wt/public.txt"
cat > "$TMP/brief-stage.md" <<'EOF'
## Command
`true`
EOF
OUT=$(bash "$TICKET" integrate "$TMP/stage-wt" --brief "$TMP/brief-stage.md" 2>&1)
RC=$?
STAGED=$(git -C "$TMP/stage-wt" diff --cached --name-only)
UNSTAGED_STATUS=$(git -C "$TMP/stage-wt" status --porcelain -- docs/rolepod)
if [ "$RC" -eq 0 ] && printf '%s\n' "$STAGED" | grep -qF 'public.txt' \
  && ! printf '%s\n' "$STAGED" | grep -q 'docs/rolepod' \
  && printf '%s\n' "$UNSTAGED_STATUS" | grep -q '^??'; then
  echo "  ✓ integrate stages everything except docs/rolepod/ (still untracked afterward)"
else
  echo "  ✗ docs/rolepod/ handling wrong: staged=[$STAGED] status=[$UNSTAGED_STATUS]"; fail=$((fail+1))
fi
if ! printf '%s\n' "$OUT" | grep -q '^proof:'; then
  echo "  ✓ integrate prints no proof: line when the brief has no ## Proof section"
else
  echo "  ✗ integrate printed a proof: line with no ## Proof section: $OUT"; fail=$((fail+1))
fi

# ── ambiguous state: commits ahead of base AND a dirty tree → refuse
AR="$TMP/ambig-repo"
mkrepo "$AR"
( cd "$AR" && git worktree add -q -b ambig-branch "$TMP/ambig-wt" )
( cd "$TMP/ambig-wt" && git commit -q --allow-empty -m "already committed once" )
echo dirty > "$TMP/ambig-wt/uncommitted.txt"
OUT=$(bash "$TICKET" integrate "$TMP/ambig-wt" --brief "$TMP/brief-stage.md" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && printf '%s\n' "$OUT" | grep -qi 'ambiguous'; then
  echo "  ✓ integrate refuses a worktree with commits ahead of base AND a dirty tree"
else
  echo "  ✗ integrate did not refuse the ambiguous state (rc=$RC): $OUT"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# finish — acceptance 3
# ═══════════════════════════════════════════════════════════════════════

# ── refuses a dirty worktree
FDR="$TMP/finish-dirty-repo"
mkrepo "$FDR"
( cd "$FDR" && git worktree add -q -b finish-dirty-branch "$TMP/finish-dirty-wt" )
echo dirty > "$TMP/finish-dirty-wt/x.txt"
OUT=$(bash "$TICKET" finish "$TMP/finish-dirty-wt" 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
  echo "  ✓ finish refuses a dirty worktree"
else
  echo "  ✗ finish accepted a dirty worktree: $OUT"; fail=$((fail+1))
fi

# ── refuses a worktree whose branch diverged from base (nothing to merge)
FVR="$TMP/finish-diverged-repo"
mkrepo "$FVR"
( cd "$FVR" && git worktree add -q -b finish-diverged-branch "$TMP/finish-diverged-wt" )
( cd "$FVR" && git commit -q --allow-empty -m "base moves on" )
( cd "$TMP/finish-diverged-wt" && git commit -q --allow-empty -m "branch diverges" )
OUT=$(bash "$TICKET" finish "$TMP/finish-diverged-wt" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && printf '%s\n' "$OUT" | grep -qi 'nothing to merge'; then
  echo "  ✓ finish refuses a diverged (unmerged) branch"
else
  echo "  ✗ finish accepted a diverged branch (rc=$RC): $OUT"; fail=$((fail+1))
fi

# ── a clean, ff-mergeable worktree: merges, cleans up, leaves worktree list = one line
FMR="$TMP/finish-merge-repo"
mkrepo "$FMR"
( cd "$FMR" && git worktree add -q -b finish-merge-branch "$TMP/finish-merge-wt" )
( cd "$TMP/finish-merge-wt" && git commit -q --allow-empty -m "the owner's real commit" )
OUT=$(bash "$TICKET" finish "$TMP/finish-merge-wt" 2>&1)
RC=$?
WLIST_LINES=$(git -C "$FMR" worktree list | wc -l | tr -d ' ')
if [ "$RC" -eq 0 ] && [ "$WLIST_LINES" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^close:' \
  && ! git -C "$FMR" show-ref --quiet refs/heads/finish-merge-branch; then
  echo "  ✓ finish merges a clean branch, removes the worktree, deletes the branch, prints close:"
else
  echo "  ✗ finish happy path wrong (rc=$RC, worktree-list-lines=$WLIST_LINES): $OUT"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# log — the only writer of the plan file besides the Lead's own editor
# ═══════════════════════════════════════════════════════════════════════

cat > "$TMP/log-plan.md" <<'EOF'
# Log Plan

## Tasks

### Task 1: alpha
- [ ] Files: a.txt
- [ ] Command: true

### Task 2: beta
- [ ] Files: b.txt
- [ ] Command: true

## Changes during build

## Follow-ups
EOF
bash "$TICKET" log "$TMP/log-plan.md" 1 --sha abc123 --note "did the thing" >/dev/null
T1_OPEN=$(awk '/^### Task 1/{f=1;next} /^(## |### )/{f=0} f' "$TMP/log-plan.md" | grep -c '\- \[ \]')
T1_DONE=$(awk '/^### Task 1/{f=1;next} /^(## |### )/{f=0} f' "$TMP/log-plan.md" | grep -c '\- \[x\]')
T2_OPEN=$(awk '/^### Task 2/{f=1;next} /^(## |### )/{f=0} f' "$TMP/log-plan.md" | grep -c '\- \[ \]')
if [ "$T1_OPEN" -eq 0 ] && [ "$T1_DONE" -eq 2 ] && [ "$T2_OPEN" -eq 2 ]; then
  echo "  ✓ log flips only the named task's checkboxes, leaving the other task untouched"
else
  echo "  ✗ log flipped the wrong task(s): t1_open=$T1_OPEN t1_done=$T1_DONE t2_open=$T2_OPEN"; fail=$((fail+1))
fi
if grep -qF -- '- Task 1 (`abc123`): did the thing' "$TMP/log-plan.md"; then
  echo "  ✓ log appends one bullet under ## Changes during build"
else
  echo "  ✗ log did not append the expected bullet"; fail=$((fail+1))
fi

# ── log is idempotent: the exact same call twice appends only one bullet
bash "$TICKET" log "$TMP/log-plan.md" 1 --sha abc123 --note "did the thing" >/dev/null
BULLET_COUNT=$(grep -cF -- '- Task 1 (`abc123`): did the thing' "$TMP/log-plan.md")
if [ "$BULLET_COUNT" -eq 1 ]; then
  echo "  ✓ log is idempotent — re-running the same call appends no second bullet"
else
  echo "  ✗ log is not idempotent: bullet appears $BULLET_COUNT times"; fail=$((fail+1))
fi

# ── log refuses (fail-closed) a plan with no ## Changes during build heading
cat > "$TMP/log-plan-nosection.md" <<'EOF'
# No Section Plan

## Tasks

### Task 1: alpha
- [ ] Command: true
EOF
BEFORE_SUM=$(cksum "$TMP/log-plan-nosection.md")
if bash "$TICKET" log "$TMP/log-plan-nosection.md" 1 --sha def456 --note "x" >/dev/null 2>&1; then
  echo "  ✗ log succeeded on a plan with no ## Changes during build heading"; fail=$((fail+1))
else
  AFTER_SUM=$(cksum "$TMP/log-plan-nosection.md")
  if [ "$BEFORE_SUM" = "$AFTER_SUM" ]; then
    echo "  ✓ log refuses (fail-closed) a plan with no ## Changes during build heading, unchanged"
  else
    echo "  ✗ log refused but modified the plan anyway"; fail=$((fail+1))
  fi
fi

# ═══════════════════════════════════════════════════════════════════════

if [ "$fail" -eq 0 ]; then
  echo "ticket: PASS"
else
  echo "ticket: FAIL ($fail)"
fi
exit "$fail"
