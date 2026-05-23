#!/usr/bin/env bash
# rolepod installer — copies workflow files to the selected CLI's config dir.
#
# Rolepod ships PURE FRAMEWORK ONLY — no 3rd-party tools or plugins are
# auto-installed. Recommended add-ons (CodeGraph, GitNexus, MemPalace, rtk,
# caveman, ui-ux-pro-max) live in README → "Recommended add-ons". The
# framework auto-integrates with each one when the user installs it themselves
# (graceful degradation everywhere).
#
# Usage:
#   ./install.sh                       # install rolepod framework (default target: claude)
#   ./install.sh --force               # overwrite existing files (selective backup created)
#                                      # Backup includes ONLY rolepod-managed paths
#                                      # (entry docs, agents/, rules/, hooks/, skills/, etc.)
#                                      # Excluded: session history (projects/), plugin cache,
#                                      # file-history/, shell-snapshots/, agent-memory/, etc.
#                                      # Typical backup: <50MB (vs ~1.8GB full ~/.claude copy)
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
#   ROLEPOD_CURSOR_TARGET    Per-CLI override — wins over ROLEPOD_TARGET for Cursor.
#
# Non-TTY behavior: --uninstall without --yes in a non-interactive context
# (no /dev/tty available) prints "Aborted. Re-run with --yes in non-interactive
# mode." and exits 0 — never crashes on a missing TTY.
#
# Managed entry docs (CLAUDE.md / AGENTS.md / GEMINI.md): rolepod content is
# wrapped in <!-- rolepod:start --> ... <!-- rolepod:end --> markers. User
# content outside those markers is preserved across re-installs and uninstall.
#
# Add-on detection: if MemPalace / GitNexus / etc. are already installed on the
# user's system, framework hooks/rules wire to them automatically. Nothing is
# installed by this script.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${ROLEPOD_TARGET:-}"   # final value depends on CLI_TARGET; resolved below
PLUGINS_DIR=""                  # set after TARGET resolves
FORCE=0
CLI_TARGET="claude"
SCOPE="global"
UNINSTALL=0
ASSUME_YES=0
DRY_RUN=0

# Args
for arg in "$@"; do
  case "$arg" in
    --force)         FORCE=1 ;;
    --uninstall)     UNINSTALL=1 ;;
    --yes|-y)        ASSUME_YES=1 ;;
    --dry-run)       DRY_RUN=1 ;;
    --target=*)      CLI_TARGET="${arg#--target=}" ;;
    --scope=*)       SCOPE="${arg#--scope=}" ;;
    -h|--help)
      sed -n '2,53p' "$0"
      exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; echo "" >&2; echo "Rolepod ships framework only. For 3rd-party add-ons (GitNexus / MemPalace / etc.), see README → Recommended add-ons." >&2; exit 1 ;;
  esac
done

case "$CLI_TARGET" in
  claude|codex|gemini|cursor|all) ;;
  *)
    echo "Unknown --target value: $CLI_TARGET (expected claude|codex|gemini|cursor|all)" >&2
    exit 1 ;;
esac

case "$SCOPE" in
  global|project) ;;
  *)
    echo "Unknown --scope value: $SCOPE (expected global|project)" >&2
    exit 1 ;;
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
      cursor) echo "$PWD/.cursor" ;;
      *)      echo "$PWD" ;;
    esac
    return
  fi
  case "$1" in
    claude) echo "$HOME/.claude" ;;
    codex)  echo "$HOME/.codex" ;;
    gemini) echo "$HOME/.gemini" ;;
    cursor) echo "$HOME/.cursor" ;;
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
    cursor) override="${ROLEPOD_CURSOR_TARGET:-}" ;;
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

# Rolepod no longer ships executable legacy skill shims. On upgrade, clean
# previously installed shim dirs so users do not keep seeing the old bloated
# skill surface forever.
LEGACY_SKILL_NAMES=(
  advisor-escalation anti-spaghetti api-and-interface-design browser-testing-with-devtools
  ci-cd-and-automation claude-api code-review-and-quality code-simplification
  context-engineering conversion-copywriting debugging-and-error-recovery doc-coauthoring
  documentation-and-adrs doubt-driven-development finishing-a-development-branch
  frontend-ui-engineering interaction-design interface-design internal-comms
  new-project-onboarding parallel-contract-orchestration performance-optimization
  planning-and-task-breakdown post-change-verify pre-merge-gate reviewer-flow
  root-cause-tracing security-and-hardening seo session-hygiene shipping-and-launch
  source-driven-development spec-driven-development subagent-task-execution
  systematic-debugging team-routing test-driven-development triage-deep
  user-facing-content using-worktrees web-design-guidelines webapp-testing zoom-out
)

remove_stale_legacy_skills() {
  local skills_dir="$1"
  [ -d "$skills_dir" ] || return 0

  local removed=0 skipped=0 name dir md
  for name in "${LEGACY_SKILL_NAMES[@]}"; do
    dir="$skills_dir/$name"
    md="$dir/SKILL.md"
    [ -d "$dir" ] || continue
    if [ -f "$md" ] && grep -Eq '^(tier: 3|redirect_to:)|Compatibility shim|This shim preserves' "$md"; then
      do_or_dry "rm -r $dir (stale rolepod legacy skill)" rm -r "$dir"
      removed=$((removed+1))
    else
      warn "Skipping possible user-owned skill while cleaning legacy rolepod names: $dir"
      skipped=$((skipped+1))
    fi
  done

  if [ "$removed" -gt 0 ]; then
    ok "Removed $removed stale legacy rolepod skill(s)"
  fi
  if [ "$skipped" -gt 0 ]; then
    warn "Skipped $skipped legacy-named skill(s) that did not look rolepod-managed"
  fi
}

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
echo "  force:   $FORCE"
echo "  dry-run: $DRY_RUN"
echo ""

