# Agent Teams — Lead-Orchestrated Recipes

Power-user pattern for multi-phase, multi-agent work. Opt-in. Default rolepod behavior (Subagent + Task spawn) is unchanged.

Reference: https://code.claude.com/docs/en/agent-teams

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
- Gate focus: S1-S5 simplicity + F1-F6 failure-mode
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

Either form works:

**Natural language**
- "use team"
- "team workflow"
- "with team"
- "as a team"
- "big feature, team"
- "use teams"

**Slash commands** (Claude only)
- `/team-define`
- `/team-plan`
- `/team-build`
- `/team-verify`
- `/team-review`
- `/team-ship`

If trigger is vague ("use team") → Lead detects scope and starts at the matching phase (typically `/team-define`).

## Composability

Inside any team phase, Lead can still spawn ad-hoc Subagents for narrow tasks. Example: during `/team-build`, an engineer hits a blocker → Lead spawns the `root-cause-tracing` skill workflow as a standalone subagent, then resumes the team.

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
- Apply the same gates (S1-S5, T1-T6, Q1-Q4, F1-F6)

The orchestration logic is portable. Only the slash-command surface differs.

## When NOT to use Team

Default Subagent is the right call when:
- Single-file fix / typo / quick refactor
- Tasks needing <3 agents
- Independent investigations (qa OR security OR perf alone)
- Lead's Q1-Q4 already routes correctly
- Time-sensitive hotfix (recipe overhead > value)

Team trigger is opt-in for a reason — overhead pays off only when coordination is the bottleneck.
