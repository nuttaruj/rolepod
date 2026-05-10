# Rolepod — Multi-CLI AI Workflow System

Complete software-house team for AI coding CLIs: 18 specialist agents, 16 lazy-load workflow rules, 27 bundled skills, 4 auto-trigger hooks, parallel-safe by path/concern ownership. Ships native plugins for Claude Code, Codex CLI, and Gemini CLI.

**Universal:** zero project-specific refs, works in any repo from day one.

---

## What this is

Turns any supported AI coding CLI into a coordinated software-house team. Instead of one Lead doing everything, 18 specialists handle different domains in parallel — backend, frontend, QA, security, performance, design, docs, ops — with explicit gates, ownership boundaries, and hand-off protocols.

Same source-of-truth content (`core/agents/`, `core/rules/`, `core/skills/`, `core/fragments/`) is rendered through per-CLI adapters into the layout each CLI expects. No CLI is the "default" — each is first-class.

Self-improving: every session captures learnings via MemPalace KG, so the next session starts smarter (when MemPalace is installed; works without it too).

---

## Quick start

### Pick a CLI

| CLI | Default install path | Native primitives used |
|-----|---------------------|------------------------|
| Claude Code | `~/.claude/` | agents, skills, hooks (settings.json), commands, plugin |
| Codex CLI (OpenAI) | `~/.codex/plugins/rolepod/` | agents (TOML), skills, hooks, plugin |
| Gemini CLI (Google) | `~/.gemini/extensions/rolepod/` | extension, commands (TOML), skills, hooks |

Pick one with `--target=claude` / `--target=codex` / `--target=gemini`, or all three with `--target=all`. Default target is `claude`. Each adapter wires into the CLI's native primitives — no wrapper scripts.

### Pick a mode

| Mode | What gets installed | Command |
|------|---------------------|---------|
| **core** (default) | rolepod files only — agents, rules, hooks, 27 bundled skills, slash commands, manifest, docs | `./install.sh` |
| **minimum** | core + `ui-ux-pro-max-skill` + GitNexus + MemPalace (final skill + cross-session memory + code intelligence) | `./install.sh --minimum` |
| **full** | minimum + caveman + rtk + the other two CLIs + openai-codex Claude Code plugin | `./install.sh --full` |

Add `--force` to overwrite existing files (auto-creates a `~/.<cli>.backup-<timestamp>/` directory). See `docs/cli-support.md` for the full per-CLI capability matrix.

### Install commands

```bash
# Interactive — pops up a menu (mode + force prompt):
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash

# Or pass mode + target directly to skip the prompt:
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --minimum --target=codex
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --full --target=all --force

# Or fully manual:
git clone https://github.com/nuttaruj/rolepod
cd rolepod
./install.sh --minimum --target=gemini
```

Every plugin is detected before installing — already-installed ones are skipped (no duplicate work). Failed installs print a manual fallback command and continue (no abort). Final summary lists what was installed / skipped / needs manual install.

The shipped hooks auto-register in each CLI's native settings location (idempotent — re-running won't duplicate entries). In `--minimum`/`--full` mode, the installer also prompts at the end to run one-time setup commands when their tools are present: `mempalace init` (cross-session memory), `gemini auth login` (Gemini CLI auth), and a reminder to install the `openai-codex` plugin from inside Claude Code. Decline any prompt to skip — you can run them manually later.

After install, restart the CLI you targeted so its hooks register.

> **Note:** Codex and Gemini adapters are spec-conformant against each CLI's published manifest schema and pass static checks (`bash -n`, `python3 -m json.tool`, `tomllib.load`). Runtime end-to-end behavior on those two CLIs is not yet user-verified — please file issues if anything misfires.

### Runtime verification status

| Target | Static checks | Dry-run install | Live runtime hooks | Live subagent dispatch | Status |
|--------|---------------|-----------------|--------------------|-----------------------|--------|
| Claude Code | ✓ | ✓ | ✓ verified | ✓ verified | **Production** |
| Codex CLI   | ✓ | ✓ | ⚠ spec-conformant, not user-verified | ⚠ spec-conformant, not user-verified | **Beta** |
| Gemini CLI  | ✓ | ✓ | ⚠ spec-conformant, not user-verified | ⚠ spec-conformant, not user-verified | **Beta** |

