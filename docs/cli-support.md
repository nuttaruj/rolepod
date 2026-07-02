# Rolepod — Per-CLI Support Matrix

Phase 2.3: rolepod ships for each supported CLI as a **native plugin / extension** — agents, skills, and hooks all wire into each CLI's own primitives. No wrapper scripts.

## Capability matrix

| Capability | Claude Code | Codex CLI | Gemini CLI | Cursor IDE | Antigravity CLI (agy) |
|---|---|---|---|---|---|
| Always-on instructions | SessionStart hook → `hooks/always-on-core.md` (additionalContext) | `~/.codex/AGENTS.md` (native) | `~/.gemini/extensions/rolepod/GEMINI.md` (extension context file) | `rules/always-on-core.mdc` with `alwaysApply: true` (Cursor native) | `AGENTS.md` at the customization root (auto-loaded) |
| Lazy-load rules (Read on trigger) | full | full | full | full (`.mdc` rules with explicit `alwaysApply: false` or glob match) | full |
| Skills (`<plugin>/skills/<name>/SKILL.md`) | 11 — Core 10 + 1 alias (native) | 11 — Core 10 + 1 alias (native) | 11 — Core 10 + 1 alias (native) | 11 — Core 10 + 1 alias (native; frontmatter stripped to `name` + `description` per Cursor spec) | 11 — Core 10 + 1 alias (native) |
| Subagents (parallel team) | full Task / SendMessage (16 agents) | 16 agents as Codex `agents/*.toml` (Lead-orchestrated) | 16 agents as extension `agents/*.md` (Lead-orchestrated) | 16 agents in `agents/*.md` (Lead-orchestrated) | 16 agents in `agents/*.md` (gemini format; Lead-orchestrated) |
| Hooks (core only) | 9 core hook scripts (10 registrations) in the plugin's `hooks/hooks.json` · auto-registered on install | 4 core hooks across `SessionStart`/`UserPromptSubmit`/`PreToolUse` · hooks require `plugin_hooks` opt-in | 5 core hooks across `SessionStart`/`BeforeAgent`/`BeforeTool`/`AfterTool`/`PreCompress` | 3 core hooks across `sessionStart`/`preToolUse`/`beforeShellExecution` · auto-fires | 4 core hook scripts across `PreInvocation`/`PreToolUse`/`PostToolUse` (`hooks.json` at the plugin root) |
| Slash commands | `/rolepod-full` (skill — force-full lifecycle) | `$rolepod-full` (skill via Codex skill UI) | `/rolepod-full` (skill; no native `.toml` commands) | `/rolepod-full` (skill) | `/rolepod-full` (skill) |
| Plugin manifest | `plugins/rolepod/.claude-plugin/plugin.json` (spec-conformant) + `.claude-plugin/marketplace.json` catalog at the repo root | `.codex-plugin/plugin.json` (mirrors caveman schema, 1.6KB) | `gemini-extension.json` (extension schema, 551B) | `plugins/rolepod-cursor/.cursor-plugin/plugin.json` (spec-conformant) + `.cursor-plugin/marketplace.json` catalog at the repo root | `plugin.json` at plugin root (agy plugin schema, validated by `agy plugin validate`) |
| Optional add-on integration | vendor-installed (own plugin / MCP); rolepod auto-detects, falls back to `rg` + `find` | vendor-installed (own plugin / MCP); rolepod auto-detects, falls back to `rg` + `find` | vendor-installed (own plugin / MCP); rolepod auto-detects, falls back to `rg` + `find` | vendor-installed (Cursor MCP / `mcp.json`); rolepod auto-detects, falls back to `rg` + `find` | vendor-installed; rolepod auto-detects, falls back to `rg` + `find` |
| MCP server config | global + per-plugin | global (`codex mcp`) | global (`gemini mcp`) | global (`~/.cursor/mcp.json`) + per-plugin (`plugin/mcp.json`) | global (agy config tree; not yet live-verified) |

## Install destinations

