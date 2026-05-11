# Rolepod — Per-CLI Support Matrix

Phase 2.3: rolepod ships for each supported CLI as a **native plugin / extension** — agents, skills, and hooks all wire into each CLI's own primitives. No wrapper scripts.

## Capability matrix

| Capability | Claude Code | Codex CLI | Gemini CLI |
|---|---|---|---|
| Always-on instructions | `~/.claude/CLAUDE.md` (native) | `~/.codex/AGENTS.md` (native) | `~/.gemini/GEMINI.md` (native) |
| Lazy-load rules (Read on trigger) | full | full | full |
| Skills (`<plugin>/skills/<name>/SKILL.md`) | 34 native | 34 native | 34 native |
| Subagents (parallel team) | full Task / SendMessage (18 agents) | 18 agents as Codex `agents/*.toml` (Lead-orchestrated) | 18 agents inlined in `GEMINI.md` (Lead-orchestrated) |
| Hooks (auto reminders) | 3 hooks (`SessionStart` + 2x `PostToolUse`) | 3 hooks (`SessionStart` + 2x `PostToolUse`) | 3 hooks (`SessionStart` + `BeforeTool` + `AfterTool`) |
| Slash commands | full (e.g. `/careful`, `/ship`, `/review`, `/test`, `/plan`, `/spec`) | n/a (commands not in current Codex schema) | full (6 commands as `commands/*.toml`) |
| Plugin manifest | `.claude-plugin/plugin.json` (spec-conformant, 598B) | `.codex-plugin/plugin.json` (mirrors caveman schema, 1.6KB) | `gemini-extension.json` (extension schema, 551B) |
| MemPalace / GitNexus integration | full hook coverage | full hook coverage (same 3 scripts as Claude) | full hook coverage (3 scripts) |
| MCP server config | global + per-plugin | global (`codex mcp`) | global (`gemini mcp`) |

## Install destinations

| CLI | Plugin / extension destination | Entry doc destination |
|---|---|---|
| Claude Code | `~/.claude/` (agents/, rules/, hooks/, skills/, commands/, .claude-plugin/) | `~/.claude/CLAUDE.md` |
| Codex CLI | rolepod marketplace registered in `~/.codex/config.toml`; plugin tree resolved from `<repo>/build/rendered/codex/plugins/rolepod/` (.codex-plugin/, agents/, hooks/, skills/) | `~/.codex/AGENTS.md` |
| Gemini CLI | `~/.gemini/extensions/rolepod/` (gemini-extension.json, commands/, hooks/, skills/) | `~/.gemini/GEMINI.md` |

