# Agent Teams — Lead-Orchestrated Recipes

> **Disambiguation.** Rolepod's "team workflow" / `/team-*` slash commands are a **single-session orchestration pattern**: Lead spawns specialist subagents via the Task tool, all coordinated inside one Claude Code session.
>
> Anthropic's experimental **agent-teams feature** (gated by `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, see [official doc](https://code.claude.com/docs/en/agent-teams)) is a **separate multi-process model** — each teammate is its own Claude Code instance with shared task list + mailbox. Different mechanism, different cost profile, different runtime state at `~/.claude/teams/{name}/config.json`.
>
> Both can coexist. Rolepod's pattern works in any Claude Code version + on Codex/Gemini (via default Subagent + Task pattern). Anthropic's experimental feature requires v2.1.32+ and env opt-in.

> **Claude Code only.** Codex CLI and Gemini CLI Leads use the default Subagent + Task pattern. The `team-trigger` rule fragment and `/team-*` slash commands are deliberately NOT shipped into Codex `AGENTS.md` or Gemini `GEMINI.md` — those CLIs don't have a slash-command schema that maps cleanly, and surfacing Claude-specific instructions there would confuse the agent.

Power-user pattern for multi-phase, multi-agent work. Opt-in. Default rolepod behavior (Subagent + Task spawn) is unchanged.

## Caveat — Anthropic agent-teams compatibility

Rolepod's subagent definitions (`core/agents/*.md`) can be used as teammate types in Anthropic's experimental agent-teams. However, per the official doc:

> "The `skills` and `mcpServers` frontmatter fields in a subagent definition are not applied when that definition runs as a teammate."

Rolepod adds `skills:` preload to specialist agents (e.g. `qa-tester` preloads `reviewer-flow`, `post-change-verify`, etc.). When invoked as a regular subagent via Task tool, these load. **When invoked as an Anthropic agent-teams teammate, they will NOT load** — the teammate falls back to project/user-level skill resolution. Plan accordingly if you're combining both patterns.

Reference: https://code.claude.com/docs/en/agent-teams

## Two opt-in patterns

Team mode has two distinct invocation shapes. Pick based on whether you want team coordination across the whole lifecycle or just one phase.

### Pattern A — Full-lifecycle team

Explicit slash command `/team-all` → Lead runs every phase via team recipes.
For: end-to-end max effort on big features.

```
User: /team-all "Add Stripe billing — high-risk"
Lead: define → plan → build → verify → review → ship
      All 6 phases use multi-agent coordinated dispatch.
      CEO sees final result after Ship.
```

**Why `/team-all` and not plain "use team"?** Plain trigger phrases ("use team", "use the team", "run team workflow") proved unreliable — Lead routinely pattern-matched them as regular subagent dispatch and skipped team recipes. The slash command is `disable-model-invocation: true` so it can ONLY fire from explicit user invocation, eliminating drift.

### Pattern B — Surgical team

Slash command (`/team-<phase>`) → only that phase uses team.
For: focused intensity on one phase, default elsewhere.

```
User: /team-build "auth refactor across 30 files"
Lead orchestration:
  Define   → default Subagent (or skip if intent clear)
  Plan     → default Subagent (system-architect alone)
  Build    → /team-build recipe ★ multi-agent parallel via cohesion contract
  Verify   → default Subagent (qa-tester floor)
  Review   → default Subagent (universal-reviewer)
  Ship     → default Subagent (devops-sre)

Team mode active ONLY in Build phase. Lead returns to default Subagent for rest.
```

### Slash commands run individually

Each slash command processes one phase per input. Claude Code does not chain slash commands. After Lead finishes a phase, ask for the next:

```
User: /team-build "auth refactor"
Lead: [runs build phase] → "Build done. Next?"
User: /team-review                              # separate input
Lead: [runs review phase] → "Review done."
```

### Multi-phase surgical via natural language

For surgical opt-in on multiple specific phases in one go, use natural language:

```
User: "Auth refactor — use team for build and review, default for rest"
Lead detects intent → applies team mode to those 2 phases:
  Define   → default Subagent
  Plan     → default Subagent
  Build    → team recipe ★
  Verify   → default Subagent
  Review   → team recipe ★
  Ship     → default Subagent
```

Lead orchestrates per intent — no slash chaining required.

### Mandatory gates regardless of pattern

Both patterns enforce: T1-T6, S1-S5, F1-F5, pre-merge-gate, CI 3-phase.
Team mode ≠ gate skip. Same quality bar.

## Overview

Two orchestration patterns coexist:

| Pattern | When | How |
|---------|------|-----|
| **Subagent** (default) | Single-task delegation, ad-hoc | Lead spawns one Task per need (covers 80%+ of work) |
| **Team** (opt-in) | Big feature, multi-phase, high coordination | Lead runs a lifecycle recipe — spawns multiple agents per phase with cohesion contract |

Same 18 specialists. Different orchestration shape.

## Why Lead-orchestrated (no YAML pre-auth)

Anthropic's Agent Teams runtime manages team configuration schema in `~/.claude/teams/`. Rolepod does NOT pre-author those YAML files — they're Anthropic's domain. Instead rolepod ships:

- A trigger fragment (`team-trigger.md`) that teaches the Lead when + how to switch into team mode
- 6 slash commands (`/team-define` etc.) that load the relevant recipe
- A docs reference (this file) for power users

