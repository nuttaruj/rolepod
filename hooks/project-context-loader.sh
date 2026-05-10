#!/bin/bash
# SessionStart — inject git activity for current repo + project setup checklist. Silent if not in git.
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

# Project setup checklist — only append section when at least one item is missing.
CHECKLIST=""

# 1. GitNexus indexed? Per-repo index lives at <repo>/.gitnexus/
if [ ! -d "$REPO/.gitnexus" ]; then
  CHECKLIST="$CHECKLIST\n- [ ] GitNexus index missing → run \`npx gitnexus analyze\` in project root for code intelligence"
fi

# 2. Project CLAUDE.md exists?
if [ ! -f "$REPO/CLAUDE.md" ]; then
  CHECKLIST="$CHECKLIST\n- [ ] No project CLAUDE.md → run \`/init\` (or skip if global rules are enough)"
fi

# 3. First-time session for this dir? Track in ~/.claude/.rolepod-seen-projects (one path per line, idempotent).
SEEN_FILE="$HOME/.claude/.rolepod-seen-projects"
mkdir -p "$HOME/.claude" 2>/dev/null || true
if [ ! -f "$SEEN_FILE" ] || ! grep -Fxq "$REPO" "$SEEN_FILE" 2>/dev/null; then
  CHECKLIST="$CHECKLIST\n- [ ] First session for this project → MemPalace will start capturing learnings now"
  echo "$REPO" >> "$SEEN_FILE" 2>/dev/null || true
fi

[ -n "$CHECKLIST" ] && CTX="$CTX\n\n## Project setup checklist\n$CHECKLIST"

python3 -c "
import json
print(json.dumps({'hookSpecificOutput':{'hookEventName':'SessionStart','additionalContext':'''$CTX'''}}))
" 2>/dev/null || echo '{}'
