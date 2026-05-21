#!/bin/bash
# install-parity — verify Claude / Codex / Gemini × global / project install
# produces the artifacts each CLI's adapter promises, per docs/cli-support.md.
#
# Honest scope (matches README/docs):
#   Claude global    → marketplace plugin (~/.claude/plugins/) + CLAUDE.md block + rules/
#   Claude project   → filesystem plugin tree ($PWD/.claude/) + CLAUDE.md block + rules/
#   Codex global     → marketplace + plugin cache + AGENTS.md
#   Codex project    → rules-only ($PWD/AGENTS.md)
#   Gemini global    → extension + hooks + extension-local GEMINI.md
#   Gemini project   → rules-only ($PWD/GEMINI.md)
#
# Test coverage (matrix):
#   Claude global     ✓ always (uses ROLEPOD_TARGET into temp dir — no mutate to real ~/.claude)
#   Claude project    ✓ always (project-scope install lands under $PWD/.claude/)
#   Codex project     ✓ always (project-scope is rules-only — writes $PWD/AGENTS.md only)
#   Gemini project    ✓ always (project-scope is rules-only — writes $PWD/GEMINI.md only)
#   Codex global      gated by ROLEPOD_INTEGRATION_MUTATE=1 — codex CLI marketplace
#                     add MUTATES the real ~/.codex/config.toml; no Codex-equivalent
#                     of ROLEPOD_TARGET. Default = skip with clear message.
#   Gemini global     gated by ROLEPOD_INTEGRATION_MUTATE=1 — gemini CLI extension
#                     lands in real ~/.gemini/extensions/. Default = skip.
#
# To run the full 6-cell matrix locally:
#   ROLEPOD_INTEGRATION_MUTATE=1 bash tests/integration/run.sh install-parity
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

