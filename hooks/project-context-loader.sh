#!/bin/bash
# SessionStart — inject git activity for current repo + project setup checklist. Silent if not in git.
# Each checklist warning fires AT MOST ONCE per repo (tracked in ~/.claude/.rolepod-warnings-shown).
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

# Project setup checklist — each warning fires at most ONCE per repo, ever.
# After the warning shows, suppress it forever (user might intentionally skip the suggestion).
# Tracking: ~/.claude/.rolepod-warnings-shown, TSV format: <repo-path>\t<warning-id>
WARN_FILE="$HOME/.claude/.rolepod-warnings-shown"
mkdir -p "$HOME/.claude" 2>/dev/null || true

# warn_once <warning-id> <message>
# Emits message + records marker if not already shown for this repo.
warn_once() {
  local id="$1"
  local msg="$2"
  local marker="$REPO	$id"
  if [ -f "$WARN_FILE" ] && grep -Fxq "$marker" "$WARN_FILE" 2>/dev/null; then
    return
  fi
  CHECKLIST="$CHECKLIST\n- [ ] $msg"
  printf '%s\n' "$marker" >> "$WARN_FILE" 2>/dev/null || true
}

CHECKLIST=""

# 1. GitNexus indexed? Per-repo index lives at <repo>/.gitnexus/
if [ ! -d "$REPO/.gitnexus" ]; then
  warn_once "gitnexus-index" "GitNexus index missing → run \`npx gitnexus analyze\` in project root for code intelligence"
fi

# 2. Project CLAUDE.md exists?
if [ ! -f "$REPO/CLAUDE.md" ]; then
  warn_once "project-claudemd" "No project CLAUDE.md → run \`/init\` (or skip if global rules are enough)"
fi

# 3. First-time session for this dir?
warn_once "first-session" "First session for this project → MemPalace will start capturing learnings now"

# 4. Dual install detected? install.sh artifacts + marketplace plugin both present
#    → user has duplicates. Warn once + suggest migration.
INSTALLED_JSON="$HOME/.claude/plugins/installed_plugins.json"
if [ -f "$INSTALLED_JSON" ] && [ -f "$HOME/.claude/agents/qa-tester.md" ]; then
  if python3 -c "
import json, sys
try:
  d = json.load(open('$INSTALLED_JSON'))
  sys.exit(0 if 'rolepod@rolepod' in d.get('plugins', {}) else 1)
except Exception:
  sys.exit(1)
" 2>/dev/null; then
    warn_once "dual-install" "Dual install detected: rolepod@rolepod via marketplace AND install.sh user-scope artifacts. → Run \`bash <rolepod-repo>/install.sh --uninstall --target=claude\` to migrate to marketplace-only (recommended) and avoid duplicate agents/skills/rules."
  fi
fi

[ -n "$CHECKLIST" ] && CTX="$CTX\n\n## Project setup checklist\n$CHECKLIST"

python3 -c "
import json
print(json.dumps({'hookSpecificOutput':{'hookEventName':'SessionStart','additionalContext':'''$CTX'''}}))
" 2>/dev/null || echo '{}'
