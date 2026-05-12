#!/usr/bin/env bash
# rolepod installer — copies workflow files to ~/.claude/ and (optionally) installs plugins.
#
# Usage:
#   ./install.sh                       # rolepod core only (no plugins) — safe default
#   ./install.sh --minimum             # core + ui-ux-pro-max + GitNexus + MemPalace
#   ./install.sh --full                # minimum + caveman + rtk + codex CLI + gemini CLI + openai-codex plugin
#   ./install.sh --force               # overwrite existing files (selective backup created)
#                                      # Backup includes ONLY rolepod-managed paths
#                                      # (entry docs, agents/, rules/, hooks/, skills/, etc.)
#                                      # Excluded: session history (projects/), plugin cache,
#                                      # file-history/, shell-snapshots/, agent-memory/, etc.
#                                      # Typical backup: <50MB (vs ~1.8GB full ~/.claude copy)
#                                      # --force can be combined with any of the above
#   ./install.sh --target=claude       # CLI target (default → ~/.claude)
#   ./install.sh --target=codex        # Codex CLI       → ~/.codex
#   ./install.sh --target=gemini       # Gemini CLI      → ~/.gemini
#   ./install.sh --target=all          # install all three
#   ./install.sh --scope=global        # default — install to home (~/.claude/, etc.)
#   ./install.sh --scope=project       # install to $PWD (no global config touched)
#                                      #   Claude → $PWD/.claude/  (full plugin)
#                                      #   Codex  → $PWD/AGENTS.md (managed block only)
#                                      #   Gemini → $PWD/GEMINI.md (managed block only)
#   ./install.sh --uninstall           # remove rolepod from selected --target
#                                      # add --yes/-y to skip confirmation prompt
#                                      # respects --scope (project = only project files)
#   ./install.sh --dry-run             # preview every action; write nothing to disk
#
# Granular flags (compose your own bundle without --minimum/--full):
#   --with-tools=gitnexus,mempalace,rtk    # global toolchain installs
#   --with-skills=ui-ux-pro-max,caveman    # 3rd-party skill plugins
#   --with-clis=codex,gemini               # install CLI binaries
#   --with-plugins=openai-codex            # Claude marketplace plugins
#
# Bundle equivalents (back-compat):
#   --minimum  ≡  --with-tools=gitnexus,mempalace --with-skills=ui-ux-pro-max
#   --full     ≡  --with-tools=gitnexus,mempalace,rtk --with-skills=ui-ux-pro-max,caveman \
#                 --with-clis=codex,gemini --with-plugins=openai-codex
#
# Env:
#   ROLEPOD_TARGET           Single-target default OR root for --target=all.
#                            • Single target (e.g. --target=codex): overrides the
#                              destination path entirely.
#                            • --target=all: each CLI installs into a subdir of
#                              ROLEPOD_TARGET — claude/, codex/, gemini/. Unset
#                              when --target=all → use ~/.claude, ~/.codex, ~/.gemini.
#   ROLEPOD_CLAUDE_TARGET    Per-CLI override — wins over ROLEPOD_TARGET for Claude.
#   ROLEPOD_CODEX_TARGET     Per-CLI override — wins over ROLEPOD_TARGET for Codex.
#   ROLEPOD_GEMINI_TARGET    Per-CLI override — wins over ROLEPOD_TARGET for Gemini.
#
# Non-TTY behavior: --uninstall without --yes in a non-interactive context
# (no /dev/tty available) prints "Aborted. Re-run with --yes in non-interactive
# mode." and exits 0 — never crashes on a missing TTY.
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
SCOPE="global"
UNINSTALL=0
ASSUME_YES=0
DRY_RUN=0

# Granular opt-in sets (comma-separated lists, normalized below).
# When empty + MODE=core, no plugins install. --minimum / --full populate these.
WANT_TOOLS=""
WANT_SKILLS=""
WANT_CLIS=""
WANT_PLUGINS=""

# Args
for arg in "$@"; do
  case "$arg" in
    --minimum|--min) MODE="minimum" ;;
    --full)          MODE="full" ;;
    --core|--merge)  MODE="core" ;;
    --force)         FORCE=1 ;;
    --uninstall)     UNINSTALL=1 ;;
    --yes|-y)        ASSUME_YES=1 ;;
    --dry-run)       DRY_RUN=1 ;;
    --target=*)      CLI_TARGET="${arg#--target=}" ;;
    --scope=*)       SCOPE="${arg#--scope=}" ;;
    --with-tools=*)   WANT_TOOLS="${arg#--with-tools=}" ;;
    --with-skills=*)  WANT_SKILLS="${arg#--with-skills=}" ;;
    --with-clis=*)    WANT_CLIS="${arg#--with-clis=}" ;;
    --with-plugins=*) WANT_PLUGINS="${arg#--with-plugins=}" ;;
    -h|--help)
      sed -n '2,46p' "$0"
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

case "$SCOPE" in
  global|project) ;;
  *)
    echo "Unknown --scope value: $SCOPE (expected global|project)" >&2
    exit 1 ;;
esac

# Bundle expansion (only fills what user did NOT pass explicitly — explicit wins).
# --minimum  → tools=gitnexus,mempalace + skills=ui-ux-pro-max
# --full     → tools=gitnexus,mempalace,rtk + skills=ui-ux-pro-max,caveman
#              clis=codex,gemini + plugins=openai-codex
case "$MODE" in
  minimum)
    [ -z "$WANT_TOOLS"  ] && WANT_TOOLS="gitnexus,mempalace"
    [ -z "$WANT_SKILLS" ] && WANT_SKILLS="ui-ux-pro-max"
    ;;
  full)
    [ -z "$WANT_TOOLS"   ] && WANT_TOOLS="gitnexus,mempalace,rtk"
    [ -z "$WANT_SKILLS"  ] && WANT_SKILLS="ui-ux-pro-max,caveman"
    [ -z "$WANT_CLIS"    ] && WANT_CLIS="codex,gemini"
    [ -z "$WANT_PLUGINS" ] && WANT_PLUGINS="openai-codex"
    ;;
esac

# Resolve install destination per CLI target. ROLEPOD_TARGET (env) wins for
# all targets when set, so dry-run installs into a tempdir keep working.
# Scope-aware:
#   global  → ~/.<cli>      (Claude: ~/.claude, Codex: ~/.codex, Gemini: ~/.gemini)
#   project → $PWD          (Claude: $PWD/.claude, Codex/Gemini: $PWD itself —
#                            their managed-block doc lives at $PWD/AGENTS.md or
#                            $PWD/GEMINI.md, NOT under a hidden dotdir)
default_target_path_for() {
  if [ "$SCOPE" = "project" ]; then
    case "$1" in
      claude) echo "$PWD/.claude" ;;
      codex)  echo "$PWD" ;;
      gemini) echo "$PWD" ;;
      *)      echo "$PWD" ;;
    esac
    return
  fi
  case "$1" in
    claude) echo "$HOME/.claude" ;;
    codex)  echo "$HOME/.codex" ;;
    gemini) echo "$HOME/.gemini" ;;
    *)      echo "$HOME/.$1" ;;
  esac
}

# Resolve where a given CLI's rolepod files actually land for the current
# invocation. Precedence (highest first):
#   1. ROLEPOD_<CLI>_TARGET   per-CLI override
#   2. ROLEPOD_TARGET + --target=all → $ROLEPOD_TARGET/<cli>/  (subdir layout)
#   3. ROLEPOD_TARGET (single target only) → use as-is
#   4. default_target_path_for <cli> (scope-aware)
# Keeps --target=all + ROLEPOD_TARGET consistent: all 3 CLIs land under one root.
# ROLEPOD_TARGET / per-CLI overrides win regardless of scope (CI temp dirs).
resolve_target_for() {
  local cli="$1"
  local override
  case "$cli" in
    claude) override="${ROLEPOD_CLAUDE_TARGET:-}" ;;
    codex)  override="${ROLEPOD_CODEX_TARGET:-}" ;;
    gemini) override="${ROLEPOD_GEMINI_TARGET:-}" ;;
    *)      override="" ;;
  esac
  if [ -n "$override" ]; then
    echo "$override"; return 0
  fi
  if [ "$CLI_TARGET" = "all" ] && [ -n "${ROLEPOD_TARGET:-}" ]; then
    echo "$ROLEPOD_TARGET/$cli"; return 0
  fi
  if [ -n "${ROLEPOD_TARGET:-}" ]; then
    echo "$ROLEPOD_TARGET"; return 0
  fi
  default_target_path_for "$cli"
}

# Per-CLI plugin/extension dir (where 3rd-party skill bundles land).
# Claude:  ~/.claude/plugins/<name>/
# Codex:   ~/.codex/plugins/<name>/
# Gemini:  ~/.gemini/extensions/<name>/
plugin_dir_for() {
  case "$1" in
    claude) echo "$(default_target_path_for claude)/plugins" ;;
    codex)  echo "$(default_target_path_for codex)/plugins" ;;
    gemini) echo "$(default_target_path_for gemini)/extensions" ;;
    *)      echo "" ;;
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
dry()  { echo "${YELLOW}[DRY-RUN]${NC} would: $*"; }

