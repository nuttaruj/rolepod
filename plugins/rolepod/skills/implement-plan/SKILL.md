---
name: implement-plan
description: Use when executing an approved plan or a clear single-file edit — TDD at the agreed seams, surgical edits, bounded delegation, worktrees only when real filesystem isolation is needed. Phase = Build.
when_to_use: when a plan is approved (or the diff is small and obvious) and the next step is to actually edit code, tests, configs, content, or other artifacts
---

# Implement Plan

Turns an approved plan into a built, reviewed diff, one task at a time, each delegated task in a fresh context.

## Skip when

- A question only.
- The plan is still vague, wrong, or names a file that does not exist → `write-plan` first.
- The root cause of a failure is unknown → `debug-issue`.

### 1. Read the plan and the touched files

- Lint the plan before the first task: `plan-lint.sh <plan>` (`../write-plan/scripts/plan-lint.sh` from this skill's folder). FAIL (no **Command**, no checkboxes, a broken Blocked-by graph) → back to `write-plan`; never build on it.
- No `plan-lint.sh` → check by eye: a **Command** and checkboxes per task, an acyclic Blocked-by graph, a **Failure policy**.
- Whoever builds the task reads the touched files end-to-end, matches the style of 2-3 nearby files (invent no patterns), and confirms every symbol the plan expects exists — the task owner on a delegated task, the Lead only on its own R1 (trivial edit) work (no subagents → the Lead). A planned file missing where expected → verify it, or re-plan. The Lead's part on a delegated task is the plan lint and the **Read first** names (Delegate).
- Baseline: before the first edit, run the task's verify command once on the untouched tree and record what already fails as limitations. The task owner does it for a delegated task; the Lead only for its own R1 (trivial edit) work, never both.
- An R2 (one file + test) or spec-as-plan R3 (multi-file) inline checklist is the same contract: run each step's command. Scope grows past one file (its test file included) → stop and write the real plan.
- Whoever builds verifies the task by running its **Command** verbatim, never a re-derived check — the task owner on a delegated task (its decision brief carries the tail), the Lead only on its own R1 work. No Command named → `write-plan` for one.
- Command passes → flip EVERY `- [ ]` under that task to `- [x]` — on a delegated task the Lead flips them from the owner's Command tail (`scripts/ticket.sh log` in the ship line; without it, by hand). A **Test / evidence** proof the Command does not run (browser, manual) is not covered by the flip; do it first.
- Command fails → the task's **On fail**, else the plan's **Failure policy**, else (an R2 checklist has neither) `debug-issue`. The same criterion failing a 2nd time → `debug-issue`, whose Second opinion caps the attempts (no `debug-issue` → the runner (the Lead without sub-agents) re-traces once; a 2nd failure → stop and report to the user).
- Before the first task commit, record the base sha (`git rev-parse HEAD`) under the plan's `## Changes during build`.
- Shared plan (issue numbers in the header) → claim the task's issue before touching a file (write-plan's `references/team-issues.md`).

Done when: the plan lints clean (or passes the by-eye check), the baseline is recorded, and every file the task touches has been read — by the task owner on a delegated task, by the Lead on its own R1 work.

### 2. Test first at the agreed seams

- Every logic slice runs `tdd-flow` at the agreed seam — the spec's Testing decisions, else the plan task's seam, neither (an R2 checklist, a single-file edit) → the highest existing seam that reaches the behavior, stated `Seam: <interface>`: a failing test at that public interface (never internals) → watch it fail (green before the code → tighten the assertion) → the smallest change → green → the next behavior. Refactor at review, not in the loop.
- `tdd-flow` cannot be opened → these limits still hold: the agreed seam only; one behavior → one test; no test ahead of the behavior; edge / error / race only when an acceptance criterion names it or it is an R4 (high-risk) floor — deny path, money math, migration rollback, shared-state race. Mock only external boundaries, never the DB in an integration test.
- A test outside the agreed seam is scope creep → one line under `## Follow-ups`.
- Prose, rename, config: no test.

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
- A named role → the **task owner**: it builds on the Command, runs its brief's reviewers (R4), fixes, and returns a **decision brief** (the agent's **Writer loop** → Ticket loop).
- No Owner line → run the delegation test:

