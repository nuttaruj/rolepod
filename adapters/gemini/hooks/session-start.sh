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
GATES+=$'careful mode: /careful for high-risk surface (auth/billing/migrations/locks).\n'

PAYLOAD="${GATES}"$'\n'"--- git context ---"$'\n'"${CTX}"

# Output strict JSON. SessionStart should use hookSpecificOutput.additionalContext
# (injected as first turn in history / prepended to non-interactive prompt) so
# Lead actually sees the gates + git context. systemMessage is operator-facing
# only — visible noise that doesn't reach the model. Spec:
# https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/reference.md
ESCAPED="$(printf '%s' "$PAYLOAD" | escape_json)"
printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": %s}}\n' "$ESCAPED"