# Generic helpers — defined early so install/uninstall blocks below can use them.
have_cmd() { command -v "$1" >/dev/null 2>&1; }
have_dir() { [ -d "$1" ]; }

# can_prompt: 0 = no TTY (don't prompt), 1 = stdin is a TTY, 2 = /dev/tty usable.
# Some systems (macOS sandbox / CI runners / curl-piped install) have /dev/tty
# as a device node but opening fails ("Device not configured"). `[ -r /dev/tty ]`
# returns 0 for the path but the redirect crashes — must actually open-test it.
can_prompt() {
  if [ -t 0 ]; then
    return 1
  elif [ -e /dev/tty ] && (exec 9<>/dev/tty) 2>/dev/null; then
    return 2
  fi
  return 0
}

# Membership test for comma-separated wanted-set strings.
# wants "gitnexus" "$WANT_TOOLS" → 0 if listed, 1 otherwise.
wants() {
  local needle="$1" haystack="$2"
  case ",$haystack," in
    *",$needle,"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Run a destructive shell command, or print a [DRY-RUN] preview. Used to gate
# every cp/mkdir/rm/chmod/git clone/npm/pip/cargo so dry-run never writes.
do_or_dry() {
  local desc="$1"; shift
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "$desc"
    return 0
  fi
  "$@"
}

# selective_backup <src> <backup> <path1> [path2 ...]
#
# Back up ONLY rolepod-managed paths from <src> into <backup>, skipping bloat
# dirs that aren't part of rolepod's workflow (session transcripts, plugin
# caches, file-history, shell-snapshots, agent-memory, etc.). Original full
# `cp -R ~/.claude ...` could exceed 1.8GB on active users; this stays small
# (typically <50MB) and only protects what install.sh might overwrite.
#
# Honors $DRY_RUN. Missing source paths are silently skipped (not all paths
# exist on every install — e.g. plugins/rolepod on a fresh Codex setup).
selective_backup() {
  local src="$1"; shift
  local backup="$1"; shift
  # Remaining args = include list (paths relative to src).

  if [ "$DRY_RUN" -eq 1 ]; then
    dry "selective backup: $src → $backup (rolepod-scoped — excludes session history / plugin cache)"
    for path in "$@"; do
      dry "  include: $path"
    done
    return 0
  fi

  mkdir -p "$backup"
  for path in "$@"; do
    if [ -e "$src/$path" ]; then
      local parent
      parent="$(dirname "$path")"
      if [ "$parent" != "." ]; then
        mkdir -p "$backup/$parent"
      fi
      cp -R "$src/$path" "$backup/$path" 2>/dev/null || true
    fi
  done

  local size
  size=$(du -sh "$backup" 2>/dev/null | awk '{print $1}')
  warn "Backup created: $backup (${size:-?} — rolepod-scoped, excludes session history / plugin cache)"
}

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
# Honors $DRY_RUN — emits a preview line and returns.
update_managed_block() {
  local target_file="$1"
  local source_file="$2"
  [ -f "$source_file" ] || { warn "managed block: source $source_file missing"; return 1; }

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ ! -e "$target_file" ] || [ ! -s "$target_file" ]; then
      dry "create $target_file with rolepod managed block from $(basename "$source_file")"
    elif grep -qF "$ROLEPOD_BLOCK_START" "$target_file" 2>/dev/null; then
      dry "replace rolepod managed block in $target_file"
    else
      dry "append rolepod managed block to $target_file (preserves existing content)"
    fi
    return 0
  fi

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
    # Migration: if surviving (non-block) content contains legacy rolepod
    # H1, it's stale content from a pre-markers install — wipe it.
    if grep -qE '^# (Claude Code|Codex|Gemini) — Core Rules' "$tmp"; then
      warn "Detected legacy rolepod content outside managed block in $target_file. Wiping legacy — backup at ${target_file}.legacy-$(date +%Y%m%d-%H%M%S)"
      cp "$target_file" "${target_file}.legacy-$(date +%Y%m%d-%H%M%S)"
      : > "$tmp"
    fi
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
      [ -s "$target_file" ] && printf '\n'
      printf '%s\n' "$ROLEPOD_BLOCK_START"
      cat "$source_file"
      printf '\n%s\n' "$ROLEPOD_BLOCK_END"
    } >> "$target_file"
    return 0
  fi

  # No markers → check for legacy rolepod content (unmigrated install from
  # before managed-block markers existed). Signature: H1 "Claude Code — Core
  # Rules" / "Codex — Core Rules" / "Gemini — Core Rules" appears in file.
  # If matched, wipe legacy content + write fresh marker-wrapped block.
  # Otherwise treat as user's own content → append marker-wrapped block after.
  if grep -qE '^# (Claude Code|Codex|Gemini) — Core Rules' "$target_file"; then
    warn "Detected legacy rolepod content in $target_file (no markers). Migrating to managed block — backup at ${target_file}.legacy-$(date +%Y%m%d-%H%M%S)"
    cp "$target_file" "${target_file}.legacy-$(date +%Y%m%d-%H%M%S)"
    {
      printf '%s\n' "$ROLEPOD_BLOCK_START"
      cat "$source_file"
      printf '\n%s\n' "$ROLEPOD_BLOCK_END"
    } > "$target_file"
    return 0
  fi

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
# Honors $DRY_RUN.
remove_managed_block() {
  local target_file="$1"
  [ -f "$target_file" ] || return 0
  if ! grep -qF "$ROLEPOD_BLOCK_START" "$target_file"; then
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "strip rolepod managed block from $target_file"
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
echo "  source:  $REPO_DIR"
echo "  cli:     $CLI_TARGET"
echo "  scope:   $SCOPE"
echo "  mode:    $MODE"
echo "  force:   $FORCE"
echo "  dry-run: $DRY_RUN"
[ -n "$WANT_TOOLS"   ] && echo "  tools:   $WANT_TOOLS"
[ -n "$WANT_SKILLS"  ] && echo "  skills:  $WANT_SKILLS"
[ -n "$WANT_CLIS"    ] && echo "  clis:    $WANT_CLIS"
[ -n "$WANT_PLUGINS" ] && echo "  plugins: $WANT_PLUGINS"
echo ""

# ─── Sanity check source ────────────────────────────────────────────────
for f in CHEATSHEET.md core/agents core/rules hooks core/skills commands plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json build/render.sh adapters/claude/CLAUDE.md.tmpl; do
  [ -e "$REPO_DIR/$f" ] || fail "missing $f in $REPO_DIR — run from rolepod repo"
done

# Codex/Gemini adapter sanity (only required if those targets selected).
# Phase 2.3: each CLI ships as a native plugin/extension — no wrapper scripts.
case "$CLI_TARGET" in
  codex|all)
    [ -e "$REPO_DIR/adapters/codex/AGENTS.md.tmpl" ]                                       || fail "missing adapters/codex/AGENTS.md.tmpl"
    [ -e "$REPO_DIR/adapters/codex/.agents/plugins/marketplace.json" ]                     || fail "missing adapters/codex/.agents/plugins/marketplace.json"
    [ -e "$REPO_DIR/adapters/codex/plugins/rolepod/.codex-plugin/plugin.json" ]            || fail "missing adapters/codex/plugins/rolepod/.codex-plugin/plugin.json"
    [ -d "$REPO_DIR/adapters/codex/plugins/rolepod/agents" ]                               || fail "missing adapters/codex/plugins/rolepod/agents/"
    [ -e "$REPO_DIR/adapters/codex/plugins/rolepod/hooks/hooks.json" ]                     || fail "missing adapters/codex/plugins/rolepod/hooks/hooks.json"
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
  echo "  cli:     $CLI_TARGET"
  echo "  dry-run: $DRY_RUN"
  echo ""

  # Discover what we'd remove so the user can decide.
  uninstall_claude=0; uninstall_codex=0; uninstall_gemini=0
  case "$CLI_TARGET" in claude|all) uninstall_claude=1 ;; esac
  case "$CLI_TARGET" in codex|all)  uninstall_codex=1 ;; esac
  case "$CLI_TARGET" in gemini|all) uninstall_gemini=1 ;; esac

  C_TARGET="$(resolve_target_for claude)"
  X_TARGET="$(resolve_target_for codex)"
  G_TARGET="$(resolve_target_for gemini)"

  echo "About to remove rolepod from:"
  [ "$uninstall_claude" -eq 1 ] && echo "  Claude → $C_TARGET (agents, skills, rules, hooks, managed CLAUDE.md block)"
  [ "$uninstall_codex"  -eq 1 ] && echo "  Codex  → rolepod marketplace + [plugins.\"rolepod@rolepod\"] in $X_TARGET/config.toml + managed AGENTS.md block"
  [ "$uninstall_gemini" -eq 1 ] && echo "  Gemini → $G_TARGET/extensions/rolepod, managed GEMINI.md block"
  echo ""

  if [ "$ASSUME_YES" -ne 1 ] && [ "$DRY_RUN" -ne 1 ]; then
    can_prompt; cp_mode=$?
    if [ "$cp_mode" -eq 0 ]; then
      echo "Aborted. Re-run with --yes in non-interactive mode."
      exit 0
    fi
    if [ "$cp_mode" -eq 1 ]; then
      printf "Continue? [y/N] "
      read -r reply || reply=""
    else
      printf "Continue? [y/N] " > /dev/tty
      read -r reply < /dev/tty || reply=""
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
    # Recurse subfolders (always-on/, code/, test/) — store paths relative to core/rules/
    while IFS= read -r f; do
      RULE_NAMES+=("${f#"$REPO_DIR/core/rules/"}")
    done < <(find "$REPO_DIR/core/rules" -name '*.md' 2>/dev/null)
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
    for n in "${AGENT_NAMES[@]}";   do do_or_dry "rm -f $C_TARGET/agents/$n"   rm -f "$C_TARGET/agents/$n"; done
    for n in "${RULE_NAMES[@]}";    do do_or_dry "rm -f $C_TARGET/rules/$n"    rm -f "$C_TARGET/rules/$n"; done
    # Prune empty rules subfolders left after file removal
    if [ "$DRY_RUN" -eq 0 ]; then
      find "$C_TARGET/rules" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    fi
    for n in "${COMMAND_NAMES[@]}"; do do_or_dry "rm -f $C_TARGET/commands/$n" rm -f "$C_TARGET/commands/$n"; done
    for n in "${HOOK_NAMES[@]}";    do do_or_dry "rm -f $C_TARGET/hooks/$n"    rm -f "$C_TARGET/hooks/$n"; done
    for n in "${SKILL_NAMES[@]}";   do do_or_dry "rm -rf $C_TARGET/skills/$n"  rm -rf "$C_TARGET/skills/$n"; done
    do_or_dry "rm -f $C_TARGET/CHEATSHEET.md"               rm -f "$C_TARGET/CHEATSHEET.md"
    do_or_dry "rm -f $C_TARGET/.claude-plugin/plugin.json"  rm -f "$C_TARGET/.claude-plugin/plugin.json"
    # Empty dirs cleanup (rmdir; ignore failure if non-empty)
    if [ "$DRY_RUN" -eq 1 ]; then
      dry "rmdir empty agents/rules/commands/hooks/skills/.claude-plugin under $C_TARGET (if empty)"
    else
      rmdir "$C_TARGET/agents" "$C_TARGET/rules" "$C_TARGET/commands" "$C_TARGET/hooks" "$C_TARGET/skills" "$C_TARGET/.claude-plugin" 2>/dev/null || true
    fi

    # Strip rolepod hook entries from settings.json (keep user's other config).
    SETTINGS_FILE="$C_TARGET/settings.json"
    if [ -f "$SETTINGS_FILE" ]; then
      step "Stripping rolepod hook entries from $SETTINGS_FILE"
      if [ "$DRY_RUN" -eq 1 ]; then
        dry "strip rolepod hook entries (paths under $C_TARGET/hooks) from $SETTINGS_FILE"
      elif command -v python3 >/dev/null 2>&1; then
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
    if [ "$SCOPE" = "project" ]; then
      # Project uninstall: only strip the managed AGENTS.md block at $PWD.
      step "Stripping rolepod block from $X_TARGET/AGENTS.md"
      remove_managed_block "$X_TARGET/AGENTS.md"
      ok "Codex project rolepod removed (global config untouched)"
      uninstall_codex=0   # signal to skip global removal block below
    fi
  fi

  if [ "$uninstall_codex" -eq 1 ]; then
    X_CONFIG="$X_TARGET/config.toml"
    # Same temp-target detection as install path: only touch global codex
    # commands when uninstalling against the real ~/.codex (refs #3).
    X_REAL_HOME="$HOME/.codex"
    X_TARGET_RESOLVED="$(cd "$X_TARGET" 2>/dev/null && pwd -P || echo "$X_TARGET")"
    X_REAL_RESOLVED="$(cd "$X_REAL_HOME" 2>/dev/null && pwd -P || echo "$X_REAL_HOME")"
    X_IS_TEMP_TARGET=0
    [ "$X_TARGET_RESOLVED" != "$X_REAL_RESOLVED" ] && X_IS_TEMP_TARGET=1

    if have_cmd codex && [ "$X_IS_TEMP_TARGET" -eq 0 ]; then
      step "Removing rolepod marketplace from Codex"
      if [ "$DRY_RUN" -eq 1 ]; then
        dry "codex plugin marketplace remove rolepod"
      else
        # Backup config.toml before mutation (reversible).
        if [ -f "$X_CONFIG" ]; then
          STAMP=$(date +%Y%m%d-%H%M%S)
          cp "$X_CONFIG" "$X_CONFIG.rolepod-bak.$STAMP" 2>/dev/null || true
        fi
        codex plugin marketplace remove rolepod >/dev/null 2>&1 || true
      fi
    elif [ "$X_IS_TEMP_TARGET" -eq 1 ]; then
      warn "ROLEPOD_TARGET set — skipping global marketplace removal (no global state was set during temp-target install)"
    else
      warn "codex binary not found — skipping marketplace removal"
    fi

    # Strip [plugins."rolepod@rolepod"] block from config.toml (codex remove
    # handles [marketplaces.rolepod], but the plugin enable line is ours).
    if [ -f "$X_CONFIG" ] && [ "$DRY_RUN" -eq 0 ]; then
      step "Stripping [plugins.\"rolepod@rolepod\"] from $X_CONFIG"
      if have_cmd python3; then
        python3 - "$X_CONFIG" <<'PY' || warn "python3 strip failed — remove [plugins.\"rolepod@rolepod\"] manually"
