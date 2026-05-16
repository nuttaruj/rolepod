#!/usr/bin/env bash
# rolepod bootstrap — clones the repo + runs install.sh.
# Interactive: prompts for target/scope if no args provided.
# Non-interactive: pass args to skip the prompt.
#
# Designed for: curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash
#
# Rolepod ships PURE FRAMEWORK ONLY. Recommended add-ons (rtk, caveman,
# GitNexus, MemPalace, ui-ux-pro-max, OpenAI Codex review plugin, Codex CLI,
# Gemini CLI) live in README → "Recommended add-ons" — install separately
# yourself. The framework auto-integrates when each is present.
#
# Env vars:
#   ROLEPOD_DEST     where to clone the repo (default: ~/rolepod)
#   ROLEPOD_TARGET   where install.sh writes to (default: ~/.claude — read by install.sh)
#   ROLEPOD_REF      branch/tag to check out (default: main)
#
# Args (forwarded to install.sh — skip interactive prompt if any are given):
#   --force           overwrite existing files (selective backup created)
#   --dry-run         preview every action; write nothing to disk
#   --target=<cli>    claude|codex|gemini|all (default claude)
#   --scope=global    install to home (default — affects all projects)
#   --scope=project   install to current dir's .claude/ etc. (no global config touched)
#
# Examples:
#   curl -fsSL .../bootstrap.sh | bash                              # interactive
#   curl -fsSL .../bootstrap.sh | bash -s -- --target=codex         # codex, no prompt
#   curl -fsSL .../bootstrap.sh | bash -s -- --target=all --force   # all CLIs, overwrite

set -euo pipefail

REPO_URL="https://github.com/nuttaruj/rolepod.git"
DEST="${ROLEPOD_DEST:-$HOME/rolepod}"
REF="${ROLEPOD_REF:-main}"
ARGS=("$@")

# Colors
if [ -t 1 ]; then
  CYAN=$(tput setaf 6 || true); GREEN=$(tput setaf 2 || true)
  YELLOW=$(tput setaf 3 || true); BOLD=$(tput bold || true); NC=$(tput sgr0 || true)
else
  CYAN=""; GREEN=""; YELLOW=""; BOLD=""; NC=""
fi

# ─── Interactive menu (only if no args + we have a terminal) ────────────
INTERACTIVE_TARGET=""
INTERACTIVE_SCOPE=""
if [ "${#ARGS[@]}" -eq 0 ]; then
  if [ -e /dev/tty ]; then
    cat >&2 <<EOF

${BOLD}rolepod installer${NC} — pure framework (no 3rd-party add-ons bundled)

Choose CLI target:
  ${BOLD}1${NC}) ${CYAN}claude${NC}    — Claude Code (~/.claude/) ${YELLOW}★ default${NC}
  ${BOLD}2${NC}) ${CYAN}codex${NC}     — Codex CLI (~/.codex/)
  ${BOLD}3${NC}) ${CYAN}gemini${NC}    — Gemini CLI (~/.gemini/)
  ${BOLD}4${NC}) ${GREEN}all${NC}       — install for all three CLIs

EOF
    target_choice=""
    read -r -p "Target [1/2/3/4] (default 1): " target_choice </dev/tty || target_choice=""
    case "${target_choice:-1}" in
      1|claude|"") INTERACTIVE_TARGET="claude" ;;
      2|codex)     INTERACTIVE_TARGET="codex" ;;
      3|gemini)    INTERACTIVE_TARGET="gemini" ;;
      4|all)       INTERACTIVE_TARGET="all" ;;
      *) echo "Unknown choice '$target_choice' — defaulting to claude"; INTERACTIVE_TARGET="claude" ;;
    esac

    cat >&2 <<EOF

Choose install scope:
  ${BOLD}1${NC}) ${CYAN}global${NC}    — install to ~/.claude/ etc. (affects all your projects) ${YELLOW}★ default${NC}
  ${BOLD}2${NC}) ${CYAN}project${NC}   — install to current directory's .claude/ etc. (no global config touched)

EOF
    scope_choice=""
    read -r -p "Scope [1/2] (default 1): " scope_choice </dev/tty || scope_choice=""
    case "${scope_choice:-1}" in
      1|global|"") INTERACTIVE_SCOPE="global" ;;
      2|project)   INTERACTIVE_SCOPE="project" ;;
      *) echo "Unknown choice '$scope_choice' — defaulting to global"; INTERACTIVE_SCOPE="global" ;;
    esac

    force_choice=""
    read -r -p "Overwrite existing files (auto-backup first)? [y/N]: " force_choice </dev/tty || force_choice=""
    case "${force_choice:-n}" in
      y|Y|yes|YES) ARGS+=("--force") ;;
    esac
  else
    # No TTY → install with all defaults (claude, global, no force)
    echo "${YELLOW}No TTY available — installing with defaults (claude, global)${NC}" >&2
  fi
fi

echo "${BOLD}rolepod bootstrap${NC}"
echo "  clone target: $DEST"
echo "  ref:          $REF"
echo "  install args: ${ARGS[*]:-<defaults>}"
echo ""

# ─── Clone or update repo ───────────────────────────────────────────────
if [ -d "$DEST/.git" ]; then
  echo "${CYAN}▸${NC} $DEST already a git repo — fetching latest"
  git -C "$DEST" fetch --quiet origin "$REF"
  git -C "$DEST" checkout --quiet "$REF"
  git -C "$DEST" pull --ff-only --quiet
elif [ -e "$DEST" ]; then
  echo "✗ $DEST exists but is not a git repo — refusing to overwrite" >&2
  echo "  Move or delete it, or set ROLEPOD_DEST to a different path." >&2
  exit 1
else
  echo "${CYAN}▸${NC} Cloning $REPO_URL → $DEST"
  git clone --quiet --branch "$REF" "$REPO_URL" "$DEST"
fi

cd "$DEST"
# Pin a --target value defensively. Default to claude unless the interactive
# menu picked something else. CLI flags in $ARGS override anything we set here.
TARGET_FLAG="--target=${INTERACTIVE_TARGET:-claude}"
# If user already passed --target=... in ARGS, drop our default to avoid duplication.
for a in "${ARGS[@]+"${ARGS[@]}"}"; do
  case "$a" in --target=*) TARGET_FLAG="" ;; esac
done
# Same logic for --scope=. Only forward when interactive picked one (don't
# clobber user's explicit --scope= in ARGS, and don't force global when ARGS
# came from a non-interactive curl pipe — install.sh defaults to global).
SCOPE_FLAG=""
if [ -n "$INTERACTIVE_SCOPE" ]; then
  SCOPE_FLAG="--scope=$INTERACTIVE_SCOPE"
fi
for a in "${ARGS[@]+"${ARGS[@]}"}"; do
  case "$a" in --scope=*) SCOPE_FLAG="" ;; esac
done
EXTRA=()
[ -n "$TARGET_FLAG" ] && EXTRA+=("$TARGET_FLAG")
[ -n "$SCOPE_FLAG" ] && EXTRA+=("$SCOPE_FLAG")
exec ./install.sh "${EXTRA[@]+"${EXTRA[@]}"}" "${ARGS[@]+"${ARGS[@]}"}"
