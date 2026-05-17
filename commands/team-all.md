---
description: Spawn a Claude Code agent team (real multi-process teammates) to run the full 6-phase lifecycle in parallel. Requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 + Claude Code v2.1.32+. Claude-only — Codex/Gemini fall back to default subagent dispatch.
disable-model-invocation: true
---

# Team All — Claude Agent Team (Multi-Process)

You are entering the **real Claude Code agent-team workflow** — multi-process teammates with shared task list, mailbox messaging, and self-coordination. NOT subagent recipes.

This command spawns a Claude Code agent team per the [official spec](https://code.claude.com/docs/en/agent-teams). Each teammate runs as a separate Claude Code instance with its own context window. Teammates communicate directly with each other via mailbox; you can also message any teammate by name.

## Preconditions + graceful fallback

Check in order. The first failure determines the mode:

1. **Claude Code v2.1.32+** (`claude --version`):
   - Pass → continue to check 2
   - **Fail** → **fail-fast**: teammate API doesn't exist in this version. Ask user to upgrade Claude Code. No fallback (cohesion contract requires the multi-process API).

2. **`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`** (settings.json or env):
   - Pass → **TEAMMATE MODE** (continue to "Teammate spawn pattern" below)
   - Not set → **FALLBACK MODE** (continue to "Fallback spawn pattern" below). State briefly in first reply: "Teammate API disabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` not set). Running parallel work via Subagent + Task instead. To enable real teammates: add `"env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }` to settings.json."

3. **Running on Claude Code**: this command file only installs to `~/.claude/commands/`. Codex/Gemini never see `/team-all` — they use natural-language Subagent dispatch via `team-routing` skill. No fail-fast needed.

The point: smooth UX. User doesn't have to manage env flags — `/team-all` always does the most-parallel work the environment allows.

## Teammate spawn pattern (TEAMMATE MODE)

You (Lead) are the team lead. Spawn 3-5 teammates per the official guidance ("Start with 3-5 teammates for most workflows. Three focused teammates often outperform five scattered ones."). Use rolepod's phase taxonomy to inform teammate roles — but each teammate is a full independent Claude Code session, not a subagent.

### Recommended teammate composition (full lifecycle)

For a typical feature with cross-domain impact, spawn 4 teammates using rolepod subagent definitions:

```
Create an agent team for <user's feature description>.

Spawn these teammates:
1. system-architect — owns spec + cohesion contract + RED test list.
   Subagent definition: system-architect (~/.claude/agents/system-architect.md).
2. backend-developer (or path-appropriate engineer per team-routing skill) —
   owns server-side implementation.
   Subagent definition: backend-developer.
3. frontend-developer (if UI in scope) — owns client-side implementation.
   Subagent definition: frontend-developer.
4. qa-tester — owns evidence collection, integration tests, reviewer floor.
   Subagent definition: qa-tester.

Coordination:
- Teammates share the task list at ~/.claude/tasks/<team-name>/
- system-architect writes the cohesion contract FIRST; other teammates
  read it before implementing (no fan-out without contract — rolepod
  parallel-contract-orchestration skill).
- qa-tester runs after each teammate marks task complete, blocks
  promotion to "done" if evidence missing.
- For high-risk surface (auth/billing/migrations/crypto/payments),
  ADDITIONALLY ask teammates to consult Codex + Gemini via Bash
  (`codex exec` / `gemini -m pro -p`) — the reviewer-flow skill rule
  still applies inside teammate sessions.

