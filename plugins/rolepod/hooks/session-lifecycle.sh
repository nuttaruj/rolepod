#!/bin/bash
# Session lifecycle hook — lock at SessionStart, unlock at Stop.
#
# Why: 2+ Claude sessions editing the same checkout race each other —
# Session A writes file.ts → Session B opens stale → B writes back → A's
# edits lost. Hard to spot, easy to repeat. This hook surfaces the
# situation at SessionStart so Lead spawns an isolated worktree before
# any edit lands. At Stop the lock is released so the next session does
# not see a phantom sibling.
#
# Mechanism: HOME-scoped lock dir per worktree (sha256 of abs path),
# one file per session. SessionStart scans siblings whose mtime is within
# 30 min. Stale locks (>30 min) get pruned on contact. Stop removes the
# current session's lock. No repo pollution.
#
# Override: ROLEPOD_ALLOW_SHARED_WORKTREE=1 silences the SessionStart
# warning for the rare intentional case (e.g. read-only review session).
#
# Modes:
#   --lock     SessionStart entry — register session + warn on siblings
#   --unlock   Stop entry — remove this session's lock
#
# Single file replaces the previous session-lock.sh + session-unlock.sh
# pair (PR 5 — hook consolidation).
#
# v2.7: also writes .rolepod/parent-active in the worktree as the
# Extension Protocol v1 marker for sibling plugins (rolepod-uiproof,
# rolepod-wplab). The marker IS the contract: present = a rolepod parent
# session owns this worktree, so a child writes its manifest into
# .rolepod/evidence/ for check-work to aggregate.
#
# v2.180.5: --unlock no longer removes the marker. Claude and Codex fire
# Stop at the end of EVERY turn, not at session end, so the old "last lock
# gone -> drop marker" logic cleared it after turn 1 and children fell back
# to standalone mode from turn 2 on. A stale marker is benign under the
# Extension Protocol (Cursor/Antigravity/opencode never remove it either) —
# it is refreshed on the next --lock, and a child reads it only as a hint
# to try with-rolepod mode.
set -euo pipefail

MODE="${1:---lock}"
case "$MODE" in
  --lock|--unlock) ;;
  *) echo "session-lifecycle.sh: unknown mode: $MODE (expected --lock | --unlock)" >&2; exit 0 ;;
esac
shift || true

# CLI identity (this task): Claude and Codex both run this script, so the
# adapter's own hooks.json states which one via --cli <name>. Content of the
# lock file becomes that name, so a sibling-warning reader can print a
# per-CLI breakdown instead of a bare count. No --cli given (older call site,
# manual invocation) -> "claude", the more common caller.
CLI_NAME="claude"
while [ $# -gt 0 ]; do
  case "$1" in
    --cli) CLI_NAME="${2:-claude}"; shift 2 ;;
    *) shift ;;
  esac
done

# Honor override env. SessionStart still writes our lock so siblings
# detect us; the env only silences the warning.
SILENT=0
[ "${ROLEPOD_ALLOW_SHARED_WORKTREE:-0}" = "1" ] && SILENT=1

