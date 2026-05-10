#!/usr/bin/env bash
# rolepod bootstrap — clones the repo + runs install.sh in one go.
#
# Designed for: curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash
#
# Env vars:
#   ROLEPOD_DEST     where to clone the repo (default: ~/rolepod)
#   ROLEPOD_TARGET   where install.sh writes to (default: ~/.claude — read by install.sh)
#   ROLEPOD_REF      branch/tag to check out (default: main)
#
# Args (forwarded to install.sh):
#   --core      (default) rolepod files only — no plugins
#   --minimum   core + ui-ux-pro-max + GitNexus + MemPalace
#   --full      minimum + caveman + rtk + Codex CLI + Gemini CLI
#   --force     overwrite existing ~/.claude (backup created)
#
# Examples:
#   curl -fsSL .../bootstrap.sh | bash                       # core
#   curl -fsSL .../bootstrap.sh | bash -s -- --minimum       # workflow plugins
#   curl -fsSL .../bootstrap.sh | bash -s -- --full          # everything

set -euo pipefail

REPO_URL="https://github.com/nuttaruj/rolepod.git"
DEST="${ROLEPOD_DEST:-$HOME/rolepod}"
REF="${ROLEPOD_REF:-main}"

echo "rolepod bootstrap"
echo "  clone target: $DEST"
echo "  ref:          $REF"
echo ""

if [ -d "$DEST/.git" ]; then
  echo "▸ $DEST already a git repo — fetching latest"
  git -C "$DEST" fetch --quiet origin "$REF"
  git -C "$DEST" checkout --quiet "$REF"
  git -C "$DEST" pull --ff-only --quiet
elif [ -e "$DEST" ]; then
  echo "✗ $DEST exists but is not a git repo — refusing to overwrite" >&2
  echo "  Move or delete it, or set ROLEPOD_DEST to a different path." >&2
  exit 1
else
  echo "▸ Cloning $REPO_URL → $DEST"
  git clone --quiet --branch "$REF" "$REPO_URL" "$DEST"
fi

cd "$DEST"
exec ./install.sh "$@"
