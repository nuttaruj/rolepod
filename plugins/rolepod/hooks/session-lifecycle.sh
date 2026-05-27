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
# v2.7: also writes/removes .rolepod/parent-active in the worktree as the
# Extension Protocol v1 marker for sibling plugins (rolepod-uiproof,
# rolepod-wplab). See docs/EXTENSION-PROTOCOL.md.
set -euo pipefail

MODE="${1:---lock}"
case "$MODE" in
  --lock|--unlock) ;;
  *) echo "session-lifecycle.sh: unknown mode: $MODE (expected --lock | --unlock)" >&2; exit 0 ;;
esac

# Honor override env. SessionStart still writes our lock so siblings
# detect us; the env only silences the warning.
SILENT=0
[ "${ROLEPOD_ALLOW_SHARED_WORKTREE:-0}" = "1" ] && SILENT=1

INPUT=$(cat 2>/dev/null || echo '{}')
SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('session_id','') or '')
except Exception: print('')" 2>/dev/null || echo "")
CWD=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('cwd','') or '')
except Exception: print('')" 2>/dev/null || echo "")
[ -z "$CWD" ] && CWD="$PWD"

# Only act inside a git worktree. Non-git dirs = no stomp risk.
WORKTREE=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0
PATH_HASH=$(printf '%s' "$WORKTREE" | shasum -a 256 2>/dev/null | awk '{print $1}' | head -c 16)
[ -z "$PATH_HASH" ] && exit 0
LOCK_DIR="$HOME/.claude/.session-locks/$PATH_HASH"

if [ "$MODE" = "--unlock" ]; then
  [ -z "$SESSION_ID" ] && exit 0
  rm -f "$LOCK_DIR/$SESSION_ID.lock" 2>/dev/null || true

  # Extension Protocol v1: if no rolepod sessions remain in this worktree,
  # drop the parent-active marker so child plugins (rolepod-uiproof, wplab)
  # fall back to standalone mode on their next skill run.
  remaining=$(find "$LOCK_DIR" -maxdepth 1 -name "*.lock" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${remaining:-0}" -eq 0 ]; then
    rm -f "$WORKTREE/.rolepod/parent-active" 2>/dev/null || true
    rmdir "$WORKTREE/.rolepod" 2>/dev/null || true
  fi
  exit 0
fi

# --lock path (SessionStart)
[ -z "$SESSION_ID" ] && SESSION_ID="unknown-$$-$(date +%s)"
mkdir -p "$LOCK_DIR" 2>/dev/null || exit 0

NOW=$(date +%s)
STALE_THRESHOLD=1800   # 30 min — covers most legit gaps between turns

# Scan siblings + prune stale. Use stat -f (BSD) with -c fallback (GNU).
ACTIVE_SIBLINGS=0
for lock in "$LOCK_DIR"/*.lock; do
  [ -f "$lock" ] || continue
  lock_basename=$(basename "$lock" .lock)
  [ "$lock_basename" = "$SESSION_ID" ] && continue

  mtime=$(stat -f %m "$lock" 2>/dev/null || stat -c %Y "$lock" 2>/dev/null || echo 0)
  age=$((NOW - mtime))
  if [ "$age" -lt "$STALE_THRESHOLD" ]; then
    ACTIVE_SIBLINGS=$((ACTIVE_SIBLINGS + 1))
  else
    rm -f "$lock" 2>/dev/null || true
  fi
done

# Write our lock (touch updates mtime on each SessionStart resume).
touch "$LOCK_DIR/$SESSION_ID.lock" 2>/dev/null || true

# Extension Protocol v1: signal to child plugins (rolepod-uiproof, wplab)
# that rolepod parent is active in this worktree. Children read this file
# at skill execution to switch from standalone to with-rolepod mode.
# Content = protocol version. Refreshed every SessionStart.
mkdir -p "$WORKTREE/.rolepod" 2>/dev/null && \
  printf 'v1\n' > "$WORKTREE/.rolepod/parent-active" 2>/dev/null || true

# No sibling, or override active → silent.
if [ "$ACTIVE_SIBLINGS" -eq 0 ] || [ "$SILENT" -eq 1 ]; then
  exit 0
fi

BRANCH=$(git -C "$WORKTREE" branch --show-current 2>/dev/null || echo "HEAD")
SUGGEST_PATH="${WORKTREE}-task-$(date +%s)"

# Emit additionalContext so Lead reads it on turn 1 and self-acts.
python3 -c "
import json
msg = ('⚠️ Sibling Claude session(s) detected in this worktree ($ACTIVE_SIBLINGS active). '
       'Concurrent edits will stomp each other. '
       'Before any Edit/Write: spawn an isolated worktree FIRST:\n\n'
       '  git worktree add $SUGGEST_PATH $BRANCH\n'
       '  cd $SUGGEST_PATH\n\n'
       'Then continue work there. Override with ROLEPOD_ALLOW_SHARED_WORKTREE=1 '
       'if this session is intentionally shared (e.g. read-only review).')
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': msg}}))
" 2>/dev/null || echo '{}'
