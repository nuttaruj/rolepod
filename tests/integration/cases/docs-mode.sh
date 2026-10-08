#!/bin/bash
# docs-mode — proves hooks/lib/docs-mode.sh status / ignore / track against
# throwaway repos (spec docs-default-2026-10-07 §Success criteria; threats
# A1-A3 of docs/rolepod/contracts/docs-default-threats-2026-10-07.md).
# Every fixture lives under $TMP; the run's cwd is a guard repo, never the
# real checkout.
set -uo pipefail

fail=0
TMP=$(mktemp -d)
[ -n "$TMP" ] && [ -d "$TMP" ] || { echo "docs-mode: mktemp -d failed — refusing to run fixtures" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT

# A user's global excludes / signing config must not flip a fixture verdict.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DM="$REPO_DIR/hooks/lib/docs-mode.sh"

REAL_HEAD_BEFORE="$(git -C "$REPO_DIR" rev-parse HEAD)"
REAL_STAGED_BEFORE="$(git -C "$REPO_DIR" diff --cached --name-only)"

ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1"; fail=1; }
check() { # desc, then a command that must succeed
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi
}
eq() { # desc, got, want
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi
}

mkrepo() { # $1 = dir — a throwaway repo with an initial commit
  mkdir -p "$1"
  ( cd "${1:?}" && git init -q . && git config user.email t@t && git config user.name t \
    && git commit -q --allow-empty -m init )
}

GUARD="$TMP/cwd-guard"
mkrepo "$GUARD"
cd "$GUARD" || { echo "docs-mode: cannot enter the guard repo" >&2; exit 1; }

if [ ! -f "$DM" ]; then
  bad "hooks/lib/docs-mode.sh exists"
  echo "docs-mode: FAIL"; exit 1
fi

st()  { bash "$DM" -C "$1" status 2>/dev/null; }
last() { tail -n 1 | sed -E 's#^git -C [^ ]+ commit#git commit#'; }   # the -C form is asserted on its own below
runcommit() { # $1 = repo, $2 = ignore|track output — runs its last line in the repo
  ( cd "$1" && eval "$(printf '%s\n' "$2" | tail -n 1)" ) >/dev/null 2>&1
}
newrepo() { local d="$TMP/$1"; mkrepo "$d"; printf '%s' "$d"; }

echo "▸ CLI contract"
R=$(newrepo cli)
check "bash -n" bash -n "$DM"
bash "$DM" -C "$TMP" status >/dev/null 2>&1; eq "not a git repo → exit 1" "$?" "1"
bash "$DM" -C "$R" bogus >/dev/null 2>&1; eq "unknown command → exit 2" "$?" "2"
bash "$DM" >/dev/null 2>&1; eq "no command → exit 2" "$?" "2"
bash "$DM" -C >/dev/null 2>&1; eq "-C without dir → exit 2" "$?" "2"
bash "$DM" -C "$R" status extra >/dev/null 2>&1; eq "extra operand → exit 2" "$?" "2"
eq "-C after the command: status -C <dir>" "$(bash "$DM" status -C "$R" 2>/dev/null)" "undecided"
bash "$DM" status -C >/dev/null 2>&1; eq "trailing -C without dir → exit 2" "$?" "2"
bash "$DM" status -C "$R" -C "$R" >/dev/null 2>&1; eq "-C twice → exit 2" "$?" "2"
mkdir -p "$R/sub"
eq "cwd mode from a subdir reads the toplevel" "$(cd "$R/sub" && bash "$DM" status)" "undecided"

echo "▸ status"
R=$(newrepo st-new)
eq "new repo → undecided" "$(st "$R")" "undecided"
bash "$DM" -C "$R" status >/dev/null 2>&1; eq "status exit 0" "$?" "0"
for rule in 'docs/' 'docs/rolepod' 'docs/rolepod/' 'docs/rolepod/*'; do
  for withdir in no yes; do
    R=$(newrepo "st-rule-$(printf '%s' "$rule" | tr -c 'a-z' _)-$withdir")
    printf '%s\n' "$rule" > "$R/.gitignore"
    [ "$withdir" = yes ] && mkdir -p "$R/docs/rolepod"
    eq "rule '$rule' dir=$withdir → ignored" "$(st "$R")" "ignored"
  done
done
R=$(newrepo st-force)
printf 'docs/rolepod/\n' > "$R/.gitignore"
mkdir -p "$R/docs/rolepod"; echo x > "$R/docs/rolepod/plan.md"
( cd "$R" && git add -f docs/rolepod/plan.md .gitignore && git commit -q -m forced )
eq "rule + force-added committed file → ignored" "$(st "$R")" "ignored"
R=$(newrepo st-exclude)
printf 'docs/rolepod/\n' >> "$R/.git/info/exclude"
eq "info/exclude-only rule → ignored" "$(st "$R")" "ignored"
R=$(newrepo st-marker)
printf 'docs/rolepod/\n' > "$R/.gitignore"
mkdir -p "$R/.rolepod"; echo tracked > "$R/.rolepod/docs-tracked"
eq "marker + rule → tracked" "$(st "$R")" "tracked"

echo "▸ tasks hint"
R=$(newrepo hint)
mkdir -p "$R/docs/rolepod/tasks"; echo r > "$R/docs/rolepod/tasks/task-01.md"
( cd "$R" && git add -f docs/rolepod/tasks/task-01.md && git commit -q -m tasks )
err=$(bash "$DM" -C "$R" status 2>&1 >/dev/null)
eq "status hint is one line" "$(printf '%s\n' "$err" | wc -l | tr -d ' ')" "1"
check "status hint names git rm -r --cached docs/rolepod/tasks" grep -qF 'git rm -r --cached docs/rolepod/tasks' <<<"$err"
eq "status stdout stays one word" "$(bash "$DM" -C "$R" status 2>/dev/null)" "undecided"
err=$(bash "$DM" -C "$R" track 2>&1 >/dev/null)
eq "track hint is one line" "$(printf '%s\n' "$err" | wc -l | tr -d ' ')" "1"
check "tasks file is still tracked (never untracked by itself)" git -C "$R" ls-files --error-unmatch docs/rolepod/tasks/task-01.md
R=$(newrepo nohint)
eq "no tracked task file → no hint" "$(bash "$DM" -C "$R" status 2>&1 >/dev/null)" ""

echo "▸ ignore"
R=$(newrepo ig-new)
out=$(bash "$DM" -C "$R" ignore 2>&1); rc=$?
eq "ignore on undecided exit 0" "$rc" "0"
eq "status after ignore → ignored" "$(st "$R")" "ignored"
eq ".gitignore holds the rule once" "$(grep -cxF 'docs/rolepod/' "$R/.gitignore")" "1"
eq "user line is second to last" "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" "Tell the user: docs/rolepod/ stays out of git by default; answer track to commit it."
eq "last line is the commit for .gitignore only" "$(printf '%s\n' "$out" | last)" "git commit -m 'chore: docs mode' -- .gitignore"
runcommit "$R" "$out"
eq "committed: tree clean" "$(git -C "$R" status --porcelain)" ""
out=$(bash "$DM" -C "$R" ignore 2>&1); rc=$?
eq "rerun: rc 0" "$rc" "0"
eq "rerun: no output (nothing changed → no commit line)" "$out" ""
eq "rerun: rule not duplicated" "$(grep -cxF 'docs/rolepod/' "$R/.gitignore")" "1"

R=$(newrepo ig-nonl)
printf 'node_modules/' > "$R/.gitignore"
bash "$DM" -C "$R" ignore >/dev/null 2>&1
eq "no final newline: old rule survives" "$(sed -n 1p "$R/.gitignore")" "node_modules/"
eq "no final newline: rule on its own line" "$(sed -n 2p "$R/.gitignore")" "docs/rolepod/"

R=$(newrepo ig-nogi)
[ ! -e "$R/.gitignore" ] && bash "$DM" -C "$R" ignore >/dev/null 2>&1
eq "no .gitignore → created with the rule" "$(cat "$R/.gitignore")" "docs/rolepod/"

R=$(newrepo ig-docs)
printf 'docs/\n' > "$R/.gitignore"; ( cd "$R" && git add .gitignore && git commit -q -m gi )
out=$(bash "$DM" -C "$R" ignore 2>&1)
eq "docs/ already in .gitignore → file untouched" "$(cat "$R/.gitignore")" "docs/"
eq "docs/ already in .gitignore → no output" "$out" ""

R=$(newrepo ig-excl)
printf 'docs/rolepod/\n' >> "$R/.git/info/exclude"
out=$(bash "$DM" -C "$R" ignore 2>&1)
eq "info/exclude-only → .gitignore gets the rule" "$(cat "$R/.gitignore")" "docs/rolepod/"
check "info/exclude-only: undecided-before user line not printed (status was ignored)" test "$(printf '%s\n' "$out" | grep -c '^Tell the user')" = 0

R=$(newrepo ig-marker-committed)
printf 'docs/rolepod/\n' > "$R/.gitignore"
mkdir -p "$R/.rolepod"; echo tracked > "$R/.rolepod/docs-tracked"
( cd "$R" && git add .gitignore && git add -f .rolepod/docs-tracked && git commit -q -m marker )
out=$(bash "$DM" -C "$R" ignore 2>&1); rc=$?
eq "committed marker: rc 0" "$rc" "0"
eq "committed marker: file removed" "$([ -e "$R/.rolepod/docs-tracked" ] && echo yes || echo no)" "no"
eq "committed marker: status ignored at once" "$(st "$R")" "ignored"
eq "committed marker: deletion staged" "$(git -C "$R" diff --cached --name-only)" ".rolepod/docs-tracked"
eq "committed marker: commit line names the marker only" "$(printf '%s\n' "$out" | last)" "git commit -m 'chore: docs mode' -- .rolepod/docs-tracked"
runcommit "$R" "$out"
eq "committed marker: tree clean after the printed commit" "$(git -C "$R" status --porcelain)" ""

R=$(newrepo ig-marker-old)
printf 'docs/rolepod/\n' > "$R/.gitignore"; ( cd "$R" && git add .gitignore && git commit -q -m gi )
mkdir -p "$R/.rolepod"; echo tracked > "$R/.rolepod/docs-tracked"
eq "uncommitted marker → tracked" "$(st "$R")" "tracked"
out=$(bash "$DM" -C "$R" ignore 2>&1); rc=$?
eq "uncommitted marker + ignore: rc 0" "$rc" "0"
eq "uncommitted marker + ignore: status ignored" "$(st "$R")" "ignored"
eq "uncommitted marker + ignore: nothing to commit" "$out" ""

R=$(newrepo ig-repo-like)
printf 'docs/rolepod/\n' > "$R/.gitignore"; ( cd "$R" && git add .gitignore && git commit -q -m gi )
out=$(bash "$DM" -C "$R" ignore 2>&1)
eq "rule already committed (this repo's shape): no output" "$out" ""
eq "rule already committed: tree clean" "$(git -C "$R" status --porcelain)" ""

echo "▸ A2: the printed commit sweeps no other staged file"
R=$(newrepo a2)
mkdir -p "$R/src" "$R/docs/rolepod/specs"
echo a > "$R/src/a.py"; echo s > "$R/docs/rolepod/specs/x.md"
( cd "$R" && git add src/a.py docs/rolepod/specs/x.md )
out=$(bash "$DM" -C "$R" ignore 2>&1)
eq "A2: commit line holds only .gitignore" "$(printf '%s\n' "$out" | last)" "git commit -m 'chore: docs mode' -- .gitignore"
runcommit "$R" "$out"
eq "A2: the commit holds only .gitignore" "$(git -C "$R" show --name-only --format= HEAD)" ".gitignore"
eq "A2: src/a.py and the doc stay staged" "$(git -C "$R" diff --cached --name-only | tr '\n' ' ')" "docs/rolepod/specs/x.md src/a.py "
R=$(newrepo a2-track)
mkdir -p "$R/src"; echo a > "$R/src/a.py"; ( cd "$R" && git add src/a.py )
out=$(bash "$DM" -C "$R" track 2>&1)
eq "A2 track: commit line has -- and only the answer files" "$(printf '%s\n' "$out" | last)" "git commit -m 'chore: docs mode' -- .rolepod/docs-tracked docs/rolepod/tasks/.gitignore"
runcommit "$R" "$out"
eq "A2 track: commit holds no code file" "$(git -C "$R" show --name-only --format= HEAD | tr '\n' ' ')" ".rolepod/docs-tracked docs/rolepod/tasks/.gitignore "
eq "A2 track: src/a.py stays staged" "$(git -C "$R" diff --cached --name-only)" "src/a.py"

echo "▸ -C form of the commit line"
R=$(newrepo cflag)
out=$(bash "$DM" -C "$R" ignore 2>&1)
( cd "$TMP" && eval "$(printf '%s\n' "$out" | tail -n 1)" ) >/dev/null 2>&1
eq "-C: the printed commit runs from another cwd" "$(git -C "$R" status --porcelain)" ""
R=$(newrepo cwdform)
eq "no -C: the last line is the plain git commit" "$(cd "$R" && bash "$DM" ignore 2>&1 | tail -n 1)" "git commit -m 'chore: docs mode' -- .gitignore"

echo "▸ track"
R=$(newrepo tr-main)
printf 'docs/rolepod/\n' > "$R/.gitignore"; ( cd "$R" && git add .gitignore && git commit -q -m gi )
out=$(bash "$DM" -C "$R" track 2>&1); rc=$?
eq "track on ignored: rc 0" "$rc" "0"
eq "track: status tracked" "$(st "$R")" "tracked"
eq "track: rule line removed" "$(grep -cxF 'docs/rolepod/' "$R/.gitignore")" "0"
eq "track: tasks/.gitignore content" "$(cat "$R/docs/rolepod/tasks/.gitignore")" "$(printf '*\n!.gitignore')"
eq "track: three files staged" "$(git -C "$R" diff --cached --name-only | sort | tr '\n' ' ')" ".gitignore .rolepod/docs-tracked docs/rolepod/tasks/.gitignore "
eq "track: last line is the commit for all three" "$(printf '%s\n' "$out" | last)" "git commit -m 'chore: docs mode' -- .gitignore .rolepod/docs-tracked docs/rolepod/tasks/.gitignore"
check "track: nothing committed by the script" test "$(git -C "$R" rev-list --count HEAD)" = 2
runcommit "$R" "$out"
out2=$(bash "$DM" -C "$R" track 2>&1); rc=$?
eq "track rerun after commit: rc 0" "$rc" "0"
eq "track rerun after commit: no output" "$out2" ""
eq "track rerun: tree clean" "$(git -C "$R" status --porcelain)" ""
CL="$TMP/tr-clone"
git clone -q "$R" "$CL" 2>/dev/null
eq "fresh clone reads tracked" "$(st "$CL")" "tracked"
git -C "$R" worktree add -q "$TMP/tr-wt" -b wt-branch 2>/dev/null
eq "worktree created after the commit reads tracked" "$(st "$TMP/tr-wt")" "tracked"

echo "▸ A3: later code commit carries no answer file"
mkdir -p "$R/docs/rolepod/tasks" "$R/docs/rolepod/plans"
echo r > "$R/docs/rolepod/tasks/task-01.md"; echo p > "$R/docs/rolepod/plans/p.md"; echo c > "$R/code.txt"
( cd "$R" && git add -A && git commit -q -m code )
names=$(git -C "$R" show --name-only --format= HEAD | tr '\n' ' ')
eq "tracked mode: code commit = code + plan, no marker / .gitignore / tasks" "$names" "code.txt docs/rolepod/plans/p.md "
R=$(newrepo a3-ignore)
bash "$DM" -C "$R" ignore >/dev/null 2>&1; ( cd "$R" && git commit -q -m dm -- .gitignore )
mkdir -p "$R/docs/rolepod/plans"; echo p > "$R/docs/rolepod/plans/p.md"; echo c > "$R/code.txt"
( cd "$R" && git add -A && git commit -q -m code )
eq "ignore mode: code commit holds no docs/rolepod, no .rolepod" "$(git -C "$R" show --name-only --format= HEAD)" "code.txt"

echo "▸ track blocked"
R=$(newrepo tr-blocked)
printf 'docs/\n' > "$R/.gitignore"; ( cd "$R" && git add .gitignore && git commit -q -m gi )
before=$(cat "$R/.gitignore")
out=$(bash "$DM" -C "$R" track 2>&1); rc=$?
eq "docs/ blocks track: exit 3" "$rc" "3"
check "blocked: output names the rule" grep -qF '.gitignore:1:docs/' <<<"$out"
eq "blocked: .gitignore untouched" "$(cat "$R/.gitignore")" "$before"
eq "blocked: no marker" "$([ -e "$R/.rolepod/docs-tracked" ] && echo yes || echo no)" "no"
eq "blocked: nothing staged" "$(git -C "$R" diff --cached --name-only)" ""
R=$(newrepo tr-blocked2)
printf 'docs/rolepod/\ndocs/\n' > "$R/.gitignore"; ( cd "$R" && git add .gitignore && git commit -q -m gi )
before=$(cat "$R/.gitignore")
bash "$DM" -C "$R" track >/dev/null 2>&1; rc=$?
eq "own rule + docs/: exit 3" "$rc" "3"
eq "own rule + docs/: .gitignore restored byte for byte" "$(cat "$R/.gitignore")" "$before"
eq "own rule + docs/: tree clean" "$(git -C "$R" status --porcelain)" ""
R=$(newrepo tr-blocked3)
printf 'docs/rolepod/\n' >> "$R/.git/info/exclude"
bash "$DM" -C "$R" track >/dev/null 2>&1; rc=$?
eq "info/exclude rule blocks track: exit 3" "$rc" "3"

R=$(newrepo tr-undecided)
out=$(bash "$DM" -C "$R" track 2>&1); rc=$?
eq "track on undecided: rc 0, tracked" "$rc$(st "$R")" "0tracked"

echo "▸ tree (A7: the real index is never touched)"
mkdir -p "$TMP/tmpd"
tree() { TMPDIR="$TMP/tmpd" bash "$DM" -C "$1" tree "${@:2}" 2>/dev/null; }
for mode in ignored tracked; do
  R=$(newrepo "tree-$mode")
  mkdir -p "$R/src" "$R/docs/rolepod/plans"
  echo a > "$R/src/a.py"; echo b > "$R/src/b.py"
  if [ "$mode" = ignored ]; then printf 'docs/rolepod/\n' > "$R/.gitignore"; else mkdir -p "$R/.rolepod"; echo tracked > "$R/.rolepod/docs-tracked"; fi
  echo p > "$R/docs/rolepod/plans/p.md"
  if [ "$mode" = ignored ]; then base_files=".gitignore src/a.py"; else base_files=".rolepod/docs-tracked src/a.py docs/rolepod/plans/p.md"; fi
  # shellcheck disable=SC2086
  ( cd "$R" && git add -f $base_files && git commit -q -m base )
  echo a2 >> "$R/src/a.py"; echo n > "$R/src/new.py"; ( cd "$R" && git add src/new.py )   # one staged, one modified, one untracked
  echo p2 >> "$R/docs/rolepod/plans/p.md"
  cached_before=$(git -C "$R" diff --cached --name-only); por_before=$(git -C "$R" status --porcelain)   # status may refresh the index: hash after it
  idx_before=$(shasum "$R/.git/index" | cut -d' ' -f1)
  t1=$(tree "$R"); rc=$?
  eq "$mode: tree exit 0, one id" "$rc ${#t1}" "0 40"
  eq "$mode: A7 diff --cached unchanged" "$(git -C "$R" diff --cached --name-only)" "$cached_before"
  eq "$mode: A7 status --porcelain unchanged" "$(git -C "$R" status --porcelain)" "$por_before"
  eq "$mode: A7 real index file byte-identical" "$(shasum "$R/.git/index" | cut -d' ' -f1)" "$idx_before"
  eq "$mode: tree has the working code, no docs/rolepod" "$(git -C "$R" ls-tree -r --name-only "$t1" | tr '\n' ' ')" "$( [ "$mode" = tracked ] && echo '.rolepod/docs-tracked ')$( [ "$mode" = ignored ] && echo '.gitignore ')src/a.py src/b.py src/new.py "
  ( cd "$R" && git add -f docs/rolepod && git commit -q -m 'docs: plan' -- docs/rolepod ) 2>/dev/null
  eq "$mode: tree equal before and after the docs: commit" "$(tree "$R")" "$t1"
  th=$(tree "$R" HEAD)
  eq "$mode: tree <rev> is one 40-char id" "${#th}" "40"
  eq "$mode: tree <rev> holds exactly the non-docs files of that commit" "$(git -C "$R" ls-tree -r --name-only "$th" | tr '\n' ' ')" "$( [ "$mode" = tracked ] && echo '.rolepod/docs-tracked ')$( [ "$mode" = ignored ] && echo '.gitignore ')src/a.py "
  check "$mode: tree <rev> ignores the working tree (≠ tree without rev)" test "$th" != "$(tree "$R")"
  eq "$mode: tree HEAD equals tree HEAD~1 (the docs: commit adds nothing else)" "$th" "$(tree "$R" HEAD~1)"
  eq "$mode: A7 index still unchanged after the commit-time run" "$(git -C "$R" status --porcelain | grep -c '^A  src/new.py')" "1"
done
R=$(newrepo tree-badrev)
tree "$R" nosuchrev >/dev/null; rc=$?
check "bad rev: non-zero exit" test "$rc" -ne 0
eq "temp index dir never leaks (ok + failed runs)" "$(ls -A "$TMP/tmpd" | wc -l | tr -d ' ')" "0"
bash "$DM" -C "$R" tree a b >/dev/null 2>&1; eq "tree with two operands → exit 2" "$?" "2"
bash "$DM" -C "$R" status HEAD >/dev/null 2>&1; eq "status with an operand → exit 2" "$?" "2"
bash "$DM" -C "$R" tree --bogus >/dev/null 2>&1; eq "tree with a flag operand → exit 2" "$?" "2"
R="$TMP/tree-unborn"; mkdir -p "$R" && git -C "$R" init -q; echo x > "$R/f"
eq "unborn HEAD: tree still works" "$(tree "$R" | wc -c | tr -d ' ')" "41"

echo "▸ rescue"
mkwt() { # $1 = mode (ignored|tracked), $2 = name, $3 = branch → base $TMP/$2, worktree $TMP/$2-wt
  local m="$1" d="$TMP/$2"
  mkrepo "$d"
  mkdir -p "$d/src" "$d/docs/rolepod/plans"
  echo code > "$d/src/a.py"
  if [ "$m" = ignored ]; then printf 'docs/rolepod/\n' > "$d/.gitignore"
  else printf 'docs/rolepod/maps/\n' > "$d/.gitignore"; echo old > "$d/docs/rolepod/plans/mod.md"; fi
  ( cd "$d" && git add -f -A . && git commit -q -m base && git worktree add -q -b "$3" "$d-wt" )
}
for mode in ignored tracked; do
  B="$TMP/rs-$mode"; W="$B-wt"; br="feat/x"
  mkwt "$mode" "rs-$mode" "$br"
  mkdir -p "$W/docs/rolepod/plans" "$W/docs/rolepod/maps"
  echo newplan > "$W/docs/rolepod/plans/new.md"        # ??
  echo map > "$W/docs/rolepod/maps/m.md"               # !! in both modes
  echo same > "$W/docs/rolepod/plans/same.md"
  echo wtver > "$W/docs/rolepod/plans/diff.md"
  mkdir -p "$B/docs/rolepod/plans"
  echo same > "$B/docs/rolepod/plans/same.md"; echo basever > "$B/docs/rolepod/plans/diff.md"
  if [ "$mode" = tracked ]; then echo modified > "$W/docs/rolepod/plans/mod.md"; fi   # M
  out=$(bash "$DM" rescue "$W" 2>&1); rc=$?
  eq "$mode: rescue exit 0" "$rc" "0"
  eq "$mode: untracked plan copied" "$(cat "$B/docs/rolepod/plans/new.md" 2>&1)" "newplan"
  eq "$mode: ignored map copied" "$(cat "$B/docs/rolepod/maps/m.md" 2>&1)" "map"
  eq "$mode: identical file skipped (no .from copy)" "$(ls "$B/docs/rolepod/plans" | grep -c '^same.md.from')" "0"
  eq "$mode: differing base file untouched" "$(cat "$B/docs/rolepod/plans/diff.md")" "basever"
  eq "$mode: differing worktree copy kept as .from-<branch>" "$(cat "$B/docs/rolepod/plans/diff.md.from-feat-x" 2>&1)" "wtver"
  if [ "$mode" = tracked ]; then
    eq "tracked: modified tracked doc → base version kept" "$(cat "$B/docs/rolepod/plans/mod.md")" "old"
    eq "tracked: modified tracked doc saved as .from-<branch>" "$(cat "$B/docs/rolepod/plans/mod.md.from-feat-x" 2>&1)" "modified"
    eq "tracked: one printed line per differing file" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "2"
  else
    eq "ignored: one printed line, naming the .from file" "$out" "rescue: docs/rolepod/plans/diff.md differs from base; kept as docs/rolepod/plans/diff.md.from-feat-x"
  fi
  eq "$mode: worktree still intact" "$(cat "$W/docs/rolepod/plans/new.md")" "newplan"
  out2=$(bash "$DM" rescue "$W" 2>&1); rc=$?
  eq "$mode: rerun exit 0, no new line (idempotent)" "$rc|$(printf '%s\n' "$out2" | grep -c .)" "0|0"
  eq "$mode: rerun leaves no .from.1 file" "$(find "$B/docs" -name '*.from-*.1' | wc -l | tr -d ' ')" "0"
  git -C "$B" worktree remove --force "$W" >/dev/null 2>&1
  eq "$mode: after rescue exit 0, remove --force loses nothing" "$(cat "$B/docs/rolepod/plans/new.md")$(cat "$B/docs/rolepod/maps/m.md")" "newplanmap"
done

# a base that changed again since the first rescue: a third version is kept, not clobbered
mkwt ignored rs-twice feat/y >/dev/null 2>&1
B="$TMP/rs-twice"; W="$B-wt"
mkdir -p "$W/docs/rolepod/plans" "$B/docs/rolepod/plans"
echo v1 > "$B/docs/rolepod/plans/p.md"; echo v2 > "$W/docs/rolepod/plans/p.md"; echo v3 > "$B/docs/rolepod/plans/p.md.from-feat-y"
bash "$DM" rescue "$W" >/dev/null 2>&1
eq "existing .from file is never overwritten" "$(cat "$B/docs/rolepod/plans/p.md.from-feat-y")" "v3"
eq "…the worktree copy lands under a counter" "$(cat "$B/docs/rolepod/plans/p.md.from-feat-y.1" 2>&1)" "v2"
eq "…and the base plan is untouched" "$(cat "$B/docs/rolepod/plans/p.md")" "v1"

echo "▸ B1: dirt outside docs/rolepod → exit 4, nothing copied"
for dirt in modified untracked staged; do
  mkwt ignored "b1-$dirt" b1; B="$TMP/b1-$dirt"; W="$B-wt"
  mkdir -p "$W/docs/rolepod/plans"; echo p > "$W/docs/rolepod/plans/new.md"
  case "$dirt" in
    modified) echo more >> "$W/src/a.py" ;;
    untracked) echo u > "$W/src/u.py" ;;
    staged) echo s > "$W/src/s.py"; git -C "$W" add src/s.py ;;
  esac
  por=$(git -C "$W" status --porcelain)
  bash "$DM" rescue "$W" >/dev/null 2>&1; rc=$?
  eq "B1 $dirt code: exit 4" "$rc" "4"
  eq "B1 $dirt code: no doc copied to base" "$([ -e "$B/docs/rolepod/plans/new.md" ] && echo yes || echo no)" "no"
  eq "B1 $dirt code: worktree status unchanged" "$(git -C "$W" status --porcelain)" "$por"