**Static checks** = `bash -n` on shell scripts, `python3 -m json.tool` on JSON manifests, `tomllib.load()` on TOML, plus snapshot diffs (no leaked `{{INCLUDE: ...}}` placeholders). **Dry-run install** = `install.sh --target=<cli>` writes correct files into a temp dir and the layout matches each CLI's expected destination. **Live** = installed in the real CLI, hooks fire on real sessions, subagents dispatch correctly. **Beta** means the adapter follows each CLI's published spec but real-world testing on those CLIs is still pending.

Help close the gap — install on Codex / Gemini and report at [issues/](https://github.com/nuttaruj/rolepod/issues).

---

## Architecture

Three layers of guidance loaded by different mechanisms:

```
Tier 1 (always loaded)        entry doc core            ~225 lines
Tier 2 (Read on trigger)      rules/                    16 files
Tier 3 (auto-pull on match)   skills/                   27 ships + plugin skills
```

Plus: hooks (auto-fire), agents (sub-process), commands (slash /).

### Tier 1 — Always-on core (entry doc)

Workflow gates that fire every task — Identity (any model = Lead), Verify-first, Q1-Q4 delegation, S1-S5 simplicity, T1-T5 testing, CI 3-phase, Hard stops.

Loaded from each CLI's native entry doc: `~/.claude/CLAUDE.md` (Claude Code), `~/.codex/AGENTS.md` (Codex CLI), `~/.gemini/GEMINI.md` (Gemini CLI).

### Tier 2 — Lazy-load workflow rules (`rules/`)

| File | Trigger |
|------|---------|
| `INDEX.md` | meta navigation |
| `agent-protocol.md` | shared by all 18 agents |
| `team-org.md` | agent picker + parallel pattern |
| `triage-deep.md` | task >5 files / multi-agent |
| `pre-merge-gate.md` | about to `gh pr merge` |
| `reviewer-flow.md` | spawning reviewer (Codex/Gemini/qa-tester) |
| `testing.md` | test plan / CI lanes |
| `verify-first.md` | claiming a fact |
| `verification.md` | post-change evidence |
| `code-intel.md` / `code-intel-workflow.md` | tools (GitNexus/MemPalace/CLI) |
| `code-quality.md` | edit pattern / style |
| `communication.md` | tone / language |
| `session-management.md` | `/clear` / `/rewind` / `/compact` |
| `advisor.md` | stuck (Sonnet/Haiku Lead) |
| `new-project.md` | first-time / `/init` |

### Tier 3 — Auto-pull skills

Ships 27 skills covering anti-spaghetti, TDD, debugging, frontend UI, security, performance, design, marketing/copy, docs, planning, ops, etc. (`zoom-out` for meta-cognitive recovery + 26 domain skills authored fresh for rolepod). Plus integrates with external skill plugins (caveman, gitnexus, ui-ux-pro-max-skill) for additional coverage. Auto-discovery via `using-agent-skills` meta-skill at SessionStart. See [Skill dependencies](#skill-dependencies).

Each CLI exposes skills as a real directory tree under its own plugin/extension dir, so agents in any CLI can pull them by name.

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

Each agent has clear path/concern ownership, expertise list, escalation paths, skill preloads, and references shared `agent-protocol.md`. Path-based ownership applies identically across all 3 CLIs.

### Hooks — `hooks/` (auto-fire)

Ships 4 hook scripts: `project-context-loader.sh` (session start — git context), `context-awareness.sh` (before tool — context fill warning), `verify-reminder.sh` (after edit — verify reminder), `post-ship-detect.sh` (after bash — reindex suggestion after big merges).

Each CLI fires them on its own native event system:

| Event class | Claude Code | Codex CLI | Gemini CLI |
|---|---|---|---|
| Session start | `SessionStart` | `SessionStart` | `SessionStart` |
| Before tool run | `PreToolUse` | `PreToolUse` | `BeforeTool` |
| After tool run | `PostToolUse` | `PostToolUse` | `AfterTool` |

Claude and Codex share the same 4 scripts; Gemini ships 3 scripts adapted to its tool names and JSON envelope. External hooks integrate via separate plugins: MemPalace (Stop/SessionStart/PreCompact), GitNexus (PreToolUse/PostToolUse), `qa-pass-check.sh` (blocks merges without qa-tester gate).

### Commands

| CLI | Slash commands shipped |
|-----|------------------------|
| Claude Code | `/careful` (custom) + Anthropic native (`/init`, `/review`, `/clear`, `/rewind`, `/compact`, `/btw`) + plugin slash commands inherited from openai-codex when installed |
| Codex CLI | n/a (commands not in current Codex schema; gates fire via hooks + entry doc) |
| Gemini CLI | 6 native commands shipped as `commands/*.toml` (e.g. `/careful`, `/ship`, `/review`, `/test`, `/plan`, `/spec`) |

### Plugin manifest

| CLI | Manifest file | Schema |
|-----|---------------|--------|
| Claude Code | `.claude-plugin/plugin.json` | spec-conformant, 598B |
| Codex CLI | `.codex-plugin/plugin.json` | mirrors caveman schema, 1.6KB |
| Gemini CLI | `gemini-extension.json` | extension schema, 551B |

---

## Active gates (always-on enforcement)

| Gate | When | What |
|------|------|------|
| **Q1-Q4** | before any code edit | files>1 / verify-run / design / tools>3 → delegate |
| **S1-S5** | before commit | feature beyond / abstraction single-use / config nobody asked / defensive impossible / pattern in 3+ |
| **T1-T5** | before commit | task needs test / new pass / existing pass / fast / isolated |
| **CI 3-phase** | before merge | Phase 1 always / Phase 2 path-triggered / Phase 3 nightly |
| **Reviewer routing** | before merge | qa-tester floor + Codex/Gemini per PR profile |
| **Hard stops** | escalation triggers | 3rd agent / 3rd PR / file vs agent / destructive / 50k+ |
| **Verify-first** | every claim | confirm from primary source |

---

## Self-improvement loop

```
Session N
  ↓ Stop hook (or equivalent on each CLI)
  ↓ MemPalace KG saves session learnings (decisions / patterns / fixes)

Session N+1 (any time later, any project, any CLI)
  ↓ SessionStart hook
  ↓ MemPalace recall — relevant past decisions injected
  ↓ Lead starts task knowing past context
  ↓ Avoids re-deciding solved problems
  ↓ Stop hook captures more learnings

→ Each session smarter than the last
```

---

## Memory architecture — two coexisting systems

Rolepod uses two memory systems that work independently:

| System | Scope | How it works | Plugin? |
|--------|-------|--------------|---------|
| **Native agent memory** (`memory:` frontmatter) | per-agent, scoped `project` or `user` | Set in each agent's frontmatter. Claude Code parses the agent file directly — same loader path as `model:`, `tools:`, `skills:`. | No — works out-of-box on Claude Code |
| **MemPalace KG** | cross-session knowledge graph | Stop hook captures learnings → KG. SessionStart hook recalls. Powers the self-improvement loop above. Works across all 3 CLIs. | Yes — optional plugin |

In rolepod's 18 agents: 17 use `memory: project` (codepaths / patterns / decisions stay scoped to the repo), 1 uses `memory: user` (`business-analyst` — pricing / competitor research is reusable across projects). The `memory:` frontmatter is a Claude Code primitive; on Codex / Gemini the same scoping is achieved via per-agent TOML / inlined roster fields rendered by the adapter.

Without MemPalace installed: agents still have their native scoping. You just lose the cross-session KG decision recall and Stop-hook capture. The Q1-Q4 / S1-S5 / T1-T5 gates and reviewer flow are unaffected.

---

## Model + effort allocation

The 18 agents are tuned for cost vs quality — bigger models only where adversarial depth or cross-system judgment pays off:

| Tier | Count | Agents |
|------|-------|--------|
| **Opus xhigh** | 1 | security-engineer (adversarial depth) |
| **Opus high** | 1 | system-architect |
| **Sonnet high** | 5 | ai-ml-engineer, billing-engineer, performance-engineer, qa-tester, universal-reviewer |
| **Sonnet standard** | 7 | backend-developer, frontend-developer, mobile-developer, data-scientist, devops-sre, ui-ux-designer, product-manager |
| **Haiku** | 4 | business-analyst, customer-success, growth-marketer, tech-writer |

Estimated **~50-60% cost reduction** vs naive "all Opus high" while keeping depth where bugs are expensive (auth / billing / migrations / arch). Codex and Gemini adapters preserve the same tiering in their native model fields.

**Fallback escalation:** Lead spawns `qa-tester` and `universal-reviewer` with `model: opus` override when external reviewers are unavailable, when the PR touches high-risk surface (auth / billing / migrations), or when the user explicitly requests deep review. See `rules/reviewer-flow.md` for the full escalation matrix.

---

## Skill dependencies

This repo bundles 27 skills out-of-the-box. Agents preload them via frontmatter `skills:` field. Optional external plugins extend coverage — most plugins listed below are CLI-agnostic or have CLI-specific equivalents in each CLI's marketplace.

| Plugin / source | Provides | Install |
|----------------|----------|---------|
| **Bundled in this repo** (`skills/`) | 27 skills covering engineering / frontend / ops / docs / content (anti-spaghetti, TDD, debugging, security, performance, design, marketing, planning, etc.) | Auto-installed by `./install.sh` |
| **[JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)** | `caveman`, `caveman-commit`, `caveman-review`, `compress` | Per repo install |
| **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** | `gitnexus-*` (7 skills) + MCP impact/context/rename tools | `npm i -g gitnexus` + MCP setup (works on all 3 CLIs via MCP) |
| **[nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)** | `ui-ux-pro-max` (used by `ui-ux-designer` agent) | Per repo install |
| **[claude-seo](https://github.com/AgriciDaniel/claude-seo)** (optional) | 18 deep technical SEO sub-agents | Claude Code plugin marketplace |
| **OpenAI Codex review plugin** (optional) | Adversarial review skills | Each CLI's plugin marketplace where available |

Minimum baseline (core install only): 18 agents + 16 rules + 4 hooks + 27 bundled skills + Q1-Q4 / S1-S5 / T1-T5 gates.

Full workflow → also install GitNexus + caveman + ui-ux-pro-max-skill.

**Skills referenced by agent preloads.** The 18 agents reference **27 unique skill names** in their `skills:` frontmatter. The math:

- **26 ship in `skills/`** in this repo → auto-installed by `./install.sh` (any mode, any target).
- **1 (`ui-ux-pro-max`)** comes from the external `nextlevelbuilder/ui-ux-pro-max-skill` plugin → installed when you run `./install.sh --minimum` or `--full`. Without it, the `ui-ux-designer` agent simply won't preload that one skill.
- The repo also ships `zoom-out` (meta-cognitive recovery) which is **user-invoked**, not preloaded by any agent — so `skills/` total is 27 files, agent preloads reference 27 names, and they overlap on 26.

Drop unwanted preloads by editing `agents/<name>.md`'s `skills:` list.

---

## Optional integrations

| Tool | Purpose | Install |
|------|---------|---------|
| **[rtk](https://github.com/rtk-ai/rtk)** | Rust Token Killer — 60-90% CLI proxy savings on `git`/`npm`/`cargo`/etc. | `cargo install rtk` |
| **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** | Code intelligence — impact analysis, symbol context, graph-aware rename | `npm i -g gitnexus`, then `npx gitnexus analyze` per repo |
| **[MemPalace](https://github.com/mempalace/mempalace)** | Cross-session memory KG — drives the self-improvement loop | `pip install mempalace`, then `mempalace init` |

Without external reviewers → `qa-tester` is universal floor + auto-fallback. Without GitNexus → `rg` + Read fallback. Without MemPalace → no cross-session memory; rules still work.

---

## Usage examples

### New project (first time)

```bash
cd /your/new/project
claude   # or: codex, or: gemini
```

Auto-detects: git repo + recent commits, project type (next.config / pyproject.toml / etc.), past sessions (MemPalace recall, empty if first time). Bootstrap mode active until first session captured. Works the same in any of the 3 CLIs.

### Bug fix

```
User: fix the login bug where session expires too early
Lead: [Q1-Q4 check] → delegate to qa-tester for reproducing test
qa-tester: writes failing test → returns to Lead
Lead: [verify-first] → reads auth files → finds root cause
Lead: edits → verify-reminder hook fires → run test → green
Lead: [S1-S5 + T1-T5 gates] → all green
Lead: [pre-merge-gate] → routing: hotfix → qa-tester only → APPROVED
Lead: commit + push
```

Same flow runs in Codex / Gemini — Lead orchestrates one agent at a time on Codex (no parallel-fanout primitive yet) and via the inlined roster on Gemini, but the gates and routing are identical.

### New feature (parallel team)

```
User: add Google OAuth to login
Lead: [interview] → SPEC.md
Lead: spawns parallel:
  - product-manager (user stories)
  - system-architect (tech design)
After architecture done, parallel engineering:
  - backend-developer (auth endpoint)
  - frontend-developer (OAuth flow UI)
  - ui-ux-designer (button + flow polish)
After engineering, parallel quality:
  - qa-tester (integration tests)
  - security-engineer (token storage audit)
  - performance-engineer (auth perf check)
Reviewer flow → ship → CI auto-merge after green
```

On Claude Code the parallel fanout uses native `Task` / `SendMessage`. On Codex / Gemini, Lead serializes the same set via each CLI's native subagent dispatch (Codex `agents/*.toml`, Gemini inlined roster) — same agents, same hand-offs, sequential instead of fully parallel until those CLIs add fanout primitives.

---

## Design principles

1. **Identity-agnostic** — any model (Opus / Sonnet / Haiku) = Lead with same role
2. **CLI-agnostic** — Claude Code / Codex CLI / Gemini CLI all first-class targets
3. **Verify-first** — never claim without primary source verification
4. **Active gates** — workflow checkpoints, not passive guidance
5. **Anti-bloat** — gates have concrete questions, files stay short
6. **Anti-spaghetti** — same pattern in 3+ places → centralize
7. **Universal** — zero project-specific refs (works any project)
8. **Parallel-safe** — path / concern / artifact ownership prevents collision
9. **Self-improving** — every session feeds the next via MemPalace KG
10. **Graceful degradation** — works without MemPalace / GitNexus / external AIs (just less powerful)
11. **Small-model friendly** — every rule has concrete trigger; no fuzzy "judgment calls"

---

## Credits

**Supported platforms:** Anthropic Claude Code ([code.claude.com](https://code.claude.com)) · OpenAI Codex CLI · [Google Gemini CLI](https://github.com/google-gemini/gemini-cli) — all first-class adapter targets.

**Patterns:** [mattpocock/skills](https://github.com/mattpocock/skills) (skill patterns + zoom-out) · [AgriciDaniel/claude-seo](https://github.com/AgriciDaniel/claude-seo) (specialized agent plugin pattern).

**External tools:** [rtk](https://github.com/rtk-ai/rtk) (CLI token optimization) · [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) (compression mode) · [GitNexus](https://github.com/abhigyanpatwari/GitNexus) (code intelligence) · [MemPalace](https://github.com/mempalace/mempalace) (cross-session memory + KG) · [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) (`ui-ux-pro-max` skill) · OpenAI Codex review plugin (adversarial review).

---

## License

MIT — see `LICENSE`.

## Contributing

Personal workflow system. Fork freely. Adapt to your team. Send feedback / patterns via issues — especially Codex / Gemini runtime reports.

## See also

- `docs/cli-support.md` — full per-CLI capability matrix + per-CLI primitives
- `CHEATSHEET.md` — 1-page quick reference
- `rules/INDEX.md` — full rule trigger map
- `rules/team-org.md` — agent picker + parallel pattern
- `rules/agent-protocol.md` — shared subagent rules
- `.claude-plugin/plugin.json` / `.codex-plugin/plugin.json` / `gemini-extension.json` — per-CLI plugin manifests