Wait for all teammates to finish before synthesizing.
```

### Adjust composition per task

- Pure research / debugging: 3 teammates each investigating a different hypothesis (per official "investigate with competing hypotheses" pattern).
- Code review: 3 teammates each with a different lens (security / performance / test coverage).
- Refactor across modules: 1 teammate per module + 1 orchestrator.
- Drop teammates that don't have a clear independent unit of work.

## Fallback spawn pattern (FALLBACK MODE — env flag not set)

Lead orchestrates parallel work using Subagent + Task tool in a single session — same outcome shape (parallel work, contract-coordinated), different mechanism (single-process, no inter-teammate messaging, Lead synthesizes).

### Recipe

1. **Write cohesion contract first** (skill `parallel-contract-orchestration`). One shared file at `docs/specs/<feature>-contract.md` (or `SPEC.md` if simpler). Covers: shared types, invariants, integration points, per-agent path ownership.

2. **Spawn parallel Subagents via Task tool** — one per independent unit, pick agent type via `team-routing` skill:
   - system-architect → owns spec + contract authoring (if not already done)
   - backend-developer / frontend-developer / etc. → per path ownership
   - qa-tester → owns evidence collection (runs after engineers finish)

3. **Each Subagent reads contract before edits.** Hook `cohesion-contract-check.sh` enforces — blocks 2nd+ Agent spawn within 10 events if no contract file written.

4. **For high-risk surface**, also dispatch external adversarial review (skill `reviewer-flow`):
   - `codex exec --skip-git-repo-check '<prompt>'` if Codex on PATH
   - `gemini -m pro -p '<prompt>'` if Gemini on PATH
   - Both if both installed (the documented drift; rolepod rule).

5. **Synthesize results in Lead context** — Subagents report back, Lead reviews, commits when all green (sub-agent commit ban — hook `block-subagent-commit.sh`).

### Difference from teammate mode

| Aspect | Teammate mode | Fallback mode |
|---|---|---|
| Process | N separate Claude instances | 1 Lead process, N subagent contexts |
| Inter-agent talk | Direct mailbox messaging | None — Lead is the bus |
| Context | Each teammate fully independent | Each subagent forked, results return to Lead |
| Token cost | ~4× Lead alone | ~Lead + subagent context per Task call |
| Resume | Broken (upstream limit) | Works |
| Real parallelism | Yes | No (sequential Task calls, but each in own context) |

Fallback is good enough for most rolepod work — the cohesion contract + reviewer-flow rules still hold. Real teammate mode is a token-budget premium for genuinely-parallel exploration / debate.

## Rolepod gates still apply (inside each teammate or subagent)

Each teammate is a full Claude Code session with CLAUDE.md + skills loaded — meaning all rolepod gates (S1-S5, T1-T6, F1-F5, verify-first, etc.) fire inside each teammate. The team-lead's job is coordination, not gate enforcement.

Hooks that fire inside teammates:
- `block-subagent-commit.sh` — teammates can NOT `git commit` directly (rolepod hard rule).
- `gate-reminder.sh` + `precommit-gate.sh` — fire as normal on teammate edits.
- `cohesion-contract-check.sh` — fires if a teammate tries to spawn an Agent (Task tool) without a contract; rare in team context since teammates are already independent.
- `session-lock.sh` — disabled inside the same worktree; team lead's worktree is shared with teammates.

## Coordination + cleanup

Per official docs:
- Lead's terminal lists all teammates + their status.
- Shift+Down to cycle through teammates in-process mode.
- Plan approval: for high-risk teammates, require `Require plan approval before they make any changes`.
- Cleanup: when done, ask Lead "Clean up the team". Shut down teammates first, then cleanup. Always cleanup via Lead (never teammates — known docs caveat).

## Cost note

Per official docs: "Token costs scale linearly — each teammate has its own context window." A 4-teammate team ≈ 4× single-session tokens for the duration of the team. Use `/team-all` for genuinely parallel work — for sequential or trivial tasks, default Subagent + Task is more cost-effective.

## Pairs with

- `team-routing` skill — pick which subagent definition each teammate should use (e.g. backend-developer for `src/api/`, frontend-developer for `src/ui/`).
- `parallel-contract-orchestration` skill — cohesion contract that teammates share (system-architect teammate writes it, others read).
- `reviewer-flow` skill — adversarial review rule still applies inside teammates (Codex + Gemini both if both installed).
- `pre-merge-gate` skill — fires inside any teammate that hits `git push` / `gh pr merge`.

## Why no per-phase `/team-define` / `/team-build` / etc.

Previous rolepod versions shipped per-phase team slash commands (`/team-define` → spawn define-phase subagents, etc.). These were **subagent recipes**, not real teammates — Lead orchestrated single-process. The pattern proved confusing (Lead routinely pattern-matched the trigger phrase into regular subagent dispatch, drift documented in `0f8de4f` and `6da9fe0`).

Per-phase team commands have been removed. For phase-scoped parallel work:
- Want a single phase done in parallel? → Tell `/team-all` to scope teammates to that phase only.
- Want fast Lead-orchestrated single-process work? → Default Subagent + Task tool (no slash command needed — just describe what you want; Lead spawns via `team-routing`).

## Limitations (from upstream)

Per [official docs limitations](https://code.claude.com/docs/en/agent-teams#limitations):
- No session resumption with in-process teammates.
- Lead is fixed (can't transfer leadership).
- One team per Lead at a time.
- No nested teams.
- Tmux/iTerm2 required for split-pane mode.
- Permissions set at spawn (per-teammate mode tweaks possible after).

These are upstream constraints — rolepod cannot work around them.