# ─── Sanity check source ────────────────────────────────────────────────
for f in CHEATSHEET.md core/agents hooks core/skills adapters/claude/.claude-plugin/plugin.json adapters/claude/.claude-plugin/marketplace.json build/render.sh; do
  [ -e "$REPO_DIR/$f" ] || fail "missing $f in $REPO_DIR — run from rolepod repo"
done

# Codex/Gemini adapter sanity (only required if those targets selected).
# Phase 2.3: each CLI ships as a native plugin/extension — no wrapper scripts.
case "$CLI_TARGET" in
  codex|all)
    [ -e "$REPO_DIR/adapters/codex/AGENTS.md.tmpl" ]                                       || fail "missing adapters/codex/AGENTS.md.tmpl"
    [ -e "$REPO_DIR/adapters/codex/.agents/plugins/marketplace.json" ]                     || fail "missing adapters/codex/.agents/plugins/marketplace.json"
    [ -e "$REPO_DIR/adapters/codex/plugins/rolepod/.codex-plugin/plugin.json" ]            || fail "missing adapters/codex/plugins/rolepod/.codex-plugin/plugin.json"
    [ -d "$REPO_DIR/adapters/codex/agent-frontmatter" ]                                    || fail "missing adapters/codex/agent-frontmatter/ (codex agent overlays)"
    [ -e "$REPO_DIR/adapters/codex/plugins/rolepod/hooks/hooks.json" ]                     || fail "missing adapters/codex/plugins/rolepod/hooks/hooks.json"
    ;;
esac
case "$CLI_TARGET" in
  gemini|all)
    [ -e "$REPO_DIR/adapters/gemini/GEMINI.md.tmpl" ]        || fail "missing adapters/gemini/GEMINI.md.tmpl"
    [ -e "$REPO_DIR/adapters/gemini/gemini-extension.json" ] || fail "missing adapters/gemini/gemini-extension.json"
    [ -e "$REPO_DIR/adapters/gemini/hooks/hooks.json" ]      || fail "missing adapters/gemini/hooks/hooks.json"
    ;;
