#!/bin/bash
# PreToolUse(Edit|Write|MultiEdit|NotebookEdit) — collision-scoped worktree guard.
#
# Problem: 2+ Claude sessions editing the same checkout silently stomp each
# other — Session A writes file.ts, Session B opens it stale, B writes back,
# A's edits vanish. session-lifecycle.sh warns ONCE at SessionStart, but that
# warning is advisory and scrolls out of context in a long session. This hook
# enforces at the moment of risk — the edit itself.
#
# Design goal: NEVER block solo work or disjoint parallel work. A gate that
# fires on "a sibling exists" punishes small bug fixes when two sessions touch
# different files. So we gate on the ONLY thing that is a real stomp: two live
# sessions about to write the SAME file.
#
# Tiers:
#   no live sibling                              → silent (record + pass)
#   live sibling, target file NOT shared         → silent (record + pass)   [disjoint work flows]
#   live sibling, target file ALSO owned by them → HARD deny (real stomp)
#   ROLEPOD_ALLOW_SHARED_WORKTREE=1              → downgrade deny → silent
#
# Mechanism: a per-session touched-files registry inside the same HOME-scoped
# lock dir session-lifecycle.sh maintains (keyed by sha256 of the worktree
# abs path). Sibling liveness comes from each session's <id>.lock mtime
# (< 30 min). On every edit we (a) check siblings' <id>.files for our target,
# then (b) record our target into our own <id>.files and refresh our .lock —
# so an actively-editing session never goes stale, and the next sibling sees
# the file we just claimed.
#
# Paired with session-lifecycle.sh --unlock, which removes <id>.lock AND
# <id>.files at Stop so a finished session releases the files it owned.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

# Parse + canonicalize in one python pass. tool_input carries file_path
# (Edit/Write/MultiEdit) or notebook_path (NotebookEdit). Relative paths are
# resolved against cwd so both sessions key the same file identically.
FIELDS=$(printf '%s' "$INPUT" | python3 -c '
import sys, json, os
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
tool = d.get("tool_name", "") or ""
sid = d.get("session_id", "") or ""
cwd = d.get("cwd", "") or ""
ti = d.get("tool_input", {}) or {}
f = ti.get("file_path") or ti.get("notebook_path") or ""
if f:
    base = cwd or os.getcwd()
    f = f if os.path.isabs(f) else os.path.join(base, f)
    # realpath (not abspath) so a symlinked cwd resolves the same way
    # `git rev-parse --show-toplevel` does — keeps the registry key and the
    # relative path in the deny message consistent across sessions.
    f = os.path.realpath(f)
print(tool)
print(sid)
print(cwd)
print(f)
' 2>/dev/null) || exit 0

{ read -r TOOL; read -r SESSION_ID; read -r CWD; read -r TARGET; } <<EOF
$FIELDS
EOF

# Only guard real edit tools; everything else passes untouched.
printf '%s' "$TOOL" | grep -qE '^(Edit|Write|MultiEdit|NotebookEdit)$' || exit 0
[ -z "$TARGET" ] && exit 0

[ -z "$CWD" ] && CWD="$PWD"

# Only act inside a git worktree. Non-git dirs have no worktree to isolate.
WORKTREE=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -z "$WORKTREE" ] && exit 0

PATH_HASH=$(printf '%s' "$WORKTREE" | shasum -a 256 2>/dev/null | awk '{print $1}' | head -c 16)
[ -z "$PATH_HASH" ] && exit 0
LOCK_DIR="$HOME/.rolepod/session-locks/$PATH_HASH"
[ -z "$SESSION_ID" ] && SESSION_ID="unknown-$$"
mkdir -p "$LOCK_DIR" 2>/dev/null || exit 0

NOW=$(date +%s)
STALE_THRESHOLD=1800   # 30 min — mirrors session-lifecycle.sh liveness window

# Scan live siblings for ownership of our exact target file.
COLLISION=""
for lock in "$LOCK_DIR"/*.lock; do
  [ -f "$lock" ] || continue
  sid=$(basename "$lock" .lock)
  [ "$sid" = "$SESSION_ID" ] && continue

  mtime=$(stat -f %m "$lock" 2>/dev/null || stat -c %Y "$lock" 2>/dev/null || echo 0)
  [ $((NOW - mtime)) -lt "$STALE_THRESHOLD" ] || continue   # idle sibling → ignore

  sib_files="$LOCK_DIR/$sid.files"
  [ -f "$sib_files" ] || continue
  if grep -Fxq "$TARGET" "$sib_files" 2>/dev/null; then
    COLLISION="$sid"
    break
  fi
done

# Always refresh our liveness so an actively-editing session never goes stale
# (this is independent of which files we own).
touch "$LOCK_DIR/$SESSION_ID.lock" 2>/dev/null || true

# No real collision, or the operator opted into a shared worktree → claim the
# file (we are about to write it) and pass silently. We record ONLY on the
# pass path: a BLOCKED attempt must not claim ownership, or it would block the
# rightful owner back (mutual deadlock).
if [ -z "$COLLISION" ] || [ "${ROLEPOD_ALLOW_SHARED_WORKTREE:-0}" = "1" ]; then
  MY_FILES="$LOCK_DIR/$SESSION_ID.files"
  grep -Fxq "$TARGET" "$MY_FILES" 2>/dev/null || printf '%s\n' "$TARGET" >> "$MY_FILES" 2>/dev/null || true
  exit 0
fi

BRANCH=$(git -C "$WORKTREE" branch --show-current 2>/dev/null || echo "HEAD")
SUGGEST_PATH="${WORKTREE}-task-$(date +%s)"
REL="${TARGET#"$WORKTREE"/}"

# HARD deny — a live sibling owns this exact file. Point at native isolation
# first (EnterWorktree), git worktree fallback second, override last.
REL="$REL" SUGGEST_PATH="$SUGGEST_PATH" BRANCH="$BRANCH" python3 -c '
import json, os
rel = os.environ.get("REL", "")
sug = os.environ.get("SUGGEST_PATH", "")
br = os.environ.get("BRANCH", "")
reason = (
    "BLOCKED: \"" + rel + "\" is being edited by a concurrent Claude session "
    "in this shared worktree — writing it now would stomp their changes. "
    "Isolate FIRST, then retry the edit:\n"
    "  • Prefer the EnterWorktree tool (native, auto-cleanup), OR\n"
    "  • git worktree add " + sug + " " + br + " && cd " + sug + "\n"
    "If this session is intentionally shared (read-only review, or you have "
    "coordinated who owns this file), set ROLEPOD_ALLOW_SHARED_WORKTREE=1."
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }
}))
' 2>/dev/null || echo '{}'

exit 0
