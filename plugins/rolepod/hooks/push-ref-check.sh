#!/bin/bash
# PreToolUse(Bash) — show what a `git push` would actually publish.
#
# A push publishes the REF, not the commit you just made. In a shared
# worktree another session's local merge rides out on your push; that is a
# measured incident, not a hypothetical. The defence in doctrine is to read
# `git log @{push}..HEAD` first, which is a thing to remember at the moment
# of least attention — a two-line comment fix.
#
# This hook only shows; it never denies. The incident happened because nobody
# looked, not because someone looked and judged wrong, so the cheap half is
# the whole fix until a "looked and still missed it" case exists. Deciding
# whose commit is whose would need a sha->session ledger, and a rebase
# rewrites every sha — which is exactly the branch-per-worktree flow rolepod
# now recommends.
#
# Speaks only when the push would publish 2+ commits. Pushing your own single
# commit is the common case and needs no line.
#
# KNOWN LIMIT, deliberate. Commands are tokenised with shlex, which knows
# whitespace and quoting but not shell grammar. A push is therefore missed
# when an operator is glued to a word (`git push; echo done`), inside command
# substitution (`VAR=$(git push)`), or after a shell keyword (`do git push`).
# Closing the gap means embedding a shell parser in a nudge. Missing a line
# costs a line; the hook never denies, so it fails on the safe side. Do not
# widen the token table to chase one more form — replace the tokeniser or
# leave it.
set -uo pipefail

INPUT=$(cat 2>/dev/null || true)

# Bash tool only, and only a real `git push` — not `git push --help`, not a
# string that merely mentions it.
IS_PUSH=$(printf '%s' "$INPUT" | python3 -I -c "
import json, sys, shlex
try:
    d = json.load(sys.stdin)
except Exception:
    print('no'); raise SystemExit
if d.get('tool_name') != 'Bash':
    print('no'); raise SystemExit
cmd = (d.get('tool_input', {}) or {}).get('command', '') or ''
try:
    toks = shlex.split(cmd)
except ValueError:
    toks = cmd.split()
# 'git' must sit in COMMAND position — so 'cd x && git push' hits while
# 'echo git push' does not. Command position means the start, or after a
# shell operator, or after only the things that legitimately prefix a
# command: an env assignment, sudo, env, command, time, nohup, xargs.
OPS = {'&&', '||', ';', '|', '(', '{', '!'}
# Open-ended by nature: a prefix not listed costs a missing line, never a
# wrong action, which is the right side to fail on for an informational hook.
PREFIX = {'sudo', 'doas', 'env', 'command', 'time', 'nohup', 'xargs', 'exec',
          'nice', 'ionice', 'chronic', 'stdbuf', 'timeout'}
# git's own options that swallow the NEXT token, so 'git -C /tmp push' does
# not read '/tmp' as the subcommand.
TAKES_VALUE = {'-C', '-c', '--git-dir', '--work-tree', '--namespace', '--exec-path'}


# A command line is a series of segments split on shell operators. Within a
# segment the command is its first word, after any env assignments. 'git' is
# a real invocation when the segment's own command is git, or is a prefix
# that runs another command (sudo, xargs, nice ...) — a prefix carries its
# own flags and values, so 'sudo -u root git push' and 'xargs -I{} git push'
# both qualify, while 'echo git push' does not: echo is neither.
def segments(toks):
    seg, out = [], []
    for t in toks:
        if t in OPS:
            if seg:
                out.append(seg)
            seg = []
        else:
            seg.append(t)
    if seg:
        out.append(seg)
    return out


def segment_runs_git(seg):
    k = 0
    while k < len(seg):
        t = seg[k]
        if '=' in t and not t.startswith('-') and t.split('=', 1)[0].isidentifier():
            k += 1
            continue
        break
    if k >= len(seg):
        return None
    head = seg[k]
    if head == 'git':
        return seg[k:]
    if head not in PREFIX:
        return None
    # Under a prefix, the wrapped command is the first later 'git' token.
    for j in range(k + 1, len(seg)):
        if seg[j] == 'git':
            return seg[j:]
    return None


# Returns None when this is not a publishing push, else (remote, src, dst).
# All three are empty unless the command names them; the caller then works the
# range out from the branch's own upstream and HEAD.
def parse_push(toks):
    for seg in segments(toks):
        run = segment_runs_git(seg)
        if run is None:
            continue
        rest = run[1:]
        k = 0
        while k < len(rest):
            tok = rest[k]
            if tok in TAKES_VALUE:
                k += 2
                continue
            if tok.startswith('-'):
                k += 1
                continue
            if tok != 'push':
                break  # some other git command; a push may still follow
            tail = rest[k + 1:]
            # A run that publishes nothing is not worth a line.
            if any(f in tail for f in ('--dry-run', '-n', '--help', '-h')):
                return None
            # A multi-ref push cannot be described by one range; say nothing
            # rather than report a number that describes a different ref.
            if any(f in tail for f in ('--mirror', '--all', '--tags')):
                return None
            args = [a for a in tail if not a.startswith('-')]
            remote = args[0] if args else ''
            src = dst = ''
            for a in args[1:]:
                spec = a.lstrip('+')  # a force refspec is still that refspec
                if ':' in spec:
                    src, dst = spec.split(':', 1)
                else:
                    # 'git push origin main' writes main from local main —
                    # the source is that ref, not whatever HEAD happens to be.
                    src = dst = spec
                break
            return (remote, src, dst)
        # fall through: keep scanning for a later 'git push' on the same line
    return None


res = parse_push(toks)
if res is None:
    # A payload handed to a shell is still a command line: recurse once.
    for i, t in enumerate(toks):
        if t in ('bash', 'sh', 'zsh'):
            for j in range(i + 1, len(toks) - 1):
                if toks[j] == '-c':
                    try:
                        inner = shlex.split(toks[j + 1])
                    except ValueError:
                        inner = toks[j + 1].split()
                    res = parse_push(inner)
                    break
        if res is not None:
            break
if res is None:
    print('no')
else:
    print('yes', res[0], res[1], res[2])
" 2>/dev/null || echo no)

# shellcheck disable=SC2086
set -- $IS_PUSH
[ "${1:-no}" = "yes" ] || exit 0
PUSH_REMOTE="${2:-}"
PUSH_SRC="${3:-}"
PUSH_DST="${4:-}"

command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# HEAD and @ are revs, not ref names: `git push origin HEAD` writes the
# branch you are on, and looking up `origin/HEAD` instead resolves to the
# remote's default branch — which reports a real count of ordinary ancestor
# commits as if they needed clearing. A fabricated warning is worse than none.
case "$PUSH_DST" in
  HEAD|@) PUSH_DST=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true) ;;
