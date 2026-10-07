#!/bin/bash
# docs-mode.sh — one home for "is docs/rolepod/ tracked or ignored in this repo".
#
#   docs-mode.sh [-C <dir>] status   -> tracked | ignored | undecided   (exit 0)
#   docs-mode.sh [-C <dir>] track    -> marker + tasks/.gitignore staged, docs/rolepod/ rule dropped
#   docs-mode.sh [-C <dir>] ignore   -> marker dropped, docs/rolepod/ rule in .gitignore
#   docs-mode.sh [-C <dir>] tree [<rev>]  -> tree id without docs/rolepod (temp index)
#   docs-mode.sh rescue <worktree>   -> copy its docs/rolepod files into the base, never overwrite
#
# exit: 1 not a git repo, a git call failed (rescue: or a copy failed) · 2 usage (rescue: a
# main checkout) · 3 track blocked by another ignore rule · 4 rescue found changes outside
# docs/rolepod (nothing copied) · rescue 0 = worktree remove --force loses no docs.
# track / ignore touch only .gitignore, .rolepod/docs-tracked and
# docs/rolepod/tasks/.gitignore (+ their index entries), never commit, and
# end with the commit command for exactly the files they changed.
set -uo pipefail

MARKER=".rolepod/docs-tracked"
TASKS_GI="docs/rolepod/tasks/.gitignore"
RULE="docs/rolepod/"

usage() { echo "usage: docs-mode.sh [-C <dir>] status|track|ignore|tree [<rev>]|rescue <worktree>" >&2; exit 2; }

DIR=""
CFLAG=0
CMD=""
ARG=""
# -C <dir> may stand before or after the command (callers use both orders).
while [ $# -gt 0 ]; do
  case "$1" in
    -C) [ $# -ge 2 ] && [ "$CFLAG" = 0 ] || usage; DIR="$2"; CFLAG=1; shift 2 ;;
    -*) usage ;;
    *)
      if [ -n "$CMD" ] && { [ "$CMD" = tree ] || [ "$CMD" = rescue ]; } && [ -z "$ARG" ]; then ARG="$1"   # a rev / dir may be named like a command
      else
        case "$1" in status|track|ignore|tree|rescue) [ -z "$CMD" ] || usage; CMD="$1" ;; *) usage ;; esac
      fi
      shift ;;
  esac
done
[ -n "$CMD" ] || usage
[ "$CMD" != rescue ] || [ -n "$ARG" ] || usage
# rescue works on the worktree it is given, whatever -C says.
[ "$CMD" != rescue ] || DIR="$ARG"

ROOT=$(git -C "${DIR:-.}" rev-parse --show-toplevel 2>/dev/null) || { echo "docs-mode.sh: not a git repo: ${DIR:-.}" >&2; exit 1; }
[ -n "$ROOT" ] || { echo "docs-mode.sh: not a git repo: ${DIR:-.}" >&2; exit 1; }

g() { git -C "$ROOT" "$@"; }

do_status() {
  if [ -f "$ROOT/$MARKER" ]; then echo tracked
  elif g check-ignore -q --no-index "$RULE"; then echo ignored
  else echo undecided
  fi
}

# .gitignore does not apply to files already tracked: say so, never untrack.
tasks_hint() {
  local tracked
  tracked=$(g ls-files -- docs/rolepod/tasks)
  if printf '%s\n' "$tracked" | grep -vxF "$TASKS_GI" | grep -q .; then
    echo "hint: tracked files under docs/rolepod/tasks; to untrack run: git rm -r --cached docs/rolepod/tasks" >&2
  fi
}

# The commit command for the answer files that differ from HEAD in the index.
# `--` + only those paths: other staged files stay staged and out of the commit.
print_commit() {
  local f files="" pre="$1"
  for f in .gitignore "$MARKER" "$TASKS_GI"; do
    g diff --cached --quiet -- "$f" || files="$files $f"
  done
  [ -n "$files" ] || return 0
  [ -z "$pre" ] || echo "$pre"
  if [ "$CFLAG" = 1 ]; then
    printf "git -C %q commit -m 'chore: docs mode' --%s\n" "$ROOT" "$files"
  else
    echo "git commit -m 'chore: docs mode' --$files"
  fi
}

# Write $2 to $ROOT/$1 only when it differs; then force-add it.
put_file() {
  local rel="$1" content="$2"
  mkdir -p "$(dirname "$ROOT/$rel")"
  if [ ! -f "$ROOT/$rel" ] || [ "$(cat "$ROOT/$rel")" != "$content" ]; then
    printf '%s\n' "$content" > "$ROOT/$rel"
  fi
  g add -f -- "$rel"
}

do_track() {
  local gi="$ROOT/.gitignore" bak="" had=0 v
  if [ -f "$gi" ] && grep -qxF "$RULE" "$gi"; then
    had=1; bak=$(mktemp) || exit 1
    cp "$gi" "$bak"
    { grep -vxF "$RULE" "$bak" || true; } > "$gi"
  fi
  if g check-ignore -q --no-index "$RULE"; then
    v=$(g check-ignore -v --no-index "$RULE")
    [ "$had" = 0 ] || cat "$bak" > "$gi"   # blocked: leave .gitignore as it was
    [ -z "$bak" ] || rm -f "$bak"
    echo "docs-mode.sh: another ignore rule blocks $RULE (nothing changed):" >&2
    echo "$v" >&2
    exit 3
  fi
  [ -z "$bak" ] || rm -f "$bak"
  [ "$had" = 0 ] || g add -- .gitignore
  put_file "$MARKER" tracked
  put_file "$TASKS_GI" "$(printf '*\n!.gitignore')"
  tasks_hint
  print_commit ""
}

