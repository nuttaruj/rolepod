# Rolepod — Per-CLI Support Matrix

Phase 2.3: rolepod ships for each supported CLI as a **native plugin / extension** — agents, skills, and hooks all wire into each CLI's own primitives. No wrapper scripts.

## Gemini CLI (removed in v2.177.0)

Google retired the standalone Gemini CLI for individual accounts (2026-06-18) and moved consumers to Antigravity (`agy`) — use `--target=antigravity`. Rolepod ships no Gemini adapter and no `--target=gemini`; that flag now prints the removal notice and points at `gemini extensions uninstall rolepod` to clean up a pre-v2.177.0 install.

## Capability matrix

| Capability | Claude Code | Codex CLI | Cursor IDE | Antigravity CLI (agy) | opencode |
|---|---|---|---|---|---|
| Always-on instructions | SessionStart hook → `hooks/always-on-core.md` (additionalContext) | `~/.codex/AGENTS.md` (native) | `rules/always-on-core.mdc` with `alwaysApply: true` (Cursor native) | `AGENTS.md` at the customization root (auto-loaded) | `~/.config/opencode/AGENTS.md` managed block (native rules chain) |
| Lazy-load rules (Read on trigger) | full | full | full (`.mdc` rules with explicit `alwaysApply: false` or glob match) | full | full |
| Skills (`<plugin>/skills/<name>/SKILL.md`) | 15 — Core 10 + 2 helpers + 1 command + 2 on-demand (native) | 15 — Core 10 + 2 helpers + 1 command + 2 on-demand (native) | 15 — Core 10 + 2 helpers + 1 command + 2 on-demand (native; frontmatter stripped to `name` + `description` per Cursor spec) | 15 — Core 10 + 2 helpers + 1 command + 2 on-demand (native) | 15 — Core 10 + 2 helpers + 1 command + 2 on-demand (native `SKILL.md`) |
| Subagents (parallel team) | full Task / SendMessage (15 agents) | 15 agents as Codex `agents/*.toml` (Lead-orchestrated) | 15 agents in `agents/*.md` (Lead-orchestrated) | 15 agents in `agents/*.md` (Lead-orchestrated) | 15 agents in `agents/*.md` (filename = agent id, `mode: subagent`; Lead-orchestrated) |
| Ticket loop (v2.144.0) | full — the Owner-line role builds on the Command (after each edit and last before returning), dispatches the reviewers its brief names (R4 only; nested Agent) — R2/R3 returns with none, the Lead's ONE combined review covers the plan diff instead — fixes, returns a decision brief; task owners run in parallel worktrees; the Lead integrates | doctrine — the role runs the loop; no nested dispatch → `REVIEW NEEDED:` in the brief and the Lead runs the review | doctrine — the role runs the loop; no nested dispatch → `REVIEW NEEDED:` in the brief and the Lead runs the review | doctrine — the role runs the loop; no nested dispatch → `REVIEW NEEDED:` in the brief and the Lead runs the review | doctrine — the role runs the loop; no nested dispatch → `REVIEW NEEDED:` in the brief and the Lead runs the review |
| Hooks (core only) | 14 core hook scripts (16 registrations) in the plugin's `hooks/hooks.json` · auto-registered on install | 7 core hook scripts (8 registrations) across `SessionStart`/`UserPromptSubmit`/`PreToolUse`/`PostToolUse`/`Stop` · fire natively on Codex ≥0.144, default-enabled | 3 core hooks across `sessionStart`/`beforeShellExecution`/`stop` · auto-fires | 3 core hook scripts across `PreInvocation`/`PreToolUse`/`Stop` under a `rolepod` name wrapper · deny-only (agy honours no context field on any hook) | JS plugin (`plugin/rolepod.js`): cross-CLI session locks, post-compact re-anchor, `tool.execute.before` precommit DENY, fix-loop-breaker (the shared `hooks/*.sh` core in `plugins/rolepod-shared/`, its nudge appended to the tool result via `tool.execute.after`); per-agent `permission:` blocks (commit ban, scout read-only); rest skill-enforced |
| Commit gate (v2.176.0) | full — private-docs deny + evidence gate (high-risk diff needs a finished strong reviewer; transcript scan + hook-auto `dispatch` rows + anchored externals) | private-docs deny only (`ROLEPOD_LEAD_CLI=codex`) + sub-agent commit ban | private-docs deny only (shared gate behind `scripts/precommit-gate.sh`) | private-docs deny only (shared gate behind `hooks/pre-tool.sh`) | private-docs deny only (the plugin's commit deny) |
| External implement (v2.139.0, live-verified 2026-09-17: all five members built the same 2-file ticket) | `-p --permission-mode acceptEdits --allowedTools Bash` (its rolepod hooks fire; 32 s) | `exec -s workspace-write` (plugin hooks fire once trusted; ~8 min) | `-p --force --trust` (runs shell; keep out of `[implement] cli` unless wanted; 36 s) | `-p --mode accept-edits --add-dir <repo>` (37 s) | `run` only when an `opencode.json(c)` (project, `OPENCODE_CONFIG_DIR` or `~/.config/opencode`) grants edit + bash; its start-up rewrite of the project file is restored as housekeeping (37 s) |
| Plugin manifest | `plugins/rolepod/.claude-plugin/plugin.json` (spec-conformant) + `.claude-plugin/marketplace.json` catalog at the repo root | `.codex-plugin/plugin.json` (Codex plugin schema, 1.6KB) | `plugins/rolepod-cursor/.cursor-plugin/plugin.json` (spec-conformant) + `.cursor-plugin/marketplace.json` catalog at the repo root | `plugin.json` at plugin root (agy plugin schema, validated by `agy plugin validate`) | `opencode.json` (version metadata — opencode has no plugin manifest for this install style) |
| Optional add-on integration | vendor-installed (own plugin / MCP); rolepod auto-detects, falls back to `rg` + `find` | vendor-installed (own plugin / MCP); rolepod auto-detects, falls back to `rg` + `find` | vendor-installed (Cursor MCP / `mcp.json`); rolepod auto-detects, falls back to `rg` + `find` | vendor-installed; rolepod auto-detects, falls back to `rg` + `find` | vendor-installed; rolepod auto-detects, falls back to `rg` + `find` |
| MCP server config | global + per-plugin | global (`codex mcp`) | global (`~/.cursor/mcp.json`) + per-plugin (`plugin/mcp.json`) | global (agy config tree; not yet live-verified) | global (opencode config) |

## Install destinations

| CLI | Plugin / extension destination | Always-on core destination |
|---|---|---|
| Claude Code | repo IS the marketplace — `.claude-plugin/marketplace.json` + committed `plugins/rolepod/` (agents/, hooks/, skills/, .claude-plugin/) at the repo root; `claude plugin marketplace add nuttaruj/rolepod` installs straight from GitHub | SessionStart hook emits `hooks/always-on-core.md` (no CLAUDE.md) |
| Codex CLI | repo IS the marketplace — `.agents/plugins/marketplace.json` + committed `plugins/rolepod-codex/` (.codex-plugin/, hooks/, skills/) at the repo root; `codex plugin marketplace add nuttaruj/rolepod` installs straight from GitHub. The 15 agent TOMLs install to `~/.codex/agents/rolepod-*.toml` — Codex's plugin loader has no agents field, so they need `install.sh` | `~/.codex/AGENTS.md` |
| Cursor IDE | repo IS the marketplace — `.cursor-plugin/marketplace.json` + committed `plugins/rolepod-cursor/` (.cursor-plugin/, rules/, agents/, skills/, hooks/, scripts/) at the repo root; `install.sh --target=cursor` copies that tree to `~/.cursor/plugins/local/rolepod/` for local install | `plugins/rolepod-cursor/rules/always-on-core.mdc` (`alwaysApply: true`) |
| Antigravity CLI (agy) | rendered to `build/rendered/antigravity/plugin/` (gitignored); `install.sh --target=antigravity` installs it via `agy plugin install` — plugin.json + hooks.json at plugin root, skills/, agents/ | `AGENTS.md` at the agy customization root (`install.sh` places it) |
| opencode | rendered to `build/rendered/opencode/` (gitignored); `install.sh --target=opencode` syncs skills/ (name-scoped), agents/ (15), `plugin/rolepod.js`, and `rolepod-version.json` into `~/.config/opencode/` (project scope: `$PWD/.opencode/`; override: `ROLEPOD_OPENCODE_TARGET`) | `~/.config/opencode/AGENTS.md` managed block (`<!-- rolepod:start/end -->`); project scope writes `$PWD/AGENTS.md` |

For Codex the entry doc is intentionally written **outside** the plugin dir (`~/.codex/AGENTS.md`) — Codex auto-loads the global `AGENTS.md` regardless of which plugins are installed, so keeping it at the root makes rolepod's gates active on every session, not just when the plugin is enabled.

For Cursor the always-on core ships as `rules/always-on-core.mdc` with `alwaysApply: true`. Cursor auto-loads any `.mdc` rule carrying that frontmatter on every session, so the install is fully self-contained — nothing is written to user-global config and uninstall is a clean `rm -rf ~/.cursor/plugins/local/rolepod/`. Caveat: a user who disables **Settings → Features → Rules** in Cursor suppresses the always-on core (the parallel of a Claude user disabling SessionStart hooks).

### Install path env vars

| Variable | Effect |
|---|---|
| `ROLEPOD_TARGET` | Single-target default OR root for `--target=all`. Single target overrides destination entirely; with `--target=all`, each CLI lands under `$ROLEPOD_TARGET/<cli>/` (e.g. `$ROLEPOD_TARGET/claude`, `/codex`). |
| `ROLEPOD_CLAUDE_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Claude only. |
| `ROLEPOD_CODEX_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Codex only. |
| `ROLEPOD_CURSOR_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Cursor only. |
| `ROLEPOD_ANTIGRAVITY_TARGET` | Per-CLI override — wins over `ROLEPOD_TARGET` for Antigravity only. A non-`~/.gemini` target also skips the real `agy plugin install` (temp-target guard). |

Non-TTY contexts: `--uninstall` without `--yes` exits 0 with `Aborted. Re-run with --yes in non-interactive mode.` instead of crashing on a missing `/dev/tty`.

## Adapter source layout

```
adapters/
├── claude/
│   ├── .claude-plugin/                 (plugin.json + marketplace.json)
│   ├── agent-frontmatter/*.yml         (15 frontmatter overlays)
│   └── hooks.json                      (plugin hooks manifest)
├── codex/
│   ├── AGENTS.md.tmpl
│   ├── agent-frontmatter/*.yml          (15 overlays — model / effort / sandbox)
│   ├── .agents/plugins/marketplace.json (Codex marketplace manifest)
│   └── plugins/rolepod/
│       ├── .codex-plugin/plugin.json
│       ├── hooks/hooks.json + 7 core *.sh (+ 1 helper, test-diff-lint.sh)
│       └── skills → ../../../../core/skills (symlink, dereferenced at render time)
├── cursor/
│   ├── .cursor-plugin/                  (plugin.json + marketplace.json)
│   ├── rules/always-on-core.mdc.tmpl    (alwaysApply: true wrapper around hooks/always-on-core.md.tmpl)
│   ├── hooks/hooks.json                 (sessionStart / beforeShellExecution / stop)
│   └── scripts/*.sh                     (3 hook scripts — Cursor JSON I/O)
└── antigravity/
    ├── AGENTS.md.tmpl
    ├── agent-frontmatter/*.yml          (15 overlays — tier:, resolved to a model: id at render time)
    ├── plugin.json                      (agy plugin manifest)
    └── hooks/hooks.json                 (`{"rolepod": {PreInvocation / PreToolUse(run_command) / Stop}}` — 3 agy-native scripts + the shared precommit-gate)
```

`build/render.sh` renders all five trees: Claude, Codex, and Cursor into committed `plugins/rolepod/`, `plugins/rolepod-codex/`, `plugins/rolepod-cursor/` paths, and Antigravity + opencode into gitignored `build/rendered/{antigravity,opencode}/`. Per-CLI agent files are generated by `build/merge-agent.py` from `core/agents/<name>.md` + the `agent-frontmatter/` overlay (Codex agents emit as TOML; Claude and Antigravity emit Markdown with full frontmatter, Antigravity's `model:` resolved from its own `gemini-3-*` ids; Cursor emits Markdown with `name` + `description` only — no overlay needed; opencode emits Markdown with `description` + `mode: subagent` + a `permission:` block derived from the Claude overlay's tools, deliberately no model pin — opencode is multi-provider and the tier stays doctrine). `install.sh` copies the rendered tree to the install destination above.

## Hook event mapping

| Event class | Claude Code | Codex CLI | Cursor IDE | Antigravity CLI |
|---|---|---|---|---|
| Session start | `SessionStart` (`startup\|resume\|clear\|compact`) | `SessionStart` (`startup\|resume`) | `sessionStart` (no matcher) | `PreInvocation` (no matcher) |
| Prompt submit (claim-verify nudge) | `UserPromptSubmit` (no matcher) | `UserPromptSubmit` (no matcher) | — (`beforeSubmitPrompt` fires on submit but cannot inject pre-answer context) | — (agy has no prompt-submit event) |
| Before tool run | `PreToolUse` (`Edit\|Write\|MultiEdit`, `NotebookEdit`, `Bash`, `Workflow`) | `PreToolUse` (`Bash`) | `beforeShellExecution` (any `git` command) | `PreToolUse` (`run_command`) |
| After tool run | `PostToolUse` (`Workflow\|Agent`, `Bash`) | `PostToolUse` (`Bash`) | — (uses `beforeShellExecution` for commit gate; no observational hooks yet) | — (agy has no post-tool event) |
| Stop / compact | `Stop` (no matcher) | `Stop` (no matcher; `session-lifecycle.sh --unlock`) | `stop` (no matcher; `stop-unlock.sh`) | `Stop` (no matcher) |

Per-CLI hook counts (distinct scripts, v2.176.0). The evidence gate and the edit-time hooks run on Claude only; every CLI keeps the private-docs commit deny. Per-hook detail: [docs/hooks.md](hooks.md).

- **Claude** — 14 core hook scripts, 16 registrations (`session-lifecycle.sh` twice, `--lock` / `--unlock`; `subagent-write-scope.sh` twice, Edit/Write and NotebookEdit).
- **Codex** — 7 scripts, 8 registrations: `claim-verify-nudge`, `project-context-loader`, `session-lifecycle` (`--lock` / `--unlock`), `agent-sync` (Codex-only SessionStart sync of the bundled agents + AGENTS.md block into `~/.codex`), `block-subagent-commit`, `precommit-gate` (`ROLEPOD_LEAD_CLI=codex` → private-docs deny only), `fix-loop-breaker`. Plugin hooks must be trusted once via `/hooks`.
- **Cursor** — 3: `project-context-loader` on `sessionStart` (+ the `cursor-<conversation_id>` lock), `precommit-gate` on `beforeShellExecution` (a translator around the shared gate → private-docs deny only), `stop-unlock` on `stop` (releases the lock, records the route line). Always-on judgment is an `alwaysApply` rule.
- **Antigravity** — 3 in `hooks.json` under a `rolepod` name key: `session-start` on PreInvocation, `pre-tool` on PreToolUse(`run_command`) → the shared gate (private-docs deny only, returned as `{decision, reason}`), `stop-unlock` on Stop. agy accepts no context field on any event, so nothing but a deny reaches the model.
- `claim-verify-nudge` ships on Claude / Codex, not Cursor (`beforeSubmitPrompt` cannot inject context). Rolepod ships no add-on hooks — rolepod-brain and GitNexus integrate via their own plugins / CLI.

## Verification status — what's confirmed locally

| Item | Verified by |
|---|---|
| Claude snapshot | 15 agent files + plugin tree layout |
| Codex plugin layout | install registers `[marketplaces.rolepod]` + `[plugins."rolepod@rolepod"] enabled = true` in `~/.codex/config.toml` and writes the `~/.codex/AGENTS.md` managed block; committed marketplace tree at the repo root (`.agents/plugins/marketplace.json` + `plugins/rolepod-codex/{.codex-plugin,agents,hooks,skills}/`) — the plugin bundles hooks + skills + the 15 agent TOMLs + the AGENTS.md block (`agents/AGENTS.rolepod.md`); the Codex manifest has no `agents` component, so the SessionStart `agent-sync.sh` hook copies them into `~/.codex/agents/` and refreshes only the rolepod block of `~/.codex/AGENTS.md` whenever the plugin version changes (v2.75.0) — `codex plugin marketplace upgrade rolepod` alone is a complete update (one-time: trust the new hook via `/hooks` — Codex skips untrusted plugin hooks by policy) |
| All shell scripts | `bash -n` clean (install.sh, bootstrap.sh, render.sh, 14 core hook scripts, the codex adapter's agent-sync.sh, 3 cursor scripts) |
| All JSON manifests | `python3 -m json.tool` clean (plugin.json x4 — claude/codex/cursor/antigravity, hooks.json x4 — claude/codex/cursor/antigravity, marketplace.json x2 — claude/cursor) |
| All TOML files | `tomllib.load()` clean (15 codex agents) |
| Render output | `build/render.sh --target=all` produces all 5 trees with no `{{INCLUDE: ...}}` leaks |

## Runtime verification status

| Target | Static checks | Dry-run install | Live runtime hooks | Live subagent dispatch | Status |
|--------|---------------|-----------------|--------------------|-----------------------|--------|
| Claude Code | ✓ | ✓ | ✓ verified | ✓ verified | **Production** |
| Codex CLI   | ✓ | ✓ | ✓ native — hooks fire without any opt-in on current Codex; `codex features list` (0.144.1, 2026-07-30) shows `hooks stable true` and the legacy `plugin_hooks` flag `removed` | ✓ verified (15 agents + 14 skills via native loader) | **Production** |
| Cursor IDE  | ✓ | ✓ | ✓ live-verified 2026-09-16 (agent CLI 2026.09.10 / IDE 3.20.21): `alwaysApply` rule loads, `sessionStart` writes the marker, `preToolUse`/`postToolUse` matchers are a regex on `tool_name` (`Write`), `beforeShellExecution` matcher a regex on the literal command; hook cwd = plugin root; `agent_message` reaches the model only on deny, so soft reminders ride `postToolUse` `additional_context` | ⚠️ 15 agents + 11 skills load (minimal-frontmatter shape); subagent dispatch unverified | **Production for hooks + rule** (subagent dispatch still unverified) |
| Antigravity CLI (agy) | ✓ (`agy plugin validate` [ok]; integration test locks the measured schema) | ✓ (live `agy plugin install`/`uninstall` round-trip verified; temp-target guard proven) | ✓ live-verified 2026-09-16 (agy 1.2.3): named-wrapper `hooks.json` loads (the old flat one never parsed), PreInvocation/PreToolUse/Stop fire, `{decision: deny, reason}` blocks the tool with the reason visible to the model; no context field exists on any event, `{}` = deny, hook cwd = plugin dir, stdin camelCase (`toolCall`, `workspacePaths`) | ⚠️ 15 agents + 11 skills install; subagent dispatch unverified | **Production for the private-docs commit deny** (deny-only; reminders impossible on agy; the evidence gate is Claude-only) |
| opencode | ✓ (14 skills / 15 agents / plugin JS `node --check` clean) | ✓ (temp-target install/uninstall round-trip verified) | partial, live-verified 2026-09-22 (opencode 2.0.12; the same file keeps the v1 named export for 1.x): the JS plugin registers through `setup(ctx)` inside opencode's shared service — `ctx.tool.hook("execute.before")` denies `git commit` on the `shell` tool (throw = deny) and every agent carries a `permission:` block; `ctx.tool.hook("execute.after")` hands the shared fix-loop-breaker core the result text (`result.content`; shell exit at `result.metadata.exit`) and its nudge lands as a text part of the tool result; `ctx.session.hook("prompt")` registers the session lock; `ctx.session.hook("context")` carries the sibling warning and the post-compact re-anchor to the model (a server plugin has no toast) and records the previous turn's route line; `ctx.event.subscribe` is one stream for every project, filtered by `location.directory`; no per-file deny event, so worktree/cohesion gates stay skill-enforced; claim-verify needs the transcript-backed lib and is not ported. Sibling MCP servers (uiproof / wplab / dblab) under opencode 2: the MCP entry's `codemode` flag (schema `@opencode/schema` mcp.d.ts, optional boolean) defaults to on and then hides the server's tools behind `execute` / `query` (measured by the uiproof session on 2.0.12) — a rolepod skill that names a sibling tool needs `"codemode": false` on that server entry, which exposes them as `rolepod-<name>_<tool>` | ⚠️ live subagent dispatch unverified | **Beta** (native skills/agents verified via install; private-docs deny + agent `permission:` blocks) |

**Static checks** = `bash -n` on shell scripts, `python3 -m json.tool` on JSON manifests, `tomllib.load()` on TOML, plus snapshot diffs (no leaked `{{INCLUDE: ...}}` placeholders). **Dry-run install** = `install.sh --target=<cli>` writes correct files into a temp dir and the layout matches each CLI's expected destination. **Live** = installed in the real CLI, hooks fire on real sessions (Claude + Codex + Cursor + Antigravity + opencode), subagents/skills dispatch correctly.

_Last live-verified: 2026-05-23 on macOS (Darwin 25.5.0), Codex 0.132.0, Gemini 0.42.0, running rolepod 2.6.0 / Gemini extension 0.6.0 (counts at that time: 18 agents, 11 skills, Claude 7 / Codex 3 / Gemini 4 / Cursor 3 hooks). **2.6.2:** content trio merged into single `content-strategist` agent — roster 18 → 16 (→ 15 in v2.115.0: `product-manager` retired, the user is the product owner). **2.9.x (current tree):** hook scripts are Claude 9 (10 registrations — worktree-guard, always-on-loader, session-lifecycle ×2, claim-verify-nudge included) / Codex 4 / Gemini 5 / Cursor 3 / Antigravity 4; agents 15; skills 11. Antigravity adapter added 2026-06-30, install-path verified live on agy 1.0.13; Cursor + Antigravity live runtime confirmation are the open items. **2.10.x (2026-07-30):** opencode adapter added as sixth target (2.10.0, opencode 1.17.7 — native skills/agents, JS plugin, no hook layer); Codex 0.144.1 re-verified — hooks now fire natively, the `plugin_hooks` opt-in flag is `removed` upstream, enable instructions dropped. **2.37.0 (2026-08-13):** Claude hook scripts 9 → 11 — Workflow/Agent tier nudge (PreToolUse) + dispatch auto-log (PostToolUse). **2.130.2 (2026-09-16):** Cursor live-verified on agent CLI 2026.09.10 / IDE 3.20.21 — rule + 3 hook scripts fire (4 registrations); Cursor also auto-imports the Claude Code plugin, whose hook manifest self-disables there since 2.130.1. **2.131.0 (2026-09-16):** Antigravity adapter rewritten against the measured agy 1.2.3 contract — the flat `hooks.json` had never parsed (every `cli-*.log` since 2026-09-04), so agy 6 → 4 scripts: session-start / model-log / pre-tool (shared precommit-gate via translation) / stop-unlock; `cross-family` now passes `--add-dir` so the agy reviewer can read the repo. **2.160.0 (2026-09-23):** `deepen-codebase` — a second explicit-invoke command (ported from mattpocock/skills `improve-codebase-architecture`, MIT): scope → one scout walks the codebase → HTML report of deepening candidates in the OS temp dir → the user picks a card and is offered a `write-spec` on it; 12 skills on every CLI. **2.161.0 (2026-09-23):** `write-prototype` — an on-demand skill (ported from mattpocock/skills `prototype`, MIT) that write-spec offers for a layout / state-logic question, or the user types /write-prototype: layout variants or a clickable logic demo in a spike worktree, never merged; 13 skills on every CLI. **2.157.0 (2026-09-22):** opencode 2.0.12 loads no v1 plugin (`Plugin must export a default definition with an id and an effect or setup function`) — the adapter now ships `export default { id, setup(ctx) }` next to the v1 named export; plugins run inside opencode's shared background service (`opencode service restart` after install or update; env flags reach the plugin only through the service's env). **2.177.0 (2026-09-25):** Gemini CLI support removed — Google retired the standalone CLI for individual accounts (2026-06-18) and moved consumers to Antigravity (`agy`); no adapter, no `--target=gemini` (it now prints a removal notice naming `gemini extensions uninstall rolepod`), no runner member — five CLIs remain: Claude, Codex, Cursor, Antigravity, opencode._

### Per-target runtime evidence

**Claude Code** — Production. Hooks/agents/skills load on session start; verified across the dev loop in this repository.

**Codex CLI 0.132.0** — Production:
- The rolepod repo IS a Codex marketplace — `.agents/plugins/marketplace.json` + the committed `plugins/rolepod-codex/` tree at the repo root. `codex plugin marketplace add nuttaruj/rolepod` installs straight from GitHub; `install.sh` runs the same `codex plugin marketplace add <repo>` against the local clone. Codex's native plugin loader picks up skills + hooks via the same code path as bundled plugins (browser-use, computer-use, etc.).
- After install, `~/.codex/config.toml` contains `[marketplaces.rolepod] source_type = "local"` and `[plugins."rolepod@rolepod"] enabled = true`.
- Plugin hooks (`hooks/hooks.json`) fire natively on current Codex — no opt-in step. `codex features list` on 0.144.1 (2026-07-30) shows `hooks stable true`; the legacy `plugin_hooks` flag is `removed`. (Historical: Codex ≤0.13x required `codex features enable plugin_hooks`; that instruction no longer applies.)
- Live verification: `codex exec --skip-git-repo-check "echo OK"` reports `hook: SessionStart Completed` from rolepod's `hooks/hooks.json`. Codex log (`~/.codex/log/codex-tui.log`) shows zero "configured non-curated plugin no longer exists" warnings for rolepod and zero manifest validation errors against `plugins/rolepod/.codex-plugin/plugin.json`.
- `~/.codex/AGENTS.md` managed block still loads on every Codex session (Tier 1 always-on rules), independent of plugin enable state.
- **Fan-out tier (verified 2026-09-03, codex 0.147.0, official subagent docs):** `model_reasoning_effort` accepts `low` / `medium` / `high` / `xhigh` / `max` / `ultra`; `ultra` = deepest reasoning **and** proactive delegation (the agent spawns its own children; how many is the model's call per task — rolepod never prescribes a count). Un-pinned children resolve explicit spawn → `agents.default_subagent_model` / `agents.default_subagent_reasoning_effort` → the parent; a rolepod role file pins effort and sandbox only, never a model (owner, 2026-09-25 — vendor ids rot every generation), so the `[agents]` default decides the model of every rolepod role too. rolepod pins security-engineer at `xhigh` — the effort ceiling on every role and every CLI (v2.75.0; it was `ultra` ≤ v2.73 — a strong × N fan-out per dispatch — and `max` in v2.74) and recommends setting `[agents] default_subagent_model` to the user's balanced model so Ultra's fan-out lands balanced. Per-spawn override still exists in 0.147.0 (`spawn_agent` validates `model` / `reasoning_effort`; the tool prompt says to set them only on user request, applicable AGENTS.md instructions, or a skill — rolepod's Codex AGENTS.md is that instruction), but full-history forks accept none and the V2 override picker is gated by `expose_spawn_agent_model_overrides`; a community thread (0.144.5+) reports the params ignored under MultiAgent V2 — role-file effort pins + the `[agents]` defaults are the reliable levers, the per-spawn `model` the tiered-by-task one.
- The CLI subcommands `plugin list` / `agent` / `skills list` / `hooks list` are not present in 0.132.0 — Codex doesn't expose enumeration commands today. The plugin still loads via the same code path as bundled plugins; verification is via session log + `config.toml` inspection.

**Cursor IDE** — hooks + rule live-verified 2026-09-16 (subagent dispatch still unverified):
- Plugin layout follows the official [cursor.com/docs/plugins](https://cursor.com/docs/plugins) spec and the [cursor/plugin-template](https://github.com/cursor/plugin-template) starter (verified against both 2026-05-23): `.cursor-plugin/plugin.json`, `rules/*.mdc`, `skills/<name>/SKILL.md`, `agents/*.md`, `hooks/hooks.json`, `scripts/*.sh`.
- Always-on judgment core ships as `rules/always-on-core.mdc` with `alwaysApply: true` — Cursor's native equivalent of Claude's SessionStart-emit pattern. No user-global config is touched on install or uninstall.
- 3 core hooks: `sessionStart` (project context loader + `cursor-<conversation_id>` session lock), `beforeShellExecution` on any `git` command (precommit-gate — a translator around the shared `scripts/shared/precommit-gate.sh`; on Cursor it denies only a staged `docs/rolepod/` path, the evidence gate being Claude-only since v2.176.0), `stop` (stop-unlock).
- Not portable on Cursor: fix-loop-breaker (no exit code on `afterShellExecution`), push-ref-check (no informational channel before a shell command), claim-verify-nudge (`beforeSubmitPrompt` cannot inject context). Hook JSON I/O follows [cursor.com/docs/hooks](https://cursor.com/docs/hooks): stdin JSON with `hook_event_name`/`tool_name`/`tool_input`/`command`/`workspace_roots` (no `cwd`), stdout JSON with `permission`/`user_message`/`agent_message`/`additional_context`. Exit code 2 = deny. Hook commands run with cwd = plugin root (`./scripts/x.sh` resolves).
- Skill frontmatter is intentionally stripped to `name` + `description` only (the two fields Cursor documents). Claude-specific keys (`tier`, `phase`, `when_to_use`, `disable-model-invocation`) are dropped at render time to avoid gambling on tolerance for unknown fields. Caveat: the `deepen-codebase` command loses its `disable-model-invocation: true` guard — its description is phrased to keep auto-trigger rare.
- Cursor also auto-imports the Claude Code plugin install from `~/.claude/plugins` and runs its Claude-format hooks; since v2.130.1 those commands self-disable under Cursor (`CURSOR_PROJECT_DIR` guard, see docs/hooks.md) so only the Cursor-native rule + 3 hooks run. A Cursor-marketplace install with the same name takes precedence over `~/.cursor/plugins/local/` — keep one source, never both.
- Agent frontmatter likewise reduces to `name` + `description` only — no Cursor-specific overlay file exists. The same 15 agent bodies ship across all CLIs.
- Local install path: `~/.cursor/plugins/local/rolepod/` (per Cursor's local-plugin convention). The repo's committed `.cursor-plugin/marketplace.json` also makes the GitHub URL importable as a team marketplace.
- Live re-verification pending: hook JSON I/O fields match the doc but have not yet been exercised on a real Cursor session.

Help close the gap — install on Codex / Cursor and report at [issues/](https://github.com/nuttaruj/rolepod/issues).

## Notes on subagent behavior

- **Claude Code**: agents auto-spawn via the `Task` / `SendMessage` tool — Lead delegates and merges results in parallel.
- **Codex CLI**: 15 `agents/*.toml` are registered with the plugin and load via the plugin loader. Codex doesn't currently expose a public `codex agent` subcommand or a parallel-fanout primitive equivalent to Claude's `Task`, so verification is via plugin config, session logs, and observed dispatch behavior — Lead orchestrates by inline reading of the relevant agent's `developer_instructions` block.
- **Antigravity**: 15 agent definitions ship as plugin `agents/*.md`; a build without sub-agent support has no roster fallback — the Lead reads the named agent file.

The path-based ownership rules from `write-plan` apply identically across all CLIs — same agent picks the same paths regardless of which CLI is in charge of orchestration.

## Cross-family externals — one runner, any Lead

Any installed CLI can be the Lead; the adversarial review, the stuck-state
consult and the spec critique go to a **different CLI** (its own default model; the vendor may coincide) through
`scripts/cross-family.sh` in the `cross-family` skill. The skill ships it
in its own folder on every CLI, so a marketplace install needs nothing
extra:

```bash
scripts/cross-family.sh --pool                       # resolved pool with reasons (or OFF + candidates), no network
scripts/cross-family.sh --kind implement --brief <task-brief> --allow <path>... [--allow-risky] --detach   # ONE member BUILDS one ticket in its write mode (v2.139.0). --allow is mandatory: `dir/` (or an existing dir) = everything below, a bare name = that one file; the allowed paths must start clean; money / auth / data paths (the commit gate's regex + .rolepod/risk-paths) are refused unless the USER passes --allow-risky. Exit 0 = kept; 21 = kept, edits outside --allow reverted (copies under <report>.reverted/); 22 = the member moved git state — refs, .git metadata, index and tree restored, nothing kept. The Lead reviews (§6) and commits.
scripts/cross-family.sh --pool --kind implement      # which members may write here (`[implement] cli = …` in the pool file; absent → the `review` order)
scripts/cross-family.sh --candidates                 # every installed CLI, the Lead's own included — the opt-in question
scripts/cross-family.sh --probe                      # one-line "reply OK" per member (spends a call each)
scripts/cross-family.sh --kind review  --brief brief.md --attach diff.patch --detach   # job; --collect <id> waits
scripts/cross-family.sh --collect <job-id> --root <git-root>   # prints the review + receipt when the job lands (exit 6 = still running); PARTIAL / no-VERDICT reviews never anchor
scripts/cross-family.sh --jobs                        # running / done
scripts/cross-family.sh --kind consult --brief ledger.md
scripts/cross-family.sh --kind critique --brief spec-draft.md          # write-spec: ranked open questions before Gate 1 (no cap)
# add --lead codex|agy|cursor|opencode when not running under Claude Code (ROLEPOD_LEAD_CLI also works)
```

| CLI | In the pool as | Invocation the runner uses (read-only for review / consult / critique — the write-mode form for `--kind implement` is in the capability matrix above; always **its own default model**, `ROLEPOD_BRAIN_SILENT=1`) | Family |
|---|---|---|---|
| Codex | `codex` | `codex exec -s read-only --skip-git-repo-check --ephemeral -o <msg> -` (prompt on stdin) | openai |
| Claude Code | `claude` | `claude -p --permission-mode plan --no-session-persistence` (prompt on stdin) | anthropic |
| Antigravity | `agy` | `agy -p "<prompt>" --mode plan --print-timeout <n>s` | google |
| Cursor | `cursor` | `cursor-agent -p --mode ask --output-format text --trust "<prompt>"` (ask, not plan — plan mode returns an empty stdout for a real brief, v2.128.3) | family of the default model in `~/.cursor/cli-config.json` (`model` string or `model.modelId`; `auto` = family not reported (CLI preset) — used as-is); `--probe` asks `cursor-agent models` for the live `(current, default)` |
| OpenCode | `opencode` | `opencode run --agent plan "<prompt>"` | family of `model` in `opencode.json(c)`, else of the CLI's last-used model (`~/.local/state/opencode/model.json`), else unknown; aggregator ids (`openrouter/…`, `ollama-cloud/…`) classify by model name |

Gemini CLI is retired for individual accounts (2026-06-18) and never a pool member — a `gemini` pool-file line is skipped; list `agy` instead.

**Opt-in, off by default.** Pool = `.rolepod/cross-family` (project) →
`~/.rolepod/cross-family` (machine): `[reviewer]` with `review = …` (the default order) and optional `consult = / critique = …`, `tier = R2|R3` (from that tier up, the external replaces `universal-reviewer` on a code diff — a `write-plan` brief names it as the alternative; default `R4` = today's behaviour, no external below R4), `[implement]` with `cli = …`; **no file = off,
`none` = off** (exit 5, nothing logged). Nothing asks unprompted: when the
user asks to set it up, `scripts/cross-family.sh --setup` prints the installed
candidates and the two questions (review order; implement `same` / `none` /
an order) and `--setup review="…" implement=…` writes the file. List
every CLI you use, the Lead's own included — it is skipped at run time, so
one file serves every Lead. **Installed ≠ usable** is proven at invoke: exit ≠ 0, timeout
(a member is killed when it goes SILENT — no new output for `stall` seconds: `--stall` > `stall=` in the config > 600 — not when it is slow; the wall-clock cap is runaway insurance only: `--timeout` > `timeout=` > kind default, review 7200 s detached / 600 s foreground, consult 300, critique 600 (v2.129.0; measured: codex reviews run 15-29 min and stream the whole way); the prompt carries a ≤30-min planning budget; `--detach` runs the chain as a job so the 600 s harness cap never kills a slow member),
or an answer under the floor (review < 500 bytes, consult / critique / implement < 200; implement budget 3600 s detached / 600 s foreground)
→ `external-fail` phase-log line, next member; every member failed → exit
3; empty pool → exit 4 — then the Lead's own path (internal strong
reviewer / vertical consult) runs and the review report records the
limitation. Evidence: `.rolepod/evidence/external/<utc>-<cli>.txt` + one
phase-log line (`phase: review|consult|critique`, `reviewer: external`) — an implement run writes `phase: implement` instead,
`model: default`, plus `ran: <id>` when the CLI names the model it ran —
Codex's `model:` banner, OpenCode's `> agent · model` header; the family
follows what ran and is recorded for information — a member is never failed
for its model family, cross-family means a different CLI). `rolepod-stats` shows external passes vs internal strong
dispatches. Live-verified 2026-09-04 on this machine: agy 10 s, cursor
28 s, opencode 8 s answered the probe; the now-removed Gemini CLI's probe
had already failed with `IneligibleTierError` (measured 2026-09-04, after
its 2026-06-18 retirement) — the historical case for dropping it as a
runner; codex answered the probe but timed out a
real review at 600 s under its owner's `model_reasoning_effort = "max"`
default, and the runner fell through to agy, which returned a REJECTED
verdict with traced findings in 24 s (that review shaped v2.76.0). With
v2.79.0's budget line and a detached 1500 s job, the same codex default
finished a real review of the runner diff in 1082 s with nine traced
findings — eight of them fixed in v2.79.1.

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

**Rules-only project install.** Writes only `$PWD/AGENTS.md` (managed block). Codex auto-loads `AGENTS.md` from the working directory on session start. **Native plugin agents/skills/hooks are NOT installed per-project** — Codex CLI's marketplace + plugin cache are global-only by design. For full Codex activation (15 agents, 14 skills, hooks), run `--scope=global` separately.

Codex hooks fire natively on Codex ≥0.144 — the legacy `plugin_hooks` opt-in flag is `removed` upstream; no config step needed.

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

When `--force` is used on an existing CLI home (`~/.claude/`, `~/.codex/`), the installer creates `~/.rolepod/backups/<cli>/rolepod-<timestamp>/` containing **only rolepod-managed paths** (off the CLI scan paths, so a backup never surfaces as a duplicate plugin entry):

| CLI | Backed up | Excluded |
|-----|-----------|----------|
| Claude  | `CLAUDE.md`, `CHEATSHEET.md`, `README.md`, `rules/`, `settings.json`, `agents/`, `hooks/`, `skills/`, `commands/`, `.claude-plugin/`, `plugins/rolepod/` | `projects/` (session history), `plugins/cache/`, `plugins/marketplaces/`, `file-history/`, `shell-snapshots/`, `session-env/`, `scheduled-tasks/`, `cache/`, `agent-memory/`, `backups/`, `teams/` |
| Codex   | `AGENTS.md`, `config.toml`, `plugins/rolepod/`, `.agents/`                                                                          | `log/`, `.tmp/`, `history/`, `sessions/` |

Rationale: a user's session transcripts (`~/.claude/projects/`) can exceed 1.8GB on active accounts. Duplicating them on every `--force` run wasted disk and time. Typical rolepod-scoped backup is <50MB. Restore is straightforward: `cp -R ~/.rolepod/backups/claude/rolepod-<stamp>/* ~/.claude/`.

**Retention: the 2 newest, per prefix.** Every install prunes older copies — backup dirs (`~/.rolepod/backups/<cli>/rolepod-*`), stamped config copies (`config.toml.rolepod-bak.*`), and the `.legacy-*` entry-doc copies written during a pre-markers migration. One knob: `BACKUP_KEEP` at the top of `install.sh`. Nothing else on disk is stamped or copied — the agy and opencode paths only replace rolepod's own plugin tree, and entry docs are edited inside the `<!-- rolepod:start -->` managed block, so user content is never overwritten and needs no backup.

### Project-specific AGENTS.md override (optional)

When a repo needs stricter rules than the global rolepod set, create `AGENTS.md` at the repo root with project-specific overrides. Codex precedence: repo-root `AGENTS.md` > `~/.codex/AGENTS.md`. Rolepod's global rules still apply unless explicitly overridden. See [Codex config docs](https://github.com/openai/codex/blob/main/docs/config.md).

### Verify install

```bash
# Plugin loaded (agents + skills):
ls ~/.codex/plugins/cache/rolepod/rolepod/*/skills | wc -l   # 11

# Hooks fire natively on Codex >=0.144 — confirm:
codex features list | grep -E '^hooks'
# expected: hooks  stable  true   (legacy plugin_hooks flag shows "removed")

# Verify hooks fire:
codex exec --skip-git-repo-check "echo OK"
# stdout shows: hook: SessionStart Completed (rolepod hooks firing through native plugin loader)

# AGENTS.md (Tier 1) always loads:
grep -A2 'marketplaces.rolepod\|plugins."rolepod' ~/.codex/config.toml
```

If hooks don't fire, check `plugins/rolepod/hooks/hooks.json` schema matches [developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks).
