---
name: manage-context
description: Use when the session is long, the repo is unfamiliar, a multi-file change is fanning out beyond the plan, you are stuck, or you need to escalate to a stronger model. Context budget, session hygiene, zoom-out, deep triage, escalate, onboarding, post-compact re-anchor. Phase = Recovery / Re-context / Escalate.
---

# Manage Context

Keep work stable when context grows long, the codebase is unfamiliar, attention drifts, or the model is stuck. Seven modes: context budget, session hygiene, zoom-out, deep triage, escalate, onboarding, post-compact re-anchor.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER continue editing when the same bug surfaces from 3+ angles — that is a context-loss signal. Zoom out first.
2. NEVER assume a fact from earlier in the session still holds for files edited since. Re-read before acting.
3. ESCALATE to a stronger model (or a fresh session) at the SECOND failed attempt at the same goal, not the tenth. In a debug flow this is debug-issue §9: one cross-model consult, one advisor-informed attempt, then the user.
4. ONBOARDING in an unfamiliar repo: detect stack and conventions from real files before writing a line.
</EXTREMELY-IMPORTANT>

## When to use

- An observable context signal: the context bar turns yellow/red, the harness warns about compaction, or recall degrades (re-reading files already read, forgetting stated constraints). ~70% of a meter is the line — act on the observable signal, not the estimate.
- You just resumed from a compaction summary (auto or `/compact`).
- A usage / quota limit is near — the session dies regardless of context; hand off, don't trim.
- The same bug reappears at a different surface · you forgot a stated constraint · unfamiliar codebase · a multi-file refactor fans out beyond the plan · the model is stuck on architecture or root cause · the previous fix was wrong but almost looked right.

## Boundary

Owns: context recovery, constraint re-read, session hygiene, zoom-out, onboarding, escalation.

Does not own: product scope · implementation edits · final verification · branch fate.

Hand off:
- Recovered → back through `using-rolepod` or the current phase skill.
- Still stuck after recovery → escalate the model / session, never widen scope.

## Workflow

### 1. Detect the mode

| Symptom | Mode |
|---------|------|
| Context bar yellow/red, compaction warning, degraded recall | Context budget |
| Just resumed from a compaction summary | Post-compact re-anchor |
| Usage / quota limit near | Context budget — handoff path, not trim |
| Forgot a stated constraint | Session hygiene |
| Same bug at 3 surfaces | Zoom-out |
| 2+ failed fix attempts on the same target (informed 3rd still allowed) | Escalate |
| Multi-file edits beyond the plan | Deep triage |
| Unfamiliar repo, no clear entry point | Onboarding |

Inputs: the original request and every correction since (latest wins) · current state (last commit, staged files, tests green / red) · the constraints stated (deadline, no-touch zones, style) · your CLI's trim commands (`references/cli-fallbacks.md`).

### 2. Context budget

Heavy context → run your CLI's trim command (Claude `/compact` · `/clear` · `/rewind`; Codex / Gemini equivalents in `references/cli-fallbacks.md`).

**Compact at seams, never mid-task.** Good moments: research done before implementation starts · a milestone landed · a debug closed · a failed approach abandoned. Mid-implementation compaction pays twice — the summary drops exactly the state you need next (variable names, paths, half-applied edits), then §7's re-anchor cost lands on top. Heavy mid-task → finish or park the task at a seam (checkpoint commit only as Lead with finish-work's gates passing; a subagent never commits), then trim.

Load only what the task needs: Tier 1 skills + the touched files is usually enough.

Starting fresh instead of trimming → fill `templates/handoff-brief.md`; the brief + plan artifact are CLI-agnostic (`references/cli-fallbacks.md`, Cross-CLI resume). A quota limit cannot be trimmed away: checkpoint what the gates allow, write the uncommitted state into the brief, switch.

### 3. Session hygiene

Re-read the original request AND every correction since — the latest instruction is authoritative. List the constraints still in force. Verify the touched files match what you remember; they may have changed.

### 4. Zoom-out

