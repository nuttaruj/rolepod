# Rolepod — Claude Code Workflow System

A complete software-house team for Claude Code: 18 specialist agents, 16 lazy-load workflow rules, auto-trigger hooks, parallel-safe by path/concern ownership.

**Universal:** zero project-specific refs, works in any repo from day one.

---

## What this is

Turns Claude Code into a coordinated software-house team. Instead of one Lead doing everything, 18 specialists handle different domains in parallel — backend, frontend, QA, security, performance, design, docs, ops — with explicit gates, ownership boundaries, and hand-off protocols.

Self-improving: every session captures learnings via MemPalace KG, so the next session starts smarter (when MemPalace is installed; works without it too).

---

## Quick start

### Pick a mode

| Mode | What gets installed | Command |
|------|---------------------|---------|
| **core** (default) | rolepod files only — agents, rules, hooks, 27 bundled skills, `/careful` command, manifest, docs | `./install.sh` |
| **minimum** | core + `ui-ux-pro-max-skill` + GitNexus + MemPalace (final skill + cross-session memory + code intelligence) | `./install.sh --minimum` |
| **full** | minimum + caveman + rtk + Codex CLI + Gemini CLI + openai-codex Claude Code plugin | `./install.sh --full` |

Add `--force` to overwrite existing `~/.claude/` files (auto-creates `~/.claude.backup-<timestamp>/`).

### Install commands

```bash
# Interactive — pops up a menu (mode + force prompt):
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash

# Or pass mode directly to skip the prompt:
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --minimum
curl -fsSL https://raw.githubusercontent.com/nuttaruj/rolepod/main/bootstrap.sh | bash -s -- --full --force

# Or fully manual:
git clone https://github.com/nuttaruj/rolepod
cd rolepod
./install.sh --minimum
```

Every plugin is detected before installing — already-installed ones are skipped (no duplicate work). Failed installs print a manual fallback command and continue (no abort). Final summary lists what was installed / skipped / needs manual install.