esac
case "$CLI_TARGET" in
  cursor|all)
    [ -e "$REPO_DIR/adapters/cursor/.cursor-plugin/plugin.json" ]      || fail "missing adapters/cursor/.cursor-plugin/plugin.json"
    [ -e "$REPO_DIR/adapters/cursor/.cursor-plugin/marketplace.json" ] || fail "missing adapters/cursor/.cursor-plugin/marketplace.json"
    [ -e "$REPO_DIR/adapters/cursor/rules/always-on-core.mdc.tmpl" ]   || fail "missing adapters/cursor/rules/always-on-core.mdc.tmpl"
    [ -e "$REPO_DIR/adapters/cursor/hooks/hooks.json" ]                || fail "missing adapters/cursor/hooks/hooks.json"
    [ -d "$REPO_DIR/adapters/cursor/scripts" ]                         || fail "missing adapters/cursor/scripts/ (cursor hook scripts)"
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
  uninstall_claude=0; uninstall_codex=0; uninstall_gemini=0; uninstall_cursor=0
  case "$CLI_TARGET" in claude|all) uninstall_claude=1 ;; esac
  case "$CLI_TARGET" in codex|all)  uninstall_codex=1 ;; esac
  case "$CLI_TARGET" in gemini|all) uninstall_gemini=1 ;; esac
  case "$CLI_TARGET" in cursor|all) uninstall_cursor=1 ;; esac

  C_TARGET="$(resolve_target_for claude)"
  X_TARGET="$(resolve_target_for codex)"
  G_TARGET="$(resolve_target_for gemini)"
  R_TARGET="$(resolve_target_for cursor)"

  echo "About to remove rolepod from:"
  [ "$uninstall_claude" -eq 1 ] && echo "  Claude → $C_TARGET (agents, skills, rules, hooks, managed CLAUDE.md block)"
  [ "$uninstall_codex"  -eq 1 ] && echo "  Codex  → rolepod marketplace + [plugins.\"rolepod@rolepod\"] in $X_TARGET/config.toml + managed AGENTS.md block"
  [ "$uninstall_gemini" -eq 1 ] && echo "  Gemini → $G_TARGET/extensions/rolepod, managed GEMINI.md block"
  [ "$uninstall_cursor" -eq 1 ] && echo "  Cursor → $R_TARGET/plugins/local/rolepod"
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

    # Resolve whether C_TARGET is the real ~/.claude, same as install path.
    # `claude plugin uninstall` writes to the real home with no override flag —
    # skip it when uninstalling against a temp/test target.
    C_REAL_HOME="$HOME/.claude"
    C_TARGET_RESOLVED="$(cd "$C_TARGET" 2>/dev/null && pwd -P || echo "$C_TARGET")"
    C_REAL_RESOLVED="$(cd "$C_REAL_HOME" 2>/dev/null && pwd -P || echo "$C_REAL_HOME")"
    C_IS_TEMP_TARGET=0
    [ "$C_TARGET_RESOLVED" != "$C_REAL_RESOLVED" ] && C_IS_TEMP_TARGET=1

    # 1. Uninstall the plugin via the CLI (real target only).
    if have_cmd claude && [ "$C_IS_TEMP_TARGET" -eq 0 ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        dry "claude plugin uninstall rolepod@rolepod --scope user -y"
        dry "claude plugin marketplace remove rolepod"
      else
        claude plugin uninstall rolepod@rolepod --scope user -y >/dev/null 2>&1 || true
        claude plugin marketplace remove rolepod >/dev/null 2>&1 || true
      fi
    elif [ "$C_IS_TEMP_TARGET" -eq 1 ]; then
      warn "Target diverges from ~/.claude — skipping 'claude plugin' CLI during uninstall."
    fi

    # 2. Remove filesystem copy of the plugin tree (temp-target installs write
    #    this path; also cleans up if the CLI uninstall left it behind).
    do_or_dry "rm -rf $C_TARGET/plugins/rolepod" rm -rf "$C_TARGET/plugins/rolepod"

    # 3. Legacy flat-file cleanup (pre-2.0 non-plugin installs). Doubles as
    #    cleanup for any leftover files the plugin install might have left.
    for n in "${AGENT_NAMES[@]}";   do do_or_dry "rm -f $C_TARGET/agents/$n"   rm -f "$C_TARGET/agents/$n"; done
    # Rolepod no longer ships rules/ — strip the known rolepod rule paths a
    # pre-redesign install left behind, leaving any user-authored rules intact.
    do_or_dry "rm -rf rolepod rule dirs under $C_TARGET/rules" rm -rf "$C_TARGET/rules/always-on" "$C_TARGET/rules/code" "$C_TARGET/rules/test"
    for n in INDEX.md communication.md verify-first.md code-search.md agent-protocol.md code-quality.md code-intel.md code-intel-workflow.md testing.md; do
      do_or_dry "rm -f $C_TARGET/rules/$n" rm -f "$C_TARGET/rules/$n"
    done
    # Prune empty rules subfolders left after file removal
    if [ "$DRY_RUN" -eq 0 ]; then
      find "$C_TARGET/rules" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    fi
    # COMMAND_NAMES is empty whenever the repo has no top-level commands/ dir
    # (the normal case — commands ship per-adapter). Expanding an empty array
    # with "${arr[@]}" trips `set -u` on bash 3.2 (macOS); the +-form expands
    # to nothing when unset and to the quoted elements otherwise.
    for n in ${COMMAND_NAMES[@]+"${COMMAND_NAMES[@]}"}; do do_or_dry "rm -f $C_TARGET/commands/$n" rm -f "$C_TARGET/commands/$n"; done
    for n in "${HOOK_NAMES[@]}";    do do_or_dry "rm -f $C_TARGET/hooks/$n"    rm -f "$C_TARGET/hooks/$n"; done
    for n in "${SKILL_NAMES[@]}";   do do_or_dry "rm -rf $C_TARGET/skills/$n"  rm -rf "$C_TARGET/skills/$n"; done
    do_or_dry "rm -f $C_TARGET/CHEATSHEET.md"              rm -f "$C_TARGET/CHEATSHEET.md"
    do_or_dry "rm -f $C_TARGET/.claude-plugin/plugin.json" rm -f "$C_TARGET/.claude-plugin/plugin.json"
    # Empty dirs cleanup (rmdir; ignore failure if non-empty)
    if [ "$DRY_RUN" -eq 1 ]; then
      dry "rmdir empty agents/rules/commands/hooks/skills/.claude-plugin under $C_TARGET (if empty)"
    else
      rmdir "$C_TARGET/agents" "$C_TARGET/rules" "$C_TARGET/commands" \
            "$C_TARGET/hooks" "$C_TARGET/skills" "$C_TARGET/.claude-plugin" 2>/dev/null || true
    fi

    # 4. Strip rolepod hook entries from settings.json (cleans pre-2.0 entries).
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

    # 5. Strip rolepod managed block from CLAUDE.md.
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
    fi

    # Remove Codex plugin cache (populated by `register cache populate` step
    # during install — see install path).
    if [ -d "$X_TARGET/plugins/cache/rolepod" ]; then
      step "Removing Codex plugin cache at $X_TARGET/plugins/cache/rolepod"
      do_or_dry "rm -rf $X_TARGET/plugins/cache/rolepod" rm -rf "$X_TARGET/plugins/cache/rolepod"
    fi

    # Remove rolepod-*.toml agents installed under $X_TARGET/agents/ (install
    # step copies the rendered build/rendered/codex/agents/*.toml with a
    # rolepod- prefix). User-authored agents without the prefix are preserved.
    if [ -d "$X_TARGET/agents" ]; then
      ROLEPOD_AGENTS=$(ls "$X_TARGET/agents"/rolepod-*.toml 2>/dev/null | wc -l | tr -d ' ')
      if [ "$ROLEPOD_AGENTS" -gt 0 ]; then
        step "Removing $ROLEPOD_AGENTS rolepod agents at $X_TARGET/agents/rolepod-*.toml"
        do_or_dry "rm -f $X_TARGET/agents/rolepod-*.toml" sh -c "rm -f \"$X_TARGET/agents\"/rolepod-*.toml"
      fi
    fi

    if [ "$DRY_RUN" -eq 0 ]; then
      rmdir "$X_TARGET/plugins/cache" 2>/dev/null || true
      rmdir "$X_TARGET/plugins" 2>/dev/null || true
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

  if [ "$uninstall_cursor" -eq 1 ]; then
    step "Removing Cursor rolepod plugin in $R_TARGET/plugins/local/rolepod"
    do_or_dry "rm -rf $R_TARGET/plugins/local/rolepod" rm -rf "$R_TARGET/plugins/local/rolepod"
    if [ "$DRY_RUN" -eq 1 ]; then
      dry "rmdir $R_TARGET/plugins/local (if empty)"
      dry "rmdir $R_TARGET/plugins (if empty)"
    else
      rmdir "$R_TARGET/plugins/local" 2>/dev/null || true
      rmdir "$R_TARGET/plugins" 2>/dev/null || true
    fi
    ok "Cursor rolepod removed"
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
cursor_selected() {
  case "$CLI_TARGET" in cursor|all) return 0 ;; *) return 1 ;; esac
}

