#!/usr/bin/env bash
# rolepod installer — copies workflow files to ~/.claude/ and (optionally) installs plugins.
#
# Usage:
#   ./install.sh                 # rolepod core only (no plugins) — safe default
#   ./install.sh --minimum       # core + ui-ux-pro-max + GitNexus + MemPalace
#   ./install.sh --full          # minimum + caveman + rtk + codex CLI + gemini CLI
#   ./install.sh --force         # overwrite existing ~/.claude files (backup created)
#                                # --force can be combined with any of the above
#
# Env:
#   ROLEPOD_TARGET    where to write rolepod files (default ~/.claude)
#
# Detection: every plugin install is preceded by a check. Already-installed plugins
# are skipped. Failed installs print a manual fallback command and continue.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${ROLEPOD_TARGET:-$HOME/.claude}"
PLUGINS_DIR="$TARGET/plugins"
MODE="core"
FORCE=0

# Args
for arg in "$@"; do
  case "$arg" in
    --minimum|--min) MODE="minimum" ;;
    --full)          MODE="full" ;;
    --core|--merge)  MODE="core" ;;
    --force)         FORCE=1 ;;
    -h|--help)
      sed -n '2,17p' "$0"
      exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

# Colors
if [ -t 1 ]; then
  CYAN=$(tput setaf 6 || true); GREEN=$(tput setaf 2 || true)
  YELLOW=$(tput setaf 3 || true); RED=$(tput setaf 1 || true)
  BOLD=$(tput bold || true); NC=$(tput sgr0 || true)
else
  CYAN=""; GREEN=""; YELLOW=""; RED=""; BOLD=""; NC=""
fi

step() { echo "${CYAN}▸${NC} $*"; }
ok()   { echo "${GREEN}✓${NC} $*"; }
warn() { echo "${YELLOW}!${NC} $*"; }
fail() { echo "${RED}✗${NC} $*" >&2; exit 1; }
skip() { echo "${YELLOW}~${NC} $*"; }

INSTALLED=()
SKIPPED=()
FAILED=()

note_installed() { INSTALLED+=("$1"); }
note_skipped()   { SKIPPED+=("$1"); }
note_failed()    { FAILED+=("$1"); }

echo "${BOLD}rolepod installer${NC}"
echo "  source: $REPO_DIR"
echo "  target: $TARGET"
echo "  mode:   $MODE"
echo "  force:  $FORCE"
echo ""

# ─── Sanity check source ────────────────────────────────────────────────
for f in CLAUDE.md CHEATSHEET.md agents rules hooks skills commands .claude-plugin/manifest.json; do
  [ -e "$REPO_DIR/$f" ] || fail "missing $f in $REPO_DIR — run from rolepod repo"
done

# ─── Backup if --force on existing ──────────────────────────────────────
if [ "$FORCE" -eq 1 ] && [ -d "$TARGET" ]; then
  STAMP=$(date +%Y%m%d-%H%M%S)
  BACKUP="$HOME/.claude.backup-$STAMP"
  warn "Backing up existing $TARGET → $BACKUP"
  cp -R "$TARGET" "$BACKUP"
fi

# ─── Copy rolepod core ──────────────────────────────────────────────────
step "Creating directory structure"
mkdir -p "$TARGET"/{agents,rules,hooks,skills,commands,.claude-plugin,plugins}

if [ "$FORCE" -eq 1 ]; then CP_FLAG=""; else CP_FLAG="-n"; fi

step "Copying core docs (CLAUDE.md, CHEATSHEET.md)"
cp $CP_FLAG "$REPO_DIR/CLAUDE.md"     "$TARGET/" 2>/dev/null || true
cp $CP_FLAG "$REPO_DIR/CHEATSHEET.md" "$TARGET/" 2>/dev/null || true

