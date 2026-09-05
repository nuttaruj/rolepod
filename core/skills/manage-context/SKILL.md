---
name: manage-context
description: Use when the session is long, the repo is unfamiliar, the work is multi-file, you are stuck, or you need to escalate to a stronger model. Context budget, session hygiene, zoom-out, deep triage, escalate, onboarding, post-compact re-anchor. Phase = Recovery / Re-context / Escalate.
when_to_use: when context feels heavy or stale, when you are mid-session and forgetting earlier constraints, when starting in an unfamiliar repo, when stuck after multiple attempts, or when the model class you are running on cannot make further progress
tier: 1
phase: recovery
---

# Manage Context

Recovery-phase skill. Keep work stable when context grows long, the codebase is unfamiliar, attention drifts, or the model is stuck. Combines context budget, session hygiene, zoom-out, deep triage, escalate, onboarding, and post-compact re-anchor.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER continue editing when the same bug surfaces from 3+ angles — that is a context loss signal. Zoom out first.
2. NEVER assume a fact from earlier in the session is still valid for files that have been edited since. Re-read before acting.
3. ESCALATE to a stronger model (or a fresh session) at the second failed attempt at the same goal, not after the tenth. In a debug flow this is debug-issue §9: one cross-model consult (fires at the second fail), one advisor-informed attempt, then the user.
4. ONBOARDING in an unfamiliar repo: detect stack and conventions from real files before writing a single line.
</EXTREMELY-IMPORTANT>

## When to use

- An observable context signal fires: the context bar turns yellow/red, the harness warns about compaction, or you notice degraded recall (re-reading files you already read, forgetting stated constraints). When a meter exists, ~70% used is the line — but act on the observable signal, not the estimate
- You just resumed from a compaction summary (auto-compact or `/compact`)
- A usage / quota limit is near — the session dies regardless of context state; handoff, don't trim
- The same bug keeps reappearing at a different surface
- You forgot a constraint the user stated earlier
- You are starting in an unfamiliar codebase
- A multi-file refactor is fanning out beyond the plan
- The current model is stuck on architecture or root cause
- The previous attempt produced a wrong fix that almost looked right

## Boundary

Owns:
- Context recovery, constraint re-read, session hygiene, zoom-out, onboarding, escalation.

Does not own:
- Product scope decisions.
- Implementation edits.
- Final verification or branch fate.

Return / hand off:
- After recovery, route back through `using-rolepod` or the current phase skill.
- If still stuck after recovery, escalate the model / session instead of widening scope.

## Inputs to gather

- The user's original request and every correction since (the latest instruction wins)
- The current state of the work (last commit, files staged, tests green / red)
- The constraint set the user stated (deadline, no-touch zones, style)
- Available context-trim commands for your CLI (see `references/cli-fallbacks.md`)

## Workflow

### 1. Detect the failure mode

| Symptom | Mode |
|---------|------|
| Context signal: bar yellow/red, compaction warning, or degraded recall | Context budget |
| Just resumed from a compaction summary | Post-compact re-anchor |
| Usage / quota limit near | Context budget — handoff path, not trim |
| Forgot a stated constraint | Session hygiene |
| Same bug at 3 surfaces | Zoom-out |
| 2+ failed fix attempts on the same target (informed 3rd still allowed) | Escalate |
| Multi-file edits beyond the plan | Deep triage |
| Unfamiliar repo, no clear entry point | Onboarding |

### 2. Context budget

If context is heavy, run your CLI's trim command — the per-CLI table (Claude `/compact` · `/clear` · `/rewind` / Codex / Gemini equivalents) lives in `references/cli-fallbacks.md`.

**Compact at seams, never mid-task.** The good moments: research done before implementation starts, a milestone landed before the next begins, a debug closed before feature work resumes, a failed approach abandoned before the new one. Mid-implementation compaction pays twice — the summary drops exactly the state you need next (variable names, file paths, half-applied edits), and §7's re-anchor cost lands on top. Heavy context mid-task → finish or park the task at a seam (checkpoint — commit only as Lead with finish-work's gates passing; a subagent never commits, implement-plan Boundary), then trim.

Only load what the current task actually needs. Tier 1 skills + the touched files is usually enough.

Starting fresh instead of trimming → fill `templates/handoff-brief.md` so the next session resumes without re-asking — on ANY CLI: the brief + plan artifact are CLI-agnostic (`references/cli-fallbacks.md`, Cross-CLI resume). A quota limit, unlike heavy context, cannot be trimmed away: checkpoint what the gates allow, write the uncommitted state into the brief, switch.

### 3. Session hygiene

Re-read the original request AND every correction stated since — the latest instruction is authoritative. List the constraints still in force. Verify the touched files match what you remember; they may have changed since you last read them.

### 4. Zoom-out

Step back from the immediate edit. Ask: what is the user actually trying to accomplish? Is the current path of attempts still aligned with that goal, or have you started solving a sub-problem you invented?

