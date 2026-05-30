#!/usr/bin/env bash
# rolepod / Gemini SessionStart hook — inject git context + gate reminder.
#
# Contract (Gemini hooks):
# - stdout = single JSON object, nothing else
# - stderr free for debug
# - exit 0 on success
# Reference: https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/index.md

set -euo pipefail

PROJECT_DIR="${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}"

git_summary() {
  if ! command -v git >/dev/null 2>&1; then return; fi
  if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then return; fi
  echo "Branch: $(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  echo "Recent commits:"
  git -C "$PROJECT_DIR" log --oneline -5 2>/dev/null || true
}

CTX="$(git_summary 2>/dev/null || true)"

# JSON-escape: only the fields we control. CTX is the only variable, replace
# backslashes / quotes / newlines.
escape_json() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

GATES=$'rolepod gates: S1-S5 simplicity + T1-T6 tests + Q1-Q4 delegation + F1-F6 failure-mode\n'
GATES+=$'verify-first: confirm facts before claiming. Memory unreliable.\n'
GATES+=$'evidence: every change ends with test / curl / screenshot / log.\n'
GATES+=$'careful mode: /rolepod for high-risk surface (auth/billing/migrations/locks).\n'

PAYLOAD="${GATES}"$'\n'"--- git context ---"$'\n'"${CTX}"

# Concurrent-session soft-warn (cross-CLI, neutral lock dir shared with the
# Claude session-lifecycle / worktree-guard hooks). Gemini has no Stop event,
# so cleanup relies on the 30-min stale-prune that runs here on each scan.
if [ "${ROLEPOD_ALLOW_SHARED_WORKTREE:-0}" != "1" ] && command -v git >/dev/null 2>&1; then
  _wt=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")
  if [ -n "$_wt" ]; then
    _h=$(printf '%s' "$_wt" | shasum -a 256 2>/dev/null | awk '{print $1}' | head -c 16)
    _ld="$HOME/.rolepod/session-locks/$_h"; _sid="auto-$PPID"
    mkdir -p "$_ld" 2>/dev/null || true
    _now=$(date +%s); _act=0
    for _lk in "$_ld"/*.lock; do
      [ -f "$_lk" ] || continue; _b=$(basename "$_lk" .lock); [ "$_b" = "$_sid" ] && continue
      _m=$(stat -f %m "$_lk" 2>/dev/null || stat -c %Y "$_lk" 2>/dev/null || echo 0)
      if [ $((_now - _m)) -lt 1800 ]; then _act=$((_act + 1)); else rm -f "$_lk" "$_ld/$_b.files" 2>/dev/null || true; fi
    done
    touch "$_ld/$_sid.lock" 2>/dev/null || true
    [ "$_act" -gt 0 ] && PAYLOAD="${PAYLOAD}"$'\n\n'"⚠️ ${_act} concurrent session(s) in this worktree. Edits to the SAME file stomp each other — isolate with a git worktree before editing a shared file. Override: ROLEPOD_ALLOW_SHARED_WORKTREE=1."
  fi
fi

# Output strict JSON. SessionStart should use hookSpecificOutput.additionalContext
# (injected as first turn in history / prepended to non-interactive prompt) so
# Lead actually sees the gates + git context. systemMessage is operator-facing
# only — visible noise that doesn't reach the model. Spec:
# https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/reference.md
ESCAPED="$(printf '%s' "$PAYLOAD" | escape_json)"
printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": %s}}\n' "$ESCAPED"
