#!/usr/bin/env bash
# rolepod installer — copies workflow files to ~/.claude/ + prints plugin install commands.
#
# Usage:
#   ./install.sh                  # safe: skip existing files, add new ones
#   ./install.sh --force          # overwrite existing (backs up first)
#   ROLEPOD_TARGET=/path ./install.sh   # custom target (default ~/.claude)
#
# The script does NOT auto-install external plugins (license / privacy). It prints
# the exact commands you can run yourself for each plugin you want.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${ROLEPOD_TARGET:-$HOME/.claude}"
MODE="${1:-merge}"

# Colors (no-op when not a TTY)
if [ -t 1 ]; then
  CYAN=$(tput setaf 6 2>/dev/null || true)
  GREEN=$(tput setaf 2 2>/dev/null || true)
  YELLOW=$(tput setaf 3 2>/dev/null || true)
  RED=$(tput setaf 1 2>/dev/null || true)
  BOLD=$(tput bold 2>/dev/null || true)
  NC=$(tput sgr0 2>/dev/null || true)
else
  CYAN=""; GREEN=""; YELLOW=""; RED=""; BOLD=""; NC=""
fi

step()  { echo "${CYAN}▸${NC} $*"; }
ok()    { echo "${GREEN}✓${NC} $*"; }
warn()  { echo "${YELLOW}!${NC} $*"; }
fail()  { echo "${RED}✗${NC} $*" >&2; exit 1; }

echo "${BOLD}rolepod installer${NC}"
echo "Source: $REPO_DIR"
echo "Target: $TARGET"
echo "Mode:   $MODE"
echo ""

# Sanity: verify source has the rolepod layout
for f in CLAUDE.md CHEATSHEET.md agents rules hooks skills commands .claude-plugin/manifest.json; do
  [ -e "$REPO_DIR/$f" ] || fail "missing $f in $REPO_DIR — run from a rolepod repo"
done

# Handle existing target
if [ -d "$TARGET" ] && [ "$MODE" != "merge" ] && [ "$MODE" != "--merge" ] && [ "$MODE" != "--force" ]; then
  cat <<EOF
${YELLOW}$TARGET already exists.${NC} Choose how to proceed:

  ./install.sh --merge    # add rolepod files, skip ones that already exist (safe default)
  ./install.sh --force    # overwrite existing files (creates a timestamped backup first)

EOF
  exit 1
fi

if [ -d "$TARGET" ] && [ "$MODE" = "--force" ]; then
  STAMP=$(date +%Y%m%d-%H%M%S)
  BACKUP="$HOME/.claude.backup-$STAMP"
  warn "Backing up existing $TARGET → $BACKUP"
  cp -R "$TARGET" "$BACKUP"
fi

# Create directory structure
step "Creating directory structure"
mkdir -p "$TARGET"/{agents,rules,hooks,skills,commands,.claude-plugin}

# Copy flags
if [ "$MODE" = "--force" ]; then
  CP_FLAG=""        # overwrite
else
  CP_FLAG="-n"      # no-clobber (safe merge)
fi

# Copy top-level docs
step "Copying core docs (CLAUDE.md, CHEATSHEET.md)"
cp $CP_FLAG "$REPO_DIR/CLAUDE.md"     "$TARGET/"     2>/dev/null || true
cp $CP_FLAG "$REPO_DIR/CHEATSHEET.md" "$TARGET/"     2>/dev/null || true

# Copy agents / rules / commands
step "Copying agents (18) + rules (16) + commands"
cp $CP_FLAG "$REPO_DIR"/agents/*.md     "$TARGET/agents/"   2>/dev/null || true
cp $CP_FLAG "$REPO_DIR"/rules/*.md      "$TARGET/rules/"    2>/dev/null || true
cp $CP_FLAG "$REPO_DIR"/commands/*.md   "$TARGET/commands/" 2>/dev/null || true

# Hooks (need executable bit)
step "Copying hooks (4) and marking executable"
cp $CP_FLAG "$REPO_DIR"/hooks/*.sh "$TARGET/hooks/" 2>/dev/null || true
chmod +x "$TARGET"/hooks/*.sh 2>/dev/null || true

# Skills (custom — only zoom-out ships)
step "Copying custom skills (zoom-out)"
if [ "$MODE" = "--force" ] || [ ! -e "$TARGET/skills/zoom-out" ]; then
  cp -R "$REPO_DIR/skills/zoom-out" "$TARGET/skills/" 2>/dev/null || true
fi

# Plugin manifest
step "Copying plugin manifest"
cp $CP_FLAG "$REPO_DIR/.claude-plugin/manifest.json" "$TARGET/.claude-plugin/" 2>/dev/null || true

# Verify critical files landed
step "Verifying installation"
for required in \
  CLAUDE.md \
  CHEATSHEET.md \
  agents/qa-tester.md \
  agents/system-architect.md \
  rules/INDEX.md \
  rules/team-org.md \
  hooks/verify-reminder.sh \
  hooks/project-context-loader.sh \
  skills/zoom-out/SKILL.md \
  commands/careful.md \
  .claude-plugin/manifest.json
do
  [ -e "$TARGET/$required" ] || fail "verification failed — $TARGET/$required missing"
done

ok "rolepod core installed → $TARGET"
echo ""

# Plugin recommendations
cat <<EOF
${BOLD}${CYAN}Plugin install commands (run yourself for what you want):${NC}

${BOLD}Recommended${NC} — used by an agent's skill preload:
  ui-ux-pro-max  →  used by ui-ux-designer
                    See: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill

${BOLD}Optional power-ups${NC}:
  caveman        →  /caveman ultra → ~75% chat token cut
                    git clone https://github.com/JuliusBrussee/caveman ~/.claude/plugins/caveman

  GitNexus       →  code intelligence (impact / context / rename)
                    npm install -g gitnexus
                    See: https://github.com/abhigyanpatwari/GitNexus

  MemPalace      →  cross-session memory (Stop hook captures learnings)
                    pip install mempalace
                    See: https://github.com/mempalace/mempalace

  claude-seo     →  deep technical SEO sub-agents
                    /plugin install AgriciDaniel/claude-seo

  rtk            →  Rust Token Killer — 60-90% CLI proxy savings
                    cargo install rtk
                    See: https://github.com/rtk-ai/rtk

${BOLD}Anthropic skills${NC} (debugging / TDD / frontend / security / etc.) are
bundled with recent Claude Code releases — no extra install needed.

${BOLD}Final step${NC}: restart Claude Code so hooks register.
EOF
