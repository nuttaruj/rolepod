#!/bin/bash
# ticket — proves implement-plan's scripts/ticket.sh start/integrate/finish/log against
# fixture repos, per spec lead-cost-no-pause-2026-09-22 acceptance 1-3 + R2
# (integrate never commits) + R1 (idempotent, fail-closed). Each fixture is
# its own throwaway git repo so no scenario leaks state into another.
set -uo pipefail

fail=0
TMP=$(mktemp -d)
[ -n "$TMP" ] && [ -d "$TMP" ] || { echo "ticket: mktemp -d failed — refusing to run fixtures against an unresolved \$TMP" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TICKET="$REPO_DIR/core/skills/implement-plan/scripts/ticket.sh"

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

# Isolation: the run's cwd is a throwaway repo under $TMP, never the real
# checkout, so a `cd "$EMPTY_VAR"` that no-ops after a failed `start` lands a
# stray commit in the guard repo, not on the real main (the e5d4d6a5 leak).
GUARD="$TMP/cwd-guard"
mkrepo "$GUARD"
cd "$GUARD" || { echo "ticket: cannot enter the guard repo $GUARD" >&2; exit 1; }

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
A per-task worktree fixture: the first line is not "Sequential", so start builds a task worktree.
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${FR:?}" && git add -A && git commit -q -m init )

# ticket.sh resolves the base checkout through `git rev-parse --show-toplevel`
# (canonical, symlinks resolved), while $FR itself is the raw mktemp path —
# on macOS /var/folders/... is a symlink to /private/var/folders/..., so the
# two differ in exactly the ship line's --sha base-checkout argument.
FR_REAL="$(git -C "$FR" rev-parse --show-toplevel)"

OUT=$(bash "$TICKET" start "$FR/plan.md" 1 2>"$TMP/start.err")
RC=$?
LINE1=$(printf '%s\n' "$OUT" | sed -n '1p')
AGENT_LINE=$(printf '%s\n' "$OUT" | sed -n '2p')
SHIP_LINE=$(printf '%s\n' "$OUT" | sed -n '3p')
BRIEF_PATH=$(printf '%s\n' "$LINE1" | awk '{print $1}')
WT_PATH=$(printf '%s\n' "$LINE1" | awk '{print $2}')
NFIELDS=$(printf '%s\n' "$LINE1" | awk '{print NF}')

# Done when: line 1 stays exactly two paths (brief, worktree); the agent
# name (needed by `finish`'s "close: <agent>") lands as its own line 2
# "agent: <name>", never a third token that would break NFIELDS. Line 3 is
# the ONE ship call (spec lean-loop-2026-09-23 Task 2) — integrate through
# git -C's commit, finish and log, <commit gate>/<subject>/<note> left for
# the Lead.
if [ "$RC" -eq 0 ] && [ "$NFIELDS" -eq 2 ] \
  && [ -f "$BRIEF_PATH" ] && [ -d "$WT_PATH" ] \
  && [[ "$AGENT_LINE" == agent:\ * ]] \
  && [[ "$SHIP_LINE" == "ship: bash '$TICKET' integrate '$WT_PATH' --brief '$BRIEF_PATH'"* ]] \
  && printf '%s\n' "$SHIP_LINE" | grep -qF "git -C '$WT_PATH' commit -m '<subject>'" \
  && printf '%s\n' "$SHIP_LINE" | grep -qF "bash '$TICKET' finish '$WT_PATH'" \
  && printf '%s\n' "$SHIP_LINE" | grep -qF "bash '$TICKET' log '$FR/plan.md' 1 --sha" \
  && printf '%s\n' "$SHIP_LINE" | grep -qF "git -C '$FR_REAL' rev-parse --short HEAD" \
  && printf '%s\n' "$SHIP_LINE" | grep -qF -- "--note '<note>'"; then
  echo "  ✓ start prints line 1 (brief, worktree), line 2 'agent: <name>', line 3 the ship chain"
else
  echo "  ✗ start dispatch lines wrong: rc=$RC nfields=$NFIELDS line1=[$LINE1] agent=[$AGENT_LINE] ship=[$SHIP_LINE]"; fail=$((fail+1))
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
A per-task worktree fixture: the first line is not "Sequential", so start builds a task worktree.
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

# ── start prints exactly four lines (dispatch + agent + ship + task file),
# never a fifth — `rolepod-ticket fleet` is gone (v2.179.0); start never hints it.
HOUT2=$(bash "$TICKET" start "$FR/plan.md" 1 2>>"$TMP/start.err")
HLINES2=$(printf '%s\n' "$HOUT2" | wc -l | tr -d ' ')
if [ "$HLINES2" -eq 4 ] && [ "$(printf '%s\n' "$HOUT2" | sed -n '4p')" = "task file: $(git -C "$FR" rev-parse --show-toplevel)/docs/rolepod/tasks/plan/task-01.md" ]; then
  echo "  ✓ start prints exactly four lines (the last names the task file), no fleet hint"
else
  echo "  ✗ start printed an unexpected line count: [$HOUT2]"; fail=$((fail+1))
fi
SK_FILE="$(git -C "$FR" rev-parse --show-toplevel)/docs/rolepod/tasks/plan/task-01.md"
SK_BRIEF="$(printf '%s\n' "$HOUT2" | awk '{print $1; exit}')"
if grep -qxF -- '- Delta H1→H2: <changed paths + delta hash>' "$SK_FILE" \
  && grep -qxF -- '- H2: <verified snapshot after the fixes>' "$SK_FILE" \
  && grep -q '^Workflow mode: ' "$SK_BRIEF"; then
  echo "  ✓ start skeleton carries the H1→H2 / H2 closure fields and the brief prints its Workflow mode"
else
  echo "  ✗ start skeleton / brief mode line missing: $SK_FILE $SK_BRIEF"; fail=$((fail+1))
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
`false`
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
  && ! printf '%s\n' "$OUT" | grep -q '^command:' \
  && printf '%s\n' "$OUT" | grep -q '^proof: ok' \
  && printf '%s\n' "$OUT" | tail -1 | grep -q 'commit -m'; then
  echo "  ✓ integrate green path: a false Command still passes (never run), <=40 lines, ends with the commit command"
else
  echo "  ✗ integrate green path wrong (rc=$RC lines=$LINES): $OUT"; fail=$((fail+1))
fi
if [ "$LOG_BEFORE" = "$LOG_AFTER" ]; then
  echo "  ✓ integrate never creates a commit"
else
  echo "  ✗ integrate created a commit — git log changed"; fail=$((fail+1))
fi

# ── integrate on a start-generated brief (real "# Task N" / "Plan:" header
# lines) prints the SAME ship chain `start` printed, from `git -C` on —
# never the bare commit command (spec lean-loop-2026-09-23 Task 2).
SHIP_OUT=$(bash "$TICKET" integrate "$WT_PATH" --brief "$BRIEF_PATH" 2>&1)
SHIP_RC=$?
if [ "$SHIP_RC" -eq 0 ] \
  && printf '%s\n' "$SHIP_OUT" | tail -1 | grep -qF "git -C '$WT_PATH' commit -m '<subject>' && bash '$TICKET' finish '$WT_PATH' && bash '$TICKET' log '$FR/plan.md' 1 --sha" \
  && printf '%s\n' "$SHIP_OUT" | tail -1 | grep -qF "git -C '$FR_REAL' rev-parse --short HEAD" \
  && printf '%s\n' "$SHIP_OUT" | tail -1 | grep -qF -- "--note '<note>'"; then
  echo "  ✓ integrate on a start-generated brief prints the full ship chain, not the bare commit command"
else
  echo "  ✗ integrate ship-chain wrong: $SHIP_OUT"; fail=$((fail+1))
fi

# ── integrate prints only THIS task's review verdicts (<plan-slug>-task<N>-*.md)
mkdir -p "$FR_REAL/.rolepod/evidence/review"
printf 'VERDICT: APPROVED\n' > "$FR_REAL/.rolepod/evidence/review/plan-task1-spec.md"
printf 'VERDICT: REJECTED\n' > "$FR_REAL/.rolepod/evidence/review/plan-task2-spec.md"
SHIP_OUT=$(bash "$TICKET" integrate "$WT_PATH" --brief "$BRIEF_PATH" 2>&1)
if printf '%s\n' "$SHIP_OUT" | grep -qF 'plan-task1-spec.md: VERDICT: APPROVED' \
  && ! printf '%s\n' "$SHIP_OUT" | grep -q 'VERDICT: REJECTED'; then
  echo "  ✓ integrate prints the VERDICT of this task's reports only, never a sibling's"
else
  echo "  ✗ integrate verdict scoping wrong: $SHIP_OUT"; fail=$((fail+1))
fi

# ── a failing Proof (Command itself never runs) also exits non-zero
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
if [ "$RC" -ne 0 ] && ! printf '%s\n' "$OUT" | grep -q '^command:' && printf '%s\n' "$OUT" | grep -q '^proof: FAIL'; then
  echo "  ✓ integrate: a failing Proof command exits non-zero (Command never runs)"
else
  echo "  ✗ integrate failing-Proof handling wrong (rc=$RC): $OUT"; fail=$((fail+1))
fi

# ── --gate: runs last, after a green Proof; failing it exits non-zero
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
if [ "$RC" -ne 0 ] && ! printf '%s\n' "$OUT" | grep -q '^command:' \
  && printf '%s\n' "$OUT" | grep -q '^proof: ok' && printf '%s\n' "$OUT" | grep -q '^gate: FAIL' \
  && ! printf '%s\n' "$OUT" | grep -q 'commit -m'; then
  echo "  ✓ integrate: a failing --gate exits non-zero after a green Proof, no commit command printed"
else
  echo "  ✗ integrate --gate handling wrong (rc=$RC): $OUT"; fail=$((fail+1))
fi

# ── --pre is gone: integrate takes it as an unknown arg (exit 2)
cat > "$TMP/brief-pre.md" <<'EOF'
## Command
`true`
EOF
OUT=$(bash "$TICKET" integrate "$TMP" --brief "$TMP/brief-pre.md" --pre 'true' 2>&1)
RC=$?
if [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -qF 'unknown arg: --pre'; then
  echo "  ✓ integrate --pre exits 2 as an unknown arg"
else
  echo "  ✗ integrate --pre should exit 2 (rc=$RC): $OUT"; fail=$((fail+1))
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
if [ "$RC" -ne 0 ] && printf '%s\n' "$OUT" | grep -qi 'nothing to merge' \
  && [ "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" = "1" ] \
  && printf '%s\n' "$OUT" | grep -qF "Fix: git -C $(cd "$TMP/finish-diverged-wt" && pwd) merge " \
  && printf '%s\n' "$OUT" | grep -qF "re-run the commit check in $(cd "$TMP/finish-diverged-wt" && pwd), then finish again"; then
  echo "  ✓ finish refuses a diverged (unmerged) branch, in one line naming the merge + commit check fix"
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

# ── FW2-e: a worktree that cannot be removed (locked) after the merge landed:
# git's own stderr is passed on, the message says the merge already landed,
# and the hint never offers --force.
FLR="$TMP/finish-lock-repo"
mkrepo "$FLR"
( cd "${FLR:?}" && git worktree add -q -b finish-lock-branch "$TMP/finish-lock-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for \$FLR/finish-lock-branch" >&2; exit 1; }
( cd "$TMP/finish-lock-wt" && git commit -q --allow-empty -m "locked owner commit" )
git -C "$FLR" worktree lock "$TMP/finish-lock-wt"
OUT=$(bash "$TICKET" finish "$TMP/finish-lock-wt" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && printf '%s\n' "$OUT" | grep -qi 'locked' \
  && printf '%s\n' "$OUT" | grep -qF 'already landed' \
  && printf '%s\n' "$OUT" | grep -qF 'status --porcelain -uall' \
  && printf '%s\n' "$OUT" | grep -qF 'remove failed even with --force' \
  && ! printf '%s\n' "$OUT" | grep -qF 'never --force' \
  && [ "$(git -C "$FLR" rev-parse HEAD)" = "$(git -C "$FLR" rev-parse finish-lock-branch)" ]; then
  echo "  ✓ finish: a failed worktree remove prints git's stderr, says the merge landed, hints status --porcelain -uall, words the hint for the --force path"
else
  echo "  ✗ finish remove-failure hint wrong (rc=$RC): $OUT"; fail=$((fail+1))
fi
git -C "$FLR" worktree unlock "$TMP/finish-lock-wt" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════
# status (S1) — `log --start` writes running, `log --sha` flips it done,
# `status` prints the block and writes nothing
# ═══════════════════════════════════════════════════════════════════════

SPLAN="$TMP/status-plan.md"
cat > "$SPLAN" <<'EOF'
# Status Plan

Intro text.

```
## Status
- Task 9 — fenced: running (nobody, since 00:00)
```

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** `a.txt`
- [ ] **Command:** `true`
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** Task 1
- [ ] **Files:** `b.txt`
- [ ] **Command:** `true`
- **Owner:** devops-sre

### Task 3: gamma
- **Blocked by:** none
- [ ] **Files:** `c.txt`
- [ ] **Command:** `true`
- **Owner:** Lead

## Parallel layout
Sequential — one owner.

## Changes during build

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
S_BEFORE="$(cat "$SPLAN")"
S_OUT=$(bash "$TICKET" status "$SPLAN" 2>&1); S_RC=$?
if [ "$S_RC" -eq 0 ] && [ "$(printf '%s\n' "$S_OUT" | sed -n '1p')" = "0/3 done · 0 running" ] \
  && printf '%s\n' "$S_OUT" | grep -qxF -- '- Task 1 — alpha: todo' \
  && printf '%s\n' "$S_OUT" | grep -qxF -- '- Task 2 — beta: waits on 1' \
  && printf '%s\n' "$S_OUT" | grep -qxF -- '- Task 3 — gamma: todo' \
  && [ "$(cat "$SPLAN")" = "$S_BEFORE" ] \
  && [ "$(bash "$TICKET" status "$SPLAN" 2>&1)" = "$S_OUT" ]; then
  echo "  ✓ status prints the block (N/M done · K running, todo, waits on N), writes nothing, repeats byte-identical"
else
  echo "  ✗ status block wrong (rc=$S_RC): $S_OUT"; fail=$((fail+1))
fi
bash "$TICKET" log "$SPLAN" 1 --start >/dev/null; S_RC=$?
S_OUT=$(bash "$TICKET" status "$SPLAN" 2>&1)
if [ "$S_RC" -eq 0 ] && [ "$(printf '%s\n' "$S_OUT" | sed -n '1p')" = "0/3 done · 1 running" ] \
  && printf '%s\n' "$S_OUT" | grep -qE -- '^- Task 1 — alpha: running \(backend-developer, since [0-9]{2}:[0-9]{2}\)$' \
  && [ "$(grep -c '^## Status$' "$SPLAN")" = "2" ] \
  && [ "$(awk '/^## /{print NR": "$0}' "$SPLAN" | sed -n '1p' | sed 's/^[0-9]*: //')" = "## Status" ] \
  && grep -qxF -- '- Task 9 — fenced: running (nobody, since 00:00)' "$SPLAN"; then
  echo "  ✓ log --start writes running with the Owner role and since HH:MM; ## Status goes before the first ## heading, the fenced one untouched"
else
  echo "  ✗ log --start wrong (rc=$S_RC): $S_OUT"; fail=$((fail+1))
fi
S_SINCE="$(printf '%s\n' "$S_OUT" | grep -oE 'since [0-9:]{5}')"
bash "$TICKET" log "$SPLAN" 1 --start >/dev/null
if [ "$(bash "$TICKET" status "$SPLAN" | grep -oE 'since [0-9:]{5}')" = "$S_SINCE" ] && [ "$(grep -c '^## Status$' "$SPLAN")" = "2" ]; then
  echo "  ✓ a second log --start keeps one block and the first since time"
else
  echo "  ✗ second log --start rewrote the block"; fail=$((fail+1))
fi
bash "$TICKET" log "$SPLAN" 1 --sha abc1234 --note "alpha done" >/dev/null
S_OUT=$(bash "$TICKET" status "$SPLAN" 2>&1)
if [ "$(printf '%s\n' "$S_OUT" | sed -n '1p')" = "1/3 done · 0 running" ] \
  && printf '%s\n' "$S_OUT" | grep -qxF -- '- Task 1 — alpha: done (`abc1234`)' \
  && printf '%s\n' "$S_OUT" | grep -qxF -- '- Task 2 — beta: todo' \
  && grep -qxF -- '- Task 1 (`abc1234`): alpha done gate: no record -> docs/rolepod/tasks/status-plan/task-01.md' "$SPLAN" \
  && [ "$(grep -c '^## Status$' "$SPLAN")" = "2" ]; then
  echo "  ✓ log --sha rewrites running to done plus the sha; the waiting task becomes todo"
else
  echo "  ✗ log --sha status wrong: $S_OUT"; fail=$((fail+1))
fi
bash "$TICKET" log "$SPLAN" 2 --start >/dev/null
S_AFTER="$(cat "$SPLAN")"
bash "$TICKET" log "$SPLAN" 2 --start >/dev/null
S_RC=0; bash "$(dirname "$TICKET")/../../write-plan/scripts/plan-lint.sh" "$SPLAN" >/dev/null 2>&1 || S_RC=$?
if [ "$(cat "$SPLAN")" = "$S_AFTER" ] && [ "$S_RC" -eq 0 ]; then
  echo "  ✓ the plan is stable under a repeated log --start and plan-lint still exits 0 with a ## Status block"
else
  echo "  ✗ plan changed on a repeat or plan-lint rc=$S_RC with the block present"; fail=$((fail+1))
fi
S_AFTER="$(cat "$SPLAN")"
S_RC=0; S_OUT=$(bash "$TICKET" log "$SPLAN" 1 --start 2>&1) || S_RC=$?
if [ "$S_RC" -eq 0 ] && [ "$S_OUT" = "ticket: log: Task 1 already done in $SPLAN" ] && [ "$(cat "$SPLAN")" = "$S_AFTER" ]; then
  echo "  ✓ log --start on an already done task says so, exits 0 and writes nothing"
else
  echo "  ✗ log --start on a done task wrong (rc=$S_RC): $S_OUT"; fail=$((fail+1))
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

# ── log refuses (fail-closed) a plain plan with no such Task N at all —
# v2.180.8 case re-added (tests/ is untracked; a worktree removal drops it).
cat > "$TMP/log-plan-notask.md" <<'EOF'
# No Task Plan

## Tasks

### Task 1: alpha
- [ ] Command: true

## Changes during build

## Follow-ups
EOF
BEFORE_SUM_NT=$(cksum "$TMP/log-plan-notask.md")
if bash "$TICKET" log "$TMP/log-plan-notask.md" 9 --sha aaa000 --note "x" >/dev/null 2>&1; then
  echo "  ✗ log succeeded on a plain plan with no such Task N"; fail=$((fail+1))
else
  AFTER_SUM_NT=$(cksum "$TMP/log-plan-notask.md")
  if [ "$BEFORE_SUM_NT" = "$AFTER_SUM_NT" ]; then
    echo "  ✓ log refuses (fail-closed) a plain plan with no such Task N, unchanged"
  else
    echo "  ✗ log refused but modified the plan anyway"; fail=$((fail+1))
  fi
fi

# ── log flips boxes on the compact heading shapes `### T1` and `### Task1`
# (no space) — v2.180.8 cases re-added.
cat > "$TMP/log-plan-t1.md" <<'EOF'
# Compact Heading Plan T1

## Tasks

### T1: alpha
- [ ] Files: a.txt

## Changes during build

## Follow-ups
EOF
if bash "$TICKET" log "$TMP/log-plan-t1.md" 1 --sha bbb000 --note "x" >/dev/null 2>&1 \
  && grep -qF -- '- [x] Files: a.txt' "$TMP/log-plan-t1.md"; then
  echo "  ✓ log exits 0 and flips the box under a '### T1' heading"
else
  echo "  ✗ log did not flip the box under '### T1'"; fail=$((fail+1))
fi

cat > "$TMP/log-plan-task1.md" <<'EOF'
# Compact Heading Plan Task1

## Tasks

### Task1: alpha
- [ ] Files: a.txt

## Changes during build

## Follow-ups
EOF
if bash "$TICKET" log "$TMP/log-plan-task1.md" 1 --sha ccc000 --note "x" >/dev/null 2>&1 \
  && grep -qF -- '- [x] Files: a.txt' "$TMP/log-plan-task1.md"; then
  echo "  ✓ log exits 0 and flips the box under a '### Task1' heading"
else
  echo "  ✗ log did not flip the box under '### Task1'"; fail=$((fail+1))
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
if [ "$RC_A" -eq 0 ] && printf '%s\n' "$OUT_A" | grep -qF "ready now: Task 3 (devops-sre)"; then
  echo "  ✓ log prints ready now with owners"
else
  echo "  ✗ log ready-now wrong (rc=$RC_A): [$OUT_A]"; cat "$TMP/ready-a.err" >&2; fail=$((fail+1))
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
if [ "$RC_C" -eq 0 ] && printf '%s\n' "$OUT_C" | grep -qF "ready now: Task 2 (Lead)"; then
  echo "  ✓ log names a Lead-owned task in the ready-now line"
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

# ── log's review: range (spec lean-loop-2026-09-23 Task 2): once every
# role-owned task is done, a Sequential plan (track `plan`) names <first logged
# task sha>^...<sha> for the track-end review — never before, idempotent.
cat > "$TMP/review-plan.md" <<'EOF'
# Review Range Plan

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** a.py
- [ ] **Command:** true
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** none
- [ ] **Files:** b.py
- [ ] **Command:** true
- **Owner:** frontend-developer

### Task 3: docs
- **Blocked by:** none
- [ ] **Files:** c.md
- [ ] **Command:** true
- **Owner:** Lead

## Parallel layout
Sequential — one track, no worktrees.

## Changes during build
- Task 1 — kept `main` as the integration branch, no rename needed

## Follow-ups
EOF
OUT_R1=$(bash "$TICKET" log "$TMP/review-plan.md" 1 --sha aaa111 --note "alpha done" 2>"$TMP/review-r1.err")
if ! printf '%s\n' "$OUT_R1" | grep -q '^track '; then
  echo "  ✓ log prints no track line while a role-owned task (Task 2) is still open"
else
  echo "  ✗ log printed a track line before every role task was done: [$OUT_R1]"; fail=$((fail+1))
fi
OUT_R3=$(bash "$TICKET" log "$TMP/review-plan.md" 3 --sha ccc333 --note "docs done" 2>"$TMP/review-r3.err")
if ! printf '%s\n' "$OUT_R3" | grep -q '^track '; then
  echo "  ✓ log prints no track line on a Lead-owned task while Task 2 is still open"
else
  echo "  ✗ log printed a track line with a role task still open: [$OUT_R3]"; fail=$((fail+1))
fi
OUT_R2=$(bash "$TICKET" log "$TMP/review-plan.md" 2 --sha bbb222 --note "beta done" 2>"$TMP/review-r2.err")
RC_R2=$?
if [ "$RC_R2" -eq 0 ]; then
  echo "  ✓ log exits 0 once every role task is done (the file's own if-not-&& rule at the review: line)"
else
  echo "  ✗ log exited $RC_R2 on the call that completes every role task"; fail=$((fail+1))
fi
if printf '%s\n' "$OUT_R2" | grep -qF 'track plan done — review: aaa111^...bbb222'; then
  echo "  ✓ log prints the Sequential track-plan range off the FIRST logged task's sha once every role task is done — never the deviation line's \`main\` above it"
else
  echo "  ✗ log track plan range wrong: [$OUT_R2]"; cat "$TMP/review-r2.err" >&2; fail=$((fail+1))
fi
# review-plan.md lives directly under $TMP, never git-inited — the diff
# write can't resolve a base checkout, so a failed write never fails log
# and the range prints with no "; lens diff:" suffix.
if [ "$RC_R2" -eq 0 ] && ! printf '%s\n' "$OUT_R2" | grep -qF 'lens diff:'; then
  echo "  ✓ log stays exit 0 and prints the range with no path when the diff can't be written (not a git repo)"
else
  echo "  ✗ log should exit 0 with no lens diff: path outside a git repo: rc=$RC_R2 out=[$OUT_R2]"; fail=$((fail+1))
fi
OUT_R2B=$(bash "$TICKET" log "$TMP/review-plan.md" 2 --sha bbb222 --note "beta done" 2>>"$TMP/review-r2.err")
if [ "$OUT_R2B" = "$OUT_R2" ]; then
  echo "  ✓ log's review: line is idempotent — a re-run prints the same line"
else
  echo "  ✗ log review: re-run differs: [$OUT_R2B] vs [$OUT_R2]"; fail=$((fail+1))
fi

# ── log's review: line names a lens diff file (spec lean-loop-2026-09-24
# Task 2): inside a real repo the diff writes to
# .rolepod/evidence/review/<plan-slug>.diff, holds the source change, and
# leaves out a path .gitattributes marks linguist-generated.
LSR="$TMP/lens-repo"
mkdir -p "$LSR/plugins"
( cd "${LSR:?}" && git init -q . && git config user.email t@t && git config user.name t \
  && git commit -q --allow-empty -m init )
# ticket.sh resolves the base checkout through `git rev-parse --show-toplevel`
# (canonical, symlinks resolved) — see FR_REAL above for the same macOS
# /var vs /private/var wrinkle.
LSR_REAL="$(git -C "$LSR" rev-parse --show-toplevel)"
printf 'plugins/** linguist-generated\n' > "$LSR/.gitattributes"
mkdir -p "$LSR/.rolepod" && printf 'plugins\n' > "$LSR/.rolepod/review-exclude"
printf 'v1\n' > "$LSR/real.txt"
printf 'gen-v1\n' > "$LSR/plugins/generated.txt"
( cd "${LSR:?}" && git add -A && git commit -q -m "task 1 commit" )
LSR_TASK1_SHA="$(git -C "$LSR" rev-parse HEAD)"
printf 'v2\n' > "$LSR/real.txt"
printf 'gen-v2\n' > "$LSR/plugins/generated.txt"
( cd "${LSR:?}" && git add -A && git commit -q -m "later work" )
cat > "$LSR/lens-plan.md" <<'EOF'
# Lens Diff Plan

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** real.py
- [ ] **Command:** true
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** 1
- [x] **Files:** real.py
- [x] **Command:** true
- **Owner:** backend-developer

## Parallel layout
Sequential — one track, no worktrees.

## Changes during build

## Follow-ups
EOF
LSR_DIFF="$LSR_REAL/.rolepod/evidence/review/lens-plan-plan.diff"
OUT_LD=$(bash "$TICKET" log "$LSR/lens-plan.md" 1 --sha "$LSR_TASK1_SHA" --note "alpha done" 2>"$TMP/lens-diff.err")
RC_LD=$?
if [ "$RC_LD" -eq 0 ] && printf '%s\n' "$OUT_LD" | grep -qF "track plan done — review: ${LSR_TASK1_SHA}^...${LSR_TASK1_SHA}; lens diff: $LSR_DIFF"; then
  echo "  ✓ log names the lens diff file on the review: line once every role task is done"
else
  echo "  ✗ log lens diff line wrong (rc=$RC_LD): [$OUT_LD]"; cat "$TMP/lens-diff.err" >&2; fail=$((fail+1))
fi
if [ -f "$LSR_DIFF" ] && grep -q 'real.txt' "$LSR_DIFF" && ! grep -q 'plugins/generated.txt' "$LSR_DIFF"; then
  echo "  ✓ the lens diff file holds the source change but excludes the linguist-generated path"
else
  echo "  ✗ lens diff file wrong or missing: $LSR_DIFF"; cat "$LSR_DIFF" 2>&1 >&2; fail=$((fail+1))
fi

# ── log's review: line falls back to a plain `git diff <range>` when the
# git on PATH rejects `attr:` pathspec magic for diff (portability MINOR,
# r2-owner review 2026-09-24) — the lens file still gets written,
# and log still exits 0.
ASR="$TMP/attr-shim-repo"
mkdir -p "$ASR/plugins"
( cd "${ASR:?}" && git init -q . && git config user.email t@t && git config user.name t \
  && git commit -q --allow-empty -m init )
ASR_REAL="$(git -C "$ASR" rev-parse --show-toplevel)"
printf 'plugins/** linguist-generated\n' > "$ASR/.gitattributes"
printf 'v1\n' > "$ASR/real.txt"
( cd "${ASR:?}" && git add -A && git commit -q -m "task 1 commit" )
ASR_TASK1_SHA="$(git -C "$ASR" rev-parse HEAD)"
printf 'v2\n' > "$ASR/real.txt"
( cd "${ASR:?}" && git add -A && git commit -q -m "later work" )
cat > "$ASR/attr-shim-plan.md" <<'EOF'
# Attr Shim Plan

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** real.py
- [ ] **Command:** true
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** 1
- [x] **Files:** real.py
- [x] **Command:** true
- **Owner:** backend-developer

## Parallel layout
Sequential — one track, no worktrees.

## Changes during build

## Follow-ups
EOF

GITSHIM_DIR="$TMP/git-shim"
mkdir -p "$GITSHIM_DIR"
REAL_GIT="$(command -v git)"
cat > "$GITSHIM_DIR/git" <<EOF2
#!/bin/bash
has_diff=0; has_attr=0
for a in "\$@"; do
  [ "\$a" = "diff" ] && has_diff=1
  case "\$a" in *attr:*) has_attr=1 ;; esac
done
if [ "\$has_diff" -eq 1 ] && [ "\$has_attr" -eq 1 ]; then
  echo "fatal: pathspec magic not supported in diff: 'attr:'" >&2
  exit 128
fi
exec "$REAL_GIT" "\$@"
EOF2
chmod +x "$GITSHIM_DIR/git"

ASR_DIFF="$ASR_REAL/.rolepod/evidence/review/attr-shim-plan-plan.diff"
OUT_ASR=$(PATH="$GITSHIM_DIR:$PATH" bash "$TICKET" log "$ASR/attr-shim-plan.md" 1 --sha "$ASR_TASK1_SHA" --note "alpha done" 2>"$TMP/attr-shim.err")
RC_ASR=$?
if [ "$RC_ASR" -eq 0 ] && printf '%s\n' "$OUT_ASR" | grep -qF "; lens diff: $ASR_DIFF"; then
  echo "  ✓ log falls back to a plain diff (still writes the lens file, still exits 0) when git rejects the attr: pathspec"
else
  echo "  ✗ log attr-pathspec fallback wrong (rc=$RC_ASR): [$OUT_ASR]"; cat "$TMP/attr-shim.err" >&2; fail=$((fail+1))
fi
if [ -f "$ASR_DIFF" ] && grep -q 'real.txt' "$ASR_DIFF"; then
  echo "  ✓ the fallback lens diff file holds the source change"
else
  echo "  ✗ fallback lens diff file wrong or missing: $ASR_DIFF"; cat "$ASR_DIFF" 2>&1 >&2; fail=$((fail+1))
fi

# ── a plan without ## Tracks and NOT Sequential: each task is its own track,
# id = the task number — logging Task 1 prints `track 1 done`, the range
# starts at the task commit's parent, and Task 2 stays silent until logged.
cat > "$LSR/par-plan.md" <<'EOF'
# Par Plan

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** real.py
- [ ] **Command:** true
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** none
- [ ] **Files:** real.py
- [ ] **Command:** true
- **Owner:** backend-developer

## Parallel layout
Tasks 1 and 2 run in parallel worktrees.

## Changes during build

## Follow-ups
EOF
PAR_HEAD="$(git -C "$LSR" rev-parse HEAD)"
PAR_DIFF="$LSR_REAL/.rolepod/evidence/review/par-plan-1.diff"
OUT_PAR=$(bash "$TICKET" log "$LSR/par-plan.md" 1 --sha "$PAR_HEAD" --note "alpha done" 2>"$TMP/par.err")
RC_PAR=$?
if [ "$RC_PAR" -eq 0 ] \
  && printf '%s\n' "$OUT_PAR" | grep -qx 'track 1 done' \
  && ! printf '%s\n' "$OUT_PAR" | grep -q 'Track end:\|review:' \
  && [ ! -f "$PAR_DIFF" ]; then
  echo "  ✓ log: a Parallel plan without ## Tracks makes each task its own track — one code task → 'track 1 done' only, no Track end line, no lens diff"
else
  echo "  ✗ log Parallel-no-Tracks line wrong (rc=$RC_PAR): [$OUT_PAR]"; cat "$TMP/par.err" >&2; fail=$((fail+1))
fi

# A docs-only track (every role-owned task briefed R1) takes no track-end
# review: log prints just `track <id> done` — no review range, no diff file.
cat > "$LSR/docs-plan.md" <<'EOF'
# Docs Plan

## Tasks

### Task 1: words
- **Blocked by:** none
- [ ] **Files:** docs/x.md
- [ ] **Command:** true
- **Owner:** content-strategist

## Parallel layout
Tasks run in parallel worktrees.

## Changes during build

## Follow-ups
EOF
OUT_DOC=$(bash "$TICKET" log "$LSR/docs-plan.md" 1 --sha "$PAR_HEAD" --note "words done" 2>"$TMP/docs.err")
RC_DOC=$?
if [ "$RC_DOC" -eq 0 ] && printf '%s\n' "$OUT_DOC" | grep -qx 'track 1 done' \
  && ! printf '%s\n' "$OUT_DOC" | grep -q 'review:\|Track end' \
  && [ ! -f "$LSR_REAL/.rolepod/evidence/review/docs-plan-1.diff" ]; then
  echo "  ✓ log: a docs-only track prints just 'track 1 done' — no review line, no track-end sentence, no diff"
else
  echo "  ✗ log docs-only track wrong (rc=$RC_DOC): [$OUT_DOC]"; cat "$TMP/docs.err" >&2; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# log — fence rule (plan-fence Task 2, case a): a fenced `- [ ]` line and a
# fenced `### Task 9` heading under Task 1 stay literal; Task 1's own real
# boxes flip; `log 9` refuses since Task 9 exists only inside the fence.
# ═══════════════════════════════════════════════════════════════════════

FCA="$TMP/fence-a-plan.md"
cat > "$FCA" <<'EOF'
# Fenced Plan A

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** a.txt
- [ ] **Command:** true
```
- [ ] OLD spec line
### Task 9: fake
```
- [ ] **Extra:** z
- **Owner:** backend-developer

## Changes during build

## Follow-ups
EOF
FCA_BEFORE_SUM=$(cksum "$FCA")
if bash "$TICKET" log "$FCA" 9 --sha aaa999 --note "phantom" >/dev/null 2>&1; then
  echo "  ✗ log 9 succeeded on a Task 9 that exists only inside a fence"; fail=$((fail+1))
else
  FCA_AFTER_SUM=$(cksum "$FCA")
  if [ "$FCA_BEFORE_SUM" = "$FCA_AFTER_SUM" ]; then
    echo "  ✓ log 9 refuses a fenced-only Task 9 and leaves the plan unchanged"
  else
    echo "  ✗ log 9 refused but modified the plan anyway"; fail=$((fail+1))
  fi
fi

FCA_FENCE_BEFORE=$(sed -n '/^```$/,/^```$/p' "$FCA")
OUT_FCA1=$(bash "$TICKET" log "$FCA" 1 --sha aaa111 --note "alpha done" 2>"$TMP/fence-a1.err")
RC_FCA1=$?
FCA_FENCE_AFTER=$(sed -n '/^```$/,/^```$/p' "$FCA")
if [ "$RC_FCA1" -eq 0 ] && [ "$FCA_FENCE_BEFORE" = "$FCA_FENCE_AFTER" ]; then
  echo "  ✓ log 1 leaves the fenced block byte-identical"
else
  echo "  ✗ log 1 fence changed (rc=$RC_FCA1): before=[$FCA_FENCE_BEFORE] after=[$FCA_FENCE_AFTER]"; cat "$TMP/fence-a1.err" >&2; fail=$((fail+1))
fi
FCA_OPEN=$(grep -c '\- \[ \]' "$FCA")
FCA_DONE=$(grep -c '\- \[x\]' "$FCA")
if [ "$FCA_OPEN" -eq 1 ] && [ "$FCA_DONE" -eq 3 ]; then
  echo "  ✓ log 1 flips only Task 1's own unfenced boxes (Files, Command, Extra), leaving the fenced box open"
else
  echo "  ✗ log 1 flipped the wrong boxes: open=$FCA_OPEN done=$FCA_DONE"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# log — block rule (plan-fence Task 2, case b): a non-task `### Notes`
# subheading stays inside Task 1's block; its own box flips too, and Task 2
# (Blocked by Task 1) shows up in ready now.
# ═══════════════════════════════════════════════════════════════════════

FCB="$TMP/fence-b-plan.md"
cat > "$FCB" <<'EOF'
# Fenced Plan B

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** a.txt
### Notes
- [ ] extra checklist item
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** Task 1
- [ ] **Files:** b.txt
- **Owner:** frontend-developer

## Changes during build

## Follow-ups
EOF
OUT_FCB=$(bash "$TICKET" log "$FCB" 1 --sha bbb111 --note "alpha done" 2>"$TMP/fence-b.err")
RC_FCB=$?
if [ "$RC_FCB" -eq 0 ] && grep -qF -- '- [x] **Files:** a.txt' "$FCB" && grep -qF -- '- [x] extra checklist item' "$FCB"; then
  echo "  ✓ log 1 flips the box after a non-task ### Notes subheading — it stays inside the block"
else
  echo "  ✗ log 1 left a box after ### Notes untouched (rc=$RC_FCB): [$OUT_FCB]"; cat "$TMP/fence-b.err" >&2; fail=$((fail+1))
fi
if printf '%s\n' "$OUT_FCB" | grep -qF "ready now: Task 2 (frontend-developer)"; then
  echo "  ✓ log 1 unblocks Task 2 once the ### Notes box counts as done"
else
  echo "  ✗ log 1 did not report Task 2 as ready: [$OUT_FCB]"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# log — Round-2 (plan-fence Task 2): an INDENTED `- [ ]` inside the task
# block flips too (plan_task_rows already counted it open) and its
# dependent shows up in ready now.
# ═══════════════════════════════════════════════════════════════════════

FCC="$TMP/fence-c-plan.md"
cat > "$FCC" <<'EOF'
# Fenced Plan C

## Tasks

### Task 1: alpha
- **Blocked by:** none
  - [ ] **Files:** a.txt
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** Task 1
- [ ] **Files:** b.txt
- **Owner:** frontend-developer

## Changes during build

## Follow-ups
EOF
OUT_FCC=$(bash "$TICKET" log "$FCC" 1 --sha ccc111 --note "alpha done" 2>"$TMP/fence-c.err")
RC_FCC=$?
if [ "$RC_FCC" -eq 0 ] && grep -qF -- '  - [x] **Files:** a.txt' "$FCC"; then
  echo "  ✓ log 1 flips an indented box inside the task block"
else
  echo "  ✗ log 1 did not flip the indented box (rc=$RC_FCC): [$OUT_FCC]"; cat "$TMP/fence-c.err" >&2; fail=$((fail+1))
fi
if printf '%s\n' "$OUT_FCC" | grep -qF "ready now: Task 2 (frontend-developer)"; then
  echo "  ✓ log 1 unblocks Task 2 once the indented box counts as done"
else
  echo "  ✗ log 1 did not report Task 2 as ready after the indented box flipped: [$OUT_FCC]"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# log — Round-3 (plan-fence Task 2): the checkbox flip uses the same
# open-box regex plan_task_rows counts — no space between the dash and the
# bracket (`-[ ]`) still flips.
# ═══════════════════════════════════════════════════════════════════════

FCE="$TMP/fence-e-plan.md"
cat > "$FCE" <<'EOF'
# No-space Box Plan

## Tasks

### Task 1: alpha
-[ ] **Files:** a.txt
- **Owner:** backend-developer

## Changes during build

## Follow-ups
EOF
OUT_FCE=$(bash "$TICKET" log "$FCE" 1 --sha eee111 --note "alpha done" 2>"$TMP/fence-e.err")
RC_FCE=$?
if [ "$RC_FCE" -eq 0 ] && grep -qF -- '-[x] **Files:** a.txt' "$FCE"; then
  echo "  ✓ log 1 flips a no-space '-[ ]' box, matching plan_task_rows' own open-box regex"
else
  echo "  ✗ log 1 did not flip a no-space '-[ ]' box (rc=$RC_FCE): [$OUT_FCE]"; cat "$TMP/fence-e.err" >&2; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# log — Round-2 (plan-fence Task 2): a `### Notes` line right after
# `**Owner:**` must not glue onto the Owner value — the ready-now line
# names the plain role, never "<role> ### Notes".
# ═══════════════════════════════════════════════════════════════════════

FCD="$TMP/fence-d-plan.md"
cat > "$FCD" <<'EOF'
# Fenced Plan D

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** a.txt
- **Owner:** devops-sre

### Task 2: beta
- **Blocked by:** Task 1
- [ ] **Files:** b.txt
- **Owner:** frontend-developer
### Notes
- some note text

## Changes during build

## Follow-ups
EOF
OUT_FCD=$(bash "$TICKET" log "$FCD" 1 --sha ddd111 --note "alpha done" 2>"$TMP/fence-d.err")
RC_FCD=$?
READY_FCD=$(printf '%s\n' "$OUT_FCD" | grep '^ready now:')
if [ "$RC_FCD" -eq 0 ] && [ "$READY_FCD" = "ready now: Task 2 (frontend-developer)" ]; then
  echo "  ✓ a ### Notes line right after **Owner:** does not glue onto the owner value"
else
  echo "  ✗ owner glued with ### Notes (rc=$RC_FCD): [$READY_FCD]"; cat "$TMP/fence-d.err" >&2; fail=$((fail+1))
fi

# ── a later `start` on a task with a pre-existing branch whose short name a
# remote ref shares reprints cleanly (for-each-ref would print it as
# "heads/<br>"); a plain non-empty dir at the target path (no branch) makes
# `worktree add -b` fail without leaving its new branch behind.
SFR="$TMP/start-fail-repo"
mkdir -p "$SFR"
( cd "${SFR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$SFR/plan.md" <<'EOF'
# Start Fail Feature Plan

## Tasks

### Task 2: build the beta widget
- **Blocked by:** none
- [ ] **Files:** `beta.js`
- [ ] **Command:** `true`
- **Owner:** frontend-developer
- **Done when:** true

### Task 4: build the delta widget
- **Blocked by:** none
- [ ] **Files:** `delta.js`
- [ ] **Command:** `true`
- **Owner:** mobile-developer
- **Done when:** true

## Parallel layout
A per-task worktree fixture: the first line is not "Sequential", so start builds a task worktree.
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${SFR:?}" && git add -A && git commit -q -m init )
SF_T2_WT="$(bash "$TICKET" start "$SFR/plan.md" 2 2>/dev/null | sed -n '1p' | awk '{print $2}')"
SF_T2_BR="$(git -C "$SF_T2_WT" symbolic-ref --quiet --short HEAD 2>/dev/null)"
git -C "$SFR" worktree remove "$SF_T2_WT"
git -C "$SFR" update-ref "refs/remotes/$SF_T2_BR" HEAD
SF_T2_OUT2="$(bash "$TICKET" start "$SFR/plan.md" 2 2>/dev/null | sed -n '1p')"
SF_T2_WT2="$(printf '%s' "$SF_T2_OUT2" | awk '{print $2}')"
if [ -n "$SF_T2_BR" ] && [ -d "$SF_T2_WT2" ] && git -C "$SFR" show-ref --verify --quiet "refs/heads/$SF_T2_BR"; then
  echo "  ✓ start reuses a branch left by a manual worktree remove — no -b, no duplicate-branch error"
else
  echo "  ✗ start on a reused branch wrong: br=[$SF_T2_BR] wt=[$SF_T2_WT2]"; fail=$((fail+1))
fi
git -C "$SFR" worktree remove "$SF_T2_WT2" 2>/dev/null || true
SF_T4_WT="$(bash "$TICKET" start "$SFR/plan.md" 4 2>/dev/null | sed -n '1p' | awk '{print $2}')"
SF_T4_BR="$(git -C "$SF_T4_WT" symbolic-ref --quiet --short HEAD 2>/dev/null)"
git -C "$SFR" worktree remove "$SF_T4_WT"
git -C "$SFR" branch -D "$SF_T4_BR" >/dev/null
mkdir -p "$SF_T4_WT" && : > "$SF_T4_WT/occupied"
OUT=$(bash "$TICKET" start "$SFR/plan.md" 4 2>"$TMP/start-fail.err")
RC=$?
if [ -n "$SF_T4_BR" ] && [ "$RC" -ne 0 ] && ! git -C "$SFR" show-ref --verify --quiet "refs/heads/$SF_T4_BR"; then
  echo "  ✓ start: worktree add -b failing on an occupied path does not leave its new branch behind"
else
  echo "  ✗ start occupied-path failure wrong (rc=$RC): $OUT"; cat "$TMP/start-fail.err" >&2; fail=$((fail+1))
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
A per-task worktree fixture: the first line is not "Sequential", so start builds a task worktree.
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
  printf '## Parallel layout\nA per-task worktree fixture.\nSequential — single owner.\n\n## Failure policy\nDefault: stop after 2 failed attempts (never a 4th).\n'
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
# log's gate: field (S15, spec Desired 10) — the gate writes to the plan,
# never reads from it. `log --sha <sha>` finds the newest phase-log "gate"
# row whose head is <sha>^ and appends what the gate counted; none → the
# line still says so.
# ═══════════════════════════════════════════════════════════════════════
GR="$TMP/gate-repo"
mkdir -p "$GR/.rolepod/evidence"
( cd "${GR:?}" && git init -q . && git config user.email t@t && git config user.name t \
  && git commit -q --allow-empty -m init )
GR_PARENT_SHA=$(git -C "$GR" rev-parse HEAD)
cat > "$GR/.rolepod/evidence/phase-log.jsonl" <<EOF
{"phase":"gate","decision":"pass","tests":2,"risk":1,"reviewers":2,"strong":2,"external":1,"head":"$GR_PARENT_SHA"}
EOF
( cd "$GR" && git commit -q --allow-empty -m "task 1 commit" )
GR_TASK_SHA=$(git -C "$GR" rev-parse HEAD)
cat > "$GR/plan.md" <<'EOF'
# Gate Row Plan

## Tasks

### Task 1: alpha
- [ ] Files: a.txt
- [ ] Command: true

## Changes during build

## Follow-ups
EOF
bash "$TICKET" log "$GR/plan.md" 1 --sha "$GR_TASK_SHA" --note "did the thing" >/dev/null
if grep -qF -- "gate: pass · tests 2 · risk 1 · reviewers 2 (security 2)" "$GR/plan.md"; then
  echo "  ✓ log's gate: field matches the newest phase-log row whose head is <sha>^"
else
  echo "  ✗ log's gate: field missing or wrong"; grep -F 'Task 1' "$GR/plan.md" >&2; fail=$((fail+1))
fi

# ── no matching gate row (a different HEAD, or none at all) → "gate: no record"
( cd "$GR" && git commit -q --allow-empty -m "task 2 commit" )
GR_TASK2_SHA=$(git -C "$GR" rev-parse HEAD)
cat >> "$GR/plan.md" <<'EOF'

### Task 2: beta
- [ ] Files: b.txt
- [ ] Command: true
EOF
bash "$TICKET" log "$GR/plan.md" 2 --sha "$GR_TASK2_SHA" --note "did another thing" >/dev/null
if grep -qF -- '- Task 2 (`'"$GR_TASK2_SHA"'`): did another thing gate: no record' "$GR/plan.md"; then
  echo "  ✓ log's gate: field says 'gate: no record' when no phase-log row matches <sha>^"
else
  echo "  ✗ log's gate: field wrong on a commit with no matching gate row"; grep -F 'Task 2' "$GR/plan.md" >&2; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# plan lock — two overlapping `start` runs against the same plan could both
# create the same worktree/branch. One `start` per plan at a time; a lock
# whose holder process is gone is taken over; a run that fails still
# releases it (the EXIT trap, not exit 0 only).
# ═══════════════════════════════════════════════════════════════════════

LKR="$TMP/lock-repo"
mkdir -p "$LKR"
( cd "${LKR:?}" && git init -q . && git config user.email t@t && git config user.name t )
cat > "$LKR/plan.md" <<'EOF'
# Lock Feature Plan

## Tasks

### Task 1: build the alpha widget
- **Blocked by:** none
- [ ] **Files:** `alpha.js`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

## Parallel layout
A per-task worktree fixture: the first line is not "Sequential", so start builds a task worktree.
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "${LKR:?}" && git add -A && git commit -q -m init )
LK="$(cd "$LKR" && cd "$(git rev-parse --git-common-dir)" && pwd)/rolepod-ticket-plan.lock"
lk_reset() {
  git -C "$LKR" worktree list --porcelain | awk '/^worktree /{print $2}' | tail -n +2 |
    while read -r w; do git -C "$LKR" worktree remove --force "$w"; done
  git -C "$LKR" for-each-ref --format='%(refname)' refs/heads | grep -vx 'refs/heads/main\|refs/heads/master' |
    while read -r b; do git -C "$LKR" branch -D "${b#refs/heads/}" >/dev/null; done
  rm -rf "$LKR/docs/rolepod/handoffs" "$LK"
}

# ── a live holder: start refuses, nothing created, lock kept
mkdir "$LK" && echo "$$" > "$LK/pid"
WT_LK_BEFORE=$(git -C "$LKR" worktree list | wc -l | tr -d ' ')
OUT_S=$(bash "$TICKET" start "$LKR/plan.md" 1 2>"$TMP/lock-start.err"); RC_S=$?
WT_LK_AFTER=$(git -C "$LKR" worktree list | wc -l | tr -d ' ')
if [ "$RC_S" -eq 1 ] && [ "$WT_LK_AFTER" = "$WT_LK_BEFORE" ] && [ "$(cat "$LK/pid" 2>/dev/null)" = "$$" ] \
  && grep -q "is running for this plan (pid $$)" "$TMP/lock-start.err"; then
  echo "  ✓ plan lock held by a live process: start refuses, nothing created"
else
  echo "  ✗ plan lock live-holder handling wrong (start rc=$RC_S wt ${WT_LK_BEFORE}->${WT_LK_AFTER}): $OUT_S"; fail=$((fail+1))
  cat "$TMP/lock-start.err" >&2
fi
lk_reset

# ── a stale lock (its holder is gone) is taken over, and released after
( exit 0 ) & LK_DEAD=$!; wait "$LK_DEAD"
mkdir "$LK" && echo "$LK_DEAD" > "$LK/pid"
OUT=$(bash "$TICKET" start "$LKR/plan.md" 1 2>"$TMP/lock-stale.err"); RC=$?
LK_STALE_BRIEF=$(printf '%s\n' "$OUT" | sed -n '1p' | awk '{print $1}')
if [ "$RC" -eq 0 ] && [ -f "$LK_STALE_BRIEF" ] && [ ! -e "$LK" ]; then
  echo "  ✓ plan lock left by a dead process is taken over, and released when the run ends"
else
  echo "  ✗ plan lock stale takeover wrong (rc=$RC lock-left=$([ -e "$LK" ] && echo yes || echo no)): $OUT"; fail=$((fail+1))
  cat "$TMP/lock-stale.err" >&2
fi

lk_reset

# ── a run that fails still releases the lock (the EXIT trap, not exit 0 only)
OUT=$(bash "$TICKET" start "$LKR/plan.md" 1 --base nonexistent-base-xyz 2>"$TMP/lock-fail.err"); RC=$?
if [ "$RC" -ne 0 ] && [ ! -e "$LK" ]; then
  echo "  ✓ plan lock released when the run fails (an unresolvable --base)"
else
  echo "  ✗ plan lock after a failing run wrong (rc=$RC lock-left=$([ -e "$LK" ] && echo yes || echo no))"; fail=$((fail+1))
  cat "$TMP/lock-fail.err" >&2
fi
lk_reset

# ═══════════════════════════════════════════════════════════════════════
# a value flag given last with no value is a usage error, never a hang:
# `shift 2` with one arg left fails without shifting, so the parser looped
# forever. perl's alarm bounds each run (macOS ships no `timeout`).
# ═══════════════════════════════════════════════════════════════════════

for flagcase in "start|$TMP/none.md|1|--base" "integrate|$TMP/none-wt|--brief" \
  "integrate|$TMP/none-wt|--gate" \
  "log|$TMP/none.md|1|--sha" "log|$TMP/none.md|1|--note"; do
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
# base checkout — integrate/finish use the checkout the task was started
# from, not the first-listed worktree (path with a space; Lead in a linked
# worktree on a feature branch)
# ═══════════════════════════════════════════════════════════════════════

# (1) a repo path with a space: a real `start` (worktree name slugged), then
# integrate + finish — the first-listed worktree must not be cut at the space
SPR="$TMP/Has Space Repo"
mkrepo "$SPR"
cat > "$SPR/plan.md" <<'EOF2'
# Space Plan

## Tasks

### Task 1: build the widget
- **Blocked by:** none
- [ ] **Files:** `widget.txt`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

## Parallel layout
A per-task worktree fixture: the first line is not "Sequential", so start builds a task worktree.
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF2
( cd "$SPR" && git add -A && git commit -q -m "add plan" )
SP_OUT=$(bash "$TICKET" start "$SPR/plan.md" 1 2>"$TMP/space.err")
# line 1 is "<brief> <worktree>"; the brief path holds the space, so strip the
# known brief prefix instead of splitting on whitespace
SP_BRIEF="$(git -C "$SPR" rev-parse --show-toplevel)/docs/rolepod/handoffs/plan-t1-owner.md"
SP_WT=$(printf '%s\n' "$SP_OUT" | sed -n '1p'); SP_WT="${SP_WT#"$SP_BRIEF" }"
( cd "${SP_WT:?}" && git commit -q --allow-empty -m "space work" )
SP_INT=$(bash "$TICKET" integrate "$SP_WT" --brief "$SP_BRIEF" 2>&1); SP_INT_RC=$?
SP_FIN=$(bash "$TICKET" finish "$SP_WT" 2>&1); SP_FIN_RC=$?
if [ "$SP_INT_RC" -eq 0 ] && [ "$SP_FIN_RC" -eq 0 ] \
  && [ "$(git -C "$SPR" log -1 --format=%s)" = "space work" ] \
  && printf '%s\n' "$SP_FIN" | grep -qF 'close: owner-plan-t1'; then
  echo "  ✓ start + integrate + finish work in a repo whose path holds a space"
else
  echo "  ✗ space path: start=[$SP_OUT] integrate rc=$SP_INT_RC finish rc=$SP_FIN_RC: $SP_INT / $SP_FIN"; fail=$((fail+1))
fi

# (2) the Lead works in a linked worktree on a feature branch: the task lands
# on that branch, the main checkout's branch never moves
LDR="$TMP/lead-main"
mkrepo "$LDR"
cat > "$LDR/plan.md" <<'EOF'
# Topic Plan

## Tasks

### Task 1: build the widget
- **Blocked by:** none
- [ ] **Files:** `widget.txt`
- [ ] **Command:** `true`
- **Owner:** backend-developer
- **Done when:** true

## Parallel layout
A per-task worktree fixture: the first line is not "Sequential", so start builds a task worktree.
Sequential — single owner.

## Failure policy
Default: stop after 2 failed attempts (never a 4th).
EOF
( cd "$LDR" && git add -A && git commit -q -m "add plan" && git branch -m main )
LDR_LEAD="$TMP/lead-topic-wt"
( cd "$LDR" && git worktree add -q -b feat/topic "$LDR_LEAD" ) \
  || { echo "ticket: fixture: git worktree add failed for the lead worktree" >&2; exit 1; }
LD_MAIN_BEFORE="$(git -C "$LDR" rev-parse main)"
LD_OUT=$(bash "$TICKET" start "$LDR_LEAD/plan.md" 1 2>"$TMP/lead.err")
LD_BRIEF=$(printf '%s\n' "$LD_OUT" | sed -n '1p' | awk '{print $1}')
LD_WT=$(printf '%s\n' "$LD_OUT" | sed -n '1p' | awk '{print $2}')
( cd "${LD_WT:?}" && git commit -q --allow-empty -m "topic task" )
LD_INT=$(bash "$TICKET" integrate "$LD_WT" --brief "$LD_BRIEF" 2>&1); LD_INT_RC=$?
LD_FIN=$(bash "$TICKET" finish "$LD_WT" 2>&1); LD_FIN_RC=$?
if [ "$LD_INT_RC" -eq 0 ] && [ "$LD_FIN_RC" -eq 0 ] \
  && [ "$(git -C "$LDR_LEAD" log -1 --format=%s)" = "topic task" ] \
  && [ "$(git -C "$LDR" rev-parse main)" = "$LD_MAIN_BEFORE" ] \
  && printf '%s\n' "$LD_FIN" | grep -qF 'close: owner-plan-t1'; then
  echo "  ✓ a Lead in a linked worktree: finish lands on its feature branch, main unmoved, close: names the agent"
else
  echo "  ✗ linked-worktree Lead: integrate rc=$LD_INT_RC finish rc=$LD_FIN_RC: $LD_INT / $LD_FIN"; fail=$((fail+1))
fi

# (3) the recorded base checkout is gone (the Lead's worktree was removed):
# finish fails closed (exit 2), never falling back to another checkout's branch
LD2_OUT=$(bash "$TICKET" start "$LDR_LEAD/plan.md" 1 2>"$TMP/lead2.err")
LD2_WT=$(printf '%s\n' "$LD2_OUT" | sed -n '1p' | awk '{print $2}')
( cd "${LD2_WT:?}" && git commit -q --allow-empty -m "orphan task" )
git -C "$LDR" worktree remove --force "$LDR_LEAD" >/dev/null 2>&1
LD2_FIN=$(bash "$TICKET" finish "$LD2_WT" 2>&1); LD2_RC=$?
if [ "$LD2_RC" -eq 2 ] && printf '%s\n' "$LD2_FIN" | grep -qF 'cannot resolve the base checkout' \
  && [ "$(git -C "$LDR" rev-parse main)" = "$LD_MAIN_BEFORE" ]; then
  echo "  ✓ a recorded base checkout that is gone: finish exits 2, main unmoved"
else
  echo "  ✗ gone base checkout: finish rc=$LD2_RC: $LD2_FIN"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# tracks (spec worktree-track-2026-09-30): one worktree per track, commits
# per task, ONE finish per track, fan-in named once its tracks merge.
# ═══════════════════════════════════════════════════════════════════════

TKR="$TMP/trk-repo"
mkrepo "$TKR"
( cd "$TKR" && git branch -m main )
TKP="$TKR/2026-09-30-trk-demo.md"
cat > "$TKP" <<'EOF'
# Trk Demo Plan

## Parallel layout
Sequential — tracks run one owner each.

## Tracks
- A — lane one: Task 1, Task 2 · branch trk-demo/a-lane-one
- B — lane two: Task 3 · branch trk-demo/b-lane-two
- C — join: Task 4 · branch trk-demo/c-join

## Tasks

### Task 1: build alpha
- **Track:** A
- **Blocked by:** none
- [ ] **Files:** `src/alpha.py`
- [ ] **Command:** `true`
- **Owner:** backend-developer

### Task 2: build beta
- **Track:** A
- **Blocked by:** Task 1
- [ ] **Files:** `src/beta.py`
- [ ] **Command:** `true`
- **Owner:** backend-developer

### Task 3: build gamma
- **Track:** B
- **Blocked by:** none
- [ ] **Files:** `src/gamma.py`
- [ ] **Command:** `true`
- **Owner:** backend-developer

### Task 4: build delta
- **Track:** C
- **Blocked by:** Task 2, Task 3
- [ ] **Files:** `src/delta.py`
- [ ] **Command:** `true`
- **Owner:** backend-developer

## Failure policy
Stop after 2 failed attempts.

## Changes during build
- base sha: init

## Follow-ups
EOF
( cd "$TKR" && git add -A && git commit -q -m "add plan" )
TKR_REAL="$(git -C "$TKR" rev-parse --show-toplevel)"

TK1=$(bash "$TICKET" start "$TKP" 1 2>"$TMP/tk1.err"); TK1_RC=$?
TK1_WT=$(printf '%s\n' "$TK1" | sed -n '1p' | awk '{print $2}')
TK1_BRIEF=$(printf '%s\n' "$TK1" | sed -n '1p' | awk '{print $1}')
TK1_SHIP=$(printf '%s\n' "$TK1" | sed -n '3p')
TK2=$(bash "$TICKET" start "$TKP" 2 2>>"$TMP/tk1.err"); TK2_RC=$?
TK2_WT=$(printf '%s\n' "$TK2" | sed -n '1p' | awk '{print $2}')
TK2_BRIEF=$(printf '%s\n' "$TK2" | sed -n '1p' | awk '{print $1}')
TK2_SHIP=$(printf '%s\n' "$TK2" | sed -n '3p')
TK3=$(bash "$TICKET" start "$TKP" 3 2>>"$TMP/tk1.err"); TK3_RC=$?
TK3_WT=$(printf '%s\n' "$TK3" | sed -n '1p' | awk '{print $2}')
TK3_BRIEF=$(printf '%s\n' "$TK3" | sed -n '1p' | awk '{print $1}')
if [ "$TK1_RC" -eq 0 ] && [ "$TK2_RC" -eq 0 ] && [ "$TK3_RC" -eq 0 ] \
  && [ -n "$TK1_WT" ] && [ "$TK1_WT" = "$TK2_WT" ] && [ "$TK3_WT" != "$TK1_WT" ] && [ -d "$TK3_WT" ] \
  && [ "$(basename "$TK1_WT")" = "trk-repo-wt-trk-demo-a-lane-one" ] \
  && [ "$(git -C "$TKR" worktree list | wc -l | tr -d ' ')" = "3" ]; then
  echo "  ✓ tracks: Task 1 and Task 2 of track A share one worktree, Task 3 (track B) gets its own"
else
  echo "  ✗ tracks: start worktrees wrong: rc=$TK1_RC/$TK2_RC/$TK3_RC wt1=[$TK1_WT] wt2=[$TK2_WT] wt3=[$TK3_WT]"; fail=$((fail+1))
  cat "$TMP/tk1.err" >&2
fi

if [ "$(git -C "$TKR" config --get branch.trk-demo/a-lane-one.rolepod-plan)" = "$TKP" ] \
  && [ "$(git -C "$TKR" config --get branch.trk-demo/b-lane-two.rolepod-plan)" = "$TKP" ] \
  && [ "$(git -C "$TK1_WT" rev-parse --abbrev-ref HEAD)" = "trk-demo/a-lane-one" ]; then
  echo "  ✓ tracks: branch <feature>/<id>-<slug> and branch.<b>.rolepod-plan = the plan path"
else
  echo "  ✗ tracks: branch name or rolepod-plan config wrong"; fail=$((fail+1))
fi

if ! printf '%s\n' "$TK1_SHIP" | grep -qF ' finish ' && ! printf '%s\n' "$TK2_SHIP" | grep -qF ' finish ' \
  && printf '%s\n' "$TK2_SHIP" | grep -qF "git -C '$TK1_WT' commit -m '<subject>' && bash '$TICKET' log '$TKP' 2 --sha"; then
  echo "  ✓ tracks: a track task's ship line is integrate -> git commit -> log, no finish"
else
  echo "  ✗ tracks: ship line still has finish or lost the commit/log chain: [$TK1_SHIP] [$TK2_SHIP]"; fail=$((fail+1))
fi

# Task 1 built, integrated, committed, logged in the track worktree.
mkdir -p "$TK1_WT/src" && echo alpha > "$TK1_WT/src/alpha.txt"
TK1_INT=$(bash "$TICKET" integrate "$TK1_WT" --brief "$TK1_BRIEF" 2>&1); TK1_INT_RC=$?
TK1_INT_TAIL=$(printf '%s\n' "$TK1_INT" | tail -n 1)
( cd "$TK1_WT" && git commit -q -m "task 1 alpha" )
TK1_SHA=$(git -C "$TK1_WT" rev-parse --short HEAD)
TK1_LOG=$(bash "$TICKET" log "$TKP" 1 --sha "$TK1_SHA" --note "alpha done" 2>&1)
if [ "$TK1_INT_RC" -eq 0 ] && ! printf '%s\n' "$TK1_INT_TAIL" | grep -qF ' finish ' \
  && ! printf '%s\n' "$TK1_LOG" | grep -q '^track ' && ! printf '%s\n' "$TK1_LOG" | grep -q '^review:'; then
  echo "  ✓ tracks: log of a non-final track task prints no track range"
else
  echo "  ✗ tracks: Task 1 integrate rc=$TK1_INT_RC tail=[$TK1_INT_TAIL] log=[$TK1_LOG]"; fail=$((fail+1))
fi

# Task 2: commit of Task 1 ahead of base + a dirty tree is NOT ambiguous.
echo beta > "$TK1_WT/src/beta.txt"
TK2_INT=$(bash "$TICKET" integrate "$TK1_WT" --brief "$TK2_BRIEF" 2>&1); TK2_INT_RC=$?
if [ "$TK2_INT_RC" -eq 0 ] && ! printf '%s\n' "$TK2_INT" | grep -q 'ambiguous'; then
  echo "  ✓ tracks: integrate Task 2 passes with Task 1's commit ahead of base and a dirty tree"
else
  echo "  ✗ tracks: integrate Task 2 rc=$TK2_INT_RC: $TK2_INT"; fail=$((fail+1))
fi

# a commit the plan does not name (no logged sha, no "Task N" subject) keeps the refusal
TKB_INT_PRE=$(git -C "$TK3_WT" rev-parse --short HEAD)
mkdir -p "$TK3_WT/src" && echo gamma > "$TK3_WT/src/gamma.txt"
( cd "$TK3_WT" && git add -A && git commit -q -m "misc tweak" )
echo more >> "$TK3_WT/src/gamma.txt"
TK3_AMB=$(bash "$TICKET" integrate "$TK3_WT" --brief "$TK3_BRIEF" 2>&1); TK3_AMB_RC=$?
if [ "$TK3_AMB_RC" -ne 0 ] && printf '%s\n' "$TK3_AMB" | grep -qF 'ambiguous'; then
  echo "  ✓ tracks: a track worktree with an unnamed commit ahead + a dirty tree is still refused"
else
  echo "  ✗ tracks: unnamed commit accepted (rc=$TK3_AMB_RC): $TK3_AMB"; fail=$((fail+1))
fi

# Task 2 committed and logged: the last task of track A prints the track range + writes the diff.
( cd "$TK1_WT" && git commit -q -m "task 2 beta" )
TK2_SHA=$(git -C "$TK1_WT" rev-parse --short HEAD)
# The printed track chain's own --sha expression, run as the Lead would: it
# must read the track worktree (the commit is not on base — no finish ran).
TK2_SHAEXPR=$(printf '%s\n' "$TK2_SHIP" | sed -n 's/.* --sha \("\$(.*)"\) --note.*/\1/p')
TK2_EVAL=$(eval "printf '%s' $TK2_SHAEXPR")
if [ -n "$TK2_SHAEXPR" ] && [ "$TK2_EVAL" = "$TK2_SHA" ] && [ "$TK2_EVAL" != "$(git -C "$TKR" rev-parse --short HEAD)" ]; then
  echo "  ✓ tracks: the printed track ship chain logs the worktree HEAD, not the base HEAD"
else
  echo "  ✗ tracks: printed --sha expr [$TK2_SHAEXPR] gave [$TK2_EVAL], want worktree HEAD $TK2_SHA"; fail=$((fail+1))
fi
LINT_T="$REPO_DIR/core/skills/write-plan/scripts/plan-lint.sh"
TK2_LOG=$(bash "$TICKET" log "$TKP" 2 --sha "$TK2_SHA" --note "beta done" 2>&1)
# the Review: line follows the session mode (lite = two lenses, standard adds the specialists)
TK2_LITE=$(ROLEPOD_SESSION_MODE=lite bash "$TICKET" log "$TKP" 2 --sha "$TK2_SHA" --note "beta done" 2>&1 | grep '^Review: ')
TK2_STD=$(ROLEPOD_SESSION_MODE=standard bash "$TICKET" log "$TKP" 2 --sha "$TK2_SHA" --note "beta done" 2>&1 | grep '^Review: ')
if [ "$(printf '%s\n' "$TK2_LITE" | grep -o 'rolepod-reviewer' | wc -l | tr -d ' ')" = "2" ] \
  && ! printf '%s\n' "$TK2_LITE" | grep -qE 'lens: perf|lens: ui|lens: arch' \
  && printf '%s\n' "$TK2_STD" | grep -q 'lens: perf' \
  && printf '%s\n' "$TK2_STD" | grep -q 'lens: ui' \
  && printf '%s\n' "$TK2_STD" | grep -q 'lens: arch'; then
  echo "  ✓ tracks: the track-end Review: line is the two-lens cell in lite and adds the specialists in standard"
else
  echo "  ✗ tracks: Review: line by mode wrong: lite=[$TK2_LITE] standard=[$TK2_STD]"; fail=$((fail+1))
fi
# a track holding an R4 task (Task 2 on a risk path) prints the mode's R4 cell, not the hard-coded R3 one
TKP4="$TKR/2026-09-30-trk-demo-r4.md"
python3 - "$TKP" "$TKP4" <<'PY'
import sys
t = open(sys.argv[1]).read().replace("`src/beta.py`", "`src/auth/beta.py`", 1)
open(sys.argv[2], "w").write(t)
PY
TK4_STD=$(ROLEPOD_SESSION_MODE=standard bash "$TICKET" log "$TKP4" 2 --sha "$TK2_SHA" --note "beta done" 2>&1 | grep '^Review: ')
TK4_WANT=$(ROLEPOD_SESSION_MODE=standard bash "$LINT_T" --review-set --tier R4)
TK3_WANT=$(ROLEPOD_SESSION_MODE=standard bash "$LINT_T" --review-set --tier R3)
if [ -n "$TK4_STD" ] && [ "$TK4_STD" = "$TK4_WANT" ] && [ "$TK4_STD" != "$TK3_WANT" ] && printf '%s\n' "$TK4_STD" | grep -qF 'lens: security'; then
  echo "  ✓ tracks: a track holding an R4 task prints the R4 Review: cell (security lens), from the track's highest code-task tier"
else
  echo "  ✗ tracks: R4 track Review: line wrong: got=[$TK4_STD] want=[$TK4_WANT]"; fail=$((fail+1))
fi
TK_DIFF="$TKR_REAL/.rolepod/evidence/review/trk-demo-A.diff"
if printf '%s\n' "$TK2_LOG" | grep -qF "track A done — review: main...$TK2_SHA" \
  && [ "$(printf '%s\n' "$TK2_LOG" | grep -A1 -F 'track A done — review:' | sed -n '2p')" = "$(bash "$LINT_T" --review-set --tier R3)" ] \
  && [ "$(printf '%s\n' "$TK2_LOG" | grep -A2 -F 'track A done — review:' | sed -n '3p' | grep -c '^Track end:.*convening-code-review')" = "1" ] \
  && ! printf '%s\n' "$TK2_LOG" | grep -q '^review:' \
  && ! printf '%s\n' "$TK2_LOG" | grep -q '^ready now' \
  && [ -f "$TK_DIFF" ] && grep -q 'src/alpha.txt' "$TK_DIFF" && grep -q 'src/beta.txt' "$TK_DIFF" \
  && grep -q '^+alpha' "$TK_DIFF"; then
  echo "  ✓ tracks: log of the last task prints 'track A done — review: main..<head>' + the track-end sentence and writes <feature>-A.diff"
else
  echo "  ✗ tracks: track-end log wrong: [$TK2_LOG] diff=$TK_DIFF"; fail=$((fail+1))
fi

# finish ONCE: ff-merges both commits, removes the worktree and the branch; Task 4 (needs Task 3's track too) not ready yet.
TKA_BEFORE=$(git -C "$TKR" rev-parse HEAD)
TK_FIN=$(bash "$TICKET" finish "$TK1_WT" 2>&1); TK_FIN_RC=$?
if [ "$TK_FIN_RC" -eq 0 ] && [ "$(git -C "$TKR" rev-parse HEAD)" = "$(git -C "$TKR" rev-parse "$TK2_SHA")" ] \
  && [ "$(git -C "$TKR" rev-list --count "$TKA_BEFORE..HEAD")" = "2" ] \
  && [ ! -d "$TK1_WT" ] && ! git -C "$TKR" show-ref --verify --quiet refs/heads/trk-demo/a-lane-one \
  && ! printf '%s\n' "$TK_FIN" | grep -q '^ready now'; then
  echo "  ✓ tracks: finish merges the whole track by ff once, removes the worktree and branch"
else
  echo "  ✗ tracks: finish rc=$TK_FIN_RC: $TK_FIN"; fail=$((fail+1))
fi

# Track B: reset the unnamed-commit fixture to a clean task commit, log, finish -> fan-in Task 4 ready.
( cd "$TK3_WT" && git checkout -q -- . 2>/dev/null; git reset -q --soft "$TKB_INT_PRE" && git add -A && git commit -q -m "task 3 gamma" )
TK3_SHA=$(git -C "$TK3_WT" rev-parse --short HEAD)
TK3_LOG=$(bash "$TICKET" log "$TKP" 3 --sha "$TK3_SHA" --note "gamma done" 2>&1)
# track A merged first, so base moved: the Lead brings main into track B (a merge commit) before finish
git -C "$TK3_WT" merge -q --no-edit main >/dev/null 2>&1
TK3_FIN_OUT=$(bash "$TICKET" finish "$TK3_WT" 2>&1); TK3_FIN_RC=$?
if printf '%s\n' "$TK3_LOG" | grep -qx 'track B done' \
  && ! printf '%s\n' "$TK3_LOG" | grep -q 'Track end:\|review:' \
  && ! printf '%s\n' "$TK3_LOG" | grep -q '^ready now' \
  && [ "$TK3_FIN_RC" -eq 0 ] \
  && printf '%s\n' "$TK3_FIN_OUT" | grep -qF 'ready now: Task 4 (backend-developer)'; then
  echo "  ✓ tracks: the fan-in task is named ready only once every track it waits for has merged"
else
  echo "  ✗ tracks: fan-in wrong: log=[$TK3_LOG] finish rc=$TK3_FIN_RC [$TK3_FIN_OUT]"; fail=$((fail+1))
fi

# ── single-track plan + another session's lock (a TEMP $HOME, never the real one)
LKH="$TMP/lock-home"
mkdir -p "$LKH"
mk_lock_repo() { # $1 = dir — a Sequential single-track plan, committed
  mkrepo "$1"
  cat > "$1/2026-09-30-lock-demo.md" <<'EOF'
# Lock Demo Plan

## Parallel layout
Sequential — single owner.

## Tasks

### Task 1: build widget
- **Blocked by:** none
- [ ] **Files:** `widget.txt`
- [ ] **Command:** `true`
- **Owner:** backend-developer

## Failure policy
Stop after 2 failed attempts.

## Changes during build
- base sha: init
EOF
  ( cd "$1" && git add -A && git commit -q -m "add plan" )
}
lock_hash() { printf '%s' "$1" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16; }

LKA="$TMP/lock-fresh"; mk_lock_repo "$LKA"
LKA_REAL="$(git -C "$LKA" rev-parse --show-toplevel)"
mkdir -p "$LKH/.rolepod/session-locks/$(lock_hash "$LKA_REAL")"
printf 'claude' > "$LKH/.rolepod/session-locks/$(lock_hash "$LKA_REAL")/other-session.lock"
LKA_OUT=$(env -u CLAUDE_CODE_SESSION_ID -u ROLEPOD_SESSION_ID HOME="$LKH" bash "$TICKET" start "$LKA/2026-09-30-lock-demo.md" 1 2>"$TMP/lka.err"); LKA_RC=$?
LKA_WT=$(printf '%s\n' "$LKA_OUT" | sed -n '1p' | awk '{print $2}')
LKA_BRIEF=$(printf '%s\n' "$LKA_OUT" | sed -n '1p' | awk '{print $1}')
if [ "$LKA_RC" -eq 0 ] && [ "$(basename "$LKA_WT")" = "lock-fresh-wt-lock-demo" ] \
  && [ "$(git -C "$LKA_WT" rev-parse --abbrev-ref HEAD)" = "lock-demo/plan" ] \
  && grep -qE '^`git worktree add -b lock-demo/plan \.\./lock-fresh-wt-lock-demo`' "$LKA_BRIEF" \
  && grep -qE '^- Edit only Files allowed under \.\./lock-fresh-wt-lock-demo, except update the canonical receipt at .+ in the base checkout' "$LKA_BRIEF" \
  && ! grep -q -- '-t1-' "$LKA_BRIEF" \
  && ! printf '%s\n' "$LKA_OUT" | sed -n '3p' | grep -qF ' finish '; then
  echo "  ✓ single-track plan + a fresh lock from another session: the plan runs in <feature>/plan, no finish per task"
else
  echo "  ✗ single-track plan with a live lock: rc=$LKA_RC out=[$LKA_OUT]"; fail=$((fail+1)); cat "$TMP/lka.err" >&2
fi

LKB="$TMP/lock-stale"; mk_lock_repo "$LKB"
LKB_REAL="$(git -C "$LKB" rev-parse --show-toplevel)"
mkdir -p "$LKH/.rolepod/session-locks/$(lock_hash "$LKB_REAL")"
printf 'claude' > "$LKH/.rolepod/session-locks/$(lock_hash "$LKB_REAL")/other-session.lock"
touch -t 202001010000 "$LKH/.rolepod/session-locks/$(lock_hash "$LKB_REAL")/other-session.lock"
LKB_OUT=$(env -u CLAUDE_CODE_SESSION_ID -u ROLEPOD_SESSION_ID HOME="$LKH" bash "$TICKET" start "$LKB/2026-09-30-lock-demo.md" 1 2>"$TMP/lkb.err"); LKB_RC=$?
LKB_BRIEF=$(printf '%s\n' "$LKB_OUT" | sed -n '1p' | awk '{print $1}')
if [ "$LKB_RC" -eq 0 ] && [ "$(git -C "$LKB" worktree list | wc -l | tr -d ' ')" = "1" ] \
  && [ "$(git -C "$LKB" branch --list | wc -l | tr -d ' ')" = "1" ] \
  && grep -q '^## Checkout' "$LKB_BRIEF" && ! grep -q '^## Worktree' "$LKB_BRIEF" \
  && [ "$(printf '%s\n' "$LKB_OUT" | sed -n '3p')" = "on the base checkout: stage with git add -A && git reset -q -- docs/rolepod, the Lead commits with the commit check, then ticket.sh log <plan> <N> --sha <sha>" ] \
  && [ "$(printf '%s\n' "$LKB_OUT" | wc -l | tr -d ' ')" = "4" ]; then
  echo "  ✓ single-track plan + a lock older than 30 min (or none): the base checkout — --main brief, no worktree, one line instead of the ship line"
else
  echo "  ✗ single-track plan with a stale lock: rc=$LKB_RC out=[$LKB_OUT]"; fail=$((fail+1)); cat "$TMP/lkb.err" >&2
fi

# The own lock on any CLI, no env var: session-lifecycle.sh writes the CLI
# name on line 1 and the CLI pid on line 2; a lock whose pid is an ancestor of
# ticket.sh is its own (main checkout), one with an unrelated live pid is a
# foreign session (plan worktree). Temp HOME only.
LKC="$TMP/lock-own"; mk_lock_repo "$LKC"
LKC_REAL="$(git -C "$LKC" rev-parse --show-toplevel)"
mkdir -p "$LKH/.rolepod/session-locks/$(lock_hash "$LKC_REAL")"
printf 'codex\n%s' "$$" > "$LKH/.rolepod/session-locks/$(lock_hash "$LKC_REAL")/own-session.lock"
LKC_OUT=$(env -u CLAUDE_CODE_SESSION_ID -u ROLEPOD_SESSION_ID HOME="$LKH" bash "$TICKET" start "$LKC/2026-09-30-lock-demo.md" 1 2>"$TMP/lkc.err"); LKC_RC=$?
LKC_BRIEF=$(printf '%s\n' "$LKC_OUT" | sed -n '1p' | awk '{print $1}')
if [ "$LKC_RC" -eq 0 ] && grep -q '^## Checkout' "$LKC_BRIEF" && [ "$(git -C "$LKC" worktree list | wc -l | tr -d ' ')" = "1" ]; then
  echo "  ✓ a fresh lock whose line-2 pid is an ancestor is this session's own — base checkout, no env var"
else
  echo "  ✗ own lock by ancestor pid: rc=$LKC_RC out=[$LKC_OUT]"; fail=$((fail+1)); cat "$TMP/lkc.err" >&2
fi
LKD="$TMP/lock-other-pid"; mk_lock_repo "$LKD"
LKD_REAL="$(git -C "$LKD" rev-parse --show-toplevel)"
mkdir -p "$LKH/.rolepod/session-locks/$(lock_hash "$LKD_REAL")"
sleep 300 & LKD_PID=$!
printf 'codex\n%s' "$LKD_PID" > "$LKH/.rolepod/session-locks/$(lock_hash "$LKD_REAL")/other-session.lock"
LKD_OUT=$(env -u CLAUDE_CODE_SESSION_ID -u ROLEPOD_SESSION_ID HOME="$LKH" bash "$TICKET" start "$LKD/2026-09-30-lock-demo.md" 1 2>"$TMP/lkd.err"); LKD_RC=$?
kill "$LKD_PID" 2>/dev/null; wait "$LKD_PID" 2>/dev/null
if [ "$LKD_RC" -eq 0 ] && [ "$(git -C "$LKD" worktree list | wc -l | tr -d ' ')" = "2" ]; then
  echo "  ✓ a fresh lock whose line-2 pid is not an ancestor is a foreign session — plan worktree"
else
  echo "  ✗ foreign lock by pid: rc=$LKD_RC out=[$LKD_OUT]"; fail=$((fail+1)); cat "$TMP/lkd.err" >&2
fi

# log: re-logging an EARLIER task of a finished track prints no track line and
# leaves the lens diff alone; outside a git repo a Tracks plan stays silent.
RLR="$TMP/relog-repo"
mkdir -p "$RLR"
( cd "${RLR:?}" && git init -q . && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init )
RLR_REAL="$(git -C "$RLR" rev-parse --show-toplevel)"
printf 'a\n' > "$RLR/a.py"; ( cd "$RLR" && git add -A && git commit -q -m "task 1" ); RLR_S1="$(git -C "$RLR" rev-parse --short HEAD)"
printf 'b\n' > "$RLR/b.py"; ( cd "$RLR" && git add -A && git commit -q -m "task 2" ); RLR_S2="$(git -C "$RLR" rev-parse --short HEAD)"
cat > "$RLR/relog-plan.md" <<'EOF'
# Relog Plan

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** a.py
- [ ] **Command:** true
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** Task 1
- [ ] **Files:** b.py
- [ ] **Command:** true
- **Owner:** backend-developer

## Parallel layout
Sequential — one track, no worktrees.

## Changes during build

## Follow-ups
EOF
bash "$TICKET" log "$RLR/relog-plan.md" 1 --sha "$RLR_S1" --note "alpha done" >/dev/null 2>&1
RLR_OUT=$(bash "$TICKET" log "$RLR/relog-plan.md" 2 --sha "$RLR_S2" --note "beta done" 2>&1)
RLR_DIFF="$RLR_REAL/.rolepod/evidence/review/relog-plan-plan.diff"
RLR_SUM1="$(cksum < "$RLR_DIFF" 2>/dev/null)"
RLR_OUT1=$(bash "$TICKET" log "$RLR/relog-plan.md" 1 --sha "$RLR_S1" --note "alpha done again" 2>&1)
RLR_SUM2="$(cksum < "$RLR_DIFF" 2>/dev/null)"
if printf '%s\n' "$RLR_OUT" | grep -qF "track plan done — review: ${RLR_S1}^...${RLR_S2}; lens diff: $RLR_DIFF" \
  && ! printf '%s\n' "$RLR_OUT1" | grep -q 'track plan done' && [ -n "$RLR_SUM1" ] && [ "$RLR_SUM1" = "$RLR_SUM2" ] && grep -q 'b.py' "$RLR_DIFF"; then
  echo "  ✓ log: re-logging an earlier task of a finished track prints no track line and keeps the lens diff"
else
  echo "  ✗ log relog: out=[$RLR_OUT] relog=[$RLR_OUT1] diff-sum $RLR_SUM1 vs $RLR_SUM2"; fail=$((fail+1))
fi
cat > "$TMP/2026-09-30-nogit-tracks.md" <<'EOF'
# Nogit Tracks Plan

## Tasks

### Task 1: alpha
- **Track:** A
- **Blocked by:** none
- [ ] **Files:** a.py
- [ ] **Command:** true
- **Owner:** backend-developer

### Task 2: beta
- **Track:** A
- **Blocked by:** 1
- [x] **Files:** b.py
- [x] **Command:** true
- **Owner:** backend-developer

## Tracks
- A — alpha: Task 1, Task 2 · branch nogit-tracks/a-alpha

## Parallel layout
Sequential — one track.

## Changes during build

## Follow-ups
EOF
NGT_OUT=$(bash "$TICKET" log "$TMP/2026-09-30-nogit-tracks.md" 1 --sha abc1234 --note "alpha done" 2>&1); NGT_RC=$?
if [ "$NGT_RC" -eq 0 ] && ! printf '%s\n' "$NGT_OUT" | grep -qE 'HEAD\.\.\.|^track |^Track end'; then
  echo "  ✓ log: a Tracks plan outside a git repo stays silent (no HEAD...sha line)"
else
  echo "  ✗ log outside git printed a track line: rc=$NGT_RC [$NGT_OUT]"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# the real repo's HEAD and worktree registry stayed untouched — unconditional:
# a fixture write that lands on the real repo instead of its own $TMP fixture
# must never go unnoticed (2026-09-22: 4b6c061f, b258f2b9 — see the header).
# ═══════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════
# task records — C2 start creates docs/rolepod/tasks/<plan>/task-NN.md,
# C3 log keeps the plan bullet to one short line that points at it
# ═══════════════════════════════════════════════════════════════════════

FR_REAL2="$(git -C "$FR" rev-parse --show-toplevel)"
TF="$FR_REAL2/docs/rolepod/tasks/plan/task-01.md"
if [ -f "$TF" ] \
  && [ "$(sed -n '1p' "$TF")" = "# Task 1 — build the widget" ] \
  && [ "$(sed -n '2p' "$TF")" = "Base: $(git -C "$FR" rev-parse HEAD)" ] \
  && [ "$(grep '^## ' "$TF" | paste -sd'|' -)" = "## Decision brief|## Verify status|## Handoff|## Reviews|## Lead notes" ] \
  && [ "$(grep '^### ' "$TF" | head -6 | paste -sd'|' -)" = "### Change|### Tests added / changed|### Commands|### Scope check|### Concerns|### Author fix closure" ] \
  && grep -q '^### Owner status$' "$TF" \
  && grep -q '^COMPLETED | PARTIAL | BLOCKED$' "$TF" \
  && grep -q '^VERIFIED | PARTIAL | UNVERIFIED$' "$TF"; then
  echo "  ✓ start creates the task file with separate owner and Verify status fields"
else
  echo "  ✗ start task file wrong:"; cat "$TF" 2>&1; fail=$((fail+1))
fi
printf 'owner wrote this\n' >> "$TF"
bash "$TICKET" start "$FR/plan.md" 1 >/dev/null 2>&1
if grep -qx 'owner wrote this' "$TF"; then
  echo "  ✓ start never overwrites an existing task file"
else
  echo "  ✗ start overwrote the task file"; fail=$((fail+1))
fi

TRP="$TMP/taskrec-repo"; mkrepo "$TRP"
cat > "$TRP/rec-plan.md" <<'EOF'
# Rec Plan

## Tasks

### Task 1: alpha
- [ ] Files: a.txt
- [ ] Command: true

## Changes during build

## Follow-ups
EOF
LONG="$(printf 'x%.0s' $(seq 1 301))"
OK300="$(printf 'y%.0s' $(seq 1 300))"
bash "$TICKET" log "$TRP/rec-plan.md" 1 --sha abc123 --note "$LONG" >/dev/null 2>"$TMP/rec-long.err"; RC_LONG=$?
bash "$TICKET" log "$TRP/rec-plan.md" 1 --sha abc123 --note $'two\nlines' >/dev/null 2>"$TMP/rec-nl.err"; RC_NL=$?
if [ "$RC_LONG" -eq 2 ] && [ "$RC_NL" -eq 2 ] \
  && grep -q 'Fix:' "$TMP/rec-long.err" && grep -q 'task file' "$TMP/rec-long.err" \
  && ! grep -q 'Task 1 (' "$TRP/rec-plan.md" && grep -q '^- \[ \]' "$TRP/rec-plan.md"; then
  echo "  ✓ log rejects a note over 300 chars or with a newline (exit 2, fact -> Fix), plan untouched"
else
  echo "  ✗ log note limit wrong: long=$RC_LONG nl=$RC_NL err=$(cat "$TMP/rec-long.err")"; fail=$((fail+1))
fi
bash "$TICKET" log "$TRP/rec-plan.md" 1 --sha abc123 --note "$OK300" >/dev/null 2>&1; RC_OK=$?
if [ "$RC_OK" -eq 0 ] && grep -qF -- "- Task 1 (\`abc123\`): $OK300" "$TRP/rec-plan.md" \
  && grep -qF -- '-> docs/rolepod/tasks/rec-plan/task-01.md' "$TRP/rec-plan.md" \
  && [ "$(grep -c 'Task 1 (' "$TRP/rec-plan.md")" = "1" ]; then
  echo "  ✓ log accepts a 300-char note and ends the bullet with the task file path"
else
  echo "  ✗ log bullet wrong (rc=$RC_OK): $(grep 'Task 1 (' "$TRP/rec-plan.md" | cut -c1-80)"; fail=$((fail+1))
fi

# Reviews: the .md reports written since the owner brief become pointers under
# ## Reviews (report names are the owner's pick, so none is copied); .diff never.
TRR="$TMP/taskrec-rev"; mkrepo "$TRR"
sed 's/^# Rec Plan/# Rev Plan/' "$TRP/rec-plan.md" | grep -v 'Task 1 (' > "$TRR/rev-plan.md"
TRR_REAL="$(git -C "$TRR" rev-parse --show-toplevel)"
mkdir -p "$TRR/docs/rolepod/handoffs" "$TRR/docs/rolepod/tasks/rev-plan" "$TRR/.rolepod/evidence/review"
printf '# Task 1 — alpha\nBase: x\n\n## Decision brief\n\n## Handoff\n\n## Reviews\n\n## Lead notes\n' > "$TRR/docs/rolepod/tasks/rev-plan/task-01.md"
printf 'brief\n' > "$TRR/docs/rolepod/handoffs/rev-plan-t1-owner.md"
sleep 1
printf 'VERDICT: APPROVED\n' > "$TRR/.rolepod/evidence/review/t1-universal-reviewer.md"
printf 'diff\n' > "$TRR/.rolepod/evidence/review/t1.diff"
bash "$TICKET" log "$TRR/rev-plan.md" 1 --sha abc123 --note "ok" >/dev/null 2>&1
if awk '/^## Reviews/{f=1;next} /^## /{f=0} f' "$TRR_REAL/docs/rolepod/tasks/rev-plan/task-01.md" | grep -qxF -- '- .rolepod/evidence/review/t1-universal-reviewer.md' \
  && ! grep -q 't1.diff' "$TRR_REAL/docs/rolepod/tasks/rev-plan/task-01.md"; then
  echo "  ✓ log points ## Reviews at the new review .md reports, never a .diff"
else
  echo "  ✗ log Reviews pointers wrong:"; cat "$TRR_REAL/docs/rolepod/tasks/rev-plan/task-01.md"; fail=$((fail+1))
fi

# Named reports (<plan-slug>-task<N>-<lens|role>.md): each task lists only its own,
# a legacy unprefixed .md is ignored while a named one exists.
TRN="$TMP/taskrec-named"; mkrepo "$TRN"
awk '{ print } /^- \[.\] Command: true/ { print ""; print "### Task 2: beta"; print "- [ ] Files: b.txt"; print "- [ ] Command: true" }' "$TRR/rev-plan.md" > "$TRN/rev-plan.md"
TRN_REAL="$(git -C "$TRN" rev-parse --show-toplevel)"
mkdir -p "$TRN/docs/rolepod/handoffs" "$TRN/docs/rolepod/tasks/rev-plan" "$TRN/.rolepod/evidence/review"
for n in 1 2; do
  printf '# Task %s — alpha\nBase: x\n\n## Decision brief\n\n## Handoff\n\n## Reviews\n\n## Lead notes\n' "$n" > "$TRN/docs/rolepod/tasks/rev-plan/task-0$n.md"
  printf 'brief\n' > "$TRN/docs/rolepod/handoffs/rev-plan-t$n-owner.md"
done
sleep 1
for f in rev-plan-task1-spec rev-plan-task2-spec owner-pick; do printf 'VERDICT: APPROVED\n' > "$TRN/.rolepod/evidence/review/$f.md"; done
bash "$TICKET" log "$TRN/rev-plan.md" 1 --sha abc123 --note "ok" >/dev/null 2>&1
T1F="$TRN_REAL/docs/rolepod/tasks/rev-plan/task-01.md"
if grep -qxF -- '- .rolepod/evidence/review/rev-plan-task1-spec.md' "$T1F" \
  && ! grep -q 'rev-plan-task2-spec' "$T1F" && ! grep -q 'owner-pick' "$T1F"; then
  echo "  ✓ log lists only this task's named review reports"
else
  echo "  ✗ log named-report scoping wrong:"; cat "$T1F"; fail=$((fail+1))
fi
bash "$TICKET" log "$TRN/rev-plan.md" 2 --sha abc123 --note "ok" >/dev/null 2>&1
T2F="$TRN_REAL/docs/rolepod/tasks/rev-plan/task-02.md"
if grep -qxF -- '- .rolepod/evidence/review/rev-plan-task2-spec.md' "$T2F" \
  && ! grep -q 'rev-plan-task1-spec' "$T2F"; then
  echo "  ✓ log Task 2 lists only task2's report"
else
  echo "  ✗ log Task 2 report scoping wrong:"; cat "$T2F"; fail=$((fail+1))
fi

# No file carries the prefix: the newer legacy .md is listed, a sibling task's is not.
TRL="$TMP/taskrec-legacy"; mkrepo "$TRL"
cp "$TRR/rev-plan.md" "$TRL/rev-plan.md"
TRL_REAL="$(git -C "$TRL" rev-parse --show-toplevel)"
mkdir -p "$TRL/docs/rolepod/handoffs" "$TRL/docs/rolepod/tasks/rev-plan" "$TRL/.rolepod/evidence/review"
printf '# Task 1 — alpha\nBase: x\n\n## Decision brief\n\n## Handoff\n\n## Reviews\n\n## Lead notes\n' > "$TRL/docs/rolepod/tasks/rev-plan/task-01.md"
printf 'brief\n' > "$TRL/docs/rolepod/handoffs/rev-plan-t1-owner.md"
sleep 1
printf 'VERDICT: APPROVED\n' > "$TRL/.rolepod/evidence/review/owner-pick.md"
printf 'VERDICT: REJECTED\n' > "$TRL/.rolepod/evidence/review/rev-plan-task2-spec.md"
bash "$TICKET" log "$TRL/rev-plan.md" 1 --sha abc123 --note "ok" >/dev/null 2>&1
TLF="$TRL_REAL/docs/rolepod/tasks/rev-plan/task-01.md"
if grep -qxF -- '- .rolepod/evidence/review/owner-pick.md' "$TLF" && ! grep -q 'rev-plan-task2' "$TLF"; then
  echo "  ✓ log falls back to a newer legacy report and skips a sibling task's"
else
  echo "  ✗ log legacy fallback wrong:"; cat "$TLF"; fail=$((fail+1))
fi

# ── finish keeps worktree-only review reports (.md) in the base evidence dir
FRV="$TMP/finish-reports-repo"; mkrepo "$FRV"
( cd "${FRV:?}" && git worktree add -q -b finish-reports-branch "$TMP/finish-reports-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for \$FRV/finish-reports-branch" >&2; exit 1; }
( cd "$TMP/finish-reports-wt" && git commit -q --allow-empty -m "owner commit" )
printf '.rolepod/\n' >> "$FRV/.git/info/exclude"   # as the real .gitignore does
mkdir -p "$TMP/finish-reports-wt/.rolepod/evidence/review" "$FRV/.rolepod/evidence/review"
printf 'VERDICT: APPROVED\n' > "$TMP/finish-reports-wt/.rolepod/evidence/review/wt-only.md"
printf 'worktree copy\n' > "$TMP/finish-reports-wt/.rolepod/evidence/review/both.md"
printf 'base copy\n' > "$FRV/.rolepod/evidence/review/both.md"
printf 'd\n' > "$TMP/finish-reports-wt/.rolepod/evidence/review/wt.diff"
bash "$TICKET" finish "$TMP/finish-reports-wt" >/dev/null 2>&1; FRV_RC=$?
if [ "$FRV_RC" -eq 0 ] && [ ! -d "$TMP/finish-reports-wt" ] \
  && grep -q 'VERDICT: APPROVED' "$FRV/.rolepod/evidence/review/wt-only.md" \
  && [ "$(cat "$FRV/.rolepod/evidence/review/both.md")" = "base copy" ] \
  && [ ! -e "$FRV/.rolepod/evidence/review/wt.diff" ]; then
  echo "  ✓ finish copies a worktree-only review .md to the base before removal, never overwrites, skips .diff"
else
  echo "  ✗ finish report copy wrong (rc=$FRV_RC)"; ls "$FRV/.rolepod/evidence/review" 2>&1; fail=$((fail+1))
fi

# A worktree-only canonical receipt is copied to base; conflicting receipts stop cleanup.
FRC="$TMP/finish-receipt-repo"; mkrepo "$FRC"
( cd "${FRC:?}" && git worktree add -q -b finish-receipt-branch "$TMP/finish-receipt-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for receipt preservation" >&2; exit 1; }
( cd "$FRC" && printf 'docs/rolepod/\n' >> .git/info/exclude )
( cd "$TMP/finish-receipt-wt" && git commit -q --allow-empty -m "receipt owner commit" )
mkdir -p "$TMP/finish-receipt-wt/docs/rolepod/tasks/receipt-plan"
printf '# canonical receipt\n' > "$TMP/finish-receipt-wt/docs/rolepod/tasks/receipt-plan/task-01.md"
bash "$TICKET" finish "$TMP/finish-receipt-wt" >"$TMP/finish-receipt.out" 2>&1; FRC_RC=$?
if [ "$FRC_RC" -eq 0 ] && [ ! -d "$TMP/finish-receipt-wt" ] \
  && [ "$(cat "$FRC/docs/rolepod/tasks/receipt-plan/task-01.md")" = "# canonical receipt" ]; then
  echo "  ✓ finish preserves a worktree-only canonical receipt to the same base path before cleanup"
else
  echo "  ✗ finish did not preserve the canonical receipt (rc=$FRC_RC): $(cat "$TMP/finish-receipt.out")"; fail=$((fail+1))
fi

FRC2="$TMP/finish-receipt-collision-repo"; mkrepo "$FRC2"
( cd "${FRC2:?}" && git worktree add -q -b finish-receipt-collision-branch "$TMP/finish-receipt-collision-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for receipt collision" >&2; exit 1; }
( cd "$FRC2" && printf 'docs/rolepod/\n' >> .git/info/exclude )
( cd "$TMP/finish-receipt-collision-wt" && git commit -q --allow-empty -m "receipt collision owner commit" )
mkdir -p "$TMP/finish-receipt-collision-wt/docs/rolepod/tasks/receipt-plan" "$FRC2/docs/rolepod/tasks/receipt-plan"
printf 'worktree receipt\n' > "$TMP/finish-receipt-collision-wt/docs/rolepod/tasks/receipt-plan/task-01.md"
printf 'base receipt\n' > "$FRC2/docs/rolepod/tasks/receipt-plan/task-01.md"
bash "$TICKET" finish "$TMP/finish-receipt-collision-wt" >/dev/null 2>&1; FRC2_RC=$?
if [ "$FRC2_RC" -eq 0 ] && [ ! -d "$TMP/finish-receipt-collision-wt" ] \
  && [ "$(cat "$FRC2/docs/rolepod/tasks/receipt-plan/task-01.md")" = "base receipt" ] \
  && [ "$(cat "$FRC2/docs/rolepod/tasks/receipt-plan/task-01.md.from-finish-receipt-collision-branch")" = "worktree receipt" ] \
  && ! git -C "$FRC2" rev-parse -q --verify finish-receipt-collision-branch >/dev/null; then
  echo "  ✓ B6 finish keeps a differing receipt as .from-<branch>, never overwrites, and completes"
else
  echo "  ✗ B6 differing receipt wrong (rc=$FRC2_RC)"; fail=$((fail+1))
fi

# T6: docs written in a track worktree survive finish in both modes; dirt outside docs and a
# failed copy never reach `worktree remove --force`.
FDM="$TMP/finish-docs-ign-repo"; mkrepo "$FDM"
( cd "${FDM:?}" && git worktree add -q -b finish-docs-ign-branch "$TMP/finish-docs-ign-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for docs ignored" >&2; exit 1; }
( cd "$FDM" && printf 'docs/rolepod/\n' >> .git/info/exclude )
( cd "$TMP/finish-docs-ign-wt" && git commit -q --allow-empty -m "docs ignored owner commit" )
mkdir -p "$TMP/finish-docs-ign-wt/docs/rolepod/plans"
printf 'plan body\n' > "$TMP/finish-docs-ign-wt/docs/rolepod/plans/p.md"
bash "$TICKET" finish "$TMP/finish-docs-ign-wt" >/dev/null 2>&1; FDM_RC=$?
if [ "$FDM_RC" -eq 0 ] && [ ! -d "$TMP/finish-docs-ign-wt" ] \
  && [ "$(cat "$FDM/docs/rolepod/plans/p.md")" = "plan body" ] \
  && ! git -C "$FDM" rev-parse -q --verify finish-docs-ign-branch >/dev/null; then
  echo "  ✓ finish rescues a plan written only in the worktree (docs ignored): base has it, worktree + branch gone"
else
  echo "  ✗ finish docs-ignored rescue wrong (rc=$FDM_RC)"; fail=$((fail+1))
fi

FDT="$TMP/finish-docs-trk-repo"; mkrepo "$FDT"
bash "$REPO_DIR/hooks/lib/docs-mode.sh" -C "$FDT" track >/dev/null 2>&1
( cd "$FDT" && git add -A && git commit -q --allow-empty -m "docs tracked" )
if [ "$(bash "$REPO_DIR/hooks/lib/docs-mode.sh" -C "$FDT" status 2>/dev/null)" = "tracked" ]; then
  echo "  ✓ docs tracked fixture: docs-mode.sh status prints tracked"
else
  echo "  ✗ docs tracked fixture is not in tracked mode: $(bash "$REPO_DIR/hooks/lib/docs-mode.sh" -C "$FDT" status 2>&1)"; fail=$((fail+1))
fi
( cd "${FDT:?}" && git worktree add -q -b finish-docs-trk-branch "$TMP/finish-docs-trk-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for docs tracked" >&2; exit 1; }
( cd "$TMP/finish-docs-trk-wt" && git commit -q --allow-empty -m "docs tracked owner commit" )
mkdir -p "$TMP/finish-docs-trk-wt/docs/rolepod/plans"
printf 'tracked plan\n' > "$TMP/finish-docs-trk-wt/docs/rolepod/plans/p.md"
bash "$TICKET" finish "$TMP/finish-docs-trk-wt" >/dev/null 2>&1; FDT_RC=$?
if [ "$FDT_RC" -eq 0 ] && [ ! -d "$TMP/finish-docs-trk-wt" ] \
  && [ "$(cat "$FDT/docs/rolepod/plans/p.md")" = "tracked plan" ] \
  && ! git -C "$FDT" rev-parse -q --verify finish-docs-trk-branch >/dev/null; then
  echo "  ✓ finish passes with an uncommitted plan under docs/rolepod (docs tracked): not dirt, plan saved"
else
  echo "  ✗ finish docs-tracked rescue wrong (rc=$FDT_RC)"; fail=$((fail+1))
fi

# no docs-mode.sh beside ticket.sh (DOCS_MODE empty): no rescue, no --force — a clean worktree is removed,
# one holding an untracked docs file is kept with the "never --force" hint (today's behavior)
NDM="$TMP/finish-nodm"; mkdir -p "$NDM/bin"; cp "$TICKET" "$NDM/bin/ticket.sh"
NDR="$NDM/repo"; mkrepo "$NDR"
( cd "$NDR" && git worktree add -q -b finish-nodm-clean "$NDM/wt-clean" )
( cd "$NDM/wt-clean" && git commit -q --allow-empty -m "nodm clean" )
bash "$NDM/bin/ticket.sh" finish "$NDM/wt-clean" >/dev/null 2>&1; NDC_RC=$?
( cd "$NDR" && git worktree add -q -b finish-nodm-dirty "$NDM/wt-dirty" )
( cd "$NDM/wt-dirty" && git commit -q --allow-empty -m "nodm dirty" )
mkdir -p "$NDM/wt-dirty/docs/rolepod"; echo keep > "$NDM/wt-dirty/docs/rolepod/n.md"
NDD_ERR=$(bash "$NDM/bin/ticket.sh" finish "$NDM/wt-dirty" 2>&1 >/dev/null); NDD_RC=$?
if [ "$NDC_RC" -eq 0 ] && [ ! -d "$NDM/wt-clean" ] \
  && [ "$NDD_RC" -ne 0 ] && [ -f "$NDM/wt-dirty/docs/rolepod/n.md" ] && printf '%s\n' "$NDD_ERR" | grep -qF 'never --force' \
  && ! printf '%s\n' "$NDD_ERR" | grep -q 'docs rescue'; then
  echo "  ✓ finish without docs-mode.sh: no rescue, no --force — clean worktree removed, dirty one kept with the never --force hint"
else
  echo "  ✗ finish no-DOCS_MODE path wrong: clean rc=$NDC_RC dirty rc=$NDD_RC err=[$NDD_ERR]"; fail=$((fail+1))
fi

FDB="$TMP/finish-docs-dirt-repo"; mkrepo "$FDB"
( cd "${FDB:?}" && git worktree add -q -b finish-docs-dirt-branch "$TMP/finish-docs-dirt-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for docs dirt" >&2; exit 1; }
( cd "$FDB" && printf 'docs/rolepod/\n' >> .git/info/exclude )
mkdir -p "$TMP/finish-docs-dirt-wt/docs/rolepod/plans"
printf 'keep me\n' > "$TMP/finish-docs-dirt-wt/docs/rolepod/plans/p.md"
printf 'stray code\n' > "$TMP/finish-docs-dirt-wt/stray.py"
bash "$TICKET" finish "$TMP/finish-docs-dirt-wt" >/dev/null 2>&1; FDB_RC=$?
if [ "$FDB_RC" -eq 1 ] && [ -f "$TMP/finish-docs-dirt-wt/stray.py" ] \
  && [ "$(cat "$TMP/finish-docs-dirt-wt/docs/rolepod/plans/p.md")" = "keep me" ] \
  && [ ! -e "$FDB/docs/rolepod/plans/p.md" ]; then
  echo "  ✓ B1 finish refuses dirt outside docs/rolepod before any copy; worktree intact"
else
  echo "  ✗ B1 dirt outside docs wrong (rc=$FDB_RC)"; fail=$((fail+1))
fi

FDC="$TMP/finish-docs-copyfail-repo"; mkrepo "$FDC"
( cd "${FDC:?}" && git worktree add -q -b finish-docs-copyfail-branch "$TMP/finish-docs-copyfail-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for docs copy fail" >&2; exit 1; }
( cd "$FDC" && printf 'docs/rolepod/\n' >> .git/info/exclude )
( cd "$TMP/finish-docs-copyfail-wt" && git commit -q --allow-empty -m "docs copyfail owner commit" )
mkdir -p "$TMP/finish-docs-copyfail-wt/docs/rolepod/plans" "$FDC/docs/rolepod"
printf 'precious\n' > "$TMP/finish-docs-copyfail-wt/docs/rolepod/plans/p.md"
printf 'in the way\n' > "$FDC/docs/rolepod/plans"   # a file where the base needs a directory: the copy fails
bash "$TICKET" finish "$TMP/finish-docs-copyfail-wt" >/dev/null 2>&1; FDC_RC=$?
if [ "$FDC_RC" -eq 1 ] && [ -d "$TMP/finish-docs-copyfail-wt" ] \
  && [ "$(cat "$TMP/finish-docs-copyfail-wt/docs/rolepod/plans/p.md")" = "precious" ]; then
  echo "  ✓ B4 a failed docs copy exits 1 and the worktree is not removed"
else
  echo "  ✗ B4 failed copy wrong (rc=$FDC_RC)"; fail=$((fail+1))
fi

# A11: a base receipt still holding the unfilled skeleton `start` wrote is no
# collision — the owner's receipt replaces it and finish exits 0.
FRC3="$TMP/finish-receipt-skeleton-repo"; mkrepo "$FRC3"
( cd "${FRC3:?}" && git worktree add -q -b finish-receipt-skeleton-branch "$TMP/finish-receipt-skeleton-wt" ) \
  || { echo "ticket: fixture: git worktree add failed for receipt skeleton" >&2; exit 1; }
( cd "$FRC3" && printf 'docs/rolepod/\n' >> .git/info/exclude )
( cd "$TMP/finish-receipt-skeleton-wt" && git commit -q --allow-empty -m "receipt skeleton owner commit" )
mkdir -p "$TMP/finish-receipt-skeleton-wt/docs/rolepod/tasks/receipt-plan" "$FRC3/docs/rolepod/tasks/receipt-plan"
printf '# Task 1 — x\nBase: y\n\n## Decision brief\n\n### Owner status\nCOMPLETED | PARTIAL | BLOCKED\n\n## Verify status\nVERIFIED | PARTIAL | UNVERIFIED\n' > "$FRC3/docs/rolepod/tasks/receipt-plan/task-01.md"
printf 'filled receipt\n' > "$TMP/finish-receipt-skeleton-wt/docs/rolepod/tasks/receipt-plan/task-01.md"
bash "$TICKET" finish "$TMP/finish-receipt-skeleton-wt" >/dev/null 2>&1; FRC3_RC=$?
if [ "$FRC3_RC" -eq 0 ] && [ ! -d "$TMP/finish-receipt-skeleton-wt" ] \
  && [ "$(cat "$FRC3/docs/rolepod/tasks/receipt-plan/task-01.md")" = "filled receipt" ]; then
  echo "  ✓ finish replaces an unfilled skeleton receipt with the owner's receipt (exit 0)"
else
  echo "  ✗ finish skeleton receipt wrong (rc=$FRC3_RC)"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# review-diff (C67) — the frozen diff, H1 and the fix delta, own temp repo
# ═══════════════════════════════════════════════════════════════════════
echo "review-diff cases:"
RD="$TMP/rd-repo"
mkrepo "$RD"
( cd "$RD" && printf '.rolepod/\n' >> .git/info/exclude && printf 'one\n' > a.txt && git add -A && git commit -q -m base )
RD_TOP="$(cd "$RD" && git rev-parse --show-toplevel)"
( cd "$RD" && printf 'two\n' >> a.txt && git add a.txt && printf 'three\n' >> a.txt \
  && printf 'fresh\n' > untracked-new.txt \
  && mkdir -p docs/rolepod && printf 'skip\n' > docs/rolepod/x.md \
  && printf 'skip\n' > a.lock && printf 'skip\n' > package-lock.json && printf 'skip\n' > pnpm-lock.yaml )
RD_HEAD0="$(git -C "$RD" rev-parse HEAD)"
RD_OUT="$(cd "$RD" && bash "$TICKET" review-diff start t2-demo 2>"$TMP/rd-err")"; RD_RC=$?
RD_FILE="$RD_TOP/.rolepod/evidence/review/t2-demo.diff"
RD_H1="$(git -C "$RD" write-tree)"
if [ "$RD_RC" -eq 0 ] \
  && [ "$(printf '%s\n' "$RD_OUT" | sed -n 1p)" = "diff: $RD_FILE" ] \
  && [ "$(printf '%s\n' "$RD_OUT" | sed -n 2p)" = "H1: $RD_H1" ] \
  && printf '%s' "$RD_H1" | /usr/bin/grep -Eq '^[0-9a-f]{40}$' \
  && [ -f "$RD_FILE" ] \
  && [ "$(sed -n 1p "$RD_FILE" | /usr/bin/grep -c ' | ')" -eq 1 ] \
  && /usr/bin/grep -q '^+three$' "$RD_FILE" && /usr/bin/grep -q '^+fresh$' "$RD_FILE" \
  && [ "$(/usr/bin/grep -n ' | ' "$RD_FILE" | head -1 | cut -d: -f1)" -lt "$(/usr/bin/grep -n '^diff --git' "$RD_FILE" | head -1 | cut -d: -f1)" ]; then
  echo "  ✓ D1 start on staged + unstaged + untracked: diff path, H1 == write-tree, stat block then diff"
else
  echo "  ✗ D1 start wrong (rc=$RD_RC out=$RD_OUT)"; fail=$((fail+1))
fi
if ! /usr/bin/grep -qE 'docs/rolepod|a\.lock|package-lock|pnpm-lock' "$RD_FILE"; then
  echo "  ✓ D2 start leaves docs/rolepod and lockfiles out of the diff"
else
  echo "  ✗ D2 an excluded path is in the diff"; fail=$((fail+1))
fi
RD_EMPTY="$TMP/rd-clean"
mkrepo "$RD_EMPTY"
( cd "$RD_EMPTY" && bash "$TICKET" review-diff start t2-demo >"$TMP/rd-o" 2>"$TMP/rd-e" ); RD3_RC=$?
if [ "$RD3_RC" -eq 1 ] && [ "$(cat "$TMP/rd-e")" = "ticket: review-diff: empty diff" ] \
  && [ ! -e "$RD_EMPTY/.rolepod/evidence/review/t2-demo.diff" ]; then
  echo "  ✓ D3 start on a clean tree: exit 1, one stderr line, no file"
else
  echo "  ✗ D3 clean tree wrong (rc=$RD3_RC err=$(cat "$TMP/rd-e"))"; fail=$((fail+1))
fi
( cd "$RD" && printf 'later-edit\n' > later.txt )
RD4_OUT="$(cd "$RD" && bash "$TICKET" review-diff delta t2-demo "$RD_H1" 2 2>/dev/null)"; RD4_RC=$?
RD4_FILE="$RD_TOP/.rolepod/evidence/review/t2-demo-r2.diff"
if [ "$RD4_RC" -eq 0 ] \
  && [ "$(printf '%s\n' "$RD4_OUT" | sed -n 1p)" = "diff: $RD4_FILE" ] \
  && [ "$(printf '%s\n' "$RD4_OUT" | sed -n 2p)" = "H2: $(git -C "$RD" write-tree)" ] \
  && /usr/bin/grep -q '^+later-edit$' "$RD4_FILE" \
  && ! /usr/bin/grep -qE '^\+(three|fresh)$' "$RD4_FILE"; then
  echo "  ✓ D4 delta: -r2 file holds only the new edit, H2 printed"
else
  echo "  ✗ D4 delta wrong (rc=$RD4_RC out=$RD4_OUT)"; fail=$((fail+1))
fi
RD5_BAD=0
RD_BADTREE="$(git -C "$RD" rev-parse HEAD)"
for args in "t2-demo $RD_H1 1" "t2-demo $RD_H1 5" "t2-demo $RD_H1 x" "t2-demo deadbeef 3" "t2-demo $RD_BADTREE 3" "bad/name $RD_H1 3" "bad name $RD_H1 3" "t2-demo $RD_H1" "t2-demo" ""; do
  # shellcheck disable=SC2086
  if [ "$args" = "bad name $RD_H1 3" ]; then
    ( cd "$RD" && bash "$TICKET" review-diff delta "bad name" "$RD_H1" 3 >/dev/null 2>"$TMP/rd-e" ); rc=$?
  else
    # shellcheck disable=SC2086
    ( cd "$RD" && bash "$TICKET" review-diff delta $args >/dev/null 2>"$TMP/rd-e" ); rc=$?
  fi
  [ "$rc" -eq 2 ] && [ "$(wc -l < "$TMP/rd-e" | tr -d ' ')" -eq 1 ] || { RD5_BAD=1; echo "    bad input [$args] rc=$rc"; }
done
( cd "$RD" && bash "$TICKET" review-diff start "bad name" >/dev/null 2>"$TMP/rd-e" ); rc=$?
[ "$rc" -eq 2 ] || { RD5_BAD=1; echo "    start bad name rc=$rc"; }
( cd "$RD" && bash "$TICKET" review-diff start >/dev/null 2>"$TMP/rd-e" ); rc=$?
[ "$rc" -eq 2 ] || { RD5_BAD=1; echo "    start no name rc=$rc"; }
if [ "$RD5_BAD" -eq 0 ] && [ ! -e "$RD_TOP/.rolepod/evidence/review/t2-demo-r1.diff" ] \
  && [ ! -e "$RD_TOP/.rolepod/evidence/review/t2-demo-r5.diff" ] \
  && [ ! -e "$RD_TOP/.rolepod/evidence/review/t2-demo-r3.diff" ]; then
  echo "  ✓ D5 bad k, non-tree H1, bad name, missing argument: exit 2, one stderr line, no file"
else
  echo "  ✗ D5 bad input handling wrong"; fail=$((fail+1))
fi
RD_H2="$(git -C "$RD" write-tree)"
( cd "$RD" && bash "$TICKET" review-diff delta t2-demo "$RD_H2" 3 >/dev/null 2>"$TMP/rd-e" ); rc=$?
if [ "$rc" -eq 1 ] && [ "$(cat "$TMP/rd-e")" = "ticket: review-diff: empty diff" ] \
  && [ ! -e "$RD_TOP/.rolepod/evidence/review/t2-demo-r3.diff" ]; then
  echo "  ✓ D4b delta with no change since H1: exit 1, empty diff, no file"
else
  echo "  ✗ D4b empty delta wrong (rc=$rc)"; fail=$((fail+1))
fi
if [ "$(git -C "$RD" rev-parse HEAD)" = "$RD_HEAD0" ] && [ -z "$(git -C "$RD" stash list)" ] \
  && [ -z "$(git -C "$RD" diff --name-only)" ]; then
  echo "  ✓ D6 neither subcommand commits, stashes or moves HEAD"
else
  echo "  ✗ D6 HEAD moved or a stash exists"; fail=$((fail+1))
fi

# ═══════════════════════════════════════════════════════════════════════
# review-diff exclude list (one list from .rolepod/review-exclude) and the
# path-bounded start / delta
# ═══════════════════════════════════════════════════════════════════════
echo "review-exclude cases:"
# mkxrepo <dir> <exclude-file-content|-> — a repo whose task-1 commit holds
# src/a.txt, docs/rolepod/x.md, a.lock, plugins/p.txt, plus a one-track plan;
# the working tree then carries the same four paths edited (uncommitted).
mkxrepo() {
  mkrepo "$1"
  ( cd "${1:?}" && printf '.rolepod/\n' >> .git/info/exclude && mkdir -p src plugins docs/rolepod \
    && printf 'v1\n' > src/a.txt && printf 'v1\n' > docs/rolepod/x.md && printf 'v1\n' > a.lock \
    && printf 'v1\n' > plugins/p.txt && git add -A && git commit -q -m "task 1 commit" )
  [ "$2" = "-" ] || { mkdir -p "$1/.rolepod" && printf '%s\n' "$2" > "$1/.rolepod/review-exclude"; }
  cat > "$1/x-plan.md" <<'EOF'
# X Plan

## Tasks

### Task 1: alpha
- **Blocked by:** none
- [ ] **Files:** real.py
- [ ] **Command:** true
- **Owner:** backend-developer

### Task 2: beta
- **Blocked by:** 1
- [x] **Files:** real.py
- [x] **Command:** true
- **Owner:** backend-developer

## Parallel layout
Sequential — one track, no worktrees.

## Changes during build

## Follow-ups
EOF
  ( cd "$1" && printf 'v2\n' > src/a.txt && printf 'v2\n' > docs/rolepod/x.md && printf 'v2\n' > a.lock \
    && printf 'v2\n' > plugins/p.txt )
}
x_names() { /usr/bin/grep -E '^diff --git' "$1" | tr '\n' ' '; }

# X1 / X2 share a shape: commit the edited paths as the task, so the track-end
# lens diff (tbase...sha) and `review-diff start` (a fresh uncommitted edit of
# the same four paths) are both non-empty.
xboth() { # $1 = repo dir → sets XL (lens diff file), XS (start diff file)
  local top sha
  top="$(git -C "$1" rev-parse --show-toplevel)"
  ( cd "$1" && git add -A && git commit -q -m "task body" )
  sha="$(git -C "$1" rev-parse HEAD)"
  bash "$TICKET" log "$1/x-plan.md" 1 --sha "$sha" --note "alpha done" >/dev/null 2>&1
  XL="$top/.rolepod/evidence/review/x-plan-plan.diff"
  ( cd "$1" && printf 'v3\n' > src/a.txt && printf 'v3\n' > docs/rolepod/x.md && printf 'v3\n' > a.lock \
    && printf 'v3\n' > plugins/p.txt && bash "$TICKET" review-diff start xs >/dev/null 2>&1 )
  XS="$top/.rolepod/evidence/review/xs.diff"
}
X1="$TMP/x1-repo"; mkxrepo "$X1" "plugins"
xboth "$X1"
if /usr/bin/grep -q 'src/a.txt' "$XL" && /usr/bin/grep -q 'src/a.txt' "$XS" \
  && ! /usr/bin/grep -qE 'docs/rolepod/x.md|a\.lock|plugins/p.txt' "$XL" \
  && ! /usr/bin/grep -qE 'docs/rolepod/x.md|a\.lock|plugins/p.txt' "$XS"; then
  echo "  ✓ X1 one list: start diff and track-end lens diff hold src/a.txt, neither holds docs/rolepod, a.lock or the configured plugins"
else
  echo "  ✗ X1 parity wrong: lens=[$(x_names "$XL" 2>&1)] start=[$(x_names "$XS" 2>&1)]"; fail=$((fail+1))
fi
X2="$TMP/x2-repo"; mkxrepo "$X2" "-"
xboth "$X2"
if /usr/bin/grep -q 'plugins/p.txt' "$XL" && /usr/bin/grep -q 'plugins/p.txt' "$XS"; then
  echo "  ✓ X2 a user plugins/ dir with no review-exclude is reviewed in both diffs"
else
  echo "  ✗ X2 plugins/p.txt missing: lens=[$(x_names "$XL" 2>&1)] start=[$(x_names "$XS" 2>&1)]"; fail=$((fail+1))
fi

X3="$TMP/x3-repo"
mkrepo "$X3"
( cd "$X3" && printf '.rolepod/\n' >> .git/info/exclude && mkdir -p src other && printf 'a1\n' > src/a.txt \
  && printf 'b1\n' > other/b.txt && git add -A && git commit -q -m base )
X3_TOP="$(git -C "$X3" rev-parse --show-toplevel)"
( cd "$X3" && printf 'a2\n' > src/a.txt && printf 'new\n' > src/new.txt && printf 'b2\n' > other/b.txt )
X3_OUT="$(cd "$X3" && bash "$TICKET" review-diff start t -- src 2>"$TMP/x3-err")"; X3_RC=$?
X3_FILE="$X3_TOP/.rolepod/evidence/review/t.diff"
if [ "$X3_RC" -eq 0 ] && [ "$(printf '%s\n' "$X3_OUT" | sed -n 1p)" = "diff: $X3_FILE" ] \
  && [ "$(printf '%s\n' "$X3_OUT" | sed -n 2p)" = "H1: $(git -C "$X3" write-tree)" ] \
  && [ "$(printf '%s\n' "$X3_OUT" | wc -l | tr -d ' ')" -eq 2 ] \
  && /usr/bin/grep -q 'src/a.txt' "$X3_FILE" && /usr/bin/grep -q 'src/new.txt' "$X3_FILE" \
  && ! /usr/bin/grep -q 'other/b.txt' "$X3_FILE" \
  && ! git -C "$X3" diff --cached --name-only | /usr/bin/grep -q 'other/b.txt'; then
  echo "  ✓ X3 start -- src: src/a.txt and the new src/new.txt in, other/b.txt neither in the diff nor staged, no limitation line"
else
  echo "  ✗ X3 path-bounded start wrong (rc=$X3_RC out=$X3_OUT err=$(cat "$TMP/x3-err"))"; fail=$((fail+1))
fi
X3_H1="$(printf '%s\n' "$X3_OUT" | sed -n 's/^H1: //p')"
( cd "$X3" && printf 'a3\n' > src/a.txt && printf 'b3\n' > other/b.txt )
X5_OUT="$(cd "$X3" && bash "$TICKET" review-diff delta t "$X3_H1" 2 -- src 2>"$TMP/x5-err")"; X5_RC=$?
X5_FILE="$X3_TOP/.rolepod/evidence/review/t-r2.diff"
if [ "$X5_RC" -eq 0 ] && [ "$(printf '%s\n' "$X5_OUT" | sed -n 1p)" = "diff: $X5_FILE" ] \
  && /usr/bin/grep -q '^+a3$' "$X5_FILE" && ! /usr/bin/grep -q 'other/b.txt' "$X5_FILE"; then
  echo "  ✓ X5 delta -- src: the r2 file holds src/a.txt only"
else
  echo "  ✗ X5 path-bounded delta wrong (rc=$X5_RC out=$X5_OUT err=$(cat "$TMP/x5-err"))"; fail=$((fail+1))
fi

if ! git -C "$X3" diff --cached --name-only | /usr/bin/grep -q 'other/b.txt'; then
  echo "  ✓ X5b delta -- src stages src only (other/b.txt still unstaged)"
else
  echo "  ✗ X5b delta staged a path outside the list"; fail=$((fail+1))
fi

# X7-X11: the path list is never widened into a whole-tree stage.
X7="$TMP/x7-repo"
mkrepo "$X7"
( cd "$X7" && printf '.rolepod/\n' >> .git/info/exclude && mkdir -p src other && printf 'a1\n' > src/a.txt \
  && printf 'g1\n' > src/gone.txt && printf 'b1\n' > other/b.txt && git add -A && git commit -q -m base \
  && printf 'a2\n' > src/a.txt && printf 'b2\n' > other/b.txt && rm src/gone.txt )
X7_TOP="$(git -C "$X7" rev-parse --show-toplevel)"
x7_bad=0
for badargs in "nope" "':!zzz'" "." "../x" "/abs" "'*'" ".//"; do
  eval "( cd \"\$X7\" && bash \"\$TICKET\" review-diff start t7 -- $badargs >/dev/null 2>\"\$TMP/x7-err\" )"; rc=$?
  [ "$rc" -eq 2 ] && git -C "$X7" diff --cached --quiet && [ ! -e "$X7_TOP/.rolepod/evidence/review/t7.diff" ] \
    || { x7_bad=1; echo "    path [$badargs] rc=$rc"; }
done
( cd "$X7" && bash "$TICKET" review-diff start t7 -- >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] || { x7_bad=1; echo "    bare -- rc=$rc"; }
( cd "$X7" && bash "$TICKET" review-diff delta t7 "$(git -C "$X7" write-tree)" 2 -- >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] || { x7_bad=1; echo "    delta bare -- rc=$rc"; }
if [ "$x7_bad" -eq 0 ]; then
  echo "  ✓ X7 a missing path, a magic/. /.. /absolute path or a bare -- exits 2 and stages nothing"
else
  echo "  ✗ X7 an unusable path list widened or did not fail"; fail=$((fail+1))
fi
X8_OUT="$(cd "$X7" && bash "$TICKET" review-diff start t8 -- src nope 2>"$TMP/x8-err")"; X8_RC=$?
X8_FILE="$X7_TOP/.rolepod/evidence/review/t8.diff"
if [ "$X8_RC" -eq 0 ] && /usr/bin/grep -q 'skipped path.*nope' "$TMP/x8-err" \
  && /usr/bin/grep -q 'src/a.txt' "$X8_FILE" && ! /usr/bin/grep -q 'other/b.txt' "$X8_FILE" \
  && ! git -C "$X7" diff --cached --name-only | /usr/bin/grep -q 'other/b.txt'; then
  echo "  ✓ X8 a live path plus a missing one: the missing is skipped with a stderr note, only the live one is staged and diffed"
else
  echo "  ✗ X8 partial skip wrong (rc=$X8_RC err=$(cat "$TMP/x8-err"))"; fail=$((fail+1))
fi
X9_OUT="$(cd "$X7" && bash "$TICKET" review-diff start t9 -- src/gone.txt 2>/dev/null)"; X9_RC=$?
if [ "$X9_RC" -eq 0 ] && /usr/bin/grep -q 'src/gone.txt' "$X7_TOP/.rolepod/evidence/review/t9.diff"; then
  echo "  ✓ X9 a path the task deleted (gone from the worktree, in HEAD) is kept"
else
  echo "  ✗ X9 deleted path wrong (rc=$X9_RC)"; fail=$((fail+1))
fi

# X10-X11: a gitignored path is skipped like a missing one, never a hard failure.
X10="$TMP/x10-repo"
mkrepo "$X10"
( cd "$X10" && printf 'ign/\n' >> .git/info/exclude && mkdir -p src ign && printf 'a1\n' > src/a.txt \
  && git add -A && git commit -q -m base && printf 'a2\n' > src/a.txt && printf 'i\n' > ign/f.txt )
X10_TOP="$(git -C "$X10" rev-parse --show-toplevel)"
X10_OUT="$(cd "$X10" && bash "$TICKET" review-diff start t10 -- src ign 2>"$TMP/x10-err")"; X10_RC=$?
X10_FILE="$X10_TOP/.rolepod/evidence/review/t10.diff"
if [ "$X10_RC" -eq 0 ] && /usr/bin/grep -q 'skipped path.*ign' "$TMP/x10-err" \
  && /usr/bin/grep -q 'src/a.txt' "$X10_FILE" && ! /usr/bin/grep -q 'ign/f.txt' "$X10_FILE"; then
  echo "  ✓ X10 a tracked path plus a gitignored one: exit 0, only the tracked file diffed, skip note on stderr"
else
  echo "  ✗ X10 gitignored path wrong (rc=$X10_RC err=$(cat "$TMP/x10-err"))"; fail=$((fail+1))
fi
( cd "$X10" && bash "$TICKET" review-diff start t11 -- ign >/dev/null 2>"$TMP/x11-err" ); X11_RC=$?
if [ "$X11_RC" -eq 2 ] && [ ! -e "$X10_TOP/.rolepod/evidence/review/t11.diff" ]; then
  echo "  ✓ X11 every path gitignored: exit 2, no file"
else
  echo "  ✗ X11 all-ignored wrong (rc=$X11_RC err=$(cat "$TMP/x11-err"))"; fail=$((fail+1))
fi

# X12: a force-tracked file under an ignored dir, named by the dir, is kept.
( cd "$X10" && git add -f ign/f.txt && git commit -q -m forced && printf 'i2\n' > ign/f.txt )
( cd "$X10" && bash "$TICKET" review-diff start t12 -- ign >/dev/null 2>"$TMP/x12-err" ); X12_RC=$?
if [ "$X12_RC" -eq 0 ] && /usr/bin/grep -q 'ign/f.txt' "$X10_TOP/.rolepod/evidence/review/t12.diff"; then
  echo "  ✓ X12 a tracked file under an ignored dir is still diffed"
else
  echo "  ✗ X12 tracked-under-ignored dropped (rc=$X12_RC)"; fail=$((fail+1))
fi

X4_OUT="$(cd "$X3" && bash "$TICKET" review-diff start t4 2>/dev/null)"
if [ "$(printf '%s\n' "$X4_OUT" | sed -n 3p | cut -c1-27)" = "limitation: whole-tree diff" ]; then
  echo "  ✓ X4 start with no path prints the whole-tree limitation line"
else
  echo "  ✗ X4 no limitation line: [$X4_OUT]"; fail=$((fail+1))
fi

X6="$TMP/x6-repo"
mkrepo "$X6"
( cd "$X6" && printf '.rolepod/\n' >> .git/info/exclude && mkdir -p src plugins && printf 'a1\n' > src/a.txt \
  && printf 'p1\n' > plugins/p.txt && git add -A && git commit -q -m base \
  && mkdir -p .rolepod && printf 'plugins\n' > .rolepod/review-exclude \
  && git worktree add -q -b x6-trk "$TMP/x6-wt" )
( cd "$TMP/x6-wt" && printf 'a2\n' > src/a.txt && printf 'p2\n' > plugins/p.txt )
X6_TOP="$(git -C "$TMP/x6-wt" rev-parse --show-toplevel)"
( cd "$TMP/x6-wt" && bash "$TICKET" review-diff start t6 >/dev/null 2>&1 )
X6_FILE="$X6_TOP/.rolepod/evidence/review/t6.diff"
if [ -f "$X6_FILE" ] && /usr/bin/grep -q 'src/a.txt' "$X6_FILE" && ! /usr/bin/grep -q 'plugins/p.txt' "$X6_FILE"; then
  echo "  ✓ X6 a track worktree with no review-exclude of its own uses the base checkout's"
else
  echo "  ✗ X6 worktree did not use the base's review-exclude: [$(x_names "$X6_FILE" 2>&1)]"; fail=$((fail+1))
fi

# ── a failing start never reaches the real repo: the empty-worktree `cd ""`
# no-op plus a commit lands in the guard repo; the real HEAD stays put.
bash "$TICKET" start "$TMP/no-such-plan.md" 1 >/dev/null 2>&1; BADSTART_RC=$?
EMPTY_WT=""
( cd "$EMPTY_WT" 2>/dev/null; git commit -q --allow-empty -m "stray fixture commit" )
if [ "$BADSTART_RC" -ne 0 ] \
  && [ "$(git -C "$REPO_DIR" rev-parse HEAD)" = "$REAL_HEAD_BEFORE" ] \
  && [ "$(git -C "$GUARD" log -1 --format=%s)" = "stray fixture commit" ]; then
  echo "  ✓ a failing start plus a no-op cd commits into the guard repo, never the real main"
else
  echo "  ✗ isolation broken: rc=$BADSTART_RC real HEAD=$(git -C "$REPO_DIR" rev-parse --short HEAD)"; fail=$((fail+1))
fi

# ── base branch pin: a checkout on a non-main branch `set` — a Sequential plan
# stays on the base checkout; a track branches off set's tip, records the checkout
# as its base root, and finish moves set, never main.
SBR="$TMP/set-repo"
mkrepo "$SBR"
( cd "$SBR" && git branch -m main )
cat > "$SBR/2026-10-07-set-seq.md" <<'EOF'
# Set Seq Plan

## Parallel layout
Sequential — single owner.

## Tasks

### Task 1: build seq
- **Blocked by:** none
- [ ] **Files:** `src/seq.py`
- [ ] **Command:** `true`
- **Owner:** backend-developer

## Failure policy
Stop after 2 failed attempts.
EOF
cat > "$SBR/2026-10-07-set-trk.md" <<'EOF'
# Set Trk Plan

## Parallel layout
Sequential — tracks run one owner each.

## Tracks
- A — lane one: Task 1 · branch set-trk/a-lane-one

## Tasks

### Task 1: build alpha
- **Track:** A
- **Blocked by:** none
- [ ] **Files:** `src/alpha.py`
- [ ] **Command:** `true`
- **Owner:** backend-developer

## Failure policy
Stop after 2 failed attempts.
EOF
( cd "$SBR" && git add -A && git commit -q -m "add plans" && git switch -q -c set && git commit -q --allow-empty -m "set tip" )
SBR_REAL="$(git -C "$SBR" rev-parse --show-toplevel)"
SB_MAIN_BEFORE=$(git -C "$SBR" rev-parse main)
SB_SEQ=$(bash "$TICKET" start "$SBR/2026-10-07-set-seq.md" 1 2>"$TMP/setseq.err"); SB_SEQ_RC=$?
if [ "$SB_SEQ_RC" -eq 0 ] && printf '%s\n' "$SB_SEQ" | grep -qF 'on the base checkout'; then
  echo "  ✓ base branch set: a Sequential plan's start stays on the base checkout"
else echo "  ✗ base branch set: Sequential start rc=$SB_SEQ_RC: $SB_SEQ"; cat "$TMP/setseq.err" >&2; fail=$((fail+1)); fi

SB_SET_TIP=$(git -C "$SBR" rev-parse set)
SB_TRK=$(bash "$TICKET" start "$SBR/2026-10-07-set-trk.md" 1 2>"$TMP/settrk.err"); SB_TRK_RC=$?
SB_WT=$(printf '%s\n' "$SB_TRK" | sed -n '1p' | awk '{print $2}')
if [ "$SB_TRK_RC" -eq 0 ] && [ -d "$SB_WT" ] \
  && [ "$(git -C "$SBR" merge-base set set-trk/a-lane-one)" = "$SB_SET_TIP" ] \
  && [ "$(git -C "$SBR" config --get branch.set-trk/a-lane-one.rolepod-base-root)" = "$SBR_REAL" ]; then
  echo "  ✓ base branch set: a track branches off set's tip and records the checkout as its base root"
else echo "  ✗ base branch set: track start rc=$SB_TRK_RC wt=[$SB_WT] merge-base=[$(git -C "$SBR" merge-base set set-trk/a-lane-one 2>&1)] want [$SB_SET_TIP]"; cat "$TMP/settrk.err" >&2; fail=$((fail+1)); fi

( cd "$SB_WT" && git commit -q --allow-empty -m "track work" )
SB_FIN=$(bash "$TICKET" finish "$SB_WT" 2>&1); SB_FIN_RC=$?
if [ "$SB_FIN_RC" -eq 0 ] && [ "$(git -C "$SBR" rev-parse set)" != "$SB_SET_TIP" ] \
  && [ "$(git -C "$SBR" rev-parse main)" = "$SB_MAIN_BEFORE" ]; then
  echo "  ✓ base branch set: finish advances set and leaves main where it was"
else echo "  ✗ base branch set: finish rc=$SB_FIN_RC set=$(git -C "$SBR" rev-parse --short set) main=$(git -C "$SBR" rev-parse --short main) (main before ${SB_MAIN_BEFORE:0:7}): $SB_FIN"; fail=$((fail+1)); fi

# ═══════════════════════════════════════════════════════════════════════
# docs-default (spec docs-default-2026-10-07 Task 5): every stage leaves
# docs/rolepod out of the index and never fails on an ignored docs dir; the
# last task's log names the one docs commit in a tracked repo only.
# ═══════════════════════════════════════════════════════════════════════
export GIT_CONFIG_GLOBAL=/dev/null
DOCS_MODE_SH="$REPO_DIR/hooks/lib/docs-mode.sh"
DDH="$TMP/dd-home"; mkdir -p "$DDH"
mk_dd_repo() { # $1 = dir, $2 = tracked | ignored — a two-task Sequential plan plus a docs file
  mkrepo "$1"
  cat > "$1/2026-10-07-dd-demo.md" <<'EOF'
# Dd Demo Plan

## Parallel layout
Sequential — single owner.

## Tasks

### Task 1: build one
- **Blocked by:** none
- [ ] **Files:** `one.txt`
- [ ] **Command:** `true`
- **Owner:** backend-developer

### Task 2: build two
- **Blocked by:** Task 1
- [ ] **Files:** `two.txt`
- [ ] **Command:** `true`
- **Owner:** backend-developer

## Failure policy
Stop after 2 failed attempts.

## Changes during build
- base sha: init
EOF
  mkdir -p "$1/docs/rolepod"
  echo "note v1" > "$1/docs/rolepod/notes.md"
  if [ "$2" = "tracked" ]; then
    bash "$DOCS_MODE_SH" -C "$1" track >/dev/null 2>&1
    ( cd "$1" && git add -A && git commit -q -m "plan and docs" )
  else
    printf 'docs/rolepod/\n' > "$1/.gitignore"
    ( cd "$1" && git add -A && git commit -q -m "plan" )
  fi
}
dd_names() { git -C "$1" diff --cached --name-only; }

# tracked, main mode: two tasks, docs change beside the code each time
DDT="$TMP/dd-tracked"; mk_dd_repo "$DDT" tracked
DDT_PLAN="$DDT/2026-10-07-dd-demo.md"
DDT_OK=1; DDT_LOGS=""
for n in 1 2; do
  DDT_S=$(env -u CLAUDE_CODE_SESSION_ID -u ROLEPOD_SESSION_ID HOME="$DDH" bash "$TICKET" start "$DDT_PLAN" "$n" 2>"$TMP/ddt-s$n.err")
  [ "$(printf '%s\n' "$DDT_S" | sed -n '3p')" = "on the base checkout: stage with git add -A && git reset -q -- docs/rolepod, the Lead commits with the commit check, then ticket.sh log <plan> <N> --sha <sha>" ] || DDT_OK=0
  case "$n" in 1) w=one ;; *) w=two ;; esac
  echo "$w" > "$DDT/$w.txt"
  echo "note v$((n+1))" > "$DDT/docs/rolepod/notes.md"
  echo "extra $n" > "$DDT/docs/rolepod/extra$n.md"
  DDT_TF="$DDT/docs/rolepod/tasks/2026-10-07-dd-demo/task-0$n.md"
  echo "receipt" >> "$DDT_TF"; echo "verified" > "$DDT/docs/rolepod/tasks/2026-10-07-dd-demo/verify.md"
  if [ -n "$(git -C "$DDT" status --porcelain | grep 'docs/rolepod/tasks/')" ]; then DDT_OK=0; echo "  ! tasks/ file visible in git status: $(git -C "$DDT" status --porcelain)"; fi
  ( cd "$DDT" && bash "$TICKET" review-diff start "dd-t$n" >/dev/null 2>"$TMP/ddt-r$n.err" ) || DDT_OK=0
  if dd_names "$DDT" | grep -q '^docs/rolepod/' || ! dd_names "$DDT" | grep -qx "$w.txt"; then DDT_OK=0; echo "  ! staged set wrong after review-diff start: $(dd_names "$DDT" | tr '\n' ' ')"; fi
  ( cd "$DDT" && git commit -q -m "task $n code" )
  DDT_LOGS="$DDT_LOGS$(bash "$TICKET" log "$DDT_PLAN" "$n" --sha "$(git -C "$DDT" rev-parse HEAD)" --note "done $n" 2>/dev/null)"$'\n'
