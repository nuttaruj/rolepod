#!/bin/bash
# Cursor sessionStart — inject git activity for current repo. Silent if not in git.
#
# Cursor sessionStart input (stdin JSON) includes workspace_roots: [str].
# We use the first root as cwd for git commands. Output: {"additional_context": "..."}.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
CWD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    roots = d.get('workspace_roots') or []
    print(roots[0] if roots else '')
except Exception:
    print('')
" 2>/dev/null || echo "")
[ -z "$CWD" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || exit 0

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
NAME=$(basename "$REPO")
BRANCH=$(git -C "$REPO" branch --show-current 2>/dev/null || echo "?")
DIRTY=$(git -C "$REPO" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
COMMITS=$(git -C "$REPO" log --oneline -5 2>/dev/null || echo "")
HOT=$(git -C "$REPO" log --since="7 days ago" --name-only --pretty=format: 2>/dev/null \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -5 \
  | awk '{printf "  %s (%dx)\n", $2, $1}' || echo "")

[ -z "$COMMITS" ] && exit 0

CTX="**$NAME** @ \`$BRANCH\` ($DIRTY uncommitted)\n\n**Recent:**\n\`\`\`\n$COMMITS\n\`\`\`"
[ -n "$HOT" ] && CTX="$CTX\n\n**Hot (7d):**\n$HOT"

# Concurrent-session soft-warn (cross-CLI, neutral lock dir shared with the
# Claude session-lifecycle / worktree-guard hooks). Cursor exposes no Stop
# event, so cleanup relies on the 30-min stale-prune that runs here on scan.
if [ "${ROLEPOD_ALLOW_SHARED_WORKTREE:-0}" != "1" ]; then
  _h=$(printf '%s' "$REPO" | shasum -a 256 2>/dev/null | awk '{print $1}' | head -c 16)
  _ld="$HOME/.rolepod/session-locks/$_h"; _sid="auto-$PPID"
  mkdir -p "$_ld" 2>/dev/null || true
  _now=$(date +%s); _act=0
  for _lk in "$_ld"/*.lock; do
    [ -f "$_lk" ] || continue; _b=$(basename "$_lk" .lock); [ "$_b" = "$_sid" ] && continue
    _m=$(stat -f %m "$_lk" 2>/dev/null || stat -c %Y "$_lk" 2>/dev/null || echo 0)
    if [ $((_now - _m)) -lt 1800 ]; then _act=$((_act + 1)); else rm -f "$_lk" "$_ld/$_b.files" 2>/dev/null || true; fi
  done
  touch "$_ld/$_sid.lock" 2>/dev/null || true
  [ "$_act" -gt 0 ] && CTX="$CTX\n\n⚠️ **$_act concurrent session(s)** in this worktree. Edits to the SAME file stomp each other — isolate with a git worktree before editing a shared file. Override: \`ROLEPOD_ALLOW_SHARED_WORKTREE=1\`."
fi

python3 -c "
import json
print(json.dumps({'additional_context':'''$CTX'''}))
" 2>/dev/null || echo '{}'
