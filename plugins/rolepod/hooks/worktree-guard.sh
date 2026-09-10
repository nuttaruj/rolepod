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

# Bypass accountability: a used bypass is recorded to .rolepod/evidence/bypass.log
# (reason via ROLEPOD_BYPASS_REASON), never blocked. Fail-open on any error.
rolepod_log_bypass() {
  _rlb_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  [ -n "$_rlb_root" ] || return 0
  mkdir -p "$_rlb_root/.rolepod/evidence" 2>/dev/null || return 0
  _rlb_reason="${ROLEPOD_BYPASS_REASON:-unreasoned}"
  _rlb_reason="${_rlb_reason//\"/ }"
  printf '{"ts":"%s","hook":"%s","var":"%s","reason":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$_rlb_reason" \
    >> "$_rlb_root/.rolepod/evidence/bypass.log" 2>/dev/null || true
}

INPUT=$(cat 2>/dev/null || echo '{}')

# Parse + canonicalize in one python pass. tool_input carries file_path
# (Edit/Write/MultiEdit) or notebook_path (NotebookEdit). Relative paths are
# resolved against cwd so both sessions key the same file identically.
FIELDS=$(printf '%s' "$INPUT" | python3 -I -c '
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
print("1" if d.get("agent_id") else "")
print(d.get("transcript_path", "") or "")
print(f)
' 2>/dev/null) || exit 0

# $(...) strips ALL trailing newlines from FIELDS, so when the tail fields
# are empty ANY of these reads can hit EOF, return 1, and set -e kills the
# hook (observed: pathless Write payload → rc=1). The || true guard
# disables set -e inside the compound; read still assigns "" on EOF, and
# TARGET slurps whatever remains via $(cat).
{ read -r TOOL; read -r SESSION_ID; read -r CWD; read -r AGENT_ID; read -r TRANSCRIPT; TARGET=$(cat); } <<EOF || true
$FIELDS
EOF

# Only guard real edit tools; everything else passes untouched.
printf '%s' "$TOOL" | grep -qE '^(Edit|Write|MultiEdit|NotebookEdit)$' || exit 0
[ -z "$TARGET" ] && exit 0

[ -z "$CWD" ] && CWD="$PWD"

# Only act inside a git worktree. Non-git dirs have no worktree to isolate.
WORKTREE=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -z "$WORKTREE" ] && exit 0

PATH_HASH=$(printf '%s' "$WORKTREE" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
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

  mtime=$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null || echo 0)
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
  [ -n "$COLLISION" ] && rolepod_log_bypass "worktree-guard" "ROLEPOD_ALLOW_SHARED_WORKTREE"
  MY_FILES="$LOCK_DIR/$SESSION_ID.files"
  FIRST_TOUCH=0
  grep -Fxq "$TARGET" "$MY_FILES" 2>/dev/null || { FIRST_TOUCH=1; printf '%s\n' "$TARGET" >> "$MY_FILES" 2>/dev/null || true; }

  # Reuse-ladder nudge (v2.109.0) — the moment scope creep happens is the
  # edit itself, and normal edits were silent (the per-edit Q1-Q4 reminder
  # was cut for cost and nudge fatigue). This registry already knows whether
  # the session has touched the file before, so the ladder is injected ONCE
  # per file per session (first touch), on a Write that creates a file, and
  # on every edit of a dependency manifest (a new dependency is the last
  # rung). Docs / config / assets stay silent. ~45 tokens per fire. Only the
  # ladder is repeated here: the scope rules (nothing beyond the request,
  # single-use abstraction inline) already reach every CLI via the always-on
  # core and S1-S5 at commit — one copy each. The
  # shared-worktree bypass path stays silent (doctor asserts it).
  [ "${ROLEPOD_NUDGE_OFF:-0}" = "1" ] && exit 0
  [ -n "$COLLISION" ] && exit 0
  BASE=$(basename "$TARGET")
  KIND=""
  if printf '%s' "$BASE" | grep -qiE '^(package\.json|requirements[^/]*\.txt|pyproject\.toml|go\.mod|Cargo\.toml|Gemfile|composer\.json|pubspec\.yaml|build\.gradle(\.kts)?|pom\.xml|Podfile|mix\.exs)$'; then
    KIND="manifest"
  elif [ "$FIRST_TOUCH" = "1" ] && ! printf '%s' "$TARGET" | grep -qiE '\.(md|mdx|txt|rst|json|ya?ml|toml|lock|csv|svg|png|jpe?g|gif|ico|env|example)$|(^|/)(docs?|\.github|\.rolepod|node_modules|dist|build)/'; then
    if [ "$TOOL" = "Write" ] && [ ! -e "$TARGET" ]; then KIND="new"; else KIND="code"; fi
  fi

  # Self-do nudge (v2.116.0) — the Lead, on an R3/R4 route, has made
  # SELFDO_EDITS edits to product code files since that route and dispatched
  # no writer role (WRITER_ROLE_AGENTS in lib/session_state.py). Fires ONCE
  # per route (marker = the route's timestamp in <session>.selfdo); never on
  # a subagent's edit (agent_id set), never on R1/R2, never on test / doc
  # files, silent when no routing line exists. Additive context, never a
  # block — the exception (user said self-do) is the user's to state.
  SELFDO=""
  SELFDO_EDITS=6
  if [ -z "$AGENT_ID" ] && [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    # lib/session_state.py is the one classifier: it returns "" unless the
    # TARGET is product code by the same rule it counts earlier edits with.
    SS="$(dirname "$0")/lib/session_state.py"
    STATE=$(printf '%s' "$INPUT" | python3 -I "$SS" selfdo-state "$TARGET" 2>/dev/null || true)
    S_TIER=""; S_EDITS=0; S_WRITERS=0; S_TS=""
    { read -r S_TIER S_EDITS S_WRITERS S_TS; } <<EOF2 || true
$STATE
EOF2
    case "$S_TIER" in
      R3|R4)
        if [ "${S_EDITS:-0}" -ge "$SELFDO_EDITS" ] && [ "${S_WRITERS:-0}" -eq 0 ]; then
          MARK="$LOCK_DIR/$SESSION_ID.selfdo"
          if [ "$(cat "$MARK" 2>/dev/null || true)" != "$S_TS" ]; then
            printf '%s' "$S_TS" > "$MARK" 2>/dev/null || true
            SELFDO="$S_TIER $S_EDITS"
          fi
        fi ;;
    esac
  fi
  [ -z "$KIND" ] && [ -z "$SELFDO" ] && exit 0
  ROLEPOD_HOOK_BASE="$BASE" ROLEPOD_HOOK_KIND="$KIND" ROLEPOD_HOOK_SELFDO="$SELFDO" python3 -I -c '
