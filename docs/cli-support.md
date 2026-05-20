# Rolepod — Per-CLI Support Matrix

Phase 2.3: rolepod ships for each supported CLI as a **native plugin / extension** — agents, skills, and hooks all wire into each CLI's own primitives. No wrapper scripts.

## Capability matrix

| Capability | Claude Code | Codex CLI | Gemini CLI |
|---|---|---|---|
| Always-on instructions | `~/.claude/CLAUDE.md` (native) | `~/.codex/AGENTS.md` (native) | `~/.gemini/extensions/rolepod/GEMINI.md` (extension context file) |
| Lazy-load rules (Read on trigger) | full | full | full |
| Skills (`<plugin>/skills/<name>/SKILL.md`) | 10 Core 10 (native) | 10 Core 10 (native) | 10 Core 10 (native) |
| Subagents (parallel team) | full Task / SendMessage (18 agents) | 18 agents as Codex `agents/*.toml` (Lead-orchestrated) | 18 agents inlined in `GEMINI.md` (Lead-orchestrated) |
| Hooks (auto reminders) | 8 hooks (6 core + 2 GitNexus add-on) · 7 registered by default, +1 when GitNexus plugin detected | 3 commands across 2 event classes (`SessionStart`/`PreToolUse`) · optional GitNexus `post-ship-detect.sh` ships but not registered by default · optional MemPalace `optional/mempalace/codex-session-start.sh` registered automatically when `command -v mempalace` succeeds at install time (self-guarded otherwise) | 4 commands across 4 event classes (`SessionStart`/`BeforeTool`/`AfterTool`/`PreCompress`) |
| Slash commands | `/rolepod-team` (slash) + `/rolepod` (skill explicit-invoke) | n/a (Codex slash schema — `/rolepod` reaches the skill via Codex skill-slash UI) | `/rolepod` via skill (no native `.toml` commands — phase commands were dropped to match Claude's design) |
| Plugin manifest | `.claude-plugin/plugin.json` (spec-conformant, 598B) | `.codex-plugin/plugin.json` (mirrors caveman schema, 1.6KB) | `gemini-extension.json` (extension schema, 551B) |
| MemPalace / GitNexus integration | hook-level integration (MemPalace + GitNexus wrapper when installed) | plugin/entry-doc integration; hooks require `plugin_hooks` opt-in | extension/entry-doc integration; Claude-only enforcement hooks do not apply |
| MCP server config | global + per-plugin | global (`codex mcp`) | global (`gemini mcp`) |

## Install destinations

| CLI | Plugin / extension destination | Entry doc destination |
|---|---|---|
| Claude Code | `~/.claude/` (agents/, rules/, hooks/, skills/, commands/, .claude-plugin/) | `~/.claude/CLAUDE.md` |
| Codex CLI | rolepod marketplace registered in `~/.codex/config.toml`; plugin tree resolved from `<repo>/build/rendered/codex/plugins/rolepod/` (.codex-plugin/, agents/, hooks/, skills/) | `~/.codex/AGENTS.md` |
| Gemini CLI | `~/.gemini/extensions/rolepod/` (gemini-extension.json, GEMINI.md, hooks/, skills/) | `~/.gemini/extensions/rolepod/GEMINI.md` (extension context file) |

For Codex the entry doc is intentionally written **outside** the plugin dir (`~/.codex/AGENTS.md`) — Codex auto-loads the global `AGENTS.md` regardless of which plugins are installed, so keeping it at the root makes rolepod's gates active on every session, not just when the plugin is enabled.

For Gemini the entry doc ships **inside** the extension dir as `extensions/rolepod/GEMINI.md`. Gemini auto-loads it via the manifest's `contextFileName` field when the extension is enabled (the default after install). This keeps rolepod's context fully self-contained — install never touches the user's own `~/.gemini/GEMINI.md`, and uninstall is a clean `rm -rf` of the extension dir. (Pre-PR-8 installs wrote a managed block into the global `~/.gemini/GEMINI.md`; the installer strips that stale block on the next run.)

### Install path env vars

| Variable | Effect |
|---|---|
| `ROLEPOD_TARGET` | Single-target default OR root for `--target=all`. Single target overrides destination entirely; with `--target=all`, each CLI lands under `$ROLEPOD_TARGET/<cli>/` (e.g. `$ROLEPOD_TARGET/claude`, `/codex`, `/gemini`). |
| `ROLEPOD_CLAUDE_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Claude only. |
| `ROLEPOD_CODEX_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Codex only. |
| `ROLEPOD_GEMINI_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Gemini only. |

Non-TTY contexts: `--uninstall` without `--yes` exits 0 with `Aborted. Re-run with --yes in non-interactive mode.` instead of crashing on a missing `/dev/tty`.

## Adapter source layout

```
adapters/
├── claude/
│   ├── CLAUDE.md.tmpl
│   └── agent-frontmatter/*.yml         (18 frontmatter overlays)
├── codex/
│   ├── AGENTS.md.tmpl
│   ├── .agents/plugins/marketplace.json (Codex marketplace manifest)
│   └── plugins/rolepod/
│       ├── .codex-plugin/plugin.json
│       ├── agents/*.toml               (18 agents, Codex schema)
│       ├── hooks/hooks.json + 3 core *.sh (+ 1 optional in hooks/optional/gitnexus/, + 1 optional in hooks/optional/mempalace/)
│       └── skills → ../../../../core/skills (symlink, dereferenced at render time)
└── gemini/
    ├── GEMINI.md.tmpl
    ├── gemini-extension.json
    ├── commands/*.toml                 (6 slash commands)
    ├── hooks/hooks.json + 4 *.sh
    └── skills/                         (real dir, populated at render time)
```

`build/render.sh --target=<cli>` produces `build/rendered/<cli>/` — a self-contained tree that `install.sh` then copies into the install destination above.

## Hook event mapping

| Event class | Claude Code | Codex CLI | Gemini CLI |
|---|---|---|---|
| Session start | `SessionStart` (`startup\|resume`) | `SessionStart` (`startup\|resume`) | `SessionStart` (`startup\|resume\|clear`) |
| Before tool run | `PreToolUse` (`Edit\|Write\|MultiEdit`, `Bash`, `Agent`) | `PreToolUse` (`apply_patch`, `Bash`) | `BeforeTool` (`write_file\|replace\|edit`) |
| After tool run | `PostToolUse` (`Edit\|Write`, `Bash`) | `PostToolUse` (`apply_patch`, `Bash`) | `AfterTool` (`write_file\|replace\|edit`) |
| Stop / compact | `Stop` (no matcher) | — | `PreCompress` |

Per-CLI hook counts: Claude copies 8 hook scripts (6 core + 2 in `hooks/optional/gitnexus/`) and registers 7 rolepod entries via `~/.claude/settings.json` by default (8 when the GitNexus plugin is detected at install time); `gitnexus-wrap.sh` only patches the optional GitNexus plugin hook when GitNexus is installed. Codex ships 5 adapter scripts (3 core + 1 in `hooks/optional/gitnexus/` + 1 in `hooks/optional/mempalace/`); by default `hooks/hooks.json` registers 3 entries across `SessionStart` / `PreToolUse`, and `install.sh` upserts a 4th SessionStart entry pointing at `optional/mempalace/codex-session-start.sh` when `command -v mempalace` succeeds at install time. All Codex hooks require `codex features enable plugin_hooks` before they fire. Gemini ships 4 adapter command hooks across `SessionStart` / `BeforeTool` / `AfterTool` / `PreCompress`.

## Verification status — what's confirmed locally

| Item | Verified by |
|---|---|
| Claude snapshot | `diff -q` 0-byte vs prior `~/.claude/CLAUDE.md` and 18 agent files |
| Codex plugin layout | install registers `[marketplaces.rolepod]` + `[plugins."rolepod@rolepod"] enabled = true` in `~/.codex/config.toml` and writes `~/.codex/AGENTS.md` managed block; rendered tree at `build/rendered/codex/{.agents/plugins/marketplace.json,plugins/rolepod/{.codex-plugin,agents,hooks,skills}/}` is the source-of-truth Codex resolves at session start |
| Gemini extension layout | dry-run install populates `~/.gemini/extensions/rolepod/{GEMINI.md,gemini-extension.json,hooks,skills}/` — entry doc ships inside the extension dir, global `~/.gemini/GEMINI.md` untouched |
| All shell scripts | `bash -n` clean (install.sh, bootstrap.sh, render.sh, 8 hook scripts (6 core + 2 GitNexus add-on), 5 codex hook scripts (3 core + 1 GitNexus add-on + 1 MemPalace add-on), 4 gemini hook scripts) |
| All JSON manifests | `python3 -m json.tool` clean (plugin.json x2, hooks.json x2, gemini-extension.json) |
| All TOML files | `tomllib.load()` clean (18 codex agents, 6 gemini commands) |
| Render output | `build/render.sh --target=all` produces all 3 trees with no `{{INCLUDE: ...}}` leaks |

## Runtime verification status

| Target | Static checks | Dry-run install | Live runtime hooks | Live subagent dispatch | Status |
|--------|---------------|-----------------|--------------------|-----------------------|--------|
| Claude Code | ✓ | ✓ | ✓ verified | ✓ verified | **Production** |
| Codex CLI   | ✓ | ✓ | ⚠️ opt-in only — `features.plugin_hooks` is "under development, false" by default; rolepod registers `hooks/hooks.json` but Codex won't fire them until user runs `codex features enable plugin_hooks` | ✓ verified (18 agents + 10 skills via native loader) | **Production** (hooks opt-in) |
| Gemini CLI  | ✓ | ✓ | ✓ verified (SessionStart hook fires) | ✓ verified (10 skills enumerated) | **Production** |

**Static checks** = `bash -n` on shell scripts, `python3 -m json.tool` on JSON manifests, `tomllib.load()` on TOML, plus snapshot diffs (no leaked `{{INCLUDE: ...}}` placeholders). **Dry-run install** = `install.sh --target=<cli>` writes correct files into a temp dir and the layout matches each CLI's expected destination. **Live** = installed in the real CLI, hooks fire on real sessions (Claude + Gemini always; Codex only after `codex features enable plugin_hooks` opt-in), subagents/skills dispatch correctly.

_Last verified: 2026-05-10 on macOS (Darwin 25.4.0), Codex 0.130.0, Gemini 0.40.1._

### Per-target runtime evidence

**Claude Code** — Production. Hooks/agents/skills load on session start; verified across the dev loop in this repository.

**Gemini CLI 0.40.1** — Production:
- `gemini skills list` enumerates all 10 rolepod Core 10 skills from `~/.gemini/extensions/rolepod/skills/`.
- SessionStart hook fires and emits the rolepod gates banner ("rolepod gates: S1-S5 simplicity + T1-T6 tests + Q1-Q4 delegation + F1-F5 failure-mode") on every Gemini session.
- The model recognizes the extension by name and version (`rolepod (v0.2.0)`) when asked.
- No native `.toml` slash commands ship — `/rolepod` reaches the `using-rolepod` skill via Gemini's skill auto-trigger, same as Claude/Codex. Phase commands (`/spec`/`/plan`/`/review`/`/test`/`/ship`) were dropped to match Claude's design (commits 0f8de4f / 6da9fe0 documented pattern-match drift).
- Caveat: the bundled SessionStart hook expects ripgrep — falls back to GrepTool with a one-line warning. Cosmetic only.

**Codex CLI 0.130.0** — Production:
- Rolepod ships as a Codex marketplace consumable (`adapters/codex/.agents/plugins/marketplace.json` + `plugins/rolepod/`). The installer renders to `build/rendered/codex/` and runs `codex plugin marketplace add <rendered-dir>` so Codex's native plugin loader picks up agents, skills, and hooks via the same code path as bundled plugins (browser-use, computer-use, etc.).
- After install, `~/.codex/config.toml` contains `[marketplaces.rolepod] source_type = "local"` and `[plugins."rolepod@rolepod"] enabled = true`.
- Plugin hooks (`hooks/hooks.json`) require explicit opt-in. Default Codex install has `plugin_hooks` flagged `under development, false` — registered hooks won't fire until the user enables it:
  ```bash
  codex features list | grep plugin_hooks      # confirm current state
  codex features enable plugin_hooks           # writes [features] plugin_hooks = true
  ```
  Without that flag, rolepod's `hooks/hooks.json` is registered but inert. Agents + skills still load via the plugin cache regardless of `plugin_hooks` state.
- Live verification after enabling `plugin_hooks`: `codex exec --skip-git-repo-check "echo OK"` reports `hook: SessionStart Completed` from rolepod's `hooks/hooks.json`. Codex log (`~/.codex/log/codex-tui.log`) shows zero "configured non-curated plugin no longer exists" warnings for rolepod and zero manifest validation errors against `plugins/rolepod/.codex-plugin/plugin.json`.
- `~/.codex/AGENTS.md` managed block still loads on every Codex session (Tier 1 always-on rules), independent of plugin enable state.
- The CLI subcommands `plugin list` / `agent` / `skills list` / `hooks list` are not present in 0.130.0 — Codex doesn't expose enumeration commands today. The plugin still loads via the same code path as bundled plugins; verification is via session log + `config.toml` inspection.

Help close the gap — install on Codex / Gemini and report at [issues/](https://github.com/nuttaruj/rolepod/issues).

## Notes on subagent behavior

- **Claude Code**: agents auto-spawn via the `Task` / `SendMessage` tool — Lead delegates and merges results in parallel.
- **Codex CLI**: 18 `agents/*.toml` are registered with the plugin and load via the plugin loader. Codex doesn't currently expose a public `codex agent` subcommand or a parallel-fanout primitive equivalent to Claude's `Task`, so verification is via plugin config, session logs, and observed dispatch behavior — Lead orchestrates by inline reading of the relevant agent's `developer_instructions` block.
- **Gemini CLI**: agents are inlined in `GEMINI.md` as a roster table. Lead reads the relevant agent's section and acts in-character. Gemini Code Assist is adding richer multi-agent primitives — when those land, the Gemini adapter will switch to native dispatch.

The path-based ownership rules from `write-plan` apply identically across all three CLIs — same agent picks the same paths regardless of which CLI is in charge of orchestration.

## Recommended Claude Code setup

Claude Code supports both global and project-level configuration. Rolepod's installer ships global by default (`~/.claude/`) but per-project installs land the full plugin in `$PWD/.claude/`.

### Per-project install (`--scope=project`)

Drop the full rolepod plugin (agents + skills + hooks + entry doc) into a single project without touching `~/.claude/`:

```bash
cd /your/project
./install.sh --target=claude --scope=project
```

Writes `$PWD/.claude/` with the full plugin tree plus `$PWD/CLAUDE.md` (managed block). Claude auto-loads project `.claude/settings.json` so the rolepod hooks fire on this project only.

### Global core (one-time per machine)

```bash
./install.sh --target=claude
```

Installs:
- `~/.claude/CLAUDE.md` (managed block — your existing content preserved)
- `~/.claude/agents/*.md` (18 agents)
- `~/.claude/skills/<name>/SKILL.md` (10 Core 10 skills)
- `~/.claude/commands/*.md` (slash commands)
- Hook entries appended idempotently to `~/.claude/settings.json` (2x `SessionStart`, 4x `PreToolUse`, 2x `PostToolUse`, 1x `Stop`; GitNexus wrapper patch is optional)
- `~/.claude/.claude-plugin/plugin.json` (manifest)

### Project-specific CLAUDE.md override (optional)

When a repo needs stricter rules than the global rolepod set, create `CLAUDE.md` at the repo root with project-specific overrides. Claude precedence: repo-root `CLAUDE.md` > `~/.claude/CLAUDE.md`. Rolepod's global rules still apply unless explicitly overridden. See [Claude Code docs](https://docs.claude.com/en/docs/claude-code/memory).

### Verify install

```bash
claude --help                           # CLI present
ls ~/.claude/agents/ | wc -l            # 18
ls ~/.claude/skills/ | wc -l            # 44
grep rolepod ~/.claude/settings.json    # hook entries present
claude -p "say OK"                      # SessionStart hook fires; banner appears in transcript
```

If hooks don't fire, check `~/.claude/settings.json` contains the rolepod hook entries pointing at `~/.claude/hooks/*.sh`.

## Recommended Codex setup

Codex CLI supports both global and project-level configuration. Rolepod's installer ships global by default (`~/.codex/`) but project-level overrides are useful when a repo needs strict rules.

### Per-project install (`--scope=project`)

Drop rolepod's Tier 1 rules into a single project without touching `~/.codex/`:

```bash
cd /your/project
./install.sh --target=codex --scope=project
```

**Rules-only project install.** Writes only `$PWD/AGENTS.md` (managed block). Codex auto-loads `AGENTS.md` from the working directory on session start. **Native plugin agents/skills/hooks are NOT installed per-project** — Codex CLI's marketplace + plugin cache are global-only by design. For full Codex activation (18 agents, 10 skills, hooks), run `--scope=global` separately.

Codex hooks (`features.plugin_hooks = true`) require explicit opt-in in `~/.codex/config.toml` — not auto-enabled by rolepod install.

### Global core (one-time per machine)

```bash
./install.sh --target=codex
```

Installs:
- `~/.codex/AGENTS.md` (managed block — your existing content preserved)
- `[marketplaces.rolepod]` + `[plugins."rolepod@rolepod"] enabled = true` in `~/.codex/config.toml`
- Marketplace source: `<repo>/build/rendered/codex/` (Codex resolves the plugin tree from here at session start — keep the rendered dir on disk; `./install.sh --target=codex` re-renders it idempotently)

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
| Claude  | `CLAUDE.md`, `CHEATSHEET.md`, `README.md`, `agents/`, `rules/`, `hooks/`, `skills/`, `commands/`, `.claude-plugin/`, `settings.json` | `projects/` (session history), `plugins/cache/`, `plugins/marketplaces/`, `file-history/`, `shell-snapshots/`, `session-env/`, `scheduled-tasks/`, `cache/`, `agent-memory/`, `backups/`, `teams/` |
| Codex   | `AGENTS.md`, `config.toml`, `plugins/rolepod/`, `.agents/`                                                                          | `log/`, `.tmp/`, `history/`, `sessions/` |
| Gemini  | `GEMINI.md`, `extensions/rolepod/`, `settings.json`                                                                                | `history/`, `log/`, `tmp/` |

Rationale: a user's session transcripts (`~/.claude/projects/`) can exceed 1.8GB on active accounts. Duplicating them on every `--force` run wasted disk and time. Typical rolepod-scoped backup is <50MB. Restore is straightforward: `cp -R ~/.claude.backup-<stamp>/* ~/.claude/` (run from the backup directory).

### Project-level GitNexus index (one-time per repo)

```bash
cd /your/project
npx gitnexus analyze
```

Indexes the codebase for impact-analysis tools. GitNexus index is per-repo, not per-CLI.

### Project-specific AGENTS.md override (optional)

When a repo needs stricter rules than the global rolepod set, create `AGENTS.md` at the repo root with project-specific overrides. Codex precedence: repo-root `AGENTS.md` > `~/.codex/AGENTS.md`. Rolepod's global rules still apply unless explicitly overridden. See [Codex config docs](https://github.com/openai/codex/blob/main/docs/config.md).

### Verify install

```bash
# Plugin loaded (agents + skills work regardless of plugin_hooks state):
ls ~/.codex/plugins/cache/rolepod/rolepod/0.1.0/skills | wc -l   # 44

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
- `~/.gemini/extensions/rolepod/` (full extension: `GEMINI.md` context file, 18 agents inlined, 10 Core 10 skills, 4 hooks)
- The global `~/.gemini/GEMINI.md` is left untouched — rolepod's context loads via the extension's `contextFileName`. A pre-PR-8 install's stale managed block in the global file is stripped on the next run.

### Project-level GitNexus index (one-time per repo)

```bash
cd /your/project
npx gitnexus analyze
```

Same per-repo index as the Codex flow — GitNexus is CLI-agnostic.

### Project-specific GEMINI.md override (optional)

Create `GEMINI.md` at the repo root with project-specific overrides. Gemini precedence: repo-root `GEMINI.md` > `~/.gemini/GEMINI.md`. See [Gemini CLI configuration docs](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/configuration.md).

### Verify install

```bash
gemini extensions list
# Should show 'rolepod' as an enabled extension
gemini
# /rolepod available via using-rolepod skill explicit-invoke (cross-CLI)
# Hooks fire automatically (SessionStart / BeforeTool / AfterTool)
```

If the extension doesn't appear, check `~/.gemini/extensions/rolepod/gemini-extension.json` matches the schema at [Gemini extensions docs](https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions.md).