import sys, re
path = sys.argv[1]
with open(path) as f:
    text = f.read()
# Match `[plugins."rolepod@rolepod"]` plus following key=value lines until next
# [section] or EOF. Preserves all other tables.
pattern = re.compile(
    r'(?:^|\n)\[plugins\."rolepod@rolepod"\][^\[]*',
    re.MULTILINE,
)
new = pattern.sub('\n', text)
# Collapse 3+ blank lines to 2.
new = re.sub(r'\n{3,}', '\n\n', new)
with open(path, "w") as f:
    f.write(new)
PY
      else
        warn "python3 not found — strip [plugins.\"rolepod@rolepod\"] from $X_CONFIG manually"
      fi
    fi

    # Legacy cleanup: remove the old plugin tree if a previous install put
    # files at $X_TARGET/plugins/rolepod/. Newer installs leave that empty.
    if [ -d "$X_TARGET/plugins/rolepod" ]; then
      step "Removing legacy plugin tree at $X_TARGET/plugins/rolepod"
      do_or_dry "rm -rf $X_TARGET/plugins/rolepod" rm -rf "$X_TARGET/plugins/rolepod"
      if [ "$DRY_RUN" -eq 0 ]; then
        rmdir "$X_TARGET/plugins" 2>/dev/null || true
      fi
    fi

    step "Stripping rolepod block from $X_TARGET/AGENTS.md"
    remove_managed_block "$X_TARGET/AGENTS.md"
    ok "Codex rolepod removed"
  fi

  if [ "$uninstall_gemini" -eq 1 ]; then
    if [ "$SCOPE" = "project" ]; then
      step "Stripping rolepod block from $G_TARGET/GEMINI.md"
      remove_managed_block "$G_TARGET/GEMINI.md"
      ok "Gemini project rolepod removed (global extension untouched)"
    else
      step "Removing Gemini rolepod extension in $G_TARGET/extensions/rolepod"
      do_or_dry "rm -rf $G_TARGET/extensions/rolepod" rm -rf "$G_TARGET/extensions/rolepod"
      if [ "$DRY_RUN" -eq 1 ]; then
        dry "rmdir $G_TARGET/extensions (if empty)"
      else
        rmdir "$G_TARGET/extensions" 2>/dev/null || true
      fi
      step "Stripping rolepod block from $G_TARGET/GEMINI.md"
      remove_managed_block "$G_TARGET/GEMINI.md"
      ok "Gemini rolepod removed"
    fi
  fi

  echo ""
  echo "${BOLD}Uninstall complete.${NC}"
  exit 0
fi

