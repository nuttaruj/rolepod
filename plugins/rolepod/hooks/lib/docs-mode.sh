#!/bin/bash
# docs-mode.sh — one home for "is docs/rolepod/ tracked or ignored in this repo".
#
#   docs-mode.sh [-C <dir>] status   -> tracked | ignored | undecided   (exit 0)
#   docs-mode.sh [-C <dir>] track    -> marker + tasks/.gitignore staged, docs/rolepod/ rule dropped
#   docs-mode.sh [-C <dir>] ignore   -> marker dropped, docs/rolepod/ rule in .gitignore
#
# exit: 1 not a git repo · 2 usage · 3 track blocked by another ignore rule.
# track / ignore touch only .gitignore, .rolepod/docs-tracked and
# docs/rolepod/tasks/.gitignore (+ their index entries), never commit, and
# end with the commit command for exactly the files they changed.
set -uo pipefail

MARKER=".rolepod/docs-tracked"
TASKS_GI="docs/rolepod/tasks/.gitignore"
RULE="docs/rolepod/"

usage() { echo "usage: docs-mode.sh [-C <dir>] status|track|ignore" >&2; exit 2; }

DIR=""
CFLAG=0
CMD=""
# -C <dir> may stand before or after the command (callers use both orders).
while [ $# -gt 0 ]; do
  case "$1" in
    -C) [ $# -ge 2 ] && [ "$CFLAG" = 0 ] || usage; DIR="$2"; CFLAG=1; shift 2 ;;
    status|track|ignore) [ -z "$CMD" ] || usage; CMD="$1"; shift ;;
    *) usage ;;
  esac
done
[ -n "$CMD" ] || usage

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

case "$CMD" in
  status) do_status; tasks_hint ;;
  track) do_track ;;
  ignore) do_ignore ;;
esac