Lead reads the recipe, then spawns agents via the standard Task tool. Anthropic's runtime can layer YAML team configs on top whenever the user wants — rolepod stays out of the way.

## 6 lifecycle recipes

### `/team-define` — frame intent → spec

- Spawn: `product-manager` + `business-analyst` + `system-architect`
- Output: `SPEC.md`
- Gate focus: verify-first (intent verification)
- Use when: vague feature request, no spec yet

### `/team-plan` — spec → ordered tasks + cohesion contract

- Spawn: `system-architect` (contract + RED tests) + `product-manager` (task breakdown)
- Path joiners: `billing-engineer` / `ai-ml-engineer` / `security-engineer` / `data-scientist`
- Output: `contract.md` + RED tests + task list
- Gate focus: Q1-Q4 delegation
- Use when: SPEC.md exists, ready to break into work

### `/team-build` — tasks → code (parallel-safe by path)

- Spawn parallel: engineers by path
- Owner: `system-architect` (contract enforcer)
- Cycle: RED → GREEN → REFACTOR
- Gate focus: S1-S5 simplicity + F1-F5 failure-mode
- Use when: contract + RED tests ready, multiple paths touched

### `/team-verify` — code → evidence

- Spawn: `qa-tester` (always) + `security-engineer` (auth/billing) + `performance-engineer` (perf-sensitive)
- Output: test evidence + security report + perf delta
- Gate focus: T1-T6 testing, verify-first
- Use when: code merged from `/team-build`, need auditable evidence

### `/team-review` — evidence → adversarial pass

- Spawn: `universal-reviewer` + `qa-tester` (review-mode)
- Adversarial: `doubt-driven-development` cycle, bounded 3 rounds
- High-risk: escalate to Codex (and Gemini for >30 files)
- Gate focus: pre-merge-gate, hard stops
- Use when: evidence clean, need ship sign-off

### `/team-ship` — approved → deploy + announce

- Spawn: `devops-sre` + `tech-writer` + `growth-marketer` + `customer-success`
- Skip lanes that don't apply (internal-only → no marketer)
- Gate focus: CI 3-phase, auto-merge rule
- Use when: review green, ready to deploy

## Triggers

**Slash commands only** (Claude). Natural-language triggers were retired because Lead routinely pattern-matched them as regular subagent dispatch.

| Command | Scope |
|---|---|
| `/team-all` | All 6 phases (full lifecycle) |
| `/team-define` | Define phase only |
| `/team-plan` | Plan phase only |
| `/team-build` | Build phase only |
| `/team-verify` | Verify phase only |
| `/team-review` | Review phase only |
| `/team-ship` | Ship phase only |

All have `disable-model-invocation: true` so Lead can't auto-fire them — explicit user invocation required. For multi-phase surgical via natural language (e.g. "use team for build and review, default for rest"), see [Pattern C above](#multi-phase-surgical-via-natural-language).

## Composability

Inside any team phase, Lead can still spawn ad-hoc Subagents for narrow tasks. Example: during `/team-build`, an engineer hits a blocker → Lead spawns the `systematic-debugging` skill workflow as a standalone subagent, then resumes the team.

Mix is the default. Team is not a lock-in.

## Subagent vs. Team — quick comparison

| Concern | Subagent (default) | Team (opt-in) |
|---------|-------------------|----------------|
| Scope | One task | Whole lifecycle phase |
| Agents per spawn | 1 | 2-4 |
| Coordination | Lead reads result | Cohesion contract + integration tests |
| Phase awareness | Implicit | Explicit recipe |
| Output | Diff or report | Phase artifact (SPEC / contract / evidence / deploy) |
| Cost | Low | Higher (parallel agents) |
| Best for | <3-file fix, narrow investigation | Big feature, multi-system change |

## CEO interaction pattern

Lead is your team's CEO. CEO does NOT micromanage:
- Spawns the team per recipe
- Reviews final output (SPEC.md / contract / evidence / deploy report)
- Asks user only on ambiguity, hard stop, or destructive op

CEO interaction = one approval per phase (where required), not per agent spawn.

## Claude-specific notes

- **Experimental flag** (optional, if Anthropic's runtime requires it): set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your shell or `.envrc`. Rolepod does not require this flag — recipes work as Lead-orchestration even without it.
- **Version**: Claude Code 2.1.32+ recommended for native Agent Teams runtime support if/when Anthropic ships YAML team configs.
- **Slash commands** live in `~/.claude/commands/team-*.md` after `install.sh` runs.

## Codex / Gemini notes

Codex and Gemini get the `team-trigger.md` fragment in their entry docs (`AGENTS.md` / `GEMINI.md`) so the Lead knows the recipes exist. They do NOT get the 6 slash commands — those are Claude-only.

Lead under Codex / Gemini can still orchestrate equivalently:
- Read the recipe from the entry doc's "Team workflow trigger" section
- Spawn the same 18 agents via Codex's / Gemini's native dispatch
- Apply the same gates (S1-S5, T1-T6, Q1-Q4, F1-F5)

The orchestration logic is portable. Only the slash-command surface differs.

## When NOT to use Team

Default Subagent is the right call when:
- Single-file fix / typo / quick refactor
- Tasks needing <3 agents
- Independent investigations (qa OR security OR perf alone)
- Lead's Q1-Q4 already routes correctly
- Time-sensitive hotfix (recipe overhead > value)

Team trigger is opt-in for a reason — overhead pays off only when coordination is the bottleneck.