INPUT=$(cat 2>/dev/null || echo '{}')
SESSION_ID=$(printf '%s' "$INPUT" | python3 -I -c "import sys,json
try: print(json.load(sys.stdin).get('session_id','') or '')
except Exception: print('')" 2>/dev/null || echo "")
CWD=$(printf '%s' "$INPUT" | python3 -I -c "import sys,json
try: print(json.load(sys.stdin).get('cwd','') or '')
except Exception: print('')" 2>/dev/null || echo "")
[ -z "$CWD" ] && CWD="$PWD"

# Only act inside a git worktree. Non-git dirs = no stomp risk.
WORKTREE=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0
PATH_HASH=$(printf '%s' "$WORKTREE" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
[ -z "$PATH_HASH" ] && exit 0
LOCK_DIR="$HOME/.rolepod/session-locks/$PATH_HASH"

if [ "$MODE" = "--unlock" ]; then
  # Route record (v2.105.0): the turn is complete -> the tier the Lead stated
  # in it lands in the phase-log (lib/route_check.py --record; once per turn,
  # fail-open). The manual append the router asked for was measured at 0 lines
  # in every product repo, so this is where the tier distribution comes from.
  LIB_DIR="$(cd "$(dirname "$0")" && pwd)/lib"
  ( cd "$CWD" 2>/dev/null && printf '%s' "$INPUT" | python3 "$LIB_DIR/route_check.py" --record ) 2>/dev/null || true
  [ -z "$SESSION_ID" ] && exit 0
  rm -f "$LOCK_DIR/$SESSION_ID.lock" 2>/dev/null || true
  # Release the files this session claimed (worktree-guard.sh registry) so a
  # sibling can pick them up once we are gone.
  rm -f "$LOCK_DIR/$SESSION_ID.files" 2>/dev/null || true
  exit 0
fi

# --lock path (SessionStart)
[ -z "$SESSION_ID" ] && SESSION_ID="unknown-$$-$(date +%s)"
mkdir -p "$LOCK_DIR" 2>/dev/null || exit 0

NOW=$(date +%s)
STALE_THRESHOLD=1800   # 30 min — covers most legit gaps between turns

# Scan siblings + prune stale. Use stat -f (BSD) with -c fallback (GNU).
# SIBLING_NAMES collects one CLI name per active sibling (newline-separated,
# no assoc arrays — /bin/bash on macOS is still 3.2) for the warning's
# per-CLI breakdown. A lock's content is the CLI name (this task); an empty
# lock (written by a version before this one) has none -> "unknown".
ACTIVE_SIBLINGS=0
SIBLING_NAMES=""
for lock in "$LOCK_DIR"/*.lock; do
  [ -f "$lock" ] || continue
  lock_basename=$(basename "$lock" .lock)
  [ "$lock_basename" = "$SESSION_ID" ] && continue

  mtime=$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null || echo 0)
  age=$((NOW - mtime))
  if [ "$age" -lt "$STALE_THRESHOLD" ]; then
    ACTIVE_SIBLINGS=$((ACTIVE_SIBLINGS + 1))
    sib_name=$(tr -d '[:space:]' < "$lock" 2>/dev/null || echo "")
    [ -z "$sib_name" ] && sib_name="unknown"
    SIBLING_NAMES="${SIBLING_NAMES}${sib_name}
"
  else
    rm -f "$lock" "$LOCK_DIR/$lock_basename.files" 2>/dev/null || true
  fi
done

# Sweep the other worktrees' dirs too: their locks are only pruned on
# contact, so a test fixture or a deleted worktree leaves them forever
# (measured: 109 dirs / 412 files). Stale = the same 30 min, locks only.
find "$(dirname "$LOCK_DIR")" -mindepth 2 -maxdepth 2 -name '*.lock' -mmin +30 -delete 2>/dev/null || true
# a .files registry ages differently (worktree-guard appends only the first
# time a file is edited this session): delete it only once its own .lock is
# gone, never on its own mtime
for _f in "$(dirname "$LOCK_DIR")"/*/*.files; do
  if [ -f "$_f" ] && [ ! -f "${_f%.files}.lock" ]; then rm -f "$_f" 2>/dev/null || true; fi   # a failing rm must not end SessionStart before our own lock is written
done
find "$(dirname "$LOCK_DIR")" -mindepth 1 -maxdepth 1 -type d -empty ! -path "$LOCK_DIR" -delete 2>/dev/null || true

# Write our lock. Content = this CLI's name (a sibling reader prints it in
# its breakdown); overwriting refreshes mtime on each SessionStart resume,
# same as the old touch did.
printf '%s' "$CLI_NAME" > "$LOCK_DIR/$SESSION_ID.lock" 2>/dev/null || true

# Extension Protocol v1: signal to child plugins (rolepod-uiproof, wplab)
# that rolepod parent is active in this worktree. Children read this file
# at skill execution to switch from standalone to with-rolepod mode.
# Content = protocol version. Refreshed every SessionStart.
#
# The marker MUST live at <git-root>/.rolepod/ — that path is the child-plugin
# IPC contract. To keep it from leaking into the user's commits, register it in
# .git/info/exclude (local, never committed) rather than the tracked .gitignore.
EXCLUDE_FILE=$(git -C "$WORKTREE" rev-parse --git-path info/exclude 2>/dev/null)
if [ -n "$EXCLUDE_FILE" ]; then
  [ -f "$EXCLUDE_FILE" ] || : > "$EXCLUDE_FILE" 2>/dev/null || true
  if ! grep -qxF '.rolepod/' "$EXCLUDE_FILE" 2>/dev/null; then
    if [ -s "$EXCLUDE_FILE" ] && [ -n "$(tail -c 1 "$EXCLUDE_FILE")" ]; then printf '\n' >> "$EXCLUDE_FILE" 2>/dev/null || true; fi   # no final newline → the append would corrupt the user's last rule
    printf '.rolepod/\n' >> "$EXCLUDE_FILE" 2>/dev/null || true
  fi
fi
mkdir -p "$WORKTREE/.rolepod" 2>/dev/null && \
  printf 'v1\n' > "$WORKTREE/.rolepod/parent-active" 2>/dev/null || true

# No sibling, or override active → silent.
if [ "$ACTIVE_SIBLINGS" -eq 0 ] || [ "$SILENT" -eq 1 ]; then
  exit 0
fi

BRANCH=$(git -C "$WORKTREE" branch --show-current 2>/dev/null || echo "HEAD")
SUGGEST_PATH="${WORKTREE}-task-$(date +%s)"

# Emit additionalContext so Lead reads it on turn 1 and self-acts. Env-pass the
# branch / path / count / names so a quote in a branch name cannot break the
# emitter (which would fail open on the exact concurrency risk this hook flags).
ROLEPOD_HOOK_SIBLINGS="$ACTIVE_SIBLINGS" ROLEPOD_HOOK_PATH="$SUGGEST_PATH" ROLEPOD_HOOK_BRANCH="$BRANCH" ROLEPOD_HOOK_NAMES="$SIBLING_NAMES" python3 -I -c "
import json, os
from collections import Counter
n = os.environ.get('ROLEPOD_HOOK_SIBLINGS', '?')
path = os.environ.get('ROLEPOD_HOOK_PATH', '')
branch = os.environ.get('ROLEPOD_HOOK_BRANCH', 'HEAD')
names = [x for x in os.environ.get('ROLEPOD_HOOK_NAMES', '').split(chr(10)) if x]
counts = Counter(names)
breakdown = ', '.join('%s ×%d' % (k, counts[k]) for k in sorted(counts))
detail = (': ' + breakdown) if breakdown else ''
msg = ('Sibling rolepod session(s) detected in this worktree (%s active%s). '
       'Concurrent edits will stomp each other. '
       'Before any Edit/Write: spawn an isolated worktree FIRST:\n\n'
       '  git worktree add %s %s\n'
       '  cd %s\n\n'
       'Then continue work there. Override with ROLEPOD_ALLOW_SHARED_WORKTREE=1 '
       'if this session is intentionally shared (e.g. read-only review).') % (n, detail, path, branch, path)
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': msg}}, ensure_ascii=False))
" 2>/dev/null || echo '{}'
