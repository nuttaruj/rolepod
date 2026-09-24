---
name: implement-plan
description: Use when executing an approved plan or a clear single-file edit — TDD at the plan's seams, surgical edits, bounded delegation, worktrees only when real filesystem isolation is needed. Phase = Build.
when_to_use: when a plan is approved (or the diff is small and obvious) and the next step is to actually edit code, tests, configs, content, or other artifacts
---

# Implement Plan

Turns an approved plan into a built, reviewed diff, one task at a time, each delegated task in a fresh context.

## Skip when

- A question only.
- The plan is still vague, wrong, or names a file that does not exist → `write-plan` first.
- The root cause of a failure is unknown → `debug-issue`.

### 1. Read the plan and the touched files

- Lint the plan before the first task: `plan-lint.sh <plan>` (`~/.rolepod/bin/`). FAIL (no **Command**, no checkboxes, a broken Blocked-by graph) → back to `write-plan`; never build on it.
- Read the touched files end-to-end, match the style of 2-3 nearby files (invent no patterns), and confirm every symbol the plan expects exists. A planned file missing where expected → verify it, or re-plan.
- Baseline: before the first edit, run the task's verify command once on the untouched tree and record what already fails as limitations. The task owner does it for a delegated task; the Lead only for its own R1 (trivial edit) work, never both.
- An R2 (one file + test) or spec-as-plan R3 (multi-file) inline checklist is the same contract: run each step's command. Scope grows past one file (its test file included) → stop and write the real plan.
- Verify each task by running its **Command** verbatim, never a re-derived check. No Command named → `write-plan` for one.
- Command passes → flip EVERY `- [ ]` under that task to `- [x]`. A **Test / evidence** proof the Command does not run (browser, manual) is not covered by the flip; do it first.
- Command fails → the task's **On fail**, else the plan's **Failure policy**.
- Shared plan (issue numbers in the header) → claim the task's issue before touching a file (write-plan's `references/team-issues.md`).

Done when: the plan lints clean, the baseline is recorded, and every file the task touches has been read.

### 2. Test first at the plan's seams

- Every logic slice: a failing unit test at the plan's seam (the public interface, never internals) → watch it fail → the smallest change → green → next slice. Refactor at review, not in the loop.
- A test that passes before the code exists has a weak assertion; tighten it.
- Prose, rename, config: no test.

Test-first vs evidence-after, mock boundaries (never a mocked DB in an integration test), your own test self-check → `references/tdd-by-risk.md`.

Done when: each logic slice has a test that was red before its change and is green after.

### 3. Edit surgically

- Touch only what the task requires: no "while I'm here" refactor, no reformatting, no single-use abstraction. Adjacent dead code → flag it; delete nothing unasked.
- Comments: none by default. Write one only for a non-obvious WHY (hidden constraint, workaround, surprising invariant), never the WHAT.
- Reuse ladder: before a new helper / constant / type / validation, stop at the first rung that holds:
  1. already in this codebase — extend, don't duplicate;
  2. stdlib;
  3. a native platform feature — DB constraint over app code, CSS over JS, `<input type="date">` over a picker lib;
  4. an installed dependency;
  5. only then the minimum new code — one line inline before a helper, a helper before a module.
- A NEW dependency is the last rung: maintained, reasonable size, compatible license. Unsure → ask.
- Blast radius is the caller count, not the diff size. Changing the behavior, signature or return shape of anything with callers → walk the callers FIRST (code-intel callers / impact when connected, else grep) and decide per caller: absorb, adapt, or split.
- Change files through the edit tool. Never a shell heredoc, `sed -i` or `tee`.

A sibling plugin covers the domain → `references/sibling-plugins.md`. A step only the human can perform → `references/wizard.md`.

Done when: the diff holds only the task's change and every caller of a changed behavior is accounted for.

### 4. Delegate

Decide *whether* first. The plan's **Owner:** line wins:
- `Owner: Lead` → self-do (R1 only; R2 goes to the owner on main).
- A named role → the **task owner**: it builds on the Command, runs its brief's reviewers (R4), fixes, and returns a **decision brief** (agent-protocol **Ticket loop**).
- No Owner line → run the delegation test:

{{INCLUDE: core/fragments/gates-q1-q4.md}}

The brief comes from the plan, never hand-written: `plan-lint.sh --brief <N> <plan> [contract]` prints it.
- The Lead adds only **Read first** (the 2-3 files and the pattern to copy) and facts the brief lacks. Never extra steps, runs or scope, a reviewer round 2 included.
- Never point the owner at the plan file; the brief is its slice.

The task owner NEVER commits and NEVER expands scope:
- A path nobody in the wave owns → touch it, plus one `Also touched:` line in the brief.
- A path another owner holds → stop, and put `NEEDS: <path> — <one-line change>` in the brief; the Lead applies it at integration (R1-sized) or reassigns.

A write mandate goes only to the path's owning role, never a generic agent or a reviewer; a writing stage carries `agentType: 'rolepod:<role>'`, never a bare `agent()` (`references/subagent-dispatch.md`: role, model, brief fields, `write: external`).

Handle the brief's status (its first word) per `references/subagent-dispatch.md`. `COMPLETED` over a failing test → reject and re-brief. `BLOCKED` → change a variable (context, model, scope); never redispatch unchanged.

No subagents → the Lead does it: steps 1-3 on each task, the module (or full) suite green, then `check-work` before claiming done.

Done when: every task has an owner and each dispatched owner has returned a decision brief.

### 5. Parallel tracks

A parallel layout → every unblocked task in ONE message, each owner in its OWN worktree; serial needs a stated reason. Shared files, merge order → `references/subagent-dispatch.md` Parallel-track dispatch.

Done when: every ready track is dispatched and each returned track is integrated in contract order.

### 6. Review

One combined pass for R2/R3, per task for R4 (high-risk).

A task owner's decision brief carries its Command tail. The Lead spot-checks ONE claim (the Proof, or one finding in an R4 report; never an axis walk), then runs the ship line.
- No report → the Lead runs `review-code` Axes, recorded as a LIMITATION.
- A diff accepted without its review → stop and run it before building further.

R2/R3 tasks carry no reviewer in the loop.
- When the plan's last code task is committed, the Lead runs ONE combined review over the plan diff (`rolepod-ticket log` prints the range); more than ~15 files → one per ship group.
- Findings → ONE fix task to the owning role; round 2 only for a BLOCKER / MAJOR fix.
- Nothing pushes or releases before it.

R4 tasks keep per-task review: the owner dispatches its reviewers before returning. Who reviews at each tier → `review-code` Pick reviewers.

One task per pass: brief → spot-check + ship line → next task. Never batch tasks into one diff.

Artifact: `templates/implementation-manifest.md` — Files changed, Tests added / changed, Verification, Scope check, Concerns, Status. A subagent returns it; the Lead commits.

Done when: every task is shipped and, for R2/R3, the combined review is clean or its fixes are verified.

## Guardrails

- Finish the planned task as planned. Never expand scope or silently redesign the plan mid-build: a new idea is one line under the plan's `## Follow-ups`.
- Run continuously between tasks and plan phases. Never ask "should I continue?" or end the turn mid-plan; an ended turn is a stop however it is worded. Stop only on a BLOCKED (after a variable change), a spec / plan gap, or a scope ambiguity that SURVIVES a re-read of the plan and the touched files. Forced to end anyway (usage limit, context, user stop) → the last act is one line under the plan's `## Changes during build`: stopped after Task N · next Task M · how to start the env.
- Read the evidence, not the status. Never accept `COMPLETED` without its Command tail.

Scope and manifest pairs, good and bad → `examples/execution-examples.md`.

## Next phase

- `check-work` proves the change works; the final done, the merge and the branch's fate belong to it and `finish-work`.
- `BLOCKED` survives context, model and scope changes and a re-plan → `manage-context` (escalate).
- If `check-work` is not available, run tests / build / curl / browser yourself and report evidence inline.