| CLI | Plugin / extension destination | Always-on core destination |
|---|---|---|
| Claude Code | repo IS the marketplace — `.claude-plugin/marketplace.json` + committed `plugins/rolepod/` (agents/, hooks/, skills/, .claude-plugin/) at the repo root; `claude plugin marketplace add nuttaruj/rolepod` installs straight from GitHub | SessionStart hook emits `hooks/always-on-core.md` (no CLAUDE.md) |
| Codex CLI | repo IS the marketplace — `.agents/plugins/marketplace.json` + committed `plugins/rolepod-codex/` (.codex-plugin/, hooks/, skills/) at the repo root; `codex plugin marketplace add nuttaruj/rolepod` installs straight from GitHub. The 16 agent TOMLs install to `~/.codex/agents/rolepod-*.toml` — Codex's plugin loader has no agents field, so they need `install.sh` | `~/.codex/AGENTS.md` |
| Gemini CLI | `~/.gemini/extensions/rolepod/` (gemini-extension.json, GEMINI.md, hooks/, skills/) | `~/.gemini/extensions/rolepod/GEMINI.md` (extension context file) |
| Cursor IDE | repo IS the marketplace — `.cursor-plugin/marketplace.json` + committed `plugins/rolepod-cursor/` (.cursor-plugin/, rules/, agents/, skills/, hooks/, scripts/) at the repo root; `install.sh --target=cursor` copies that tree to `~/.cursor/plugins/local/rolepod/` for local install | `plugins/rolepod-cursor/rules/always-on-core.mdc` (`alwaysApply: true`) |
| Antigravity CLI (agy) | rendered to `build/rendered/antigravity/plugin/` (gitignored); `install.sh --target=antigravity` installs it via `agy plugin install` — plugin.json + hooks.json at plugin root, skills/, agents/ | `AGENTS.md` at the agy customization root (`install.sh` places it) |

For Codex the entry doc is intentionally written **outside** the plugin dir (`~/.codex/AGENTS.md`) — Codex auto-loads the global `AGENTS.md` regardless of which plugins are installed, so keeping it at the root makes rolepod's gates active on every session, not just when the plugin is enabled.

For Gemini the entry doc ships **inside** the extension dir as `extensions/rolepod/GEMINI.md`. Gemini auto-loads it via the manifest's `contextFileName` field when the extension is enabled (the default after install). This keeps rolepod's context fully self-contained — install never touches the user's own `~/.gemini/GEMINI.md`, and uninstall is a clean `rm -rf` of the extension dir. (Pre-PR-8 installs wrote a managed block into the global `~/.gemini/GEMINI.md`; the installer strips that stale block on the next run.)

For Cursor the always-on core ships as `rules/always-on-core.mdc` with `alwaysApply: true`. Cursor auto-loads any `.mdc` rule carrying that frontmatter on every session, so the install is fully self-contained — nothing is written to user-global config and uninstall is a clean `rm -rf ~/.cursor/plugins/local/rolepod/`. Caveat: a user who disables **Settings → Features → Rules** in Cursor suppresses the always-on core (the parallel of a Claude user disabling SessionStart hooks).

### Install path env vars

