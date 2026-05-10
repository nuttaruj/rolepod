# Rolepod — Claude Code Workflow System

A complete software-house team for Claude Code: 18 specialist agents, 16 lazy-load workflow rules, auto-trigger hooks, MemPalace + GitNexus integration, 3-phase CI lanes, parallel-safe by path/concern ownership.

**Universal:** zero project-specific refs, works in any repo from day one.

---

## What this is

A workflow system that turns Claude Code into a coordinated software-house team. Instead of one Lead doing everything, 18 specialists handle different domains in parallel — backend, frontend, QA, security, performance, design, docs, ops — with explicit gates, ownership boundaries, and hand-off protocols.

The system is **self-improving** — every session captures learnings via MemPalace KG, so the next session starts smarter.

---

## Architecture

Three layers of guidance loaded by different mechanisms:

```
Tier 1 (always loaded)        CLAUDE.md core            ~225 lines
Tier 2 (Read on trigger)      rules/                    16 files
Tier 3 (auto-pull on match)   skills/                   1 ships (`zoom-out`) + plugin skills (see Skill dependencies)

Plus: hooks (auto-fire), agents (sub-process), commands (slash /)
```

### Tier 1 — Always-on core (`~/.claude/CLAUDE.md`)

Workflow gates that fire every task:
- Identity (any model = Lead — Opus / Sonnet / Haiku same role)
- Verify-first (NO guessing — verify from primary source)
- Q1-Q4 delegation checklist
- S1-S5 simplicity gate (pre-commit)
- T1-T5 test gate (pre-commit)
- CI 3-phase model (Phase 1 always / Phase 2 path-triggered / Phase 3 nightly)
- Hard stops (3rd agent / 50k tokens / destructive)

### Tier 2 — Lazy-load workflow rules (`~/.claude/rules/`)

| File | Trigger |
|------|---------|
| `INDEX.md` | meta navigation |
| `agent-protocol.md` | shared by all 18 agents |
| `team-org.md` | agent picker + parallel pattern |
| `triage-deep.md` | task >5 files / multi-agent / scope unclear |
| `pre-merge-gate.md` | about to `gh pr merge` |
| `reviewer-flow.md` | spawning reviewer (Codex/Gemini/qa-tester) |
| `testing.md` | test plan / CI lanes question |
| `verify-first.md` | claiming a fact |
| `verification.md` | post-change evidence |
| `code-intel.md` | tools (GitNexus/MemPalace/CLI) |
| `code-intel-workflow.md` | workflow stage map |
| `code-quality.md` | edit pattern / style |
| `communication.md` | tone / language |
| `session-management.md` | `/clear` / `/rewind` / `/compact` |
| `advisor.md` | stuck (Sonnet/Haiku Lead) |
| `new-project.md` | first-time / `/init` |

### Tier 3 — Auto-pull skills

This repo **ships 1 custom skill** (`zoom-out` — meta-cognitive recovery) and is designed to integrate with **external skill plugins** (Anthropic skills, mattpocock/skills, GitNexus plugin, caveman, etc.) for the full workflow surface (~30+ skills covering anti-spaghetti, TDD, debugging, frontend UI, security, performance, GitNexus, Claude API, design, marketing, etc.).

