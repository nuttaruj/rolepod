---
description: Spawn a Claude Code agent team (real multi-process teammates) to run the full 6-phase lifecycle in parallel. Requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 + Claude Code v2.1.32+. Claude-only — Codex/Gemini fall back to default subagent dispatch.
disable-model-invocation: true
---

# Team All — Claude Agent Team (Multi-Process)

You are entering the **real Claude Code agent-team workflow** — multi-process teammates with shared task list, mailbox messaging, and self-coordination. NOT subagent recipes.

This command spawns a Claude Code agent team per the [official spec](https://code.claude.com/docs/en/agent-teams). Each teammate runs as a separate Claude Code instance with its own context window. Teammates communicate directly with each other via mailbox; you can also message any teammate by name.

## Preconditions (verify before spawning)

1. **Claude Code v2.1.32+**: `claude --version`. Below 2.1.32 → fail-fast, ask user to upgrade.
2. **`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`**: check `settings.json` or env. Not set → fail-fast, instruct user:
   ```json
   { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
   ```
3. **Running on Claude Code** (not Codex/Gemini): teammate feature is Claude-only. Other CLIs have no equivalent → respond "team feature is Claude-only; on Codex/Gemini use default subagent dispatch with `team-routing` skill for per-task delegation."

If ANY precondition fails → respond with what's missing + how to fix. Do NOT attempt teammate spawn.

## Spawn pattern

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

## Rolepod gates still apply (inside each teammate)

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