# ─── Render all required entry docs up front ────────────────────────────
# render.sh is read-only (writes to build/rendered/ inside the repo, not the
# user's home). It's safe to run during dry-run so subsequent verification
# steps can still inspect rendered/.
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
  TARGET="$(resolve_target_for claude)"
  PLUGINS_DIR="$TARGET/plugins"
  echo ""
  echo "${BOLD}─── Installing for Claude Code ───${NC}"
  echo "  target: $TARGET"

  RENDERED_CLAUDE_MD="$REPO_DIR/build/rendered/claude/CLAUDE.md"
  [ -f "$RENDERED_CLAUDE_MD" ] || fail "expected $RENDERED_CLAUDE_MD after render"

  # Backup if --force on existing — rolepod-scoped only.
  # Excludes: projects/ (session history), plugins/cache/, plugins/marketplaces/,
  # file-history/, shell-snapshots/, session-env/, scheduled-tasks/, cache/,
  # agent-memory/, backups/, teams/ — none are rolepod-managed.
  if [ "$FORCE" -eq 1 ] && [ -d "$TARGET" ]; then
    STAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP="${TARGET}.backup-$STAMP"
    warn "Backing up rolepod-managed paths in $TARGET → $BACKUP"
    selective_backup "$TARGET" "$BACKUP" \
      CLAUDE.md \
      CHEATSHEET.md \
      README.md \
      agents \
      rules \
      hooks \
      skills \
      commands \
      .claude-plugin \
      settings.json
  fi

  step "Creating directory structure"
  do_or_dry "mkdir -p $TARGET/{agents,rules,hooks,skills,commands,.claude-plugin,plugins}" \
    mkdir -p "$TARGET/agents" "$TARGET/rules" "$TARGET/hooks" "$TARGET/skills" \
             "$TARGET/commands" "$TARGET/.claude-plugin" "$TARGET/plugins"

  if [ "$FORCE" -eq 1 ]; then CP_FLAG=""; else CP_FLAG="-n"; fi

  step "Updating CLAUDE.md (managed block) + CHEATSHEET.md"
  update_managed_block "$TARGET/CLAUDE.md" "$RENDERED_CLAUDE_MD"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "cp $CP_FLAG $REPO_DIR/CHEATSHEET.md → $TARGET/CHEATSHEET.md"
  else
    cp $CP_FLAG "$REPO_DIR/CHEATSHEET.md" "$TARGET/" 2>/dev/null || true
  fi

  step "Copying agents (18 from rendered/) + rules (recursive, subfolders preserved) + commands"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "cp $CP_FLAG $REPO_DIR/build/rendered/claude/agents/*.md → $TARGET/agents/"
    dry "clean stale legacy flat-path rolepod rules from $TARGET/rules/"
    dry "cp -R $REPO_DIR/core/rules/. → $TARGET/rules/  (preserves always-on/ code/ test/ subdirs)"
    dry "cp $CP_FLAG $REPO_DIR/commands/*.md → $TARGET/commands/"
  else
    cp $CP_FLAG "$REPO_DIR"/build/rendered/claude/agents/*.md "$TARGET/agents/" 2>/dev/null || true
    # Clean stale legacy flat-path rolepod rules (pre-subfolder layout).
    # Known basenames that USED to live at rules/ root before restructure.
    # Files now live in always-on/, code/, test/ subdirs OR converted to skills.
    for legacy in pre-merge-gate.md reviewer-flow.md advisor.md \
                  session-management.md triage-deep.md new-project.md \
                  team-org.md verification.md \
                  communication.md verify-first.md agent-protocol.md \
                  code-quality.md code-intel.md code-intel-workflow.md \
                  testing.md; do
      rm -f "$TARGET/rules/$legacy"
    done
    # Recursive copy: preserves always-on/, code/, test/ subfolders
    cp -R "$REPO_DIR"/core/rules/. "$TARGET/rules/" 2>/dev/null || true
    cp $CP_FLAG "$REPO_DIR"/commands/*.md "$TARGET/commands/" 2>/dev/null || true
  fi

  step "Copying hooks (4) and marking executable"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "cp $CP_FLAG $REPO_DIR/hooks/*.sh → $TARGET/hooks/  (chmod +x)"
  else
    cp $CP_FLAG "$REPO_DIR"/hooks/*.sh "$TARGET/hooks/" 2>/dev/null || true
    chmod +x "$TARGET"/hooks/*.sh 2>/dev/null || true
  fi

  # Count skills locally — SKILL_NAMES is only populated in uninstall flow.
  _skill_count=$(find "$REPO_DIR/core/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  step "Copying bundled skills ($_skill_count)"
  for skill_dir in "$REPO_DIR"/core/skills/*/; do
    name=$(basename "$skill_dir")
    if [ "$FORCE" -eq 1 ] || [ ! -e "$TARGET/skills/$name" ]; then
      do_or_dry "cp -R $REPO_DIR/core/skills/$name → $TARGET/skills/" \
        cp -R "$REPO_DIR/core/skills/$name" "$TARGET/skills/" 2>/dev/null || true
    fi
  done

  step "Copying plugin manifest"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "cp $CP_FLAG $REPO_DIR/plugin/.claude-plugin/plugin.json → $TARGET/.claude-plugin/"
  else
    cp $CP_FLAG "$REPO_DIR/plugin/.claude-plugin/plugin.json" "$TARGET/.claude-plugin/" 2>/dev/null || true
  fi

# ─── Register hooks in settings.json ────────────────────────────────────
# Claude Code reads hooks from ~/.claude/settings.json — manifest.json is
# descriptive metadata only. Hooks shipped to ~/.claude/hooks/ do NOT auto-fire
# unless registered here. This block is idempotent: existing entries are
# preserved, rolepod entries are upserted by command path.

SETTINGS_FILE="$TARGET/settings.json"
HOOK_DIR="$TARGET/hooks"

step "Registering rolepod hooks in $SETTINGS_FILE"

if [ "$DRY_RUN" -eq 1 ]; then
  dry "register hooks in $SETTINGS_FILE:"
  dry "  SessionStart  startup|resume      → $HOOK_DIR/project-context-loader.sh (timeout 5)"
  dry "  PreToolUse    Edit|Write|MultiEdit → $HOOK_DIR/gate-reminder.sh        (timeout 3)"
  dry "  PreToolUse    Bash                 → $HOOK_DIR/precommit-gate.sh      (timeout 5)"
  dry "  PostToolUse   Edit|Write           → $HOOK_DIR/verify-reminder.sh      (timeout 3)"
  dry "  PostToolUse   Bash                 → $HOOK_DIR/post-ship-detect.sh     (timeout 5)"
  REGISTER_OK=1
else

# Create empty settings.json if missing
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

