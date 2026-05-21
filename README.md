# Rolepod — Multi-CLI AI Workflow System

Complete software-house team for AI coding CLIs: 18 specialist agents, 10 workflow skills (Core 10: 1 router + 9 phase skills), 7 core hooks (self-guarded). Native plugins for Claude Code, Codex CLI, and Gemini CLI.

**Universal:** zero project-specific refs, works in any repo from day one.

---

## What this is

Turns any supported AI coding CLI into a coordinated software-house team. 18 specialists handle different domains in parallel — backend, frontend, QA, security, performance, design, docs, ops — with explicit gates, ownership boundaries, and hand-off protocols.

Same source-of-truth content (`core/agents/`, `core/rules/`, `core/skills/`, `core/fragments/`) rendered through per-CLI adapters. No CLI is "default" — each is first-class.

Self-improving: every session captures learnings via MemPalace KG so the next session starts smarter (optional — works without it).

### Positioning

**Lean workflow spine + specialist agent routing + cost-aware model tiers** for full-stack software-house work on AI coding CLIs.

Rolepod ships a workflow router (`using-rolepod`) so every task flows through the same spine, then each Core 10 phase skill routes specialist work to the right agent. Lead does not see the full skill surface every turn — only Tier 0 (router) + Tier 1 (Core 10 phase skills) load by default; specialist depth lives in the 18 agents and fires on domain match.

---

## Rolepod workflow spine

Every request routes through this spine before code lands:

```
Define → Plan → Build → Verify → Review → Ship
```

The **`using-rolepod`** router skill (Tier 0) fires first on each request, picks the phase, and chains into the right Tier 1 Core 10 skill:

| Phase | Trigger | Tier 1 skill |
|---|---|---|
| **Define** | vague feature / "build / add / create" | `write-spec` |
| **Plan** | spec exists or work spans multiple files | `write-plan` (covers task breakdown, agent routing, cohesion contracts) |
| **Build** | approved plan or explicit code task | `implement-plan` (TDD, bounded delegation, worktree discipline) |
| **Build (bug)** | "fix / failing / broken" | `debug-issue` |
| **Build (refactor)** | "refactor / simplify / clean up" | `simplify-code` |
| **Verify** | claim of "done / fixed / works" | `check-work` |
| **Review** | before ship / multi-file / high-risk | `review-code` (covers multi-axis review, reviewer routing, adversarial mode) |
| **Ship** | "ship / merge / push / PR" | `finish-work` (pre-merge gate, CI lanes, 4-option finish menu) |
| **Recovery** | stuck / context heavy / unfamiliar repo | `manage-context` |

**Skip rule** — the spine is skippable only when (a) the task is trivial-answer-only with no file change, OR (b) the diff is ≤5 lines / single file / zero logic / not on a high-risk path, OR (c) the user explicitly authorizes skip ("skip spec", "just commit"). The skip must be stated in the response.

### Skill tiers (Core 10)

Rolepod ships 10 executable skills total — 1 router + 9 Core workflow skills. Legacy skill names are documented in [docs/legacy-skill-map.md](docs/legacy-skill-map.md), not installed as executable shims:

| Tier | Purpose | Count |
|---|---|---|
| **0 — Router** | `using-rolepod` — loaded first, decides the phase | 1 |
| **1 — Core 10 phase skills** | one skill per phase: Define / Plan / Build / Verify / Review / Ship + recovery | 9 |
| **2 — Specialist** | empty by default; domain depth lives in the 18 specialist agents | 0 |
| **3 — Legacy map** | prose-only migration map; no executable skill dirs | 0 |

Tier 1 (Core 9 phase skills): `write-spec`, `write-plan`, `implement-plan`, `debug-issue`, `check-work`, `review-code`, `finish-work`, `simplify-code`, `manage-context`. Tier 0 (`using-rolepod`) loads ahead of these on every turn — combined default Lead surface = 10 skills.

Domain expertise (frontend / API / security / performance / SEO / content / platform) lives in the 18 specialist agents and is routed from inside the Core 10 phase skills. If an old trigger phrase stops routing correctly, update the matching Core 10 frontmatter instead of adding a new shim.

---

## Quick start

### Pick a CLI