esac

RANGE=""
# An explicit `src:dst` refspec writes dst, which need not be this branch —
# `git push origin HEAD:release` publishes against release, so measuring
# against the branch's own upstream reports the wrong count (and, under the
# 2-commit threshold, reports nothing at all).
if [ -n "$PUSH_DST" ]; then
  CAND="${PUSH_REMOTE:-origin}/$PUSH_DST"
  git rev-parse --verify --quiet "$CAND" >/dev/null 2>&1 && RANGE="$CAND"
  # A destination branch that does not exist yet is created whole by this
  # push; there is no "someone else's commit already there" to warn about.
  [ -z "$RANGE" ] && exit 0
fi

# Otherwise: what the push would publish from this branch. `@{push}` resolves
# only once the branch has a push destination; a branch on its first push has
# none, so fall back to the remote's default branch. Local reads, no network.
[ -n "$RANGE" ] || RANGE=$(git rev-parse --abbrev-ref '@{push}' 2>/dev/null || true)
# `@{push}` resolves to a NAME even when that remote branch does not exist
# yet (push.default=current on a branch never pushed), and a range against a
# missing ref counts zero — silently the wrong answer. Verify it resolves.
[ -n "$RANGE" ] && ! git rev-parse --verify --quiet "$RANGE" >/dev/null 2>&1 && RANGE=""
if [ -z "$RANGE" ]; then
  BASE=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
  git rev-parse --verify "$BASE" >/dev/null 2>&1 || exit 0
  RANGE="$BASE"
fi

# The tip being published is the refspec's SOURCE, not whatever is checked
# out: `git push origin main:main` from branch feature publishes main, and
# measuring HEAD there describes an unrelated branch.
TIP="HEAD"
if [ -n "$PUSH_SRC" ]; then
  git rev-parse --verify --quiet "$PUSH_SRC" >/dev/null 2>&1 && TIP="$PUSH_SRC"
fi

COUNT=$(git rev-list --count "$RANGE".."$TIP" 2>/dev/null || echo 0)
case "$COUNT" in ''|*[!0-9]*) exit 0 ;; esac
[ "$COUNT" -ge 2 ] || exit 0

LIST=$(git log --oneline --format='%h %s' "$RANGE".."$TIP" 2>/dev/null | cut -c1-60 | head -6 | tr '\n' ';' | sed 's/;$//')
[ -n "$LIST" ] || exit 0

ROLEPOD_HOOK_MSG="⇧ this push publishes $COUNT commits, not only your last: $LIST. Fix: confirm each one is yours or cleared for publication by its author — approved work is not a cleared push; a session may be holding an approved commit unpushed on purpose. Exception: you already read this ref since your last commit." \
python3 -I -c '
import json, os, sys
payload = json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": os.environ["ROLEPOD_HOOK_MSG"],
}}, ensure_ascii=False)
sys.stdout.buffer.write(payload.encode("utf-8") + b"\n")
' 2>/dev/null || exit 0