done
mkwt ignored b1-ignored-ok b1i; B="$TMP/b1-ignored-ok"; W="$B-wt"
mkdir -p "$W/node_modules" "$W/docs/rolepod/plans"; echo x > "$W/node_modules/x"; printf 'node_modules/\n' >> "$B/.git/info/exclude"
echo p > "$W/docs/rolepod/plans/new.md"
bash "$DM" rescue "$W" >/dev/null 2>&1; eq "an ignored non-docs file is not dirt → exit 0" "$?" "0"
eq "…and the doc was copied" "$(cat "$B/docs/rolepod/plans/new.md" 2>&1)" "p"

echo "▸ rescue: renames, odd names, a failing git"
mkwt tracked rs-odd feat/odd; B="$TMP/rs-odd"; W="$B-wt"
git -C "$W" mv docs/rolepod/plans/mod.md docs/rolepod/plans/mod2.md        # staged rename inside docs
mkdir -p "$W/docs/rolepod/plans"; echo sp > "$W/docs/rolepod/plans/a b \"q\".md"
bash "$DM" rescue "$W" >/dev/null 2>&1; rc=$?
eq "rename + spaces/quotes: exit 0" "$rc" "0"
eq "staged rename: the new name arrives" "$(cat "$B/docs/rolepod/plans/mod2.md" 2>&1)" "old"
eq "file named with spaces and quotes arrives" "$(cat "$B/docs/rolepod/plans/a b \"q\".md" 2>&1)" "sp"
mkwt ignored rs-badidx b2; B="$TMP/rs-badidx"; W="$B-wt"
mkdir -p "$W/docs/rolepod/plans"; echo p > "$W/docs/rolepod/plans/new.md"
printf 'garbage' > "$(git -C "$W" rev-parse --absolute-git-dir)/index"
bash "$DM" rescue "$W" >/dev/null 2>&1; rc=$?
eq "a failing git status is exit 1, never a silent 0" "$rc" "1"
eq "…and the worktree doc is still there" "$(cat "$W/docs/rolepod/plans/new.md")" "p"
R=$(newrepo tree-cmdname); git -C "$R" branch ignore
eq "tree <rev> named like a command (branch 'ignore')" "$(tree "$R" ignore | wc -c | tr -d ' ')" "41"