step "Copying agents (18) + rules (16) + commands"
cp $CP_FLAG "$REPO_DIR"/agents/*.md   "$TARGET/agents/"   2>/dev/null || true
cp $CP_FLAG "$REPO_DIR"/rules/*.md    "$TARGET/rules/"    2>/dev/null || true
cp $CP_FLAG "$REPO_DIR"/commands/*.md "$TARGET/commands/" 2>/dev/null || true

step "Copying hooks (4) and marking executable"
cp $CP_FLAG "$REPO_DIR"/hooks/*.sh "$TARGET/hooks/" 2>/dev/null || true
chmod +x "$TARGET"/hooks/*.sh 2>/dev/null || true

step "Copying bundled skills (27)"
for skill_dir in "$REPO_DIR"/skills/*/; do
  name=$(basename "$skill_dir")
  if [ "$FORCE" -eq 1 ] || [ ! -e "$TARGET/skills/$name" ]; then
    cp -R "$REPO_DIR/skills/$name" "$TARGET/skills/" 2>/dev/null || true
  fi
done

step "Copying plugin manifest"
cp $CP_FLAG "$REPO_DIR/.claude-plugin/manifest.json" "$TARGET/.claude-plugin/" 2>/dev/null || true

# ─── Register hooks in settings.json ────────────────────────────────────
# Claude Code reads hooks from ~/.claude/settings.json — manifest.json is
# descriptive metadata only. Hooks shipped to ~/.claude/hooks/ do NOT auto-fire
# unless registered here. This block is idempotent: existing entries are
# preserved, rolepod entries are upserted by command path.

SETTINGS_FILE="$TARGET/settings.json"
HOOK_DIR="$TARGET/hooks"

step "Registering rolepod hooks in $SETTINGS_FILE"

# Create empty settings.json if missing
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

