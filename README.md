# Rolepod — Multi-CLI AI Workflow System

Complete software-house team for AI coding CLIs: 18 specialist agents, 7 rules (3 always-on + 4 path-scoped) + 8 lifecycle skills, 44 bundled skills, 10 hooks (6 context + 4 enforcement), parallel-safe by path/concern. Native plugins for Claude Code, Codex CLI, and Gemini CLI.

**Universal:** zero project-specific refs, works in any repo from day one.

---

## What this is

Turns any supported AI coding CLI into a coordinated software-house team. 18 specialists handle different domains in parallel — backend, frontend, QA, security, performance, design, docs, ops — with explicit gates, ownership boundaries, and hand-off protocols.

Same source-of-truth content (`core/agents/`, `core/rules/`, `core/skills/`, `core/fragments/`) rendered through per-CLI adapters. No CLI is "default" — each is first-class.

Self-improving: every session captures learnings via MemPalace KG so the next session starts smarter (optional — works without it).

### Positioning

**Lean workflow spine + specialist agent routing + cost-aware model tiers** for full-stack software-house work on AI coding CLIs.

Rolepod ships a workflow router (`using-rolepod`) so every task flows through the same spine, then `team-routing` picks the right specialist agent for the phase. Lead doesn't see the full 44-skill / 18-agent surface every turn — only Tier 0 (router) + Tier 1 (core workflow) load by default; specialists fire on domain match.

---

## Rolepod workflow spine

Every request routes through this spine before code lands:

```
Define → Plan → Build → Verify → Review → Ship
```

The **`using-rolepod`** router skill (Tier 0) fires first on each request, picks the phase, and chains into the right Tier 1 core-workflow skill:

| Phase | Trigger | Tier 1 skill |
|---|---|---|
| **Define** | vague feature / "build / add / create" | `spec-driven-development` |
| **Plan** | spec exists or work spans multiple files | `planning-and-task-breakdown` (+ `team-routing` + `parallel-contract-orchestration` when multi-agent) |
| **Build** | approved plan or explicit code task | `test-driven-development` (+ `subagent-task-execution` when delegated) |
| **Build (bug)** | "fix / failing / broken" | `systematic-debugging` → `test-driven-development` |
| **Build (refactor)** | "refactor / simplify / clean up" | `code-simplification` |
| **Verify** | claim of "done / fixed / works" | `post-change-verify` |
| **Review** | before ship / multi-file / high-risk | `code-review-and-quality` (+ `reviewer-flow` for adversarial routing) |
| **Ship** | "ship / merge / push / PR" | `pre-merge-gate` |

**Skip rule** — the spine is skippable only when (a) the task is trivial-answer-only with no file change, OR (b) the diff is ≤5 lines / single file / zero logic / not on a high-risk path, OR (c) the user explicitly authorizes skip ("skip spec", "just commit"). The skip must be stated in the response.

### Skill tiers

Rolepod ships 44 skills total, organized by routing tier:

| Tier | Purpose | Count |
|---|---|---|
| **0 — Router** | `using-rolepod` — loaded first, decides the phase | 1 |
| **1 — Core Workflow** | the default path each phase fires | 11 |
| **2 — Specialist** | fire by domain match inside a phase (frontend / billing / security / browser / etc.) | 29 |
| **3 — Compatibility shims** | redirect legacy trigger phrases to canonical Tier 1 skills | 2 |

Tier 1 (11 core workflow skills): `spec-driven-development`, `planning-and-task-breakdown`, `systematic-debugging`, `test-driven-development`, `team-routing`, `parallel-contract-orchestration`, `subagent-task-execution`, `post-change-verify`, `code-review-and-quality`, `pre-merge-gate`, `code-simplification`. Tier 0 (`using-rolepod`) loads ahead of these on every turn — combined default Lead surface = 12 skills.

Specialists stay on disk and fire when their domain matches — the router doesn't hide them, just orders the work so phase decisions land before specialist selection.

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

