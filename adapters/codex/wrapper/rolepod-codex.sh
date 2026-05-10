#!/usr/bin/env bash
# rolepod-codex — opt-in Codex CLI wrapper.
#
# Prepends a synthesized "rule-of-the-turn" reminder before forwarding args
# to the `codex` binary. Mirrors hooks/context-awareness.sh (Claude) but
# client-side because Codex has no native PreToolUse hook.
#
# Usage:
#   rolepod-codex.sh                                # interactive, with reminder
#   rolepod-codex.sh "list project files"           # one-shot
#   rolepod-codex.sh --careful "edit auth module"   # high-risk mode
#   ROLEPOD_CAREFUL=1 rolepod-codex.sh ...          # same, via env
#
# First-run only: writes a one-shot warning file to ~/.codex/.rolepod-warnings-shown
# (mirrors hooks/project-context-loader.sh behaviour for Claude).

set -euo pipefail

CAREFUL="${ROLEPOD_CAREFUL:-0}"
ARGS=()
for a in "$@"; do
  case "$a" in
    --careful) CAREFUL=1 ;;
    *) ARGS+=("$a") ;;
  esac
done

if ! command -v codex >/dev/null 2>&1; then
  echo "rolepod-codex: codex binary not found. Install: npm install -g @openai/codex" >&2
  exit 127
fi

# One-shot first-run banner.
WARN_FILE="${HOME}/.codex/.rolepod-warnings-shown"
if [ ! -e "$WARN_FILE" ]; then
  mkdir -p "$(dirname "$WARN_FILE")"
  cat >&2 <<'EOF'
[rolepod] First-run notice — Codex CLI runs in Lead-only mode.
  - All 18 agents documented in AGENTS.md (no native subagent dispatch).
  - Hooks are unsupported; this wrapper is the only reminder mechanism.
  - For high-risk work: rolepod-codex.sh --careful  (or ROLEPOD_CAREFUL=1)
  - This message is shown once. Delete ~/.codex/.rolepod-warnings-shown to see again.

EOF
  : > "$WARN_FILE"
fi

# Build the per-turn reminder. Kept under ~25 lines so it doesn't dominate
# the prompt. Full rules live in AGENTS.md (always-loaded).
REMINDER=$'[rolepod reminder]\n'
REMINDER+=$'- Verify-first: confirm facts before claiming. Memory unreliable.\n'
REMINDER+=$'- Q1-Q4: >1 file or tests/build needed → consider out-of-band specialist.\n'
REMINDER+=$'- S1-S5 before commit: cut feature creep, single-use abstractions, defensive code.\n'
REMINDER+=$'- T1-T5 before commit: bug-fix needs reproducing test; new feature needs happy+edge.\n'

if [ "$CAREFUL" = "1" ]; then
  REMINDER+=$'\n[CAREFUL MODE ACTIVE]\n'
  REMINDER+=$'- Run all 5 S/T questions explicitly\n'
  REMINDER+=$'- Spawn reviewer (codex exec) for auth/billing/migration changes\n'
  REMINDER+=$'- ≤3 files per commit\n'
fi

# Forward to codex. If args are present, prepend reminder to the first arg
# (which Codex treats as the prompt). If no args, drop into interactive mode
# with the reminder echoed to stderr so the user sees it.
if [ "${#ARGS[@]}" -eq 0 ]; then
  printf '%s\n' "$REMINDER" >&2
  exec codex
else
  FIRST="${ARGS[0]}"
  REST=("${ARGS[@]:1}")
  exec codex "${REST[@]}" "$REMINDER"$'\n'"$FIRST"
fi
