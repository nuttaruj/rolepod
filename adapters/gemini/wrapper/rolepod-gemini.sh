#!/usr/bin/env bash
# rolepod-gemini — opt-in Gemini CLI wrapper.
#
# Prepends a synthesized "rule-of-the-turn" reminder before forwarding args
# to the `gemini` binary. Mirrors hooks/context-awareness.sh (Claude) but
# client-side because Gemini has no native PreToolUse hook.
#
# Usage:
#   rolepod-gemini.sh                                  # interactive, with reminder
#   rolepod-gemini.sh -p "list project files"          # non-interactive
#   rolepod-gemini.sh --careful -p "edit auth module"  # high-risk mode
#   ROLEPOD_CAREFUL=1 rolepod-gemini.sh ...            # same, via env
#
# First-run only: writes a one-shot warning file to ~/.gemini/.rolepod-warnings-shown.

set -euo pipefail

CAREFUL="${ROLEPOD_CAREFUL:-0}"
ARGS=()
for a in "$@"; do
  case "$a" in
    --careful) CAREFUL=1 ;;
    *) ARGS+=("$a") ;;
  esac
done

if ! command -v gemini >/dev/null 2>&1; then
  echo "rolepod-gemini: gemini binary not found. Install: npm install -g @google/gemini-cli" >&2
  exit 127
fi

# One-shot first-run banner.
WARN_FILE="${HOME}/.gemini/.rolepod-warnings-shown"
if [ ! -e "$WARN_FILE" ]; then
  mkdir -p "$(dirname "$WARN_FILE")"
  cat >&2 <<'EOF'
[rolepod] First-run notice — Gemini CLI runs in Lead-only mode.
  - All 18 agents documented in GEMINI.md (no subagent dispatch).
  - Hooks/skills are not auto-pulled; this wrapper is the only reminder mechanism.
  - For high-risk work: rolepod-gemini.sh --careful  (or ROLEPOD_CAREFUL=1)
  - This message is shown once. Delete ~/.gemini/.rolepod-warnings-shown to see again.

EOF
  : > "$WARN_FILE"
fi

# Build the per-turn reminder.
REMINDER=$'[rolepod reminder]\n'
REMINDER+=$'- Verify-first: confirm facts before claiming. Memory unreliable.\n'
REMINDER+=$'- Q1-Q4: >1 file or tests/build needed → spawn external reviewer.\n'
REMINDER+=$'- S1-S5 before commit: cut feature creep, single-use abstractions, defensive code.\n'
REMINDER+=$'- T1-T5 before commit: bug-fix needs reproducing test; new feature needs happy+edge.\n'

if [ "$CAREFUL" = "1" ]; then
  REMINDER+=$'\n[CAREFUL MODE ACTIVE]\n'
  REMINDER+=$'- Run all 5 S/T questions explicitly\n'
  REMINDER+=$'- External reviewer required for auth/billing/migration changes\n'
  REMINDER+=$'- ≤3 files per commit\n'
fi

# Forward to gemini. We splice the reminder into a -p prompt if -p is used,
# otherwise echo to stderr and let the user see it before interactive mode.
HAS_PROMPT=0
for a in "${ARGS[@]+"${ARGS[@]}"}"; do
  case "$a" in
    -p|--prompt|-p=*|--prompt=*) HAS_PROMPT=1 ;;
  esac
done

if [ "$HAS_PROMPT" -eq 0 ]; then
  printf '%s\n' "$REMINDER" >&2
  if [ "${#ARGS[@]}" -eq 0 ]; then
    exec gemini
  else
    exec gemini "${ARGS[@]}"
  fi
fi

# Build args list, splicing reminder into -p value when found.
NEW_ARGS=()
i=0
while [ $i -lt ${#ARGS[@]} ]; do
  cur="${ARGS[$i]}"
  case "$cur" in
    -p|--prompt)
      next="${ARGS[$((i + 1))]:-}"
      NEW_ARGS+=("$cur" "$REMINDER"$'\n'"$next")
      i=$((i + 2))
      continue ;;
    -p=*) NEW_ARGS+=("-p=$REMINDER"$'\n'"${cur#-p=}") ; i=$((i + 1)) ; continue ;;
    --prompt=*) NEW_ARGS+=("--prompt=$REMINDER"$'\n'"${cur#--prompt=}") ; i=$((i + 1)) ; continue ;;
  esac
  NEW_ARGS+=("$cur")
  i=$((i + 1))
done

exec gemini "${NEW_ARGS[@]}"
