# Rolepod — Multi-CLI AI Workflow System

Complete software-house team for AI coding CLIs: 18 specialist agents, 7 rules (3 always-on + 4 path-scoped) + 8 lifecycle skills, 42 bundled skills, 3 auto-trigger hooks, parallel-safe by path/concern. Native plugins for Claude Code, Codex CLI, and Gemini CLI.

**Universal:** zero project-specific refs, works in any repo from day one.

---

## What this is

Turns any supported AI coding CLI into a coordinated software-house team. 18 specialists handle different domains in parallel — backend, frontend, QA, security, performance, design, docs, ops — with explicit gates, ownership boundaries, and hand-off protocols.

Same source-of-truth content (`core/agents/`, `core/rules/`, `core/skills/`, `core/fragments/`) rendered through per-CLI adapters. No CLI is "default" — each is first-class.

Self-improving: every session captures learnings via MemPalace KG so the next session starts smarter (optional — works without it).

---

## Quick start

### Pick a CLI

| CLI | Default install path | Native primitives |
|-----|---------------------|-------------------|
| Claude Code | `~/.claude/` | agents, skills, hooks, commands, plugin |
| Codex CLI | `~/.codex/` (marketplace + `AGENTS.md`) | agents (TOML), skills, hooks, plugin |
| Gemini CLI | `~/.gemini/extensions/rolepod/` | extension, commands (TOML), skills, hooks |

Pick one with `--target=claude` / `--target=codex` / `--target=gemini`, or all three with `--target=all`. Default: `claude`. Each adapter wires into native primitives — no wrapper scripts.

### Pick a mode

| Mode | What gets installed | Command |
|------|---------------------|---------|
| **core** (default) | rolepod files only — agents, rules, hooks, 42 skills, commands, manifest, docs | `./install.sh` |
| **minimum** | core + `ui-ux-pro-max-skill` + GitNexus + MemPalace | `./install.sh --minimum` |
| **full** | minimum + caveman + rtk + the other two CLIs + openai-codex Claude plugin + chrome-devtools MCP | `./install.sh --full` |

Add `--force` to overwrite. Creates `~/.<cli>.backup-<timestamp>/` with **only rolepod-managed paths** (session history, plugin caches, file-history stay in place). Typical backup <50MB. See `docs/cli-support.md`.

### Install

