# Rolepod — Per-CLI Support Matrix

Phase 2.3: rolepod ships for each supported CLI as a **native plugin / extension** — agents, skills, and hooks all wire into each CLI's own primitives. No wrapper scripts.

## Capability matrix

| Capability | Claude Code | Codex CLI | Gemini CLI |
|---|---|---|---|
| Always-on instructions | `~/.claude/CLAUDE.md` (native) | `~/.codex/AGENTS.md` (native) | `~/.gemini/GEMINI.md` (native) |
| Lazy-load rules (Read on trigger) | full | full | full |
| Skills (`<plugin>/skills/<name>/SKILL.md`) | 27 native | 27 native | 27 native |
| Subagents (parallel team) | full Task / SendMessage (18 agents) | 18 agents as Codex `agents/*.toml` (Lead-orchestrated) | 18 agents inlined in `GEMINI.md` (Lead-orchestrated) |
| Hooks (auto reminders) | 4 hooks (`SessionStart` + `PreToolUse` + 2x `PostToolUse`) | 4 hooks (`SessionStart` + `PreToolUse` + 2x `PostToolUse`) | 3 hooks (`SessionStart` + `BeforeTool` + `AfterTool`) |
| Slash commands | full (e.g. `/careful`, `/ship`, `/review`, `/test`, `/plan`, `/spec`) | n/a (commands not in current Codex schema) | full (6 commands as `commands/*.toml`) |
| Plugin manifest | `.claude-plugin/plugin.json` (spec-conformant, 598B) | `.codex-plugin/plugin.json` (mirrors caveman schema, 1.6KB) | `gemini-extension.json` (extension schema, 551B) |
| MemPalace / GitNexus integration | full hook coverage | full hook coverage (same 4 scripts as Claude) | full hook coverage (3 scripts) |
| MCP server config | global + per-plugin | global (`codex mcp`) | global (`gemini mcp`) |

## Install destinations

| CLI | Plugin / extension destination | Entry doc destination |
|---|---|---|
| Claude Code | `~/.claude/` (agents/, rules/, hooks/, skills/, commands/, .claude-plugin/) | `~/.claude/CLAUDE.md` |
| Codex CLI | `~/.codex/plugins/rolepod/` (.codex-plugin/, agents/, hooks/, skills/) | `~/.codex/AGENTS.md` |
| Gemini CLI | `~/.gemini/extensions/rolepod/` (gemini-extension.json, commands/, hooks/, skills/) | `~/.gemini/GEMINI.md` |

The entry doc is intentionally written **outside** the plugin/extension dir for Codex and Gemini — both CLIs auto-load the global `AGENTS.md` / `GEMINI.md` regardless of which plugins are installed, so keeping the entry doc at the root makes rolepod's gates active on every session, not just when the plugin is enabled.

## Adapter source layout

```
adapters/
├── claude/
│   ├── CLAUDE.md.tmpl
│   └── agent-frontmatter/*.yml         (18 frontmatter overlays)
├── codex/
│   ├── AGENTS.md.tmpl
│   ├── .codex-plugin/plugin.json
│   ├── agents/*.toml                   (18 agents, Codex schema)
│   ├── hooks/hooks.json + 4 *.sh
│   └── skills → ../../core/skills      (symlink, dereferenced at render time)
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
| Before tool run | `PreToolUse` (matcher `Edit\|Write\|Bash`) | `PreToolUse` (matcher `Bash\|apply_patch`) | `BeforeTool` (matcher `write_file\|replace\|edit`) |
| After tool run | `PostToolUse` (matcher `Edit\|Write` and `Bash`) | `PostToolUse` (matcher `apply_patch` and `Bash`) | `AfterTool` (matcher `write_file\|replace\|edit`) |

Hook scripts are interchangeable across Claude and Codex (same 4 files); Gemini ships its own 3 scripts adapted to Gemini's tool names and JSON envelope.

## Verification status — what's confirmed locally

| Item | Verified by |
|---|---|
| Claude snapshot | `diff -q` 0-byte vs prior `~/.claude/CLAUDE.md` and 18 agent files |
| Codex plugin layout | dry-run install populates `~/.codex/plugins/rolepod/{.codex-plugin,agents,hooks,skills}/` plus `~/.codex/AGENTS.md` |
| Gemini extension layout | dry-run install populates `~/.gemini/extensions/rolepod/{gemini-extension.json,commands,hooks,skills}/` plus `~/.gemini/GEMINI.md` |
| All shell scripts | `bash -n` clean (install.sh, bootstrap.sh, render.sh, 4 codex hooks, 3 gemini hooks, 4 root hooks) |
| All JSON manifests | `python3 -m json.tool` clean (plugin.json x2, hooks.json x2, gemini-extension.json) |
| All TOML files | `tomllib.load()` clean (18 codex agents, 6 gemini commands) |
| Render output | `build/render.sh --target=all` produces all 3 trees with no `{{INCLUDE: ...}}` leaks |

## Runtime verification status

| Target | Static checks | Dry-run install | Live runtime hooks | Live subagent dispatch | Status |
|--------|---------------|-----------------|--------------------|-----------------------|--------|
| Claude Code | ✓ | ✓ | ✓ verified | ✓ verified | **Production** |
| Codex CLI   | ✓ | ✓ | ⚠ spec-conformant, not user-verified | ⚠ spec-conformant, not user-verified | **Beta** |
| Gemini CLI  | ✓ | ✓ | ⚠ spec-conformant, not user-verified | ⚠ spec-conformant, not user-verified | **Beta** |

**Static checks** = `bash -n` on shell scripts, `python3 -m json.tool` on JSON manifests, `tomllib.load()` on TOML, plus snapshot diffs (no leaked `{{INCLUDE: ...}}` placeholders). **Dry-run install** = `install.sh --target=<cli>` writes correct files into a temp dir and the layout matches each CLI's expected destination. **Live** = installed in the real CLI, hooks fire on real sessions, subagents dispatch correctly. **Beta** means the adapter follows each CLI's published spec but real-world testing on those CLIs is still pending.

Help close the gap — install on Codex / Gemini and report at [issues/](https://github.com/nuttaruj/rolepod/issues).

## Notes on subagent behavior

- **Claude Code**: agents auto-spawn via the `Task` / `SendMessage` tool — Lead delegates and merges results in parallel.
- **Codex CLI**: 18 `agents/*.toml` are registered with the plugin so Codex can pull them by name. Codex doesn't currently have a parallel-fanout primitive equivalent to Claude's `Task`, so Lead orchestrates one agent at a time via `codex agent run` (or inline reading of the agent's `developer_instructions`).
- **Gemini CLI**: agents are inlined in `GEMINI.md` as a roster table. Lead reads the relevant agent's section and acts in-character. Gemini Code Assist is adding richer multi-agent primitives — when those land, the Gemini adapter will switch to native dispatch.

The path-based ownership rules from `team-org.md` apply identically across all three CLIs — same agent picks the same paths regardless of which CLI is in charge of orchestration.