done
DDT_CODE_DOCS=$(git -C "$DDT" log --name-only --format= HEAD~2..HEAD | grep -c '^docs/rolepod/')
if [ "$DDT_OK" = "1" ] && [ "$DDT_CODE_DOCS" = "0" ] \
  && git -C "$DDT" status --porcelain | grep -q 'docs/rolepod/notes.md'; then
  echo "  ✓ docs-default tracked, main mode: the stage keeps docs out of both code commits and docs/rolepod/tasks/ out of git status"
else
  echo "  ✗ docs-default tracked main mode: ok=$DDT_OK docs-in-code-commits=$DDT_CODE_DOCS"; fail=$((fail+1)); cat "$TMP"/ddt-*.err >&2
fi
if [ "$(printf '%s' "$DDT_LOGS" | grep -c '^phase end:')" = "1" ] \
  && printf '%s' "$DDT_LOGS" | grep -qxF "phase end: git add -- docs/rolepod && git commit -m 'docs: 2026-10-07-dd-demo.md' -- docs/rolepod" \
  && ! printf '%s' "$DDT_LOGS" | head -n 3 | grep -q '^phase end:'; then
  echo "  ✓ docs-default tracked: log prints the docs: commit line once, on the last task only"
else
  echo "  ✗ docs-default tracked log lines wrong: [$DDT_LOGS]"; fail=$((fail+1))
