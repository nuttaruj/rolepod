#!/bin/bash
# Stop hook — remove this session's lock from the shared lock dir so
# the next session doesn't see a phantom sibling.
#
# Pairs with session-lock.sh (SessionStart). Stale locks also get
# pruned passively on next SessionStart scan (mtime > 30 min) — this
# hook is the fast path.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('session_id','') or '')
except Exception: print('')" 2>/dev/null || echo "")
CWD=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('cwd','') or '')
except Exception: print('')" 2>/dev/null || echo "")
[ -z "$CWD" ] && CWD="$PWD"
[ -z "$SESSION_ID" ] && exit 0

WORKTREE=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0
PATH_HASH=$(printf '%s' "$WORKTREE" | shasum -a 256 2>/dev/null | awk '{print $1}' | head -c 16)
[ -z "$PATH_HASH" ] && exit 0

LOCK_FILE="$HOME/.claude/.session-locks/$PATH_HASH/$SESSION_ID.lock"
rm -f "$LOCK_FILE" 2>/dev/null || true
exit 0