echo "▸ B4: a failed copy → exit 1"
if [ "$(id -u)" != 0 ]; then
  mkwt ignored b4 b4; B="$TMP/b4"; W="$B-wt"
  mkdir -p "$W/docs/rolepod/plans" "$B/docs/rolepod/plans"
  echo p1 > "$W/docs/rolepod/plans/one.md"; echo p2 > "$W/docs/rolepod/plans/two.md"
  chmod a-w "$B/docs/rolepod/plans"
  bash "$DM" rescue "$W" >/dev/null 2>&1; rc=$?
  chmod u+w "$B/docs/rolepod/plans"
  eq "B4: read-only base dir → exit 1" "$rc" "1"
  eq "B4: worktree docs intact" "$(cat "$W/docs/rolepod/plans/one.md")" "p1"
  bash "$DM" rescue "$W" >/dev/null 2>&1; eq "B4: after the dir is fixed, a rerun → exit 0" "$?" "0"
  eq "B4: and both files arrive" "$(cat "$B/docs/rolepod/plans/one.md")$(cat "$B/docs/rolepod/plans/two.md")" "p1p2"
else
  ok "B4 skipped (root ignores directory modes)"
fi

echo "▸ rescue operands"
bash "$DM" rescue >/dev/null 2>&1; eq "rescue without a worktree → exit 2" "$?" "2"
err=$(bash "$DM" rescue "$TMP/rs-twice" 2>&1 >/dev/null); rc=$?
eq "rescue on the main checkout → exit 2" "$rc" "2"
check "…with the main-checkout message, not usage" grep -qF 'main checkout' <<<"$err"
bash "$DM" rescue "$TMP" >/dev/null 2>&1; eq "rescue outside a repo → exit 1" "$?" "1"
bash "$DM" rescue "$TMP/rs-ignored-wt" extra >/dev/null 2>&1; eq "rescue with two operands → exit 2" "$?" "2"