fi

# tracked, worktree mode: integrate stages code only, no staged docs deletion
DDW="$TMP/dd-tracked-wt"; mk_dd_repo "$DDW" tracked
( cd "$DDW" && git worktree add -q -b dd-task "$TMP/dd-tracked-wt-b" ) || { echo "ticket: fixture: worktree add failed" >&2; exit 1; }
echo one > "$TMP/dd-tracked-wt-b/one.txt"
echo "note v9" > "$TMP/dd-tracked-wt-b/docs/rolepod/notes.md"
echo new > "$TMP/dd-tracked-wt-b/docs/rolepod/fresh.md"
printf '## Command\n`true`\n## Proof\nok\n`true`\n' > "$TMP/dd-brief.md"
DDW_OUT=$(bash "$TICKET" integrate "$TMP/dd-tracked-wt-b" --brief "$TMP/dd-brief.md" 2>&1); DDW_RC=$?
if [ "$DDW_RC" -eq 0 ] && printf '%s\n' "$DDW_OUT" | grep -q '^stage: ok' \
  && [ "$(dd_names "$TMP/dd-tracked-wt-b")" = "one.txt" ]; then
  echo "  ✓ docs-default tracked, worktree mode: integrate stages the code and leaves modified and new docs out"
else
  echo "  ✗ docs-default tracked integrate: rc=$DDW_RC staged=[$(dd_names "$TMP/dd-tracked-wt-b" | tr '\n' ' ')] $DDW_OUT"; fail=$((fail+1))
