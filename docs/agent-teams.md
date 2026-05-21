# Agent Teams — `/rolepod-full` teammate backend (Claude only)

When the user invokes `/rolepod-full` on a Claude Code session with agent-teams enabled, the force-full lifecycle runs on the **teammate backend** — a real Claude Code agent team: multi-process teammates with a shared task list and direct mailbox messaging. This is the [official agent-teams feature](https://code.claude.com/docs/en/agent-teams), not rolepod's old subagent-recipe pattern.

`/rolepod-full` is the only public command. Teammate mode is one of its execution backends, not a separate command — `/rolepod-team` was removed (see [migration](#migration-from-rolepod-team)).

## Backend selection — by environment

`/rolepod-full` picks the highest-fidelity backend the environment supports and announces the choice. The user does not manage flags up front.

| Env state | Backend | Behavior |
|---|---|---|
| Claude v2.1.32+ + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | **teammate mode** | Real multi-process teammates (this doc) |
| Claude v2.1.32+, env flag unset | **Task / subagents** | Lead-orchestrated Subagent + Task with a cohesion contract (single-process) |
| Claude < v2.1.32 | **Task / subagents** | Teammate API does not exist; subagent dispatch delivers the same outcome shape |
| User asked for single-process | **Task / subagents** | Explicit override — skip teammate mode even when available |
| Codex / Gemini | **native subagents** | Codex / Gemini subagent dispatch via `write-plan` agent routing; inline fallback when unsupported |

To enable teammate mode on Claude:

```json settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Also set `ROLEPOD_ALLOW_SHARED_WORKTREE=1` before spawning a team so rolepod's session-lock hook does not warn on teammates sharing the Lead's worktree.

Until the flag is set, the Task/subagent backend delivers the same outcome shape (parallel work, contract-coordinated) at single-process cost.

## How teammate mode differs from subagents

| Aspect | Task / subagent backend | Teammate backend |
|---|---|---|
| Process model | Single Claude session, Lead spawns sub-context via Task tool | Multi-process — each teammate = full Claude Code instance |
| Communication | Subagent reports back to Lead only | Teammates message each other directly + Lead can talk to any teammate |
| Context window | Forked context per subagent | Independent context window per teammate |
| Coordination | Lead orchestrates everything | Shared task list + self-claim + Lead can intervene |
| Token cost | ~1× per subagent invocation | Linear: N teammates × N independent contexts (~4× for a 4-teammate team) |
| Resume | `/resume` works | No `/resume` for in-process teammates (upstream limitation) |
| CLI support | Cross-CLI (Claude / Codex / Gemini) | Claude only |
| Stability | Stable | Experimental |

## When teammate mode is worth the cost

`/rolepod-full` already signals feature-scale work. Teammate mode adds real parallelism on top — worth the ~4× tokens for:

| Use case | Why a team helps |
|---|---|
| **New feature with cross-domain impact** | Each teammate owns frontend / backend / DB / tests independently |
| **Refactor across modules** | One teammate per module, no file-conflict overlap |
| **Research + review** | Parallel exploration, then cross-challenge findings |
| **Debugging with competing hypotheses** | Adversarial debate — teammates try to disprove each other |
| **High-risk surface (auth/billing/migrations)** | Multiple independent reviewers + implementers, lower bug-survival rate |

When the Task/subagent backend is the better pick even on a teams-enabled Claude:
- Sequential work with many dependencies (team-coordination overhead > benefit)
- Token budget tight
- User explicitly asked for single-process

## Teammate spawn pattern

For a feature with cross-domain impact, spawn 3-5 teammates (official guidance: "Three focused teammates often outperform five scattered ones"). Each teammate is a full Claude Code session — not a subagent — and uses a rolepod subagent definition for its role:

```
Create an agent team for <feature description>.

Spawn these teammates:
1. system-architect — owns spec + cohesion contract + RED test list.
2. backend-developer (or path-appropriate engineer per write-plan agent routing)
   — owns server-side implementation.
3. frontend-developer (if UI in scope) — owns client-side implementation.
4. qa-tester — owns evidence collection, integration tests, reviewer floor.

Coordination:
- system-architect writes the cohesion contract FIRST; other teammates read it
  before implementing (no fan-out without a contract — write-plan skill).
- qa-tester runs after each teammate marks a task complete; blocks promotion
  to "done" if evidence is missing.
- High-risk surface (auth/billing/migrations/crypto/payments): teammates
  ALSO consult external reviewers when configured (Codex via `codex exec`,
  Gemini via `gemini -m pro -p`) — review-code skill rule.

Wait for all teammates to finish before synthesizing.
```

### Adjust composition per task

- Pure research / debugging: 3 teammates, each a competing hypothesis.
- Code review: 3 teammates, each a different lens (security / performance / test coverage).
- Refactor across modules: one teammate per module + one orchestrator.
- Drop any teammate without a clear independent unit of work.

### Phase-scoped teams

For parallel work on a single phase, scope the teammates to it:

```
/rolepod-full — just the Build phase. Spawn 3 engineers in parallel,
each owning a different module of the auth refactor.
```

### Manual fine-grain control

For surgical team work, prompt Lead directly — no command needed:

```
Spawn a 3-teammate agent team to investigate the auth bug at src/auth/login.ts.
Teammate 1: race-condition hypothesis.
Teammate 2: token-expiry hypothesis.
Teammate 3: middleware-ordering hypothesis.
Have them message each other to disprove the other theories.
```

This is the official [competing-hypotheses pattern](https://code.claude.com/docs/en/agent-teams#investigate-with-competing-hypotheses).

## Rolepod gates inside teammates

Each teammate is a full Claude Code session — rolepod's CLAUDE.md + skills + hooks all load. Gates that fire per teammate:

- **S1-S5 / T1-T6 / F1-F5** — every teammate's pre-commit / pre-edit checks.
- **`block-subagent-commit.sh`** — teammates cannot `git commit` directly. Lead commits after teammates report COMPLETED + evidence.
- **`gate-reminder.sh`** — high-risk path detection fires per teammate edit.
- **`review-code` skill** — adversarial review (external reviewers when configured) still applies inside teammates.
- **`session-lifecycle.sh --lock`** — does NOT fire across teammates (same worktree shared by design).

Lead's job is coordination + cleanup. Gate enforcement is per-teammate.

## Cleanup

Per official docs:
- Lead's terminal lists all teammates + status; Shift+Down cycles through them.
- High-risk teammates: require plan approval before they make changes.
- When done, ask Lead to "Clean up the team" — shut down teammates first, then cleanup. Always via Lead, never teammates.

## Limitations (from upstream)

Per [official docs](https://code.claude.com/docs/en/agent-teams#limitations):
- No session resumption for in-process teammates
- One team per Lead at a time
- No nested teams
- Lead is fixed (cannot transfer leadership)
- Tmux or iTerm2 required for split-pane mode
- Permissions set at spawn

These are upstream constraints — rolepod cannot work around them.

## Migration from `/rolepod-team`

`/rolepod-team` was a separate public slash command. It has been **removed** — no deprecated alias. Teammate mode is now an execution backend of `/rolepod-full`, selected automatically when agent-teams is enabled. Anything that used `/rolepod-team` now uses `/rolepod-full`.

Per-phase team commands (`/team-define`, `/team-build`, etc.) were removed earlier — they were single-process subagent recipes that Lead pattern-matched into regular dispatch (drift documented in commits `0f8de4f`, `6da9fe0`).

## See also

- [Official Claude Code agent-teams docs](https://code.claude.com/docs/en/agent-teams)
- `core/skills/rolepod-full/SKILL.md` — the `/rolepod-full` force-full entrypoint
- `core/skills/using-rolepod/SKILL.md` — the router; defines force-full mode + backend selection
- `core/skills/write-plan/SKILL.md` — agent routing + cohesion contract
- `core/skills/review-code/SKILL.md` — reviewer routing + adversarial mode
