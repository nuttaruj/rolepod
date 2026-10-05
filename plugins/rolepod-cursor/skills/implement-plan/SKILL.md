---
name: implement-plan
description: Use when an approved plan, an inline R2 checklist or a spec-as-plan R3 list is ready to build; a plan's next task is unblocked; a clear single-file edit is next; or the user says to execute the plan.
---

# Implement Plan

Phase = Build: turns an approved plan into a built, reviewed diff, one task at a time, each delegated task in a fresh context.
An approved plan with a task in progress → resume Build at that task; never restart Define or Plan.

## Skip when

- A question only.
- The plan is still vague, wrong, or names a file that does not exist → `write-plan` first.
- The root cause of a failure is unknown → `debug-issue`.

### 1. Lint the plan

- A plan file → `plan-lint.sh <plan>` (`../write-plan/scripts/plan-lint.sh`, relative to this skill's folder) before the first task. FAIL (no **Command**, no checkboxes, a broken Blocked-by graph) → back to `write-plan`; never build on it. No `plan-lint.sh` → check by eye: a **Command** and checkboxes per task, an acyclic Blocked-by graph, a **Failure policy**.
- An inline chat checklist has no file: no lint, no temp file; it is the owner's brief, and every step names its verify command. It fits only R2 (one source file plus its own test) or spec-as-plan R3 (≤3 approved ordered tasks, each naming files, verify command and dependencies; single owner; no parallel work or high-risk path). An added source file, a 4th task, parallel work, a high-risk path, changed acceptance or compaction → stop and `write-plan` the real plan.
- No **Command** named for a task → `write-plan` for one.
- Before the first task commit, record the base sha (`git rev-parse HEAD`) under the plan's `## Changes during build`.
- Shared plan (issue numbers in the header) → claim the task's issue before touching a file (`write-plan` team issues; no `write-plan` → assign the issue to yourself).

Done when: the plan lints clean (or passes the by-eye check; an inline checklist: every step names its verify command) and the base sha is recorded.

### 2. Brief each ready task

The plan's **Owner:** line wins:
- `Owner: Lead` → Build it yourself (below; R1 only — R2 goes to the owner on main).
- A named role → the **task owner**: it builds on the Command, runs its brief's reviewers, fixes, and returns a **decision brief** (its agent's Writer loop).
- No Owner line → self-do only when all four are no: more than one file to edit, a test / build / server run, a real design-judgment call, more than 3 tool calls; any yes → the path's writer role (write-plan's domain map).