What is the user actually trying to accomplish? Is the current path of attempts still aligned with that goal, or have you started solving a sub-problem you invented?

### 5. Deep triage (multi-file)

List every file edited or planned. Group by concern. Re-check the plan against the spec. Surface wider than the plan → write a new plan; do not keep widening edits.

### 6. Escalate

Two failed attempts is the trigger — identical failure twice means the mental model is wrong, and even a progressing second fail is re-aimed cheaper by a cold advisor than by a third guess from the same mind. Past that, the only permitted attempt is the single advisor-informed one from debug-issue §9 — never another blind try.

- Capture the exact problem: error, what was tried, what failed.
- Change the model, not just the prompt: redispatch at a stronger tier, or in a debug flow run debug-issue §9's one cross-model consult. A fresh session on the same model is the weakest lever.
- Ladder exhausted (strongest exposed tier and/or cross-family consulted, blocker stands) → STOP and hand the user a decision menu: the attempt log (each rung + result) and 2-3 concrete options with trade-offs (relax a constraint / split or defer scope / accept a documented limitation) — never a bare "stuck". This stop is legitimate mid-plan: continuous execution (implement-plan Iron Rule 5) yields to an exhausted ladder, never the other way around.
- Resume with the user's direction, not another blind attempt.

### 7. Post-compact re-anchor

A compaction summary is a lossy narrator, not a state file. Before the first action after any compaction:
- Re-read the plan artifact — checkboxes mark the real position, not the summary's claim. An inline checklist (R2 one file + test / spec-as-plan R3) is re-stated in the hand-off with its ticks, or written to an artifact before compacting.
- `git log --oneline -5` + `git status` — commits and staged files are the ground truth.
- Re-open the spec / cohesion contract if the flow has one.
Disk beats summary on implementation state; a user correction that never touched disk still stands.

### 8. Onboarding (new repo)

Before any edit: read whichever of `README.md` / `CLAUDE.md` / `AGENTS.md` applies and is not auto-loaded · detect the stack from `package.json` / `pyproject.toml` / `Cargo.toml` / `Makefile` · read 2-3 representative files for style · find the test runner and run a smoke test · identify the entry point and main module.

## If a matching Rolepod agent is available

- `system-architect` — multi-file refactor scope decisions
- `qa-tester` — recurring failure in test discipline
- `universal-reviewer` — fresh-context read of your in-flight diff

Brief: original request, what was tried, what failed, what you suspect.

## If no matching agent is available

Execute as Lead: re-read the request literally → list constraints in force → list files touched vs the plan → pick the mode from §1 → run that section; for stuck, capture the exact failure and ask the user for direction.

## Output

```
Mode: <context budget | session hygiene | zoom-out | escalate | deep triage | onboarding | post-compact re-anchor | none — continuing>
Trigger: <what tipped this skill>
Action taken: <command run / re-read / escalation>
State after: <what is loaded, what is dropped>
Next: <which skill resumes work>
```

Fresh session → the durable artifact is `templates/handoff-brief.md`, saved under `docs/rolepod/handoffs/<topic>-YYYY-MM-DD.md`. **`docs/rolepod/` is private by default:** before the first save run `grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore` — a repo that deliberately tracks its working docs creates `.rolepod/docs-tracked`.

## References

Load only when needed:
- `references/cli-fallbacks.md` — context commands per CLI (Claude / Codex / Gemini), cross-CLI resume.
- `examples/context-examples.md` — a zoom-out recovery and a session handoff, good/bad pairs.

## Hard stops

- Context too heavy to trim safely → fresh session with a written handoff brief.
- 2 failed attempts at the same target with no outside opinion → stop and get one (debug flow: §9); only the informed 3rd is permitted, never a blind 4th.
- You cannot state what the user asked for in one sentence → re-read the request.
- Unfamiliar repo with no README and no obvious entry → ask the user before editing.

## Next phase

- Recovered → return to the phase you came from (`write-spec` … `finish-work`, or `simplify-code`).
- Still stuck → surface the blocker to the user with a concrete ask.
