#!/usr/bin/env bash
# rolepod bootstrap — clones the repo + runs install.sh.
# Interactive: prompts for target/scope if no args provided.
# Non-interactive: pass args to skip the prompt.
#
# Designed for: curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash
#
# Rolepod ships PURE FRAMEWORK ONLY. Recommended add-ons (rtk, caveman,
# GitNexus, claude-mem, ui-ux-pro-max, OpenAI Codex review plugin, Codex CLI,
# Gemini CLI) live in README → "Recommended add-ons" — install separately
# yourself. The framework auto-integrates when each is present.
#
# Env vars:
#   ROLEPOD_DEST     where to clone the repo. Default resolution:
#                      1. honor $ROLEPOD_DEST if set (user-owned, never cleaned)
#                      2. reuse $HOME/rolepod if it's already a git repo (legacy installs)
#                      3. otherwise clone into a $(mktemp -d) and auto-clean on exit
#   ROLEPOD_TARGET   where install.sh writes to (default: ~/.claude — read by install.sh)
#   ROLEPOD_REF      branch/tag to check out (default: main)
#
# Args (forwarded to install.sh — skip interactive prompt if any are given):
#   --force           overwrite existing files (selective backup created)
#   --dry-run         preview every action; write nothing to disk
#   --target=<cli>    claude|codex|gemini|cursor|all (default claude)
#   --scope=global    install to home (default — affects all projects)
#   --scope=project   install to current dir's .claude/ etc. (no global config touched)
#
# Examples:
#   curl -fsSL .../bootstrap.sh | bash                              # interactive
#   curl -fsSL .../bootstrap.sh | bash -s -- --target=codex         # codex, no prompt
#   curl -fsSL .../bootstrap.sh | bash -s -- --target=all --force   # all CLIs, overwrite

set -euo pipefail

REPO_URL="https://github.com/nuttaruj/rolepod.git"
REF="${ROLEPOD_REF:-main}"
ARGS=("$@")

# DEST resolution — pick the safest path that respects user choice:
#   1. honor explicit $ROLEPOD_DEST (user-managed, never cleaned)
#   2. reuse existing ~/rolepod clone (legacy installs, backward compat)
#   3. fall back to ephemeral $(mktemp -d) and clean on exit
CLEANUP_DEST=""
if [ -n "${ROLEPOD_DEST:-}" ]; then
  DEST="$ROLEPOD_DEST"
elif [ -d "$HOME/rolepod/.git" ]; then
  DEST="$HOME/rolepod"
else
  TMP_PARENT="$(mktemp -d -t rolepod-install.XXXXXX)"
  DEST="$TMP_PARENT/rolepod"
  CLEANUP_DEST="$TMP_PARENT"
fi

cleanup() {
  if [ -n "$CLEANUP_DEST" ] && [ -d "$CLEANUP_DEST" ]; then
    rm -rf "$CLEANUP_DEST" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

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
  ${BOLD}4${NC}) ${CYAN}cursor${NC}    — Cursor IDE (~/.cursor/)
  ${BOLD}5${NC}) ${GREEN}all${NC}       — install for all four CLIs

EOF
    target_choice=""
    read -r -p "Target [1/2/3/4/5] (default 1): " target_choice </dev/tty || target_choice=""
    case "${target_choice:-1}" in
      1|claude|"") INTERACTIVE_TARGET="claude" ;;
      2|codex)     INTERACTIVE_TARGET="codex" ;;
      3|gemini)    INTERACTIVE_TARGET="gemini" ;;
      4|cursor)    INTERACTIVE_TARGET="cursor" ;;
      5|all)       INTERACTIVE_TARGET="all" ;;
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
# Run install.sh in-process so the EXIT trap can clean up the temp clone.
./install.sh "${EXTRA[@]+"${EXTRA[@]}"}" "${ARGS[@]+"${ARGS[@]}"}"
