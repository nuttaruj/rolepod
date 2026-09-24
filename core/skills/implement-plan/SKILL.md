---
name: implement-plan
description: Use when executing an approved plan or a clear single-file edit — TDD at the plan's seams, surgical edits, bounded delegation, worktrees only when real filesystem isolation is needed. Phase = Build.
when_to_use: when a plan is approved (or the diff is small and obvious) and the next step is to actually edit code, tests, configs, content, or other artifacts
tier: 1
phase: build
---

# Implement Plan

Turns an approved plan into a built, reviewed diff, task by task: test first at the plan's seams, surgical edits, a fresh context per delegated task.

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
- Shared plan (issue numbers in the plan header) → assign yourself the task's issue before touching a file; already assigned → take the next unblocked task; close it with the commit / PR pointer when review passes (write-plan's `references/team-issues.md`).

Done when: the plan lints clean, the baseline is recorded, and every file the task touches has been read.

### 2. Test first at the plan's seams

- Every logic slice: a failing unit test at the plan's seam (the public interface, never internals) → watch it fail → the smallest change → green → next slice. Refactor at review, not in the loop.
- A seam's interface is everything a caller must know: the signature plus its invariants, ordering, error modes and required config. The test asserts those, not the type alone.
- A test that passes before the code exists has a weak assertion; tighten it.
- Prose, rename, config: no test.

Unsure whether a task is test-first or evidence-after, or checking your own tests → `references/tdd-by-risk.md`.

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
- Tests use a real dependency over a fake / stub / mock. Never mock the database in an integration test.
- Blast radius is the caller count, not the diff size. Changing the behavior, signature or return shape of anything with callers → walk the callers FIRST (code-intel callers / impact when connected, else grep) and decide per caller: absorb, adapt, or split.
- Change files through the edit tool. Never a shell heredoc, `sed -i` or `tee`.
- A sibling plugin covers the domain → its edit primitive over a hand-rolled write: `rolepod-uiproof` `/scaffold-e2e`; `rolepod-wplab` `/wp-edit-{design,plugin,theme}`, `/wp-scaffold` (WP primitives inside `wp-content/`). Its evidence lands under `<git-root>/.rolepod/evidence/` (a child's own path when standalone); `check-work` aggregates it.

A stretch only the human can perform (a vendor dashboard, minting credentials or CI secrets, a one-off cutover) → `references/wizard.md`.

Done when: the diff holds only the task's change and every caller of a changed behavior is accounted for.

### 4. Delegate

Decide *whether* first. The plan's **Owner:** line wins:
- `Owner: Lead` → self-do (R1 only; R2 goes to the owner on main).
- A named role → dispatch the task brief to that role as the **task owner**. It builds on the Command, dispatches the reviewers its brief names (R4), fixes, and returns a **decision brief** (agent-protocol **Ticket loop**).
- No Owner line → run the delegation test:

{{INCLUDE: core/fragments/gates-q1-q4.md}}

Closest specialist: `frontend-developer` / `ui-ux-designer` (UI, interaction) · `backend-developer` (API, business logic, DB models) · `mobile-developer` (iOS, Android, RN, Flutter) · `billing-engineer` (billing, credits, subscription) · `ai-ml-engineer` (LLM, RAG, SDK, prompt cache) · `data-scientist` (analytics, pipelines, dashboards) · `content-strategist` (written output; pass `audience: dev|user|prospect`).

The brief comes from the plan, never hand-written: `plan-lint.sh --brief <N> <plan> [contract]` prints Goal / Tier / Blocked by / Read first / Files allowed + forbidden / Change / Command / Done when / Write / Reviewers by tier (`none` for a docs-only diff) / Bounds.
- The Lead adds only **Read first** (the 2-3 files and the pattern to copy) and facts the brief lacks. Never extra steps, runs or scope, a reviewer round 2 included.
- The owner starts there and never re-surveys what the Lead already mapped.
- Never point the owner at the plan file; the brief is its slice.
- Use the least powerful model that can handle the role.

The task owner NEVER commits and NEVER expands scope:
- A path nobody in the wave owns → touch it, plus one `Also touched:` line in the brief.
- A path another owner holds → stop, and put `NEEDS: <path> — <one-line change>` in the brief; the Lead applies it at integration (R1-sized) or reassigns.

A write mandate goes only to the role that owns the path. Never a generic platform agent (`general-purpose` / `default` / `claude`, or a bare Workflow `agent()`; a writing stage carries `agentType: 'rolepod:<role>'`). Never a reviewer: `qa-tester` / `security-engineer` write tests and markdown only; `universal-reviewer` / `scout` write markdown only.

`Owner: <role> · write: external` (pool opt-in, per task) → `references/subagent-dispatch.md` External write.

The decision brief's first word is its status:
- `COMPLETED` over a failing test → reject and re-brief.
- `COMPLETED`, no concerns → Review.
- `COMPLETED` with Concerns → resolve correctness and scope concerns first, then Review.
- `PARTIAL` → review the done slice, redispatch the remainder narrowed.
- `BLOCKED` → change a variable (context, model, scope); never redispatch unchanged.

Status handling in depth, model choice, fleets → `references/subagent-dispatch.md`.
No subagents → the Lead does it: steps 1-3 on each task, the module (or full) suite green, then `check-work` before claiming done.

Done when: every task has an owner and each dispatched owner has returned a decision brief.

### 5. Parallel tracks

The plan's layout is the dispatch signal. Every unblocked task goes out in ONE message, each task owner in its OWN worktree named for the task (the brief prints the command), under the plan's cohesion contract.
- The Lead keeps working while task owners build.
- Integrate each as it returns (Review); merge in the contract's order.
- Two tracks reach for the same file → stop: run them sequentially, or rewrite the contract.
- A parallel-layout plan run one track at a time needs a stated reason; otherwise dispatch the ready tracks together.

Mid-flight conflicts, separate CLI sessions as track owners → `references/subagent-dispatch.md`.

Done when: every ready track is dispatched and each returned track is integrated in contract order.

### 6. Review

One combined pass for R2/R3, per task for R4 (high-risk).

A task owner's decision brief carries its Command tail. The Lead spot-checks ONE claim (the Proof, or one finding in an R4 report), then runs the ship line.
- Spot-check ONE traced claim; never an axis walk.
- No report → the Lead runs `review-code` Axes, recorded as a LIMITATION.
- A diff accepted without its review → stop and run it before building further.

R2/R3 tasks carry no reviewer in the loop.
- When the plan's last code task is committed, the Lead runs ONE combined review over the plan diff (`rolepod-ticket log` prints the range).
- Two `universal-reviewer` lenses in ONE message: `lens: spec` · `lens: standards` (or the concern-matched row); the external instead at the pool's tier.
- More than ~15 files → one review per ship group.
- Findings → ONE fix task to the owning role; round 2 only for a BLOCKER / MAJOR fix.
- Nothing pushes or releases before it.

R4 tasks keep per-task review: the owner dispatches `security-engineer` + ONE strong pass (the external with a usable pool, else `universal-reviewer`), plus `qa-tester` when the slice changes what a user sees, before returning.

One task per pass, then ship it: decision brief → Lead spot-check + ship line → next unblocked task. Never batch tasks into one diff; the rhythm is a fresh context per task.

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
