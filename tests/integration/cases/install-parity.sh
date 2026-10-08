#!/bin/bash
# install-parity — verify Claude / Codex × global / project install
# produces the artifacts each CLI's adapter promises, per docs/cli-support.md.
# Antigravity (agy) coverage lives in antigravity-adapter.sh; Gemini CLI
# support was removed in v2.177.0 (Google moved consumers to Antigravity).
#
# Honest scope (matches README/docs):
#   Claude global    → marketplace plugin (~/.claude/plugins/) + path-scoped rules/
#   Claude project   → filesystem plugin tree ($PWD/.claude/) + path-scoped rules/
#   Codex global     → marketplace + plugin cache + AGENTS.md
#   Codex project    → rules-only ($PWD/AGENTS.md)
#
# Test coverage (matrix):
#   Claude global     ✓ always (uses ROLEPOD_TARGET into temp dir — no mutate to real ~/.claude)
#   Claude project    ✓ always (project-scope install lands under $PWD/.claude/)
#   Codex project     ✓ always (project-scope is rules-only — writes $PWD/AGENTS.md only)
#   Codex global      gated by ROLEPOD_INTEGRATION_MUTATE=1 — codex CLI marketplace
#                     add MUTATES the real ~/.codex/config.toml; no Codex-equivalent
#                     of ROLEPOD_TARGET. Default = skip with clear message.
#   gemini            ✓ always — --target=gemini prints the removal notice and exits 1
#
# To run the full matrix locally:
#   ROLEPOD_INTEGRATION_MUTATE=1 bash tests/integration/run.sh install-parity
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