```bash
# Interactive (mode prompt):
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash

# Specify mode + target:
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --minimum --target=codex
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --full --target=all --force
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

Plugins detected before install — already-installed skipped. Failed installs print fallback + continue (no abort). Final summary lists installed / skipped / manual.

Shipped hooks auto-register in each CLI's native settings (idempotent). In `--minimum`/`--full` mode, the installer prompts to run one-time setup (`mempalace init`, `gemini auth login`, openai-codex plugin reminder). Decline to skip.

After install, restart the CLI you targeted so hooks register.

> **Power-user: Agent Teams (Claude Code only) — two opt-in patterns.**
> - Broad trigger "use team" → full-lifecycle (all 6 phases use team recipes)
> - `/team-build` / `/team-verify` / etc. → surgical (that phase only)
>
> Codex / Gemini Leads use default Subagent + Task pattern. See [docs/agent-teams.md](docs/agent-teams.md).

> **Note:** Adapter conformance verified by static checks (`bash -n`, `python3 -m json.tool`, `tomllib.load`). Runtime status per CLI — see table.

### Runtime verification status

| Target | Static | Dry-run | Live hooks | Live dispatch | Status |
|--------|--------|---------|-----------|--------------|--------|
| Claude Code | ✓ | ✓ | ✓ | ✓ | **Production** |
| Codex CLI | ✓ | ✓ | ✓ | ✓ (18 agents + 42 skills) | **Production** ([global registration](docs/cli-support.md#marketplace-registration-is-global)) |
| Gemini CLI | ✓ | ✓ | ✓ | ✓ (42 skills) | **Production** |

**Static** = `bash -n` + `json.tool` + `tomllib.load()` + snapshot diff (no leaked `{{INCLUDE: ...}}`). **Dry-run** = `install.sh` writes correct files to temp dir. **Live** = real CLI, hooks fire, subagents/skills dispatch.

_Last verified: 2026-05-10, macOS Darwin 25.4.0, Codex 0.130.0, Gemini 0.40.1._

**Codex install (0.130.0+):** installer renders to `build/rendered/codex/`, runs `codex plugin marketplace add <rendered-dir>`, writes `[plugins."rolepod@rolepod"] enabled = true` to `~/.codex/config.toml`. Native plugin loader resolves the tree (18 agents + 42 skills + 4 hooks); `SessionStart` fires on every session. `~/.codex/AGENTS.md` managed block loads independently.

File runtime issues at [issues/](https://github.com/nuttaruj/rolepod/issues).

---

## Architecture

Three layers, different load mechanisms (per [Anthropic memory doc](https://code.claude.com/docs/en/memory)):

```
Tier 1 (always loaded)        entry doc core            ≤200 lines
Tier 2a (always-on rules)     rules/always-on/          3 files (eager)
Tier 2b (path-scoped rules)   rules/{code,test}/        4 files (load on file match)
Tier 3 (skill on trigger)     skills/                   42 skills + plugin skills
```

Plus: hooks (auto-fire), agents (sub-process), commands (slash /).

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

42 skills covering anti-spaghetti, TDD, debugging, frontend UI, security, performance, design, marketing, docs, planning, ops. (`zoom-out` meta-recovery + 27 domain skills authored fresh + `doubt-driven-development` / `source-driven-development` influenced by addyosmani/agent-skills.) Integrates with external skill plugins (caveman, gitnexus, ui-ux-pro-max-skill). Auto-discovery via `using-agent-skills` at SessionStart. See [Skill dependencies](#skill-dependencies).

Each CLI exposes skills as a real directory tree. Every SKILL.md ends with "Common Rationalizations" — typical excuses + data-backed rebuttals.

### Lifecycle phases (6-phase taxonomy)

Skills/agents/gates organize onto 6 phases orthogonal to the 4-step `Explore → Plan → Implement → Commit` workflow:

```
Define   → spec-driven-development
Plan     → planning-and-task-breakdown · parallel-contract-orchestration · api-and-interface-design
Build    → test-driven-development · frontend-ui-engineering · anti-spaghetti · claude-api · interface-design · interaction-design · doc-coauthoring · conversion-copywriting
Verify   → debugging-and-error-recovery · webapp-testing · browser-testing-with-devtools · performance-optimization · security-and-hardening
Review   → code-review-and-quality · code-simplification · web-design-guidelines · doubt-driven-development
Ship     → shipping-and-launch · ci-cd-and-automation · deprecation-and-migration · internal-comms · user-facing-content · documentation-and-adrs · seo
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

### Hooks — `hooks/` (auto-fire)

3 hook scripts: `project-context-loader.sh` (session start — git context), `verify-reminder.sh` (after edit), `post-ship-detect.sh` (reindex suggestion after big merges). Context-fill warnings handled by each CLI's native compact.

| Event class | Claude | Codex | Gemini |
|---|---|---|---|
| Session start | `SessionStart` | `SessionStart` | `SessionStart` |
| Before tool | — | — | `BeforeTool` |
| After tool | `PostToolUse` | `PostToolUse` | `AfterTool` |

Claude + Codex share 3 scripts; Gemini ships 3 adapted to its JSON envelope. External hooks integrate via plugins: MemPalace (Stop/SessionStart/PreCompact), GitNexus (PreToolUse/PostToolUse), `qa-pass-check.sh`.

### Commands

| CLI | Slash commands |
|-----|----------------|
| Claude Code | `/careful` + Anthropic native (`/init`, `/review`, `/clear`, `/rewind`, `/compact`, `/btw`) + openai-codex plugin commands |
| Codex CLI | n/a (commands not in Codex schema today; gates fire via entry doc — hooks require `codex features enable plugin_hooks` opt-in) |
| Gemini CLI | 6 native commands as `commands/*.toml` (`/careful`, `/ship`, `/review`, `/test`, `/plan`, `/spec`) |

### Plugin manifest

| CLI | Manifest | Schema |
|-----|----------|--------|
| Claude | `.claude-plugin/plugin.json` | spec-conformant, 598B |
| Codex | `.codex-plugin/plugin.json` | mirrors caveman schema, 1.6KB |
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