| Variable | Effect |
|---|---|
| `ROLEPOD_TARGET` | Single-target default OR root for `--target=all`. Single target overrides destination entirely; with `--target=all`, each CLI lands under `$ROLEPOD_TARGET/<cli>/` (e.g. `$ROLEPOD_TARGET/claude`, `/codex`, `/gemini`). |
| `ROLEPOD_CLAUDE_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Claude only. |
| `ROLEPOD_CODEX_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Codex only. |
| `ROLEPOD_GEMINI_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Gemini only. |
| `ROLEPOD_CURSOR_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Cursor only. |
| `ROLEPOD_ANTIGRAVITY_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Antigravity only. A non-`~/.gemini` target also skips the real `agy plugin install` (temp-target guard). |

Non-TTY contexts: `--uninstall` without `--yes` exits 0 with `Aborted. Re-run with --yes in non-interactive mode.` instead of crashing on a missing `/dev/tty`.

## Adapter source layout

```
adapters/
├── claude/
│   ├── .claude-plugin/                 (plugin.json + marketplace.json)
│   ├── agent-frontmatter/*.yml         (16 frontmatter overlays)
│   └── hooks.json                      (plugin hooks manifest)
├── codex/
│   ├── AGENTS.md.tmpl
│   ├── agent-frontmatter/*.yml          (16 overlays — model / effort / sandbox)
│   ├── .agents/plugins/marketplace.json (Codex marketplace manifest)
│   └── plugins/rolepod/
│       ├── .codex-plugin/plugin.json
│       ├── hooks/hooks.json + 4 core *.sh
│       └── skills → ../../../../core/skills (symlink, dereferenced at render time)
├── gemini/
│   ├── GEMINI.md.tmpl
│   ├── gemini-extension.json
│   ├── agent-frontmatter/*.yml          (16 overlays — model)
│   ├── hooks/hooks.json + 5 *.sh
│   └── skills/                         (real dir, populated at render time)
├── cursor/
│   ├── .cursor-plugin/                  (plugin.json + marketplace.json)
│   ├── rules/always-on-core.mdc.tmpl    (alwaysApply: true wrapper around hooks/always-on-core.md.tmpl)
│   ├── hooks/hooks.json                 (sessionStart / preToolUse / beforeShellExecution)
│   └── scripts/*.sh                     (3 hook scripts — Cursor JSON I/O)
└── antigravity/
    ├── AGENTS.md.tmpl
    ├── plugin.json                      (agy plugin manifest)
    └── hooks/hooks.json                 (PreInvocation / PreToolUse / PostToolUse — reuses the gemini hook scripts)
```

`build/render.sh` renders the Claude, Codex, and Cursor plugin trees into committed `plugins/rolepod/`, `plugins/rolepod-codex/`, `plugins/rolepod-cursor/` paths, and the Gemini extension + Antigravity plugin into gitignored `build/rendered/gemini/` and `build/rendered/antigravity/`. Per-CLI agent files are generated by `build/merge-agent.py` from `core/agents/<name>.md` + the `agent-frontmatter/` overlay (Codex agents emit as TOML; Claude / Gemini emit Markdown with full frontmatter; Cursor emits Markdown with `name` + `description` only — no overlay needed). `install.sh` copies the rendered tree to the install destination above.

## Hook event mapping

| Event class | Claude Code | Codex CLI | Gemini CLI | Cursor IDE |
|---|---|---|---|---|
| Session start | `SessionStart` (`startup\|resume`) | `SessionStart` (`startup\|resume`) | `SessionStart` (`startup\|resume\|clear`) | `sessionStart` (no matcher) |
| Prompt submit (claim-verify nudge) | `UserPromptSubmit` (no matcher) | `UserPromptSubmit` (no matcher) | `BeforeAgent` (`*`) | — (`beforeSubmitPrompt` fires on submit but cannot inject pre-answer context) |
| Before tool run | `PreToolUse` (`Edit\|Write\|MultiEdit`, `Bash`, `Agent`) | `PreToolUse` (`apply_patch`, `Bash`) | `BeforeTool` (`write_file\|replace\|edit`) | `preToolUse` (`Write\|Edit\|MultiEdit`); `beforeShellExecution` (`git[[:space:]]+commit`) |
| After tool run | `PostToolUse` (`Edit\|Write`, `Bash`) | `PostToolUse` (`apply_patch`, `Bash`) | `AfterTool` (`write_file\|replace\|edit`) | — (uses `beforeShellExecution` for commit gate; no observational hooks yet) |
| Stop / compact | `Stop` (no matcher) | — | `PreCompress` | — (sessionEnd/stop reserved for future use) |

Per-CLI hook counts (distinct scripts): Claude registers 9 core hook scripts via the plugin manifest (10 registrations — `session-lifecycle.sh` registers twice, `--lock`/`--unlock`). Codex registers 4 in `hooks/hooks.json` (requires `codex features enable plugin_hooks` opt-in; plugin-bundled hooks must be trusted by the user before they fire). Gemini registers 5 in `hooks/hooks.json`. Cursor registers 3 in `hooks/hooks.json` (always-on judgment uses an `alwaysApply` rule instead of a SessionStart hook, so the loader script is folded into the rule). Antigravity registers 4 in `hooks.json` at the plugin root (reusing the gemini scripts; no PreCompress equivalent). The `claim-verify-nudge` answer-path hook ships on Claude / Codex / Gemini / Antigravity but not Cursor — Cursor's `beforeSubmitPrompt` cannot inject pre-answer context. Rolepod ships no add-on hooks — claude-mem and GitNexus integrate via their own vendor plugins/CLI.

## Verification status — what's confirmed locally

| Item | Verified by |
|---|---|
| Claude snapshot | 16 agent files + plugin tree layout |
| Codex plugin layout | install registers `[marketplaces.rolepod]` + `[plugins."rolepod@rolepod"] enabled = true` in `~/.codex/config.toml` and writes the `~/.codex/AGENTS.md` managed block; committed marketplace tree at the repo root (`.agents/plugins/marketplace.json` + `plugins/rolepod-codex/{.codex-plugin,hooks,skills}/`) — the plugin bundles hooks + skills, the 16 agent TOMLs install to `~/.codex/agents/` |
| Gemini extension layout | dry-run install populates `~/.gemini/extensions/rolepod/{GEMINI.md,gemini-extension.json,hooks,skills}/` — entry doc ships inside the extension dir, global `~/.gemini/GEMINI.md` untouched |
| All shell scripts | `bash -n` clean (install.sh, bootstrap.sh, render.sh, 9 core hook scripts, 4 codex hook scripts, 5 gemini hook scripts, 3 cursor scripts) |
| All JSON manifests | `python3 -m json.tool` clean (plugin.json x4 — claude/codex/cursor/antigravity, hooks.json x5 — claude/codex/gemini/cursor/antigravity, marketplace.json x2 — claude/cursor, gemini-extension.json) |
| All TOML files | `tomllib.load()` clean (16 codex agents) |
| Render output | `build/render.sh --target=all` produces all 5 trees with no `{{INCLUDE: ...}}` leaks |

## Runtime verification status

| Target | Static checks | Dry-run install | Live runtime hooks | Live subagent dispatch | Status |
|--------|---------------|-----------------|--------------------|-----------------------|--------|
| Claude Code | ✓ | ✓ | ✓ verified | ✓ verified | **Production** |
| Codex CLI   | ✓ | ✓ | ⚠️ opt-in only — `features.plugin_hooks` is "under development, false" by default; rolepod registers `hooks/hooks.json` but Codex won't fire them until user runs `codex features enable plugin_hooks` | ✓ verified (16 agents + 10 skills via native loader) | **Production** (hooks opt-in) |
| Gemini CLI  | ✓ | ✓ | ✓ verified (SessionStart hook fires) | ✓ verified (10 skills enumerated) | **Production** |
| Cursor IDE  | ✓ | ✓ | ⚠️ live re-verification pending (always-on rule + 3 hooks ship; hook JSON I/O contract verified against [cursor.com/docs/hooks](https://cursor.com/docs/hooks) 2026-05-23 fetch but not exercised on a live Cursor session yet) | ⚠️ live re-verification pending (16 agents + 11 skills ship with minimal-frontmatter shape; subagent dispatch unverified) | **Beta** (static + install paths verified; live runtime confirmation pending) |
| Antigravity CLI (agy) | ✓ (`agy plugin validate` [ok] on agy 1.0.13; integration test locks the schema) | ✓ (live `agy plugin install`/`uninstall` round-trip verified; temp-target guard proven) | ⚠️ hooks registered ("3 hook event types processed"); live firing unverified | ⚠️ runtime probe blocked on agy model quota (resets 2026-07-02) | **Beta** (install verified live; runtime session confirmation pending) |

**Static checks** = `bash -n` on shell scripts, `python3 -m json.tool` on JSON manifests, `tomllib.load()` on TOML, plus snapshot diffs (no leaked `{{INCLUDE: ...}}` placeholders). **Dry-run install** = `install.sh --target=<cli>` writes correct files into a temp dir and the layout matches each CLI's expected destination. **Live** = installed in the real CLI, hooks fire on real sessions (Claude + Gemini always; Codex only after `codex features enable plugin_hooks` opt-in; Cursor pending), subagents/skills dispatch correctly.

_Last live-verified: 2026-05-23 on macOS (Darwin 25.5.0), Codex 0.132.0, Gemini 0.42.0, running rolepod 2.6.0 / Gemini extension 0.6.0 (counts at that time: 18 agents, 11 skills, Claude 7 / Codex 3 / Gemini 4 / Cursor 3 hooks). **2.6.2:** content trio merged into single `content-strategist` agent — roster 18 → 16. **2.9.x (current tree):** hook scripts are Claude 9 (10 registrations — worktree-guard, always-on-loader, session-lifecycle ×2, claim-verify-nudge included) / Codex 4 / Gemini 5 / Cursor 3 / Antigravity 4; agents 16; skills 11. Antigravity adapter added 2026-06-30, install-path verified live on agy 1.0.13; Cursor + Antigravity live runtime confirmation are the open items._

### Per-target runtime evidence

**Claude Code** — Production. Hooks/agents/skills load on session start; verified across the dev loop in this repository.

**Gemini CLI 0.42.0** — Production:
- `gemini skills list` enumerates all 11 rolepod skills (Core 10 + the `rolepod-full` alias) from `~/.gemini/extensions/rolepod/skills/`.
- SessionStart hook fires and emits the rolepod gates banner ("rolepod gates: S1-S5 simplicity + T1-T6 tests + Q1-Q4 delegation + F1-F5 failure-mode") on every Gemini session.
- The model recognizes the extension by name and version (`rolepod (v0.6.0)`) when asked.
- No native `.toml` slash commands ship — `/rolepod-full` is the `rolepod-full` skill, invocable across Claude/Codex/Gemini skill UIs. Phase commands (`/spec`/`/plan`/`/review`/`/test`/`/ship`) were dropped to match Claude's design (commits 0f8de4f / 6da9fe0 documented pattern-match drift).
- Caveat: the bundled SessionStart hook expects ripgrep — falls back to GrepTool with a one-line warning. Cosmetic only.

**Codex CLI 0.132.0** — Production:
- The rolepod repo IS a Codex marketplace — `.agents/plugins/marketplace.json` + the committed `plugins/rolepod-codex/` tree at the repo root. `codex plugin marketplace add nuttaruj/rolepod` installs straight from GitHub; `install.sh` runs the same `codex plugin marketplace add <repo>` against the local clone. Codex's native plugin loader picks up skills + hooks via the same code path as bundled plugins (browser-use, computer-use, etc.).
- After install, `~/.codex/config.toml` contains `[marketplaces.rolepod] source_type = "local"` and `[plugins."rolepod@rolepod"] enabled = true`.
- Plugin hooks (`hooks/hooks.json`) require explicit opt-in. Default Codex install has `plugin_hooks` flagged `under development, false` — registered hooks won't fire until the user enables it:
  ```bash
  codex features list | grep plugin_hooks      # confirm current state
  codex features enable plugin_hooks           # writes [features] plugin_hooks = true
  ```
  Without that flag, rolepod's `hooks/hooks.json` is registered but inert. Agents + skills still load via the plugin cache regardless of `plugin_hooks` state.
- Live verification after enabling `plugin_hooks`: `codex exec --skip-git-repo-check "echo OK"` reports `hook: SessionStart Completed` from rolepod's `hooks/hooks.json`. Codex log (`~/.codex/log/codex-tui.log`) shows zero "configured non-curated plugin no longer exists" warnings for rolepod and zero manifest validation errors against `plugins/rolepod/.codex-plugin/plugin.json`.
- `~/.codex/AGENTS.md` managed block still loads on every Codex session (Tier 1 always-on rules), independent of plugin enable state.
- The CLI subcommands `plugin list` / `agent` / `skills list` / `hooks list` are not present in 0.132.0 — Codex doesn't expose enumeration commands today. The plugin still loads via the same code path as bundled plugins; verification is via session log + `config.toml` inspection.

**Cursor IDE** — Beta (static + install verified; live runtime confirmation pending):
- Plugin layout follows the official [cursor.com/docs/plugins](https://cursor.com/docs/plugins) spec and the [cursor/plugin-template](https://github.com/cursor/plugin-template) starter (verified against both 2026-05-23): `.cursor-plugin/plugin.json`, `rules/*.mdc`, `skills/<name>/SKILL.md`, `agents/*.md`, `hooks/hooks.json`, `scripts/*.sh`.
- Always-on judgment core ships as `rules/always-on-core.mdc` with `alwaysApply: true` — Cursor's native equivalent of Claude's SessionStart-emit pattern. No user-global config is touched on install or uninstall.
- 3 core hooks: `sessionStart` (project context loader), `preToolUse:Write|Edit|MultiEdit` (gate-reminder for schema-bound + high-risk paths), `beforeShellExecution:git commit` (precommit-gate). Hook JSON I/O follows [cursor.com/docs/hooks](https://cursor.com/docs/hooks): stdin JSON with `tool_name`/`tool_input`/`command` fields, stdout JSON with `permission`/`user_message`/`agent_message`/`additional_context`. Exit code 2 = deny.
- Skill frontmatter is intentionally stripped to `name` + `description` only (the two fields Cursor documents). Claude-specific keys (`tier`, `phase`, `when_to_use`, `disable-model-invocation`) are dropped at render time to avoid gambling on tolerance for unknown fields. Caveat: the `rolepod-full` alias loses its `disable-model-invocation: true` guard — its description ("Use only when the user explicitly invokes `/rolepod-full` ...") is phrased to keep auto-trigger rare.
- Agent frontmatter likewise reduces to `name` + `description` only — no Cursor-specific overlay file exists. The same 16 agent bodies ship across all CLIs.
- Local install path: `~/.cursor/plugins/local/rolepod/` (per Cursor's local-plugin convention). The repo's committed `.cursor-plugin/marketplace.json` also makes the GitHub URL importable as a team marketplace.
- Live re-verification pending: hook JSON I/O fields match the doc but have not yet been exercised on a real Cursor session.

Help close the gap — install on Codex / Gemini / Cursor and report at [issues/](https://github.com/nuttaruj/rolepod/issues).

## Notes on subagent behavior

- **Claude Code**: agents auto-spawn via the `Task` / `SendMessage` tool — Lead delegates and merges results in parallel.
- **Codex CLI**: 16 `agents/*.toml` are registered with the plugin and load via the plugin loader. Codex doesn't currently expose a public `codex agent` subcommand or a parallel-fanout primitive equivalent to Claude's `Task`, so verification is via plugin config, session logs, and observed dispatch behavior — Lead orchestrates by inline reading of the relevant agent's `developer_instructions` block.
- **Gemini CLI / Antigravity**: 16 agent definitions ship as extension `agents/*.md`; builds with sub-agent support load them natively, older builds fall back to the roster table in the entry doc (Lead reads the relevant agent's section and acts in-character).

The path-based ownership rules from `write-plan` apply identically across all CLIs — same agent picks the same paths regardless of which CLI is in charge of orchestration.

## Recommended Claude Code setup

Claude Code supports both global and project-level configuration. Rolepod installs as a marketplace plugin.

### Global install (one-time per machine)

```bash
./install.sh --target=claude
```

Runs `claude plugin marketplace add <repo>` + `claude plugin install rolepod@rolepod --scope user` to register and enable the plugin — the repo IS the marketplace (`.claude-plugin/marketplace.json` + committed `plugins/rolepod/`), so `claude plugin marketplace add nuttaruj/rolepod` does the same straight from GitHub. Installs:
- the rolepod plugin (agents, skills, hooks, manifest) — Claude Code resolves it from the marketplace cache
- Plugin hooks (7 core) in the plugin's `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}` paths

### Per-project install (`--scope=project`)

Drop the rolepod plugin + rules into a single project without touching `~/.claude/`:

```bash
cd /your/project
./install.sh --target=claude --scope=project
```

Writes `$PWD/.claude/plugins/rolepod/` with the full plugin tree. Claude auto-loads project `.claude/settings.json` (plugin settings), so rolepod fires on this project only.

### Project-specific CLAUDE.md override (optional, user-level)

When a repo needs stricter rules beyond rolepod, create your own `CLAUDE.md` at the repo root with custom overrides. Claude precedence: repo-root `CLAUDE.md` > global always-on-core. Rolepod's rules still apply unless explicitly overridden. See [Claude Code docs](https://docs.claude.com/en/docs/claude-code/memory).

### Verify install

```bash
claude plugin list                      # Should show "rolepod" as enabled
ls ~/.claude/plugins/rolepod/           # Plugin tree present
claude -p "say OK"                      # SessionStart hook fires; always-on-core emitted
```

If the plugin doesn't appear, run `claude plugin list` to check registration. If hooks don't fire, restart Claude Code so the plugin system reloads.

## Recommended Codex setup

Codex CLI supports both global and project-level configuration. Rolepod's installer ships global by default (`~/.codex/`) but project-level overrides are useful when a repo needs strict rules.

### Per-project install (`--scope=project`)

Drop rolepod's Tier 1 rules into a single project without touching `~/.codex/`:

```bash
cd /your/project
./install.sh --target=codex --scope=project
```

**Rules-only project install.** Writes only `$PWD/AGENTS.md` (managed block). Codex auto-loads `AGENTS.md` from the working directory on session start. **Native plugin agents/skills/hooks are NOT installed per-project** — Codex CLI's marketplace + plugin cache are global-only by design. For full Codex activation (16 agents, 10 skills, hooks), run `--scope=global` separately.

Codex hooks (`features.plugin_hooks = true`) require explicit opt-in in `~/.codex/config.toml` — not auto-enabled by rolepod install.

### Global core (one-time per machine)

```bash
./install.sh --target=codex
```

Installs:
- `~/.codex/AGENTS.md` (managed block — your existing content preserved)
- `[marketplaces.rolepod]` + `[plugins."rolepod@rolepod"] enabled = true` in `~/.codex/config.toml`
- Marketplace source: the rolepod repo root (`.agents/plugins/marketplace.json` + the committed `plugins/rolepod-codex/` tree). `codex plugin marketplace add nuttaruj/rolepod` consumes it from GitHub; `install.sh` registers the local clone

Restart any open Codex sessions after install so the plugin loader picks up the new registration.

### Marketplace registration is global

Codex CLI has no `CODEX_HOME` env var or `--config-home` flag — `codex plugin marketplace add` always writes to `~/.codex/config.toml`, no matter where rolepod's filesystem files land. Two things follow:

1. **`ROLEPOD_TARGET` does NOT isolate the marketplace.** When `ROLEPOD_TARGET` (or `ROLEPOD_CODEX_TARGET`) points to a temp dir, the installer detects this and **skips** `codex plugin marketplace add` entirely so it cannot mutate the user's real `~/.codex/config.toml`. AGENTS.md and the rendered plugin tree still land under the temp dir for inspection, but the Codex loader will not see them. Use `--dry-run` for fully isolated previews:
   ```bash
   ROLEPOD_TARGET=/tmp/rolepod-test ./install.sh --target=codex --dry-run
   ```
2. **Re-installing from a different rendered path needs `--force`.** If rolepod is already registered from a different source (e.g. you moved the repo), a plain `./install.sh --target=codex` exits with a remediation message. Pick one:
   ```bash
   ./install.sh --target=codex --force        # auto remove + re-add with current source
   # or
   codex plugin marketplace remove rolepod    # manual cleanup
   ./install.sh --target=codex
   ```

### `--force` backup is rolepod-scoped

When `--force` is used on an existing CLI home (`~/.claude/`, `~/.codex/`, `~/.gemini/`), the installer creates `~/.<cli>.backup-<timestamp>/` containing **only rolepod-managed paths**:

| CLI | Backed up | Excluded |
|-----|-----------|----------|
| Claude  | `CLAUDE.md`, `CHEATSHEET.md`, `README.md`, `rules/`, `settings.json`, `agents/`, `hooks/`, `skills/`, `commands/`, `.claude-plugin/`, `plugins/rolepod/` | `projects/` (session history), `plugins/cache/`, `plugins/marketplaces/`, `file-history/`, `shell-snapshots/`, `session-env/`, `scheduled-tasks/`, `cache/`, `agent-memory/`, `backups/`, `teams/` |
| Codex   | `AGENTS.md`, `config.toml`, `plugins/rolepod/`, `.agents/`                                                                          | `log/`, `.tmp/`, `history/`, `sessions/` |
| Gemini  | `GEMINI.md`, `extensions/rolepod/`, `settings.json`                                                                                | `history/`, `log/`, `tmp/` |

Rationale: a user's session transcripts (`~/.claude/projects/`) can exceed 1.8GB on active accounts. Duplicating them on every `--force` run wasted disk and time. Typical rolepod-scoped backup is <50MB. Restore is straightforward: `cp -R ~/.claude.backup-<stamp>/* ~/.claude/` (run from the backup directory).

### Project-specific AGENTS.md override (optional)

When a repo needs stricter rules than the global rolepod set, create `AGENTS.md` at the repo root with project-specific overrides. Codex precedence: repo-root `AGENTS.md` > `~/.codex/AGENTS.md`. Rolepod's global rules still apply unless explicitly overridden. See [Codex config docs](https://github.com/openai/codex/blob/main/docs/config.md).

### Verify install

```bash
# Plugin loaded (agents + skills work regardless of plugin_hooks state):
ls ~/.codex/plugins/cache/rolepod/rolepod/*/skills | wc -l   # 11