echo "▸ fix round: failed git add, dirty .gitignore"
for m in track ignore; do
  R=$(newrepo addfail-$m)
  : > "$R/.git/index.lock"   # every git add now fails
  out=$(bash "$DM" -C "$R" $m 2>"$TMP/addfail-$m.err"); rc=$?
  [ "$rc" -ne 0 ] && ok "F3: $m with a failing git add → exit $rc" || bad "F3: $m with a failing git add exited 0"
  check "F3: $m names the failed add on stderr" grep -q 'git add failed' "$TMP/addfail-$m.err"
  case "$out" in *"git commit"*|*"commit -m"*) bad "F3: $m printed a commit line after a failed add" ;; *) ok "F3: $m prints no commit line" ;; esac
done
R=$(newrepo ig-dirty)
printf 'node_modules/\n' > "$R/.gitignore"
( cd "$R" && git add .gitignore && git commit -q -m gi )
printf 'node_modules/\ndist/\n' > "$R/.gitignore"   # uncommitted edit before ignore
out=$(bash "$DM" -C "$R" ignore 2>/dev/null)
eq "F4: dirty .gitignore → one note line" "$(printf '%s\n' "$out" | grep -c '^note: .gitignore already had uncommitted changes')" "1"
check "F4: the commit stays the last line" bash -c "printf '%s\n' \"\$1\" | tail -n 1 | grep -q 'commit -m'" _ "$out"
R=$(newrepo ig-clean)
printf 'node_modules/\n' > "$R/.gitignore"
( cd "$R" && git add .gitignore && git commit -q -m gi )
out=$(bash "$DM" -C "$R" ignore 2>/dev/null)
eq "F4: clean .gitignore → no note" "$(printf '%s\n' "$out" | grep -c '^note:')" "0"