if claude_selected; then
  TARGET="$(resolve_target_for claude)"
  PLUGINS_DIR="$TARGET/plugins"
  echo ""
  echo "${BOLD}─── Installing for Claude Code ───${NC}"
  echo "  target: $TARGET"

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
      plugins/rolepod \
      settings.json
  fi

  # `claude plugin` CLI writes to the real ~/.claude and has no home-override
  # flag. On a temp/diverged target (test isolation, ROLEPOD_TARGET set) skip
  # the CLI and fall back to a filesystem-only plugin-tree copy. Mirror the
  # Codex temp-target detection at the codex install block.
  CLAUDE_REAL_HOME="$HOME/.claude"
  TARGET_RESOLVED="$(cd "$TARGET" 2>/dev/null && pwd -P || echo "$TARGET")"
  CLAUDE_REAL_RESOLVED="$(cd "$CLAUDE_REAL_HOME" 2>/dev/null && pwd -P || echo "$CLAUDE_REAL_HOME")"
  CLAUDE_IS_TEMP_TARGET=0
  [ "$TARGET_RESOLVED" != "$CLAUDE_REAL_RESOLVED" ] && CLAUDE_IS_TEMP_TARGET=1

  # The repo root IS the Claude marketplace — .claude-plugin/marketplace.json
  # + plugins/rolepod/ are committed and refreshed by render. `claude plugin
  # marketplace add` consumes the repo directly.
  RENDERED_CLAUDE_DIR="$REPO_DIR"
  [ -d "$RENDERED_CLAUDE_DIR/plugins/rolepod" ] || fail "expected $RENDERED_CLAUDE_DIR/plugins/rolepod after render"

  if [ "$FORCE" -eq 1 ]; then CP_FLAG=""; else CP_FLAG="-n"; fi

  # CHEATSHEET reference doc. The always-on judgment core ships via the
  # plugin's SessionStart hook (hooks/always-on-loader.sh) — rolepod no longer
  # writes a managed block into the user's ~/.claude/CLAUDE.md.
  step "Copying CHEATSHEET.md"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "cp $CP_FLAG $REPO_DIR/CHEATSHEET.md → $TARGET/CHEATSHEET.md"
  else
    cp $CP_FLAG "$REPO_DIR/CHEATSHEET.md" "$TARGET/" 2>/dev/null || true
  fi

  # Migration — strip a stale rolepod managed block from a pre-redesign
  # install. Rolepod no longer manages a CLAUDE.md block; leaving the old one
  # would double up with the hook-delivered always-on core. A fresh install
  # has no block, so remove_managed_block is a no-op (no file write).
  remove_managed_block "$TARGET/CLAUDE.md"

  # rules/ — rolepod ships no rules/ copy any more. Path-scoped code/test
  # guidance folded into the phase skills; always-on judgment ships via the
  # SessionStart hook. Strip any rolepod rules a prior install left behind.
  step "Removing stale rolepod rules (no rules/ shipped)"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "rm stale rolepod rules from $TARGET/rules/ (always-on/ code/ test/ INDEX.md + legacy flat files)"
  else
    rm -rf "$TARGET/rules/always-on" "$TARGET/rules/code" "$TARGET/rules/test"
    for legacy in pre-merge-gate.md reviewer-flow.md advisor.md \
                  session-management.md triage-deep.md new-project.md \
                  team-org.md verification.md \
                  communication.md verify-first.md agent-protocol.md \
                  code-quality.md code-intel.md code-intel-workflow.md \
                  testing.md INDEX.md; do
      rm -f "$TARGET/rules/$legacy"
    done
    # Drop the rules/ dir if rolepod cleanup left it empty.
    rmdir "$TARGET/rules" 2>/dev/null || true
  fi

  # Migration — strip a pre-2.0 non-plugin install. Older rolepod copied
  # agents/skills/commands/hooks into ~/.claude/* and registered hooks in
  # settings.json. The plugin now owns all of that; leftovers would double up
  # (duplicate skills/agents loaded, duplicate hooks fired). Best-effort,
  # non-fatal, dry-run aware.
  step "Migration — removing any pre-2.0 non-plugin rolepod files"

  # 1. Strip rolepod hook entries from settings.json. Reuse the exact
  #    python strip-by-hook-dir-substring block from the uninstall path
  #    with hook_dir="$TARGET/hooks".
  _LEGACY_SETTINGS_FILE="$TARGET/settings.json"
  if [ -f "$_LEGACY_SETTINGS_FILE" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      dry "strip rolepod hook entries (paths under $TARGET/hooks) from $_LEGACY_SETTINGS_FILE"
    elif command -v python3 >/dev/null 2>&1; then
      python3 - "$_LEGACY_SETTINGS_FILE" "$TARGET/hooks" <<'PY' || warn "settings.json migration strip failed (non-fatal)"
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
      warn "python3 not found — leaving settings.json hook entries untouched (remove rolepod entries manually)"
    fi
  fi

  # 2. Remove legacy rolepod flat-file install artifacts (only if they exist).
  #    Agents — match by basename from the rendered plugin agents/ dir.
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "rm legacy agents/skills/commands/hooks/.claude-plugin from $TARGET (pre-2.0 non-plugin install)"
  else
    if [ -d "$RENDERED_CLAUDE_DIR/plugins/rolepod/agents" ]; then
      for f in "$RENDERED_CLAUDE_DIR/plugins/rolepod/agents"/*.md; do
        [ -f "$f" ] || continue
        rm -f "$TARGET/agents/$(basename "$f")" 2>/dev/null || true
      done
    fi
    # Skills — match by dir name from core/skills/
    for d in "$REPO_DIR"/core/skills/*/; do
      [ -d "$d" ] || continue
      rm -rf "$TARGET/skills/$(basename "$d")" 2>/dev/null || true
    done
    # Commands — match by basename from commands/
    for f in "$REPO_DIR"/commands/*.md; do
      [ -f "$f" ] || continue
      rm -f "$TARGET/commands/$(basename "$f")" 2>/dev/null || true
    done
    # Hooks — match by basename from hooks/*.sh
    for f in "$REPO_DIR"/hooks/*.sh; do
      [ -f "$f" ] || continue
      rm -f "$TARGET/hooks/$(basename "$f")" 2>/dev/null || true
    done
    rm -rf "$TARGET/hooks/optional" "$TARGET/hooks/lib" 2>/dev/null || true
    # Old root-level plugin manifest (not the plugin's own manifest)
    rm -f "$TARGET/.claude-plugin/plugin.json" 2>/dev/null || true
    # Prune now-possibly-empty dirs (ignore failure if non-empty — other tools may share them)
    rmdir "$TARGET/agents" "$TARGET/skills" "$TARGET/commands" \
          "$TARGET/hooks" "$TARGET/.claude-plugin" 2>/dev/null || true
  fi

  # 3. Stale Tier-3 legacy shim skills (pre-Core-10 names) a pre-2.0 install
  #    left in $TARGET/skills/. do_or_dry-aware — safe in dry-run.
  remove_stale_legacy_skills "$TARGET/skills"

  # Plugin install.
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "claude plugin marketplace add $RENDERED_CLAUDE_DIR"
    dry "claude plugin install rolepod@rolepod --scope user"
  elif [ "$CLAUDE_IS_TEMP_TARGET" -eq 1 ]; then
    warn "Target diverges from ~/.claude — skipping 'claude plugin' CLI (would mutate real Claude home)."
    warn "  Copying plugin tree to $TARGET/plugins/rolepod/ for filesystem checks only."
    rm -rf "$TARGET/plugins/rolepod"; mkdir -p "$TARGET/plugins"
    cp -R "$RENDERED_CLAUDE_DIR/plugins/rolepod" "$TARGET/plugins/"
  elif have_cmd claude; then
    step "Registering rolepod marketplace + installing plugin"
    claude plugin marketplace remove rolepod >/dev/null 2>&1 || true
    if claude plugin marketplace add "$RENDERED_CLAUDE_DIR" >/dev/null 2>&1 \
       && claude plugin install rolepod@rolepod --scope user >/dev/null 2>&1; then
      ok "rolepod plugin installed (marketplace: rolepod)"
    else
      warn "Could not install via 'claude plugin' CLI — run: claude plugin marketplace add $RENDERED_CLAUDE_DIR && claude plugin install rolepod@rolepod"
    fi
  else
    warn "claude binary not found — skipping plugin install."
    warn "  Then run: claude plugin marketplace add $RENDERED_CLAUDE_DIR && claude plugin install rolepod@rolepod"
  fi

  # Verify.
  if [ "$DRY_RUN" -eq 0 ]; then
    step "Verifying rolepod install"
    if [ "$CLAUDE_IS_TEMP_TARGET" -eq 1 ]; then
      [ -d "$TARGET/plugins/rolepod" ] || fail "verification failed — $TARGET/plugins/rolepod missing"
    elif have_cmd claude; then
      claude plugin list 2>/dev/null | grep -q rolepod \
        || warn "rolepod not in 'claude plugin list' — restart Claude Code, check /plugin."
    fi
    ok "rolepod installed → plugin (skills + SessionStart hook; no rules/ copy)"
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
  # The repo root IS the Codex marketplace — .agents/plugins/marketplace.json
  # + the committed plugins/rolepod-codex/ tree. `codex plugin marketplace add`
  # consumes the repo directly. AGENTS.md + agent .toml staging stay under
  # build/rendered/codex/ (gitignored — used only by this installer).
  CODEX_PLUGIN_SRC="$REPO_DIR/plugins/rolepod-codex"
  echo ""
  echo "${BOLD}─── Installing for Codex CLI ───${NC}"
  echo "  target:                $CODEX_TARGET"
  if [ "$SCOPE" = "project" ]; then
    echo "  mode:                  project-scope (managed AGENTS.md only — global config NOT mutated)"
  else
    echo "  marketplace source:    $REPO_DIR"
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
  [ -f "$REPO_DIR/.agents/plugins/marketplace.json" ]                 || fail "expected marketplace manifest after render"
  [ -d "$CODEX_PLUGIN_SRC/.codex-plugin" ]                    || fail "expected plugins/rolepod/.codex-plugin/ after render"
  [ -d "$RENDERED_CODEX_DIR/agents" ]                                           || fail "expected agents/ after render (outside plugin tree)"
  [ -d "$CODEX_PLUGIN_SRC/hooks" ]                            || fail "expected plugins/rolepod/hooks/ after render"
  [ -d "$CODEX_PLUGIN_SRC/skills" ]                           || fail "expected plugins/rolepod/skills/ after render"

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
    dry "chmod +x $CODEX_PLUGIN_SRC/hooks/*.sh"
  else
    chmod +x "$CODEX_PLUGIN_SRC/hooks"/*.sh 2>/dev/null || true
  fi

  if have_cmd codex && [ "$CODEX_IS_TEMP_TARGET" -eq 0 ]; then
    # Real install path — codex commands write to $HOME/.codex/config.toml.
    # Backup config.toml before any modification (reversible).
    if [ -f "$CODEX_CONFIG" ] && [ "$DRY_RUN" -eq 0 ]; then
      STAMP=$(date +%Y%m%d-%H%M%S)
      cp "$CODEX_CONFIG" "$CODEX_CONFIG.rolepod-bak.$STAMP" 2>/dev/null || true
    fi

    # The rolepod repo is a Codex marketplace published on GitHub. install.sh
    # registers it from GitHub (codex plugin marketplace add nuttaruj/rolepod)
    # so `codex plugin marketplace upgrade` works and the source matches a
    # manual install. `codex plugin add` then installs the plugin — Codex
    # clones the git source into its own cache and records the install; no
    # manual config.toml [plugins.*] edit, no manual cache copy.
    CODEX_MARKETPLACE_REF="nuttaruj/rolepod"
    if [ -f "$CODEX_CONFIG" ] && grep -q '^\[marketplaces\.rolepod\]' "$CODEX_CONFIG" 2>/dev/null; then
      if [ "$FORCE" -eq 1 ]; then
        step "Re-registering rolepod marketplace from GitHub (--force)"
        if [ "$DRY_RUN" -eq 1 ]; then
          dry "codex plugin marketplace remove rolepod && codex plugin marketplace add $CODEX_MARKETPLACE_REF"
        else
          codex plugin marketplace remove rolepod >/dev/null 2>&1 || true
          if ! codex plugin marketplace add "$CODEX_MARKETPLACE_REF" 2>&1 | sed 's/^/    /'; then
            fail "codex plugin marketplace add failed — see output above"
          fi
        fi
      else
        # The rolepod marketplace is already registered (e.g. a prior
        # `codex plugin marketplace add nuttaruj/rolepod`). Keep it untouched —
        # do not re-point or re-fetch it — and install only the pieces the
        # marketplace cannot carry: the 18 agents + the AGENTS.md block.
        # `--force` re-registers the marketplace from GitHub instead.
        step "rolepod marketplace already registered — keeping it; installing agents + AGENTS.md only"
        warn "  Marketplace left as-is. To re-register from GitHub: ./install.sh --target=codex --force"
        CODEX_KEEP_MARKETPLACE=1
      fi
    else
      step "Registering rolepod marketplace from GitHub"
      if [ "$DRY_RUN" -eq 1 ]; then
        dry "codex plugin marketplace add $CODEX_MARKETPLACE_REF"
      else
        if ! codex plugin marketplace add "$CODEX_MARKETPLACE_REF" 2>&1 | sed 's/^/    /'; then
          fail "codex plugin marketplace add failed — see output above"
        fi
      fi
    fi

    # Install the plugin. `codex plugin add` clones the marketplace's git
    # source into the plugin cache and records the install — it replaces the
    # older manual config.toml [plugins.*] enable + manual cache copy. Skipped
    # in keep-marketplace mode (the plugin is already installed).
    if [ "${CODEX_KEEP_MARKETPLACE:-0}" -eq 1 ]; then
      skip "Codex plugin install — already installed; keeping it"
    else
      step "Installing rolepod plugin (codex plugin add)"
      if [ "$DRY_RUN" -eq 1 ]; then
        dry "codex plugin add rolepod@rolepod"
      else
        if ! codex plugin add rolepod@rolepod 2>&1 | sed 's/^/    /'; then
          fail "codex plugin add failed — see output above"
        fi
      fi
    fi

    # Codex reads agent TOMLs from ~/.codex/agents/ (global) — NOT from plugin
    # bundle. The plugin.json `agents` field is not in the Codex schema and is
    # silently ignored. We copy rolepod's 18 agent TOMLs with a "rolepod-"
    # filename prefix so they (a) don't collide with user-authored agents and
    # (b) can be cleanly removed on uninstall via glob match.
    AGENTS_DEST="$CODEX_TARGET/agents"
    step "Installing 18 rolepod agents → $AGENTS_DEST/rolepod-*.toml"
    if [ "$DRY_RUN" -eq 1 ]; then
      dry "mkdir -p $AGENTS_DEST && copy *.toml from rendered agents/ with rolepod- prefix"
    else
      mkdir -p "$AGENTS_DEST"
      copied=0
      for f in "$RENDERED_CODEX_DIR/agents"/*.toml; do
        [ -f "$f" ] || continue
        cp "$f" "$AGENTS_DEST/rolepod-$(basename "$f")" 2>/dev/null && copied=$((copied+1))
      done
      ok "rolepod agents installed → $AGENTS_DEST/rolepod-*.toml (count: $copied)"
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
      warn "  After install, run: codex plugin marketplace add $REPO_DIR"
    fi
    step "Copying rendered plugin tree → $CODEX_TARGET/plugins/rolepod (filesystem only — Codex loader resolves from rendered dir)"
    if [ "$DRY_RUN" -eq 1 ]; then
      dry "rm -rf $CODEX_TARGET/plugins/rolepod && mkdir -p $CODEX_TARGET/plugins/rolepod && cp -R $CODEX_PLUGIN_SRC/. $CODEX_TARGET/plugins/rolepod/"
    else
      rm -rf "$CODEX_TARGET/plugins/rolepod" 2>/dev/null || true
      mkdir -p "$CODEX_TARGET/plugins/rolepod"
      cp -R "$CODEX_PLUGIN_SRC/." "$CODEX_TARGET/plugins/rolepod/" 2>/dev/null || true
    fi

    # Mirror the agent copy in the temp-target / no-binary path so smoke tests
    # and offline installs land 18 agent TOMLs at $CODEX_TARGET/agents/. Safe
    # because $CODEX_TARGET is per definition NOT $HOME/.codex here.
    AGENTS_DEST="$CODEX_TARGET/agents"
    step "Installing 18 rolepod agents → $AGENTS_DEST/rolepod-*.toml"
    if [ "$DRY_RUN" -eq 1 ]; then
      dry "mkdir -p $AGENTS_DEST && copy *.toml from rendered agents/ with rolepod- prefix"
    else
      mkdir -p "$AGENTS_DEST"
      copied=0
      for f in "$RENDERED_CODEX_DIR/agents"/*.toml; do
        [ -f "$f" ] || continue
        cp "$f" "$AGENTS_DEST/rolepod-$(basename "$f")" 2>/dev/null && copied=$((copied+1))
      done
      ok "rolepod agents installed → $AGENTS_DEST/rolepod-*.toml (count: $copied)"
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
      # Confirm the committed marketplace tree is intact in the repo.
      [ -f "$REPO_DIR/.agents/plugins/marketplace.json" ] || fail "Codex verification failed — committed marketplace manifest missing"
      # The plugin install is verified by the `codex plugin add` step above —
      # it fails the install hard on any error. A post-hoc `codex plugin list`
      # check is intentionally omitted: the list can lag right after
      # `plugin add` and produce a false negative.
      # No agents/ check here — Codex's plugin loader has no agents field; the
      # 18 agent TOMLs install to ~/.codex/agents/ (verified separately).
      ok "rolepod codex marketplace registered (GitHub) → $CODEX_CONFIG"
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
  else
    do_or_dry "rm -rf $GEMINI_EXT_DEST/skills (stale legacy skill cleanup)" \
      rm -rf "$GEMINI_EXT_DEST/skills"
  fi

  step "Copying extension tree → $GEMINI_EXT_DEST/"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "cp -R $RENDERED_GEMINI_DIR/. → $GEMINI_EXT_DEST/ (incl. GEMINI.md context file)"
  else
    cp -R "$RENDERED_GEMINI_DIR/." "$GEMINI_EXT_DEST/" 2>/dev/null || true
    # GEMINI.md ships INSIDE the extension dir. Gemini auto-loads it via the
    # extension's contextFileName, so rolepod's context never touches the
    # user's global ~/.gemini/GEMINI.md.
  fi

  # Migration: older installs wrote a rolepod managed block into the global
  # ~/.gemini/GEMINI.md. The entry doc now lives in the extension dir, so
  # strip any stale global block left behind by a pre-PR-8 install.
  step "Stripping stale rolepod block from global $GEMINI_TARGET/GEMINI.md (migration)"
  remove_managed_block "$GEMINI_TARGET/GEMINI.md"

  step "Marking hook scripts executable"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "chmod +x $GEMINI_EXT_DEST/hooks/*.sh"
  else
    chmod +x "$GEMINI_EXT_DEST/hooks"/*.sh 2>/dev/null || true
  fi

  if [ "$DRY_RUN" -eq 0 ]; then
    step "Verifying Gemini install"
    for required in \
      extensions/rolepod/GEMINI.md \
      extensions/rolepod/gemini-extension.json \
      extensions/rolepod/hooks/hooks.json \
      extensions/rolepod/skills/using-rolepod/SKILL.md \
      extensions/rolepod/skills/debug-issue/SKILL.md
    do
      [ -e "$GEMINI_TARGET/$required" ] || fail "Gemini verification failed — $GEMINI_TARGET/$required missing"
    done
    ok "rolepod gemini extension installed → $GEMINI_EXT_DEST"
    ok "GEMINI.md (extension context file) → $GEMINI_EXT_DEST/GEMINI.md"
  else
    skip "Gemini verification skipped (dry-run)"
  fi
  fi  # end GEMINI_PROJECT_DONE guard
fi

# ─── install_cursor — Cursor IDE path (~/.cursor/) ─────────────────────
# Cursor loads local plugins from ~/.cursor/plugins/local/<plugin-name>/
# (per Cursor docs: cursor.com/docs/plugins). We copy the committed
# plugins/rolepod-cursor/ tree there. Cursor auto-discovers the plugin on
# next session start; no marketplace install command is required for local
# install. The plugin's rules/always-on-core.mdc (alwaysApply: true)
# delivers the always-on judgment core without touching user-global config.
if cursor_selected; then
  CURSOR_TARGET="$(resolve_target_for cursor)"
  CURSOR_PLUGIN_DEST="$CURSOR_TARGET/plugins/local/rolepod"
  echo ""
  echo "${BOLD}─── Installing for Cursor ───${NC}"
  echo "  target:        $CURSOR_TARGET"
  echo "  plugin dest:   $CURSOR_PLUGIN_DEST"

  RENDERED_CURSOR_DIR="$REPO_DIR/plugins/rolepod-cursor"
  [ -d "$RENDERED_CURSOR_DIR" ] || fail "expected $RENDERED_CURSOR_DIR after render"
  [ -f "$RENDERED_CURSOR_DIR/.cursor-plugin/plugin.json" ] || fail "expected $RENDERED_CURSOR_DIR/.cursor-plugin/plugin.json after render"
  [ -d "$RENDERED_CURSOR_DIR/rules" ]                     || fail "expected $RENDERED_CURSOR_DIR/rules/ after render"
  [ -d "$RENDERED_CURSOR_DIR/skills" ]                    || fail "expected $RENDERED_CURSOR_DIR/skills/ after render"
  [ -d "$RENDERED_CURSOR_DIR/agents" ]                    || fail "expected $RENDERED_CURSOR_DIR/agents/ after render"
  [ -d "$RENDERED_CURSOR_DIR/hooks" ]                     || fail "expected $RENDERED_CURSOR_DIR/hooks/ after render"

  # Backup if --force on existing — rolepod-scoped only (the plugin's own dir).
  if [ "$FORCE" -eq 1 ] && [ -d "$CURSOR_PLUGIN_DEST" ]; then
    STAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP="${CURSOR_PLUGIN_DEST}.backup-$STAMP"
    warn "Backing up existing $CURSOR_PLUGIN_DEST → $BACKUP"
    do_or_dry "cp -R $CURSOR_PLUGIN_DEST $BACKUP" cp -R "$CURSOR_PLUGIN_DEST" "$BACKUP"
  fi

  step "Creating Cursor plugin directory"
  do_or_dry "mkdir -p $CURSOR_PLUGIN_DEST" mkdir -p "$CURSOR_PLUGIN_DEST"

  if [ "$FORCE" -eq 1 ]; then
    do_or_dry "rm -rf $CURSOR_PLUGIN_DEST && mkdir -p $CURSOR_PLUGIN_DEST" \
      bash -c "rm -rf '$CURSOR_PLUGIN_DEST' && mkdir -p '$CURSOR_PLUGIN_DEST'"
  fi

  step "Copying plugin tree → $CURSOR_PLUGIN_DEST/"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry "cp -R $RENDERED_CURSOR_DIR/. → $CURSOR_PLUGIN_DEST/"
  else
    cp -R "$RENDERED_CURSOR_DIR/." "$CURSOR_PLUGIN_DEST/" 2>/dev/null || true
    chmod +x "$CURSOR_PLUGIN_DEST/scripts/"*.sh 2>/dev/null || true
  fi

  if [ "$DRY_RUN" -eq 0 ]; then
    step "Verifying Cursor install"
    for required in \
      .cursor-plugin/plugin.json \
      rules/always-on-core.mdc \
      hooks/hooks.json \
      skills/using-rolepod/SKILL.md \
      skills/debug-issue/SKILL.md \
      agents/qa-tester.md \
      scripts/precommit-gate.sh
    do
      [ -e "$CURSOR_PLUGIN_DEST/$required" ] || fail "Cursor verification failed — $CURSOR_PLUGIN_DEST/$required missing"
    done
    ok "rolepod Cursor plugin installed → $CURSOR_PLUGIN_DEST"
    ok "always-on judgment core → $CURSOR_PLUGIN_DEST/rules/always-on-core.mdc (alwaysApply: true)"
  else
    skip "Cursor verification skipped (dry-run)"
  fi
fi

# Ensure TARGET is set for the rest of the script. Fallback only when
# claude wasn't selected at all.
if [ -z "${TARGET:-}" ]; then
  TARGET="$(default_target_path_for claude)"
  PLUGINS_DIR="$TARGET/plugins"
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
cat <<EOF
${BOLD}rolepod framework installed.${NC} (Pure framework — no 3rd-party add-ons bundled.)

Recommended add-ons (install separately — framework auto-integrates each):
  • Code intel    — CodeGraph, GitNexus
  • Memory        — MemPalace
  • Token cuts    — rtk, caveman
  • Design        — ui-ux-pro-max

See README → "Recommended add-ons" for install commands + integration notes.

EOF

echo ""
if [ "$SCOPE" = "project" ]; then
  case "$CLI_TARGET" in
    claude) echo "${BOLD}Final step${NC}: restart Claude Code in this project to load the rolepod workflow." ;;
    codex)  echo "${BOLD}Final step${NC}: Codex auto-loads $PWD/AGENTS.md when you run codex in this project." ;;
    gemini) echo "${BOLD}Final step${NC}: Gemini auto-loads $PWD/GEMINI.md when you run gemini in this project." ;;
    cursor) echo "${BOLD}Final step${NC}: restart Cursor in this project to load the rolepod plugin." ;;
    all)    echo "${BOLD}Final step${NC}: restart Claude Code + Cursor in this project; Codex/Gemini auto-load $PWD/AGENTS.md and $PWD/GEMINI.md." ;;
  esac
else
  case "$CLI_TARGET" in
    claude) echo "${BOLD}Final step${NC}: restart Claude Code so the hooks register." ;;
    codex)  echo "${BOLD}Final step${NC}: restart Codex CLI to load the new plugin."
            echo "  Hooks require opt-in: ${BOLD}codex features enable plugin_hooks${NC} (plugin_hooks is 'under development, false' by default; rolepod's hooks/hooks.json is inert without this flag)." ;;
    gemini) echo "${BOLD}Final step${NC}: restart Gemini CLI to load the new extension and hooks." ;;
    cursor) echo "${BOLD}Final step${NC}: restart Cursor (or reload window) so the plugin + rules register."
            echo "  Verify under Cursor → Settings → Features → Rules / Plugins." ;;
    all)    echo "${BOLD}Final step${NC}: restart Claude Code, Codex CLI, Gemini CLI, and Cursor."
            echo "  Codex hooks require opt-in: ${BOLD}codex features enable plugin_hooks${NC}." ;;
  esac
fi

# Post-install validation hint: best-practice from Claude Code docs.
# `/doctor` validates settings.json schema + flags broken hooks. `/hooks` lists
# registered hooks. `/mcp` lists connected MCP servers. Recommended after every
# install to catch misregistrations early.
case "$CLI_TARGET" in
  claude|all)
    echo ""
    echo "${BOLD}Validate config${NC} (run inside Claude Code):"
    echo "  ${CYAN}/doctor${NC}  — schema + hook validation"
    echo "  ${CYAN}/hooks${NC}   — list registered hooks"
    echo "  ${CYAN}/mcp${NC}     — list MCP servers"
    ;;
esac