```
Q1: More than 1 file to edit?        Q2: Run tests / build / server?
Q3: A real design-judgment call?     Q4: More than 3 tool calls total?
```
All "no" → self-do. Any "yes" → delegate to the closest specialist by path / concern / strategy.

The brief comes from the plan, generated when plan-lint exists: `plan-lint.sh --brief <N> <plan> [contract]` prints it; add `--main` for a task that runs on the main checkout (a sequential track), so the brief names no worktree. No plan-lint → the brief is the task block verbatim, plus the spec path and the Bounds: never commit, stay in scope, run the Command, return a decision brief.
- The Lead adds only **Read first** (the 2-3 files and the pattern to copy) and facts the brief lacks. Never extra steps, runs or scope, a reviewer round 2 included.
- Never point the owner at the plan file; the brief is its slice.

The task owner NEVER commits and NEVER expands scope:
- A path nobody in the wave owns → touch it, plus one `Also touched:` line in the brief.
- A path another owner holds → stop, and put `NEEDS: <path> — <one-line change>` in the brief; the Lead applies it at integration (R1-sized) or reassigns.

A write mandate goes only to the path's owning role, never a generic agent or a reviewer; a writing stage carries `agentType: 'rolepod:<role>'`, never a bare `agent()` (`references/subagent-dispatch.md`: role, model, brief fields). `write: external` → the owner writes the failing test first, then `cross-family` kind implement; pool off or `cross-family` absent → the owner writes the task.

Handle the brief's status (its first word):
- `COMPLETED` over a failing test → reject and re-brief.
- `COMPLETED`, no concerns → Review; with Concerns → resolve correctness and scope concerns first.
- `PARTIAL` → review the done slice, redispatch the remainder narrowed.
- `BLOCKED` → change a variable (context, model, scope); never redispatch unchanged.
- A question or any other first word → answer it or ask for the status, then redispatch.

No subagents → the Lead does it: steps 1-3 on each task, the module (or full) suite green, then `check-work` before claiming done.

Done when: every task has an owner and each dispatched owner has returned a decision brief.

### 5. Parallel tracks

A parallel layout → every unblocked task in ONE message, each owner in its OWN worktree; serial needs a stated reason. Shared files, merge order → `references/subagent-dispatch.md` Parallel-track dispatch.

Done when: every ready track is dispatched and each returned track is integrated in contract order.

### 6. Review

One combined pass for R2/R3, per task for R4 (high-risk).

A task owner's decision brief carries its Command tail. The Lead spot-checks ONE claim (the Proof, or one finding in an R4 report; never an axis walk), then runs the ship line.
- No report → the Lead runs `review-code` Axes (no review-code → intent, trace, correctness, tests on the diff), recorded as a LIMITATION.
- A diff accepted without its review → stop and run it before building further.

R2/R3 tasks carry no reviewer in the loop.
- When the plan's last code task is committed, the Lead runs ONE combined review over the plan diff (`scripts/ticket.sh log` prints the range; without it, the recorded base sha..HEAD, i.e. the first task commit^..HEAD); more than ~15 files → one per ship group.
- A plan that names a ship group → after its last task, one drift pass over the group's range, a normal review of the cross-task seams (never adversarial): `security-engineer` when it holds an R4 task, else the combined review is the drift pass.
- Findings → ONE fix task to the owning role; round 2 only for a BLOCKER / MAJOR fix — internal, never a new external round (`review-code` Fix-verify rounds).
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
- `BLOCKED` survives context, model and scope changes and a re-plan → `manage-context` (escalate); if it is not available, stop and hand the user the attempt log and 2-3 options.
- If `check-work` is not available, run tests / build / curl / browser yourself and report evidence inline.
