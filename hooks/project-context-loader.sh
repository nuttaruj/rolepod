#!/bin/bash
# SessionStart — inject git activity for current repo. Silent if not in git.
#
# Scope: repo name, branch, dirty count, recent commits, hot files.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
CWD=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('cwd','') or '')" 2>/dev/null || echo "$PWD")
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

# Concurrent-session soft-warn (cross-CLI, neutral lock dir shared with
# worktree-guard / session-lifecycle). On Claude this is owned by
# session-lifecycle.sh — skip there to avoid a double warning; fire on the
# other CLIs (Codex) that have no session-lifecycle hook. Stale locks (>30 min)
# are pruned on contact; cleanup otherwise relies on the 30-min window since
# those CLIs expose no Stop event.
if [ -z "${CLAUDE_PROJECT_DIR:-}" ] && [ "${ROLEPOD_ALLOW_SHARED_WORKTREE:-0}" != "1" ]; then
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
print(json.dumps({'hookSpecificOutput':{'hookEventName':'SessionStart','additionalContext':'''$CTX'''}}))
" 2>/dev/null || echo '{}'
