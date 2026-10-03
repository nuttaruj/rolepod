#!/bin/bash
# Cursor sessionStart — inject git activity for current repo. Silent if not in git.
#
# Cursor sessionStart input (stdin JSON) includes workspace_roots: [str].
# We use the first root as cwd for git commands. Output: {"additional_context": "..."}.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE=$(printf '%s' "$INPUT" | ROLEPOD_SESSION_CLI=cursor bash "$HERE/session-start.sh" --cli cursor --format env 2>/dev/null || echo '{}')
_mode=$(printf '%s' "$PROFILE" | python3 -I -c 'import json,sys; print((json.load(sys.stdin).get("env") or {}).get("ROLEPOD_SESSION_MODE", "standard"))' 2>/dev/null || echo standard)
ROLEPOD_SESSION_SOURCE=$(printf '%s' "$PROFILE" | python3 -I -c 'import json,sys; print((json.load(sys.stdin).get("env") or {}).get("ROLEPOD_SESSION_SOURCE", "uncaptured"))' 2>/dev/null || echo uncaptured)
export ROLEPOD_SESSION_CLI=cursor ROLEPOD_SESSION_MODE="$_mode" ROLEPOD_SESSION_SOURCE
PROFILE_CONTEXT="Active Rolepod workflow profile: $_mode (source: $ROLEPOD_SESSION_SOURCE). This profile is fixed for this conversation; start a new conversation to apply configuration changes."
emit_output() {
  ROLEPOD_PROFILE_JSON="$PROFILE" ROLEPOD_PROFILE_CONTEXT="$PROFILE_CONTEXT" ROLEPOD_HOOK_CTX="${1:-}" python3 -I -c '
import json, os
try: out=json.loads(os.environ.get("ROLEPOD_PROFILE_JSON", "{}"))
except Exception: out={}
parts=[os.environ.get("ROLEPOD_PROFILE_CONTEXT", "")]
context=os.environ.get("ROLEPOD_HOOK_CTX", "")
if context: parts.append(context)
out["additional_context"]="\n\n".join(part for part in parts if part)
print(json.dumps(out))
' 2>/dev/null || printf '%s\n' '{}'
}
_root=$(printf '%s' "$INPUT" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); print((d.get("workspace_roots") or [""])[0] or d.get("cwd") or "")' 2>/dev/null || true)
[ "$_mode" = lite ] && { emit_output; exit 0; }
export ROLEPOD_PROJECT_ROOT="${_root:-$PWD}"
IFS=$'\t' read -r CWD CONV <<< "$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    roots = d.get('workspace_roots') or []
    print((roots[0] if roots else '') + '\t' + (d.get('conversation_id') or d.get('session_id') or ''))
except Exception:
    print('\t')
" 2>/dev/null || printf '\t')"
[ -z "${CWD:-}" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || { emit_output; exit 0; }

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || { emit_output; exit 0; }

# Combined-mode marker for child plugins — parent active in this worktree.
# Cursor has no session-end hook wired; the marker persists (stale is benign —
# children only read its presence).
{ mkdir -p "$REPO/.rolepod" 2>/dev/null && printf 'v1\n' > "$REPO/.rolepod/parent-active"; } 2>/dev/null || true
NAME=$(basename "$REPO")
BRANCH=$(git -C "$REPO" branch --show-current 2>/dev/null || echo "?")
DIRTY=$(git -C "$REPO" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
COMMITS=$(git -C "$REPO" log --oneline -5 2>/dev/null || echo "")
HOT=$(git -C "$REPO" log --since="7 days ago" --name-only --pretty=format: 2>/dev/null \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -5 \
  | awk '{printf "  %s (%dx)\n", $2, $1}' || echo "")

[ -z "$COMMITS" ] && { emit_output; exit 0; }

CTX="**$NAME** @ \`$BRANCH\` ($DIRTY uncommitted)\n\n**Recent:**\n\`\`\`\n$COMMITS\n\`\`\`"
[ -n "$HOT" ] && CTX="$CTX\n\n**Hot (7d):**\n$HOT"

# Concurrent-session soft-warn (cross-CLI, neutral lock dir shared with the
# Claude session-lifecycle / worktree-guard hooks). The lock is keyed on
# Cursor's conversation_id and released by scripts/stop-unlock.sh on `stop`
# (v2.132.0); the 30-min stale prune here still covers a killed session.
if [ "${ROLEPOD_ALLOW_SHARED_WORKTREE:-0}" != "1" ]; then
  _h=$(printf '%s' "$REPO" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
  _ld="$HOME/.rolepod/session-locks/$_h"; _sid="cursor-${CONV:-auto-$PPID}"
  mkdir -p "$_ld" 2>/dev/null || true
  _now=$(date +%s); _act=0; _names=""
  for _lk in "$_ld"/*.lock; do
    [ -f "$_lk" ] || continue; _b=$(basename "$_lk" .lock); [ "$_b" = "$_sid" ] && continue
    _m=$(stat -c %Y "$_lk" 2>/dev/null || stat -f %m "$_lk" 2>/dev/null || echo 0)
    if [ $((_now - _m)) -lt 1800 ]; then
      _act=$((_act + 1))
      # Lock-name rule (same in session-lifecycle.sh and the opencode
      # plugin): first line only (line 2 of a session-lifecycle lock is the
      # CLI pid), at most 32 bytes, keep it only if it matches [a-z0-9_-]+ —
      # anything else (empty, junk, a lock that vanished or failed to read
      # between the count and this read) is "unknown", so the count and the
      # breakdown always agree.
      _nm=$(head -n 1 "$_lk" 2>/dev/null | head -c 32) || _nm=""
      case "$_nm" in *[!a-z0-9_-]*|"") _nm="unknown" ;; esac
      _names="${_names}${_nm}
"
    else
      rm -f "$_lk" "$_ld/$_b.files" 2>/dev/null || true
    fi
  done
  # Lock content = this CLI's name, same convention as every other writer
  # (session-lifecycle.sh, the opencode plugin) — a sibling then knows which
  # CLI it is, not just how many.
  # Line 2 = the Cursor process pid ($PPID) so ticket.sh recognises the lock as
  # its own; a reader takes line 1 only.
  printf '%s\n%s' "cursor" "$PPID" > "$_ld/$_sid.lock" 2>/dev/null || true
  if [ "$_act" -gt 0 ]; then
    _breakdown=$(printf '%s' "$_names" | LC_ALL=C sort | uniq -c | awk '{printf "%s%s ×%d", sep, $2, $1; sep=", "}')
    CTX="$CTX\n\n**$_act concurrent session(s)** ($_breakdown) in this worktree. Edits to the SAME file stomp each other — isolate with a git worktree before editing a shared file. Override: \`ROLEPOD_ALLOW_SHARED_WORKTREE=1\`."
  fi
fi

# CTX carries literal `\n`; convert to real newlines before adding the frozen
# workflow profile line. The env fields from capture remain intact.
emit_output "${CTX//\\n/$'\n'}"
