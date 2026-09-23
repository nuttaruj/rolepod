#!/bin/bash
# ticket — proves scripts/ticket.sh's start/integrate/finish/log against
# fixture repos, per spec lead-cost-no-pause-2026-09-22 acceptance 1-3 + R2
# (integrate never commits) + R1 (idempotent, fail-closed). Each fixture is
# its own throwaway git repo so no scenario leaks state into another.
set -uo pipefail

fail=0
TMP=$(mktemp -d)
[ -n "$TMP" ] && [ -d "$TMP" ] || { echo "ticket: mktemp -d failed — refusing to run fixtures against an unresolved \$TMP" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TICKET="$REPO_DIR/scripts/ticket.sh"

# The real repo's HEAD and worktree registry must not move while this file
# runs — every fixture lives under $TMP, so any write landing anywhere else
# is a leak (2026-09-22: an unchecked `start` failure left $AG_WT empty,
# `cd ""` no-op'd into the real checkout cwd, and two empty commits landed
# on main — 4b6c061f "task 1 commit", b258f2b9 "the owner's real commit").
# Asserted unconditionally in the epilogue below.
REAL_HEAD_BEFORE="$(git -C "$REPO_DIR" rev-parse HEAD)"
REAL_WORKTREES_BEFORE="$(git -C "$REPO_DIR" worktree list --porcelain)"

mkrepo() { # $1 = dir — a throwaway repo with an initial empty commit
  mkdir -p "$1"
  ( cd "${1:?}" && git init -q . && git config user.email t@t && git config user.name t \
    && git commit -q --allow-empty -m init )
}

# ═══════════════════════════════════════════════════════════════════════
# start — acceptance 1: dispatch line, idempotency
# ═══════════════════════════════════════════════════════════════════════

FR="$TMP/fixture-repo"
mkdir -p "$FR"
( cd "${FR:?}" && git init -q . && git config user.email t@t && git config user.name t )
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
( cd "${FR:?}" && git add -A && git commit -q -m init )

OUT=$(bash "$TICKET" start "$FR/plan.md" 1 2>"$TMP/start.err")
RC=$?
LINE1=$(printf '%s\n' "$OUT" | sed -n '1p')
AGENT_LINE=$(printf '%s\n' "$OUT" | sed -n '2p')
BRIEF_PATH=$(printf '%s\n' "$LINE1" | awk '{print $1}')
WT_PATH=$(printf '%s\n' "$LINE1" | awk '{print $2}')
NFIELDS=$(printf '%s\n' "$LINE1" | awk '{print NF}')

# Done when: line 1 stays exactly two paths (brief, worktree); the agent
# name (needed by `finish`'s "close: <agent>") lands as its own line 2
# "agent: <name>", never a third token that would break NFIELDS.
if [ "$RC" -eq 0 ] && [ "$NFIELDS" -eq 2 ] && [ ${#OUT} -le 600 ] \
  && [ -f "$BRIEF_PATH" ] && [ -d "$WT_PATH" ] \
  && [[ "$AGENT_LINE" == agent:\ * ]]; then
  echo "  ✓ start prints line 1 with exactly two paths (brief, worktree) and line 2 'agent: <name>'"
else
  echo "  ✗ start dispatch lines wrong: rc=$RC len=${#OUT} nfields=$NFIELDS line1=[$LINE1] agent=[$AGENT_LINE]"; fail=$((fail+1))
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
( cd "${BBR:?}" && git init -q . && git config user.email t@t && git config user.name t )
echo main-only > "$BBR/main-file.txt"
( cd "${BBR:?}" && git add -A && git commit -q -m "main commit" )
( cd "${BBR:?}" && git checkout -q -b feature-base )
echo feature-only > "$BBR/feature-file.txt"
( cd "${BBR:?}" && git add -A && git commit -q -m "feature-base commit" )
( cd "${BBR:?}" && git checkout -q main 2>/dev/null || git checkout -q master )
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
( cd "${BBR:?}" && git add -A && git commit -q -m "add plan" )
BOUT=$(bash "$TICKET" start "$BBR/plan.md" 1 --base feature-base 2>"$TMP/base.err")
BWT=$(printf '%s\n' "$BOUT" | sed -n '1p' | awk '{print $2}')
if [ -f "$BWT/feature-file.txt" ]; then
  echo "  ✓ start --base branches the worktree off the named base, not the current HEAD"
else
  echo "  ✗ start --base wrong: worktree=[$BWT]"; ls "$BWT" 2>&1; cat "$TMP/base.err" >&2; fail=$((fail+1))
fi

# ── start's fleet hint (Task 5): a line AFTER "agent: <name>", only when
# 2+ role-owned tasks are ready — a single-ready-task plan (the
# acceptance-1 fixture above) must keep printing exactly two lines
# (dispatch line + agent line), no third.
HR="$TMP/hint-repo"
mkdir -p "$HR"
( cd "${HR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$HR/plan.md" <<'EOF'
# Hint Feature Plan

## Tasks

### Task 1: build the alpha widget
- **Blocked by:** none
- [ ] **Files:** `alpha.js`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

### Task 2: build the beta widget
- **Blocked by:** none
- [ ] **Files:** `beta.js`
- [ ] **Command:** `true`
- **Owner:** frontend-developer
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${HR:?}" && git add -A && git commit -q -m init )
HOUT=$(bash "$TICKET" start "$HR/plan.md" 1 2>"$TMP/hint.err")
HLINES=$(printf '%s\n' "$HOUT" | wc -l | tr -d ' ')
if [ "$HLINES" -eq 3 ] && printf '%s\n' "$HOUT" | sed -n '3p' | grep -qF "fleet: rolepod-ticket fleet $HR/plan.md"; then
  echo "  ✓ start prints a fleet hint line when 2+ role-owned tasks are ready"
else
  echo "  ✗ start fleet-hint wrong: [$HOUT]"; cat "$TMP/hint.err" >&2; fail=$((fail+1))
fi

HOUT2=$(bash "$TICKET" start "$FR/plan.md" 1 2>>"$TMP/hint.err")
HLINES2=$(printf '%s\n' "$HOUT2" | wc -l | tr -d ' ')
if [ "$HLINES2" -eq 2 ]; then
  echo "  ✓ start prints no fleet hint when only one role-owned task is ready"
else
  echo "  ✗ start printed a hint with only one ready task: [$HOUT2]"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# integrate — acceptance 2 + R2 (never commits) + docs/rolepod exclusion
# ═══════════════════════════════════════════════════════════════════════

# ── green path: ok steps, <=40 lines, ends in the commit command, no commit made
IR="$TMP/integrate-repo"
mkrepo "$IR"
( cd "${IR:?}" && git worktree add -q -b task-branch "$TMP/integrate-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for \$IR/task-branch" >&2; exit 1; }
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
( cd "${PFR:?}" && git worktree add -q -b proof-branch "$TMP/proof-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for \$PFR/proof-branch" >&2; exit 1; }
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
( cd "${GTR:?}" && git worktree add -q -b gate-branch "$TMP/gate-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for \$GTR/gate-branch" >&2; exit 1; }
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
( cd "${PRR:?}" && git add -A && git commit -q -m "add render.txt" )
( cd "${PRR:?}" && git worktree add -q -b pre-branch-a "$TMP/pre-wt-a" ) \
  || { echo "ticket: fixture: git worktree add failed for \$PRR/pre-branch-a" >&2; exit 1; }
( cd "${PRR:?}" && git worktree add -q -b pre-branch-b "$TMP/pre-wt-b" ) \
  || { echo "ticket: fixture: git worktree add failed for \$PRR/pre-branch-b" >&2; exit 1; }
echo new > "$PRR/render.txt"
( cd "${PRR:?}" && git commit -aqm "advance base" )
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
( cd "${SR:?}" && git worktree add -q -b stage-branch "$TMP/stage-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for \$SR/stage-branch" >&2; exit 1; }
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
( cd "${AR:?}" && git worktree add -q -b ambig-branch "$TMP/ambig-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for \$AR/ambig-branch" >&2; exit 1; }
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
( cd "${FDR:?}" && git worktree add -q -b finish-dirty-branch "$TMP/finish-dirty-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for \$FDR/finish-dirty-branch" >&2; exit 1; }
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
( cd "${FVR:?}" && git worktree add -q -b finish-diverged-branch "$TMP/finish-diverged-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for \$FVR/finish-diverged-branch" >&2; exit 1; }
( cd "${FVR:?}" && git commit -q --allow-empty -m "base moves on" )
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
( cd "${FMR:?}" && git worktree add -q -b finish-merge-branch "$TMP/finish-merge-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for \$FMR/finish-merge-branch" >&2; exit 1; }
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

# ── log's ready-now line (chief-adoptions T2): who Task N just unblocked
cat > "$TMP/ready-a-plan.md" <<'EOF'
# Ready Plan A

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [x] **Files:** a.txt
- [x] **Command:** true
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** none
- [ ] **Files:** b.txt
- [ ] **Command:** true
- **Owner:** frontend-developer

### Task 3: gamma
- **Blocked by:** Task 1, Task 2
- [ ] **Files:** c.txt
- [ ] **Command:** true
- **Owner:** devops-sre

## Changes during build

## Follow-ups
EOF
OUT_A=$(bash "$TICKET" log "$TMP/ready-a-plan.md" 2 --sha bbb222 --note "beta done" 2>"$TMP/ready-a.err")
RC_A=$?
if [ "$RC_A" -eq 0 ] && printf '%s\n' "$OUT_A" | grep -qF "ready now: Task 3 (devops-sre)" \
  && printf '%s\n' "$OUT_A" | grep -qF "fleet: rolepod-ticket fleet $TMP/ready-a-plan.md"; then
  echo "  ✓ log prints ready now with owners and the fleet line"
else
  echo "  ✗ log ready-now-with-fleet wrong (rc=$RC_A): [$OUT_A]"; cat "$TMP/ready-a.err" >&2; fail=$((fail+1))
fi

cat > "$TMP/ready-b-plan.md" <<'EOF'
# Ready Plan B

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** a.txt
- [ ] **Command:** true
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** Task 1, Task 3
- [ ] **Files:** b.txt
- [ ] **Command:** true
- **Owner:** frontend-developer

### Task 3: gamma
- **Blocked by:** none
- [ ] **Files:** c.txt
- [ ] **Command:** true
- **Owner:** devops-sre

## Changes during build

## Follow-ups
EOF
OUT_B=$(bash "$TICKET" log "$TMP/ready-b-plan.md" 1 --sha ccc333 --note "alpha done" 2>"$TMP/ready-b.err")
RC_B=$?
if [ "$RC_B" -eq 0 ] && printf '%s\n' "$OUT_B" | grep -qF "ticket: log: Task 1 updated" \
  && ! printf '%s\n' "$OUT_B" | grep -q '^ready now:'; then
  echo "  ✓ log prints no ready line when nothing unblocks"
else
  echo "  ✗ log printed an unexpected ready line or failed (rc=$RC_B): [$OUT_B]"; cat "$TMP/ready-b.err" >&2; fail=$((fail+1))
fi

cat > "$TMP/ready-c-plan.md" <<'EOF'
# Ready Plan C

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** a.txt
- [ ] **Command:** true
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** Task 1
- [ ] **Files:** b.txt
- [ ] **Command:** true
- **Owner:** Lead

## Changes during build

## Follow-ups
EOF
OUT_C=$(bash "$TICKET" log "$TMP/ready-c-plan.md" 1 --sha ddd444 --note "alpha done" 2>"$TMP/ready-c.err")
RC_C=$?
if [ "$RC_C" -eq 0 ] && printf '%s\n' "$OUT_C" | grep -qF "ready now: Task 2 (Lead)" \
  && ! printf '%s\n' "$OUT_C" | grep -q '^fleet:'; then
  echo "  ✓ log names a Lead-owned task without the fleet line"
else
  echo "  ✗ log Lead-owned case wrong (rc=$RC_C): [$OUT_C]"; cat "$TMP/ready-c.err" >&2; fail=$((fail+1))
fi

# re-running the same log call prints the same ready-now lines, nothing else
OUT_A2=$(bash "$TICKET" log "$TMP/ready-a-plan.md" 2 --sha bbb222 --note "beta done" 2>"$TMP/ready-a2.err")
if [ "$OUT_A2" = "$OUT_A" ]; then
  echo "  ✓ log's ready-now line is idempotent — a re-run prints the same lines"
else
  echo "  ✗ log ready-now re-run differs: [$OUT_A2] vs [$OUT_A]"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# fleet — Task 5: two ready role-owned tasks, one blocked, one Owner: Lead
# ═══════════════════════════════════════════════════════════════════════

FLR="$TMP/fleet-repo"
mkdir -p "$FLR"
( cd "${FLR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$FLR/plan.md" <<'EOF'
# Fleet Feature Plan

## Tasks

### Task 1: build the alpha widget
- **Blocked by:** none
- [ ] **Files:** `alpha.js`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

### Task 2: build the beta widget
- **Blocked by:** none
- [ ] **Files:** `beta.js`
- [ ] **Command:** `true`
- **Owner:** frontend-developer
- **Done when:** true

### Task 3: build the gamma widget
- **Blocked by:** Task 1, Task 2
- [ ] **Files:** `gamma.js`
- [ ] **Command:** `true`
- **Owner:** devops-sre
- **Done when:** true

### Task 4: write the docs
- **Blocked by:** none
- [ ] **Files:** `README.md`
- [ ] **Command:** `true`
- **Owner:** Lead
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${FLR:?}" && git add -A && git commit -q -m init )

WT_BEFORE=$(git -C "$FLR" worktree list | wc -l | tr -d ' ')
OUT=$(bash "$TICKET" fleet "$FLR/plan.md" 2>"$TMP/fleet.err")
RC=$?
WT_AFTER=$(git -C "$FLR" worktree list | wc -l | tr -d ' ')
FLEET_JSON=$(printf '%s\n' "$OUT" | sed -n '1p')
FLEET_LAUNCH=$(printf '%s\n' "$OUT" | sed -n '2p')

if [ "$RC" -eq 0 ] && [ "$WT_AFTER" -eq $((WT_BEFORE + 2)) ]; then
  echo "  ✓ fleet exits 0 and creates exactly the two ready tasks' worktrees"
else
  echo "  ✗ fleet worktree count wrong (rc=$RC before=$WT_BEFORE after=$WT_AFTER)"; fail=$((fail+1))
  cat "$TMP/fleet.err" >&2
fi

if printf '%s\n' "$FLEET_JSON" | python3 -c '
import json, os, sys
data = json.load(sys.stdin)
assert "scriptPath" in data, "no scriptPath"
tasks = data["args"]["tasks"]
ns = sorted(t["n"] for t in tasks)
assert ns == [1, 2], "expected tasks [1, 2], got %r" % (ns,)
for t in tasks:
    assert t["reviewers"] == ["universal-reviewer"], t
    assert os.path.isdir(t["worktree"]), "no worktree dir: %r" % t["worktree"]
    assert os.path.isfile(t["brief"]), "no brief file: %r" % t["brief"]
    assert t["role"] in ("backend-developer", "frontend-developer"), t["role"]
' 2>"$TMP/fleet-json.err"; then
  echo "  ✓ fleet JSON holds exactly the two ready role-owned tasks, worktrees + reviewers from each brief"
else
  echo "  ✗ fleet JSON wrong: $FLEET_JSON"; cat "$TMP/fleet-json.err" >&2; fail=$((fail+1))
fi

if printf '%s\n' "$FLEET_LAUNCH" | grep -qi 'launch'; then
  echo "  ✓ fleet prints one line on how to launch the script after the JSON"
else
  echo "  ✗ fleet did not print a launch line: [$FLEET_LAUNCH]"; fail=$((fail+1))
fi

# ── fleet rerun on FLR — both tasks just launched above are now in flight:
# skipped by name, no JSON, worktree count unchanged (chief-adoptions T1)
WT_RERUN_BEFORE=$(git -C "$FLR" worktree list | wc -l | tr -d ' ')
OUT=$(bash "$TICKET" fleet "$FLR/plan.md" 2>"$TMP/fleet-rerun.err")
RC=$?
WT_RERUN_AFTER=$(git -C "$FLR" worktree list | wc -l | tr -d ' ')
if [ "$RC" -eq 0 ] && [ "$WT_RERUN_AFTER" = "$WT_RERUN_BEFORE" ] \
  && ! printf '%s\n' "$OUT" | sed -n '1p' | grep -q '^{' \
  && printf '%s\n' "$OUT" | grep -qi 'in flight.*Task 1' \
  && printf '%s\n' "$OUT" | grep -qi 'in flight.*Task 2'; then
  echo "  ✓ fleet rerun: in-flight tasks skipped, no JSON entry"
else
  echo "  ✗ fleet rerun wrong (rc=$RC before=$WT_RERUN_BEFORE after=$WT_RERUN_AFTER): $OUT"; fail=$((fail+1))
  cat "$TMP/fleet-rerun.err" >&2
fi

# ═══════════════════════════════════════════════════════════════════════
# fleet --gate — a red base gate refuses before any worktree is created;
# a green gate behaves exactly like no --gate at all (chief-adoptions T1)
# ═══════════════════════════════════════════════════════════════════════

FGTR="$TMP/fleet-gate-repo"
mkdir -p "$FGTR"
( cd "${FGTR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$FGTR/plan.md" <<'EOF'
# Gate Feature Plan

## Tasks

### Task 1: build the alpha widget
- **Blocked by:** none
- [ ] **Files:** `alpha.js`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

### Task 2: build the beta widget
- **Blocked by:** none
- [ ] **Files:** `beta.js`
- [ ] **Command:** `true`
- **Owner:** frontend-developer
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${FGTR:?}" && git add -A && git commit -q -m init )

WT_GATE_BEFORE=$(git -C "$FGTR" worktree list | wc -l | tr -d ' ')
OUT=$(bash "$TICKET" fleet "$FGTR/plan.md" --gate 'echo gate-boom-line; false' 2>"$TMP/gate-red.err")
RC=$?
WT_GATE_AFTER=$(git -C "$FGTR" worktree list | wc -l | tr -d ' ')
if [ "$RC" -eq 1 ] && [ "$WT_GATE_AFTER" = "$WT_GATE_BEFORE" ] \
  && printf '%s\n' "$OUT" | grep -qi 'base gate red' \
  && printf '%s\n' "$OUT" | grep -qF 'gate-boom-line'; then
  echo "  ✓ fleet --gate red: exit 1, no worktree created"
else
  echo "  ✗ fleet --gate red wrong (rc=$RC before=$WT_GATE_BEFORE after=$WT_GATE_AFTER): $OUT"; fail=$((fail+1))
  cat "$TMP/gate-red.err" >&2
fi

OUT=$(bash "$TICKET" fleet "$FGTR/plan.md" --gate 'echo should-not-leak; true' 2>"$TMP/gate-green.err")
RC=$?
WT_GATE_GREEN_AFTER=$(git -C "$FGTR" worktree list | wc -l | tr -d ' ')
GREEN_JSON=$(printf '%s\n' "$OUT" | sed -n '1p')
GREEN_LAUNCH=$(printf '%s\n' "$OUT" | sed -n '2p')
if [ "$RC" -eq 0 ] && [ "$WT_GATE_GREEN_AFTER" -eq $((WT_GATE_BEFORE + 2)) ] \
  && printf '%s\n' "$GREEN_JSON" | python3 -c '
import json, sys
data = json.load(sys.stdin)
ns = sorted(t["n"] for t in data["args"]["tasks"])
assert ns == [1, 2], ns
' 2>"$TMP/gate-green-json.err" \
  && printf '%s\n' "$GREEN_LAUNCH" | grep -qi 'launch' \
  && ! printf '%s\n' "$OUT" | grep -qF 'should-not-leak'; then
  echo "  ✓ fleet --gate green: same output as without the flag"
else
  echo "  ✗ fleet --gate green wrong (rc=$RC after=$WT_GATE_GREEN_AFTER): $OUT"; fail=$((fail+1))
  cat "$TMP/gate-green.err" "$TMP/gate-green-json.err" >&2 2>/dev/null
fi

# ═══════════════════════════════════════════════════════════════════════
# fleet --max — keeps only the first N ready tasks in plan order and holds
# the rest back by name without ever creating their worktree; --max 0 is a
# usage error (chief-adoptions T1)
# ═══════════════════════════════════════════════════════════════════════

MXR="$TMP/max-repo"
mkdir -p "$MXR"
( cd "${MXR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$MXR/plan.md" <<'EOF'
# Max Feature Plan

## Tasks

### Task 1: build the alpha widget
- **Blocked by:** none
- [ ] **Files:** `alpha.js`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

### Task 2: build the beta widget
- **Blocked by:** none
- [ ] **Files:** `beta.js`
- [ ] **Command:** `true`
- **Owner:** frontend-developer
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${MXR:?}" && git add -A && git commit -q -m init )

WT_MAX_BEFORE=$(git -C "$MXR" worktree list | wc -l | tr -d ' ')
OUT=$(bash "$TICKET" fleet "$MXR/plan.md" --max 1 2>"$TMP/fleet-max.err")
RC=$?
WT_MAX_AFTER=$(git -C "$MXR" worktree list | wc -l | tr -d ' ')
if [ "$RC" -eq 0 ] && [ "$WT_MAX_AFTER" -eq $((WT_MAX_BEFORE + 1)) ] \
  && printf '%s\n' "$OUT" | sed -n '1p' | python3 -c '
import json, sys
data = json.load(sys.stdin)
ns = sorted(t["n"] for t in data["args"]["tasks"])
assert ns == [1], ns
' 2>"$TMP/fleet-max-json.err" \
  && printf '%s\n' "$OUT" | grep -qi 'held back.*Task 2'; then
  echo "  ✓ fleet --max 1: one worktree, the other held back"
else
  echo "  ✗ fleet --max 1 wrong (rc=$RC before=$WT_MAX_BEFORE after=$WT_MAX_AFTER): $OUT"; fail=$((fail+1))
  cat "$TMP/fleet-max.err" "$TMP/fleet-max-json.err" >&2 2>/dev/null
fi

# ── mixed run on the same repo: Task 1 (started above) is now in flight
# and skipped, Task 2 (held back above) is remaining and starts — proves
# the in-flight line prints AFTER the launch line even when this same run
# also starts a task, not just in the all-in-flight/all-fresh extremes.
WT_MIX_BEFORE=$(git -C "$MXR" worktree list | wc -l | tr -d ' ')
OUT=$(bash "$TICKET" fleet "$MXR/plan.md" 2>"$TMP/fleet-mix.err")
RC=$?
WT_MIX_AFTER=$(git -C "$MXR" worktree list | wc -l | tr -d ' ')
MIX_LINE1=$(printf '%s\n' "$OUT" | sed -n '1p')
MIX_LINE2=$(printf '%s\n' "$OUT" | sed -n '2p')
MIX_LINE3=$(printf '%s\n' "$OUT" | sed -n '3p')
if [ "$RC" -eq 0 ] && [ "$WT_MIX_AFTER" -eq $((WT_MIX_BEFORE + 1)) ] \
  && printf '%s\n' "$MIX_LINE1" | python3 -c '
import json, sys
data = json.load(sys.stdin)
ns = sorted(t["n"] for t in data["args"]["tasks"])
assert ns == [2], ns
' 2>"$TMP/fleet-mix-json.err" \
  && printf '%s\n' "$MIX_LINE2" | grep -qi 'launch' \
  && [ "$MIX_LINE3" = "in flight — skipped: Task 1" ]; then
  echo "  ✓ fleet mixed run: in-flight task named after the launch line, remaining task started"
else
  echo "  ✗ fleet mixed run wrong (rc=$RC before=$WT_MIX_BEFORE after=$WT_MIX_AFTER): $OUT"; fail=$((fail+1))
  cat "$TMP/fleet-mix.err" "$TMP/fleet-mix-json.err" >&2 2>/dev/null
fi

OUT=$(bash "$TICKET" fleet "$MXR/plan.md" --max 0 2>"$TMP/fleet-max0.err")
RC=$?
if [ "$RC" -eq 2 ] && grep -qi 'positive integer' "$TMP/fleet-max0.err"; then
  echo "  ✓ fleet --max 0: usage error"
else
  echo "  ✗ fleet --max 0 should be a usage error naming a positive integer (rc=$RC): $OUT"; fail=$((fail+1))
  cat "$TMP/fleet-max0.err" >&2
fi

# ── an Owner-less task refuses BEFORE any `start` in the same run, even
# one that comes after a task with a real role in plan order — the role
# check must not strand an earlier task's just-created worktree (round-2
# review finding on chief-adoptions T1).
ORR="$TMP/owner-refused-repo"
mkdir -p "$ORR"
( cd "${ORR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$ORR/plan.md" <<'EOF'
# Owner Refused Feature Plan

## Tasks

### Task 1: build the alpha widget
- **Blocked by:** none
- [ ] **Files:** `alpha.js`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

### Task 2: build the beta widget
- **Blocked by:** none
- [ ] **Files:** `beta.js`
- [ ] **Command:** `true`
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${ORR:?}" && git add -A && git commit -q -m init )

WT_ORR_BEFORE=$(git -C "$ORR" worktree list | wc -l | tr -d ' ')
OUT=$(bash "$TICKET" fleet "$ORR/plan.md" 2>"$TMP/fleet-orr.err")
RC=$?
WT_ORR_AFTER=$(git -C "$ORR" worktree list | wc -l | tr -d ' ')
if [ "$RC" -eq 1 ] && [ "$WT_ORR_AFTER" = "$WT_ORR_BEFORE" ] && grep -qi 'Task 2 has no Owner' "$TMP/fleet-orr.err"; then
  echo "  ✓ fleet refuses an Owner-less task before start ever runs for its plan-order sibling: no worktree stranded"
else
  echo "  ✗ fleet Owner-less refusal wrong (rc=$RC before=$WT_ORR_BEFORE after=$WT_ORR_AFTER): $OUT"; fail=$((fail+1))
  cat "$TMP/fleet-orr.err" >&2
fi

# ── a later `start` failure rolls back ONLY what this run created. Task 1
# is fresh (worktree + branch rolled back). Task 2 has a pre-existing branch
# whose short name a remote ref shares, so for-each-ref would print it as
# "heads/<br>" (worktree rolled back, branch KEPT). Task 3 has a pre-existing
# worktree whose handoff is gone, so it is not seen as in flight and start
# reprints it (KEPT). Task 4's path is a plain non-empty dir and it has no
# branch: `worktree add -b` fails and must not leave its new branch behind.
SFR="$TMP/start-fail-repo"
mkdir -p "$SFR"
( cd "${SFR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$SFR/plan.md" <<'EOF'
# Start Fail Feature Plan

## Tasks

### Task 1: build the alpha widget
- **Blocked by:** none
- [ ] **Files:** `alpha.js`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

### Task 2: build the beta widget
- **Blocked by:** none
- [ ] **Files:** `beta.js`
- [ ] **Command:** `true`
- **Owner:** frontend-developer
- **Done when:** true

### Task 3: build the gamma widget
- **Blocked by:** none
- [ ] **Files:** `gamma.js`
- [ ] **Command:** `true`
- **Owner:** devops-sre
- **Done when:** true

### Task 4: build the delta widget
- **Blocked by:** none
- [ ] **Files:** `delta.js`
- [ ] **Command:** `true`
- **Owner:** data-scientist
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${SFR:?}" && git add -A && git commit -q -m init )
SF_T2_WT="$(bash "$TICKET" start "$SFR/plan.md" 2 2>/dev/null | sed -n '1p' | awk '{print $2}')"
SF_T2_BR="$(git -C "$SF_T2_WT" symbolic-ref --quiet --short HEAD 2>/dev/null)"
git -C "$SFR" worktree remove "$SF_T2_WT"
git -C "$SFR" update-ref "refs/remotes/$SF_T2_BR" HEAD
SF_T3_OUT="$(bash "$TICKET" start "$SFR/plan.md" 3 2>/dev/null | sed -n '1p')"
SF_T3_WT="$(printf '%s' "$SF_T3_OUT" | awk '{print $2}')"
rm -f "$(printf '%s' "$SF_T3_OUT" | awk '{print $1}')"
SF_T4_WT="$(bash "$TICKET" start "$SFR/plan.md" 4 2>/dev/null | sed -n '1p' | awk '{print $2}')"
SF_T4_BR="$(git -C "$SF_T4_WT" symbolic-ref --quiet --short HEAD 2>/dev/null)"
git -C "$SFR" worktree remove "$SF_T4_WT"
git -C "$SFR" branch -D "$SF_T4_BR" >/dev/null
mkdir -p "$SF_T4_WT" && : > "$SF_T4_WT/occupied"
SF_BRANCHES_BEFORE=$(git -C "$SFR" branch --list | wc -l | tr -d ' ')
WT_SF_BEFORE=$(git -C "$SFR" worktree list | wc -l | tr -d ' ')
OUT=$(bash "$TICKET" fleet "$SFR/plan.md" 2>"$TMP/fleet-sf.err")
RC=$?
WT_SF_AFTER=$(git -C "$SFR" worktree list | wc -l | tr -d ' ')
SF_BRANCHES_AFTER=$(git -C "$SFR" branch --list | wc -l | tr -d ' ')
if [ -n "$SF_T2_BR" ] && [ -n "$SF_T3_WT" ] && [ -n "$SF_T4_BR" ] && [ "$RC" -eq 1 ] \
  && [ "$WT_SF_AFTER" = "$WT_SF_BEFORE" ] && [ "$SF_BRANCHES_AFTER" = "$SF_BRANCHES_BEFORE" ] \
  && git -C "$SFR" show-ref --verify --quiet "refs/heads/$SF_T2_BR" \
  && ! git -C "$SFR" show-ref --verify --quiet "refs/heads/$SF_T4_BR" \
  && git -C "$SFR" worktree list --porcelain | grep -qxF "worktree $SF_T3_WT" \
  && grep -q 'start failed for Task 4' "$TMP/fleet-sf.err" \
  && grep -q 'rolled back.*Task 1, Task 2' "$TMP/fleet-sf.err"; then
  echo "  ✓ fleet start failure: rolls back only this run's worktrees + new branches; pre-existing branch and worktree kept"
else
  echo "  ✗ fleet start-failure rollback wrong (rc=$RC wt ${WT_SF_BEFORE}->${WT_SF_AFTER} branches ${SF_BRANCHES_BEFORE}->${SF_BRANCHES_AFTER}): $OUT"; fail=$((fail+1))
  cat "$TMP/fleet-sf.err" >&2
fi

# ── rollback never forces: a worktree this run created but that is dirty
# (a post-checkout hook drops an untracked file) is kept and reported.
# core.hooksPath pinned locally — a global hooksPath would skip .git/hooks.
DFR="$TMP/dirty-rollback-repo"
mkdir -p "$DFR"
( cd "${DFR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$DFR/plan.md" <<'EOF'
# Dirty Rollback Feature Plan

## Tasks

### Task 1: build the alpha widget
- **Blocked by:** none
- [ ] **Files:** `alpha.js`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

### Task 2: build the beta widget
- **Blocked by:** none
- [ ] **Files:** `beta.js`
- [ ] **Command:** `true`
- **Owner:** frontend-developer
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${DFR:?}" && git add -A && git commit -q -m init )
DF_T2_WT="$(bash "$TICKET" start "$DFR/plan.md" 2 2>/dev/null | sed -n '1p' | awk '{print $2}')"
git -C "$DFR" worktree remove "$DF_T2_WT"
mkdir -p "$DF_T2_WT" && : > "$DF_T2_WT/occupied"
mkdir -p "$DFR/.git/hooks"
printf '#!/bin/sh\n: > stray.txt\n' > "$DFR/.git/hooks/post-checkout"
chmod +x "$DFR/.git/hooks/post-checkout"
git -C "$DFR" config core.hooksPath "$DFR/.git/hooks"
WT_DF_BEFORE=$(git -C "$DFR" worktree list | wc -l | tr -d ' ')
OUT=$(bash "$TICKET" fleet "$DFR/plan.md" 2>"$TMP/fleet-df.err")
RC=$?
WT_DF_AFTER=$(git -C "$DFR" worktree list | wc -l | tr -d ' ')
if [ -n "$DF_T2_WT" ] && [ "$RC" -eq 1 ] && [ "$WT_DF_AFTER" -eq $((WT_DF_BEFORE + 1)) ] \
  && grep -q 'could not roll back' "$TMP/fleet-df.err"; then
  echo "  ✓ fleet rollback never forces: a dirty worktree is kept and reported"
else
  echo "  ✗ fleet dirty-rollback wrong (rc=$RC wt ${WT_DF_BEFORE}->${WT_DF_AFTER}): $OUT"; fail=$((fail+1))
  cat "$TMP/fleet-df.err" >&2
fi

# ── no ready role-owned task → says so, exit 0, nothing created
NRR="$TMP/no-ready-repo"
mkdir -p "$NRR"
( cd "${NRR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$NRR/plan.md" <<'EOF'
# No Ready Feature Plan

## Tasks

### Task 1: write the docs
- **Blocked by:** none
- [ ] **Files:** `README.md`
- [ ] **Command:** `true`
- **Owner:** Lead
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${NRR:?}" && git add -A && git commit -q -m init )
WT_NR_BEFORE=$(git -C "$NRR" worktree list | wc -l | tr -d ' ')
OUT=$(bash "$TICKET" fleet "$NRR/plan.md" 2>"$TMP/no-ready.err")
RC=$?
WT_NR_AFTER=$(git -C "$NRR" worktree list | wc -l | tr -d ' ')
if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -qi 'no ready' && [ "$WT_NR_AFTER" = "$WT_NR_BEFORE" ]; then
  echo "  ✓ fleet with no ready role-owned task: exit 0, says so, creates nothing"
else
  echo "  ✗ fleet no-ready handling wrong (rc=$RC): $OUT"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# fleet — a Test / evidence sentence quoting a field's own words is prose,
# never the field itself (ROOT CAUSE: substring-anywhere field detection)
# ═══════════════════════════════════════════════════════════════════════

PRW="$TMP/prose-repo"
mkdir -p "$PRW"
( cd "${PRW:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$PRW/plan.md" <<'EOF'
# Prose Feature Plan

## Tasks

### Task 1: build the widget
- **Blocked by:** none
- [ ] **Files:** `widget.txt`
- [ ] **Test / evidence:** confirm the note does not say Blocked by: Task 9 anywhere
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${PRW:?}" && git add -A && git commit -q -m init )
OUT=$(bash "$TICKET" fleet "$PRW/plan.md" 2>"$TMP/prose.err")
RC=$?
if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | sed -n '1p' | python3 -c '
import json, sys
data = json.load(sys.stdin)
ns = sorted(t["n"] for t in data["args"]["tasks"])
assert ns == [1], "expected [1], got %r" % (ns,)
' 2>"$TMP/prose-json.err"; then
  echo "  ✓ fleet lists a ready task whose Test / evidence prose quotes a field's own words"
else
  echo "  ✗ fleet false-blocker parse wrong (rc=$RC): $OUT"; cat "$TMP/prose.err" "$TMP/prose-json.err" >&2; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# fleet — an em-dash aside with no parens must not feed its digits into the
# Blocked-by graph (T2 follow-up, mirrored from plan-lint.sh)
# ═══════════════════════════════════════════════════════════════════════

EDR="$TMP/em-dash-repo"
mkdir -p "$EDR"
( cd "${EDR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$EDR/plan.md" <<'EOF'
# Em Dash Aside Plan

## Tasks

### Task 3: c
- **Blocked by:** none
- [x] **Files:** `c.txt`
- [x] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

### Task 4: d
- **Blocked by:** Task 3 — landed in v2.90.0
- [ ] **Files:** `d.txt`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${EDR:?}" && git add -A && git commit -q -m init )
OUT=$(bash "$TICKET" fleet "$EDR/plan.md" 2>"$TMP/em-dash.err")
RC=$?
if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | sed -n '1p' | python3 -c '
import json, sys
data = json.load(sys.stdin)
ns = sorted(t["n"] for t in data["args"]["tasks"])
assert ns == [4], "expected [4] (Task 3 is [x] and Task 4'"'"'s only real blocker), got %r" % (ns,)
' 2>"$TMP/em-dash-json.err"; then
  echo "  ✓ fleet reads Task 3 — landed in v2.90.0 as blocker {3} only, ready once Task 3 is done"
else
  echo "  ✗ fleet read digits out of an em-dash aside (rc=$RC): $OUT"; cat "$TMP/em-dash.err" "$TMP/em-dash-json.err" >&2; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# fleet — Blocked by: None (any case) is no blockers, same as plan-lint.sh
# ═══════════════════════════════════════════════════════════════════════

NCR="$TMP/none-case-repo"
mkdir -p "$NCR"
( cd "${NCR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$NCR/plan.md" <<'EOF'
# None Case Plan

## Tasks

### Task 1: a
- **Blocked by:** None
- [ ] **Files:** `a.txt`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

## Parallel layout
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${NCR:?}" && git add -A && git commit -q -m init )
OUT=$(bash "$TICKET" fleet "$NCR/plan.md" 2>"$TMP/none-case.err")
RC=$?
if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | sed -n '1p' | python3 -c '
import json, sys
data = json.load(sys.stdin)
ns = sorted(t["n"] for t in data["args"]["tasks"])
assert ns == [1], "expected [1], got %r" % (ns,)
' 2>"$TMP/none-case-json.err"; then
  echo "  ✓ fleet treats Blocked by: None as no blockers"
else
  echo "  ✗ fleet did not treat None as no blockers (rc=$RC): $OUT"; cat "$TMP/none-case.err" "$TMP/none-case-json.err" >&2; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# start/finish — the Agent: line start appends and finish reads back
# ═══════════════════════════════════════════════════════════════════════

AGR="$TMP/agent-repo"
mkrepo "$AGR"
cat > "$AGR/plan.md" <<'EOF'
# Agent Feature Plan

## Tasks

### Task 1: build the widget
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
( cd "${AGR:?}" && git add -A && git commit -q -m "add plan" )
AG_OUT=$(bash "$TICKET" start "$AGR/plan.md" 1 2>"$TMP/agent.err")
AG_LINE1=$(printf '%s\n' "$AG_OUT" | sed -n '1p')
AG_BRIEF=$(printf '%s\n' "$AG_LINE1" | awk '{print $1}')
AG_WT=$(printf '%s\n' "$AG_LINE1" | awk '{print $2}')
if grep -qE '^Agent: owner-plan-t1$' "$AG_BRIEF"; then
  echo "  ✓ start appends an Agent: <name> line to the brief"
else
  echo "  ✗ start did not append the expected Agent: line"; cat "$AG_BRIEF" >&2; fail=$((fail+1))
fi
( cd "${AG_WT:?}" && git commit -q --allow-empty -m "the owner's real commit" )
AG_FIN=$(bash "$TICKET" finish "$AG_WT" 2>&1)
if printf '%s\n' "$AG_FIN" | grep -qF 'close: owner-plan-t1'; then
  echo "  ✓ finish prints close: <agent> for the name start recorded"
else
  echo "  ✗ finish did not report the recorded agent name: $AG_FIN"; fail=$((fail+1))
fi

# -t1 vs -t11: a second task on the SAME plan whose id is a digit-suffix of
# the first (Task 11) must resolve `finish` to ITS OWN agent name, never the
# other's, even though "-t1" is a literal substring of "-t11".
AGR11="$TMP/agent-repo-11"
mkrepo "$AGR11"
{
  printf '%s\n\n## Tasks\n\n' "# Agent Collision Plan"
  printf '### Task 1: build the widget\n- **Blocked by:** none\n- [ ] **Files:** `widget.txt`\n- [ ] **Command:** `true`\n- **Owner:** backend-developer\n- **Done when:** true\n\n'
  i=2
  while [ "$i" -le 10 ]; do
    printf '### Task %s: filler %s\n- **Blocked by:** none\n- [ ] **Files:** `f%s.txt`\n- [ ] **Command:** `true`\n- **Owner:** backend-developer\n- **Done when:** true\n\n' "$i" "$i" "$i"
    i=$((i+1))
  done
  printf '### Task 11: build the other widget\n- **Blocked by:** none\n- [ ] **Files:** `widget11.txt`\n- [ ] **Command:** `true`\n- **Owner:** backend-developer\n- **Done when:** true\n\n'
  printf '## Parallel layout\nSequential — single owner.\n\n## Failure policy\nDefault: stop after 2 failed attempts (never a 4th).\n'
} > "$AGR11/plan.md"
( cd "${AGR11:?}" && git add -A && git commit -q -m "add plan" )
AG11_OUT_1=$(bash "$TICKET" start "$AGR11/plan.md" 1 2>"$TMP/agent11-1.err")
AG11_OUT_11=$(bash "$TICKET" start "$AGR11/plan.md" 11 2>"$TMP/agent11-11.err")
AG11_WT_1=$(printf '%s\n' "$AG11_OUT_1" | sed -n '1p' | awk '{print $2}')
AG11_WT_11=$(printf '%s\n' "$AG11_OUT_11" | sed -n '1p' | awk '{print $2}')
( cd "${AG11_WT_1:?}" && git commit -q --allow-empty -m "task 1 commit" )
AG11_FIN_1=$(bash "$TICKET" finish "$AG11_WT_1" 2>&1)
if printf '%s\n' "$AG11_FIN_1" | grep -qF 'close: owner-plan-t1'; then
  echo "  ✓ finish resolves Task 1's own agent name, not Task 11's, despite the -t1/-t11 substring overlap"
else
  echo "  ✗ finish collided -t1 with -t11: $AG11_FIN_1"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# log — dedupe is scoped to ## Changes during build; a look-alike line
# elsewhere in the plan never blocks a real append; a backslash survives
# ═══════════════════════════════════════════════════════════════════════

cat > "$TMP/log-plan2.md" <<'EOF'
# Log Plan Two

## Tasks

### Task 1: alpha
- [ ] Files: a.txt
- [ ] Test / evidence: the follow-up note reads "- Task 1 (`zz9999`): did the thing"
- [ ] Command: true

## Changes during build

## Follow-ups
EOF
bash "$TICKET" log "$TMP/log-plan2.md" 1 --sha zz9999 --note "did the thing" >/dev/null
IN_SECTION=$(awk '/^## Changes during build/{f=1;next} /^## /{f=0} f' "$TMP/log-plan2.md" | grep -cF -- '- Task 1 (`zz9999`): did the thing')
if [ "$IN_SECTION" -eq 1 ]; then
  echo "  ✓ log appends the real bullet even when a look-alike line sits elsewhere in the plan"
else
  echo "  ✗ log skipped the append because of the unrelated look-alike line (found=$IN_SECTION)"; fail=$((fail+1))
fi

bash "$TICKET" log "$TMP/log-plan.md" 2 --sha bs0001 --note 'a\b' >/dev/null
if grep -qF -- '- Task 2 (`bs0001`): a\b' "$TMP/log-plan.md"; then
  echo "  ✓ log writes a note holding a backslash byte-for-byte"
else
  echo "  ✗ log mangled a backslash in the note"; grep -F 'bs0001' "$TMP/log-plan.md" >&2; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# a value flag given last with no value is a usage error, never a hang:
# `shift 2` with one arg left fails without shifting, so the parser looped
# forever. perl's alarm bounds each run (macOS ships no `timeout`).
# ═══════════════════════════════════════════════════════════════════════

for flagcase in "start|$TMP/none.md|1|--base" "integrate|$TMP/none-wt|--brief" \
  "integrate|$TMP/none-wt|--pre" "integrate|$TMP/none-wt|--gate" \
  "log|$TMP/none.md|1|--sha" "log|$TMP/none.md|1|--note" \
  "fleet|$TMP/none.md|--base" "fleet|$TMP/none.md|--gate"; do
  oldifs="$IFS"; IFS='|'; set -- $flagcase; IFS="$oldifs"
  OUT=$(perl -e 'alarm 10; exec @ARGV or die' bash "$TICKET" "$@" 2>&1)
  RC=$?
  last="${!#}"
  if [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -qF -- "$last needs a value"; then
    echo "  ✓ $1 $last with no value: usage error, exit 2, no hang"
  else
    echo "  ✗ $1 $last with no value: rc=$RC (142 = hung until the alarm): $OUT"; fail=$((fail+1))
  fi
done

# ═══════════════════════════════════════════════════════════════════════
# the real repo's HEAD and worktree registry stayed untouched — unconditional:
# a fixture write that lands on the real repo instead of its own $TMP fixture
# must never go unnoticed (2026-09-22: 4b6c061f, b258f2b9 — see the header).
# ═══════════════════════════════════════════════════════════════════════

REAL_HEAD_AFTER="$(git -C "$REPO_DIR" rev-parse HEAD)"
if [ "$REAL_HEAD_AFTER" = "$REAL_HEAD_BEFORE" ]; then
  echo "  ✓ the real repo's HEAD stayed at $REAL_HEAD_BEFORE — no fixture commit leaked onto main"
else
  echo "  ✗ the real repo's HEAD moved $REAL_HEAD_BEFORE -> $REAL_HEAD_AFTER during this run — leaked commit: $(git -C "$REPO_DIR" log -1 --format='%h %s' "$REAL_HEAD_AFTER")"
  fail=$((fail+1))
fi

REAL_WORKTREES_AFTER="$(git -C "$REPO_DIR" worktree list --porcelain)"
if [ "$REAL_WORKTREES_AFTER" = "$REAL_WORKTREES_BEFORE" ]; then
  echo "  ✓ the real repo's worktree registry is unchanged"
else
  echo "  ✗ the real repo's worktree registry changed during this run — a fixture worktree registered against the real repo"
  fail=$((fail+1))
fi

if [ "$fail" -eq 0 ]; then
  echo "ticket: PASS"
else
  echo "ticket: FAIL ($fail)"
fi
exit "$fail"