Auto-discovery via meta-skill `using-agent-skills` loaded at SessionStart. Install plugins separately — see [Skill dependencies](#skill-dependencies) below.

### Agents — `~/.claude/agents/` (18 specialists)

Organized in 7 layers, parallel-safe by path/concern ownership:

| Layer | Agents |
|-------|--------|
| **Strategy (4 parallel)** | product-manager, business-analyst, growth-marketer, customer-success |
| **Architecture (1)** | system-architect |
| **Engineering (6 parallel by path)** | backend-developer, frontend-developer, mobile-developer, billing-engineer, ai-ml-engineer, data-scientist |
| **Quality (3 parallel by concern)** | qa-tester, security-engineer, performance-engineer |
| **Operations (1)** | devops-sre |
| **Design + Docs (2 parallel)** | ui-ux-designer, tech-writer |
| **Code Review (1)** | universal-reviewer |

Each agent has:
- Clear path / concern ownership (no overlap)
- Domain expertise list
- Escalation paths
- Skill preload references
- Reference to shared `agent-protocol.md`

### Hooks — `~/.claude/hooks/` (auto-fire)

| Event | Hook | Purpose |
|-------|------|---------|
| SessionStart | `mempalace hook run --hook session-start` | recall past decisions for project |
| SessionStart | `project-context-loader.sh` | inject git log + hot files + branch state |
| PreToolUse Edit/Write/Bash | `context-awareness.sh` | warn when context filling |
| PreToolUse Bash | `qa-pass-check.sh` | block `gh pr merge` without qa-tester gate |
| PreToolUse Grep/Glob/Bash | `gitnexus-hook.cjs` | enrich query with graph context |
| PostToolUse Edit/Write | `verify-reminder.sh` | remind to verify after edit |
| PostToolUse Bash | `gitnexus-hook.cjs` | check index freshness |
| PostToolUse Bash (ship cmds) | `post-ship-detect.sh` | suggest reindex after big merge |
| Stop | `mempalace hook run --hook stop` | capture learnings → KG (self-improvement) |
| PreCompact | `mempalace hook run --hook precompact` | save state before compaction |

### Commands — `~/.claude/commands/`

Custom slash commands:
- `/careful` — toggle careful mode (high-risk surface protocol)
- `/build`, `/plan`, `/spec`, `/review`, `/test`, `/ship`, `/code-simplify` (project-specific)

Plus Anthropic native: `/init`, `/review`, `/security-review`, `/clear`, `/rewind`, `/compact`, `/btw`.

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
| **Mid-implement** | M1-M4 | scope creep detection |

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

## Token optimization

Multiple layers active by default:

### CLI / output
- **[rtk](https://github.com/rtk-ai/rtk)** (Rust Token Killer) — token-optimized CLI proxy. 60-90% savings on dev operations (`git`, `npm`, `cargo`, etc.). Auto-rewrites via hook. **Highly recommended** — install separately:
  ```bash
  cargo install rtk
  # or per repo instructions at https://github.com/rtk-ai/rtk
  ```
- **[caveman](https://github.com/JuliusBrussee/caveman)** mode — compress chat output ~75% while preserving technical accuracy. Skill by JuliusBrussee/caveman. Activate with `/caveman` or set as default.
- **`/btw`** — side question that doesn't enter conversation history.

### Context architecture
- Lazy-load rules (Read only when trigger fires)
- Skill auto-pull (loaded only when description matches)
- Subagent isolation (separate context window)
- Plugin namespacing (modular load)
- Agent protocol shared file (no duplicate per agent — saved ~480 lines)

### Session ops
- `/clear` between unrelated tasks
- `/rewind` (Esc Esc) restore checkpoint
- `/compact <focus>` manual compaction
- `claude --continue` / `--resume` resume without re-context

### Auto-compress
- MemPalace `Stop` hook compresses learnings → KG
- MemPalace `PreCompact` hook saves state pre-auto-compact
- `context-awareness.sh` hook warns at high context

### API-level
- `claude-api` skill — prompt caching guidance (90% saving on cached prefix)
- `context-engineering` skill — context optimization patterns

---

## Multi-AI review (optional)

By default, code review uses **Claude qa-tester** (universal floor). For deeper / multi-perspective review, install these external integrations:

### Codex (OpenAI) — for adversarial / depth review

Install [openai-codex plugin](https://docs.claude.com/) for:
- `/codex:review` — code review by GPT
- `/codex:adversarial-review` — high-risk surface (auth/billing/migrations) attacker-mindset audit

**When to use:** Touching auth / billing / payments / migrations / locks / external integrations.

### Gemini CLI — for breadth / cross-file review

Install [Gemini CLI](https://github.com/google-gemini/gemini-cli):

```bash
brew install gemini  # or platform equivalent
gemini auth login
```

Lead invokes via Bash:
```bash
gemini -m pro -o text -p "<prompt>" > /tmp/gemini-$(date +%s).txt 2> /tmp/gemini-$(date +%s).err
```

**When to use:** 5-30 file refactor / UI changes / cross-file consistency check.

### Without external AIs

System works fully without Codex / Gemini — `qa-tester` is universal floor + fallback. Reviewer flow auto-degrades to qa-tester when external reviewers unavailable.

---

## GitNexus + MemPalace integration

Optional but highly recommended for full power:

### [GitNexus](https://github.com/abhigyanpatwari/GitNexus) — code intelligence

Install per repo instructions: https://github.com/abhigyanpatwari/GitNexus

Then in your project:
```bash
cd /your/project
npx gitnexus analyze
```

Adds tools for impact analysis, symbol context, refactor safety:
- `gitnexus_impact({target, direction:"upstream"})` — blast radius before edit
- `gitnexus_context({name})` — full symbol context
- `gitnexus_detect_changes()` — pre-commit scope verify
- `gitnexus_rename` — graph-aware rename

Without GitNexus → fallback to `rg` + Read.

### [MemPalace](https://github.com/mempalace/mempalace) — cross-session memory

Install per repo instructions: https://github.com/mempalace/mempalace

```bash
pip install mempalace
mempalace init
```

Adds knowledge graph for past decisions, cross-session memory. Self-improvement loop depends on this.

Without MemPalace → no cross-session memory; rules still work.

---

## Specialized plugins (project-specific)

### [claude-seo](https://github.com/AgriciDaniel/claude-seo) — deep technical SEO

For projects with heavy SEO requirements. Adds 18 SEO sub-agents (technical / schema / Google APIs / local / maps / etc.). `growth-marketer` agent delegates technical SEO work to these sub-agents.

Install only if project needs deep technical SEO beyond `growth-marketer`'s general SEO scope.

---

## Installation

### Quick start (existing Claude Code)

1. Clone or copy `~/.claude/` files into your home directory
2. Restart Claude Code
3. Hooks register automatically via `~/.claude/settings.json`
4. Skills auto-discover via `using-agent-skills` meta-skill at SessionStart

### Plugin install (when packaged)

```bash
# Future:
claude plugin install rolepod
```

### Manual structure

```
~/.claude/
├── CLAUDE.md                    # always loaded core
├── CHEATSHEET.md                # 1-page reference
├── README.md                    # this file
├── settings.json                # hook registration
├── .claude-plugin/manifest.json # plugin metadata
├── rules/                       # 16 lazy-load files
├── agents/                      # 18 specialists
├── skills/                      # 1 ships (zoom-out) + external plugin skills
├── commands/                    # slash commands
└── hooks/                       # auto-fire scripts
```

### Skill dependencies

This repo is a **workflow framework** (gates + agents + rules + hooks), not a skill bundle. The full workflow assumes you also install external skill plugins. Without them, agents/rules still work — but skill auto-pull (Tier 3) returns fewer matches.

CHEATSHEET's skill picker references skills like `debugging-and-error-recovery`, `test-driven-development`, `webapp-testing`, `frontend-ui-engineering`, `security-and-hardening`, `gitnexus-*`, `claude-api`, `caveman`, etc. These ship from separate plugins:

| Plugin / source | Provides | Install |
|----------------|----------|---------|
| **Anthropic skills** (built-in or plugin marketplace) | `debugging-*`, `test-driven-development`, `frontend-ui-engineering`, `security-and-hardening`, `code-review-and-quality`, `webapp-testing`, etc. | Bundled in recent Claude Code or via `/plugin install` |
| **[mattpocock/skills](https://github.com/mattpocock/skills)** | Skill patterns + meta utilities | Clone into `~/.claude/skills/` |
| **[JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)** | `caveman`, `caveman-commit`, `caveman-review`, `compress` | Per repo install |
| **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** | `gitnexus-exploring`, `gitnexus-impact-analysis`, `gitnexus-debugging`, `gitnexus-refactoring`, `gitnexus-pr-review`, `gitnexus-cli`, `gitnexus-guide` | `npm i -g gitnexus` + MCP setup |
| **[nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)** | `ui-ux-pro-max` (50+ styles, 161 palettes, 161 product types, UX guidelines) | Per repo install |
| **[claude-seo](https://github.com/AgriciDaniel/claude-seo)** (optional) | Deep technical SEO sub-agents | `/plugin install AgriciDaniel/claude-seo` |
| **OpenAI Codex plugin** (optional) | Adversarial review skills | Plugin marketplace |

Minimum baseline (works without any plugin): 18 agents + 16 rules + 4 hooks + `zoom-out` skill + Q1-Q4 / S1-S5 / T1-T5 gates.

Want full workflow → install Anthropic skills + GitNexus + caveman at minimum.

#### Skills referenced by agent preloads

The 18 agents preload 28 skills via their frontmatter `skills:` field. Skill missing = agent still runs, just no auto-pull for that skill. Full list grouped by source:

**Anthropic skills (26)** — `anti-spaghetti`, `api-and-interface-design`, `browser-testing-with-devtools`, `ci-cd-and-automation`, `claude-api`, `code-review-and-quality`, `code-simplification`, `context-engineering`, `conversion-copywriting`, `debugging-and-error-recovery`, `doc-coauthoring`, `documentation-and-adrs`, `frontend-ui-engineering`, `interaction-design`, `interface-design`, `internal-comms`, `performance-optimization`, `planning-and-task-breakdown`, `security-and-hardening`, `seo`, `shipping-and-launch`, `spec-driven-development`, `test-driven-development`, `user-facing-content`, `web-design-guidelines`, `webapp-testing`

**Other plugins (1)** — `ui-ux-pro-max` from [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) (used by `ui-ux-designer` agent — install separately or remove from agent frontmatter if not desired)

Drop a skill from agent preload? Edit the agent's `skills:` list in `agents/<name>.md`. Agents work fine without preloaded skills (they can still auto-pull on description match if installed).

---

## Usage examples

### New project (first time)

```bash
cd /your/new/project
claude
```

System auto-detects:
- Git repo + recent commits (project-context-loader hook)
- Project type (next.config / pyproject.toml / etc.)
- Past sessions (MemPalace recall, empty if first time)

Bootstrap mode active until you run `npx gitnexus analyze` + first session captured.

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
Lead: spawns in parallel:
  - product-manager (user stories)
  - system-architect (tech design)
After architecture done, Lead spawns engineering parallel:
  - backend-developer (auth endpoint)
  - frontend-developer (OAuth flow UI)
  - ui-ux-designer (button + flow polish)
After engineering, parallel quality:
  - qa-tester (integration tests)
  - security-engineer (token storage audit)
  - performance-engineer (auth perf check)
Reviewer flow → ship → CI auto-merge after green
```

### Stuck (Sonnet/Haiku Lead)

```
Lead: [tries solution X — fails]
Lead: [tries solution Y — fails]
Lead: [3rd agent triggered → escalation path]
Lead: 1. Fresh angle
      2. MemPalace kg_query (past similar?)
      3. Specialist subagent
      4. Advisor (Opus) — consult bigger model
      5. Hard stop — ask user
```

---

## Credits

This system synthesizes patterns from many great open-source projects:

### Core patterns
- **Anthropic Claude Code** — base platform + best practices ([code.claude.com](https://code.claude.com))
- **[mattpocock/skills](https://github.com/mattpocock/skills)** — skill patterns + zoom-out concept (68k stars)
- **[wshobson/agents](https://github.com/wshobson/agents)** — plugin packaging structure + agent orchestration patterns (35k stars)
- **[AgriciDaniel/claude-seo](https://github.com/AgriciDaniel/claude-seo)** — specialized agent plugin pattern (6.2k stars)

### External tools
- **[rtk](https://github.com/rtk-ai/rtk)** (Rust Token Killer) — CLI token optimization
- **[JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)** — caveman compression mode (chat output ~75% reduction)
- **[Gemini CLI](https://github.com/google-gemini/gemini-cli)** — Google AI CLI
- **[OpenAI Codex plugin](https://docs.claude.com/)** — adversarial code review
- **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** — code intelligence (impact / context / rename)
- **[MemPalace](https://github.com/mempalace/mempalace)** — cross-session memory + KG
- **[nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)** — `ui-ux-pro-max` skill (used by `ui-ux-designer` agent)

### Skills used (1 ships + plugin skills)
This repo ships only `zoom-out`. Other skills referenced in rules and `CHEATSHEET.md` skill picker come from external plugins — install separately (see [Skill dependencies](#skill-dependencies)).

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

## License

MIT

---

## Contributing

This is a personal workflow system. Fork freely. Adapt to your team. Send feedback / patterns via issues.

---

## See also

- `CHEATSHEET.md` — 1-page quick reference
- `CLAUDE.md` — core workflow rules (always loaded)
- `rules/INDEX.md` — full rule trigger map
- `rules/team-org.md` — agent picker + parallel pattern
- `rules/agent-protocol.md` — shared subagent rules
- `.claude-plugin/manifest.json` — plugin metadata
