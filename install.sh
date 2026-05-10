#!/usr/bin/env bash
# rolepod installer — copies workflow files to ~/.claude/ and (optionally) installs plugins.
#
# Usage:
#   ./install.sh                       # rolepod core only (no plugins) — safe default
#   ./install.sh --minimum             # core + ui-ux-pro-max + GitNexus + MemPalace
#   ./install.sh --full                # minimum + caveman + rtk + codex CLI + gemini CLI
#   ./install.sh --force               # overwrite existing files (backup created)
#                                      # --force can be combined with any of the above
#   ./install.sh --target=claude       # CLI target (default → ~/.claude)
#   ./install.sh --target=codex        # Codex CLI       → ~/.codex
#   ./install.sh --target=gemini       # Gemini CLI      → ~/.gemini
#   ./install.sh --target=all          # install all three
#   ./install.sh --uninstall           # remove rolepod from selected --target
#                                      # add --yes/-y to skip confirmation prompt
#
# Env:
#   ROLEPOD_TARGET    where to write rolepod files. For single targets it
#                     overrides the default path; for --target=all it is
#                     ignored (each CLI uses its conventional path).
#
# Managed entry docs (CLAUDE.md / AGENTS.md / GEMINI.md): rolepod content is
# wrapped in <!-- rolepod:start --> ... <!-- rolepod:end --> markers. User
# content outside those markers is preserved across re-installs and uninstall.
#
# Detection: every plugin install is preceded by a check. Already-installed plugins
# are skipped. Failed installs print a manual fallback command and continue.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${ROLEPOD_TARGET:-}"   # final value depends on CLI_TARGET; resolved below
PLUGINS_DIR=""                  # set after TARGET resolves
MODE="core"
FORCE=0
CLI_TARGET="claude"
UNINSTALL=0
ASSUME_YES=0

# Args
for arg in "$@"; do
  case "$arg" in
    --minimum|--min) MODE="minimum" ;;
    --full)          MODE="full" ;;
    --core|--merge)  MODE="core" ;;
    --force)         FORCE=1 ;;
    --uninstall)     UNINSTALL=1 ;;
    --yes|-y)        ASSUME_YES=1 ;;
    --target=*)      CLI_TARGET="${arg#--target=}" ;;
    -h|--help)
      sed -n '2,28p' "$0"
      exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

case "$CLI_TARGET" in
  claude|codex|gemini|all) ;;
  *)
    echo "Unknown --target value: $CLI_TARGET (expected claude|codex|gemini|all)" >&2
    exit 1 ;;
esac

# Resolve install destination per CLI target. ROLEPOD_TARGET (env) wins for
# all targets when set, so dry-run installs into a tempdir keep working.
default_target_path_for() {
  case "$1" in
    claude) echo "$HOME/.claude" ;;
    codex)  echo "$HOME/.codex" ;;
    gemini) echo "$HOME/.gemini" ;;
    *)      echo "$HOME/.$1" ;;
  esac
}

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

# Generic helpers — defined early so install/uninstall blocks below can use them.
have_cmd() { command -v "$1" >/dev/null 2>&1; }
have_dir() { [ -d "$1" ]; }

# ─── Managed-block helpers ──────────────────────────────────────────────
# Entry docs (~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.gemini/GEMINI.md)
# may contain user content. Wrap rolepod content in HTML markers so we only
# touch our own block on subsequent installs.
ROLEPOD_BLOCK_START="<!-- rolepod:start -->"
ROLEPOD_BLOCK_END="<!-- rolepod:end -->"

