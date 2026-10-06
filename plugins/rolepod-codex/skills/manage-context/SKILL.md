---
name: manage-context
description: Use when context is heavy, stale or near a usage quota; a session resumes from a compaction or a handoff; a stated constraint was forgotten; fixes keep failing; edits spread past the plan; or the repo is unfamiliar.
---

# Manage Context

Phase = Recovery: turns a drifting, heavy, stuck or unfamiliar session back into stable work — pick the mode, run it, resume the phase you came from.

## Skip when

- No row of the step 1 table matches: the context is light, the request and its constraints are in view, and the next step is clear — stay in the current phase.

### 1. Detect the mode

Inputs: the original request and every correction since (latest wins) · the current state (last commit, staged files, tests green / red) · the constraints stated (deadline, no-touch zones, style).

| Symptom | Mode |
|---------|------|
| Just resumed from a compaction summary (auto or `/compact`), or the user asks to continue from the handoff | Re-anchor |
| Usage / quota limit near — the session dies regardless of context | Context budget — handoff path, not trim |
| Forgot a stated constraint | Session hygiene |
| Same bug at 3 surfaces | Zoom-out |
| 2+ failed fix attempts on the same unresolved repro or criterion, or stuck on architecture / root cause, or the previous fix was wrong but almost looked right | Escalate |
| Multi-file edits beyond the plan | Deep triage |
| Context bar yellow / red, a compaction warning, degraded recall (re-reading files already read, forgetting stated constraints) | Context budget |
| Unfamiliar repo, no clear entry point | Onboarding |
| The user asks for a handoff | Context budget — handoff path |

~70% of a context meter is the line; act on the observable signal, not the estimate.

Several rows match → run each once, top-down. Re-anchor precedes edits; quota uses handoff without trimming; re-anchor and hygiene share one reread; zoom-out never resets failed attempts.

Done when: every matching mode is picked, in table order.

### 2. Context budget

A quota limit cannot be trimmed away — skip the trim (no compact, no compact offer) even when the context is heavy too: checkpoint what the gates allow, write the uncommitted state into the brief, switch.

Heavy context → compact with your CLI's command (Claude `/compact <focus>`; other CLIs → `references/cli-fallbacks.md` (context commands by CLI); no reference → write the handoff brief below and start a fresh session). Still heavy → hand off; do not compact twice in a row.
- `/clear` is not a trim: it starts a fresh session, and runs only after the handoff brief is written, or when no work is left to carry.
- `/rewind` is not a trim: it undoes recent work, and runs only when that path itself is wrong — never to free context.

**Compact at seams.** Good moments: research done before implementation starts · a milestone landed · a debug closed · a failed approach abandoned · the Lead waiting on background sub-agents (not mid-task for the Lead: the plan on disk holds its state).
- Never compact mid-task: the summary drops exactly the state you need next (variable names, paths, half-applied edits), and the re-anchor cost lands on top.
- Heavy mid-task → finish or park the task at a seam (a checkpoint commit only as the Lead with finish-work's Pre-merge gate passing — finish-work absent → the task Command green + `git diff` reviewed; a subagent never commits), then trim.
- A wait offers the compact only as the relay of a context-check line (context past the hook's line) that arrived since the last compact and is not yet relayed; none → no offer. The offer is ONE line of ~100 characters or fewer, never a question: your CLI's compact command (Claude `/compact <focus>`), the focus naming the plan path (or "inline checklist") and the next step. A longer one wraps in the terminal, and a multi-line paste reaches the CLI as text, not a command.

Load only what the task needs: the Tier 1 skills + the touched files is usually enough.

**Handoff.** Context too heavy to trim safely, still heavy after compaction, starting fresh, or the user asks for a handoff → write `templates/handoff-brief.md` (the handoff fields) to the active repository's `docs/rolepod/handoff.md`; no template → a markdown file with the request and every correction, the disk state, the next task and command, the constraints and decisions, and the failed-attempt and Second opinion state. Point to artifacts by path; redact secrets, tokens and PII.
- This is the default session path; overwrite only that file. An explicit user path is authoritative, including a dated legacy handoff. Never select the newest file or overwrite a legacy path automatically; keep task-owner briefs at their generated paths.
- **`docs/rolepod/` is private by default:** before the first save run `grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore`; a repo that deliberately tracks its working docs creates `.rolepod/docs-tracked`.

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

Failed fixes → `debug-issue` step 9 holds the count, the Second opinion and the stop (no `debug-issue` → four failed fixes for one repro: stop and ask; one Second opinion after two).
- Capture the exact problem: the error, what was tried, what failed.
- Change the model, not just the prompt: a fresh-context read of your in-flight diff → `universal-reviewer`; a product failure returns to the Lead, who briefs the path owner to fix against that test. Brief: the original request, what was tried, what failed, what you suspect. No subagents → the Lead does it.
- The stop (the failed-fix count is spent, no usable advisor, or the advisor says stop) → hand the user a decision menu: the attempt log (each fix + result) and 2-3 concrete options with trade-offs (relax a constraint / split or defer scope / accept a documented limitation) — never a bare "stuck". Mid-plan this is a legitimate stop (`orchestrating-plans`): nothing runs on this blocker until the user picks, then resume on that pick.

Done when: a stronger model or outside opinion has run, or the user holds the decision menu.

### 7. Re-anchor

After a compaction, or to continue from a handoff — before acting, establish the repository / worktree and inspect `git status` and recent commits; disk is ground truth.
- Continue from a handoff → read the requested one: default `docs/rolepod/handoff.md`; an explicit user path wins, including a dated legacy handoff; never substitute the newest file. Missing, or from another checkout → stop before editing and ask for the exact artifact or checkout state.
- Read the next task and only the required predecessor handoff, contract clauses, or unresolved debug state. Use receipt/evidence pointers for files and tests already recorded.
- Expand reads only when a next-task decision, contract or debug fact is missing. Read the full plan/spec only if scope, acceptance, ownership, or position remains unclear; restore checklist ticks from the handoff or its artifact. Never invent a plan; ask for the exact missing artifact or state.
- Preserve the user's latest correction and failed-attempt counts. Same-session compaction keeps the carried mode; fresh native startup/resume/clear uses its newly captured profile.
- Resuming on another CLI → `references/cli-fallbacks.md` (cross-CLI resume); no reference → the same reads work on any CLI: the handoff and the disk carry the state.

Disk beats the summary on implementation state; a user correction that never touched disk still stands.

Still yellow / red after the re-anchor → Context budget's handoff path.

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
Mode: <each mode run, in table order: re-anchor | context budget | session hygiene | zoom-out | escalate | deep triage | onboarding | none — continuing>
Trigger: <what tipped this skill>
Action taken: <command run / re-read / escalation>
State after: <what is loaded, what is dropped>
Next: <which skill resumes work>
```

A session handoff is the brief from step 2 (Handoff), not this block.

Done when: the report names the mode and the skill that resumes.

## Guardrails

- Recover the context, then hand the work back. Never widen scope to get unstuck.

A zoom-out recovery and a session handoff, good vs bad → `examples/context-examples.md`; no examples → the Report block in step 9.

## Next phase

- Recovered → return to the phase you came from (`write-spec` … `finish-work`, or `simplify-code`) through `using-rolepod` or the current phase skill.
- At the decision menu, stop.
- No other skill → stop and tell the user the state, the next step and the evidence.