REGISTER_OK=0
if command -v jq >/dev/null 2>&1; then
  TMP_FILE=$(mktemp)
  if jq \
    --arg ctx "$HOOK_DIR/project-context-loader.sh" \
    --arg awa "$HOOK_DIR/context-awareness.sh" \
    --arg ver "$HOOK_DIR/verify-reminder.sh" \
    --arg shp "$HOOK_DIR/post-ship-detect.sh" '
    # Helper: ensure a matcher group exists with given matcher (returns updated array)
    def ensure_group($arr; $matcher):
      if ($arr | map(select(.matcher == $matcher)) | length) > 0 then $arr
      else $arr + [{"matcher": $matcher, "hooks": []}] end;

    # Helper: add command to matching matcher group if absent
    def upsert_cmd($arr; $matcher; $cmd; $timeout):
      ensure_group($arr; $matcher) | map(
        if .matcher == $matcher then
          if (.hooks | map(select(.command == $cmd)) | length) > 0 then .
          else .hooks += [{"type": "command", "command": $cmd, "timeout": $timeout}] end
        else . end
      );

    # Helper for SessionStart (uses startup|resume matcher)
    def upsert_session($arr; $cmd; $timeout):
      ensure_group($arr; "startup|resume") | map(
        if .matcher == "startup|resume" then
          if (.hooks | map(select(.command == $cmd)) | length) > 0 then .
          else .hooks += [{"type": "command", "command": $cmd, "timeout": $timeout}] end
        else . end
      );

    .hooks = (.hooks // {})
    | .hooks.SessionStart = upsert_session((.hooks.SessionStart // []); $ctx; 5)
    | .hooks.PreToolUse = upsert_cmd((.hooks.PreToolUse // []); "Edit|Write|Bash"; $awa; 3)
    | .hooks.PostToolUse = upsert_cmd((.hooks.PostToolUse // []); "Edit|Write"; $ver; 3)
    | .hooks.PostToolUse = upsert_cmd((.hooks.PostToolUse // []); "Bash"; $shp; 5)
  ' "$SETTINGS_FILE" > "$TMP_FILE" 2>/dev/null && [ -s "$TMP_FILE" ]; then
    mv "$TMP_FILE" "$SETTINGS_FILE"
    REGISTER_OK=1
  else
    rm -f "$TMP_FILE"
  fi
fi

if [ "$REGISTER_OK" -eq 0 ]; then
  # Fallback: python3
  if command -v python3 >/dev/null 2>&1; then
    if python3 - "$SETTINGS_FILE" "$HOOK_DIR" <<'PY'
import json, sys, os
path, hook_dir = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}
hooks = data.setdefault("hooks", {})

def upsert(event, matcher, cmd, timeout):
    arr = hooks.setdefault(event, [])
    group = next((g for g in arr if g.get("matcher") == matcher), None)
    if group is None:
        group = {"matcher": matcher, "hooks": []}
        arr.append(group)
    inner = group.setdefault("hooks", [])
    if not any(h.get("command") == cmd for h in inner):
        inner.append({"type": "command", "command": cmd, "timeout": timeout})

upsert("SessionStart", "startup|resume", os.path.join(hook_dir, "project-context-loader.sh"), 5)
upsert("PreToolUse", "Edit|Write|Bash", os.path.join(hook_dir, "context-awareness.sh"), 3)
upsert("PostToolUse", "Edit|Write", os.path.join(hook_dir, "verify-reminder.sh"), 3)
upsert("PostToolUse", "Bash", os.path.join(hook_dir, "post-ship-detect.sh"), 5)

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
    then
      REGISTER_OK=1
    fi
  fi
fi

if [ "$REGISTER_OK" -eq 1 ]; then
  ok "Hooks registered in settings.json (SessionStart + PreToolUse + 2x PostToolUse)"
else
  warn "Could not auto-register hooks — install jq or python3, or edit $SETTINGS_FILE manually"
  warn "  See manifest.json 'components.hooks.shipped' for the 4 hook → event mappings"
fi

# ─── Verify rolepod core ────────────────────────────────────────────────
step "Verifying rolepod core"
for required in \
  CLAUDE.md CHEATSHEET.md \
  agents/qa-tester.md agents/system-architect.md \
  rules/INDEX.md rules/team-org.md \
  hooks/verify-reminder.sh hooks/project-context-loader.sh \
  skills/zoom-out/SKILL.md skills/anti-spaghetti/SKILL.md commands/careful.md \
  .claude-plugin/manifest.json
do
  [ -e "$TARGET/$required" ] || fail "verification failed — $TARGET/$required missing"
done
ok "rolepod core installed → $TARGET"

# ─── Helpers for plugin checks ──────────────────────────────────────────
have_cmd()    { command -v "$1" >/dev/null 2>&1; }
have_dir()    { [ -d "$1" ]; }

# ─── Plugin definitions ─────────────────────────────────────────────────

plugin_anthropic_skills() {
  local p="$TARGET/plugins/marketplaces"
  if have_dir "$p" || have_dir "$TARGET/skills/test-driven-development" \
    || have_dir "$TARGET/skills/anthropic-skills" \
    || have_dir "$TARGET/plugins/marketplaces/anthropics"; then
    ok "Anthropic skills detected (referenced by agent preloads — works as-is)"
    note_skipped "anthropic-skills (already present)"
  else
    warn "Anthropic skills not detected. Most are bundled with recent Claude Code."
    warn "  Update Claude Code, or install via: claude plugin install anthropic-skills"
    note_failed "anthropic-skills (manual)"
  fi
}

plugin_ui_ux_pro_max() {
  local dest="$PLUGINS_DIR/ui-ux-pro-max-skill"
  if have_dir "$dest"; then
    ok "ui-ux-pro-max already installed → $dest"
    note_skipped "ui-ux-pro-max"
    return 0
  fi
  if ! have_cmd git; then
    warn "git not found — install: brew install git"
    note_failed "ui-ux-pro-max"
    return 1
  fi
  step "Cloning ui-ux-pro-max-skill"
  if git clone --quiet https://github.com/nextlevelbuilder/ui-ux-pro-max-skill "$dest"; then
    ok "ui-ux-pro-max installed"
    note_installed "ui-ux-pro-max"
  else
    warn "ui-ux-pro-max clone failed"
    note_failed "ui-ux-pro-max"
  fi
}

plugin_gitnexus() {
  if have_cmd gitnexus; then
    ok "GitNexus already installed → $(command -v gitnexus)"
    note_skipped "gitnexus"
    return 0
  fi
  if ! have_cmd npm; then
    warn "GitNexus needs npm. Install Node.js first → npm install -g gitnexus"
    note_failed "gitnexus"
    return 1
  fi
  step "Installing GitNexus via npm"
  if npm install -g gitnexus 2>&1 | tail -3; then
    ok "GitNexus installed"
    note_installed "gitnexus"
  else
    warn "GitNexus install failed → manual: npm install -g gitnexus"
    note_failed "gitnexus"
  fi
}

plugin_mempalace() {
  if have_cmd mempalace; then
    ok "MemPalace already installed → $(command -v mempalace)"
    note_skipped "mempalace"
    return 0
  fi
  local pip_cmd=""
  if have_cmd pip3; then pip_cmd="pip3"
  elif have_cmd pip; then pip_cmd="pip"
  else
    warn "MemPalace needs pip. Install Python first → pip install mempalace"
    note_failed "mempalace"
    return 1
  fi
  step "Installing MemPalace via $pip_cmd"
  if "$pip_cmd" install --user mempalace 2>&1 | tail -3; then
    ok "MemPalace installed"
    note_installed "mempalace"
  else
    warn "MemPalace install failed → manual: $pip_cmd install mempalace"
    note_failed "mempalace"
  fi
}

plugin_caveman() {
  local dest="$PLUGINS_DIR/caveman"
  if have_dir "$dest"; then
    ok "caveman already installed → $dest"
    note_skipped "caveman"
    return 0
  fi
  if ! have_cmd git; then
    warn "git not found"
    note_failed "caveman"
    return 1
  fi
  step "Cloning caveman"
  if git clone --quiet https://github.com/JuliusBrussee/caveman "$dest"; then
    ok "caveman installed"
    note_installed "caveman"
  else
    warn "caveman clone failed"
    note_failed "caveman"
  fi
}

plugin_rtk() {
  if have_cmd rtk; then
    ok "rtk already installed → $(command -v rtk)"
    note_skipped "rtk"
    return 0
  fi
  if ! have_cmd cargo; then
    warn "rtk needs cargo. Install Rust (https://rustup.rs) → cargo install rtk"
    note_failed "rtk"
    return 1
  fi
  step "Installing rtk via cargo (this can take a few minutes)"
  if cargo install rtk 2>&1 | tail -3; then
    ok "rtk installed"
    note_installed "rtk"
  else
    warn "rtk install failed → manual: cargo install rtk"
    note_failed "rtk"
  fi
}

plugin_gemini_cli() {
  if have_cmd gemini; then
    ok "Gemini CLI already installed → $(command -v gemini)"
    note_skipped "gemini-cli"
    return 0
  fi
  if have_cmd npm; then
    step "Installing Gemini CLI via npm"
    if npm install -g @google/gemini-cli 2>&1 | tail -3; then
      ok "Gemini CLI installed"
      note_installed "gemini-cli"
      warn "Run: gemini auth login"
      return 0
    fi
  fi
  if have_cmd brew; then
    step "Installing Gemini CLI via brew"
    if brew install gemini-cli 2>&1 | tail -3; then
      ok "Gemini CLI installed"
      note_installed "gemini-cli"
      warn "Run: gemini auth login"
      return 0
    fi
  fi
  warn "Gemini CLI needs npm or brew. Manual: npm install -g @google/gemini-cli"
  note_failed "gemini-cli"
}

plugin_codex_cli() {
  if have_cmd codex; then
    ok "Codex CLI already installed → $(command -v codex)"
    note_skipped "codex-cli"
    return 0
  fi
  if ! have_cmd npm; then
    warn "Codex CLI needs npm. Manual: npm install -g @openai/codex"
    note_failed "codex-cli"
    return 1
  fi
  step "Installing Codex CLI via npm"
  if npm install -g @openai/codex 2>&1 | tail -3; then
    ok "Codex CLI installed"
    note_installed "codex-cli"
  else
    warn "Codex CLI install failed → manual: npm install -g @openai/codex"
    note_failed "codex-cli"
  fi
}

plugin_openai_codex_marketplace() {
  local p="$TARGET/plugins/marketplaces/openai-codex"
  if have_dir "$p"; then
    ok "openai-codex Claude Code plugin already installed"
    note_skipped "openai-codex-plugin"
    return 0
  fi
  warn "openai-codex plugin must be installed inside Claude Code:"
  warn "  start Claude Code, then run: /plugin install openai-codex"
  note_failed "openai-codex-plugin (manual /plugin install)"
}

# ─── Run plugin install based on mode ───────────────────────────────────

if [ "$MODE" = "minimum" ] || [ "$MODE" = "full" ]; then
  echo ""
  echo "${BOLD}${CYAN}Installing minimum plugin set${NC}"
  echo "  (Anthropic skills + ui-ux-pro-max + GitNexus + MemPalace)"
  echo ""
  plugin_anthropic_skills
  plugin_ui_ux_pro_max
  plugin_gitnexus
  plugin_mempalace
fi

if [ "$MODE" = "full" ]; then
  echo ""
  echo "${BOLD}${CYAN}Installing full plugin set${NC}"
  echo "  (caveman + rtk + Codex CLI + Gemini CLI + openai-codex plugin)"
  echo ""
  plugin_caveman
  plugin_rtk
  plugin_codex_cli
  plugin_gemini_cli
  plugin_openai_codex_marketplace
fi

# ─── Summary ────────────────────────────────────────────────────────────
echo ""
echo "${BOLD}─── Summary ───${NC}"
if [ "${#INSTALLED[@]}" -gt 0 ]; then
  echo "${GREEN}Installed:${NC}"
  for x in "${INSTALLED[@]}"; do echo "  ✓ $x"; done
fi
if [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo "${YELLOW}Already installed (skipped):${NC}"
  for x in "${SKIPPED[@]}"; do echo "  ~ $x"; done
fi
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "${RED}Manual install needed:${NC}"
  for x in "${FAILED[@]}"; do echo "  ✗ $x"; done
fi

echo ""
if [ "$MODE" = "core" ]; then
  cat <<EOF
${BOLD}rolepod core installed.${NC} For plugin install:

  ./install.sh --minimum    # ui-ux-pro-max + GitNexus + MemPalace
  ./install.sh --full       # minimum + caveman + rtk + Codex + Gemini

EOF
fi

# ─── Post-install interactive prompts ───────────────────────────────────
# Only when stdin is a TTY (or /dev/tty available), and only for modes that
# actually installed the relevant tool. Each prompt reads from /dev/tty so
# this also works when install.sh is piped via curl.

was_installed() {
  local needle="$1"
  for x in "${INSTALLED[@]}"; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

ask_yn() {
  # ask_yn "Question" "Y"|"N"  → returns 0 for yes, 1 for no
  local prompt="$1" default="$2" reply
  local hint="[y/N]"; [ "$default" = "Y" ] && hint="[Y/n]"
  printf "%s %s " "$prompt" "$hint" > /dev/tty
  if ! read -r reply < /dev/tty; then return 1; fi
  reply="${reply:-$default}"
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

if [ -t 0 ] || [ -r /dev/tty ]; then
  if [ "$MODE" = "minimum" ] || [ "$MODE" = "full" ]; then
    # Only prompt if at least one relevant tool is available.
    SHOW_PROMPTS=0
    if have_cmd mempalace || was_installed "mempalace" || have_cmd gemini || was_installed "gemini-cli"; then
      SHOW_PROMPTS=1
    fi
    [ "$MODE" = "full" ] && SHOW_PROMPTS=1

    if [ "$SHOW_PROMPTS" -eq 1 ]; then
      echo ""
      echo "${BOLD}─── Post-install setup ───${NC}"

      # 1) MemPalace init
      if have_cmd mempalace; then
        if ask_yn "Run \`mempalace init\` now to enable cross-session memory?" "Y"; then
          if mempalace init </dev/tty; then
            ok "mempalace init succeeded"
          else
            warn "mempalace init failed — run manually later"
          fi
        else
          skip "Skipped mempalace init (run later: mempalace init)"
        fi
      fi

      # 2) Gemini auth login
      if have_cmd gemini; then
        if ask_yn "Run \`gemini auth login\` now? (opens a browser)" "N"; then
          if gemini auth login </dev/tty; then
            ok "gemini auth login completed"
          else
            warn "gemini auth login failed — run manually later"
          fi
        else
          skip "Skipped gemini auth login (run later: gemini auth login)"
        fi
      fi

      # 3) openai-codex marketplace plugin (full mode + plugin not yet present)
      if [ "$MODE" = "full" ] && [ ! -d "$TARGET/plugins/marketplaces/openai-codex" ]; then
        if ask_yn "Open Claude Code now to install the openai-codex plugin?" "N"; then
          echo "  Start Claude Code, then run inside it:"
          echo "    /plugin install openai-codex"
        else
          skip "Skipped (later inside Claude Code: /plugin install openai-codex)"
        fi
      fi
    fi
  fi
fi

echo ""
echo "${BOLD}Final step${NC}: restart Claude Code so the hooks register."