The 4 shipped hooks are auto-registered in `~/.claude/settings.json` (idempotent — re-running won't duplicate entries). In `--minimum`/`--full` mode, the installer also prompts at the end to run one-time setup commands when their tools are present: `mempalace init` (cross-session memory), `gemini auth login` (Gemini CLI auth), and a reminder to install the `openai-codex` plugin from inside Claude Code. Decline any prompt to skip — you can run them manually later.

After install, restart Claude Code so the hooks register.

---

## Architecture

Three layers of guidance loaded by different mechanisms:

```
Tier 1 (always loaded)        CLAUDE.md core            ~225 lines
Tier 2 (Read on trigger)      rules/                    16 files
Tier 3 (auto-pull on match)   skills/                   27 ships + plugin skills
```

Plus: hooks (auto-fire), agents (sub-process), commands (slash /).

### Tier 1 — Always-on core (`CLAUDE.md`)

Workflow gates that fire every task — Identity (any model = Lead), Verify-first, Q1-Q4 delegation, S1-S5 simplicity, T1-T5 testing, CI 3-phase, Hard stops.

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

Each agent has clear path/concern ownership, expertise list, escalation paths, skill preloads, and references shared `agent-protocol.md`.

### Hooks — `hooks/` (auto-fire)

Ships 4 hooks: `project-context-loader.sh` (SessionStart — git context), `context-awareness.sh` (PreToolUse — context fill warning), `verify-reminder.sh` (PostToolUse Edit — verify reminder), `post-ship-detect.sh` (PostToolUse Bash — reindex suggestion after big merges).

External hooks integrate via separate plugins: MemPalace (Stop/SessionStart/PreCompact), GitNexus (PreToolUse/PostToolUse), `qa-pass-check.sh` (blocks `gh pr merge` without qa-tester gate). See `.claude-plugin/manifest.json`.

### Commands — `commands/`

Custom: `/careful` (high-risk surface protocol). Plus Anthropic native (`/init`, `/review`, `/clear`, `/rewind`, `/compact`, `/btw`).

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
  ↓ Stop hook
  ↓ MemPalace KG saves session learnings (decisions / patterns / fixes)

Session N+1 (any time later, any project)
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
| **Native agent memory** (`memory:` frontmatter) | per-agent, scoped `project` or `user` | Set in each agent's frontmatter. Claude Code parses the agent file directly — same loader path as `model:`, `tools:`, `skills:`. | No — works out-of-box |
| **MemPalace KG** | cross-session knowledge graph | Stop hook captures learnings → KG. SessionStart hook recalls. Powers the self-improvement loop above. | Yes — optional plugin |

In rolepod's 18 agents: 17 use `memory: project` (codepaths / patterns / decisions stay scoped to the repo), 1 uses `memory: user` (`business-analyst` — pricing / competitor research is reusable across projects).

Without MemPalace installed: agents still have their native `memory:` scoping. You just lose the cross-session KG decision recall and Stop-hook capture. The Q1-Q4 / S1-S5 / T1-T5 gates and reviewer flow are unaffected.

> Note: `memory:` is part of Claude Code's agent frontmatter spec — it isn't surfaced in `claude agents --help`, but Claude Code reads it the same way it reads `model:` and `tools:`.

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

Estimated **~50-60% cost reduction** vs naive "all Opus high" while keeping depth where bugs are expensive (auth / billing / migrations / arch).

**Fallback escalation:** Lead spawns `qa-tester` and `universal-reviewer` with `model: opus` override when external reviewers (Codex / Gemini) are unavailable, when the PR touches high-risk surface (auth / billing / migrations), or when the user explicitly requests deep review. See `rules/reviewer-flow.md` for the full escalation matrix.

---

## Skill dependencies

This repo bundles 27 skills out-of-the-box. Agents preload them via frontmatter `skills:` field. Optional external plugins extend coverage.

| Plugin / source | Provides | Install |
|----------------|----------|---------|
| **Bundled in this repo** (`skills/`) | 27 skills covering engineering / frontend / ops / docs / content (anti-spaghetti, TDD, debugging, security, performance, design, marketing, planning, etc.) | Auto-installed by `./install.sh` |
| **[JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)** | `caveman`, `caveman-commit`, `caveman-review`, `compress` | Per repo install |
| **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** | `gitnexus-*` (7 skills) + MCP impact/context/rename tools | `npm i -g gitnexus` + MCP setup |
| **[nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)** | `ui-ux-pro-max` (used by `ui-ux-designer` agent) | Per repo install |
| **[claude-seo](https://github.com/AgriciDaniel/claude-seo)** (optional) | 18 deep technical SEO sub-agents | `/plugin install AgriciDaniel/claude-seo` |
| **OpenAI Codex plugin** (optional) | Adversarial review skills | Plugin marketplace |

Minimum baseline (core install only): 18 agents + 16 rules + 4 hooks + 27 bundled skills + Q1-Q4 / S1-S5 / T1-T5 gates.

Full workflow → also install GitNexus + caveman + ui-ux-pro-max-skill.

**Skills referenced by agent preloads.** The 18 agents reference **27 unique skill names** in their `skills:` frontmatter. The math:

- **26 ship in `skills/`** in this repo → auto-installed by `./install.sh` (any mode).
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
| **OpenAI Codex plugin** | Adversarial / depth review for high-risk surface (auth/billing/migrations) | Plugin marketplace |
| **[Gemini CLI](https://github.com/google-gemini/gemini-cli)** | Breadth / cross-file review for 5-30 file refactors / UI changes | `brew install gemini` + `gemini auth login` |

Without Codex / Gemini → `qa-tester` is universal floor + auto-fallback. Without GitNexus → `rg` + Read fallback. Without MemPalace → no cross-session memory; rules still work.

---

## Usage examples

### New project (first time)

```bash
cd /your/new/project
claude
```

Auto-detects: git repo + recent commits, project type (next.config / pyproject.toml / etc.), past sessions (MemPalace recall, empty if first time). Bootstrap mode active until first session captured.

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

---

## Design principles

1. **Identity-agnostic** — any model (Opus / Sonnet / Haiku) = Lead with same role
2. **Verify-first** — never claim without primary source verification
3. **Active gates** — workflow checkpoints, not passive guidance
4. **Anti-bloat** — gates have concrete questions, files stay short
5. **Anti-spaghetti** — same pattern in 3+ places → centralize
6. **Universal** — zero project-specific refs (works any project)
7. **Parallel-safe** — path / concern / artifact ownership prevents collision
8. **Self-improving** — every session feeds the next via MemPalace KG
9. **Graceful degradation** — works without MemPalace / GitNexus / external AIs (just less powerful)
10. **Small-model friendly** — every rule has concrete trigger; no fuzzy "judgment calls"

---

## Credits

### Core patterns
- **Anthropic Claude Code** — base platform + best practices ([code.claude.com](https://code.claude.com))
- **[mattpocock/skills](https://github.com/mattpocock/skills)** — skill patterns + zoom-out concept
- **[AgriciDaniel/claude-seo](https://github.com/AgriciDaniel/claude-seo)** — specialized agent plugin pattern

### External tools
- **[rtk](https://github.com/rtk-ai/rtk)** — CLI token optimization
- **[JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)** — caveman compression mode
- **[Gemini CLI](https://github.com/google-gemini/gemini-cli)** — Google AI CLI
- **OpenAI Codex plugin** — adversarial code review
- **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** — code intelligence
- **[MemPalace](https://github.com/mempalace/mempalace)** — cross-session memory + KG
- **[nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)** — `ui-ux-pro-max` skill

---

## Multi-CLI support

Rolepod currently ships first-class support for Claude Code. Phase 2.1 (this release) introduces a `core/` + `adapters/<cli>/` layout with a small `build/render.sh` step that assembles the per-CLI entry doc from shared fragments, so the same source-of-truth content can power other coding CLIs without prose duplication.

| CLI | Status | Install command |
|-----|--------|-----------------|
| Claude Code | Shipping (default) | `./install.sh --target=claude` (default if flag omitted) |
| Codex CLI (OpenAI) | Phase 2.2 — not yet implemented | will fail with a clear message |
| Gemini CLI (Google) | Phase 2.2 — not yet implemented | will fail with a clear message |

Phase 2.2 will add `adapters/codex/` + `adapters/gemini/` with their respective entry docs (`AGENTS.md`, `GEMINI.md`), wrapper scripts for opt-in rule reminders, and a per-CLI behavior matrix documenting which Claude-Code-only features (hooks, sub-agents, slash commands) gracefully degrade vs. ship as-is.

## License

MIT — see `LICENSE`.

## Contributing

Personal workflow system. Fork freely. Adapt to your team. Send feedback / patterns via issues.

## See also

- `CHEATSHEET.md` — 1-page quick reference
- `CLAUDE.md` — core workflow rules (always loaded)
- `rules/INDEX.md` — full rule trigger map
- `rules/team-org.md` — agent picker + parallel pattern
- `rules/agent-protocol.md` — shared subagent rules
- `.claude-plugin/manifest.json` — plugin metadata