The brief: `scripts/ticket.sh start <plan> <N>`, or `plan-lint.sh --brief <N> <plan> [contract]` (add `--main` for a task on the main checkout, so the brief names no worktree). No script → the task block verbatim, plus the spec path and the Bounds: never commit, stay in scope, run the Command, return a decision brief. Picking the role, the BLOCKED variables and the ship recipe → `references/subagent-dispatch.md`; no reference → the closest specialist by path.
- The Lead adds only **Read first** (the 2-3 files and the pattern to copy) and facts the brief lacks, appended after the generated sections; Tier, Reviewers and Command stay as generated. Never extra steps, runs or scope — a whole-suite run (the Lead's, once, at release) included.
- A wide-effort session (the `cross-family` skill's rule) → every owner brief carries `External: off — wide-effort session`.
- Never point the owner at the plan file; the brief is its slice.

A Blocked-by task's brief carries each predecessor's Handoff (plan-lint --brief prints the section, or the receipt path when it cannot); the Lead never tells an owner to read or write the plan's ## Changes during build.

The task owner NEVER commits and NEVER expands scope: a path nobody in the wave owns → touch it, plus one `Also touched:` line; a path another owner holds → `NEEDS: <path> — <one-line change>`, and the Lead applies it at integration (R1-sized) or reassigns. A write mandate goes to the path's owning role, never a reviewer; portable dispatch → `using-rolepod` model tiers; no `using-rolepod` → a fresh default subagent given the role's text.

Done when: every ready task is dispatched, independent ones in ONE message.

### 3. Build: accept the return

Handle the brief's status (its first word):
- `COMPLETED` over a failing test, or with no Command tail → reject and re-brief.
- `COMPLETED`, no concerns → step 4; with Concerns → resolve correctness and scope concerns first.
- `PARTIAL` → review the done slice, redispatch the remainder narrowed.
- `BLOCKED` → change a variable (context, model, scope); never redispatch unchanged.
- A question or any other first word → answer it or ask for the status, then redispatch.

An owner's return whose last line is `WAITING: <report paths>` is mid-task — never integrate or stop it. A report it names reaches you instead → SendMessage the owner `Report in: <path>` in the same turn; never merge or fix its findings yourself.

The owner writes its decision brief to the absolute base receipt its brief names (docs/rolepod/tasks/<plan>/task-NN.md; Handoff at most ~15 lines — signatures, invariants); owners and reviewers never edit the plan file, and the Lead's own points go under ## Lead notes. Owner status (`COMPLETED | PARTIAL | BLOCKED`) and Verify status (`VERIFIED | PARTIAL | UNVERIFIED`) stay distinct; neither implies the other.
A plan task's chat reply stays within 12 lines: status, receipt path, Command tail, reviewer verdicts + report paths, residuals.

Validate the receipt, spot-check ONE claim, then integrate: the ship line (`ticket.sh integrate` → commit → `log`); no script → the commit check, `git commit`, then one `## Changes during build` line (sha / verdict / receipt pointer). Flip EVERY `- [ ]` under the task to `- [x]` from the Command tail; a **Test / evidence** proof the Command does not run (browser, manual) comes first. Integrated → stop the owner (TaskStop, or the CLI's close) in the same turn, and any background work it reports. One task per pass; never batch tasks into one diff.

Artifact: `templates/implementation-manifest.md` — `## Decision brief` (Change, Tests added / changed, Commands, Scope check, Concerns, Author fix closure, Owner status), `## Verify status`, `## Handoff`, `## Reviews`, `## Lead notes`, filled inside the task receipt. Without a file-writing tool, the owner returns the complete receipt inline and names the limitation.

Done when: the task is committed, its boxes flipped, its owner stopped.

### 4. Review at its seam

- R4 task → per-task review: the owner's round-1 reports exist before its commit (who reviews at each tier → `review-code` Pick reviewers; no `review-code` → the brief's Reviewers line).
- R2/R3 tasks:

> Track end: a track with two or more code tasks → one fresh owner (the role owning most of the track's code) runs the two lenses in ONE message on the track diff and fixes each BLOCKER / MAJOR with its proof (`review-code` Fix-verify); the Lead commits the fixes in the track worktree, then `ticket.sh finish <worktree>` merges the track. A track with one code task → its task owner runs the two lenses before returning, the same way, and the track takes no track-end review.

- A docs-only track takes no review. A track-end brief over a diff holding an R3 or R4 task carries the pool-on lens line when `cross-family.sh --pool-names` prints a member.
- A required report missing, failed, empty or partial keeps that round open: its isolated reviewer completes its own report on the frozen diff. Never substitute a Lead review when agents are available; with no agents, the Lead records both axes and the independence limitation. Never accept a diff without its required reports.
- The Lead never runs a review loop itself; it talks to owners. Findings → ONE fix task to the owning role; rounds and closure → `review-code` Fix-verify (no `review-code` → one fresh reviewer re-checks only each fix's delta, at most four rounds), closure in the receipt's Author fix closure with report pointers. Nothing pushes or releases before it.

Done when: every track's review is closed at the receipts.

### 5. Tracks

- Two or more tracks, a ship group, a track over ~800 changed lines or ~15 files, or another session's live lock on the base checkout → call `run-tracks` (layout, worktrees, size slices, drift pass, session split).
- No `run-tracks` → run the tracks one after another on the base checkout in plan order. A named ship group → after its tasks one seams-only drift pass by a fresh owner (`security-engineer` when the group holds an R4 task), never adversarial. Another session holds a live lock on the base → the whole plan runs in one worktree (`git worktree add .worktrees/<plan> -b <branch>`). A track over ~800 changed lines / ~15 files → split its review by task ranges.

Done when: every track is merged.

### 6. Prove the whole

`check-work` on the full diff (it writes the plan's `docs/rolepod/tasks/<plan file name without .md>/verify.md`). No `check-work` → run every task Command and the suite once and report the evidence inline.

Done when: a Verify status is recorded.

## Build it yourself

`Owner: Lead` (R1), or no subagents (then steps 1-6 run here per task):
- Read the touched files end to end, match the style of 2-3 nearby files (invent no patterns), and confirm every symbol the plan expects exists; a planned file missing → verify it, or re-plan.
- Logic → call `tdd-flow` at the agreed seam (the spec's Testing decisions, else the plan task's seam, else the highest existing seam, stated `Seam: <interface>`); a test outside it → one line under `## Follow-ups`.
  No `tdd-flow` → one behavior, one failing test at the agreed seam, the smallest change to green; edge / error / race only with a criterion or an R4 floor; mock only external boundaries.
- Prose, a rename, config, wiring or CRUD pass-through with no rule of its own → no new test; the evidence-after proof its Test / evidence line names.
- Touch only the task: no "while I'm here" refactor, no reformatting, no single-use abstraction; adjacent dead code → flag it. Comments only for a non-obvious why.
- Reuse first: codebase → stdlib → platform feature → installed dependency → minimal new code; a new dependency → ask.
- Changing a behavior, signature or return shape with callers → walk the callers first (code-intel or grep) and decide per caller: absorb, adapt or split.
- Change files through the edit tool, never a shell heredoc, `sed -i` or `tee`.
- A sibling plugin covers the domain → `references/sibling-plugins.md`; no reference → its edit primitive when installed. A step only the human can perform → `references/wizard.md`; no reference → ask the user for that one step and wait.
- Verify on the Command verbatim or cite a matching passing run (`check-work` Evidence cache); a failure → run just those tests on the base tree (`check-work` Run the evidence): red there too = pre-existing, a limitation.
- Failure → the task's **On fail**, else the plan's **Failure policy**, else `debug-issue`. Four failed fixes for one unresolved repro or criterion → stop and ask; one Second opinion after two (`debug-issue` Second opinion); review rounds count separately.

Scope and receipt pairs, good and bad → `examples/execution-examples.md`; no examples → the Artifact line in step 3.

## Guardrails

- Finish the planned task as planned; a new idea is one line under the plan's `## Follow-ups`, never a mid-build redesign.
- Run continuously between tasks: stop only on a BLOCKED after a variable change, or a spec / plan gap or scope ambiguity that survives a re-read. Every dispatch out and nothing unblocked → the turn ends as a wait on something whose end wakes you (CI → `finish-work` CI lanes; no `finish-work` → poll the lane). Forced to end → one line under `## Changes during build`: stopped after Task N · next Task M · how to start the env.
  A wait offers /compact only as the relay of a context-check line → manage-context Compact at seams; no manage-context → ONE line of ~100 characters naming the plan path and the next step, never a question.
- Read the evidence, not the status: never accept `COMPLETED` without its Command tail.

## Next phase

- All tracks shipped and reviewed → `check-work` (step 6); then the merge and the branch's fate belong to `finish-work`.
- `BLOCKED` survives context, model and scope changes and a re-plan → `manage-context` (escalate); if it is not available, stop and hand the user the attempt log and 2-3 options.
- If `check-work` is not available, run tests / build / curl / browser yourself and report evidence inline.