### 5. Deep triage (multi-file)

Map the actual surface: list every file you have edited or planned to edit. Group by concern. Re-check the plan against the spec. If the surface is wider than the plan, write a new plan, do not keep widening edits.

### 6. Escalate

If stuck after multiple attempts:
- Capture the exact problem (error, what was tried, what failed)
- Change the model, not just the prompt: redispatch the task at a stronger tier, or in a debug flow run debug-issue §9's one cross-model consult — a fresh session on the same model is the weakest lever
- Ladder exhausted — stronger tier (fable-class where exposed) and/or
  cross-family consulted and the blocker stands → STOP and hand the user a
  decision menu: the attempt log (each rung tried + its result) and 2-3
  concrete options with trade-offs (relax a constraint / split or defer the
  scope / accept a documented limitation) — never a bare "stuck". This stop
  is legitimate mid-plan: continuous execution (implement-plan Iron Rule 5)
  yields to an exhausted ladder, never the other way around.
- Resume with the user's direction, not another blind attempt

Two failed attempts is the trigger — same signature or progressing alike: identical failure twice means the mental model is wrong, and even a progressing second fail is re-aimed cheaper by a cold advisor than by a third guess from the same mind. Past that, the only permitted attempt is the single advisor-informed one from debug-issue §9 — never another blind try.

### 7. Post-compact re-anchor

A compaction summary is a lossy narrator, not a state file. Before the first
action after any compaction (auto or `/compact`):
- Re-read the plan artifact if one exists — checkboxes mark the real position, not the
  summary's claim of it
- Run `git log --oneline -5` + `git status` — commits and staged files are
  the ground truth of what actually landed
- Re-open the spec / cohesion contract if the flow has one
A summary can say a task is done that the plan file still shows `- [ ]`.
Disk beats summary on implementation state; a correction the user gave that never touched disk still stands.

### 8. Onboarding (new repo)

Before any edit:
- Read `README.md`, `CLAUDE.md` if present
- Detect stack from `package.json` / `pyproject.toml` / `Cargo.toml` / `Makefile`
- Read 2-3 representative files to match style
- Find the test runner and run a smoke test
- Identify the entry point and the main module

## If a matching Rolepod agent is available

Delegate the recovery action to the closest specialist:

- `system-architect` for multi-file refactor scope decisions
- `qa-tester` when the recurring failure is in test discipline
- `universal-reviewer` to read your in-flight diff with fresh context

Brief: original user request, what has been tried, what failed, what you suspect is wrong.

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Re-read the original user request literally
2. List the constraints still in force
3. List the files you have actually touched vs the plan
4. Identify which of the seven modes above matches the current symptom
5. Run the appropriate context command for your CLI (see `references/cli-fallbacks.md`)
6. For unfamiliar repo: read README + config + 2-3 representative files before editing
7. For stuck: capture exact failure and ask the user for direction
8. For multi-file drift: stop, write the new plan, then continue

## Output format

```
Mode: <context budget | session hygiene | zoom-out | escalate | deep triage | onboarding | post-compact re-anchor>
Trigger: <what tipped this skill>
Action taken: <command run / re-read / escalation>
State after: <what is loaded, what is dropped>
Next: <which skill resumes work>
```

When starting a fresh session, the durable artifact is `templates/handoff-brief.md` — save it under `docs/rolepod/handoffs/<topic>-YYYY-MM-DD.md`, which is private by default (`grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore`; the commit gate refuses to commit it unless the repo opted in with `.rolepod/docs-tracked`).

## Examples

Non-blocking — read only when unsure how to recover or hand off:
- `examples/context-examples.md` — a zoom-out recovery and a session handoff, each a good/bad pair with a "why good wins" table. Read the whole file; the contrast is the lesson.

## References

Load only when the task needs it:
- `references/cli-fallbacks.md` — context-management commands per CLI (Claude / Codex / Gemini)

## Hard stops

- Context is too heavy to trim safely → start a fresh session with a written handoff brief
- 2 failed attempts at the same target with no outside opinion → stop and get one (debug flow: §9); only the informed 3rd is permitted, never a blind 4th
- You cannot name what the user asked for in one sentence → stop, re-read the request
- An unfamiliar repo has no README and no obvious entry → ask the user before editing

## Full Rolepod enhancement

Full Rolepod improves this phase by surfacing context-budget reminders via SessionStart hooks (where the CLI supports them), re-injecting the always-on core after `/clear` and compaction (Claude `clear|compact` matchers), the escalation pattern, the deep triage checklist, and onboarding on first session in a new repo.

## Next phase

- After recovery, return to the phase you came from — `write-spec`, `write-plan`, `implement-plan`, `debug-issue`, `check-work`, `review-code`, `finish-work`, or `simplify-code`.
- If still stuck after recovery, surface the blocker to the user with a concrete ask.