# update_managed_block <target_file> <source_file>
# - target missing/empty → write block-only
# - target has markers   → replace content between markers
# - target has no markers → append markers + block (preserve existing user content)
update_managed_block() {
  local target_file="$1"
  local source_file="$2"
  [ -f "$source_file" ] || { warn "managed block: source $source_file missing"; return 1; }

  if [ ! -e "$target_file" ] || [ ! -s "$target_file" ]; then
    mkdir -p "$(dirname "$target_file")"
    {
      printf '%s\n' "$ROLEPOD_BLOCK_START"
      cat "$source_file"
      printf '\n%s\n' "$ROLEPOD_BLOCK_END"
    } > "$target_file"
    return 0
  fi

  if grep -qF "$ROLEPOD_BLOCK_START" "$target_file" && grep -qF "$ROLEPOD_BLOCK_END" "$target_file"; then
    # Replace block: strip existing block, then append fresh block.
    # awk reads body from source file (not -v) to avoid escape issues with
    # arbitrary content (em-dashes, backticks, backslashes, etc.).
    local tmp
    tmp=$(mktemp)
    awk -v start="$ROLEPOD_BLOCK_START" -v end="$ROLEPOD_BLOCK_END" '
      $0 == start { in_block = 1; next }
      in_block { if ($0 == end) in_block = 0; next }
      { print }
    ' "$target_file" > "$tmp"
    # Trim trailing blank lines from the surviving user content
    awk '
      { lines[NR] = $0 }
      END {
        last = NR
        while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
        for (i = 1; i <= last; i++) print lines[i]
      }
    ' "$tmp" > "$target_file"
    rm -f "$tmp"
    {
      printf '\n%s\n' "$ROLEPOD_BLOCK_START"
      cat "$source_file"
      printf '\n%s\n' "$ROLEPOD_BLOCK_END"
    } >> "$target_file"
    return 0
  fi

  # No markers → append block after existing user content
  {
    printf '\n%s\n' "$ROLEPOD_BLOCK_START"
    cat "$source_file"
    printf '\n%s\n' "$ROLEPOD_BLOCK_END"
  } >> "$target_file"
}

# remove_managed_block <target_file>
# - removes ROLEPOD_BLOCK_START..ROLEPOD_BLOCK_END (inclusive)
# - leaves rest of file intact
# - if file becomes empty (only contained our block), removes the file
remove_managed_block() {
  local target_file="$1"
  [ -f "$target_file" ] || return 0
  if ! grep -qF "$ROLEPOD_BLOCK_START" "$target_file"; then
    return 0
  fi
  local tmp
  tmp=$(mktemp)
  awk -v start="$ROLEPOD_BLOCK_START" -v end="$ROLEPOD_BLOCK_END" '
    {
      if ($0 == start) { in_block = 1; next }
      if (in_block) {
        if ($0 == end) { in_block = 0 }
        next
      }
      print
    }
  ' "$target_file" > "$tmp"
  # Trim trailing blank lines
  awk 'NF{p=1} p' "$tmp" | awk '
    { lines[NR] = $0 }
    END {
      last = NR
      while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
      for (i = 1; i <= last; i++) print lines[i]
    }
  ' > "$target_file"
  rm -f "$tmp"
  if [ ! -s "$target_file" ]; then
    rm -f "$target_file"
  fi
}

INSTALLED=()
SKIPPED=()
FAILED=()

note_installed() { INSTALLED+=("$1"); }
note_skipped()   { SKIPPED+=("$1"); }
note_failed()    { FAILED+=("$1"); }

echo "${BOLD}rolepod installer${NC}"
echo "  source: $REPO_DIR"
echo "  cli:    $CLI_TARGET"
echo "  mode:   $MODE"
echo "  force:  $FORCE"
echo ""

# ─── Sanity check source ────────────────────────────────────────────────
for f in CHEATSHEET.md core/agents core/rules hooks core/skills commands .claude-plugin/plugin.json build/render.sh adapters/claude/CLAUDE.md.tmpl; do
  [ -e "$REPO_DIR/$f" ] || fail "missing $f in $REPO_DIR — run from rolepod repo"
done

# Codex/Gemini adapter sanity (only required if those targets selected).
# Phase 2.3: each CLI ships as a native plugin/extension — no wrapper scripts.
case "$CLI_TARGET" in
  codex|all)
    [ -e "$REPO_DIR/adapters/codex/AGENTS.md.tmpl" ]            || fail "missing adapters/codex/AGENTS.md.tmpl"
    [ -e "$REPO_DIR/adapters/codex/.codex-plugin/plugin.json" ] || fail "missing adapters/codex/.codex-plugin/plugin.json"
    [ -d "$REPO_DIR/adapters/codex/agents" ]                     || fail "missing adapters/codex/agents/"
    [ -e "$REPO_DIR/adapters/codex/hooks/hooks.json" ]           || fail "missing adapters/codex/hooks/hooks.json"
    ;;
