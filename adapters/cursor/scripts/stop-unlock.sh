#!/bin/bash
# Cursor stop hook — release this session's worktree lock.
#
# project-context-loader.sh registers cursor-<conversation_id>.lock under
# ~/.rolepod/session-locks/<sha256(worktree)[:16]> at sessionStart (the lock
# dir every CLI's worktree-guard reads); this removes it when the agent loop
# stops. A miss removes nothing and the 30-min stale prune still covers it.
# Prints nothing (stop needs no answer).
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
IFS=$'\t' read -r CWD SID <<< "$(printf '%s' "$INPUT" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
roots = d.get("workspace_roots") or []
print((roots[0] if roots else "") + "\t" + (d.get("conversation_id") or d.get("session_id") or ""))
' 2>/dev/null || true)"
[ -n "${CWD:-}" ] || CWD="$PWD"
[ -n "${SID:-}" ] || exit 0

WT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
H=$(printf '%s' "$WT" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
LD="$HOME/.rolepod/session-locks/$H"
rm -f "$LD/cursor-$SID.lock" "$LD/cursor-$SID.files" 2>/dev/null || true
exit 0
