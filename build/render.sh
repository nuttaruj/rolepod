#!/usr/bin/env bash
# rolepod render — assembles per-CLI entry doc from core/ fragments + adapter template.
#
# Usage:
#   ./build/render.sh --target=claude            # default
#   ./build/render.sh --target=codex
#   ./build/render.sh --target=cursor
#   ./build/render.sh --target=antigravity       # Antigravity CLI (agy)
#   ./build/render.sh --target=opencode          # opencode CLI
#   ./build/render.sh --target=all               # render all five
#
# Outputs:
#   .claude-plugin/marketplace.json                    # committed — repo IS the Claude marketplace
#   .cursor-plugin/marketplace.json                    # committed — repo IS the Cursor marketplace
#   plugins/rolepod/                                   # committed — rendered Claude plugin tree
#   plugins/rolepod/agents/<name>.md                   # 15 files (Claude frontmatter)
#   plugins/rolepod-codex/                             # committed — rendered Codex plugin tree
#   plugins/rolepod-cursor/                            # committed — rendered Cursor plugin tree
#   build/rendered/codex/AGENTS.md                     # gitignored build output
#   build/rendered/codex/agents/<name>.md              # 15 files (portable frontmatter)
#   build/rendered/antigravity/AGENTS.md               # gitignored build output
#
# The Claude + Cursor targets render into committed repo-root paths so the
# repo is a directly installable marketplace for each (`claude plugin
# marketplace add <repo>` / Cursor team-marketplace import). Codex similarly
# commits its plugin tree. Antigravity stays under build/rendered/ (plugin
# install, not a marketplace). Gemini CLI support was removed in v2.177.0 —
# use --target=antigravity.
#
# Template directives (one per line):
#   {{INCLUDE: <path-relative-to-repo-root>}}
# The directive line is replaced verbatim with the contents of <path>.
# Includes are NOT recursive — fragments cannot include other fragments.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Default to all targets. A single-target default (claude) silently left the
# other four committed trees stale on a bare `render.sh`, which is the recurring
# "render-clean" amend loop. Pick one target explicitly with --target=<name>.
TARGET="all"

for arg in "$@"; do
  case "$arg" in
    --target=*) TARGET="${arg#--target=}" ;;
    -h|--help)
      sed -n '2,21p' "$0"
      exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

case "$TARGET" in
  claude|codex|cursor|antigravity|opencode|all) ;;
  *)
    echo "Unknown target: $TARGET (expected claude|codex|cursor|antigravity|opencode|all)" >&2
    exit 1 ;;
esac

# Strip macOS .DS_Store noise from source before any copy — skill dirs now
# carry templates/examples/references subfolders, and `cp -R` would otherwise
# propagate Finder's .DS_Store into every rendered plugin tree.
find "$REPO_DIR/core" -name .DS_Store -delete 2>/dev/null || true

# ─── Render template, resolving {{INCLUDE: ...}} directives ─────────────────
# Reads template line-by-line; lines matching `{{INCLUDE: <path>}}` are
# replaced with file contents. All other lines pass through verbatim.

render_template() {
  local template="$1"
  local output="$2"
  local line path inc_file

  : > "$output"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "{{INCLUDE: "*"}}")
        path="${line#'{{INCLUDE: '}"
        path="${path%'}}'}"
        inc_file="$REPO_DIR/$path"
        if [ ! -f "$inc_file" ]; then
          echo "render: missing include $path (referenced from $template)" >&2
          exit 1
        fi
        cat "$inc_file" >> "$output"
        ;;
      *)
        printf '%s\n' "$line" >> "$output"
        ;;
    esac
  done < "$template"
}

# ─── Render per-target agent files (Claude / Codex frontmatter shape) ──────