import json, os
b = os.environ.get("ROLEPOD_HOOK_BASE", "?"); k = os.environ.get("ROLEPOD_HOOK_KIND", "")
sd = os.environ.get("ROLEPOD_HOOK_SELFDO", "")
ladder = "reuse before new logic (codebase \u2192 stdlib \u2192 platform \u2192 installed dep \u2192 one line before a helper). (off: ROLEPOD_NUDGE_OFF=1)"
parts = []
if sd:
    k = ""   # the self-do line replaces the ladder this once (joined they pass 600 chars)
if k == "manifest":
    parts.append("\u2702 dependency manifest %s: a NEW dependency is the last rung \u2014 codebase \u2192 stdlib \u2192 platform \u2192 installed dep first; if it stays, justify it in the plan (maintained \u00b7 size \u00b7 license). (off: ROLEPOD_NUDGE_OFF=1)" % b)
elif k == "new":
    parts.append("\u2702 new file %s: does it need to exist \u2014 extend an existing module first? Then %s" % (b, ladder))
elif k == "code":
    parts.append("\u2702 first touch of %s this session: %s" % (b, ladder))
if sd:
    tier, n = (sd.split() + ["", ""])[:2]
    parts.append("\u27c2 self-do: route %s, %s Lead edits on product code, 0 writer-role dispatch since the route. Fix: the rest goes out as a task brief to the Owner the domain map names (plan-template Owner hint: frontend-developer / backend-developer / devops-sre / content-strategist \u2026); the Lead reviews the manifest. Exception: the user said self-do, or what remains is R1/R2-sized. (off: ROLEPOD_NUDGE_OFF=1)" % (tier, n))
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": " ".join(parts)}}))
' 2>/dev/null || true
  exit 0
fi

BRANCH=$(git -C "$WORKTREE" branch --show-current 2>/dev/null || echo "HEAD")
SUGGEST_PATH="${WORKTREE}-task-$(date +%s)"
REL="${TARGET#"$WORKTREE"/}"

# HARD deny — a live sibling owns this exact file. Point at native isolation
# first (EnterWorktree), git worktree fallback second, override last.
REL="$REL" SUGGEST_PATH="$SUGGEST_PATH" BRANCH="$BRANCH" python3 -I -c '
import json, os
rel = os.environ.get("REL", "")
sug = os.environ.get("SUGGEST_PATH", "")
br = os.environ.get("BRANCH", "")
reason = (
    "BLOCKED: \"" + rel + "\" is being edited by a concurrent session in this "
    "shared worktree — writing now would stomp their changes. Isolate first, then retry:\n"
    "  • EnterWorktree tool (native), OR\n"
    "  • git worktree add " + sug + " " + br + " && cd " + sug + "\n"
    "Intentionally shared (read-only review / coordinated owner) → ask the USER to set "
    "ROLEPOD_ALLOW_SHARED_WORKTREE=1; env bypass is user-set only."
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