fi

# ignored mode, docs present in the checkout: integrate and review-diff exit 0
DDI="$TMP/dd-ignored"; mk_dd_repo "$DDI" ignored
( cd "$DDI" && git worktree add -q -b dd-task "$TMP/dd-ignored-b" ) || { echo "ticket: fixture: worktree add failed" >&2; exit 1; }
mkdir -p "$TMP/dd-ignored-b/docs/rolepod"; echo local > "$TMP/dd-ignored-b/docs/rolepod/notes.md"
echo one > "$TMP/dd-ignored-b/one.txt"
DDI_OUT=$(bash "$TICKET" integrate "$TMP/dd-ignored-b" --brief "$TMP/dd-brief.md" 2>&1); DDI_RC=$?
if [ "$DDI_RC" -eq 0 ] && printf '%s\n' "$DDI_OUT" | grep -q '^stage: ok' \
  && [ "$(dd_names "$TMP/dd-ignored-b")" = "one.txt" ]; then
  echo "  ✓ docs-default ignored mode: integrate with docs in the checkout prints stage: ok and exits 0"
else
  echo "  ✗ docs-default ignored integrate: rc=$DDI_RC $DDI_OUT"; fail=$((fail+1))
fi
echo two > "$DDI/two.txt"
( cd "$DDI" && bash "$TICKET" review-diff start dd-i >/dev/null 2>"$TMP/ddi-r.err" ); DDI_RD=$?
if [ "$DDI_RD" -eq 0 ] && [ "$(dd_names "$DDI")" = "two.txt" ]; then
  echo "  ✓ docs-default ignored mode: review-diff start with docs ignored in the checkout exits 0"
else
  echo "  ✗ docs-default ignored review-diff: rc=$DDI_RD staged=[$(dd_names "$DDI" | tr '\n' ' ')]"; fail=$((fail+1)); cat "$TMP/ddi-r.err" >&2
fi
DDI_LOGS=""
for n in 1 2; do
  DDI_LOGS="$DDI_LOGS$(bash "$TICKET" log "$DDI/2026-10-07-dd-demo.md" "$n" --sha "$(git -C "$DDI" rev-parse HEAD)" --note "done $n" 2>/dev/null)"
done
if ! printf '%s' "$DDI_LOGS" | grep -q 'phase end:'; then
  echo "  ✓ docs-default ignored: log never prints the docs: commit line"
else
  echo "  ✗ docs-default ignored log printed a docs: line: [$DDI_LOGS]"; fail=$((fail+1))
fi

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