render_agents() {
  local target="$1"
  local out_dir="${2:-$REPO_DIR/build/rendered/$target/agents}"
  mkdir -p "$out_dir"
  # Codex agents are TOML; every other target is markdown.
  local ext="md"
  [ "$target" = "codex" ] && ext="toml"
  local count=0
  for core_md in "$REPO_DIR"/core/agents/*.md; do
    local name
    name="$(basename "$core_md" .md)"
    python3 "$REPO_DIR/build/merge-agent.py" --target="$target" --name="$name" \
      > "$out_dir/$name.$ext"
    count=$((count + 1))
  done
  echo "rendered $count agents → ${out_dir#"$REPO_DIR"/}"
}

# ─── Render skills — copy each skill dir; resolve {{INCLUDE}} in SKILL.md ──
# Supporting files (references/, examples/, templates/) copy verbatim. SKILL.md
# is processed through render_template so a skill body can {{INCLUDE}} a shared
# fragment instead of restating it. A SKILL.md with no directive renders
# byte-identical, so this is a safe no-op for skills that include nothing.

render_skills() {
  local skills_dst="$1"
  mkdir -p "$skills_dst"
  for skill_dir in "$REPO_DIR"/core/skills/*/; do
    local name; name="$(basename "$skill_dir")"
    cp -R "$skill_dir" "$skills_dst/$name"
    [ -f "$skill_dir/SKILL.md" ] && \
      render_template "$skill_dir/SKILL.md" "$skills_dst/$name/SKILL.md"
  done
}

# ─── Strip skill frontmatter to name + description ──────────────────────────
# Shared by the cursor + opencode targets: both CLIs document only those two
# SKILL.md fields, so rolepod's extra keys (tier / phase / when_to_use /
# disable-model-invocation) are stripped rather than gambling on tolerance.

strip_skill_frontmatter() {
  python3 - "$1" <<'PY'
import re
import sys
from pathlib import Path

target_dir = Path(sys.argv[1])
keep = {"name", "description"}
for skill in target_dir.glob("*/SKILL.md"):
    text = skill.read_text()
    if not text.startswith("---\n"):
        continue
    end = text.find("\n---\n", 4)
    if end == -1:
        continue
    fm = text[4:end]
    body = text[end + 5:]
    kept_lines = []
    for line in fm.split("\n"):
        m = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):\s", line)
        if m and m.group(1) in keep:
            kept_lines.append(line)
    skill.write_text("---\n" + "\n".join(kept_lines) + "\n---\n" + body)
PY
}

# ─── Render Claude target ───────────────────────────────────────────────────
# Claude ships as a pure marketplace plugin — no entry doc, no managed block.
# The always-on judgment core is delivered at runtime by the SessionStart
# hook (hooks/always-on-loader.sh).
#
# The Claude target renders into COMMITTED repo-root paths so the repo is a
# directly installable marketplace — `claude plugin marketplace add <repo>`
# reads the repo-root .claude-plugin/marketplace.json and resolves the plugin
# from ./plugins/rolepod. Both paths are committed (a CI render-clean check
# guards against drift). Only the plugin tree is rebuilt — never the repo root.
#   .claude-plugin/marketplace.json            (marketplace manifest — repo root)
#   plugins/rolepod/.claude-plugin/plugin.json (plugin manifest)
#   plugins/rolepod/agents/*.md                (15 rendered agents)
#   plugins/rolepod/skills/<name>/SKILL.md     (real dir, copied from core/skills)
#   plugins/rolepod/commands/*.md              (slash commands)
#   plugins/rolepod/hooks/*.sh + *.md + lib/
# Sources: adapters/claude/.claude-plugin/{marketplace,plugin}.json.

