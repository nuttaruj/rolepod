#!/bin/bash
# PostToolUse(Bash) — after a ship cmd touches ≥5 files, auto-spawn
# `npx gitnexus analyze --no-stats` in the background. Silent unless
# something diagnostic.
#
# Why: previously this hook printed "Reindex recommended... Suggest user run
# X" as an additionalContext nag. Lead can't actually act on a "tell user"
# message inside a hook, and the bare nag forced the user to run a long
# command themselves. Now: Lead-owned auto-spawn, no user action.
#
# Dedup: shares the same once/day/repo marker as gitnexus-wrap.sh so a
# stale-notice + post-ship trigger in the same day spawns at most once.
#
# Self-guarded: silent if no `npx` on PATH or no .gitnexus/ dir (= user
# hasn't adopted GitNexus in this repo). No nag, no block.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
CMD=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[ -z "$CMD" ] && exit 0

# Match ship commands
echo "$CMD" | grep -qE '(gh pr merge|git push.*\b(main|master)\b|git merge.*\b(main|master)\b)' || exit 0

CWD=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || echo "$PWD")
REPO=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0
N=$(git -C "$REPO" diff --name-only HEAD~5..HEAD 2>/dev/null | wc -l | tr -d ' ')

[ "$N" -lt 5 ] && exit 0

# Self-guards: skip if GitNexus not adopted or npx absent. No nag.
[ -d "$REPO/.gitnexus" ] || exit 0
command -v npx >/dev/null 2>&1 || exit 0

REPO_NAME=$(basename "$REPO")

# Shared marker with gitnexus-wrap.sh — dedup so stale-notice path + post-ship
# path don't double-spawn within the same day.
MARKER="$HOME/.claude/.gitnexus-bg-reindex-${REPO_NAME}-$(date +%Y%m%d)"
if [ -f "$MARKER" ]; then
  exit 0
fi
touch "$MARKER" 2>/dev/null || true

# Auto-add .gitnexus/ to .git/info/exclude (same logic as gitnexus-wrap.sh)
# so analyze doesn't leave the DB dir as untracked noise.
EXCLUDE_FILE="$REPO/.git/info/exclude"
if [ -d "$REPO/.git" ] && [ -f "$EXCLUDE_FILE" ]; then
  if ! grep -qxF ".gitnexus/" "$EXCLUDE_FILE" 2>/dev/null; then
    printf '\n# rolepod: auto-added by post-ship-detect.sh\n.gitnexus/\n' >> "$EXCLUDE_FILE" 2>/dev/null || true
  fi
fi

# Spawn bg reindex. --skip-agents-md freezes the gitnexus block in
# CLAUDE.md/AGENTS.md entirely — no diff churn after reindex.
(cd "$REPO" && nohup npx gitnexus analyze --skip-agents-md \
   > "/tmp/gitnexus-reindex-${REPO_NAME}.log" 2>&1 &) 2>/dev/null

# Silent additionalContext: brief Lead-facing note (no user action requested).
python3 -c "
import json
print(json.dumps({'hookSpecificOutput':{'hookEventName':'PostToolUse','additionalContext':'GitNexus auto-reindex spawned in background ($N files in last 5 commits). No user action needed.'}}))
" 2>/dev/null || echo '{}'