## Skill dependencies

42 skills out-of-the-box. Agents preload via `skills:` frontmatter. Optional plugins extend coverage.

| Plugin / source | Provides | Install |
|----------------|----------|---------|
| **Bundled** (`skills/`) | 42 skills covering engineering / frontend / ops / docs / content | Auto-installed by `./install.sh` |
| **[caveman](https://github.com/JuliusBrussee/caveman)** | `caveman`, `caveman-commit`, `caveman-review`, `compress` | Per repo |
| **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** | `gitnexus-*` (7 skills) + MCP tools | `npm i -g gitnexus` + MCP setup |
| **[ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)** | `ui-ux-pro-max` (used by `ui-ux-designer`) | Per repo |
| **[claude-seo](https://github.com/AgriciDaniel/claude-seo)** | 18 deep technical SEO sub-agents | Claude plugin marketplace |
| **[OpenAI Codex review plugin](https://github.com/openai/codex-plugin-cc)** | Adversarial review | Each CLI's marketplace |

Minimum baseline: 18 agents + 7 rules (3 always-on + 4 path-scoped) + 3 hooks + 42 skills + Q1-Q4 / S1-S5 / T1-T6 / F1-F5 + 6-phase lifecycle.

Full workflow → also install GitNexus + caveman + ui-ux-pro-max-skill.

**Skills referenced by agent preloads:**
- **42 bundled** → auto-installed by `./install.sh` (any mode/target)
- **1 external (`ui-ux-pro-max`)** → installed by `--minimum` / `--full`. Without it, `ui-ux-designer` skips that one preload.
- Of the 34: most preloaded by ≥1 agent; `zoom-out`, `doubt-driven-development`, `source-driven-development` are **Lead-invoked** (not preloaded).

Drop unwanted preloads by editing `agents/<name>.md`'s `skills:` list.

---

## Optional integrations

| Tool | Purpose | Install |
|------|---------|---------|
| **[rtk](https://github.com/rtk-ai/rtk)** | Rust Token Killer — 60-90% savings on `git`/`npm`/`cargo` | `cargo install rtk` |
| **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** | Impact analysis, symbol context, graph-aware rename | `npm i -g gitnexus`, then `npx gitnexus analyze` per repo |
| **[MemPalace](https://github.com/mempalace/mempalace)** | Cross-session memory KG — drives self-improvement loop | `pip install mempalace`, then `mempalace init` |

Without external reviewers → `qa-tester` is floor + auto-fallback. Without GitNexus → `rg` + Read fallback. Without MemPalace → no cross-session memory; rules still work.

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

**Patterns:** [mattpocock/skills](https://github.com/mattpocock/skills) (skill patterns + zoom-out) · [AgriciDaniel/claude-seo](https://github.com/AgriciDaniel/claude-seo) (specialized agent plugin pattern).

**External tools:** [rtk](https://github.com/rtk-ai/rtk) · [caveman](https://github.com/JuliusBrussee/caveman) · [GitNexus](https://github.com/abhigyanpatwari/GitNexus) · [MemPalace](https://github.com/mempalace/mempalace) · [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) · OpenAI Codex review plugin.

---

## License

MIT — see `LICENSE`.

## Contributing

Personal workflow system. Fork freely. Send feedback via issues — especially Codex / Gemini runtime reports.

## See also

- [`docs/cli-support.md`](docs/cli-support.md) — per-CLI capability matrix + primitives
- [`CHEATSHEET.md`](CHEATSHEET.md) — 1-page quick reference
- [`core/rules/INDEX.md`](core/rules/INDEX.md) — full rule trigger map
- [`core/skills/team-routing/SKILL.md`](core/skills/team-routing/SKILL.md) — agent picker + parallel pattern
- [`core/rules/always-on/agent-protocol.md`](core/rules/always-on/agent-protocol.md) — shared subagent rules
- [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) / [`adapters/codex/plugins/rolepod/.codex-plugin/plugin.json`](adapters/codex/plugins/rolepod/.codex-plugin/plugin.json) / [`adapters/gemini/gemini-extension.json`](adapters/gemini/gemini-extension.json) — per-CLI manifests
