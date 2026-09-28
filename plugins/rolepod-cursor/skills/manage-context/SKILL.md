---
name: manage-context
description: Use when the session is long, the repo is unfamiliar, a multi-file change is fanning out beyond the plan, you are stuck, or you need to escalate to a stronger model. Context budget, session hygiene, zoom-out, deep triage, escalate, onboarding, post-compact re-anchor. Phase = Recovery / Re-context / Escalate.
---

# Manage Context

Turns a drifting, heavy, stuck or unfamiliar session back into stable work: pick the mode, run it, resume the phase you came from.

### 1. Detect the mode

Inputs: the original request and every correction since (latest wins) · the current state (last commit, staged files, tests green / red) · the constraints stated (deadline, no-touch zones, style) · your CLI's context commands (`references/cli-fallbacks.md`).

| Symptom | Mode |
|---------|------|
| Just resumed from a compaction summary (auto or `/compact`) | Re-anchor after compaction |
| Usage / quota limit near — the session dies regardless of context | Context budget — handoff path, not trim |
| Forgot a stated constraint | Session hygiene |
| Same bug at 3 surfaces | Zoom-out |
| 2+ failed fix attempts on the same target (an informed 3rd is still allowed), or stuck on architecture / root cause, or the previous fix was wrong but almost looked right | Escalate |
| Multi-file edits beyond the plan | Deep triage |
| Context bar yellow / red, a compaction warning, degraded recall (re-reading files already read, forgetting stated constraints) | Context budget |
| Unfamiliar repo, no clear entry point | Onboarding |

~70% of a context meter is the line; act on the observable signal, not the estimate.

Several rows match → run each matching mode once, top-down in table order; a later mode acts on the state an earlier one recovered.
- After a compaction, Re-anchor runs first — before a fix or any edit; still heavy after it → Context budget's handoff path, not another trim.
- Quota near → Context budget runs once, on its handoff path only — even when the context is heavy too, never a trim first.
- Re-anchor and Session hygiene run as one pass: disk state first, then the request, its corrections and the constraints; a file re-read once serves both.
- Zoom-out, then Escalate: the re-aim serves the same goal, so the failed attempts on it still count — a re-aim never resets them.

Done when: every matching mode is picked, in table order.

### 2. Context budget

Heavy context → trim with your CLI's compact command (Claude `/compact <focus>`; other CLIs in `references/cli-fallbacks.md`). Still heavy right after a compaction → the handoff path below, never a second compaction in a row.
- `/clear` is not a trim: it starts a fresh session, and runs only after the handoff brief is written, or when no work is left to carry.
- `/rewind` is not a trim: it undoes recent work, and runs only when that path itself is wrong — never to free context.