esac
case "$CLI_TARGET" in
  gemini|all)
    [ -e "$REPO_DIR/adapters/gemini/GEMINI.md.tmpl" ]        || fail "missing adapters/gemini/GEMINI.md.tmpl"
    [ -e "$REPO_DIR/adapters/gemini/gemini-extension.json" ] || fail "missing adapters/gemini/gemini-extension.json"
    [ -d "$REPO_DIR/adapters/gemini/commands" ]              || fail "missing adapters/gemini/commands/"
    [ -e "$REPO_DIR/adapters/gemini/hooks/hooks.json" ]      || fail "missing adapters/gemini/hooks/hooks.json"
    ;;
esac

# ─── Uninstall path (early-exit) ────────────────────────────────────────
# Removes rolepod files written by this installer. Preserves user content
# outside our managed blocks. Idempotent — safe to run when nothing installed.
if [ "$UNINSTALL" -eq 1 ]; then
  echo "${BOLD}rolepod uninstaller${NC}"
  echo "  cli:    $CLI_TARGET"
  echo ""

  # Discover what we'd remove so the user can decide.
  uninstall_claude=0; uninstall_codex=0; uninstall_gemini=0
  case "$CLI_TARGET" in claude|all) uninstall_claude=1 ;; esac
  case "$CLI_TARGET" in codex|all)  uninstall_codex=1 ;; esac
  case "$CLI_TARGET" in gemini|all) uninstall_gemini=1 ;; esac

  C_TARGET="${ROLEPOD_TARGET:-$(default_target_path_for claude)}"
  X_TARGET="${ROLEPOD_TARGET:-$(default_target_path_for codex)}"
  G_TARGET="${ROLEPOD_TARGET:-$(default_target_path_for gemini)}"
  if [ "$CLI_TARGET" = "all" ]; then
    C_TARGET="$(default_target_path_for claude)"
    X_TARGET="$(default_target_path_for codex)"
    G_TARGET="$(default_target_path_for gemini)"
  fi

  echo "About to remove rolepod from:"
  [ "$uninstall_claude" -eq 1 ] && echo "  Claude → $C_TARGET (agents, skills, rules, hooks, managed CLAUDE.md block)"
  [ "$uninstall_codex"  -eq 1 ] && echo "  Codex  → $X_TARGET/plugins/rolepod, managed AGENTS.md block"
  [ "$uninstall_gemini" -eq 1 ] && echo "  Gemini → $G_TARGET/extensions/rolepod, managed GEMINI.md block"
  echo ""

  if [ "$ASSUME_YES" -ne 1 ]; then
    if [ -t 0 ] || [ -r /dev/tty ]; then
      printf "Continue? [y/N] " > /dev/tty
      read -r reply < /dev/tty || reply=""
    else
      reply=""
    fi
    case "$reply" in
      y|Y|yes|YES) ;;
      *) echo "Aborted."; exit 0 ;;
    esac
  fi

  # Build name lists from source repo so we only remove what rolepod ships.
  AGENT_NAMES=()
  if [ -d "$REPO_DIR/core/agents" ]; then
    while IFS= read -r f; do
      AGENT_NAMES+=("$(basename "$f")")
    done < <(find "$REPO_DIR/core/agents" -maxdepth 1 -name '*.md' 2>/dev/null)
  fi
  SKILL_NAMES=()
  if [ -d "$REPO_DIR/core/skills" ]; then
    for d in "$REPO_DIR"/core/skills/*/; do
      [ -d "$d" ] && SKILL_NAMES+=("$(basename "$d")")
    done
  fi
  RULE_NAMES=()
  if [ -d "$REPO_DIR/core/rules" ]; then
    while IFS= read -r f; do
      RULE_NAMES+=("$(basename "$f")")
    done < <(find "$REPO_DIR/core/rules" -maxdepth 1 -name '*.md' 2>/dev/null)
  fi
  HOOK_NAMES=()
  if [ -d "$REPO_DIR/hooks" ]; then
    while IFS= read -r f; do
      HOOK_NAMES+=("$(basename "$f")")
    done < <(find "$REPO_DIR/hooks" -maxdepth 1 -name '*.sh' 2>/dev/null)
  fi
  COMMAND_NAMES=()
  if [ -d "$REPO_DIR/commands" ]; then
    while IFS= read -r f; do
      COMMAND_NAMES+=("$(basename "$f")")
    done < <(find "$REPO_DIR/commands" -maxdepth 1 -name '*.md' 2>/dev/null)
  fi

  if [ "$uninstall_claude" -eq 1 ]; then
    step "Removing Claude rolepod files in $C_TARGET"
    for n in "${AGENT_NAMES[@]}";   do rm -f "$C_TARGET/agents/$n"; done
    for n in "${RULE_NAMES[@]}";    do rm -f "$C_TARGET/rules/$n"; done
    for n in "${COMMAND_NAMES[@]}"; do rm -f "$C_TARGET/commands/$n"; done
    for n in "${HOOK_NAMES[@]}";    do rm -f "$C_TARGET/hooks/$n"; done
    for n in "${SKILL_NAMES[@]}";   do rm -rf "$C_TARGET/skills/$n"; done
    rm -f "$C_TARGET/CHEATSHEET.md"
    rm -f "$C_TARGET/.claude-plugin/plugin.json"
    # Empty dirs cleanup (rmdir; ignore failure if non-empty)
    rmdir "$C_TARGET/agents" "$C_TARGET/rules" "$C_TARGET/commands" "$C_TARGET/hooks" "$C_TARGET/skills" "$C_TARGET/.claude-plugin" 2>/dev/null || true

    # Strip rolepod hook entries from settings.json (keep user's other config).
    SETTINGS_FILE="$C_TARGET/settings.json"
    if [ -f "$SETTINGS_FILE" ]; then
      step "Stripping rolepod hook entries from $SETTINGS_FILE"
      if command -v python3 >/dev/null 2>&1; then
        python3 - "$SETTINGS_FILE" "$C_TARGET/hooks" <<'PY' || warn "settings.json strip failed (non-fatal)"
import json, sys, os
path, hook_dir = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)
if not isinstance(data, dict) or "hooks" not in data:
    sys.exit(0)
hooks = data.get("hooks") or {}
def strip(arr):
    out = []
    for group in arr or []:
        inner = [h for h in (group.get("hooks") or [])
                 if hook_dir not in (h.get("command") or "")]
        if inner:
            group["hooks"] = inner
            out.append(group)
    return out
for evt in list(hooks.keys()):
    new = strip(hooks[evt])
    if new:
        hooks[evt] = new
    else:
        del hooks[evt]
if hooks:
    data["hooks"] = hooks
else:
    data.pop("hooks", None)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
      else
        warn "python3 not found — leaving settings.json untouched (remove rolepod hook entries manually)"
      fi
    fi

    step "Stripping rolepod block from $C_TARGET/CLAUDE.md"
    remove_managed_block "$C_TARGET/CLAUDE.md"

    ok "Claude rolepod files removed"
  fi

  if [ "$uninstall_codex" -eq 1 ]; then
    step "Removing Codex rolepod plugin in $X_TARGET/plugins/rolepod"
    rm -rf "$X_TARGET/plugins/rolepod"
    rmdir "$X_TARGET/plugins" 2>/dev/null || true
    step "Stripping rolepod block from $X_TARGET/AGENTS.md"
    remove_managed_block "$X_TARGET/AGENTS.md"
    ok "Codex rolepod removed"
  fi

  if [ "$uninstall_gemini" -eq 1 ]; then
    step "Removing Gemini rolepod extension in $G_TARGET/extensions/rolepod"
    rm -rf "$G_TARGET/extensions/rolepod"
    rmdir "$G_TARGET/extensions" 2>/dev/null || true
    step "Stripping rolepod block from $G_TARGET/GEMINI.md"
    remove_managed_block "$G_TARGET/GEMINI.md"
    ok "Gemini rolepod removed"
  fi

  echo ""
  echo "${BOLD}Uninstall complete.${NC}"
  exit 0
fi

# ─── Render all required entry docs up front ────────────────────────────
RENDER_TARGET="$CLI_TARGET"
step "Rendering entry doc(s) (target: $RENDER_TARGET)"
if ! bash "$REPO_DIR/build/render.sh" --target="$RENDER_TARGET"; then
  fail "render.sh failed — fix template/fragments before installing"
fi

# ─── install_claude — Claude Code path (~/.claude/) ────────────────────
# This logic flows top-level (not in a function) for back-compat with the
# original install.sh; gated by `if claude_selected` so other targets skip it.
claude_selected() {
  case "$CLI_TARGET" in claude|all) return 0 ;; *) return 1 ;; esac
}
codex_selected() {
  case "$CLI_TARGET" in codex|all)  return 0 ;; *) return 1 ;; esac
}
gemini_selected() {
  case "$CLI_TARGET" in gemini|all) return 0 ;; *) return 1 ;; esac
}

if claude_selected; then
  TARGET="${ROLEPOD_TARGET:-$(default_target_path_for claude)}"
  PLUGINS_DIR="$TARGET/plugins"
  echo ""
  echo "${BOLD}─── Installing for Claude Code ───${NC}"
  echo "  target: $TARGET"

  RENDERED_CLAUDE_MD="$REPO_DIR/build/rendered/claude/CLAUDE.md"
  [ -f "$RENDERED_CLAUDE_MD" ] || fail "expected $RENDERED_CLAUDE_MD after render"

  # Backup if --force on existing
  if [ "$FORCE" -eq 1 ] && [ -d "$TARGET" ]; then
    STAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP="$HOME/.claude.backup-$STAMP"
    warn "Backing up existing $TARGET → $BACKUP"
    cp -R "$TARGET" "$BACKUP"
  fi

  step "Creating directory structure"
  mkdir -p "$TARGET"/{agents,rules,hooks,skills,commands,.claude-plugin,plugins}

  if [ "$FORCE" -eq 1 ]; then CP_FLAG=""; else CP_FLAG="-n"; fi

  step "Updating CLAUDE.md (managed block) + CHEATSHEET.md"
  update_managed_block "$TARGET/CLAUDE.md" "$RENDERED_CLAUDE_MD"
  cp $CP_FLAG "$REPO_DIR/CHEATSHEET.md" "$TARGET/" 2>/dev/null || true

  step "Copying agents (18 from rendered/) + rules (16) + commands"
  cp $CP_FLAG "$REPO_DIR"/build/rendered/claude/agents/*.md "$TARGET/agents/"   2>/dev/null || true
  cp $CP_FLAG "$REPO_DIR"/core/rules/*.md                   "$TARGET/rules/"    2>/dev/null || true
  cp $CP_FLAG "$REPO_DIR"/commands/*.md                     "$TARGET/commands/" 2>/dev/null || true

  step "Copying hooks (4) and marking executable"
  cp $CP_FLAG "$REPO_DIR"/hooks/*.sh "$TARGET/hooks/" 2>/dev/null || true
  chmod +x "$TARGET"/hooks/*.sh 2>/dev/null || true

  step "Copying bundled skills (27)"
  for skill_dir in "$REPO_DIR"/core/skills/*/; do
    name=$(basename "$skill_dir")
    if [ "$FORCE" -eq 1 ] || [ ! -e "$TARGET/skills/$name" ]; then
      cp -R "$REPO_DIR/core/skills/$name" "$TARGET/skills/" 2>/dev/null || true
    fi
  done

  step "Copying plugin manifest"
  cp $CP_FLAG "$REPO_DIR/.claude-plugin/plugin.json" "$TARGET/.claude-plugin/" 2>/dev/null || true

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
  warn "  Hooks shipped: project-context-loader.sh (SessionStart), context-awareness.sh (PreToolUse Edit|Write|Bash), verify-reminder.sh (PostToolUse Edit|Write), post-ship-detect.sh (PostToolUse Bash)"