# Hooks ONLY fire after opt-in. Confirm flag state first:
codex features list | grep plugin_hooks
# default: plugin_hooks  under development  false

# Enable hooks:
codex features enable plugin_hooks

# After opt-in, verify hooks fire:
codex exec --skip-git-repo-check "echo OK"
# stdout shows: hook: SessionStart Completed (rolepod hooks firing through native plugin loader)
# Without plugin_hooks=true, this line is absent — rolepod's hooks/hooks.json is registered but inert.

# AGENTS.md (Tier 1) always loads regardless of plugin_hooks:
grep -A2 'marketplaces.rolepod\|plugins."rolepod' ~/.codex/config.toml
```

If hooks don't fire after the opt-in, check `plugins/rolepod/hooks/hooks.json` schema matches [developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks).

## Recommended Gemini setup

Gemini CLI uses an extension model. Rolepod ships as a global extension; project-level `GEMINI.md` overrides apply on top.

### Per-project install (`--scope=project`)

Drop rolepod's Tier 1 rules into a single project without touching `~/.gemini/`:

```bash
cd /your/project
./install.sh --target=gemini --scope=project
```

**Rules-only project install.** Writes only `$PWD/GEMINI.md` (managed block). Gemini auto-loads `GEMINI.md` from the working directory on session start. **Native extension commands/skills/hooks are NOT installed per-project** — Gemini CLI's extension system is global-only by design. For full Gemini activation, run `--scope=global` separately.

### Global core (one-time per machine)

```bash
./install.sh --target=gemini
```

Installs:
- `~/.gemini/extensions/rolepod/` (full extension: `GEMINI.md` context file, 16 agents in `agents/`, 11 skills, 5 hooks)
- The global `~/.gemini/GEMINI.md` is left untouched — rolepod's context loads via the extension's `contextFileName`. A pre-PR-8 install's stale managed block in the global file is stripped on the next run.

### Project-specific GEMINI.md override (optional)

Create `GEMINI.md` at the repo root with project-specific overrides. Gemini precedence: repo-root `GEMINI.md` > `~/.gemini/GEMINI.md`. See [Gemini CLI configuration docs](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/configuration.md).

### Verify install

```bash
gemini extensions list
# Should show 'rolepod' as an enabled extension
gemini
# /rolepod-full available via the rolepod-full skill (cross-CLI)
# Hooks fire automatically (SessionStart / BeforeAgent / BeforeTool / AfterTool / PreCompress)
```

If the extension doesn't appear, check `~/.gemini/extensions/rolepod/gemini-extension.json` matches the schema at [Gemini extensions docs](https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions.md).