REGISTER_OK=0
if command -v jq >/dev/null 2>&1; then
  TMP_FILE=$(mktemp)
  if jq \
    --arg ctx "$HOOK_DIR/project-context-loader.sh" \
    --arg gate "$HOOK_DIR/gate-reminder.sh" \
    --arg pre "$HOOK_DIR/precommit-gate.sh" \
    --arg ver "$HOOK_DIR/verify-reminder.sh" \
    --arg shp "$HOOK_DIR/post-ship-detect.sh" '
    # Helper: strip command from ALL matcher groups in event (handles
    # matcher-rename across versions, e.g. "startup" → "startup|resume").
    # Returns array with cmd removed everywhere, empty groups dropped.
    def strip_cmd($arr; $cmd):
      ($arr // []) | map(
        .hooks = (.hooks // [] | map(select(.command != $cmd)))
      ) | map(select(.hooks | length > 0));

    # Helper: ensure matcher group exists, then add command to it.
    def ensure_group($arr; $matcher):
      if ($arr | map(select(.matcher == $matcher)) | length) > 0 then $arr
      else $arr + [{"matcher": $matcher, "hooks": []}] end;

    # Cross-group dedup upsert: strip cmd anywhere in event, then add to
    # canonical matcher group exactly once.
    def upsert_cmd($arr; $matcher; $cmd; $timeout):
      (strip_cmd($arr; $cmd) | ensure_group(.; $matcher)) | map(
        if .matcher == $matcher then
          .hooks += [{"type": "command", "command": $cmd, "timeout": $timeout}]
        else . end
      );

    .hooks = (.hooks // {})
    | .hooks.SessionStart = upsert_cmd((.hooks.SessionStart // []); "startup|resume"; $ctx; 5)
    | .hooks.PreToolUse = upsert_cmd((.hooks.PreToolUse // []); "Edit|Write|MultiEdit"; $gate; 3)
    | .hooks.PreToolUse = upsert_cmd((.hooks.PreToolUse // []); "Bash"; $pre; 5)
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
    # Strip cmd from ALL groups in event (handles matcher-rename across
    # versions, e.g. "startup" → "startup|resume"). Drop now-empty groups.
    for g in arr:
        g["hooks"] = [h for h in g.get("hooks", []) if h.get("command") != cmd]
    arr[:] = [g for g in arr if g.get("hooks")]
    # Find or create canonical matcher group, then add cmd exactly once.
    group = next((g for g in arr if g.get("matcher") == matcher), None)
    if group is None:
        group = {"matcher": matcher, "hooks": []}
        arr.append(group)
    group.setdefault("hooks", []).append(
        {"type": "command", "command": cmd, "timeout": timeout}
    )

upsert("SessionStart", "startup|resume", os.path.join(hook_dir, "project-context-loader.sh"), 5)
upsert("PreToolUse", "Edit|Write|MultiEdit", os.path.join(hook_dir, "gate-reminder.sh"), 3)
upsert("PreToolUse", "Bash", os.path.join(hook_dir, "precommit-gate.sh"), 5)
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
  ok "Hooks registered in settings.json (SessionStart + 2x PreToolUse + 2x PostToolUse)"
else
  warn "Could not auto-register hooks — install jq or python3, or edit $SETTINGS_FILE manually"
  warn "  Hooks shipped: project-context-loader.sh (SessionStart), gate-reminder.sh (PreToolUse Edit|Write|MultiEdit), precommit-gate.sh (PreToolUse Bash), verify-reminder.sh (PostToolUse Edit|Write), post-ship-detect.sh (PostToolUse Bash)"
fi

fi  # end DRY_RUN gate around settings.json registration

# ─── Verify Claude rolepod core ─────────────────────────────────────────
# Skip in dry-run — files we'd verify weren't actually written.
if [ "$DRY_RUN" -eq 0 ]; then
  step "Verifying rolepod core"
  for required in \
    CLAUDE.md CHEATSHEET.md \
    agents/qa-tester.md agents/system-architect.md \
    rules/INDEX.md rules/always-on/agent-protocol.md rules/always-on/verify-first.md rules/code/code-quality.md rules/test/testing.md \
    hooks/verify-reminder.sh hooks/project-context-loader.sh hooks/gate-reminder.sh hooks/precommit-gate.sh \
    skills/zoom-out/SKILL.md skills/anti-spaghetti/SKILL.md commands/careful.md \
    .claude-plugin/plugin.json
  do
    [ -e "$TARGET/$required" ] || fail "verification failed — $TARGET/$required missing"
  done
  ok "rolepod core installed → $TARGET"
else
  skip "verification skipped (dry-run)"
fi
fi  # end claude_selected

# ─── install_codex — Codex CLI path (~/.codex/) ────────────────────────
# Phase 2.4: install as a Codex marketplace consumable so the native plugin
# loader actually wires up agents/skills/hooks (not just AGENTS.md text).
# Flow:
#   1. Render to build/rendered/codex/ (marketplace shape).
#   2. `codex plugin marketplace add <rendered-dir>` — registers the marketplace.
#   3. Set `[plugins."rolepod@rolepod"] enabled = true` in ~/.codex/config.toml.
#   4. Update managed block in ~/.codex/AGENTS.md (Tier 1 always-on rules).
# Fallback when codex binary missing: file-copy AGENTS.md only + warn.
#
# Temp-target safety (refs #3): Codex CLI has no CODEX_HOME / --config-home —
# `codex plugin marketplace add` always writes to ~/.codex/config.toml. When
# the resolved CODEX_TARGET points away from $HOME/.codex (i.e. user set
# ROLEPOD_TARGET or ROLEPOD_CODEX_TARGET for an isolated test), we MUST skip
# the global codex commands or we mutate the user's real config. In that mode
# we still write filesystem artifacts (AGENTS.md, rendered tree) so static
# checks pass, then warn the user that the install is partial.
if codex_selected; then
  CODEX_TARGET="$(resolve_target_for codex)"
  CODEX_REAL_HOME="$HOME/.codex"
  # Marketplace registration is global — skip when target diverges from the
  # real Codex config home. Detect via path comparison (resolve symlinks where
  # available so /tmp/foo vs /private/tmp/foo on macOS still matches).
  CODEX_TARGET_RESOLVED="$(cd "$CODEX_TARGET" 2>/dev/null && pwd -P || echo "$CODEX_TARGET")"
  CODEX_REAL_RESOLVED="$(cd "$CODEX_REAL_HOME" 2>/dev/null && pwd -P || echo "$CODEX_REAL_HOME")"
  CODEX_IS_TEMP_TARGET=0
  if [ "$CODEX_TARGET_RESOLVED" != "$CODEX_REAL_RESOLVED" ]; then
    CODEX_IS_TEMP_TARGET=1
  fi
  CODEX_CONFIG="$CODEX_TARGET/config.toml"
  RENDERED_CODEX_DIR="$REPO_DIR/build/rendered/codex"
  RENDERED_AGENTS_MD="$RENDERED_CODEX_DIR/AGENTS.md"
  echo ""
  echo "${BOLD}─── Installing for Codex CLI ───${NC}"
  echo "  target:                $CODEX_TARGET"
  if [ "$SCOPE" = "project" ]; then
    echo "  mode:                  project-scope (managed AGENTS.md only — global config NOT mutated)"
  else
    echo "  marketplace source:    $RENDERED_CODEX_DIR"
    if [ "$CODEX_IS_TEMP_TARGET" -eq 1 ]; then
      echo "  mode:                  temp-target (filesystem only — global config NOT mutated)"
    fi
  fi

  if [ "$SCOPE" = "project" ]; then
    # Project scope: write only $PWD/AGENTS.md managed block. Codex plugins are
    # global-only (marketplace registration + ~/.codex/config.toml), so per-project
    # plugin install is impossible — warn so user knows the tradeoff.
    warn "Codex plugins are global only. Per-project install writes AGENTS.md only."
    warn "  For full plugin install, run --scope=global separately."
    step "Updating AGENTS.md (managed block) → $CODEX_TARGET/AGENTS.md"
    update_managed_block "$CODEX_TARGET/AGENTS.md" "$RENDERED_AGENTS_MD"
    if [ "$DRY_RUN" -eq 0 ]; then
      step "Verifying Codex project install"
      [ -e "$CODEX_TARGET/AGENTS.md" ] || fail "Codex verification failed — $CODEX_TARGET/AGENTS.md missing"
      ok "AGENTS.md → $CODEX_TARGET/AGENTS.md"
    else
      skip "Codex verification skipped (dry-run)"
    fi
    # Skip the rest of the codex install block — no marketplace, no plugin tree.
    CODEX_PROJECT_DONE=1
  else
    CODEX_PROJECT_DONE=0
  fi
  if [ "${CODEX_PROJECT_DONE:-0}" -eq 0 ]; then

  [ -f "$RENDERED_AGENTS_MD" ]                                                  || fail "expected $RENDERED_AGENTS_MD after render"
  [ -f "$RENDERED_CODEX_DIR/.agents/plugins/marketplace.json" ]                 || fail "expected marketplace manifest after render"
  [ -d "$RENDERED_CODEX_DIR/plugins/rolepod/.codex-plugin" ]                    || fail "expected plugins/rolepod/.codex-plugin/ after render"
  [ -d "$RENDERED_CODEX_DIR/plugins/rolepod/agents" ]                           || fail "expected plugins/rolepod/agents/ after render"
  [ -d "$RENDERED_CODEX_DIR/plugins/rolepod/hooks" ]                            || fail "expected plugins/rolepod/hooks/ after render"
  [ -d "$RENDERED_CODEX_DIR/plugins/rolepod/skills" ]                           || fail "expected plugins/rolepod/skills/ after render"

  # Backup if --force on existing — rolepod-scoped only.
  # Excludes: log/, .tmp/, history/, sessions/ — Codex runtime data, not rolepod-managed.
  # config.toml has its own .rolepod-bak.<stamp> backup later (see below).
  if [ "$FORCE" -eq 1 ] && [ -d "$CODEX_TARGET" ]; then
    STAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP="${CODEX_TARGET}.backup-$STAMP"
    warn "Backing up rolepod-managed paths in $CODEX_TARGET → $BACKUP"
    selective_backup "$CODEX_TARGET" "$BACKUP" \
      AGENTS.md \
      config.toml \
      plugins/rolepod \
      .agents
  fi

  # Mark hook scripts executable in the rendered tree (codex resolves source from this path).
  step "Marking hook scripts executable"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "chmod +x $RENDERED_CODEX_DIR/plugins/rolepod/hooks/*.sh"
  else
    chmod +x "$RENDERED_CODEX_DIR/plugins/rolepod/hooks"/*.sh 2>/dev/null || true
  fi

  if have_cmd codex && [ "$CODEX_IS_TEMP_TARGET" -eq 0 ]; then
    # Real install path — codex commands write to $HOME/.codex/config.toml.
    # Backup config.toml before any modification (reversible).
    if [ -f "$CODEX_CONFIG" ] && [ "$DRY_RUN" -eq 0 ]; then
      STAMP=$(date +%Y%m%d-%H%M%S)
      cp "$CODEX_CONFIG" "$CODEX_CONFIG.rolepod-bak.$STAMP" 2>/dev/null || true
    fi

    # Detect existing marketplace registration via config.toml; pick add vs upgrade.
    # Note: `codex plugin marketplace upgrade` only works for git sources, so for
    # local sources we always re-add (which Codex handles idempotently for local).
    if [ -f "$CODEX_CONFIG" ] && grep -q '^\[marketplaces\.rolepod\]' "$CODEX_CONFIG" 2>/dev/null; then
      # Already registered.
      if [ "$FORCE" -eq 1 ]; then
        # --force: auto-refresh source path with current rendered dir.
        step "Refreshing rolepod marketplace registration (--force)"
        if [ "$DRY_RUN" -eq 1 ]; then
          dry "codex plugin marketplace remove rolepod && codex plugin marketplace add $RENDERED_CODEX_DIR"
        else
          echo "    Removing existing rolepod marketplace..."
          codex plugin marketplace remove rolepod >/dev/null 2>&1 || true
          echo "    Adding fresh marketplace registration..."
          if ! codex plugin marketplace add "$RENDERED_CODEX_DIR" 2>&1 | sed 's/^/    /'; then
            fail "codex plugin marketplace add failed — see output above"
          fi
        fi
      else
        # Without --force: detect "different source" conflict and surface a
        # clean remediation. Try a no-op probe to capture the exact error.
        step "rolepod marketplace already registered — probing for source mismatch"
        if [ "$DRY_RUN" -eq 1 ]; then
          dry "codex plugin marketplace add $RENDERED_CODEX_DIR (would detect conflict)"
        else
          probe_out=$(codex plugin marketplace add "$RENDERED_CODEX_DIR" 2>&1) || probe_rc=$?
          probe_rc=${probe_rc:-0}
          if [ "$probe_rc" -ne 0 ] && echo "$probe_out" | grep -qi 'already added from a different source'; then
            warn "rolepod marketplace already registered from a different source"
            warn ""
            warn "  To refresh:    ./install.sh --target=codex --force"
            warn "  To remove:     codex plugin marketplace remove rolepod"
            warn "                 ./install.sh --target=codex"
            fail "marketplace conflict — pick one of the options above"
          elif [ "$probe_rc" -ne 0 ]; then
            echo "$probe_out" | sed 's/^/    /'
            fail "codex plugin marketplace add failed — see output above"
          fi
          # probe_rc == 0 → idempotent re-add succeeded, source matches.
        fi
      fi
    else
      step "Registering rolepod marketplace with Codex"
      if [ "$DRY_RUN" -eq 1 ]; then
        dry "codex plugin marketplace add $RENDERED_CODEX_DIR"
      else
        if ! codex plugin marketplace add "$RENDERED_CODEX_DIR" 2>&1 | sed 's/^/    /'; then
          fail "codex plugin marketplace add failed — see output above"
        fi
      fi
    fi

    # Enable plugin in config.toml. Codex enables plugins via:
    #   [plugins."<plugin-name>@<marketplace-name>"]
    #   enabled = true
    # For rolepod the plugin name and marketplace name are both "rolepod".
    step "Enabling rolepod plugin in $CODEX_CONFIG"
    if [ "$DRY_RUN" -eq 1 ]; then
      dry "ensure [plugins.\"rolepod@rolepod\"] enabled = true in $CODEX_CONFIG"
    else
      mkdir -p "$CODEX_TARGET"
      touch "$CODEX_CONFIG"
      if grep -q '^\[plugins\."rolepod@rolepod"\]' "$CODEX_CONFIG" 2>/dev/null; then
        # Already enabled — no edit needed.
        :
      else
        printf '\n[plugins."rolepod@rolepod"]\nenabled = true\n' >> "$CODEX_CONFIG"
      fi
    fi
  else
    # Either temp-target mode OR codex binary missing. Both paths skip global
    # codex commands and write only filesystem artifacts so static checks pass.
    if [ "$CODEX_IS_TEMP_TARGET" -eq 1 ]; then
      warn "ROLEPOD_TARGET set — skipping global marketplace registration."
      warn "  Codex CLI has no per-target config home. Marketplace add would mutate $HOME/.codex/config.toml."
      warn "  For real install, run without ROLEPOD_TARGET: ./install.sh --target=codex"
      warn "  For isolated preview, use --dry-run: ROLEPOD_TARGET=$CODEX_TARGET ./install.sh --target=codex --dry-run"
    else
      warn "codex binary not found — installing AGENTS.md + filesystem artifacts only (Tier 1 rules still active)"
      warn "  Install Codex CLI: npm install -g @openai/codex"
      warn "  After install, run: codex plugin marketplace add $RENDERED_CODEX_DIR"
    fi
    step "Copying rendered plugin tree → $CODEX_TARGET/plugins/rolepod (filesystem only — Codex loader resolves from rendered dir)"
    if [ "$DRY_RUN" -eq 1 ]; then
      dry "mkdir -p $CODEX_TARGET/plugins/rolepod && cp -R $RENDERED_CODEX_DIR/plugins/rolepod/. $CODEX_TARGET/plugins/rolepod/"
    else
      mkdir -p "$CODEX_TARGET/plugins/rolepod"
      cp -R "$RENDERED_CODEX_DIR/plugins/rolepod/." "$CODEX_TARGET/plugins/rolepod/" 2>/dev/null || true
    fi
  fi

  step "Updating AGENTS.md (managed block) → $CODEX_TARGET/AGENTS.md"
  update_managed_block "$CODEX_TARGET/AGENTS.md" "$RENDERED_AGENTS_MD"

  if [ "$DRY_RUN" -eq 0 ]; then
    step "Verifying Codex install"
    [ -e "$CODEX_TARGET/AGENTS.md" ] || fail "Codex verification failed — $CODEX_TARGET/AGENTS.md missing"
    if have_cmd codex && [ "$CODEX_IS_TEMP_TARGET" -eq 0 ]; then
      # Real install — verify the actual config Codex wrote to (always $HOME/.codex/config.toml).
      [ -f "$CODEX_CONFIG" ] || fail "Codex verification failed — $CODEX_CONFIG missing"
      grep -q '^\[marketplaces\.rolepod\]' "$CODEX_CONFIG" || fail "Codex verification failed — [marketplaces.rolepod] not in $CODEX_CONFIG"
      grep -q '^\[plugins\."rolepod@rolepod"\]' "$CODEX_CONFIG" || fail "Codex verification failed — [plugins.\"rolepod@rolepod\"] not in $CODEX_CONFIG"
      # Confirm rendered tree still resolvable (codex stores source path in config).
      [ -f "$RENDERED_CODEX_DIR/.agents/plugins/marketplace.json" ] || fail "Codex verification failed — rendered marketplace manifest missing"
      ok "rolepod codex marketplace registered → $RENDERED_CODEX_DIR"
    else
      # Temp-target OR codex binary missing — verify filesystem artifacts only.
      [ -d "$CODEX_TARGET/plugins/rolepod" ] || fail "Codex verification failed — $CODEX_TARGET/plugins/rolepod missing"
      [ -f "$CODEX_TARGET/plugins/rolepod/.codex-plugin/plugin.json" ] || fail "Codex verification failed — plugin.json missing"
      if [ "$CODEX_IS_TEMP_TARGET" -eq 1 ]; then
        ok "rolepod codex filesystem artifacts written → $CODEX_TARGET (global config NOT mutated)"
      else
        ok "rolepod codex filesystem artifacts written → $CODEX_TARGET (codex binary missing — Tier 1 rules still active via AGENTS.md)"
      fi
    fi
    ok "AGENTS.md → $CODEX_TARGET/AGENTS.md"
  else
    skip "Codex verification skipped (dry-run)"
  fi
  fi  # end CODEX_PROJECT_DONE guard
fi

# ─── install_gemini — Gemini CLI path (~/.gemini/) ─────────────────────
# Phase 2.3: install as a native Gemini extension under
# ~/.gemini/extensions/rolepod/. GEMINI.md goes to ~/.gemini/GEMINI.md (auto-loaded).
if gemini_selected; then
  GEMINI_TARGET="$(resolve_target_for gemini)"
  GEMINI_EXT_DEST="$GEMINI_TARGET/extensions/rolepod"
  echo ""
  echo "${BOLD}─── Installing for Gemini CLI ───${NC}"
  echo "  target:           $GEMINI_TARGET"
  if [ "$SCOPE" = "project" ]; then
    echo "  mode:             project-scope (managed GEMINI.md only — extension NOT installed)"
  else
    echo "  extension dest:   $GEMINI_EXT_DEST"
  fi

  RENDERED_GEMINI_DIR="$REPO_DIR/build/rendered/gemini"
  RENDERED_GEMINI_MD="$RENDERED_GEMINI_DIR/GEMINI.md"
  [ -f "$RENDERED_GEMINI_MD" ] || fail "expected $RENDERED_GEMINI_MD after render"

  if [ "$SCOPE" = "project" ]; then
    # Project scope: only write $PWD/GEMINI.md managed block. Gemini extensions
    # are global-only (load via ~/.gemini/extensions/) — same warn pattern as Codex.
    warn "Gemini extensions are global only. Per-project install writes GEMINI.md only."
    warn "  For full extension install, run --scope=global separately."
    step "Updating GEMINI.md (managed block) → $GEMINI_TARGET/GEMINI.md"
    update_managed_block "$GEMINI_TARGET/GEMINI.md" "$RENDERED_GEMINI_MD"
    if [ "$DRY_RUN" -eq 0 ]; then
      step "Verifying Gemini project install"
      [ -e "$GEMINI_TARGET/GEMINI.md" ] || fail "Gemini verification failed — $GEMINI_TARGET/GEMINI.md missing"
      ok "GEMINI.md → $GEMINI_TARGET/GEMINI.md"
    else
      skip "Gemini verification skipped (dry-run)"
    fi
    GEMINI_PROJECT_DONE=1
  else
    GEMINI_PROJECT_DONE=0
  fi

  if [ "${GEMINI_PROJECT_DONE:-0}" -eq 0 ]; then

  if ! have_cmd gemini; then
    warn "gemini binary not found — skipping Gemini install (file copy only)"
    warn "  Install Gemini CLI: npm install -g @google/gemini-cli"
  fi

  [ -f "$RENDERED_GEMINI_DIR/gemini-extension.json" ]     || fail "expected $RENDERED_GEMINI_DIR/gemini-extension.json after render"
  [ -d "$RENDERED_GEMINI_DIR/commands" ]                  || fail "expected $RENDERED_GEMINI_DIR/commands/ after render"
  [ -d "$RENDERED_GEMINI_DIR/hooks" ]                     || fail "expected $RENDERED_GEMINI_DIR/hooks/ after render"
  [ -d "$RENDERED_GEMINI_DIR/skills" ]                    || fail "expected $RENDERED_GEMINI_DIR/skills/ after render"

  # Backup if --force on existing — rolepod-scoped only.
  # Excludes: history/, log/, tmp/ — Gemini runtime data, not rolepod-managed.
  if [ "$FORCE" -eq 1 ] && [ -d "$GEMINI_TARGET" ]; then
    STAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP="${GEMINI_TARGET}.backup-$STAMP"
    warn "Backing up rolepod-managed paths in $GEMINI_TARGET → $BACKUP"
    selective_backup "$GEMINI_TARGET" "$BACKUP" \
      GEMINI.md \
      extensions/rolepod \
      settings.json
  fi

  step "Creating Gemini extension directory"
  do_or_dry "mkdir -p $GEMINI_EXT_DEST" mkdir -p "$GEMINI_EXT_DEST"

  if [ "$FORCE" -eq 1 ]; then
    do_or_dry "rm -rf $GEMINI_EXT_DEST && mkdir -p $GEMINI_EXT_DEST" \
      bash -c "rm -rf '$GEMINI_EXT_DEST' && mkdir -p '$GEMINI_EXT_DEST'"
  fi

  step "Copying extension tree → $GEMINI_EXT_DEST/"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "cp -R $RENDERED_GEMINI_DIR/. → $GEMINI_EXT_DEST/"
    dry "rm -f $GEMINI_EXT_DEST/GEMINI.md (entry doc lives at root, not in extension)"
  else
    cp -R "$RENDERED_GEMINI_DIR/." "$GEMINI_EXT_DEST/" 2>/dev/null || true
    # GEMINI.md is the entry doc — it lives at the Gemini root, not in the extension.
    rm -f "$GEMINI_EXT_DEST/GEMINI.md"
  fi

  step "Updating GEMINI.md (managed block) → $GEMINI_TARGET/GEMINI.md"
  update_managed_block "$GEMINI_TARGET/GEMINI.md" "$RENDERED_GEMINI_MD"

  step "Marking hook scripts executable"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "chmod +x $GEMINI_EXT_DEST/hooks/*.sh"
  else
    chmod +x "$GEMINI_EXT_DEST/hooks"/*.sh 2>/dev/null || true
  fi

  if [ "$DRY_RUN" -eq 0 ]; then
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
  else
    skip "Gemini verification skipped (dry-run)"
  fi
  fi  # end GEMINI_PROJECT_DONE guard
fi

# Ensure TARGET is set for the rest of the script. Plugin install routing
# now uses per-CLI plugin_dir_for() lookups, so this is a fallback only when
# claude wasn't selected at all.
if [ -z "${TARGET:-}" ]; then
  TARGET="$(default_target_path_for claude)"
  PLUGINS_DIR="$TARGET/plugins"
fi

# ─── Plugin definitions ─────────────────────────────────────────────────
# Per-CLI install routing:
#   - Skill plugins (ui-ux-pro-max, caveman) clone into the SELECTED target's
#     plugin/extension dir. For --target=all, clone once into Claude's plugins/
#     (skills are read by Claude Code's plugin loader; Codex/Gemini have their
#     own native skill discovery via the rendered plugin/extension tree).
#   - Global tools (rtk, gitnexus, mempalace) install via system package
#     managers and end up on $PATH — no per-target work.
#   - openai-codex Claude Code plugin is Claude-specific (only installs when
#     Claude is in the selected target set).

# Pick the "primary" target for skill plugins. Claude wins if selected,
# otherwise pick the single non-claude target.
primary_skill_target() {
  if claude_selected; then echo "claude"; return; fi
  case "$CLI_TARGET" in
    codex)  echo "codex"  ;;
    gemini) echo "gemini" ;;
    *)      echo "claude" ;;  # safe fallback
  esac
}

plugin_anthropic_skills() {
  # Anthropic skills are Claude-Code-only. Skip outside Claude target.
  if ! claude_selected; then
    skip "anthropic-skills (target: claude only — current: $CLI_TARGET)"
    return 0
  fi
  local p="$TARGET/plugins/marketplaces"
  if have_dir "$p" || have_dir "$TARGET/skills/test-driven-development" \
    || have_dir "$TARGET/skills/anthropic-skills" \
    || have_dir "$TARGET/plugins/marketplaces/anthropics"; then
    ok "Anthropic skills detected (target: claude — referenced by agent preloads)"
    note_skipped "anthropic-skills (already present)"
  else
    warn "Anthropic skills not detected. Most are bundled with recent Claude Code."
    warn "  Update Claude Code, or install via: claude plugin install anthropic-skills"
    note_failed "anthropic-skills (manual)"
  fi
}

plugin_ui_ux_pro_max() {
  local skill_target dest_root dest
  skill_target="$(primary_skill_target)"
  dest_root="$(plugin_dir_for "$skill_target")"
  dest="$dest_root/ui-ux-pro-max-skill"
  if have_dir "$dest"; then
    ok "ui-ux-pro-max already installed (target: $skill_target) → $dest"
    note_skipped "ui-ux-pro-max"
    return 0
  fi
  if ! have_cmd git; then
    warn "git not found — install: brew install git"
    note_failed "ui-ux-pro-max"
    return 1
  fi
  step "Cloning ui-ux-pro-max-skill (target: $skill_target) → $dest"
  do_or_dry "mkdir -p $dest_root" mkdir -p "$dest_root"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "git clone https://github.com/nextlevelbuilder/ui-ux-pro-max-skill $dest"
    note_installed "ui-ux-pro-max (dry-run)"
    return 0
  fi
  if git clone --quiet https://github.com/nextlevelbuilder/ui-ux-pro-max-skill "$dest"; then
    ok "ui-ux-pro-max installed (target: $skill_target)"
    note_installed "ui-ux-pro-max"
  else
    warn "ui-ux-pro-max clone failed"
    note_failed "ui-ux-pro-max"
  fi
}

plugin_gitnexus() {
  if have_cmd gitnexus; then
    ok "GitNexus already installed (target: global) → $(command -v gitnexus)"
    note_skipped "gitnexus"
    return 0
  fi
  if ! have_cmd npm; then
    warn "GitNexus needs npm. Install Node.js first → npm install -g gitnexus"
    note_failed "gitnexus"
    return 1
  fi
  step "Installing GitNexus via npm (target: global)"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "npm install -g gitnexus"
    note_installed "gitnexus (dry-run)"
    return 0
  fi
  if npm install -g gitnexus 2>&1 | tail -3; then
    ok "GitNexus installed (target: global)"
    note_installed "gitnexus"
  else
    warn "GitNexus install failed → manual: npm install -g gitnexus"
    note_failed "gitnexus"
  fi
}

plugin_mempalace() {
  if have_cmd mempalace; then
    ok "MemPalace already installed (target: global) → $(command -v mempalace)"
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
  step "Installing MemPalace via $pip_cmd (target: global)"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "$pip_cmd install --user mempalace"
    note_installed "mempalace (dry-run)"
    return 0
  fi
  if "$pip_cmd" install --user mempalace 2>&1 | tail -3; then
    ok "MemPalace installed (target: global)"
    note_installed "mempalace"
  else
    warn "MemPalace install failed → manual: $pip_cmd install mempalace"
    note_failed "mempalace"
  fi
}

plugin_caveman() {
  local skill_target dest_root dest
  skill_target="$(primary_skill_target)"
  dest_root="$(plugin_dir_for "$skill_target")"
  dest="$dest_root/caveman"
  if have_dir "$dest"; then
    ok "caveman already installed (target: $skill_target) → $dest"
    note_skipped "caveman"
    return 0
  fi
  if ! have_cmd git; then
    warn "git not found"
    note_failed "caveman"
    return 1
  fi
  step "Cloning caveman (target: $skill_target) → $dest"
  do_or_dry "mkdir -p $dest_root" mkdir -p "$dest_root"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "git clone https://github.com/JuliusBrussee/caveman $dest"
    note_installed "caveman (dry-run)"
    return 0
  fi
  if git clone --quiet https://github.com/JuliusBrussee/caveman "$dest"; then
    ok "caveman installed (target: $skill_target)"
    note_installed "caveman"
  else
    warn "caveman clone failed"
    note_failed "caveman"
  fi
}

plugin_rtk() {
  if have_cmd rtk; then
    ok "rtk already installed (target: global) → $(command -v rtk)"
    note_skipped "rtk"
    return 0
  fi
  if ! have_cmd cargo; then
    warn "rtk needs cargo. Install Rust (https://rustup.rs) → cargo install rtk"
    note_failed "rtk"
    return 1
  fi
  step "Installing rtk via cargo (target: global, this can take a few minutes)"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "cargo install rtk"
    note_installed "rtk (dry-run)"
    return 0
  fi
  if cargo install rtk 2>&1 | tail -3; then
    ok "rtk installed (target: global)"
    note_installed "rtk"
  else
    warn "rtk install failed → manual: cargo install rtk"
    note_failed "rtk"
  fi
}

plugin_gemini_cli() {
  if have_cmd gemini; then
    ok "Gemini CLI already installed (target: global) → $(command -v gemini)"
    note_skipped "gemini-cli"
    return 0
  fi
  if have_cmd npm; then
    step "Installing Gemini CLI via npm (target: global)"
    if [ "$DRY_RUN" -eq 1 ]; then
      dry "npm install -g @google/gemini-cli"
      note_installed "gemini-cli (dry-run)"
      return 0
    fi
    if npm install -g @google/gemini-cli 2>&1 | tail -3; then
      ok "Gemini CLI installed (target: global)"
      note_installed "gemini-cli"
      warn "Run: gemini auth login"
      return 0
    fi
  fi
  if have_cmd brew; then
    step "Installing Gemini CLI via brew (target: global)"
    if [ "$DRY_RUN" -eq 1 ]; then
      dry "brew install gemini-cli"
      note_installed "gemini-cli (dry-run)"
      return 0
    fi
    if brew install gemini-cli 2>&1 | tail -3; then
      ok "Gemini CLI installed (target: global)"
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
    ok "Codex CLI already installed (target: global) → $(command -v codex)"
    note_skipped "codex-cli"
    return 0
  fi
  if ! have_cmd npm; then
    warn "Codex CLI needs npm. Manual: npm install -g @openai/codex"
    note_failed "codex-cli"
    return 1
  fi
  step "Installing Codex CLI via npm (target: global)"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "npm install -g @openai/codex"
    note_installed "codex-cli (dry-run)"
    return 0
  fi
  if npm install -g @openai/codex 2>&1 | tail -3; then
    ok "Codex CLI installed (target: global)"
    note_installed "codex-cli"
  else
    warn "Codex CLI install failed → manual: npm install -g @openai/codex"
    note_failed "codex-cli"
  fi
}

plugin_openai_codex_marketplace() {
  # Claude Code plugin — only meaningful when Claude is in the selected set.
  if ! claude_selected; then
    skip "openai-codex Claude Code plugin (target: claude only — current: $CLI_TARGET)"
    return 0
  fi
  local p="$TARGET/plugins/marketplaces/openai-codex"
  if have_dir "$p"; then
    ok "openai-codex Claude Code plugin already installed (target: claude)"
    note_skipped "openai-codex-plugin"
    return 0
  fi
  warn "openai-codex plugin (target: claude) must be installed inside Claude Code:"
  warn "  start Claude Code, then run: /plugin install openai-codex"
  note_failed "openai-codex-plugin (manual /plugin install)"
}

# ─── Run plugin installs based on granular sets ─────────────────────────
# WANT_TOOLS / WANT_SKILLS / WANT_CLIS / WANT_PLUGINS were populated either
# directly via --with-* flags or expanded from --minimum/--full above.

ANY_PLUGIN=0
[ -n "$WANT_TOOLS"   ] && ANY_PLUGIN=1
[ -n "$WANT_SKILLS"  ] && ANY_PLUGIN=1
[ -n "$WANT_CLIS"    ] && ANY_PLUGIN=1
[ -n "$WANT_PLUGINS" ] && ANY_PLUGIN=1

if [ "$ANY_PLUGIN" -eq 1 ]; then
  echo ""
  echo "${BOLD}${CYAN}Installing requested extras${NC}"
  [ -n "$WANT_TOOLS"   ] && echo "  tools:   $WANT_TOOLS"
  [ -n "$WANT_SKILLS"  ] && echo "  skills:  $WANT_SKILLS"
  [ -n "$WANT_CLIS"    ] && echo "  clis:    $WANT_CLIS"
  [ -n "$WANT_PLUGINS" ] && echo "  plugins: $WANT_PLUGINS"
  echo ""

  # Anthropic skills detection — always runs when Claude is the target and any
  # extras are requested (cheap, read-only check).
  if claude_selected; then
    plugin_anthropic_skills
  fi

  # Skills (3rd-party clones into per-CLI plugin/extension dir)
  if wants "ui-ux-pro-max" "$WANT_SKILLS"; then plugin_ui_ux_pro_max; fi
  if wants "caveman"       "$WANT_SKILLS"; then plugin_caveman; fi

  # Global tools (toolchain-installed, end up on $PATH)
  if wants "gitnexus"  "$WANT_TOOLS"; then plugin_gitnexus; fi
  if wants "mempalace" "$WANT_TOOLS"; then plugin_mempalace; fi
  if wants "rtk"       "$WANT_TOOLS"; then plugin_rtk; fi

  # CLI binaries
  if wants "codex"  "$WANT_CLIS"; then plugin_codex_cli; fi
  if wants "gemini" "$WANT_CLIS"; then plugin_gemini_cli; fi

  # Claude marketplace plugins (Claude-only)
  if wants "openai-codex" "$WANT_PLUGINS"; then plugin_openai_codex_marketplace; fi
fi

# ─── Summary ────────────────────────────────────────────────────────────
echo ""
echo "${BOLD}─── Summary ───${NC}"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "${YELLOW}DRY-RUN: nothing was written to disk${NC}"
fi
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
if [ "$MODE" = "core" ] && [ "$ANY_PLUGIN" -eq 0 ]; then
  cat <<EOF
${BOLD}rolepod core installed.${NC} For plugin install:

  ./install.sh --minimum    # ui-ux-pro-max + GitNexus + MemPalace
  ./install.sh --full       # minimum + caveman + rtk + Codex + Gemini

Granular alternatives:
  ./install.sh --with-tools=gitnexus,mempalace
  ./install.sh --with-skills=ui-ux-pro-max
  ./install.sh --with-clis=codex,gemini --with-plugins=openai-codex

EOF
fi

# ─── Post-install interactive prompts ───────────────────────────────────
# Only when stdin is a TTY (or /dev/tty available), and only for modes that
# actually installed the relevant tool. Each prompt reads from /dev/tty so
# this also works when install.sh is piped via curl. Skipped in dry-run.

was_installed() {
  local needle="$1"
  for x in "${INSTALLED[@]}"; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

ask_yn() {
  # ask_yn "Question" "Y"|"N"  → returns 0 for yes, 1 for no.
  # Uses can_prompt() to pick stdin vs /dev/tty. Returns 1 when no TTY at all.
  local prompt="$1" default="$2" reply mode
  local hint="[y/N]"; [ "$default" = "Y" ] && hint="[Y/n]"
  can_prompt; mode=$?
  if [ "$mode" -eq 0 ]; then return 1; fi
  if [ "$mode" -eq 1 ]; then
    printf "%s %s " "$prompt" "$hint"
    if ! read -r reply; then return 1; fi
  else
    printf "%s %s " "$prompt" "$hint" > /dev/tty
    if ! read -r reply < /dev/tty; then return 1; fi
  fi
  reply="${reply:-$default}"
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

can_prompt; _post_install_mode=$?
if [ "$DRY_RUN" -eq 0 ] && [ "$_post_install_mode" -ne 0 ]; then
  if [ "$ANY_PLUGIN" -eq 1 ]; then
    # Only prompt if at least one relevant tool is available.
    SHOW_PROMPTS=0
    if have_cmd mempalace || was_installed "mempalace" || have_cmd gemini || was_installed "gemini-cli"; then
      SHOW_PROMPTS=1
    fi
    wants "openai-codex" "$WANT_PLUGINS" && SHOW_PROMPTS=1

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

      # 3) openai-codex marketplace plugin (only when explicitly requested + missing)
      if wants "openai-codex" "$WANT_PLUGINS" && claude_selected \
         && [ ! -d "$TARGET/plugins/marketplaces/openai-codex" ]; then
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
if [ "$SCOPE" = "project" ]; then
  case "$CLI_TARGET" in
    claude) echo "${BOLD}Final step${NC}: restart Claude Code in this project to load the rolepod workflow." ;;
    codex)  echo "${BOLD}Final step${NC}: Codex auto-loads $PWD/AGENTS.md when you run codex in this project." ;;
    gemini) echo "${BOLD}Final step${NC}: Gemini auto-loads $PWD/GEMINI.md when you run gemini in this project." ;;
    all)    echo "${BOLD}Final step${NC}: restart Claude Code in this project; Codex/Gemini auto-load $PWD/AGENTS.md and $PWD/GEMINI.md." ;;
  esac
else
  case "$CLI_TARGET" in
    claude) echo "${BOLD}Final step${NC}: restart Claude Code so the hooks register." ;;
    codex)  echo "${BOLD}Final step${NC}: restart Codex CLI to load the new plugin and hooks." ;;
    gemini) echo "${BOLD}Final step${NC}: restart Gemini CLI to load the new extension and hooks." ;;
    all)    echo "${BOLD}Final step${NC}: restart Claude Code, Codex CLI, and Gemini CLI." ;;
  esac
fi