do_ignore() {
  local before gi="$ROOT/.gitignore" v src
  before=$(do_status)
  if g ls-files --error-unmatch -- "$MARKER" >/dev/null 2>&1; then g rm -q -f -- "$MARKER"
  else rm -f "$ROOT/$MARKER"; fi
  v=""
  g check-ignore -q --no-index "$RULE" && v=$(g check-ignore -v --no-index "$RULE")
  src="${v%%:*}"
  # A rule from a .gitignore inside the repo already answers; info/exclude, a
  # global excludes file or no rule at all does not (clone / worktree can't see it).
  case "$src" in
    "") ;;
    /*) src="" ;;
    *) [ "$(basename "$src")" = ".gitignore" ] || src="" ;;
  esac
  if [ -z "$src" ]; then
    if [ -s "$gi" ] && [ -n "$(tail -c 1 "$gi")" ]; then printf '\n' >> "$gi"; fi   # no final newline: the append would corrupt the last rule
    printf '%s\n' "$RULE" >> "$gi"
    g add -- .gitignore
  fi
  if [ "$before" = undecided ]; then
    print_commit "Tell the user: docs/rolepod/ stays out of git by default; answer track to commit it."
  else
    print_commit ""
  fi
}

# Tree id of <rev> (default: the working tree as `git add -A` sees it) without
# docs/rolepod. Every git call below runs on a temp index; the real one is never written.
TREE_TMP=""
do_tree() {
  TREE_TMP=$(mktemp -d) || exit 1
  trap 'rm -rf "$TREE_TMP"' EXIT
  trap 'rm -rf "$TREE_TMP"; exit 1' INT TERM
  export GIT_INDEX_FILE="$TREE_TMP/index"
  if [ -n "$ARG" ]; then
    g read-tree "$ARG" || exit 1
  else
    if g rev-parse -q --verify HEAD >/dev/null; then g read-tree HEAD || exit 1; fi
    g add -A || exit 1
  fi
  # -f: with <rev> the temp index differs from both HEAD and the file, and rm --cached refuses without it.
  g rm -r -q -f --cached --ignore-unmatch docs/rolepod || exit 1
  g write-tree || exit 1
}

# Copy the worktree's docs/rolepod files (untracked, ignored, modified) into its
# base checkout without overwriting anything. exit: 4 dirt outside docs/rolepod ·
# 1 a copy failed · 0 nothing left to lose in docs/rolepod (worktree remove --force is safe).
do_rescue() {
  local wt base branch st f rec path dest n rc=0 dirt list
  wt="$ROOT"
  # git calls that decide "safe to remove" run to a variable / file first: a failed git is exit 1, never "clean".
  base=$(g worktree list --porcelain) || exit 1
  base=$(printf '%s\n' "$base" | sed -n '1s/^worktree //p')
  [ -n "$base" ] || { echo "docs-mode.sh: cannot find the base checkout of $wt" >&2; exit 1; }
  if [ "$(cd "$base" && pwd -P)" = "$(cd "$wt" && pwd -P)" ]; then
    echo "docs-mode.sh: $wt is the main checkout, not a linked worktree" >&2; exit 2
  fi
  dirt=$(g --no-optional-locks status --porcelain -- . ':(exclude)docs/rolepod') || { echo "docs-mode.sh: git status failed in $wt" >&2; exit 1; }
  if [ -n "$dirt" ]; then
    echo "docs-mode.sh: uncommitted changes outside docs/rolepod in $wt; nothing copied" >&2; exit 4
  fi
  branch=$(g symbolic-ref -q --short HEAD || g rev-parse --short HEAD) || exit 1
  branch=${branch//\//-}
  TREE_TMP=$(mktemp -d) || exit 1
  trap 'rm -rf "$TREE_TMP"' EXIT
  list="$TREE_TMP/status"
  g --no-optional-locks status --porcelain -z --ignored -uall -- docs/rolepod > "$list" || { echo "docs-mode.sh: git status failed in $wt" >&2; exit 1; }
  while IFS= read -r -d '' rec; do
    st="${rec:0:2}"; path="${rec:3}"
    case "$st" in *R*|*C*) IFS= read -r -d '' _ ;; esac   # rename / copy: the next record is the old path
    case "$path" in docs/rolepod/*) ;; *) continue ;; esac
    f="$wt/$path"
    [ -f "$f" ] || [ -L "$f" ] || continue   # a deleted file has nothing to save
    dest="$base/$path"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      cmp -s "$f" "$dest" && continue
      n=0; dest="$base/$path.from-$branch"
      while [ -e "$dest" ] || [ -L "$dest" ]; do
        cmp -s "$f" "$dest" && continue 2
        n=$((n + 1)); dest="$base/$path.from-$branch.$n"
      done
      echo "rescue: $path differs from base; kept as ${dest#"$base"/}"
    fi
    if ! { mkdir -p "$(dirname "$dest")" && cp -P "$f" "$dest"; }; then
      echo "docs-mode.sh: copy failed: $path -> $dest" >&2; rc=1
    fi
  done < "$list"
  exit "$rc"
}

case "$CMD" in
  tree) do_tree ;;
  rescue) do_rescue ;;
  status) do_status; tasks_hint ;;
  track) do_track ;;
  ignore) do_ignore ;;
esac
