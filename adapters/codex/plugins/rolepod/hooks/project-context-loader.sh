#!/bin/bash
# SessionStart — inject git activity for current repo. Silent if not in git.
#
# Scope (post-PR-5 slim): repo name, branch, dirty count, recent commits,
# hot files. Add-on availability (GitNexus, MemPalace, Codex / Gemini
# external reviewers) used to nag from here; the nags moved into docs +
# skills where they belong. Per-session reminder noise was the bigger
# tax than the missing-add-on surface itself.
#
# GitNexus auto-recovery still lives here because the plugin's own
# background reindex can wedge the DB write-lock, causing every
# subsequent Bash hook to print a noisy error. Detect via failed log
# marker + wipe + fresh bg reindex. Once per repo per day. Silent on
# success.
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

# GitNexus auto-recovery — silent unless the plugin's bg reindex actually
# wedged the DB. No "missing index" nag (moved to docs).
GITNEXUS_LOG="/tmp/gitnexus-reindex-${NAME}.log"
RECOVERY_MARKER="$HOME/.claude/.gitnexus-recovered-${NAME}-$(date +%Y%m%d)"
if [ -d "$REPO/.gitnexus" ] && [ -f "$GITNEXUS_LOG" ] && [ ! -f "$RECOVERY_MARKER" ]; then
  if grep -q "npm error\|Cannot execute write operations" "$GITNEXUS_LOG" 2>/dev/null; then
    rm -rf "$REPO/.gitnexus" 2>/dev/null || true
    (cd "$REPO" && nohup npx gitnexus analyze --no-stats > "$GITNEXUS_LOG" 2>&1 &) 2>/dev/null
    mkdir -p "$HOME/.claude" 2>/dev/null || true
    touch "$RECOVERY_MARKER" 2>/dev/null || true
  fi
fi

python3 -c "
import json
print(json.dumps({'hookSpecificOutput':{'hookEventName':'SessionStart','additionalContext':'''$CTX'''}}))
" 2>/dev/null || echo '{}'