The entry doc is intentionally written **outside** the plugin/extension dir for Codex and Gemini — both CLIs auto-load the global `AGENTS.md` / `GEMINI.md` regardless of which plugins are installed, so keeping the entry doc at the root makes rolepod's gates active on every session, not just when the plugin is enabled.

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
│       ├── hooks/hooks.json + 3 *.sh
│       └── skills → ../../../../core/skills (symlink, dereferenced at render time)
└── gemini/
    ├── GEMINI.md.tmpl
    ├── gemini-extension.json
    ├── commands/*.toml                 (6 slash commands)
    ├── hooks/hooks.json + 3 *.sh
    └── skills/                         (real dir, populated at render time)
```

`build/render.sh --target=<cli>` produces `build/rendered/<cli>/` — a self-contained tree that `install.sh` then copies into the install destination above.

## Hook event mapping

| Event class | Claude Code | Codex CLI | Gemini CLI |
|---|---|---|---|
| Session start | `SessionStart` (matcher `startup\|resume`) | `SessionStart` (matcher `startup\|resume`) | `SessionStart` (matcher `*`) |
| Before tool run | — (CLI handles native compact) | — (CLI handles native compact) | `BeforeTool` (matcher `write_file\|replace\|edit`, verify-first reminder) |
| After tool run | `PostToolUse` (matcher `Edit\|Write` and `Bash`) | `PostToolUse` (matcher `apply_patch` and `Bash`) | `AfterTool` (matcher `write_file\|replace\|edit`) |

Hook scripts are interchangeable across Claude and Codex (same 3 files: SessionStart project-context-loader, PostToolUse verify-reminder, PostToolUse post-ship-detect); Gemini ships its own 3 scripts adapted to Gemini's tool names and JSON envelope.

## Verification status — what's confirmed locally

| Item | Verified by |
|---|---|
| Claude snapshot | `diff -q` 0-byte vs prior `~/.claude/CLAUDE.md` and 18 agent files |
| Codex plugin layout | install registers `[marketplaces.rolepod]` + `[plugins."rolepod@rolepod"] enabled = true` in `~/.codex/config.toml` and writes `~/.codex/AGENTS.md` managed block; rendered tree at `build/rendered/codex/{.agents/plugins/marketplace.json,plugins/rolepod/{.codex-plugin,agents,hooks,skills}/}` is the source-of-truth Codex resolves at session start |
| Gemini extension layout | dry-run install populates `~/.gemini/extensions/rolepod/{gemini-extension.json,commands,hooks,skills}/` plus `~/.gemini/GEMINI.md` |
| All shell scripts | `bash -n` clean (install.sh, bootstrap.sh, render.sh, 3 codex hooks, 3 gemini hooks, 3 root hooks) |
| All JSON manifests | `python3 -m json.tool` clean (plugin.json x2, hooks.json x2, gemini-extension.json) |
| All TOML files | `tomllib.load()` clean (18 codex agents, 6 gemini commands) |
| Render output | `build/render.sh --target=all` produces all 3 trees with no `{{INCLUDE: ...}}` leaks |

## Runtime verification status

| Target | Static checks | Dry-run install | Live runtime hooks | Live subagent dispatch | Status |
|--------|---------------|-----------------|--------------------|-----------------------|--------|
| Claude Code | ✓ | ✓ | ✓ verified | ✓ verified | **Production** |
| Codex CLI   | ✓ | ✓ | ✓ verified (SessionStart hook fires) | ✓ verified (18 agents + 34 skills via native loader) | **Production** |
| Gemini CLI  | ✓ | ✓ | ✓ verified (SessionStart hook fires) | ✓ verified (34 skills enumerated) | **Production** |

**Static checks** = `bash -n` on shell scripts, `python3 -m json.tool` on JSON manifests, `tomllib.load()` on TOML, plus snapshot diffs (no leaked `{{INCLUDE: ...}}` placeholders). **Dry-run install** = `install.sh --target=<cli>` writes correct files into a temp dir and the layout matches each CLI's expected destination. **Live** = installed in the real CLI, hooks fire on real sessions, subagents/skills dispatch correctly.

_Last verified: 2026-05-10 on macOS (Darwin 25.4.0), Codex 0.130.0, Gemini 0.40.1._

### Per-target runtime evidence

**Claude Code** — Production. Hooks/agents/skills load on session start; verified across the dev loop in this repository.

**Gemini CLI 0.40.1** — Production:
- `gemini skills list` enumerates all 34 rolepod skills from `~/.gemini/extensions/rolepod/skills/`.
- SessionStart hook fires and emits the rolepod gates banner ("rolepod gates: S1-S5 simplicity + T1-T6 tests + Q1-Q4 delegation + F1-F6 failure-mode") on every Gemini session.
- The model recognizes the extension by name and version (`rolepod (v0.2.0)`) when asked.
- 6 slash commands (`/careful /ship /review /test /plan /spec`) ship as schema-conformant `.toml` files in `commands/` (Gemini exposes these interactively; there is no `gemini commands list` subcommand).
- Caveat: the bundled SessionStart hook expects ripgrep — falls back to GrepTool with a one-line warning. Cosmetic only.

**Codex CLI 0.130.0** — Production:
- Rolepod ships as a Codex marketplace consumable (`adapters/codex/.agents/plugins/marketplace.json` + `plugins/rolepod/`). The installer renders to `build/rendered/codex/` and runs `codex plugin marketplace add <rendered-dir>` so Codex's native plugin loader picks up agents, skills, and hooks via the same code path as bundled plugins (browser-use, computer-use, etc.).
- After install, `~/.codex/config.toml` contains `[marketplaces.rolepod] source_type = "local"` and `[plugins."rolepod@rolepod"] enabled = true`.
- Live verification: `codex exec --skip-git-repo-check "echo OK"` reports `hook: SessionStart Completed` from rolepod's `hooks/hooks.json`. Codex log (`~/.codex/log/codex-tui.log`) shows zero "configured non-curated plugin no longer exists" warnings for rolepod and zero manifest validation errors against `plugins/rolepod/.codex-plugin/plugin.json`.
- `~/.codex/AGENTS.md` managed block still loads on every Codex session (Tier 1 always-on rules), independent of plugin enable state.
- The CLI subcommands `plugin list` / `agent` / `skills list` / `hooks list` are not present in 0.130.0 — Codex doesn't expose enumeration commands today. The plugin still loads via the same code path as bundled plugins; verification is via session log + `config.toml` inspection.

Help close the gap — install on Codex / Gemini and report at [issues/](https://github.com/nuttaruj/rolepod/issues).

## Notes on subagent behavior

- **Claude Code**: agents auto-spawn via the `Task` / `SendMessage` tool — Lead delegates and merges results in parallel.
- **Codex CLI**: 18 `agents/*.toml` are registered with the plugin and load via the plugin loader. Codex doesn't currently expose a public `codex agent` subcommand or a parallel-fanout primitive equivalent to Claude's `Task`, so verification is via plugin config, session logs, and observed dispatch behavior — Lead orchestrates by inline reading of the relevant agent's `developer_instructions` block.
- **Gemini CLI**: agents are inlined in `GEMINI.md` as a roster table. Lead reads the relevant agent's section and acts in-character. Gemini Code Assist is adding richer multi-agent primitives — when those land, the Gemini adapter will switch to native dispatch.

The path-based ownership rules from `team-org.md` apply identically across all three CLIs — same agent picks the same paths regardless of which CLI is in charge of orchestration.

## Recommended Claude Code setup

Claude Code supports both global and project-level configuration. Rolepod's installer ships global by default (`~/.claude/`) but per-project installs land the full plugin in `$PWD/.claude/`.

### Per-project install (`--scope=project`)

Drop the full rolepod plugin (agents + skills + hooks + entry doc) into a single project without touching `~/.claude/`:

```bash
cd /your/project
./install.sh --target=claude --scope=project
```

Writes `$PWD/.claude/` with the full plugin tree plus `$PWD/CLAUDE.md` (managed block). Claude auto-loads project `.claude/settings.json` so the 3 hooks fire on this project only.

### Global core (one-time per machine)

```bash
./install.sh --target=claude
```

Installs:
- `~/.claude/CLAUDE.md` (managed block — your existing content preserved)
- `~/.claude/agents/*.md` (18 agents)
- `~/.claude/skills/<name>/SKILL.md` (34 skills)
- `~/.claude/commands/*.md` (slash commands)
- Hook entries appended idempotently to `~/.claude/settings.json` (SessionStart + 2x PostToolUse)
- `~/.claude/.claude-plugin/plugin.json` (manifest)

### Project-specific CLAUDE.md override (optional)

When a repo needs stricter rules than the global rolepod set, create `CLAUDE.md` at the repo root with project-specific overrides. Claude precedence: repo-root `CLAUDE.md` > `~/.claude/CLAUDE.md`. Rolepod's global rules still apply unless explicitly overridden. See [Claude Code docs](https://docs.claude.com/en/docs/claude-code/memory).

### Verify install

```bash
claude --help                           # CLI present
ls ~/.claude/agents/ | wc -l            # 18
ls ~/.claude/skills/ | wc -l            # 34
grep rolepod ~/.claude/settings.json    # hook entries present
claude -p "say OK"                      # SessionStart hook fires; banner appears in transcript
```

If hooks don't fire, check `~/.claude/settings.json` contains the three rolepod entries pointing at `~/.claude/hooks/*.sh`.

## Recommended Codex setup

Codex CLI supports both global and project-level configuration. Rolepod's installer ships global by default (`~/.codex/`) but project-level overrides are useful when a repo needs strict rules.

### Per-project install (`--scope=project`)

Drop rolepod's Tier 1 rules into a single project without touching `~/.codex/`:

```bash
cd /your/project
./install.sh --target=codex --scope=project
```

Writes only `$PWD/AGENTS.md` (managed block). Codex auto-loads `AGENTS.md` from the working directory on session start. Plugins/skills are global-only by Codex CLI design — for those, run `--scope=global` separately.

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
codex exec --skip-git-repo-check "echo OK"
# stdout shows: hook: SessionStart Completed (rolepod hooks firing through native plugin loader)
# Auto-loads the rolepod block from ~/.codex/AGENTS.md (Tier 1 always-on rules)
# Plugin tree (18 agents, 34 skills, 3 hooks) resolved from build/rendered/codex/plugins/rolepod/
# Verify config: grep -A2 'marketplaces.rolepod\|plugins."rolepod' ~/.codex/config.toml
```

If hooks don't fire, check `~/.codex/hooks.json` matches the schema documented at [developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks).

## Recommended Gemini setup

Gemini CLI uses an extension model. Rolepod ships as a global extension; project-level `GEMINI.md` overrides apply on top.

### Per-project install (`--scope=project`)

Drop rolepod's Tier 1 rules into a single project without touching `~/.gemini/`:

```bash
cd /your/project
./install.sh --target=gemini --scope=project
```

Writes only `$PWD/GEMINI.md` (managed block). Gemini auto-loads `GEMINI.md` from the working directory on session start. The full extension (commands/skills/hooks) is global-only by Gemini CLI design — for those, run `--scope=global` separately.

### Global core (one-time per machine)

```bash
./install.sh --target=gemini
```

Installs:
- `~/.gemini/GEMINI.md` (managed block — your existing content preserved)
- `~/.gemini/extensions/rolepod/` (full extension: 18 agents inlined, 34 skills, 6 commands, 3 hooks)

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
# /careful, /ship, /review, /test, /plan, /spec available as slash commands
# Hooks fire automatically (SessionStart / BeforeTool / AfterTool)
```

If the extension doesn't appear, check `~/.gemini/extensions/rolepod/gemini-extension.json` matches the schema at [Gemini extensions docs](https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions.md).
