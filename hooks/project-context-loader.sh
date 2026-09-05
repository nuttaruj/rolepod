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

# Cross-family runner locator (v2.76.0): marketplace installs have no
# install.sh launcher on PATH, so name the shipped copy next to this hook
# once per session — the skills say "rolepod-cross-family, or the path the
# session context names".
_xf="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/../scripts/cross-family.sh"
if [ -f "$_xf" ]; then
  _xf=$(cd "$(dirname "$_xf")" && pwd)/cross-family.sh
  _xfcmd="rolepod-cross-family"; command -v rolepod-cross-family >/dev/null 2>&1 || _xfcmd="bash $_xf"
  command -v rolepod-cross-family >/dev/null 2>&1 || CTX="$CTX\n\ncross-family runner: \`$_xfcmd\` (reviews / consults on a different model family — opt-in pool: .rolepod/cross-family)"
  # Opt-in question, asked ONCE per machine (v2.77.0): cross-family is OFF
  # until the user lists CLIs in ~/.rolepod/cross-family. No file, never
  # asked, and at least one other-family CLI installed → tell the Lead to
  # ask this session and record the answer (names, or `none`). The marker
  # keeps it from nagging; the user can always enable later by hand.
  if [ ! -f "$HOME/.rolepod/cross-family" ] && [ ! -f "$REPO/.rolepod/cross-family" ] && [ ! -f "$HOME/.rolepod/cross-family.asked" ]; then
    _lead="${ROLEPOD_LEAD_CLI:-}"; [ -z "$_lead" ] && [ -n "${CLAUDE_PROJECT_DIR:-}${CLAUDE_PLUGIN_ROOT:-}" ] && _lead=claude
    _cand=$(bash "$_xf" --candidates ${_lead:+--lead "$_lead"} 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
    if [ -n "$_cand" ]; then
      CTX="$CTX\n\n**Cross-family reviewers are OFF (opt-in).** Installed other-family CLIs: $_cand. ASK THE USER ONCE this session — do they want rolepod to send adversarial reviews / debug consults / plan advisories to a different model family, and which of those CLIs, in what order? Yes → write the names one per line to \`~/.rolepod/cross-family\` (project-only: \`<git-root>/.rolepod/cross-family\`). No → write \`none\` there. Never enable it without their answer; until then every review stays on this CLI."
      { mkdir -p "$HOME/.rolepod" 2>/dev/null && : > "$HOME/.rolepod/cross-family.asked"; } 2>/dev/null || true
    fi
  fi
fi

# Combined-mode marker for child plugins (uiproof / wplab / dblab): the
# parent is active in this worktree. On Claude, session-lifecycle.sh owns
# write + Stop-event cleanup; this branch covers CLIs with no lifecycle hook
# (Codex). Those CLIs expose no Stop event, so the marker persists — children
# only read its presence, and a stale marker is benign (evidence still routes
# to .rolepod/evidence/).
if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
  { mkdir -p "$REPO/.rolepod" 2>/dev/null && printf 'v1\n' > "$REPO/.rolepod/parent-active"; } 2>/dev/null || true
fi

# Concurrent-session soft-warn (cross-CLI, neutral lock dir shared with
# worktree-guard / session-lifecycle). On Claude this is owned by
# session-lifecycle.sh — skip there to avoid a double warning; fire on the
# other CLIs (Codex) that have no session-lifecycle hook. Stale locks (>30 min)
# are pruned on contact; cleanup otherwise relies on the 30-min window since
# those CLIs expose no Stop event.
if [ -z "${CLAUDE_PROJECT_DIR:-}" ] && [ "${ROLEPOD_ALLOW_SHARED_WORKTREE:-0}" != "1" ]; then
  _h=$(printf '%s' "$REPO" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
  _ld="$HOME/.rolepod/session-locks/$_h"; _sid="auto-$PPID"
  mkdir -p "$_ld" 2>/dev/null || true
  _now=$(date +%s); _act=0
  for _lk in "$_ld"/*.lock; do
    [ -f "$_lk" ] || continue; _b=$(basename "$_lk" .lock); [ "$_b" = "$_sid" ] && continue
    _m=$(stat -c %Y "$_lk" 2>/dev/null || stat -f %m "$_lk" 2>/dev/null || echo 0)
    if [ $((_now - _m)) -lt 1800 ]; then _act=$((_act + 1)); else rm -f "$_lk" "$_ld/$_b.files" 2>/dev/null || true; fi
  done
  touch "$_ld/$_sid.lock" 2>/dev/null || true
  [ "$_act" -gt 0 ] && CTX="$CTX\n\n⚠️ **$_act concurrent session(s)** in this worktree. Edits to the SAME file stomp each other — isolate with a git worktree before editing a shared file. Override: \`ROLEPOD_ALLOW_SHARED_WORKTREE=1\`."
fi

# Env-pass the context so a crafted commit message / branch name cannot escape
# the Python string literal (RCE). CTX is built with literal `\n`; convert to
# real newlines here since the old inline literal relied on Python to do it.
ROLEPOD_HOOK_CTX="${CTX//\\n/$'\n'}" python3 -c "
import json, os
print(json.dumps({'hookSpecificOutput':{'hookEventName':'SessionStart','additionalContext':os.environ.get('ROLEPOD_HOOK_CTX','')}}))
" 2>/dev/null || echo '{}'