# Evidence readers + the cross-family runner shipped with every plugin tree —
# installed users get `rolepod-stats` / `rolepod-junit` / `rolepod-cross-family`
# / `rolepod-ticket` (install.sh drops launchers on PATH) without cloning the
# source repo. Byte-exact copies of scripts/.
render_evidence_scripts() {
  local dst="$1"
  mkdir -p "$dst/scripts"
  cp "$REPO_DIR/scripts/stats.sh" "$dst/scripts/stats.sh"
  cp "$REPO_DIR/scripts/junit-summary.sh" "$dst/scripts/junit-summary.sh"
  cp "$REPO_DIR/scripts/plan-lint.sh" "$dst/scripts/plan-lint.sh"
  # Cross-family runner (v2.76.0) — the hooks resolve it as ../scripts/ from
  # their own dir, so it ships in every tree, marketplace installs included.
  cp "$REPO_DIR/scripts/cross-family.sh" "$dst/scripts/cross-family.sh"
  # Ticket-loop helper (rolepod-ticket) — resolves plan-lint.sh beside itself
  # the same way, so it ships next to it here too.
  cp "$REPO_DIR/scripts/ticket.sh" "$dst/scripts/ticket.sh"
  # `rolepod-ticket fleet`'s scriptPath resolves ticket-fleet.js beside
  # itself, falling back to ~/.rolepod/bin (install.sh) — shipped here too so
  # a marketplace-only install (no install.sh run) has it next to ticket.sh.
  cp "$REPO_DIR/scripts/ticket-fleet.js" "$dst/scripts/ticket-fleet.js"
  chmod +x "$dst/scripts/"*.sh 2>/dev/null || true
}

