#!/bin/bash
# Wrap gitnexus plugin's PreToolUse/PostToolUse hook.
# Forward stdin/stdout transparently. Two extras over the bare plugin hook:
#   1. PostToolUse "stale index" notice → strip from additionalContext +
#      spawn `npx gitnexus analyze --no-stats` in bg (once/day/repo).
#   2. Plugin .cjs missing (user uninstalled gitnexus plugin) → silent no-op.
#
# Why: bare plugin emits stale notice on every commit but doesn't actually
# reindex — leaving Lead to manually trigger or DB drifts forever. This
# wrapper auto-reindexes once/day so notice becomes redundant.
#
# Registered in place of the bare `node .../gitnexus-hook.cjs` command by
# rolepod's install.sh. Idempotent (re-install detects already-patched).
set -euo pipefail

CJS="$HOME/.claude/hooks/gitnexus/gitnexus-hook.cjs"

INPUT=$(cat 2>/dev/null || echo '{}')

# Plugin gone → silent no-op (preserves uninstall safety same as mempalace
# guard pattern).
if [ ! -f "$CJS" ]; then
  exit 0
fi

# Forward stdin to original plugin hook; capture stdout.
OUTPUT=$(printf '%s' "$INPUT" | node "$CJS" 2>/dev/null || echo "")

# No stale notice → pass through unchanged. Common path (every PreToolUse +
# most PostToolUse fires after non-commit Bash).
if ! printf '%s' "$OUTPUT" | grep -q "GitNexus index is stale"; then
  printf '%s' "$OUTPUT"
  exit 0
fi

# Stale notice detected → resolve repo + maybe spawn bg reindex.
CWD=$(printf '%s' "$INPUT" | python3 -c "
import sys,json
try:
    print(json.load(sys.stdin).get('cwd','') or '')
except Exception:
    print('')
" 2>/dev/null || echo "")
[ -z "$CWD" ] && CWD="$PWD"

REPO=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$REPO" ] && [ -d "$REPO/.gitnexus" ]; then
  REPO_NAME=$(basename "$REPO")

  # Auto-add .gitnexus/ to .git/info/exclude so `npx gitnexus analyze` doesn't
  # leave the 38MB DB dir as untracked noise in `git status`. We use
  # info/exclude (per-clone, NOT tracked) instead of project .gitignore to
  # avoid polluting user's tracked ignore file with a tool they may not have
  # adopted project-wide. Idempotent — only appends if line missing.
  EXCLUDE_FILE="$REPO/.git/info/exclude"
  if [ -d "$REPO/.git" ] && [ -f "$EXCLUDE_FILE" ]; then
    if ! grep -qxF ".gitnexus/" "$EXCLUDE_FILE" 2>/dev/null; then
      printf '\n# rolepod: auto-added by gitnexus-wrap.sh\n.gitnexus/\n' >> "$EXCLUDE_FILE" 2>/dev/null || true
    fi
  fi

  # Once/day/repo marker — prevents spamming `npx gitnexus analyze` after
  # every commit. Day boundary because reindex run takes minutes; daily
  # cadence keeps DB current enough for typical workflow.
  MARKER="$HOME/.claude/.gitnexus-bg-reindex-${REPO_NAME}-$(date +%Y%m%d)"
  if [ ! -f "$MARKER" ]; then
    touch "$MARKER" 2>/dev/null || true
    # Block-seeded detection: if CLAUDE.md / AGENTS.md already has the
    # gitnexus:start marker, freeze the block (no diff churn). Otherwise
    # let the first reindex seed it. First-run = one-time diff (user
    # commits block once); every subsequent reindex stays clean.
    FREEZE_FLAG="--skip-agents-md"
    for entry in "$REPO/CLAUDE.md" "$REPO/AGENTS.md"; do
      [ -f "$entry" ] || continue
      if ! grep -q "<!-- gitnexus:start -->" "$entry" 2>/dev/null; then
        FREEZE_FLAG=""
        break
      fi
    done
    (cd "$REPO" && nohup npx gitnexus analyze $FREEZE_FLAG \
       > "/tmp/gitnexus-reindex-${REPO_NAME}.log" 2>&1 &) 2>/dev/null
  fi
fi

# Strip the stale-notice hookSpecificOutput so Lead doesn't see it (Lead
# can't act on it usefully — we've already queued the reindex).
printf '%s' "$OUTPUT" | python3 -c "
import sys,json
try:
    d = json.loads(sys.stdin.read())
    hso = d.get('hookSpecificOutput', {})
    ctx = hso.get('additionalContext', '')
    if 'GitNexus index is stale' in ctx:
        d.pop('hookSpecificOutput', None)
    print(json.dumps(d))
except Exception:
    print('')
" 2>/dev/null || echo ""