echo "▸ skill commands: C2 worktree exclude, C3 rescue then remove (run as the skills word them)"
SK="$REPO_DIR/core/skills"
c2_of() { # the C2 command, cut out of one skill line
  local l; l=$(grep -F 'git check-ignore -q .worktrees/ ||' "$1" | head -1)
  l=${l#*git check-ignore -q .worktrees/ ||}; l=${l%%info/exclude)\"*}
  printf 'git check-ignore -q .worktrees/ ||%sinfo/exclude)"' "$l"
}
for f in using-rolepod orchestrating-plans; do
  C2=$(c2_of "$SK/$f/SKILL.md")
  check "C2 found in $f" grep -qF 'printf' <<<"$C2"
  R=$(newrepo c2-$f); ( cd "$R" && git commit -q --allow-empty -m base )
  gi_before=$(cat "$R/.gitignore" 2>/dev/null; echo end)
  ( cd "$R" && bash -c "$C2" ) >/dev/null 2>&1
  eq "C2 ($f) from the main checkout: one .worktrees/ line in info/exclude" "$(grep -c '^\.worktrees/$' "$R/.git/info/exclude")" "1"
  ( cd "$R" && bash -c "$C2" ) >/dev/null 2>&1
  eq "C2 ($f) twice: still one line" "$(grep -c '^\.worktrees/$' "$R/.git/info/exclude")" "1"
  ( cd "$R" && git worktree add -q .worktrees/t -b t/$f && echo x > .worktrees/t/x && git add -A )
  eq "C2 ($f): git add -A stages no gitlink" "$(git -C "$R" ls-files -s | grep -c '^160000')" "0"
  eq "C2 ($f): .gitignore unchanged" "$(cat "$R/.gitignore" 2>/dev/null; echo end)" "$gi_before"
  # from inside a linked worktree the rule lands in the shared info/exclude
  R=$(newrepo c2w-$f); ( cd "$R" && git commit -q --allow-empty -m base && git worktree add -q "$TMP/c2w-$f-wt" -b w/$f )
  ( cd "$TMP/c2w-$f-wt" && bash -c "$C2" ) >/dev/null 2>&1
  eq "C2 ($f) from a linked worktree: .worktrees/ in the shared info/exclude" "$(grep -c '^\.worktrees/$' "$R/.git/info/exclude")" "1"
done

l=$(grep -F 'scripts/docs-mode.sh rescue <wt>` exits 0 →' "$SK/finish-work/SKILL.md" | head -1)
l=${l#*\`scripts/docs-mode.sh rescue <wt>\` exits 0 → \`}; C3_RM=${l%%\`*}
check "C3 found in finish-work" test "$C3_RM" = 'git worktree remove --force <wt>'
c3_run() { # $1 = base, $2 = worktree: rescue then remove, as the skill chains them
  ( cd "$1" && bash "$DM" rescue "$2" && eval "${C3_RM//<wt>/\"\$2\"}" ) >/dev/null 2>&1
}
mkwt ignored c3 feat/c3; B="$TMP/c3"; W="$B-wt"
mkdir -p "$W/docs/rolepod/plans"; echo kept > "$W/docs/rolepod/plans/p.md"
c3_run "$B" "$W"; rc=$?
eq "C3: rescue 0 then remove → exit 0" "$rc" "0"
eq "C3: the doc survives in the base" "$(cat "$B/docs/rolepod/plans/p.md" 2>&1)" "kept"
check "C3: the worktree is gone" test ! -e "$W"
mkwt ignored c3d feat/c3d; B="$TMP/c3d"; W="$B-wt"
mkdir -p "$W/docs/rolepod/plans"; echo kept > "$W/docs/rolepod/plans/p.md"; echo dirt >> "$W/src/a.py"
c3_run "$B" "$W"; rc=$?
[ "$rc" -ne 0 ] && ok "C3: dirt outside docs → the chain stops (exit $rc)" || bad "C3: dirt outside docs still exited 0"
check "C3: …and the worktree stays, never --force" test -d "$W"

echo "▸ real repo untouched"
eq "real HEAD did not move" "$(git -C "$REPO_DIR" rev-parse HEAD)" "$REAL_HEAD_BEFORE"
eq "real index did not change" "$(git -C "$REPO_DIR" diff --cached --name-only)" "$REAL_STAGED_BEFORE"

echo ""
if [ "$fail" -ne 0 ]; then echo "docs-mode: FAIL"; exit 1; fi
echo "docs-mode: all passed"