fi

# ─── Verify Claude rolepod core ─────────────────────────────────────────
step "Verifying rolepod core"
for required in \
  CLAUDE.md CHEATSHEET.md \
  agents/qa-tester.md agents/system-architect.md \
  rules/INDEX.md rules/team-org.md \
  hooks/verify-reminder.sh hooks/project-context-loader.sh \
  skills/zoom-out/SKILL.md skills/anti-spaghetti/SKILL.md commands/careful.md \
  .claude-plugin/plugin.json
do
  [ -e "$TARGET/$required" ] || fail "verification failed — $TARGET/$required missing"
done
ok "rolepod core installed → $TARGET"
fi  # end claude_selected

# ─── install_codex — Codex CLI path (~/.codex/) ────────────────────────
# Phase 2.3: install as a native Codex plugin under ~/.codex/plugins/rolepod/.
# AGENTS.md still goes to ~/.codex/AGENTS.md (Codex auto-loads global instructions
# from there independently of the plugin tree).
if codex_selected; then
  CODEX_TARGET="${ROLEPOD_TARGET:-$(default_target_path_for codex)}"
  # If --target=all, ROLEPOD_TARGET may have been used by claude block. For
  # multi-target installs we still want each CLI in its conventional path,
  # so reset to default when CLI_TARGET=all.
  if [ "$CLI_TARGET" = "all" ]; then
    CODEX_TARGET="$(default_target_path_for codex)"
  fi
  CODEX_PLUGIN_DEST="$CODEX_TARGET/plugins/rolepod"
  echo ""
  echo "${BOLD}─── Installing for Codex CLI ───${NC}"
  echo "  target:        $CODEX_TARGET"
  echo "  plugin dest:   $CODEX_PLUGIN_DEST"

  if ! have_cmd codex; then
    warn "codex binary not found — skipping Codex install (file copy only)"
    warn "  Install Codex CLI: npm install -g @openai/codex"
  fi

  RENDERED_CODEX_DIR="$REPO_DIR/build/rendered/codex"
  RENDERED_AGENTS_MD="$RENDERED_CODEX_DIR/AGENTS.md"
  [ -f "$RENDERED_AGENTS_MD" ]                || fail "expected $RENDERED_AGENTS_MD after render"
  [ -d "$RENDERED_CODEX_DIR/.codex-plugin" ]  || fail "expected $RENDERED_CODEX_DIR/.codex-plugin/ after render"
  [ -d "$RENDERED_CODEX_DIR/agents" ]         || fail "expected $RENDERED_CODEX_DIR/agents/ after render"
  [ -d "$RENDERED_CODEX_DIR/hooks" ]          || fail "expected $RENDERED_CODEX_DIR/hooks/ after render"
  [ -d "$RENDERED_CODEX_DIR/skills" ]         || fail "expected $RENDERED_CODEX_DIR/skills/ after render"

  if [ "$FORCE" -eq 1 ] && [ -d "$CODEX_TARGET" ]; then
    STAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP="$HOME/.codex.backup-$STAMP"
    warn "Backing up existing $CODEX_TARGET → $BACKUP"
    cp -R "$CODEX_TARGET" "$BACKUP"
  fi

  step "Creating Codex plugin directory"
  mkdir -p "$CODEX_PLUGIN_DEST"

  # If --force, wipe plugin dir first so deletions in source propagate.
  if [ "$FORCE" -eq 1 ]; then
    rm -rf "$CODEX_PLUGIN_DEST"
    mkdir -p "$CODEX_PLUGIN_DEST"
  fi

  step "Copying plugin tree → $CODEX_PLUGIN_DEST/"
  # cp -R src/. dest/ copies *contents* of src into dest (BSD + GNU compatible).
  cp -R "$RENDERED_CODEX_DIR/." "$CODEX_PLUGIN_DEST/" 2>/dev/null || true
  # AGENTS.md is the entry doc — it lives at the Codex root, not inside the plugin.
  rm -f "$CODEX_PLUGIN_DEST/AGENTS.md"

  step "Updating AGENTS.md (managed block) → $CODEX_TARGET/AGENTS.md"
  update_managed_block "$CODEX_TARGET/AGENTS.md" "$RENDERED_AGENTS_MD"

  step "Marking hook scripts executable"
  chmod +x "$CODEX_PLUGIN_DEST/hooks"/*.sh 2>/dev/null || true

  step "Verifying Codex install"
  for required in \
    AGENTS.md \
    plugins/rolepod/.codex-plugin/plugin.json \
    plugins/rolepod/agents/qa-tester.toml \
    plugins/rolepod/hooks/hooks.json \
    plugins/rolepod/skills/anti-spaghetti/SKILL.md
  do
    [ -e "$CODEX_TARGET/$required" ] || fail "Codex verification failed — $CODEX_TARGET/$required missing"
  done
  ok "rolepod codex plugin installed → $CODEX_PLUGIN_DEST"
  ok "AGENTS.md → $CODEX_TARGET/AGENTS.md"
fi

# ─── install_gemini — Gemini CLI path (~/.gemini/) ─────────────────────
# Phase 2.3: install as a native Gemini extension under
# ~/.gemini/extensions/rolepod/. GEMINI.md goes to ~/.gemini/GEMINI.md (auto-loaded).
if gemini_selected; then
  GEMINI_TARGET="${ROLEPOD_TARGET:-$(default_target_path_for gemini)}"
  if [ "$CLI_TARGET" = "all" ]; then
    GEMINI_TARGET="$(default_target_path_for gemini)"
  fi
  GEMINI_EXT_DEST="$GEMINI_TARGET/extensions/rolepod"
  echo ""
  echo "${BOLD}─── Installing for Gemini CLI ───${NC}"
  echo "  target:           $GEMINI_TARGET"
  echo "  extension dest:   $GEMINI_EXT_DEST"

  if ! have_cmd gemini; then
    warn "gemini binary not found — skipping Gemini install (file copy only)"
    warn "  Install Gemini CLI: npm install -g @google/gemini-cli"
  fi

  RENDERED_GEMINI_DIR="$REPO_DIR/build/rendered/gemini"
  RENDERED_GEMINI_MD="$RENDERED_GEMINI_DIR/GEMINI.md"
  [ -f "$RENDERED_GEMINI_MD" ]                            || fail "expected $RENDERED_GEMINI_MD after render"
  [ -f "$RENDERED_GEMINI_DIR/gemini-extension.json" ]     || fail "expected $RENDERED_GEMINI_DIR/gemini-extension.json after render"
  [ -d "$RENDERED_GEMINI_DIR/commands" ]                  || fail "expected $RENDERED_GEMINI_DIR/commands/ after render"
  [ -d "$RENDERED_GEMINI_DIR/hooks" ]                     || fail "expected $RENDERED_GEMINI_DIR/hooks/ after render"
  [ -d "$RENDERED_GEMINI_DIR/skills" ]                    || fail "expected $RENDERED_GEMINI_DIR/skills/ after render"

  if [ "$FORCE" -eq 1 ] && [ -d "$GEMINI_TARGET" ]; then
    STAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP="$HOME/.gemini.backup-$STAMP"
    warn "Backing up existing $GEMINI_TARGET → $BACKUP"
    cp -R "$GEMINI_TARGET" "$BACKUP"
  fi

  step "Creating Gemini extension directory"
  mkdir -p "$GEMINI_EXT_DEST"

  if [ "$FORCE" -eq 1 ]; then
    rm -rf "$GEMINI_EXT_DEST"
    mkdir -p "$GEMINI_EXT_DEST"
  fi

  step "Copying extension tree → $GEMINI_EXT_DEST/"
  cp -R "$RENDERED_GEMINI_DIR/." "$GEMINI_EXT_DEST/" 2>/dev/null || true
  # GEMINI.md is the entry doc — it lives at the Gemini root, not in the extension.
  rm -f "$GEMINI_EXT_DEST/GEMINI.md"

  step "Updating GEMINI.md (managed block) → $GEMINI_TARGET/GEMINI.md"
  update_managed_block "$GEMINI_TARGET/GEMINI.md" "$RENDERED_GEMINI_MD"

  step "Marking hook scripts executable"
  chmod +x "$GEMINI_EXT_DEST/hooks"/*.sh 2>/dev/null || true

  step "Verifying Gemini install"
  for required in \
    GEMINI.md \
    extensions/rolepod/gemini-extension.json \
    extensions/rolepod/commands/careful.toml \
    extensions/rolepod/hooks/hooks.json \
    extensions/rolepod/skills/anti-spaghetti/SKILL.md
  do
    [ -e "$GEMINI_TARGET/$required" ] || fail "Gemini verification failed — $GEMINI_TARGET/$required missing"
  done
  ok "rolepod gemini extension installed → $GEMINI_EXT_DEST"
  ok "GEMINI.md → $GEMINI_TARGET/GEMINI.md"
fi

# Ensure TARGET is set for the rest of the script (Claude plugin install paths
# below assume Claude conventions). For codex/gemini-only runs, plugin install
# is skipped via mode gates anyway.
if [ -z "${TARGET:-}" ]; then
  TARGET="$(default_target_path_for claude)"
  PLUGINS_DIR="$TARGET/plugins"
fi

# ─── Plugin definitions ─────────────────────────────────────────────────
# (have_cmd / have_dir defined earlier near the log helpers)

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
case "$CLI_TARGET" in
  claude) echo "${BOLD}Final step${NC}: restart Claude Code so the hooks register." ;;
  codex)  echo "${BOLD}Final step${NC}: restart Codex CLI to load the new plugin and hooks." ;;
  gemini) echo "${BOLD}Final step${NC}: restart Gemini CLI to load the new extension and hooks." ;;
  all)    echo "${BOLD}Final step${NC}: restart Claude Code, Codex CLI, and Gemini CLI." ;;
esac
