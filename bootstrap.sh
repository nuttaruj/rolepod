#!/usr/bin/env bash
# rolepod bootstrap — clones the repo + runs install.sh.
# Interactive: prompts for install mode if no args provided.
# Non-interactive: pass args to skip the prompt.
#
# Designed for: curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash
#
# Env vars:
#   ROLEPOD_DEST     where to clone the repo (default: ~/rolepod)
#   ROLEPOD_TARGET   where install.sh writes to (default: ~/.claude — read by install.sh)
#   ROLEPOD_REF      branch/tag to check out (default: main)
#
# Args (forwarded to install.sh — skip interactive prompt if any are given):
#   --core      rolepod files only — no plugins
#   --minimum   core + ui-ux-pro-max + GitNexus + MemPalace
#   --full      minimum + caveman + rtk + Codex CLI + Gemini CLI + openai-codex
#   --force     overwrite existing ~/.claude (backup created)
#
# Examples:
#   curl -fsSL .../bootstrap.sh | bash                       # interactive menu
#   curl -fsSL .../bootstrap.sh | bash -s -- --minimum       # skip prompt
#   curl -fsSL .../bootstrap.sh | bash -s -- --full --force

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
if [ "${#ARGS[@]}" -eq 0 ]; then
  if [ -e /dev/tty ]; then
    cat >&2 <<EOF

${BOLD}rolepod installer${NC}

Choose install mode:
  ${BOLD}1${NC}) ${CYAN}core${NC}      — rolepod files only (no external plugins)
  ${BOLD}2${NC}) ${GREEN}minimum${NC}   — core + ui-ux-pro-max + GitNexus + MemPalace ${YELLOW}★ recommended${NC}
  ${BOLD}3${NC}) ${CYAN}full${NC}      — minimum + caveman + rtk + Codex CLI + Gemini CLI + openai-codex plugin

EOF
    choice=""
    read -r -p "Mode [1/2/3] (default 2): " choice </dev/tty || choice=""
    case "${choice:-2}" in
      1|core)        ARGS=("--core") ;;
      3|full)        ARGS=("--full") ;;
      2|minimum|"")  ARGS=("--minimum") ;;
      *) echo "Unknown choice '$choice' — defaulting to minimum"; ARGS=("--minimum") ;;
    esac

    force_choice=""
    read -r -p "Overwrite existing ~/.claude files (auto-backup first)? [y/N]: " force_choice </dev/tty || force_choice=""
    case "${force_choice:-n}" in
      y|Y|yes|YES) ARGS+=("--force") ;;
    esac
  else
    # No TTY → default minimum (most useful baseline)
    echo "${YELLOW}No TTY available — defaulting to --minimum${NC}" >&2
    ARGS=("--minimum")
  fi
fi

echo "${BOLD}rolepod bootstrap${NC}"
echo "  clone target: $DEST"
echo "  ref:          $REF"
echo "  install args: ${ARGS[*]}"
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
# Pin --target=claude defensively — install.sh defaults to claude already, but
# pass it explicitly so a future default change can't surprise existing users.
exec ./install.sh --target=claude "${ARGS[@]}"