**Compact at seams.** Good moments: research done before implementation starts · a milestone landed · a debug closed · a failed approach abandoned · the Lead waiting on background sub-agents (not mid-task for the Lead: the plan on disk holds its state).
- Never compact mid-task: the summary drops exactly the state you need next (variable names, paths, half-applied edits), and the re-anchor cost lands on top.
- Heavy mid-task → finish or park the task at a seam (a checkpoint commit only as the Lead with finish-work's Pre-merge gates passing — finish-work absent → the task Command green + `git diff` reviewed; a subagent never commits), then trim.

Load only what the task needs: the Tier 1 skills + the touched files is usually enough.

Context too heavy to trim safely, still heavy right after a compaction, or starting fresh → fill `templates/handoff-brief.md`, then start the fresh session (Claude `/clear`). The brief is the entry point: the fresh session reads it, then every artifact it links — plan, spec, cohesion contract, debug ledger. The brief and those artifacts are CLI-agnostic (`references/cli-fallbacks.md` Cross-CLI resume).
A quota limit cannot be trimmed away — skip the trim even when the context is heavy too: checkpoint what the gates allow, write the uncommitted state into the brief, switch.

Done when: the context is trimmed at a seam, or a handoff brief is written for the fresh session.

### 3. Session hygiene

Re-read the original request AND every correction since; the latest instruction is authoritative.
List the constraints still in force.
Re-read every file edited since you last read it; a fact from earlier in the session does not hold for it.
You cannot state what the user asked for in one sentence → re-read the request.

Done when: the request fits one sentence and every constraint in force is listed.

### 4. Zoom-out

The same bug surfacing from 3+ angles is a context-loss signal: stop editing.
Ask what the user is actually trying to accomplish, and whether the current path of attempts still serves that goal or a sub-problem you invented.

Done when: the next attempt is aimed at the user's goal in one sentence.

### 5. Deep triage (multi-file)

List every file edited or planned, grouped by concern.
Re-check the plan against the spec.
The surface is wider than the plan → write a new plan; stop widening edits.
A multi-file refactor scope decision → dispatch `system-architect`. No subagents → the Lead does it.

Done when: every touched file maps to a plan task, or a new plan exists.

### 6. Escalate

Escalate at the SECOND failed attempt at the same goal, never the tenth. Identical failure twice means the mental model is wrong, and even a progressing second fail is re-aimed cheaper by a cold advisor than by a third guess from the same mind.
- Capture the exact problem: the error, what was tried, what failed.
- Change the model, not just the prompt: redispatch at a stronger tier, or in a debug flow run `debug-issue` Second opinion — one cross-model consult, one advisor-informed attempt, then the user. A fresh session on the same model is the weakest lever. Arriving from `debug-issue` with the ledger's `Second opinion:` line at `done` (an opinion, or `no usable advisor`) → the ladder is exhausted: go straight to the decision menu below; never re-enter `debug-issue` or run another consult for the same bug. The line's state decides, not whether an opinion text exists.
- After two failed attempts the only permitted attempt is that single informed 3rd; never a blind 3rd or 4th.
- A fresh-context read of your in-flight diff → `universal-reviewer`; an E2E flake or a user-visible (E2E) failure → `qa-tester` for the repro test or bug report (unit-test discipline belongs to the writer); a product failure it reports returns to the Lead, who briefs the path owner to fix against that test. Brief: the original request, what was tried, what failed, what you suspect. No subagents → the Lead does it.
- Ladder exhausted (the strongest exposed tier and / or cross-family consulted, the blocker stands) → STOP and hand the user a decision menu: the attempt log (each rung + result) and 2-3 concrete options with trade-offs (relax a constraint / split or defer scope / accept a documented limitation) — never a bare "stuck".
  - This stop is legitimate mid-plan: implement-plan's continuous execution yields to an exhausted ladder, never the other way around.
- After the menu, nothing runs on this blocker — no attempt, consult or escalation — until the user picks an option; then resume on that pick.

Done when: a stronger model or outside opinion has run, or the user holds the decision menu.

### 7. Re-anchor after compaction

A compaction summary is a lossy narrator, not a state file. Before the first action after any compaction:
- Re-read the plan artifact — its checkboxes mark the real position, not the summary's claim. An inline checklist (R2 one file + test / spec-as-plan R3 multi-file) is re-stated in the hand-off with its ticks, or written to an artifact before compacting.
- `git log --oneline -5` + `git status` — commits and staged files are the ground truth.
- Re-open the spec / cohesion contract if the flow has one.

Disk beats the summary on implementation state; a user correction that never touched disk still stands.

Still yellow / red after the re-anchor → Context budget's handoff path, never a second compaction in a row.

Done when: the plan position, the last commits and the staged files are read from disk.

### 8. Onboarding (new repo)

Before any edit:
- read whichever of `README.md` / `CLAUDE.md` / `AGENTS.md` applies and is not auto-loaded;
- detect the stack from `package.json` / `pyproject.toml` / `Cargo.toml` / `Makefile`;
- read 2-3 representative files for style;
- find the test runner and run a smoke test;
- identify the entry point and the main module.

No README and no obvious entry → ask the user before editing.

Done when: the stack, the style, the test runner and the entry point are named from real files.

### 9. Report

```
Mode: <each mode run, in table order: re-anchor after compaction | context budget | session hygiene | zoom-out | escalate | deep triage | onboarding | none — continuing>
Trigger: <what tipped this skill>
Action taken: <command run / re-read / escalation>
State after: <what is loaded, what is dropped>
Next: <which skill resumes work>
```

A fresh session's durable artifact is `templates/handoff-brief.md` — original request, current branch / commit, artifacts to read next, files touched, tests run and status, constraints still active, decisions made, blockers and attempts, resume with — saved under `docs/rolepod/handoffs/<topic>-YYYY-MM-DD.md`.
**`docs/rolepod/` is private by default:** before the first save run `grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore`; a repo that deliberately tracks its working docs creates `.rolepod/docs-tracked`.

Done when: the report names the mode and the skill that resumes.

## Guardrails

- Recover the context, then hand the work back. Never widen scope to get unstuck.

A zoom-out recovery and a session handoff, good vs bad → `examples/context-examples.md`.

## Next phase

- Recovered → return to the phase you came from (`write-spec` … `finish-work`, or `simplify-code`) through `using-rolepod` or the current phase skill.
- Still stuck after recovery → run Escalate once. Its ladder exhausted → the decision menu ends the run: work resumes only on the user's pick.
- If the phase skill is not available, state the recovered state and the next concrete step, and continue as the Lead.