| CLI | Default install path | Native primitives |
|-----|---------------------|-------------------|
| Claude Code | `~/.claude/` | agents, skills, hooks, commands, plugin |
| Codex CLI | `~/.codex/` (marketplace + `AGENTS.md`) | agents (TOML), skills, hooks, plugin |
| Gemini CLI | `~/.gemini/extensions/rolepod/` | extension, commands (TOML), skills, hooks |

Pick one with `--target=claude` / `--target=codex` / `--target=gemini`, or all three with `--target=all`. Default: `claude`. Each adapter wires into native primitives — no wrapper scripts.

### Install — pure framework only

Rolepod installs the framework itself: agents, rules, hooks, Core 10 skills, commands, manifest, docs. **No 3rd-party tools, plugins, or CLIs are auto-installed.** For add-ons that pair well with rolepod, see [Recommended add-ons](#recommended-add-ons) below — install each one yourself; the framework auto-integrates when present.

Add `--force` to overwrite. Creates `~/.<cli>.backup-<timestamp>/` with **only rolepod-managed paths** (session history, plugin caches, file-history stay in place). Typical backup <50MB. See `docs/cli-support.md`.

```bash
# Interactive (target + scope prompt):
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash

# Specify target:
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --target=codex
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --target=all --force
```

### Update

```bash
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --target=claude --force
```

`--force` overwrites rolepod-managed paths. Auto-backup at `~/.<cli>.backup-<timestamp>/` (rolepod-scoped, typically <50 MB; session history / plugin caches stay in place).

> **Update via the script only.** Claude Code is a pure plugin — `claude plugin update` / `/plugin` UI refresh update the plugin. Re-run the command above for a complete update. Same applies to Codex and Gemini — all three CLIs update through `install.sh`.

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --uninstall --target=claude
```

Targets: `claude` / `codex` / `gemini` / `all`. Removed per target:
- **Claude** — rolepod plugin (via `claude plugin uninstall rolepod@rolepod`) + rolepod marketplace (via `claude plugin marketplace remove rolepod`) + strips any legacy pre-redesign managed block from `~/.claude/CLAUDE.md`. For pre-2.0 installs, also strips any legacy hook entries from `~/.claude/settings.json`.
- **Codex** — rolepod marketplace + `[plugins."rolepod@rolepod"]` line in `~/.codex/config.toml` + managed block in `~/.codex/AGENTS.md`.
- **Gemini** — `~/.gemini/extensions/rolepod/` (entry doc `GEMINI.md` ships inside the extension dir; uninstall also strips any stale pre-PR-8 managed block from the global `~/.gemini/GEMINI.md`).

Non-rolepod content (project CLAUDE.md, other plugin installs, custom skills) untouched — uninstall is scoped.

### Install scope — pick by user intent

Two intents rolepod supports:

1. **Global default** — rolepod as your main framework everywhere. Use `--scope=global` (default). Installs full native integration for each CLI.
2. **Project-only** — you already use another global framework, want rolepod in one repo. Use `--scope=project`. No global config touched.

```bash
cd /your/project
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --target=claude --scope=project
```

| Scope | Claude | Codex | Gemini |
|-------|--------|-------|--------|
| `global` (default) | **full native install** (`~/.claude/plugins/rolepod/` plugin) | full marketplace + plugin cache + AGENTS.md (`~/.codex/`) | full extension + GEMINI.md (`~/.gemini/`) |
| `project` | **full native install** (`$PWD/.claude/plugins/rolepod/` plugin) | **rules-only** (`$PWD/AGENTS.md`) | **rules-only** (`$PWD/GEMINI.md`) |

**Project scope is full for Claude; rules-only for Codex/Gemini.** Codex plugins and Gemini extensions are global-only by CLI design — `--scope=project` writes only the auto-loaded entry doc (AGENTS.md / GEMINI.md). Native plugin agents/skills/hooks are NOT installed per-project for those CLIs. For full Codex/Gemini activation, run `--scope=global` separately.

**Codex hooks require explicit opt-in.** Fresh Codex install has `plugin_hooks` flagged `under development, false` — rolepod registers `hooks/hooks.json` in the plugin but Codex won't fire them until the user enables it: `codex features enable plugin_hooks`. Agents + skills load regardless. Without the opt-in, gate enforcement on Codex relies entirely on AGENTS.md (Tier 1) — hooks are inert.

Rolepod ships **7 core hooks** (always-on loader, context loader, session safety, discipline gates, pre-commit enforcement, multi-agent contract check) — no add-on hooks. MemPalace and GitNexus integrate via their own vendor plugins/CLI:

| Vendor | Claude | Codex | Gemini |
|---|---|---|---|
| **MemPalace** | Marketplace plugin (`claude plugin marketplace add MemPalace/mempalace` + `claude plugin install --scope user mempalace`) | `.codex-plugin` (install via `uv tool install mempalace`) | manual — clone + `uv sync` + `gemini mcp add` + PreCompress hook |
| **GitNexus** | `claude mcp add gitnexus -- npx -y gitnexus@latest mcp` | `codex mcp add gitnexus -- npx -y gitnexus@latest mcp` | no GitNexus integration |

Rolepod's value-add is **workflow rules** (when to call `gitnexus_impact`, `mempalace_kg_query`, etc.) — not hook plumbing. The vendors own their own integrations.

After install, restart the CLI you targeted so the plugin system loads.

> **`/rolepod-full` — force-full lifecycle (cross-CLI).**
> A normal prompt auto-routes through the `using-rolepod` skill — lean, phase skips allowed, the user invokes nothing. For the deliberate full lifecycle the user invokes **`/rolepod-full`** (or `$rolepod-full`): Define → Plan → Build → Verify → Review → Ship, no phase skips.
>
> `/rolepod-full` picks the best execution backend per CLI:
> - **Claude with agent-teams enabled** → real multi-process teammates per [official agent-teams spec](https://code.claude.com/docs/en/agent-teams)
> - **Claude without agent-teams** → Subagent + Task + cohesion contract (single-process, same outcome shape)
> - **Codex / Gemini** → native subagent dispatch; inline fallback when unsupported
>
> **Want real teammate mode on Claude?** Add to `~/.claude/settings.json`:
> ```json
> { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
> ```
> Plus Claude Code v2.1.32+ (`claude --version`). Also set `ROLEPOD_ALLOW_SHARED_WORKTREE=1` before spawning a team so rolepod's session-lock hook doesn't warn on teammate sessions sharing the Lead's worktree.
>
> `/rolepod` is not needed for normal use — a normal prompt auto-routes. See [docs/agent-teams.md](docs/agent-teams.md) for the teammate backend.

> **Note:** Adapter conformance verified by static checks (`bash -n`, `python3 -m json.tool`, `tomllib.load`). Runtime status per CLI — see table.

### Runtime verification status

| Target | Static | Dry-run | Live hooks | Live dispatch | Status |
|--------|--------|---------|-----------|--------------|--------|
| Claude Code | ✓ | ✓ | ✓ | ✓ | **Production** |
| Codex CLI | ✓ | ✓ | ⚠️ opt-in only — `codex features enable plugin_hooks` required (default: `under development, false`) | ✓ (10 skills via plugin cache + 18 agents in `~/.codex/agents/`) | **Production** (hooks opt-in) |
| Gemini CLI | ✓ | ✓ | ✓ | ✓ (10 skill files) | **Production** |

**Static** = `bash -n` + `json.tool` + `tomllib.load()` + snapshot diff (no leaked `{{INCLUDE: ...}}`). **Dry-run** = `install.sh` writes correct files to temp dir. **Live** = real CLI; hooks fire (Claude + Gemini always; Codex only after `plugin_hooks` opt-in); subagents/skills dispatch.

_Last verified: 2026-05-15, macOS Darwin 25.4.0, Codex 0.130.0, Gemini 0.40.1._

**Codex install (0.130.0+):** installer renders to `build/rendered/codex/`, runs `codex plugin marketplace add <rendered-dir>`, populates `~/.codex/plugins/cache/rolepod/rolepod/<version>/`, writes `[plugins."rolepod@rolepod"] enabled = true` to `~/.codex/config.toml`. Native plugin loader resolves agents + skills (18 + 10) from cache. `SessionStart` fires **only after `codex features enable plugin_hooks`** (default flag is `under development, false`). `~/.codex/AGENTS.md` managed block loads independently of `plugin_hooks` state.

File runtime issues at [issues/](https://github.com/nuttaruj/rolepod/issues).

---

## Architecture

Three layers, different load mechanisms (per [Anthropic memory doc](https://code.claude.com/docs/en/memory)):

```
Tier 1 (always loaded)        entry doc core            ≤200 lines
Skill layer (on trigger)      skills/                   10 Core skill files + optional plugin skills
Hook layer (auto-fire)        hooks/ + always-on-core.md SessionStart injects always-on judgment
```

Plus: hooks (Claude/Gemini auto-fire; Codex opt-in via `plugin_hooks`), agents (sub-process), commands (slash /).

### Tier 1 — Always-on core (entry doc)

Gates that fire every task — Identity, Verify-first, Q1-Q4 delegation, S1-S5 simplicity, T1-T6 testing, F1-F5 failure-mode, CI 3-phase, Hard stops.

Loaded from each CLI's entry doc: `~/.codex/AGENTS.md` / `~/.gemini/extensions/rolepod/GEMINI.md`. Claude loads always-on judgment via the SessionStart `always-on-loader.sh` hook, which emits `hooks/always-on-core.md` as `additionalContext`.

### Skill layer — Core 10 on trigger phrase

Core 10 public skills cover the workflow spine (define / plan / build / verify / review / ship / recovery). Deep domain expertise (frontend, API, security, performance, SEO, content, platform integration) lives in the 18 specialist agents and is routed from inside the Core 10 phase skills. Old skill names are documented in [docs/legacy-skill-map.md](docs/legacy-skill-map.md) but are not installed as executable shims. Optional add-on skills (caveman, gitnexus, ui-ux-pro-max) integrate when the user installs them — see [Recommended add-ons](#recommended-add-ons).

Each CLI exposes skills as a real directory tree. Every Core 10 SKILL.md follows the standalone contract: agent-available path + no-agent fallback path + Full Rolepod enhancement note + Hard stops.

### Lifecycle phases (6-phase taxonomy)

Core 10 maps one phase skill per workflow state; recovery handles re-context / stuck / unfamiliar repo:

```
Define   → write-spec
Plan     → write-plan          (task breakdown + agent routing + cohesion contracts)
Build    → implement-plan      (TDD + bounded delegation + worktrees)
Build    → debug-issue         (bug fix path: reproduce → trace → failing test → minimal fix)
Verify   → check-work          (evidence: tests / build / curl / browser / screenshot)
Review   → review-code         (multi-axis review + adversarial mode for high-risk diffs)
Ship     → finish-work         (pre-merge gate + CI lanes + 4-option finish menu)
Simplify → simplify-code       (behavior-preserving cleanup)
Recovery → manage-context      (re-context / session hygiene / advisor escalation / onboarding)
```

Full skill detail: [docs/skills.md](docs/skills.md) + [CHEATSHEET.md](CHEATSHEET.md).

### Agents — `agents/` (18 specialists, 7 layers)

| Layer | Agents |
|-------|--------|
| **Strategy (4 parallel)** | product-manager, business-analyst, growth-marketer, customer-success |
| **Architecture (1)** | system-architect |
| **Engineering (6 parallel by path)** | backend-developer, frontend-developer, mobile-developer, billing-engineer, ai-ml-engineer, data-scientist |
| **Quality (3 parallel by concern)** | qa-tester, security-engineer, performance-engineer |
| **Operations (1)** | devops-sre |
| **Design + Docs (2 parallel)** | ui-ux-designer, tech-writer |
| **Code Review (1)** | universal-reviewer |

Path/concern ownership + expertise list + escalation paths + skill preloads. Shared `agent-protocol.md`. Identical across all 3 CLIs.

### Hooks — `hooks/` (7 core, self-guarded)

Rolepod ships **7 core hook scripts** in `hooks/` — no add-on hooks. MemPalace and GitNexus integrate through their own vendor plugins / MCP, not through rolepod-shipped hooks. Full reference: [docs/hooks.md](docs/hooks.md).

| Category | Hooks |
|---|---|
| **Core always-on** | `always-on-loader` (SessionStart → emits always-on-core.md) |
| **Core enforcement** | `block-subagent-commit`, `cohesion-contract-check`, `gate-reminder`, `precommit-gate` |
| **Core context** | `project-context-loader` |
| **Core session safety** | `session-lifecycle` (SessionStart `--lock` + Stop `--unlock`) |

Per-CLI exposure:

- **Claude:** ships as a marketplace plugin. The installer renders rolepod to a temp dir, runs `claude plugin marketplace add <rendered-dir>` + `claude plugin install rolepod@rolepod --scope user`. The plugin tree (agents, skills, hooks) lives under `~/.claude/plugins/rolepod/` and is auto-discovered by Claude Code. The 7 core hooks are declared in the plugin's `hooks/hooks.json` (canonical plugin-root form) using `${CLAUDE_PLUGIN_ROOT}` paths, registered automatically on install. `~/.claude/settings.json` is only touched by the Claude Code CLI itself (for `enabledPlugins` / `extraKnownMarketplaces`).
- **Codex:** ships 3 core command hooks (`project-context-loader.sh`, `gate-reminder.sh`, `precommit-gate.sh`) via `hooks/hooks.json`. Claude-only hooks (`always-on-loader`, `block-subagent-commit`, `cohesion-contract-check`, `session-lifecycle`) are not registered — Codex has no `Agent` or `Stop` event API and a different plugin model.
- **Gemini:** ships 4 adapter command hooks: `session-start.sh`, `before-tool.sh`, `after-tool.sh`, `pre-compress.sh`.

**Codex caveat:** hooks register via `hooks/hooks.json` inside the plugin but require `codex features enable plugin_hooks` (default flag: `under development, false`). Without the opt-in, rolepod's hooks are registered but inert — Tier 1 rules in AGENTS.md still drive gate compliance.

| Event class | Claude | Codex | Gemini |
|---|---|---|---|
| Session start | `SessionStart` (`project-context-loader`, `session-lifecycle --lock`) | `SessionStart` (`project-context-loader`) | `SessionStart` (`session-start`) |
| Before tool | `PreToolUse` (`gate-reminder`, `precommit-gate`, `block-subagent-commit`, `cohesion-contract-check`) | `PreToolUse` (`gate-reminder`, `precommit-gate`) | `BeforeTool` (`before-tool`) |
| After tool | — | — | `AfterTool` (`after-tool`) |
| Stop / compact | `Stop` (`session-lifecycle --unlock`) | — | `PreCompress` (`pre-compress`) |

MemPalace and GitNexus ship their own hooks through their own integration — install them per [Recommended add-ons](#recommended-add-ons). Rolepod does not register, wrap, or bridge any vendor hook.

### Commands

| CLI | Slash commands |
|-----|----------------|
| Claude Code | `/rolepod-full` (skill — force-full lifecycle) + Anthropic native (`/init`, `/review`, `/clear`, `/rewind`, `/compact`, `/btw`) |
| Codex CLI | `$rolepod-full` (skill via Codex skill UI); gates fire via entry doc — hooks require `codex features enable plugin_hooks` opt-in |
| Gemini CLI | `/rolepod-full` available cross-CLI via the `rolepod-full` skill; no native `.toml` slash commands |

### Plugin manifest

| CLI | Manifest | Schema |
|-----|----------|--------|
| Claude | `.claude-plugin/plugin.json` | spec-conformant, 598B |
| Codex | `.codex-plugin/plugin.json` | Codex plugin schema, 1.6KB |
| Gemini | `gemini-extension.json` | extension schema, 551B |

---

## Active gates (always-on enforcement)

| Gate | When | What |
|------|------|------|
| **Q1-Q4** | before edit | files>1 / verify-run / design / tools>3 → delegate |
| **S1-S5** | before commit | feature beyond / abstraction single-use / config nobody asked / defensive impossible / pattern 3+ |
| **T1-T6** | before commit | needs test / new pass / existing pass / fast / isolated / assertion correct |
| **F1-F5** | before done | hallucinated / scope creep / cascading / context loss / tool misuse |
| **CI 3-phase** | merge | Phase 1 always / Phase 2 path / Phase 3 nightly |
| **Reviewer routing** | merge | qa-tester floor + Codex/Gemini per PR profile |
| **Hard stops** | escalation | 3rd agent / 3rd PR / file vs agent / destructive / 50k+ |
| **Verify-first** | every claim | confirm from primary source |

---

## Self-improvement loop

```
Session N
  ↓ Stop hook (Claude) / manual capture (Codex + Gemini)
  ↓ MemPalace KG saves load-bearing learnings

Session N+1
  ↓ SessionStart hook (Claude + Codex with plugin_hooks) / manual MCP recall (Gemini)
  ↓ Lead starts task with past context
  ↓ Avoids re-deciding solved problems
  ↓ Capture more learnings before ship / stop

→ Each session smarter than the last
```

---

## Memory architecture — two coexisting systems

| System | Scope | How | Plugin? |
|--------|-------|-----|---------|
| **Anthropic auto memory** (Tier 1 — fallback) | per-project (git path) | Built into Claude Code v2.1.59+. Claude writes `~/.claude/projects/<project>/memory/MEMORY.md` on memorable events. First 200 lines / 25KB loaded every session. | No — default ON |
| **Native agent memory** (Tier 2 — `memory:` frontmatter) | per-agent, `project` or `user` | Set in frontmatter; Claude Code parses directly | No — works out-of-box |
| **MemPalace KG** (optional plugin) | cross-session graph | Claude: Stop captures + SessionStart recalls. Codex: SessionStart bridge when `plugin_hooks` is enabled; capture remains manual. Gemini: manual / MCP-assisted until native harness support. | Yes — optional |

In rolepod: 15 agents use `memory: project` (codepaths / patterns / decisions scoped to repo); 3 use `memory: user` — `business-analyst` (pricing / ROI / competitor research generic), `ai-ml-engineer` (LLM API patterns + prompt caching idioms travel across projects), `growth-marketer` (SEO frameworks + copy formulas + conversion patterns reusable). `memory:` is a Claude primitive; Codex/Gemini achieve same scoping via per-agent TOML / inlined roster.

**Graceful degradation** — install MemPalace for richest cross-session recall; without it, Anthropic auto memory (Tier 1) still gives per-project persistence built into Claude Code (Codex/Gemini: project-level git context only). Q1-Q4 / S1-S5 / T1-T6 / F1-F5 gates and reviewer flow unaffected by memory tier.

---

## Model + effort allocation

| Tier | Count | Agents |
|------|-------|--------|
| **Opus xhigh** | 1 | security-engineer |
| **Opus high** | 1 | system-architect |
| **Sonnet high** | 5 | ai-ml-engineer, billing-engineer, performance-engineer, qa-tester, universal-reviewer |
| **Sonnet standard** | 7 | backend-developer, frontend-developer, mobile-developer, data-scientist, devops-sre, ui-ux-designer, product-manager |
| **Haiku** | 4 | business-analyst, customer-success, growth-marketer, tech-writer |

Estimated **~50-60% cost reduction** vs "all Opus high" while keeping depth where bugs are expensive (auth / billing / migrations / arch). Codex + Gemini adapters preserve same tiering.

**Fallback escalation:** Lead spawns `qa-tester` / `universal-reviewer` with `model: opus` when external reviewers unavailable, when PR touches high-risk surface, or when user requests deep review. See skill `review-code`.

---

## Recommended add-ons

Rolepod ships **pure framework only** — agents, rules, hooks, Core 10 skills, commands, manifests. No 3rd-party tools, plugins, or CLIs are auto-installed by `./install.sh`.

The framework is designed to **auto-integrate** when a recommended add-on is present on the user's system. Install whichever ones you want, on your own; rolepod hooks/rules/skills detect them at runtime and wire up. **Nothing breaks if an add-on is missing** — every integration has a documented fallback.

### Token Optimize

Cut token usage on routine commands and code-intel queries.

| Add-on | What rolepod auto-uses it for | Fallback when missing | Install |
|---|---|---|---|
| **[rtk](https://github.com/rtk-ai/rtk)** | Wraps `git` / `npm` / `cargo` calls — 60-90% token reduction on routine output | Raw command output (no compression) | `cargo install rtk` |
| **[caveman](https://github.com/JuliusBrussee/caveman)** | Compressed reply mode (`/caveman` slash command, ~75% token cut) | Normal verbose replies | Per repo: `git clone` into `~/.claude/plugins/caveman` |
| **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** | `gitnexus_impact` / `gitnexus_context` / `gitnexus_query` — sub-second graph queries instead of fan-out file reads. `code-search.md` rule auto-prefers it for symbol lookups; `using-rolepod` audit row uses it for scope-then-spawn | `rg` + `find` text search (slower for symbol/caller lookups) | `npm i -g gitnexus` then `npx gitnexus analyze` per repo |

### Self-improvement

Cross-session memory so each session starts smarter.

| Add-on | What rolepod auto-uses it for | Fallback when missing | Install |
|---|---|---|---|
| **[MemPalace](https://github.com/mempalace/mempalace)** | KG of past decisions, codepaths, architectural choices. `install.sh` auto-registers Claude `SessionStart` / `Stop` / `PreCompact` hooks and Codex's optional `SessionStart` bridge when MemPalace is on `$PATH`. Lead queries via `mempalace_kg_query` before re-deciding | Anthropic auto memory (Tier 1) + per-agent `memory:` frontmatter still work — just no cross-session KG recall | `pip install mempalace` then `mempalace init` |

### Design

Component recipes + style guidance for the `ui-ux-designer` agent.

| Add-on | What rolepod auto-uses it for | Fallback when missing | Install |
|---|---|---|---|
| **[ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)** | `ui-ux-designer` agent preloads the `ui-ux-pro-max` skill when present (50+ styles, 161 palettes, 57 font pairings) | `ui-ux-designer` skips that one preload — other design skills (`interface-design`, `interaction-design`, `web-design-guidelines`) still load | Per repo: `git clone` into `~/.claude/plugins/ui-ux-pro-max-skill` |

### QA Multi-opinion

Adversarial review beyond the in-process `qa-tester` floor.

| Add-on | What rolepod auto-uses it for | Fallback when missing | Install |
|---|---|---|---|
| **[OpenAI Codex review plugin](https://github.com/openai/codex-plugin-cc)** (Claude Code plugin) | `review-code` routes high-risk PRs through it for adversarial pass | `qa-tester` agent (universal floor) handles correctness alone | Inside Claude Code: `/plugin install openai-codex` |
| **Codex CLI** ([@openai/codex](https://www.npmjs.com/package/@openai/codex)) | `review-code` invokes `codex exec --skip-git-repo-check '<prompt>'` for cross-CLI adversarial review (correctness + security) | qa-tester only | `npm install -g @openai/codex` then `codex login` |
| **Gemini CLI** ([@google/gemini-cli](https://www.npmjs.com/package/@google/gemini-cli)) | `review-code` invokes `gemini -p '<prompt>'` for breadth + cross-file + code-smell review | qa-tester only | `npm install -g @google/gemini-cli` then `gemini auth login` |

### Detection

`SessionStart` hook (`project-context-loader.sh`) scans for `codex` / `gemini` / `mempalace` / `gitnexus` binaries on `$PATH` and surfaces availability to Lead. No add-on detected = no banner, no nag.

### Skill preloads

10 Core skill files ship bundled. Agents preload Core 10 skills via `skills:` frontmatter. `ui-ux-pro-max` is the **only** preload that points at an external add-on — every other preload is bundled. Drop unwanted preloads by editing `core/agents/<name>.md`'s `skills:` list.

Recovery / adversarial / source-grounding patterns live inside the relevant Core 10 skills (`manage-context`, `review-code`, `write-plan`) — Lead invokes them via the phase trigger rather than preloading them on every agent.

---

## Usage examples

### New project (first time)

```bash
cd /your/new/project
claude   # or: codex, or: gemini
```

Auto-detects git repo + recent commits and project type (next.config / pyproject.toml / etc.). Claude also gets MemPalace recall when installed; Codex gets the optional SessionStart bridge when MemPalace is installed and `plugin_hooks` is enabled; Gemini uses manual / MCP recall for now.

### Bug fix

Same 8-step flow on all 3 CLIs — only dispatch primitive changes:

| Step | What | Claude | Codex | Gemini |
|------|------|--------|-------|--------|
| 1 | User asks "fix login bug, session expires too early" | `claude` prompt | `codex` prompt | `gemini` prompt |
| 2 | Lead Q1-Q4 → delegate qa-tester (repro test) | `Task` tool, `subagent_type: qa-tester` | Lead reads `agents/qa-tester.toml` developer_instructions, role-switches | Lead reads qa-tester block in inlined roster, role-switches |
| 3 | qa-tester writes failing reproducing test | separate subagent context | same Lead, qa-tester persona | same Lead, qa-tester persona |
| 4 | Lead verify-first: Read auth files, find root cause | Read tool | Read tool | read_file tool |
| 5 | Edit code | Edit → `gate-reminder.sh` checks high-risk path | Edit → same hook | replace/edit → `after-tool.sh` fires |
| 6 | Run test → green | Bash | Bash | run_shell_command |
| 7 | S1-S5 + T1-T6 + F1-F5 gates | inline by Lead | inline by Lead | inline by Lead |
| 8 | Pre-merge: hotfix profile → qa-tester only → APPROVED → commit + push | `gh pr create`, auto-merge after CI green | same | same |

Gates and routing identical across CLIs. Only difference: Claude spawns qa-tester in separate context (parallel-capable); Codex/Gemini Lead-orchestrate inline (sequential).

### New feature (parallel team)

```
User: add Google OAuth to login

Phase 1 — Lead interview → SPEC.md
Phase 2 — Strategy + Architecture (parallel-eligible)
  product-manager (user stories)
  system-architect (tech design)
Phase 3 — Engineering (parallel-eligible by path)
  backend-developer (auth endpoint)
  frontend-developer (OAuth flow UI)
  ui-ux-designer (button + flow polish)
Phase 4 — Quality (parallel-eligible by concern)
  qa-tester (integration tests)
  security-engineer (token storage audit)
  performance-engineer (auth perf)
Phase 5 — Reviewer flow → ship → CI auto-merge after green
```

How each CLI executes:

| CLI | Orchestration | Dispatch | Parallel? |
|-----|---------------|----------|-----------|
| **Claude Code** | Native fanout via `Task` | `Agent({subagent_type: ...})` per agent, one assistant turn | YES — true parallel contexts |
| **Codex CLI** | Lead role-switches | Reads `agents/<name>.toml` `developer_instructions`, inline | Serial |
| **Gemini CLI** | Lead role-switches | Reads agent block from inlined `GEMINI.md`, inline | Serial |

For Codex/Gemini, the cohesion contract step inside `write-plan` still applies — Lead writes the contract first, then serially dispatches against it. Deliverable identical; throughput differs. When fanout primitives land, adapters switch to native dispatch with no agent-set change.

---

## Design principles

1. **Identity-agnostic** — any model (Opus / Sonnet / Haiku) = Lead, same role
2. **CLI-agnostic** — Claude / Codex / Gemini all first-class
3. **Verify-first** — never claim without primary-source verification
4. **Active gates** — workflow checkpoints, not passive guidance
5. **Anti-bloat** — concrete questions, short files
6. **Anti-spaghetti** — same pattern in 3+ → centralize
7. **Universal** — zero project-specific refs
8. **Parallel-safe** — path/concern/artifact ownership prevents collision
9. **Self-improving** — every session feeds the next via MemPalace KG
10. **Graceful degradation** — works without MemPalace / GitNexus / external AIs
11. **Small-model friendly** — concrete triggers, no fuzzy judgment calls

---

## Credits

**Platforms:** Anthropic Claude Code ([code.claude.com](https://code.claude.com)) · OpenAI Codex CLI · [Google Gemini CLI](https://github.com/google-gemini/gemini-cli).

**Patterns:** [mattpocock/skills](https://github.com/mattpocock/skills) (skill patterns + zoom-out).

**Recommended add-ons (not bundled — install separately):** see [Recommended add-ons](#recommended-add-ons).

---

## License

MIT — see `LICENSE`.

## Contributing

Personal workflow system. Fork freely. Send feedback via issues — especially Codex / Gemini runtime reports.

## See also

- [`docs/cli-support.md`](docs/cli-support.md) — per-CLI capability matrix + primitives
- [`docs/hooks.md`](docs/hooks.md) — 7 core hooks reference (triggers, gates, bypass envs)
- [`CHEATSHEET.md`](CHEATSHEET.md) — 1-page quick reference
- [`core/skills/write-plan/SKILL.md`](core/skills/write-plan/SKILL.md) — agent picker + parallel cohesion contract (Core 10)
- [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) / [`adapters/codex/plugins/rolepod/.codex-plugin/plugin.json`](adapters/codex/plugins/rolepod/.codex-plugin/plugin.json) / [`adapters/gemini/gemini-extension.json`](adapters/gemini/gemini-extension.json) — per-CLI manifests
