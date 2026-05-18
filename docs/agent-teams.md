# Agent Teams (Claude only)

`/rolepod-all` spawns a real Claude Code agent team — multi-process teammates with shared task list and direct mailbox messaging. This is the [official agent-teams feature](https://code.claude.com/docs/en/agent-teams), NOT rolepod's old subagent-recipe pattern.

## Modes — graceful fallback by environment

`/rolepod-all` adapts to whatever the environment supports. User doesn't manage flags up front; Lead picks the highest-fidelity mode available and announces what it chose.

| Env state | Mode | Behavior |
|---|---|---|
| Claude v2.1.32+ + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | **TEAMMATE** | Real multi-process teammates (this doc) |
| Claude v2.1.32+ + env flag unset | **FALLBACK** | Lead-orchestrated Subagent + Task with cohesion contract (single-process). Lead announces fallback briefly + how to enable real teammates |
| Claude < v2.1.32 | **FAIL-FAST** | Upgrade required — teammate API doesn't exist; no fallback can match the contract |
| Codex / Gemini | not installed | `/rolepod-all` not shipped to those CLIs. Use natural-language Subagent dispatch via `team-routing` skill |

To enable teammate mode:

```json settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Until then, fallback mode delivers the same outcome shape (parallel work, contract-coordinated) at single-process cost.

## How it differs from subagents

| Aspect | Default Subagent + Task | Agent team (`/rolepod-all`) |
|---|---|---|
| Process model | Single Claude session, Lead spawns sub-context via Task tool | Multi-process — each teammate = full Claude Code instance |
| Communication | Subagent reports back to Lead only | Teammates message each other directly + Lead can talk to any teammate |
| Context window | Subagent has own context but it's a forked context | Each teammate has independent context window from spawn |
| Coordination | Lead orchestrates everything | Shared task list + self-claim + lead can intervene |
| Token cost | ~1× per subagent invocation | Linear: N teammates × N independent contexts |
| Resume | `/resume` works | No `/resume` for in-process teammates (upstream limitation) |
| CLI support | Cross-CLI (Claude / Codex / Gemini) | Claude only |
| Stability | Stable | Experimental |

## When to use `/rolepod-all`

Per official guidance, agent teams shine on:

| Use case | Why team helps |
|---|---|
| **Research + review** | Parallel exploration of different aspects, then cross-challenge findings |
| **New feature with cross-domain impact** | Each teammate owns frontend / backend / DB / tests independently |
| **Refactor across modules** | One teammate per module, no file-conflict overlap |
| **Debugging with competing hypotheses** | Adversarial debate — teammates try to disprove each other |
| **High-risk surface (auth/billing/migrations)** | Multiple independent reviewers + implementers, lower bug-survival rate |

When NOT to use:
- Single-file change
- Typo / docs edit
- Hotfix
- Sequential work with many dependencies (team-coordination overhead > benefit)
- Token budget tight (4-teammate team ≈ 4× cost)

## Spawn pattern

Default suggested composition for a full lifecycle (3-5 teammates per official guidance):

```
/rolepod-all "Add Stripe billing — high-risk"
```

The command body in `commands/rolepod-all.md` instructs Lead to:
1. Verify preconditions (version + env flag + CLI)
2. Pick 3-5 teammates using rolepod subagent definitions (system-architect, backend/frontend/mobile-developer per `team-routing` skill, qa-tester, etc.)
3. Have system-architect teammate write the cohesion contract FIRST
4. Other teammates read contract before implementing
5. qa-tester teammate blocks task-completion if evidence missing
6. For high-risk surface: teammates ALSO invoke Codex + Gemini via Bash per `reviewer-flow` skill

### Manual fine-grain control

Use plain prompts to Lead for surgical team work — no slash command needed:

```
Spawn a 3-teammate agent team to investigate the auth-bug at src/auth/login.ts.
Teammate 1: race-condition hypothesis.
Teammate 2: token-expiry hypothesis.
Teammate 3: middleware-ordering hypothesis.
Have them message each other to disprove the other theories.
```

This is the official pattern for [competing hypotheses](https://code.claude.com/docs/en/agent-teams#investigate-with-competing-hypotheses). Lead reads the prompt + spawns the team.

## Rolepod gates inside teammates

Each teammate is a full Claude Code session — meaning rolepod's CLAUDE.md + skills + hooks all load. Gates that fire inside each teammate:

- **S1-S5 / T1-T6 / F1-F5** — every teammate's pre-commit / pre-edit checks.
- **`block-subagent-commit.sh`** — teammates can NOT `git commit` directly. Lead commits after teammates report COMPLETED + evidence.
- **`gate-reminder.sh`** — high-risk path detection fires per teammate edit.
- **`reviewer-flow` skill** — adversarial review (Codex + Gemini both if available) still applies inside teammates.
- **`session-lock.sh`** — does NOT fire across teammates (same worktree shared by design).

Lead's job is coordination + cleanup. Gate enforcement is per-teammate.

## Why no per-phase team commands

Previous rolepod versions shipped `/team-define`, `/team-plan`, `/team-build`, `/team-verify`, `/team-review`, `/team-ship` as subagent recipes (single-process). These have been removed because:

1. **Lead drifted on the trigger phrase** — pattern-matched "team" prompts into regular Subagent dispatch and skipped the recipe entirely (drift documented in commits `0f8de4f`, `6da9fe0`).
2. **They duplicated default Subagent + Task tool** — Lead can already spawn N subagents in parallel within one session; the recipe added doctrine but no execution mechanism.
3. **They confused "team" semantics** — users expected multi-process teammates (the official Claude feature), got single-process recipes instead.

For phase-scoped parallel work, tell `/rolepod-all` to spawn teammates focused on that phase:

```
/rolepod-all "Just the Build phase — spawn 3 engineers in parallel,
each owning a different module of the auth refactor."
```

Lead will spawn 3 teammates scoped to Build, skipping Define/Plan/etc. (the prompt narrows the scope).

## Limitations (from upstream)

Per [official docs](https://code.claude.com/docs/en/agent-teams#limitations):
- No session resumption for in-process teammates
- One team per Lead at a time
- No nested teams
- Lead is fixed (can't transfer leadership)
- Tmux or iTerm2 required for split-pane mode
- Permissions set at spawn

These are upstream constraints — rolepod cannot work around them.

## See also

- [Official Claude Code agent-teams docs](https://code.claude.com/docs/en/agent-teams)
- `commands/rolepod-all.md` — the slash command body
- `core/skills/team-routing/SKILL.md` — picks which subagent definition each teammate uses
- `core/skills/parallel-contract-orchestration/SKILL.md` — cohesion contract pattern (teammates share)
- `core/skills/reviewer-flow/SKILL.md` — adversarial review rule (applies inside teammates)
