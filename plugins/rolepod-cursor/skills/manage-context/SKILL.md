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
| 2+ failed fix attempts on the same unresolved repro or criterion, or stuck on architecture / root cause, or the previous fix was wrong but almost looked right | Escalate |
| Multi-file edits beyond the plan | Deep triage |
| Context bar yellow / red, a compaction warning, degraded recall (re-reading files already read, forgetting stated constraints) | Context budget |
| Unfamiliar repo, no clear entry point | Onboarding |
| The user asks for a handoff, or to continue from the handoff | Context budget — handoff path |

~70% of a context meter is the line; act on the observable signal, not the estimate.

Several rows match → run each once, top-down. Re-anchor precedes edits; quota uses handoff without trimming; re-anchor and hygiene share one reread; zoom-out never resets failed attempts.

Done when: every matching mode is picked, in table order.

### 2. Context budget

Heavy context → compact with the CLI command (Claude `/compact <focus>`; other CLIs: `references/cli-fallbacks.md`). Still heavy → hand off; do not compact twice in a row.
- `/clear` is not a trim: it starts a fresh session, and runs only after the handoff brief is written, or when no work is left to carry.
- `/rewind` is not a trim: it undoes recent work, and runs only when that path itself is wrong — never to free context.

**Compact at seams.** Good moments: research done before implementation starts · a milestone landed · a debug closed · a failed approach abandoned · the Lead waiting on background sub-agents (not mid-task for the Lead: the plan on disk holds its state).
- Never compact mid-task: the summary drops exactly the state you need next (variable names, paths, half-applied edits), and the re-anchor cost lands on top.
- Heavy mid-task → finish or park the task at a seam (a checkpoint commit only as the Lead with finish-work's Pre-merge gates passing — finish-work absent → the task Command green + `git diff` reviewed; a subagent never commits), then trim.

Load only what the task needs: the Tier 1 skills + the touched files is usually enough.

Context too heavy to trim safely, still heavy after compaction, starting fresh, or the user asks for a handoff → write `templates/handoff-brief.md` to the active repository's `docs/rolepod/handoff.md`.
- This is the default session path; overwrite only that file. An explicit user path is authoritative, including a dated legacy handoff. Never select the newest file or overwrite a legacy path automatically; keep task-owner briefs at their generated paths.
- If the required file is missing or belongs to another checkout, stop before editing and ask for the exact artifact or checkout state.

"Continue from the handoff" → establish the repository/worktree, then read the requested handoff (default `docs/rolepod/handoff.md` unless the user gave a path).
- Inspect `git status` and recent commits, then read the next task and only the predecessor handoff, required contract clauses, or unresolved debug state.
- Use receipt/evidence pointers for files and tests already recorded. Expand reads only when a next-task decision, contract, or debug fact is missing.
- Read the full spec/plan only when scope, acceptance, ownership, or position remains unclear. Do not invent a plan; ask for the exact missing artifact or state. See `references/cli-fallbacks.md` for cross-CLI resume.
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

After two failed fixes for the same unresolved repro or criterion, get one Second opinion before attempts three and four. Carry the count across owners and phases. Retrace before each remaining attempt and use the advice; no usable advisor means stop before another fix. Four failed fixes means stop and ask the user. Keep review rounds on their separate count.
- Capture the exact problem: the error, what was tried, what failed.
- Change the model, not just the prompt: in a debug flow run `debug-issue` Second opinion once after two failures. A fresh session on the same model is not an independent opinion. The ledger records whether advice was usable; never consult twice for the same issue.
- After the opinion, attempts three and four require a fresh trace and use the advice plus new repro evidence. No usable advisor → stop before another fix. After four failed fixes, go straight to the decision menu; never reset the count on owner, model or phase changes.
- A fresh-context read of your in-flight diff → `universal-reviewer`; an E2E flake or a user-visible (E2E) failure → `qa-tester` for the repro test or bug report (unit-test discipline belongs to the writer); a product failure it reports returns to the Lead, who briefs the path owner to fix against that test. Brief: the original request, what was tried, what failed, what you suspect. No subagents → the Lead does it.
- The failed-fix ladder is exhausted at four failures, when no usable advisor exists, or when the advisor says stop and no informed attempt remains → STOP and hand the user a decision menu: the attempt log (each fix + result) and 2-3 concrete options with trade-offs (relax a constraint / split or defer scope / accept a documented limitation) — never a bare "stuck". A completed usable opinion alone does not exhaust the ladder; carry out the informed third and, if needed, fourth attempt.
  - This stop is legitimate mid-plan: implement-plan's continuous execution yields to an exhausted ladder, never the other way around.
- After the menu, nothing runs on this blocker — no attempt, consult or escalation — until the user picks an option; then resume on that pick.

Done when: a stronger model or outside opinion has run, or the user holds the decision menu.

### 7. Re-anchor after compaction

Before acting after compaction, inspect `git status` and recent commits; disk is ground truth.
- Read the next task and only required predecessor handoff, contract clauses, or unresolved debug state. Use receipt/evidence pointers for files and tests already recorded.
- Expand reads only when a next-task decision is missing. Read the full plan/spec only if scope, acceptance, ownership, or position remains unclear; restore checklist ticks from the handoff or its artifact.
- Preserve the user's latest correction and failed-attempt counts. Same-session compaction keeps the carried mode; fresh native startup/resume/clear uses its newly captured profile.

Disk beats the summary on implementation state; a user correction that never touched disk still stands.

Still yellow / red after the re-anchor → Context budget's handoff path, never a second compaction in a row.

Done when: the repository state, next task, and required predecessor state are read from disk.

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

A session handoff uses `templates/handoff-brief.md` at `docs/rolepod/handoff.md` by default. Record the request/corrections, repository and worktree state, phase, next task/command, constraints, decisions, and checklist ticks.
- Include receipt, contract, debug, and evidence pointers plus unresolved attempts/Second opinion state. Point to receipts for files/tests; without a receipt, keep required facts in the handoff.
- An explicit user path remains valid, including a dated legacy handoff. Never select or overwrite one automatically. Task-owner briefs keep their generated paths.

Done when: the report names the mode and the skill that resumes.

## Guardrails

- Recover the context, then hand the work back. Never widen scope to get unstuck.

A zoom-out recovery and a session handoff, good vs bad → `examples/context-examples.md`.

## Next phase

- Recovered → return to the phase you came from (`write-spec` … `finish-work`, or `simplify-code`) through `using-rolepod` or the current phase skill.
- Still stuck after recovery → run Escalate once. Its ladder exhausted → the decision menu ends the run: work resumes only on the user's pick.
- If the phase skill is not available, state the recovered state and the next concrete step, and continue as the Lead.