[ -f "./install.sh" ] || { echo "ERROR: install.sh missing in $REPO_DIR" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

# ─── Claude global into temp HOME ───────────────────────────────────────
# Temp target (ROLEPOD_TARGET diverges from ~/.claude) → install does the
# filesystem-only plugin-tree copy (the `claude plugin` CLI would mutate the
# real Claude home, so it is skipped). Expected layout: CLAUDE.md managed
# block + rules/ copy + plugins/rolepod/ tree. Hooks live INSIDE the plugin
# manifest, not in settings.json.
echo "[claude global] install into $TMP/.claude"
export ROLEPOD_TARGET="$TMP/.claude"
mkdir -p "$ROLEPOD_TARGET"
mkdir -p "$ROLEPOD_TARGET/skills/systematic-debugging"
cat > "$ROLEPOD_TARGET/skills/systematic-debugging/SKILL.md" <<'EOF'
---
name: systematic-debugging
tier: 3
redirect_to: debug-issue
---

Compatibility shim from an older rolepod install.
EOF
if ./install.sh --target=claude > "$TMP/claude.log" 2>&1; then
  PLUGIN_DIR="$ROLEPOD_TARGET/plugins/rolepod"
  required_paths=(
    "$ROLEPOD_TARGET/CLAUDE.md"
    "$ROLEPOD_TARGET/CHEATSHEET.md"
    "$ROLEPOD_TARGET/rules/always-on"
    "$ROLEPOD_TARGET/rules/code"
    "$PLUGIN_DIR/.claude-plugin/plugin.json"
    "$PLUGIN_DIR/agents"
    "$PLUGIN_DIR/skills"
    "$PLUGIN_DIR/hooks/lib/session_state.py"
  )
  for p in "${required_paths[@]}"; do
    if [ ! -e "$p" ]; then
      echo "  ✗ missing: $p"
      FAIL=$((FAIL+1))
    fi
  done
  # Core 10 skills land inside the plugin tree, not ~/.claude/skills/.
  for skill in using-rolepod debug-issue check-work rolepod-full; do
    if [ ! -d "$PLUGIN_DIR/skills/$skill" ]; then
      echo "  ✗ skill missing from plugin: $skill"
      FAIL=$((FAIL+1))
    fi
  done
  skill_count=$(find "$PLUGIN_DIR/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  if [ "$skill_count" -ne 11 ]; then
    echo "  ✗ expected exactly 11 plugin skills (Core 10 + rolepod-full alias), got $skill_count"
    FAIL=$((FAIL+1))
  fi
  # Migration must clean a pre-2.0 legacy shim skill from ~/.claude/skills/.
  if [ -d "$ROLEPOD_TARGET/skills/systematic-debugging" ]; then
    echo "  ✗ stale legacy skill survived migration: systematic-debugging"
    FAIL=$((FAIL+1))
  fi
  # Hooks live in the plugin's hooks/hooks.json (canonical form) — NOT in
  # settings.json, NOT inline in plugin.json.
  if [ ! -f "$PLUGIN_DIR/hooks/hooks.json" ]; then
    echo "  ✗ plugin hooks/hooks.json missing"
    FAIL=$((FAIL+1))
  else
    for hook in project-context-loader gate-reminder precommit-gate block-subagent-commit cohesion-contract-check session-lifecycle; do
      if ! grep -q "$hook" "$PLUGIN_DIR/hooks/hooks.json"; then
        echo "  ✗ hook not in hooks/hooks.json: $hook"
        FAIL=$((FAIL+1))
      fi
    done
  fi
  if [ -f "$ROLEPOD_TARGET/settings.json" ] && grep -q '/hooks/gate-reminder.sh' "$ROLEPOD_TARGET/settings.json" 2>/dev/null; then
    echo "  ✗ rolepod hook entry leaked into settings.json (should be plugin-only)"
    FAIL=$((FAIL+1))
  fi
  if [ "$FAIL" -eq 0 ]; then
    echo "  ✓ Claude global: CLAUDE.md block + rules/ + plugin tree (agents/skills/hooks) + plugin hooks/hooks.json + legacy migration"
    PASS=$((PASS+1))
  fi
else
  echo "  ✗ install failed (see $TMP/claude.log)"
  FAIL=$((FAIL+1))
fi
unset ROLEPOD_TARGET

# ─── Claude project (--scope=project) ───────────────────────────────────
# Project target ($PWD/.claude) diverges from ~/.claude → same filesystem-only
# plugin-tree copy as the temp-target global path.
echo ""
echo "[claude project] install into $TMP/project/.claude"
mkdir -p "$TMP/project"
( cd "$TMP/project" && "$REPO_DIR/install.sh" --target=claude --scope=project > "$TMP/claude-project.log" 2>&1 ) || {
  echo "  ✗ install failed (see $TMP/claude-project.log)"
  FAIL=$((FAIL+1))
}
if [ -f "$TMP/project/.claude/CLAUDE.md" ] && [ -d "$TMP/project/.claude/rules" ] && [ -f "$TMP/project/.claude/plugins/rolepod/.claude-plugin/plugin.json" ]; then
  echo "  ✓ Claude project: .claude/CLAUDE.md + .claude/rules/ + .claude/plugins/rolepod/ tree under \$PWD/.claude/"
  PASS=$((PASS+1))
else
  echo "  ✗ Claude project: expected files missing under \$PWD/.claude/"
  FAIL=$((FAIL+1))
fi

# ─── Codex project (--scope=project, rules-only) ────────────────────────
echo ""
echo "[codex project] install into $TMP/codex-proj"
mkdir -p "$TMP/codex-proj"
( cd "$TMP/codex-proj" && "$REPO_DIR/install.sh" --target=codex --scope=project > "$TMP/codex-project.log" 2>&1 ) || {
  echo "  ✗ install failed (see $TMP/codex-project.log)"
  FAIL=$((FAIL+1))
}
if [ -f "$TMP/codex-proj/AGENTS.md" ]; then
  # Rules-only: no native plugin tree at $PWD/.codex/
  if [ ! -d "$TMP/codex-proj/.codex/agents" ]; then
    echo "  ✓ Codex project: AGENTS.md present, native plugin NOT installed (correct per docs)"
    PASS=$((PASS+1))
  else
    echo "  ✗ Codex project: native plugin tree appeared at $TMP/codex-proj/.codex/ — should be rules-only"
    FAIL=$((FAIL+1))
  fi
else
  echo "  ✗ Codex project: AGENTS.md missing"
  FAIL=$((FAIL+1))
fi

# ─── Gemini project (--scope=project, rules-only) ───────────────────────
echo ""
echo "[gemini project] install into $TMP/gemini-proj"
mkdir -p "$TMP/gemini-proj"
( cd "$TMP/gemini-proj" && "$REPO_DIR/install.sh" --target=gemini --scope=project > "$TMP/gemini-project.log" 2>&1 ) || {
  echo "  ✗ install failed (see $TMP/gemini-project.log)"
  FAIL=$((FAIL+1))
}
if [ -f "$TMP/gemini-proj/GEMINI.md" ]; then
  if [ ! -d "$TMP/gemini-proj/.gemini/extensions/rolepod" ]; then
    echo "  ✓ Gemini project: GEMINI.md present, extension NOT installed (correct per docs)"
    PASS=$((PASS+1))
  else
    echo "  ✗ Gemini project: extension tree appeared — should be rules-only"
    FAIL=$((FAIL+1))
  fi
else
  echo "  ✗ Gemini project: GEMINI.md missing"
  FAIL=$((FAIL+1))
fi

# ─── Codex global (gated — mutates real ~/.codex/config.toml) ───────────
echo ""
if [ "${ROLEPOD_INTEGRATION_MUTATE:-0}" = "1" ]; then
  if command -v codex >/dev/null 2>&1; then
    echo "[codex global] install via codex marketplace add (MUTATES ~/.codex/config.toml)"
    if ./install.sh --target=codex > "$TMP/codex-global.log" 2>&1; then
      # Per docs/cli-support.md: marketplace registered + plugin cache populated
      # + [plugins."rolepod@rolepod"] enabled = true + ~/.codex/AGENTS.md present.
      ok=1
      grep -q '^\[marketplaces\.rolepod\]' "$HOME/.codex/config.toml" 2>/dev/null || { echo "  ✗ [marketplaces.rolepod] not in ~/.codex/config.toml"; ok=0; }
      grep -q '^\[plugins\."rolepod@rolepod"\]' "$HOME/.codex/config.toml" 2>/dev/null || { echo "  ✗ [plugins.\"rolepod@rolepod\"] not in ~/.codex/config.toml"; ok=0; }
      ls "$HOME/.codex/plugins/cache/rolepod/rolepod/"*/skills >/dev/null 2>&1 || { echo "  ✗ plugin cache skills/ not populated"; ok=0; }
      [ -f "$HOME/.codex/AGENTS.md" ] || { echo "  ✗ ~/.codex/AGENTS.md missing"; ok=0; }
      if [ "$ok" -eq 1 ]; then
        echo "  ✓ Codex global: marketplace + plugin cache + AGENTS.md"
        PASS=$((PASS+1))
      else
        FAIL=$((FAIL+1))
      fi
    else
      echo "  ✗ install failed (see $TMP/codex-global.log)"
      FAIL=$((FAIL+1))
    fi
  else
    echo "[codex global] SKIP — codex CLI not on PATH"
  fi
else
  echo "[codex global] SKIP — ROLEPOD_INTEGRATION_MUTATE=1 required (mutates real ~/.codex/config.toml)"
fi

# ─── Gemini global (gated — mutates real ~/.gemini/extensions) ──────────
echo ""
if [ "${ROLEPOD_INTEGRATION_MUTATE:-0}" = "1" ]; then
  if command -v gemini >/dev/null 2>&1; then
    echo "[gemini global] install (MUTATES ~/.gemini/)"
    if ./install.sh --target=gemini > "$TMP/gemini-global.log" 2>&1; then
      ok=1
      [ -d "$HOME/.gemini/extensions/rolepod" ] || { echo "  ✗ ~/.gemini/extensions/rolepod missing"; ok=0; }
      [ -f "$HOME/.gemini/extensions/rolepod/gemini-extension.json" ] || { echo "  ✗ gemini-extension.json missing"; ok=0; }
      [ -f "$HOME/.gemini/extensions/rolepod/GEMINI.md" ] || { echo "  ✗ extensions/rolepod/GEMINI.md missing"; ok=0; }
      if [ "$ok" -eq 1 ]; then
        echo "  ✓ Gemini global: extension tree + extension-local GEMINI.md"
        PASS=$((PASS+1))
      else
        FAIL=$((FAIL+1))
      fi
    else
      echo "  ✗ install failed (see $TMP/gemini-global.log)"
      FAIL=$((FAIL+1))
    fi
  else
    echo "[gemini global] SKIP — gemini CLI not on PATH"
  fi
else
  echo "[gemini global] SKIP — ROLEPOD_INTEGRATION_MUTATE=1 required (mutates real ~/.gemini/)"
fi

# ─── Summary ────────────────────────────────────────────────────────────
echo ""
echo "install-parity: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
