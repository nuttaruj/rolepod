#!/usr/bin/env bash
# rolepod / Antigravity Stop hook — release this session's worktree lock.
#
# agy exposes a Stop event (execution loop terminated) that Gemini CLI never
# had, so the lock registered by session-start.sh at PreInvocation can now be
# released instead of waiting out the 30-min stale prune. Lock id mirrors
# session-start.sh exactly (auto-$PPID under sha256(worktree)[:16]) — both
# hooks are spawned by the same agy session process. A PPID mismatch removes
# nothing and the stale prune still covers it: strictly fail-open.
#
# Contract (agy hooks, gemini-compatible): stdout = single JSON object or
# empty, exit 0. Stop needs no output — observe-only here (we never set
# decision: continue).

set -euo pipefail

PROJECT_DIR="${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}"

if command -v git >/dev/null 2>&1; then
  _wt=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")
  if [ -n "$_wt" ]; then
    _h=$(printf '%s' "$_wt" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
    _ld="$HOME/.rolepod/session-locks/$_h"
    rm -f "$_ld/auto-$PPID.lock" "$_ld/auto-$PPID.files" 2>/dev/null || true
  fi
fi

exit 0
