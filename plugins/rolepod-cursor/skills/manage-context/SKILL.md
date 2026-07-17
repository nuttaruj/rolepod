---
name: manage-context
description: Use when the session is long, the repo is unfamiliar, the work is multi-file, you are stuck, or you need to escalate to a stronger model. Context budget, session hygiene, zoom-out, deep triage, escalate, onboarding. Phase = Recovery / Re-context / Escalate.
---

# Manage Context

Recovery-phase skill. Keep work stable when context grows long, the codebase is unfamiliar, attention drifts, or the model is stuck. Combines context budget, session hygiene, zoom-out, deep triage, escalate, and onboarding.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER continue editing when the same bug surfaces from 3+ angles — that is a context loss signal. Zoom out first.
2. NEVER assume a fact from earlier in the session is still valid for files that have been edited since. Re-read before acting.
3. ESCALATE to a stronger model (or a fresh session) at the third failed attempt at the same goal, not after the tenth. In a debug flow this is debug-issue §9: one cross-model consult, one advisor-informed attempt, then the user.
4. ONBOARDING in an unfamiliar repo: detect stack and conventions from real files before writing a single line.
</EXTREMELY-IMPORTANT>

## When to use

- An observable context signal fires: the context bar turns yellow/red, the harness warns about compaction, or you notice degraded recall (re-reading files you already read, forgetting stated constraints). When a meter exists, ~70% used is the line — but act on the observable signal, not the estimate
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

- The user's original request (literal quote if possible)
- The current state of the work (last commit, files staged, tests green / red)
- The constraint set the user stated (deadline, no-touch zones, style)
- Available context-trim commands for your CLI (see `references/cli-fallbacks.md`)

## Workflow

### 1. Detect the failure mode

| Symptom | Mode |
|---------|------|
| Context signal: bar yellow/red, compaction warning, or degraded recall | Context budget |
| Forgot a stated constraint | Session hygiene |
| Same bug at 3 surfaces | Zoom-out |
| 3+ failed fix attempts on the same target | Escalate |
| Multi-file edits beyond the plan | Deep triage |
| Unfamiliar repo, no clear entry point | Onboarding |

### 2. Context budget

If context is heavy, run your CLI's trim command — the per-CLI table (Claude `/compact` · `/clear` · `/rewind` / Codex / Gemini equivalents) lives in `references/cli-fallbacks.md`.

Only load what the current task actually needs. Tier 1 skills + the touched files is usually enough.

Starting fresh instead of trimming → fill `templates/handoff-brief.md` so the next session resumes without re-asking.

### 3. Session hygiene

Re-read the original request literally. List the constraints still in force. Verify the touched files match what you remember; they may have changed since you last read them.

### 4. Zoom-out

Step back from the immediate edit. Ask: what is the user actually trying to accomplish? Is the current path of attempts still aligned with that goal, or have you started solving a sub-problem you invented?

### 5. Deep triage (multi-file)

Map the actual surface: list every file you have edited or planned to edit. Group by concern. Re-check the plan against the spec. If the surface is wider than the plan, write a new plan, do not keep widening edits.

### 6. Escalate

If stuck after multiple attempts:
- Capture the exact problem (error, what was tried, what failed)
- Change the model, not just the prompt: redispatch the task at a stronger tier, or in a debug flow run debug-issue §9's one cross-model consult — a fresh session on the same model is the weakest lever
- Surface the blocker to the user with a concrete ask, or start a fresh session with the captured context
- Resume with the user's direction, not another blind attempt

Three failed attempts is the trigger. Past that, the only permitted attempt is the single advisor-informed one from debug-issue §9 — never another blind try.

### 7. Onboarding (new repo)

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
4. Identify which of the six modes above matches the current symptom
5. Run the appropriate context command for your CLI (see `references/cli-fallbacks.md`)
6. For unfamiliar repo: read README + config + 2-3 representative files before editing
7. For stuck: capture exact failure and ask the user for direction
8. For multi-file drift: stop, write the new plan, then continue

## Output format

```
Mode: <context budget | session hygiene | zoom-out | escalate | deep triage | onboarding>
Trigger: <what tipped this skill>
Action taken: <command run / re-read / escalation>
State after: <what is loaded, what is dropped>
Next: <which skill resumes work>
```

When starting a fresh session, the durable artifact is `templates/handoff-brief.md`.

## Examples

Non-blocking — read only when unsure how to recover or hand off:
- `examples/context-examples.md` — a zoom-out recovery and a session handoff, each a good/bad pair with a "why good wins" table. Read the whole file; the contrast is the lesson.

## References

Load only when the task needs it:
- `references/cli-fallbacks.md` — context-management commands per CLI (Claude / Codex / Gemini)

## Hard stops

- Context is too heavy to trim safely → start a fresh session with a written handoff brief
- 3 failed attempts at the same target → stop, escalate, do not try a fourth blind
- You cannot name what the user asked for in one sentence → stop, re-read the request
- An unfamiliar repo has no README and no obvious entry → ask the user before editing

## Full Rolepod enhancement

Full Rolepod improves this phase by surfacing context-budget reminders via SessionStart hooks (where the CLI supports them), the escalation pattern, the deep triage checklist, and onboarding on first session in a new repo.

## Next phase

- After recovery, return to the phase you came from — `write-spec`, `write-plan`, `implement-plan`, `debug-issue`, `check-work`, `review-code`, `finish-work`, or `simplify-code`.
- If still stuck after recovery, surface the blocker to the user with a concrete ask.