render_claude() {
  local adapter_dir="$REPO_DIR/adapters/claude"
  local plugin_dst="$REPO_DIR/plugins/rolepod"

  # Rebuild only the plugin tree — the repo root is never rm'd.
  rm -rf "$plugin_dst"
  mkdir -p "$plugin_dst"

  # Marketplace manifest at the repo-root .claude-plugin/.
  if [ -f "$adapter_dir/.claude-plugin/marketplace.json" ]; then
    mkdir -p "$REPO_DIR/.claude-plugin"
    cp "$adapter_dir/.claude-plugin/marketplace.json" "$REPO_DIR/.claude-plugin/"
  else
    echo "render: missing $adapter_dir/.claude-plugin/marketplace.json" >&2; exit 1
  fi

  # Plugin manifest under plugins/rolepod/.claude-plugin/.
  if [ -f "$adapter_dir/.claude-plugin/plugin.json" ]; then
    mkdir -p "$plugin_dst/.claude-plugin"
    cp "$adapter_dir/.claude-plugin/plugin.json" "$plugin_dst/.claude-plugin/"
  else
    echo "render: missing $adapter_dir/.claude-plugin/plugin.json" >&2; exit 1
  fi

  # Rendered agents into the plugin tree.
  render_agents "claude" "$plugin_dst/agents"

  # Skills as a real directory tree (rendered from core/skills/).
  render_skills "$plugin_dst/skills"

  # Slash commands.
  if [ -d "$REPO_DIR/commands" ]; then
    mkdir -p "$plugin_dst/commands"
    cp "$REPO_DIR/commands"/*.md "$plugin_dst/commands/" 2>/dev/null || true
  fi

  # Hooks: hooks/hooks.json config (canonical plugin-root form) + 6 core
  # scripts + lib/ helpers.
  mkdir -p "$plugin_dst/hooks"
  if [ -f "$adapter_dir/hooks.json" ]; then
    cp "$adapter_dir/hooks.json" "$plugin_dst/hooks/hooks.json"
  else
    echo "render: missing $adapter_dir/hooks.json" >&2; exit 1
  fi
  cp "$REPO_DIR/hooks"/*.sh "$plugin_dst/hooks/" 2>/dev/null || true
  # always-on-core — the judgment core emitted at runtime by
  # always-on-loader.sh. The .md.tmpl source resolves {{INCLUDE}} of shared
  # fragments into the shipped .md, so doctrine is single-sourced from
  # core/fragments/.
  render_template "$REPO_DIR/hooks/always-on-core.md.tmpl" \
    "$plugin_dst/hooks/always-on-core.md"
  # terse-core — the opt-in output layer emitted by terse-loader.sh only when
  # the user has created the flag. Shipped unconditionally, loaded on demand.
  render_template "$REPO_DIR/hooks/terse-core.md.tmpl" \
    "$plugin_dst/hooks/terse-core.md"
  [ -d "$REPO_DIR/hooks/lib" ] && cp -R "$REPO_DIR/hooks/lib" "$plugin_dst/hooks/"
  chmod +x "$plugin_dst/hooks/"*.sh 2>/dev/null || true

  render_evidence_scripts "$plugin_dst"
}

# ─── Render Codex target ────────────────────────────────────────────────────
# Codex ships as a Codex marketplace consumable. Like the Claude target, the
# marketplace catalog + plugin tree render into COMMITTED repo-root paths so
# the repo is directly installable — `codex marketplace add nuttaruj/rolepod`
# reads the repo-root .agents/plugins/marketplace.json and resolves the plugin
# from ./plugins/rolepod-codex. A CI render-clean check guards against drift.
#
# Committed (repo root):
#   .agents/plugins/marketplace.json                 (marketplace catalog)
#   plugins/rolepod-codex/.codex-plugin/plugin.json  (plugin manifest)
#   plugins/rolepod-codex/hooks/hooks.json + *.sh    (hooks.json + agent-sync.sh
#                                                     from the adapter; 7 shared scripts
#                                                     render-copied from hooks/)
#   plugins/rolepod-codex/skills/<name>/SKILL.md     (copied from core/skills)
# Gitignored (build/rendered/codex/ — read by install.sh only):
#   AGENTS.md                                        (~/.codex/AGENTS.md block)
#   agents/*.toml                                    (15 agents → ~/.codex/agents/,
#                                                     NOT a plugin component)

render_codex() {
  local template="$REPO_DIR/adapters/codex/AGENTS.md.tmpl"
  local out_dir="$REPO_DIR/build/rendered/codex"
  local output="$out_dir/AGENTS.md"
  local adapter_dir="$REPO_DIR/adapters/codex"
  local plugin_src="$adapter_dir/plugins/rolepod"
  local plugin_dst="$REPO_DIR/plugins/rolepod-codex"

  [ -f "$template" ] || { echo "render: missing $template" >&2; exit 1; }

  # Rebuild only the committed plugin tree — the repo root is never rm'd.
  rm -rf "$plugin_dst"
  mkdir -p "$plugin_dst"
  # AGENTS.md + agent-TOML staging stay in the gitignored build dir.
  rm -rf "$out_dir"
  mkdir -p "$out_dir"
  render_template "$template" "$output"

  # Marketplace catalog at the repo-root .agents/plugins/.
  if [ -f "$adapter_dir/.agents/plugins/marketplace.json" ]; then
    mkdir -p "$REPO_DIR/.agents/plugins"
    cp "$adapter_dir/.agents/plugins/marketplace.json" "$REPO_DIR/.agents/plugins/"
  else
    echo "render: missing $adapter_dir/.agents/plugins/marketplace.json" >&2; exit 1
  fi

  # Plugin manifest under plugins/rolepod-codex/.codex-plugin/.
  if [ -d "$plugin_src/.codex-plugin" ]; then
    cp -R "$plugin_src/.codex-plugin" "$plugin_dst/"
  else
    echo "render: missing $plugin_src/.codex-plugin/" >&2; exit 1
  fi

  # TOML agents — generated from core/agents/ + adapters/codex/agent-frontmatter/
  # into the gitignored build dir (install.sh copies from there). Codex's
  # plugin loader has no agent-discovery path; agents load only from the
  # global ~/.codex/agents/ directory.
  render_agents "codex" "$out_dir/agents"

  # v2.75.0: bundle the same agents + the AGENTS.md block INTO the plugin tree
  # too. hooks/agent-sync.sh (SessionStart) copies them into ~/.codex/agents/
  # and replaces only the rolepod block of ~/.codex/AGENTS.md when the plugin
  # version changes, so `codex plugin marketplace upgrade` alone is a complete
  # update. Filenames carry the same rolepod- prefix install.sh uses; the block
  # file is deliberately NOT named AGENTS.md (nothing may ever read it as
  # instructions from the plugin cache).
  mkdir -p "$plugin_dst/agents"
  local t
  for t in "$out_dir/agents"/*.toml; do
    [ -f "$t" ] || continue
    cp "$t" "$plugin_dst/agents/rolepod-$(basename "$t")"
  done
  cp "$output" "$plugin_dst/agents/AGENTS.rolepod.md"

  # Hooks — the 7 shared scripts come straight from canonical hooks/ (same
  # single-source rule as render_claude above and render_antigravity below);
  # only hooks.json + agent-sync.sh are genuinely Codex-specific.
  # subagent-write-scope.sh is not bundled — Codex has no
  # Edit/Write/MultiEdit/NotebookEdit tools of its own to gate. gate-reminder.sh
  # is not bundled either — it fires on Edit/Write, which Codex has none of.
  mkdir -p "$plugin_dst/hooks"
  cp "$plugin_src/hooks/hooks.json" "$plugin_dst/hooks/hooks.json"
  cp "$plugin_src/hooks/agent-sync.sh" "$plugin_dst/hooks/agent-sync.sh"
  # terse-core — the opt-in output layer the AGENTS.md pointer names.
  render_template "$REPO_DIR/hooks/terse-core.md.tmpl" \
    "$plugin_dst/hooks/terse-core.md"
  local h
  for h in precommit-gate project-context-loader claim-verify-nudge \
           block-subagent-commit session-lifecycle test-diff-lint fix-loop-breaker; do
    cp "$REPO_DIR/hooks/$h.sh" "$plugin_dst/hooks/$h.sh"
  done
  # hooks/lib/ (session_state.py, route_check.py) ships here too (v2.128.1):
  # claim-verify-nudge, session-lifecycle and precommit-gate resolve
  # `$(dirname "$0")/lib/...` — without it the Codex copies ran their
  # fallbacks (no route nudge / recorder, no context check) and, since the
  # v2.128.0 one-spawn rewrite, claim-verify-nudge exited before its claim
  # and auto-resume lines. Measured on the 2.128.0 Codex cache.
  rm -rf "$plugin_dst/hooks/lib"
  [ -d "$REPO_DIR/hooks/lib" ] && cp -R "$REPO_DIR/hooks/lib" "$plugin_dst/hooks/"
  find "$plugin_dst/hooks/lib" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  chmod +x "$plugin_dst/hooks/"*.sh 2>/dev/null || true

  # Skills as a real directory tree (rendered from core/skills/).
  render_skills "$plugin_dst/skills"

  render_evidence_scripts "$plugin_dst"
}

# ─── Render Cursor target ───────────────────────────────────────────────────
# Cursor ships as a native plugin under ~/.cursor/plugins/local/rolepod/.
# Layout mirrors Claude's plugin tree (skills/, agents/, hooks/, commands/)
# with three Cursor-specific adjustments:
#   1. .cursor-plugin/plugin.json (manifest) instead of .claude-plugin/
#   2. rules/always-on-core.mdc (alwaysApply: true) replaces the SessionStart
#      hook that emits always-on-core.md on Claude. Cleaner Cursor-native
#      delivery; caveat — a user who disables "Rules" in Cursor settings loses
#      the always-on core, parallel to Claude users who suppress hooks.
#   3. Hooks live under hooks/hooks.json with shell scripts under scripts/
#      (per Cursor template convention) and use camelCase event names
#      (sessionStart / preToolUse / beforeShellExecution).
#
# Committed (repo root):
#   .cursor-plugin/marketplace.json                  (marketplace catalog)
#   plugins/rolepod-cursor/.cursor-plugin/plugin.json
#   plugins/rolepod-cursor/rules/always-on-core.mdc  (fully resolved)
#   plugins/rolepod-cursor/skills/<name>/SKILL.md    (stripped to name+description)
#   plugins/rolepod-cursor/agents/<name>.md          (15 files, minimal frontmatter)
#   plugins/rolepod-cursor/hooks/hooks.json
#   plugins/rolepod-cursor/scripts/*.sh              (6 hook scripts + scripts/shared/ cores)

render_cursor() {
  local adapter_dir="$REPO_DIR/adapters/cursor"
  local plugin_dst="$REPO_DIR/plugins/rolepod-cursor"

  rm -rf "$plugin_dst"
  mkdir -p "$plugin_dst"

  if [ -f "$adapter_dir/.cursor-plugin/marketplace.json" ]; then
    mkdir -p "$REPO_DIR/.cursor-plugin"
    cp "$adapter_dir/.cursor-plugin/marketplace.json" "$REPO_DIR/.cursor-plugin/"
  else
    echo "render: missing $adapter_dir/.cursor-plugin/marketplace.json" >&2; exit 1
  fi

  if [ -f "$adapter_dir/.cursor-plugin/plugin.json" ]; then
    mkdir -p "$plugin_dst/.cursor-plugin"
    cp "$adapter_dir/.cursor-plugin/plugin.json" "$plugin_dst/.cursor-plugin/"
  else
    echo "render: missing $adapter_dir/.cursor-plugin/plugin.json" >&2; exit 1
  fi

  # Always-on judgment core — two-pass include resolution. Pass 1 splices the
  # adapter's rule template (frontmatter + single {{INCLUDE}} to the always-on
  # body template). Pass 2 expands the body template's own {{INCLUDE: core/fragments/...}}
  # directives. render_template is intentionally non-recursive; two passes
  # cover the one-deep nesting used here.
  mkdir -p "$plugin_dst/rules"
  local pass1="$plugin_dst/rules/.always-on-core.pass1"
  render_template "$adapter_dir/rules/always-on-core.mdc.tmpl" "$pass1"
  render_template "$pass1" "$plugin_dst/rules/always-on-core.mdc"
  rm -f "$pass1"

  # Terse output — same two-pass shape, but alwaysApply: false. Cursor loads
  # it on demand (flag file or an explicit ask), which is this CLI's native
  # equivalent of the flag-gated SessionStart hook the other targets use.
  local terse_pass1="$plugin_dst/rules/.terse.pass1"
  render_template "$adapter_dir/rules/terse.mdc.tmpl" "$terse_pass1"
  render_template "$terse_pass1" "$plugin_dst/rules/terse.mdc"
  rm -f "$terse_pass1"

  # Skills — render the same source as Claude, then post-process each
  # frontmatter to keep only the fields Cursor documents (name + description).
  # Defensive: the Cursor docs only acknowledge name/description in SKILL.md;
  # we don't want to gamble that Cursor silently ignores tier / phase /
  # when_to_use / disable-model-invocation. A command skill (e.g.
  # deepen-codebase) loses its disable-model-invocation guard on Cursor —
  # its description is phrased ("explicit user invocation only") to keep
  # auto-trigger rare even so.
  render_skills "$plugin_dst/skills"
  strip_skill_frontmatter "$plugin_dst/skills"

  # Agents — minimal name+description frontmatter (see merge-agent.py cursor target).
  render_agents "cursor" "$plugin_dst/agents"

  # Hooks (config + scripts).
  mkdir -p "$plugin_dst/hooks"
  if [ -f "$adapter_dir/hooks/hooks.json" ]; then
    cp "$adapter_dir/hooks/hooks.json" "$plugin_dst/hooks/hooks.json"
  else
    echo "render: missing $adapter_dir/hooks/hooks.json" >&2; exit 1
  fi
  if [ -d "$adapter_dir/scripts" ]; then
    mkdir -p "$plugin_dst/scripts"
    cp "$adapter_dir/scripts"/*.sh "$plugin_dst/scripts/" 2>/dev/null || true
    chmod +x "$plugin_dst/scripts/"*.sh 2>/dev/null || true
  fi
  # Shared cores behind Cursor translators (scripts/precommit-gate.sh maps
  # Cursor's stdin/events onto the Claude script and its additionalContext
  # back onto Cursor's additional_context). Byte-identical to hooks/, pinned
  # by tests/integration/cases/cursor-adapter.sh.
  mkdir -p "$plugin_dst/scripts/shared"
  local h
  for h in precommit-gate test-diff-lint; do
    cp "$REPO_DIR/hooks/$h.sh" "$plugin_dst/scripts/shared/$h.sh"
  done
  cp "$REPO_DIR/hooks/lib/route_check.py" "$plugin_dst/scripts/shared/route_check.py"   # stop → route record (v2.135.0)
  chmod +x "$plugin_dst/scripts/shared/"*.sh 2>/dev/null || true

  render_evidence_scripts "$plugin_dst"
}

# ─── Render Antigravity (agy) target ────────────────────────────────────────
# agy (Antigravity CLI) is Google's native successor to the now-removed
# Gemini CLI (support dropped in v2.177.0). It ships as a PLUGIN (skills +
# subagents + hooks) installed to ~/.gemini/config/plugins/rolepod/, plus an
# AGENTS.md context file that lives in the agy customization root (NOT a
# plugin component). Output stays under build/rendered/ (gitignored) —
# install.sh copies the plugin to the agy plugin dir and AGENTS.md to the
# customization root.
#
# Gitignored (build/rendered/antigravity/ — read by install.sh only):
#   AGENTS.md                  (always-on core → agy customization root)
#   plugin/plugin.json         (agy plugin manifest)
#   plugin/skills/<name>/...    (copied from core/skills)
#   plugin/agents/<name>.md     (15 agents, md + YAML frontmatter)
#   plugin/hooks.json           (agy-native event wiring at PLUGIN ROOT: PreInvocation/PreToolUse/Stop)
#   plugin/hooks/*.sh           (3 agy-native scripts + the shared precommit-gate.sh /
#                                test-diff-lint.sh / route_check.py, copied verbatim)

render_antigravity() {
  local template="$REPO_DIR/adapters/antigravity/AGENTS.md.tmpl"
  local out_dir="$REPO_DIR/build/rendered/antigravity"
  local adapter_dir="$REPO_DIR/adapters/antigravity"
  local plugin_dst="$out_dir/plugin"

  [ -f "$template" ] || { echo "render: missing $template" >&2; exit 1; }

  rm -rf "$out_dir"
  mkdir -p "$plugin_dst"

  # AGENTS.md context file — installed to the agy customization root, NOT the
  # plugin (agy loads always-on rules from the root, not a plugin component).
  render_template "$template" "$out_dir/AGENTS.md"
  render_template "$REPO_DIR/hooks/terse-core.md.tmpl" "$out_dir/terse-core.md"

  # Plugin manifest.
  if [ -f "$adapter_dir/plugin.json" ]; then
    cp "$adapter_dir/plugin.json" "$plugin_dst/plugin.json"
  else
    echo "render: missing $adapter_dir/plugin.json" >&2; exit 1
  fi

  # Skills as a real directory tree (rendered from core/skills/).
  render_skills "$plugin_dst/skills"

  # Agents — md + YAML frontmatter.
  render_agents "antigravity" "$plugin_dst/agents"

  # Hooks — agy-native event wiring (hooks.json at the PLUGIN ROOT) + three
  # agy-native scripts. Contract measured live on agy 1.2.3 (2026-09-16):
  # events sit under ONE name key ({"rolepod": {...}} — a flat top-level
  # manifest fails to parse and no hook ever fires), commands are relative
  # to the hooks.json directory (`hooks/x.sh`; ${extensionPath} is passed
  # through literally), stdin is camelCase (toolCall / workspacePaths /
  # conversationId), and only a PreToolUse {decision, reason} is an accepted
  # result — every other output, `{}` included, blocks the tool.
  mkdir -p "$plugin_dst/hooks"
  if [ -f "$adapter_dir/hooks/hooks.json" ]; then
    cp "$adapter_dir/hooks/hooks.json" "$plugin_dst/hooks.json"
  else
    echo "render: missing $adapter_dir/hooks/hooks.json" >&2; exit 1
  fi
  local h
  for h in session-start pre-tool stop-unlock; do
    cp "$adapter_dir/hooks/$h.sh" "$plugin_dst/hooks/$h.sh"
  done
  # Shared commit gate reused verbatim: pre-tool.sh translates agy's
  # run_command call into the Claude-shape stdin precommit-gate.sh expects
  # and its deny back into agy's {decision, reason}; test-diff-lint.sh rides
  # along (the gate calls it by dirname). No lib/ — agy has no Claude
  # transcript, so the gate takes its non-Claude evidence path (phase-log).
  for h in precommit-gate test-diff-lint; do
    cp "$REPO_DIR/hooks/$h.sh" "$plugin_dst/hooks/$h.sh"
  done
  cp "$REPO_DIR/hooks/lib/route_check.py" "$plugin_dst/hooks/route_check.py"   # Stop → route record (v2.135.0)
  chmod +x "$plugin_dst/hooks/"*.sh 2>/dev/null || true

  render_evidence_scripts "$plugin_dst"
}

# ─── Render opencode target ─────────────────────────────────────────────────
# opencode ships as plain files copied to ~/.config/opencode/ (no marketplace).
# opencode supports SKILL.md natively; agents/<name>.md where
# the FILENAME is the agent id; AGENTS.md is the global rules file (written
# as a managed block by install.sh); plugins/rolepod.js is the best-effort
# session-hygiene shim (session locks + post-compact re-anchor).
#
# Gitignored (build/rendered/opencode/ — read by install.sh only):
#   AGENTS.md                  (always-on core → managed block)
#   agents/<name>.md           (15 agents, description + mode: subagent)
#   skills/<name>/...          (frontmatter stripped to name + description)
#   plugin/rolepod.js          (plugin shim)
#   opencode.json              (version stamp for install verification)

render_opencode() {
  local template="$REPO_DIR/adapters/opencode/AGENTS.md.tmpl"
  local out_dir="$REPO_DIR/build/rendered/opencode"
  local adapter_dir="$REPO_DIR/adapters/opencode"

  [ -f "$template" ] || { echo "render: missing $template" >&2; exit 1; }

  rm -rf "$out_dir"
  mkdir -p "$out_dir"
  render_template "$template" "$out_dir/AGENTS.md"
  render_template "$REPO_DIR/hooks/terse-core.md.tmpl" "$out_dir/terse-core.md"

  # Version stamp (install verification + bump-script parity).
  if [ -f "$adapter_dir/opencode.json" ]; then
    cp "$adapter_dir/opencode.json" "$out_dir/"
  else
    echo "render: missing $adapter_dir/opencode.json" >&2; exit 1
  fi

  # Skills — same source as Claude; frontmatter stripped to the two fields
  # opencode documents (shared helper with the cursor target).
  render_skills "$out_dir/skills"
  strip_skill_frontmatter "$out_dir/skills"

  # Agents — description + mode: subagent (filename = agent id).
  render_agents "opencode" "$out_dir/agents"

  # Plugin shim + the shared hook cores it runs behind a translator
  # (plugins/rolepod-shared/ next to rolepod.js; byte-identical to hooks/).
  if [ -f "$adapter_dir/plugin/rolepod.js" ]; then
    mkdir -p "$out_dir/plugin/rolepod-shared"
    cp "$adapter_dir/plugin/rolepod.js" "$out_dir/plugin/rolepod.js"
    local h
    # precommit-gate ships too (hook-layer-lean fix round, 2026-09-25,
    # B-spec MAJOR): the commit hook runs it directly (ROLEPOD_LEAD_CLI=
    # opencode) instead of a hand-duplicated JS private-docs check, so a
    # compound `git add -A && git commit` gets the same working-tree read
    # every other CLI's gate has. It exits right after the private-docs
    # deny for a non-Claude lead — no hooks/lib/ dependency to ship with it.
    for h in fix-loop-breaker precommit-gate; do
      cp "$REPO_DIR/hooks/$h.sh" "$out_dir/plugin/rolepod-shared/$h.sh"
    done
    cp "$REPO_DIR/hooks/lib/route_check.py" "$out_dir/plugin/rolepod-shared/route_check.py"   # session.idle → route record (v2.135.0)
    chmod +x "$out_dir/plugin/rolepod-shared/"*.sh 2>/dev/null || true
  else
    echo "render: missing $adapter_dir/plugin/rolepod.js" >&2; exit 1
  fi

  render_evidence_scripts "$out_dir"
}

case "$TARGET" in
  claude)      render_claude ;;
  codex)       render_codex ;;
  cursor)      render_cursor ;;
  antigravity) render_antigravity ;;
  opencode)    render_opencode ;;
  all)         render_claude; render_codex; render_cursor; render_antigravity; render_opencode ;;
esac