Rolepod installs the framework itself: agents, rules, hooks, 44 skills, commands, manifest, docs. **No 3rd-party tools, plugins, or CLIs are auto-installed.** For add-ons that pair well with rolepod, see [Recommended add-ons](#recommended-add-ons) below — install each one yourself; the framework auto-integrates when present.

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

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --uninstall --target=claude
```

Targets: `claude` / `codex` / `gemini` / `all`. Removed per target:
- **Claude** — `~/.claude/{agents,rules,skills,hooks,commands,.claude-plugin}` rolepod files + managed block in `~/.claude/CLAUDE.md` + rolepod hook entries in `~/.claude/settings.json`.
- **Codex** — rolepod marketplace + `[plugins."rolepod@rolepod"]` line in `~/.codex/config.toml` + managed block in `~/.codex/AGENTS.md`.
- **Gemini** — `~/.gemini/extensions/rolepod/` + managed block in `~/.gemini/GEMINI.md`.

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
| `global` (default) | **full native install** (`~/.claude/` — agents, skills, hooks, settings) | full marketplace + plugin cache + AGENTS.md (`~/.codex/`) | full extension + GEMINI.md (`~/.gemini/`) |
| `project` | **full native install** (`$PWD/.claude/` — agents, skills, hooks, settings) | **rules-only** (`$PWD/AGENTS.md`) | **rules-only** (`$PWD/GEMINI.md`) |

**Project scope is full for Claude; rules-only for Codex/Gemini.** Codex plugins and Gemini extensions are global-only by CLI design — `--scope=project` writes only the auto-loaded entry doc (AGENTS.md / GEMINI.md). Native plugin agents/skills/hooks are NOT installed per-project for those CLIs. For full Codex/Gemini activation, run `--scope=global` separately.

**Codex hooks require explicit opt-in.** Fresh Codex install has `plugin_hooks` flagged `under development, false` — rolepod registers `hooks/hooks.json` in the plugin but Codex won't fire them until the user enables it: `codex features enable plugin_hooks`. Agents + skills load regardless. Without the opt-in, gate enforcement on Codex relies entirely on AGENTS.md (Tier 1) — hooks are inert.

Shipped hooks auto-register in each CLI's native settings (idempotent). If MemPalace is detected on `$PATH`, its `SessionStart` / `Stop` / `PreCompact` hooks are also auto-registered (self-guarded — silently no-ops if uninstalled later). For other add-ons see [Recommended add-ons](#recommended-add-ons).

After install, restart the CLI you targeted so hooks register.

> **`/team-all` — adaptive parallel orchestration (Claude only).**
> Always works. Adapts silently to the environment:
> - Claude v2.1.32+ AND `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` → real multi-process teammates per [official agent-teams spec](https://code.claude.com/docs/en/agent-teams)
> - Any other Claude state → Subagent + Task + cohesion contract (single-process, same outcome shape)
>
> No friction either way — invoke it, get parallel work. Lead does not announce which mode it picked.
>
> **Want real teammate mode?** Add to `~/.claude/settings.json`:
> ```json
> { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
> ```
> Plus Claude Code v2.1.32+ (`claude --version`). Note: also set `ROLEPOD_ALLOW_SHARED_WORKTREE=1` before spawning the team so rolepod's session-lock hook doesn't warn on teammate sessions sharing the Lead's worktree.
>
> Per-phase team commands (`/team-define`, `/team-build`, etc.) removed — they were subagent recipes that Lead routinely pattern-matched into regular dispatch.
>
> Codex / Gemini have no `/team-all` command — use natural-language Subagent dispatch via `team-routing` skill. See [docs/agent-teams.md](docs/agent-teams.md).

> **Note:** Adapter conformance verified by static checks (`bash -n`, `python3 -m json.tool`, `tomllib.load`). Runtime status per CLI — see table.

### Runtime verification status

| Target | Static | Dry-run | Live hooks | Live dispatch | Status |
|--------|--------|---------|-----------|--------------|--------|
| Claude Code | ✓ | ✓ | ✓ | ✓ | **Production** |
| Codex CLI | ✓ | ✓ | ⚠️ opt-in only — `codex features enable plugin_hooks` required (default: `under development, false`) | ✓ (18 agents + 44 skills via plugin cache) | **Production** (hooks opt-in) |
| Gemini CLI | ✓ | ✓ | ✓ | ✓ (44 skills) | **Production** |

**Static** = `bash -n` + `json.tool` + `tomllib.load()` + snapshot diff (no leaked `{{INCLUDE: ...}}`). **Dry-run** = `install.sh` writes correct files to temp dir. **Live** = real CLI; hooks fire (Claude + Gemini always; Codex only after `plugin_hooks` opt-in); subagents/skills dispatch.

_Last verified: 2026-05-15, macOS Darwin 25.4.0, Codex 0.130.0, Gemini 0.40.1._

**Codex install (0.130.0+):** installer renders to `build/rendered/codex/`, runs `codex plugin marketplace add <rendered-dir>`, populates `~/.codex/plugins/cache/rolepod/rolepod/<version>/`, writes `[plugins."rolepod@rolepod"] enabled = true` to `~/.codex/config.toml`. Native plugin loader resolves agents + skills (18 + 44) from cache. `SessionStart` fires **only after `codex features enable plugin_hooks`** (default flag is `under development, false`). `~/.codex/AGENTS.md` managed block loads independently of `plugin_hooks` state.

File runtime issues at [issues/](https://github.com/nuttaruj/rolepod/issues).

---

## Architecture

Three layers, different load mechanisms (per [Anthropic memory doc](https://code.claude.com/docs/en/memory)):

```
Tier 1 (always loaded)        entry doc core            ≤200 lines
Tier 2a (always-on rules)     rules/always-on/          3 files (eager)
Tier 2b (path-scoped rules)   rules/{code,test}/        4 files (load on file match)
Tier 3 (skill on trigger)     skills/                   44 skills + plugin skills
```

Plus: hooks (Claude/Gemini auto-fire; Codex opt-in via `plugin_hooks`), agents (sub-process), commands (slash /).

### Tier 1 — Always-on core (entry doc)

Gates that fire every task — Identity, Verify-first, Q1-Q4 delegation, S1-S5 simplicity, T1-T6 testing, F1-F5 failure-mode, CI 3-phase, Hard stops.

Loaded from each CLI's entry doc: `~/.claude/CLAUDE.md` / `~/.codex/AGENTS.md` / `~/.gemini/GEMINI.md`.

### Tier 2a — Always-on rules (`rules/always-on/`)

Eager-loaded judgment shapers (no `paths:` frontmatter):

| File | Trigger |
|------|---------|
| `communication.md` | tone / CEO modes — every reply |
| `verify-first.md` | claiming a fact — every action |
| `agent-protocol.md` | shared by all 18 agents |

### Tier 2b — Path-scoped rules (`rules/{code,test}/`)

Lazy-load via `paths:` frontmatter — only enter context when Claude touches matching files:

| File | Paths |
|------|-------|
| `code/code-quality.md` | source files (ts/py/go/rs/...) |
| `code/code-intel.md` | source files |
| `code/code-intel-workflow.md` | source files |
| `test/testing.md` | test files (`*test*` / `*spec*` / `__tests__/`) |

### Tier 3 — Skills (on trigger phrase)

44 skills covering anti-spaghetti, TDD, debugging, frontend UI, security, performance, design, marketing, docs, planning, ops. (`zoom-out` meta-recovery + 27 domain skills authored fresh + `doubt-driven-development` / `source-driven-development` influenced by addyosmani/agent-skills.) Auto-discovery via `using-agent-skills` at SessionStart. Optional add-on skills (caveman, gitnexus, ui-ux-pro-max) integrate when the user installs them — see [Recommended add-ons](#recommended-add-ons).

Each CLI exposes skills as a real directory tree. Every SKILL.md ends with "Common Rationalizations" — typical excuses + data-backed rebuttals.

### Lifecycle phases (6-phase taxonomy)

Skills/agents/gates organize onto 6 phases orthogonal to the 4-step `Explore → Plan → Implement → Commit` workflow:

```
Define   → spec-driven-development
Plan     → planning-and-task-breakdown · parallel-contract-orchestration · api-and-interface-design
Build    → test-driven-development · frontend-ui-engineering · anti-spaghetti · claude-api · interface-design · interaction-design · doc-coauthoring · conversion-copywriting
Verify   → systematic-debugging · webapp-testing · browser-testing-with-devtools · performance-optimization · security-and-hardening
Review   → code-review-and-quality · code-simplification · web-design-guidelines · doubt-driven-development
Ship     → shipping-and-launch · ci-cd-and-automation · internal-comms · user-facing-content · documentation-and-adrs · seo
Cross    → zoom-out · source-driven-development · context-engineering
```

Full mapping: [CHEATSHEET.md](CHEATSHEET.md#lifecycle-phases-6-phase-taxonomy). Influence: addyosmani/agent-skills taxonomy.

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

### Hooks — `hooks/` (auto-fire on Claude/Gemini; opt-in on Codex)

Rolepod keeps 10 root hook scripts in `hooks/`, but each CLI exposes a different subset:

- **Claude:** copies all 10 scripts and registers 9 rolepod entries in `settings.json` (2x `SessionStart`, 4x `PreToolUse`, 2x `PostToolUse`, 1x `Stop`). `gitnexus-wrap.sh` is not a standalone rolepod entry; it patches the optional GitNexus hook when GitNexus is installed.
- **Codex:** ships 5 plugin command hooks: `project-context-loader.sh`, `gate-reminder.sh`, `precommit-gate.sh`, `verify-reminder.sh`, `post-ship-detect.sh`.
- **Gemini:** ships 4 adapter command hooks: `session-start.sh`, `before-tool.sh`, `after-tool.sh`, `pre-compress.sh`.

**Codex caveat:** hooks register via `hooks/hooks.json` inside the plugin but require `codex features enable plugin_hooks` (default flag: `under development, false`). Without the opt-in, rolepod's hooks are registered but inert — Tier 1 rules in AGENTS.md still drive gate compliance.

| Event class | Claude | Codex | Gemini |
|---|---|---|---|
| Session start | `SessionStart` (`project-context-loader`, `session-lock`) | `SessionStart` (`project-context-loader`) | `SessionStart` (`session-start`) |
| Before tool | `PreToolUse` (`gate-reminder`, `precommit-gate`, `block-subagent-commit`, `cohesion-contract-check`) | `PreToolUse` (`gate-reminder`, `precommit-gate`) | `BeforeTool` (`before-tool`) |
| After tool | `PostToolUse` (`verify-reminder`, `post-ship-detect`) | `PostToolUse` (`verify-reminder`, `post-ship-detect`) | `AfterTool` (`after-tool`) |
| Stop / compact | `Stop` (`session-unlock`) | — | `PreCompress` (`pre-compress`) |

External hooks integrate via plugins: MemPalace (Stop/SessionStart/PreCompact), GitNexus (PreToolUse/PostToolUse), `qa-pass-check.sh`.

### Commands

| CLI | Slash commands |
|-----|----------------|
| Claude Code | `/careful` + Anthropic native (`/init`, `/review`, `/clear`, `/rewind`, `/compact`, `/btw`) |
| Codex CLI | n/a (commands not in Codex schema today; gates fire via entry doc — hooks require `codex features enable plugin_hooks` opt-in) |
| Gemini CLI | 6 native commands as `commands/*.toml` (`/careful`, `/ship`, `/review`, `/test`, `/plan`, `/spec`) |

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
  ↓ Stop hook (or equivalent per CLI)
  ↓ MemPalace KG saves learnings

Session N+1 (any time, any project, any CLI)
  ↓ SessionStart hook → MemPalace recall
  ↓ Lead starts task knowing past context
  ↓ Avoids re-deciding solved problems
  ↓ Stop hook captures more learnings

→ Each session smarter than the last
```

---

## Memory architecture — two coexisting systems

| System | Scope | How | Plugin? |
|--------|-------|-----|---------|
| **Anthropic auto memory** (Tier 1 — fallback) | per-project (git path) | Built into Claude Code v2.1.59+. Claude writes `~/.claude/projects/<project>/memory/MEMORY.md` on memorable events. First 200 lines / 25KB loaded every session. | No — default ON |
| **Native agent memory** (Tier 2 — `memory:` frontmatter) | per-agent, `project` or `user` | Set in frontmatter; Claude Code parses directly | No — works out-of-box |
| **MemPalace KG** (Tier 3 — optional plugin) | cross-session graph | Stop captures → SessionStart recalls; powers self-improvement loop; works on all 3 CLIs | Yes — optional |

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

**Fallback escalation:** Lead spawns `qa-tester` / `universal-reviewer` with `model: opus` when external reviewers unavailable, when PR touches high-risk surface, or when user requests deep review. See skill `reviewer-flow`.

---

## Recommended add-ons

Rolepod ships **pure framework only** — agents, rules, hooks, 44 skills, commands, manifests. No 3rd-party tools, plugins, or CLIs are auto-installed by `./install.sh`.

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
| **[MemPalace](https://github.com/mempalace/mempalace)** | KG of past decisions, codepaths, architectural choices. `install.sh` auto-registers `SessionStart` / `Stop` / `PreCompact` hooks (self-guarded — silently no-ops if uninstalled). Lead queries via `mempalace_kg_query` before re-deciding | Anthropic auto memory (Tier 1) + per-agent `memory:` frontmatter still work — just no cross-session KG recall | `pip install mempalace` then `mempalace init` |

### Design

Component recipes + style guidance for the `ui-ux-designer` agent.

| Add-on | What rolepod auto-uses it for | Fallback when missing | Install |
|---|---|---|---|
| **[ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)** | `ui-ux-designer` agent preloads the `ui-ux-pro-max` skill when present (50+ styles, 161 palettes, 57 font pairings) | `ui-ux-designer` skips that one preload — other design skills (`interface-design`, `interaction-design`, `web-design-guidelines`) still load | Per repo: `git clone` into `~/.claude/plugins/ui-ux-pro-max-skill` |

### QA Multi-opinion

Adversarial review beyond the in-process `qa-tester` floor.

| Add-on | What rolepod auto-uses it for | Fallback when missing | Install |
|---|---|---|---|
| **[OpenAI Codex review plugin](https://github.com/openai/codex-plugin-cc)** (Claude Code plugin) | `reviewer-flow` skill routes high-risk PRs through it for adversarial pass | `qa-tester` agent (universal floor) handles correctness alone | Inside Claude Code: `/plugin install openai-codex` |
| **Codex CLI** ([@openai/codex](https://www.npmjs.com/package/@openai/codex)) | `reviewer-flow` invokes `codex exec --skip-git-repo-check '<prompt>'` for cross-CLI adversarial review (correctness + security) | qa-tester only | `npm install -g @openai/codex` then `codex login` |
| **Gemini CLI** ([@google/gemini-cli](https://www.npmjs.com/package/@google/gemini-cli)) | `reviewer-flow` invokes `gemini -p '<prompt>'` for breadth + cross-file + code-smell review | qa-tester only | `npm install -g @google/gemini-cli` then `gemini auth login` |

### Detection

`SessionStart` hook (`project-context-loader.sh`) scans for `codex` / `gemini` / `mempalace` / `gitnexus` binaries on `$PATH` and surfaces availability to Lead. No add-on detected = no banner, no nag.

### Skill preloads

44 skills ship bundled. Agents preload skills via `skills:` frontmatter. `ui-ux-pro-max` is the **only** preload that points at an external add-on — every other preload is bundled. Drop unwanted preloads by editing `core/agents/<name>.md`'s `skills:` list.

`zoom-out`, `doubt-driven-development`, `source-driven-development` are **Lead-invoked** (not preloaded by any agent).

---

## Usage examples

### New project (first time)

```bash
cd /your/new/project
claude   # or: codex, or: gemini
```

Auto-detects git repo + recent commits, project type (next.config / pyproject.toml / etc.), past sessions (MemPalace recall, empty first time). Bootstrap mode active until first session captured. Same on all 3 CLIs.

### Bug fix

Same 8-step flow on all 3 CLIs — only dispatch primitive changes:

| Step | What | Claude | Codex | Gemini |
|------|------|--------|-------|--------|
| 1 | User asks "fix login bug, session expires too early" | `claude` prompt | `codex` prompt | `gemini` prompt |
| 2 | Lead Q1-Q4 → delegate qa-tester (repro test) | `Task` tool, `subagent_type: qa-tester` | Lead reads `agents/qa-tester.toml` developer_instructions, role-switches | Lead reads qa-tester block in inlined roster, role-switches |
| 3 | qa-tester writes failing reproducing test | separate subagent context | same Lead, qa-tester persona | same Lead, qa-tester persona |
| 4 | Lead verify-first: Read auth files, find root cause | Read tool | Read tool | read_file tool |
| 5 | Edit code | Edit → `verify-reminder.sh` fires | Edit → same script | replace/edit → `after-tool.sh` fires |
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

For Codex/Gemini, `parallel-contract-orchestration` still applies — Lead writes cohesion contract, then serially dispatches against it. Deliverable identical; throughput differs. When fanout primitives land, adapters switch to native dispatch with no agent-set change.

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
- [`docs/hooks.md`](docs/hooks.md) — 10 hooks reference (triggers, gates, bypass envs)
- [`CHEATSHEET.md`](CHEATSHEET.md) — 1-page quick reference
- [`core/rules/INDEX.md`](core/rules/INDEX.md) — full rule trigger map
- [`core/skills/team-routing/SKILL.md`](core/skills/team-routing/SKILL.md) — agent picker + parallel pattern
- [`core/rules/always-on/agent-protocol.md`](core/rules/always-on/agent-protocol.md) — shared subagent rules
- [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) / [`adapters/codex/plugins/rolepod/.codex-plugin/plugin.json`](adapters/codex/plugins/rolepod/.codex-plugin/plugin.json) / [`adapters/gemini/gemini-extension.json`](adapters/gemini/gemini-extension.json) — per-CLI manifests