[ -f "./install.sh" ] || { echo "ERROR: install.sh missing in $REPO_DIR" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# install.sh anchors its backup directory to ${HOME} even when the install
# TARGET is a temp dir, so a --force run against a temp target still writes
# into the real ~/.rolepod/backups. Point HOME at a throwaway dir for those
# invocations so the suite leaves no trace in the developer's home.
FAKE_HOME="$TMP/fakehome"
mkdir -p "$FAKE_HOME"
export HOME="$FAKE_HOME"   # every section installs into a throwaway home: a test must never write the real ~/.rolepod/config.json

PASS=0
FAIL=0

# ─── Claude global into temp HOME ───────────────────────────────────────
# Temp target (ROLEPOD_TARGET diverges from ~/.claude) → install does the
# filesystem-only plugin-tree copy (the `claude plugin` CLI would mutate the
# real Claude home, so it is skipped). Expected layout: a plugins/rolepod/
# tree and NOTHING else — no CLAUDE.md managed block, no rules/ copy.
# Path-scoped guidance is folded into the skills, always-on into the
# SessionStart hook. Hooks live INSIDE the plugin manifest, not settings.json.
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
    "$ROLEPOD_TARGET/CHEATSHEET.md"
    "$PLUGIN_DIR/.claude-plugin/plugin.json"
    "$PLUGIN_DIR/agents"
    "$PLUGIN_DIR/skills"
    "$PLUGIN_DIR/hooks/lib/session_state.py"
    "$PLUGIN_DIR/hooks/always-on-core.md"
  )
  for p in "${required_paths[@]}"; do
    if [ ! -e "$p" ]; then
      echo "  ✗ missing: $p"
      FAIL=$((FAIL+1))
    fi
  done
  # Pure plugin — no managed CLAUDE.md block, no rules/ copy at all.
  # Path-scoped guidance is in the skills; always-on is in the hook.
  if [ -e "$ROLEPOD_TARGET/CLAUDE.md" ]; then
    echo "  ✗ CLAUDE.md should not be written (pure plugin — no managed block)"
    FAIL=$((FAIL+1))
  fi
  for forbidden in rules/always-on rules/code rules/test; do
    if [ -e "$ROLEPOD_TARGET/$forbidden" ]; then
      echo "  ✗ $forbidden should not be installed (skills + hook carry it)"
      FAIL=$((FAIL+1))
    fi
  done
  # Core 10 skills land inside the plugin tree, not ~/.claude/skills/.
  for skill in using-rolepod debug-issue check-work; do
    if [ ! -d "$PLUGIN_DIR/skills/$skill" ]; then
      echo "  ✗ skill missing from plugin: $skill"
      FAIL=$((FAIL+1))
    fi
  done
  skill_count=$(find "$PLUGIN_DIR/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  if [ "$skill_count" -ne 20 ]; then
    echo "  ✗ expected exactly 20 plugin skills (the 19 phase/helper skills + rolepod-stats), got $skill_count"
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
    for hook in session-start gate-reminder precommit-gate block-subagent-commit session-lifecycle; do
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
    echo "  ✓ Claude global: path-scoped rules/ + plugin tree (agents/skills/hooks) + plugin hooks/hooks.json + no CLAUDE.md block + legacy migration"
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
if [ ! -e "$TMP/project/.claude/CLAUDE.md" ] && [ ! -e "$TMP/project/.claude/rules" ] && [ -f "$TMP/project/.claude/plugins/rolepod/.claude-plugin/plugin.json" ]; then
  echo "  ✓ Claude project: .claude/plugins/rolepod/ tree under \$PWD/.claude/ (no CLAUDE.md block, no rules/ copy)"
  PASS=$((PASS+1))
else
  echo "  ✗ Claude project: plugin tree missing, or CLAUDE.md / rules/ wrongly written, under \$PWD/.claude/"
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

# ─── --target=gemini (removed v2.177.0) — notice + rc 1 ─────────────────
echo ""
echo "[gemini] install.sh --target=gemini"
gemini_rc=0
gemini_out=$(bash "$REPO_DIR/install.sh" --target=gemini 2>&1) || gemini_rc=$?
if [ "$gemini_rc" -eq 1 ] && printf '%s' "$gemini_out" | grep -q 'removed in v2.177.0'; then
  echo "  ✓ --target=gemini: removal notice + exit 1"
  PASS=$((PASS+1))
else
  echo "  ✗ --target=gemini: expected exit 1 + 'removed in v2.177.0', got rc=$gemini_rc out=${gemini_out:0:200}"
  FAIL=$((FAIL+1))
fi

# ─── Cursor global into temp target ─────────────────────────────────────
# Cursor install is filesystem-only (copy the committed plugins/rolepod-cursor/
# tree into <CURSOR_TARGET>/plugins/local/rolepod/). No CLI mutation, so this
# runs by default with ROLEPOD_CURSOR_TARGET pointed at a temp dir.
echo ""
echo "[cursor global] install into $TMP/cursor/.cursor"
export ROLEPOD_CURSOR_TARGET="$TMP/cursor/.cursor"
mkdir -p "$ROLEPOD_CURSOR_TARGET"
if ./install.sh --target=cursor > "$TMP/cursor.log" 2>&1; then
  PLUGIN_DEST="$ROLEPOD_CURSOR_TARGET/plugins/local/rolepod"
  required_paths=(
    "$PLUGIN_DEST/.cursor-plugin/plugin.json"
    "$PLUGIN_DEST/rules/always-on-core.mdc"
    "$PLUGIN_DEST/hooks/hooks.json"
    "$PLUGIN_DEST/scripts/precommit-gate.sh"
    "$PLUGIN_DEST/skills/using-rolepod/SKILL.md"
    "$PLUGIN_DEST/agents/rolepod-qa.md"
  )
  cursor_fail=0
  for p in "${required_paths[@]}"; do
    if [ ! -e "$p" ]; then
      echo "  ✗ missing: $p"
      cursor_fail=1
    fi
  done
  # Exactly 20 skills (the 19 phase/helper skills + rolepod-stats) — same as Claude.
  skill_count=$(find "$PLUGIN_DEST/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  if [ "$skill_count" -ne 20 ]; then
    echo "  ✗ expected 20 cursor skills (the 19 phase/helper skills + rolepod-stats), got $skill_count"
    cursor_fail=1
  fi
  # Exactly 4 agents.
  agent_count=$(find "$PLUGIN_DEST/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$agent_count" -ne 4 ]; then
    echo "  ✗ expected 4 cursor agents, got $agent_count"
    cursor_fail=1
  fi
  # Always-on rule must carry alwaysApply: true.
  if ! grep -q '^alwaysApply: true' "$PLUGIN_DEST/rules/always-on-core.mdc" 2>/dev/null; then
    echo "  ✗ rules/always-on-core.mdc missing 'alwaysApply: true'"
    cursor_fail=1
  fi
  if [ "$cursor_fail" -eq 0 ]; then
    echo "  ✓ Cursor global: plugin tree (rules/ + skills/ + agents/ + hooks/ + scripts/) under <target>/plugins/local/rolepod/"
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
  fi
else
  echo "  ✗ install failed (see $TMP/cursor.log)"
  FAIL=$((FAIL+1))
fi
unset ROLEPOD_CURSOR_TARGET

# ─── Codex global into temp target ──────────────────────────────────────
# CODEX_IS_TEMP_TARGET is derived by path comparison against $HOME/.codex
# (install.sh), so a temp target reaches the offline/temp branch — plugin
# tree copy + install_codex_agents() — without touching the real ~/.codex.
# This was the audit-surfaced gap: no default-suite test executed the codex
# agent-install block at all (codex --scope=project returns before it).
echo ""
echo "[codex global] install into $TMP/codex/.codex"
export ROLEPOD_CODEX_TARGET="$TMP/codex/.codex"
mkdir -p "$ROLEPOD_CODEX_TARGET"
# HOME override: this is the only default-suite install that passes --force
# into a pre-existing target, so it is the only one that stamps a backup.
if HOME="$FAKE_HOME" ./install.sh --target=codex --force > "$TMP/codex-global.log" 2>&1; then
  # install.sh re-renders, so a fixture agent cannot ride through it: run the
  # install function alone on a fixture dir that already carries a rolepod- name.
  FX="$TMP/codex-prefix-fx"; mkdir -p "$FX/agents"
  printf 'name = "x"\n' > "$FX/agents/rolepod-x.toml"; printf 'name = "y"\n' > "$FX/agents/y.toml"
  (
    step() { :; }; ok() { :; }; DRY_RUN=0; REPO_DIR="$REPO_DIR"; RENDERED_CODEX_DIR="$FX"
    eval "$(sed -n '/^install_codex_agents() {/,/^}/p' "${ROLEPOD_INSTALL_SRC:-$REPO_DIR/install.sh}")"
    install_codex_agents "$FX/dest"
  ) >/dev/null 2>&1
  if [ -f "$FX/dest/rolepod-x.toml" ] && [ -f "$FX/dest/rolepod-y.toml" ] && [ ! -e "$FX/dest/rolepod-rolepod-x.toml" ]; then
    echo "  ✓ codex install: rolepod-x.toml keeps its name, y.toml gets the prefix"
  else
    echo "  ✗ codex install: prefix not idempotent (rolepod-x.toml → rolepod-rolepod-x.toml)"
    FAIL=$((FAIL+1))
  fi
  AGENT_TOML_COUNT=$(find "$ROLEPOD_CODEX_TARGET/agents" -name 'rolepod-*.toml' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$AGENT_TOML_COUNT" -eq 4 ]; then
    echo "  ✓ codex temp-target install lands 4 rolepod-*.toml agents"
  else
    echo "  ✗ codex temp-target agents: expected 4, got $AGENT_TOML_COUNT"
    FAIL=$((FAIL+1))
  fi
  # A14: no doubled prefix, a user's own toml survives a re-install over old rolepod tomls
  printf 'name = "mine"\n' > "$ROLEPOD_CODEX_TARGET/agents/mine.toml"
  printf 'name = "old"\n' > "$ROLEPOD_CODEX_TARGET/agents/rolepod-qa-tester.toml"
  HOME="$FAKE_HOME" ./install.sh --target=codex --force > "$TMP/codex-global2.log" 2>&1 || true
  if [ -z "$(find "$ROLEPOD_CODEX_TARGET/agents" -name 'rolepod-rolepod-*.toml' 2>/dev/null)" ] \
     && [ ! -e "$ROLEPOD_CODEX_TARGET/agents/rolepod-qa-tester.toml" ] \
     && [ -f "$ROLEPOD_CODEX_TARGET/agents/mine.toml" ]; then
    echo "  ✓ codex reinstall: no rolepod-rolepod-*, old toml gone, user toml kept (A14)"
  else
    echo "  ✗ codex reinstall: leftover or lost file (A14)"
    FAIL=$((FAIL+1))
  fi
  if [ -e "$ROLEPOD_CODEX_TARGET/plugins/rolepod/hooks/precommit-gate.sh" ]; then
    echo "  ✓ codex plugin tree copied (hooks present)"
  else
    echo "  ✗ codex plugin tree missing hooks/precommit-gate.sh"
    FAIL=$((FAIL+1))
  fi
else
  echo "  ✗ codex temp-target install failed (see $TMP/codex-global.log)"
  FAIL=$((FAIL+1))
fi
unset ROLEPOD_CODEX_TARGET

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

# ─── The machine setting survives uninstall + install ────────────────────
# ~/.rolepod/config.json is the user's workflow profile + independent pool.
# Explicit --force reinstall resets workflow to Lite and preserves pool.
echo "[machine setting] --force migrates profile and preserves pool"
CFG_HOME="$TMP/cfghome"; mkdir -p "$CFG_HOME/.rolepod"
printf '{"gates":{"mode":"hard"},"pool":{"reviewer":{"review":"codex agy"}}}\n' > "$CFG_HOME/.rolepod/config.json"
CFG_TARGET="$TMP/.claude-cfg"; mkdir -p "$CFG_TARGET"
ok=1
HOME="$CFG_HOME" ROLEPOD_TARGET="$CFG_TARGET" ./install.sh --target=claude --force > "$TMP/cfg-install1.log" 2>&1 || { echo "  ✗ first install failed (see $TMP/cfg-install1.log)"; ok=0; }
[ -f "$CFG_TARGET/plugins/rolepod/skills/cross-family/scripts/rolepod_config.py" ] || { echo "  ✗ the installed cross-family skill has no pool reader beside its runner"; ok=0; }
[ -f "$CFG_TARGET/plugins/rolepod/skills/using-rolepod/scripts/rolepod_config.py" ] || { echo "  ✗ using-rolepod is missing its canonical reader bundle"; ok=0; }
[ -f "$CFG_TARGET/plugins/rolepod/skills/using-rolepod/scripts/session-mode.sh" ] || { echo "  ✗ using-rolepod is missing its session profile reader"; ok=0; }
for _s in write-plan implement-plan; do
  [ -f "$CFG_TARGET/plugins/rolepod/skills/$_s/scripts/session-mode.sh" ] || { echo "  ✗ $_s is missing its session profile reader"; ok=0; }
  [ -f "$CFG_TARGET/plugins/rolepod/skills/$_s/scripts/rolepod_config.py" ] || { echo "  ✗ $_s is missing its canonical reader bundle"; ok=0; }
done
for _s in write-spec write-plan manage-context check-work finish-work implement-plan; do
  [ -f "$CFG_TARGET/plugins/rolepod/skills/$_s/scripts/docs-mode.sh" ] || { echo "  ✗ $_s is missing its docs mode helper"; ok=0; }
done
# docs-mode.sh rides beside every rendered session-mode.sh (adapter libs + the gate's lib).
_sm_list=$(find build/rendered plugins -name session-mode.sh -not -path '*/using-rolepod/*' 2>/dev/null)
[ -n "$_sm_list" ] || { echo "  ✗ no rendered session-mode.sh found to pair docs-mode.sh with"; ok=0; }
for _sm in $_sm_list; do
  [ -f "$(dirname "$_sm")/docs-mode.sh" ] || { echo "  ✗ docs-mode.sh missing beside $_sm"; ok=0; }
done
HOME="$CFG_HOME" bash "$CFG_TARGET/plugins/rolepod/skills/using-rolepod/scripts/workflow-mode.sh" | grep -qx lite || { echo "  ✗ installed workflow-mode helper does not read bundled reader"; ok=0; }
mkdir -p "$CFG_HOME/.rolepod/session-profiles/codex"
cp "$CFG_HOME/.rolepod/config.json" "$TMP/config-before-session-flip"
printf 'full\nproject\n' > "$CFG_HOME/.rolepod/session-profiles/codex/spot-session.mode"
printf 'standard\nproject\n' > "$CFG_HOME/.rolepod/session-profiles/codex/explicit-session.mode"
printf 'full\nproject\n' > "$CFG_HOME/.rolepod/session-profiles/codex/native-session.mode"
printf 'lite\nproject\n' > "$CFG_HOME/.rolepod/session-profiles/codex/host-session.mode"
chmod 600 "$CFG_HOME/.rolepod/session-profiles/codex/spot-session.mode"
chmod 600 "$CFG_HOME/.rolepod/session-profiles/codex/explicit-session.mode" "$CFG_HOME/.rolepod/session-profiles/codex/native-session.mode" "$CFG_HOME/.rolepod/session-profiles/codex/host-session.mode"
printf '{"workflow":{"mode":"lite"}}\n' > "$CFG_HOME/.rolepod/config.json"
HOME="$CFG_HOME" ROLEPOD_SESSION_CLI=codex ROLEPOD_SESSION_ID=spot-session CODEX_THREAD_ID=host-session bash "$CFG_TARGET/plugins/rolepod/skills/using-rolepod/scripts/workflow-mode.sh" | grep -qx full || { echo "  ✗ installed workflow helper did not honor captured session profile"; ok=0; }
HOME="$CFG_HOME" ROLEPOD_SESSION_CLI=codex ROLEPOD_SESSION_ID=explicit-session CODEX_THREAD_ID=host-session bash "$CFG_TARGET/plugins/rolepod/skills/using-rolepod/scripts/workflow-mode.sh" | grep -qx standard || { echo "  ✗ explicit session ID did not precede Codex thread ID"; ok=0; }
HOME="$CFG_HOME" ROLEPOD_SESSION_CLI=codex ROLEPOD_SESSION_ID=explicit-session CODEX_THREAD_ID=host-session ROLEPOD_HOOK_INPUT='{"session_id":"native-session"}' bash "$CFG_TARGET/plugins/rolepod/skills/using-rolepod/scripts/workflow-mode.sh" | grep -qx full || { echo "  ✗ native input session ID did not precede explicit and Codex IDs"; ok=0; }
# A captured Codex profile can identify the helper namespace without an
# explicit CLI env; its cached path works even when the config reader is absent.
WF_READER="$CFG_TARGET/plugins/rolepod/skills/using-rolepod/scripts/rolepod_config.py"
mv "$WF_READER" "$WF_READER.disabled"
WF_INFERRED=$(env -u ROLEPOD_SESSION_CLI -u ROLEPOD_SESSION_MODE -u ROLEPOD_SESSION_SOURCE HOME="$CFG_HOME" CODEX_THREAD_ID=spot-session bash "$CFG_TARGET/plugins/rolepod/skills/using-rolepod/scripts/workflow-mode.sh")
mv "$WF_READER.disabled" "$WF_READER"
[ "$WF_INFERRED" = full ] || { echo "  ✗ installed helper did not use the captured Codex profile without a config reader ($WF_INFERRED)"; ok=0; }
cp "$TMP/config-before-session-flip" "$CFG_HOME/.rolepod/config.json"
cp "$CFG_HOME/.rolepod/config.json" "$TMP/config.keep"
HOME="$CFG_HOME" ROLEPOD_TARGET="$CFG_TARGET" ./install.sh --target=claude --uninstall --yes > "$TMP/cfg-uninstall.log" 2>&1 || { echo "  ✗ uninstall failed (see $TMP/cfg-uninstall.log)"; ok=0; }
cmp -s "$TMP/config.keep" "$CFG_HOME/.rolepod/config.json" || { echo "  ✗ config.json changed or vanished after --uninstall"; ok=0; }
HOME="$CFG_HOME" ROLEPOD_TARGET="$CFG_TARGET" ./install.sh --target=claude --force > "$TMP/cfg-install2.log" 2>&1 || { echo "  ✗ re-install failed (see $TMP/cfg-install2.log)"; ok=0; }
python3 -I - "$CFG_HOME/.rolepod/config.json" <<'PY' || { echo "  ✗ --force did not reset mode to lite and preserve pool"; ok=0; }
import json,sys
d=json.load(open(sys.argv[1]))
assert d.get("workflow",{}).get("mode")=="lite", d
assert not ({"gates","nudge","review"} & d.keys()), d
assert d.get("pool")=={"reviewer":{"review":"codex agy"}}, d
PY
if [ "$ok" -eq 1 ]; then echo "  ✓ --force resets workflow.mode=lite, preserves pool across uninstall/reinstall, and bundles canonical helper readers"; PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# A project managed block points at an existing global core instead of
# repeating the full payload; user text and the global block remain intact.
echo "[managed blocks] project pointer avoids duplicate full core"
POINTER_HOME="$TMP/pointer-home"; POINTER_PROJECT="$TMP/pointer-project"
mkdir -p "$POINTER_HOME/.codex" "$POINTER_PROJECT"
printf 'global user text\n<!-- rolepod:start -->\nfull global core\n<!-- rolepod:end -->\n' > "$POINTER_HOME/.codex/AGENTS.md"
printf 'project user text\n' > "$POINTER_PROJECT/AGENTS.md"
HOME="$POINTER_HOME" ROLEPOD_CODEX_TARGET="$POINTER_PROJECT" ./install.sh --target=codex --scope=project --force > "$TMP/pointer.log" 2>&1 || { echo "  ✗ project pointer install failed"; FAIL=$((FAIL+1)); }
if grep -q 'project user text' "$POINTER_PROJECT/AGENTS.md" && grep -q 'Rolepod project pointer' "$POINTER_PROJECT/AGENTS.md" && grep -q "$POINTER_HOME/.codex/AGENTS.md" "$POINTER_PROJECT/AGENTS.md" && ! grep -q 'Tier classes' "$POINTER_PROJECT/AGENTS.md" && grep -q 'full global core' "$POINTER_HOME/.codex/AGENTS.md"; then
  echo "  ✓ project pointer keeps user text and avoids duplicating global core"; PASS=$((PASS+1))
else
  echo "  ✗ project/global managed block content was not preserved or compacted"; FAIL=$((FAIL+1))
fi
PF_HOME="$TMP/project-first-home"; PF_PROJECT="$TMP/project-first"
PF_GLOBAL="$PF_HOME/.codex"; mkdir -p "$PF_HOME" "$PF_PROJECT"
printf 'project-first user text\n' > "$PF_PROJECT/AGENTS.md"
HOME="$PF_HOME" ROLEPOD_CODEX_TARGET="$PF_PROJECT" "$REPO_DIR/install.sh" --target=codex --scope=project --force > "$TMP/project-first.log" 2>&1 || { echo "  ✗ project-first install failed"; FAIL=$((FAIL+1)); }
( cd "$PF_PROJECT" && HOME="$PF_HOME" ROLEPOD_CODEX_TARGET="$PF_GLOBAL" "$REPO_DIR/install.sh" --target=codex --scope=global --force ) > "$TMP/global-after-project.log" 2>&1 || { echo "  ✗ global install after project install failed"; FAIL=$((FAIL+1)); }
if grep -q 'workflow.mode' "$PF_GLOBAL/AGENTS.md" && grep -q 'Rolepod project pointer' "$PF_PROJECT/AGENTS.md" && grep -q "$PF_GLOBAL/AGENTS.md" "$PF_PROJECT/AGENTS.md" && ! grep -q 'Tier classes' "$PF_PROJECT/AGENTS.md" && grep -q 'project-first user text' "$PF_PROJECT/AGENTS.md"; then
  echo "  ✓ project-first install compacts after global core arrives and preserves user text"; PASS=$((PASS+1))
else
  echo "  ✗ global install did not compact existing project core"; FAIL=$((FAIL+1))
fi
RD_HOME="$TMP/redirect-home"; RD_PROJECT="$TMP/redirect-project"; RD_TARGET="$TMP/redirect-global"
mkdir -p "$RD_HOME" "$RD_PROJECT"
printf 'redirect user text\n<!-- rolepod:start -->\nreal project core\n<!-- rolepod:end -->\n' > "$RD_PROJECT/AGENTS.md"
cp "$RD_PROJECT/AGENTS.md" "$TMP/redirect-project.keep"
( cd "$RD_PROJECT" && HOME="$RD_HOME" ROLEPOD_CODEX_TARGET="$RD_TARGET" "$REPO_DIR/install.sh" --target=codex --scope=global --force ) > "$TMP/redirect-global.log" 2>&1 || { echo "  ✗ redirected global install failed"; FAIL=$((FAIL+1)); }
if cmp -s "$TMP/redirect-project.keep" "$RD_PROJECT/AGENTS.md" && ! grep -q "$RD_TARGET/AGENTS.md" "$RD_PROJECT/AGENTS.md"; then
  echo "  ✓ redirected global install leaves project managed block unchanged"; PASS=$((PASS+1))
else
  echo "  ✗ redirected global install rewrote project block to temporary target"; FAIL=$((FAIL+1))
fi

# A nested tool cwd must resolve the nearest repository profile, both when
# invoked from cwd and when a hook passes that nested cwd as an override.
echo "[nested project profile] cwd and hook override resolve repository root"
NEST_HOME="$TMP/nested-home"; mkdir -p "$NEST_HOME"
nested_ok=1
for kind in directory file; do
  NEST_ROOT="$TMP/nested-$kind"; NEST_CWD="$NEST_ROOT/packages/app"
  mkdir -p "$NEST_ROOT/.rolepod" "$NEST_CWD/.rolepod" "$NEST_CWD/src"
  if [ "$kind" = directory ]; then mkdir -p "$NEST_ROOT/.git"; else printf 'gitdir: ../gitdir\n' > "$NEST_ROOT/.git"; fi
  printf '{"workflow":{"mode":"full"}}\n' > "$NEST_ROOT/.rolepod/config.json"
  ( cd "$NEST_CWD" && HOME="$NEST_HOME" python3 -I "$REPO_DIR/hooks/lib/rolepod_config.py" mode ) | grep -qx 'mode=full' || { echo "  ✗ native cwd lost $kind-shaped repository mode"; FAIL=$((FAIL+1)); nested_ok=0; }
  ( cd "$NEST_CWD" && HOME="$NEST_HOME" ROLEPOD_PROJECT_ROOT="$NEST_CWD" python3 -I "$REPO_DIR/hooks/lib/rolepod_config.py" mode ) | grep -qx 'mode=full' || { echo "  ✗ hook cwd override lost $kind-shaped repository mode"; FAIL=$((FAIL+1)); nested_ok=0; }
done
if [ "$nested_ok" -eq 1 ]; then echo "  ✓ nearest repository root wins from nested cwd and hook override"; PASS=$((PASS+1)); fi

# ─── Create-only init and explicit reinstall migration ────────────────────
echo "[default config] create-only init; --force migrates profile"
ok=1
DC_TARGET="$TMP/.claude-dc"; mkdir -p "$DC_TARGET"
dc_install() { HOME="$1" ROLEPOD_TARGET="$DC_TARGET" ./install.sh --target=claude --force "${@:2}" > "$TMP/dc.log" 2>&1; }
dc_install_no_force() { HOME="$1" ROLEPOD_TARGET="$DC_TARGET" ./install.sh --target=claude "${@:2}" > "$TMP/dc.log" 2>&1; }
cat > "$TMP/dc.expected" <<'EOF'
{
  "version": 1,
  "workflow": { "mode": "lite" },
  "pool": {
    "cross-family": "off",
    "reviewer": { "review": "claude codex agy", "consult": "claude codex agy", "critique": "claude codex agy" }
  }
}
EOF
# fresh install writes it, with one line naming the path
DC1="$TMP/dc1"; mkdir -p "$DC1"
dc_install "$DC1" || { echo "  ✗ fresh install failed"; ok=0; }
cmp -s "$TMP/dc.expected" "$DC1/.rolepod/config.json" || { echo "  ✗ fresh install did not write the default config"; ok=0; }
[ "$(/usr/bin/grep -c "wrote $DC1/.rolepod/config.json" "$TMP/dc.log")" = 1 ] || { echo "  ✗ expected exactly one 'wrote <path>' line"; ok=0; }
# the reader sees today's defaults
[ "$(HOME="$DC1" python3 -I hooks/lib/rolepod_config.py shell | tr '\n' ' ')" = "gates=off nudge=on " ] || { echo "  ✗ rolepod_config.py shell is not gates=off nudge=on"; ok=0; }
POOLOUT="$(HOME="$DC1" python3 -I hooks/lib/rolepod_config.py pool)"
printf '%s\n' "$POOLOUT" | /usr/bin/grep -qx 'enabled=off' && printf '%s\n' "$POOLOUT" | /usr/bin/grep -qx 'configured=yes' || { echo "  ✗ rolepod_config.py pool is not enabled=off + configured=yes: $POOLOUT"; ok=0; }
HOME="$DC1" bash core/skills/cross-family/scripts/cross-family.sh --pool 2>&1 | /usr/bin/grep -qi 'off' || { echo "  ✗ --pool does not report the pool off"; ok=0; }
# A forced install over a valid modern file (full mode) changes nothing and prints no 'wrote' line.
printf '{"workflow":{"mode":"full"},"pool":{"cross-family":"on"}}\n' > "$DC1/.rolepod/config.json"
cp "$DC1/.rolepod/config.json" "$TMP/dc.keep"
dc_install "$DC1" || { echo "  ✗ second install failed"; ok=0; }
cmp -s "$TMP/dc.keep" "$DC1/.rolepod/config.json" || { echo "  ✗ --force changed a valid modern config"; ok=0; }
[ "$(/usr/bin/grep -c "wrote $DC1/.rolepod/config.json" "$TMP/dc.log")" = 0 ] || { echo "  ✗ --force over a valid config reported a write"; ok=0; }
# old-format and unreadable files are rewritten (pool kept, no backup), with or without --force
for body in '{"gates":{"mode":"hard"},"pool":{"cross-family":"on"}}' '{ not json'; do
  for fn in dc_install dc_install_no_force; do
    DC2="$TMP/dc2"; rm -rf "$DC2"; mkdir -p "$DC2/.rolepod"
    printf '%s\n' "$body" > "$DC2/.rolepod/config.json"
    $fn "$DC2" || { echo "  ✗ install over '$body' failed"; ok=0; }
    python3 -I - "$DC2/.rolepod/config.json" "$body" <<'PY' || { echo "  ✗ '$body' was not rewritten correctly ($fn)"; ok=0; }
import json,sys
d=json.load(open(sys.argv[1]))
assert d["workflow"]=={"mode":"lite"} and not ({"gates","nudge","review"} & d.keys()), d
assert (d["pool"]=={"cross-family":"on"}) == ("pool" in sys.argv[2]), d
PY
    [ "$(find "$DC2/.rolepod" -name 'config*' | wc -l | tr -d ' ')" = 1 ] || { echo "  ✗ a backup file was left beside the config ($fn)"; ok=0; }
  done
done
# --dry-run and --uninstall write nothing
DC3="$TMP/dc3"; mkdir -p "$DC3"
dc_install "$DC3" --dry-run || { echo "  ✗ dry-run failed"; ok=0; }
[ ! -e "$DC3/.rolepod/config.json" ] || { echo "  ✗ --dry-run wrote the config"; ok=0; }
dc_install "$DC3" --uninstall --yes || { echo "  ✗ uninstall failed"; ok=0; }
[ ! -e "$DC3/.rolepod/config.json" ] || { echo "  ✗ --uninstall wrote the config"; ok=0; }
# uninstall then install keeps a user-edited modern file
dc_install "$DC1" || ok=0
printf '{"version":1,"workflow":{"mode":"standard"},"nudge_note":"x"}\n' > "$DC1/.rolepod/config.json"
cp "$DC1/.rolepod/config.json" "$TMP/dc.keep"
dc_install "$DC1" --uninstall --yes || { echo "  ✗ uninstall failed"; ok=0; }
dc_install_no_force "$DC1" || { echo "  ✗ normal re-install failed"; ok=0; }
cmp -s "$TMP/dc.keep" "$DC1/.rolepod/config.json" || { echo "  ✗ create-only init changed edited file after uninstall + install"; ok=0; }
# redirected install + non-temp HOME writes nothing; temp HOME or no target env writes
NT_HOME="$REPO_DIR/.test-nontemp-home"; rm -rf "$NT_HOME"; mkdir -p "$NT_HOME"
HOME="$NT_HOME" ROLEPOD_TARGET="$DC_TARGET" ./install.sh --target=claude --force > "$TMP/dc-nt.log" 2>&1 || { echo "  ✗ non-temp-HOME install failed"; ok=0; }
[ ! -e "$NT_HOME/.rolepod/config.json" ] || { echo "  ✗ target env + non-temp HOME wrote the config"; ok=0; }
rm -rf "$NT_HOME"
DC4="$TMP/dc4"; mkdir -p "$DC4"
dc_install "$DC4" || ok=0
[ -f "$DC4/.rolepod/config.json" ] || { echo "  ✗ target env + temp HOME did not write the config"; ok=0; }
DC5="$TMP/dc5"; mkdir -p "$DC5"
env -u ROLEPOD_TARGET HOME="$DC5" ./install.sh --target=opencode --force > "$TMP/dc5.log" 2>&1 </dev/null || { echo "  ✗ no-target-env install failed (see $TMP/dc5.log)"; ok=0; }
[ -f "$DC5/.rolepod/config.json" ] || { echo "  ✗ no target env + temp HOME did not write the config"; ok=0; }
if [ "$ok" -eq 1 ]; then echo "  ✓ default config written only when missing, unreadable or old format (pool kept, no backup); valid files survive any install; dry-run / uninstall write nothing"; PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ─── opencode upgrade over 15 retired role files (A11-A13) ─────────────
echo ""
echo "[opencode upgrade] retired role files go, user files stay"
OCU="$TMP/ocu/.config/opencode"; mkdir -p "$OCU/agents" "$TMP/ocu-home"
OLD_ROLES="backend-developer frontend-developer mobile-developer billing-engineer ai-ml-engineer devops-sre content-strategist ui-ux-designer performance-engineer system-architect universal-reviewer adversarial-reviewer security-engineer qa-tester scout"
for n in $OLD_ROLES; do printf '# %s\n\n## Skill Mapping\n\nold\n' "$n" > "$OCU/agents/$n.md"; done
printf '# pm\n\n## Skill Mapping\n' > "$OCU/agents/product-manager.md"
printf '# ds\n\n## Skill Mapping\n' > "$OCU/agents/data-scientist.md"
# user files: qa-tester stays only if it has no marker -> use two distinct names
printf '# mine, no marker\n' > "$OCU/agents/qa-tester.md"
printf '# real\n\n## Skill Mapping\n' > "$TMP/ocu-real.md"
rm -f "$OCU/agents/devops-sre.md"; ln -s "$TMP/ocu-real.md" "$OCU/agents/devops-sre.md"
printf '# mine\n' > "$OCU/agents/my-own.md"
if HOME="$TMP/ocu-home" ROLEPOD_OPENCODE_TARGET="$OCU" ./install.sh --target=opencode --force > "$TMP/ocu.log" 2>&1; then
  ocu_ok=1
  for n in $OLD_ROLES product-manager data-scientist; do
    case "$n" in qa-tester|devops-sre) continue ;; esac
    [ ! -e "$OCU/agents/$n.md" ] || { echo "  ✗ retired $n.md still present (A11)"; ocu_ok=0; }
  done
  for t in builder reviewer qa scout; do [ -f "$OCU/agents/rolepod-$t.md" ] || { echo "  ✗ rolepod-$t.md missing (A11)"; ocu_ok=0; }; done
  [ -f "$OCU/agents/qa-tester.md" ] && ! /usr/bin/grep -qx '## Skill Mapping' "$OCU/agents/qa-tester.md" || { echo "  ✗ user qa-tester.md lost (A12)"; ocu_ok=0; }
  [ -L "$OCU/agents/devops-sre.md" ] || { echo "  ✗ symlink devops-sre.md lost (A12)"; ocu_ok=0; }
  [ -f "$OCU/agents/my-own.md" ] || { echo "  ✗ my-own.md lost"; ocu_ok=0; }
  # A13: uninstall removes the 4 types, keeps the user's files; seed a marked retired file first
  printf '# scout\n\n## Skill Mapping\n\nold\n' > "$OCU/agents/scout.md"
  HOME="$TMP/ocu-home" ROLEPOD_OPENCODE_TARGET="$OCU" ./install.sh --target=opencode --uninstall --yes > "$TMP/ocu-un.log" 2>&1 || true
  for t in builder reviewer qa scout; do [ ! -e "$OCU/agents/rolepod-$t.md" ] || { echo "  ✗ uninstall left rolepod-$t.md (A13)"; ocu_ok=0; }; done
  [ ! -e "$OCU/agents/scout.md" ] || { echo "  ✗ uninstall left the marked retired scout.md (A13)"; ocu_ok=0; }
  [ -f "$OCU/agents/qa-tester.md" ] && [ -L "$OCU/agents/devops-sre.md" ] && [ -f "$OCU/agents/my-own.md" ] || { echo "  ✗ uninstall removed a user file (A13)"; ocu_ok=0; }
  if [ "$ocu_ok" -eq 1 ]; then echo "  ✓ opencode upgrade: retired files removed, 4 types present, user files kept; uninstall clean (A11-A13)"; PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
else
  echo "  ✗ opencode upgrade install failed (see $TMP/ocu.log)"; FAIL=$((FAIL+1))
fi

# ─── Summary ────────────────────────────────────────────────────────────
echo ""
echo "install-parity: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
