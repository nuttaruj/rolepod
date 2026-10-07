---
name: orchestrating-plans
description: Use when you are the Lead and an approved plan, an inline R2 checklist or a spec-as-plan R3 list is ready to run; a plan's next task is unblocked; or the user says to execute the plan — the Lead's Build procedure.
---

# Orchestrating Plans

The Lead's Build: an approved plan → briefed owners, accepted returns, reviews at their seams and merged tracks, one task at a time.
A task in progress → resume Build at that task; never restart Define or Plan.

## Skip when

- A question only.
- The plan is vague, wrong, or names a file that does not exist → `write-plan` first.
- The root cause of a failure is unknown → `debug-issue`.
- You were dispatched to build a task → `implement-plan`.

### 1. Lint the plan

- A plan file → `../write-plan/scripts/plan-lint.sh <plan>` (relative to this skill's folder) before the first task. FAIL → back to `write-plan`; never build on it. No script → check by eye: a **Command** and checkboxes per task, an acyclic Blocked-by graph, a **Failure policy**.
- An inline chat checklist: no lint, no temp file; it is the owner's brief and every step names its verify command. It fits only R2 (one source file plus its own test) or spec-as-plan R3 (≤ 3 approved ordered tasks naming files, verify command and dependencies; one owner; no parallel work, no high-risk path). An added source file, a 4th task, parallel work, a high-risk path, changed acceptance or compaction → `write-plan` the real plan.
- Phase 1 of an approved spec set → `git switch -c <set>` (the map's slug) before the plan base, unless the project's instructions keep work on the base branch; another live session on this checkout → ask the user first.
- Before the first task commit, record the plan base (`git rev-parse HEAD`) under the plan's `## Changes during build`.
- Shared plan (issue numbers in the header) → claim the task's issue before a file is touched (`write-plan` team issues; none → assign it to yourself).

Done when: the plan lints clean (or passes the by-eye check) and the plan base is recorded.

### 2. Brief each ready task

The plan's **Owner:** line wins:
- `Owner: Lead` (R1 only) → load `implement-plan` and build it yourself.
- A named role → the task owner; it builds, runs its brief's reviewers, fixes and returns a decision brief.
- No Owner line → the path's writer role from the agent listing.

- The brief: `../implement-plan/scripts/ticket.sh start <plan> <N>`, or `plan-lint.sh --brief <N> <plan> [contract]` (`--main` for a task on the main checkout). No script → the task block verbatim, the spec path and the Bounds: never commit, stay in scope, run the Command, return a decision brief.
- Add only **Read first** (2-3 files and the pattern to copy) and facts the brief lacks. Tier, Reviewers and Command stay as generated: no extra steps, runs or scope.
- A brief you cannot summarize in one sentence is defective: fix it before dispatch.
- Never point the owner at the plan file; the brief is its slice.
- A Blocked-by task's brief carries each predecessor's Handoff (or its receipt path).
- `NEEDS: <path>` from an owner → apply it at integration (R1-sized) or reassign it.
- A write mandate goes to the path's owning role, never a reviewer: `qa-tester` / `security-engineer` write tests and markdown only.
- A CLI without the named role → `using-rolepod` model tiers; none → a fresh default subagent given the role's text.
- A `security-engineer` dispatch outside a review round binds to Standard / Full.
- One fresh owner per task; a reused one carries Task N's naming into Task N+1.
- A worktree holds tracked files only: a gitignored harness is missing there, so the brief says how the Command gets in, or the owner runs on main.
- Dispatched → `ticket.sh log <plan> <N> --start` per task.

Done when: every ready task is dispatched, independent ones in ONE message.

### 3. Accept and integrate

Read the status, the first word of the decision brief:
- `COMPLETED` over a failing test, or with no Command tail → reject and re-brief.
- `COMPLETED` with Concerns (`Assuming:` lines, residuals, `NEEDS:`) → a correctness or scope concern is resolved first (coverage confirmed, spillover rolled back, or sent back with the case named); an observation → one `## Follow-ups` line.
- `PARTIAL` → review the done slice, redispatch the remainder narrowed, fresh context; never merge an unreviewed partial into the next task.
- `BLOCKED` → change one variable: more context, a stronger tier, a smaller scope, or back to `write-plan`; never redispatch unchanged.
- The same spec section tripping two tasks → the spec is the suspect: pause those tasks, amend it through `write-spec`, re-brief the slice.
- An unreviewed diff → `convening-code-review` on it before you integrate; its findings go back to that owner as one fix brief.
- Any other first word, or a question → answer it or ask for the status, then redispatch.

Validate the receipt, then spot-check ONE claim (the Proof); it fails → the exact discrepancy back to the owner, no commit.
Integrate: a **Test / evidence** proof the Command does not run (browser, manual) runs first; then the ship line (`ticket.sh integrate` → commit → `log`) as ONE Bash call, a red step stopping the chain; no script → the commit check, `git commit`, one `## Changes during build` line (sha, verdict, receipt pointer), and every `- [ ]` under the task flipped. A cleanup from `simplify-code` gets its own commit, apart from the feature commit.
Integrated → stop the owner in the same turn, plus any background work it reports; keep a track's last code-task owner for its track end. One task per pass.

Done when: the task is committed, its boxes flipped, its owner stopped or kept for its track end.

### 4. Review at its seam

- Every code task → its track end (`ticket.sh log`'s `Track end:` / `Review:` lines); a track holding an R4 task takes the mode's R4 set, the threat list in the brief. No script → the last code task's owner runs `convening-code-review` on `git diff <base>...<track branch>` with `plan-lint.sh --review-set --tier <the track's highest tier>`. A docs-only track takes none.
- Findings → ONE fix task to the owning role; rounds, rulings and closure live in `convening-code-review` Fix-verify.
- A missing or partial report keeps its round open; never substitute your own review while agents exist.
- A Lead review ends back here at the plan's next step, else `finish-work`.

Done when: every review is closed at the receipts.

### 5. Tracks

- Two or more tracks, a track over ~800 changed lines / ~15 files, or another session's live lock on the base → `coordinating-parallel-tracks`.
- None → run the tracks one after another on the base in plan order; a live lock → the whole plan in one worktree (`git worktree add .worktrees/<plan> -b <branch>`).

Done when: every track is merged.

### 6. Final branch review

- Two or more tracks, or a size-sliced track → `convening-code-review` with one fresh strong `universal-reviewer`, both axes, on `git diff <plan base>...HEAD` after every merge.
- One unsliced track → none; its track-end review is the branch review.
- The plan's Ship group lines are the seams to check, not a review of their own; an R4 task → `plan-lint.sh --review-set --tier R4` joins on its seam.
- ONE fix dispatch with every finding → ONE delta re-check → the rest ruled at the cap; the rulings go to `finish-work`.
- A spec's `**Phase-end review:**` line → at phase end, one spec-lens pass on `<plan base>...HEAD`, never size-split: its text joins the spec lens of a review on that range (the final branch review, or the only track's track-end review), else one `convening-code-review` pass, spec lens only.

Done when: the final review is closed or ruled, or none is due.

## Guardrails

- Run continuously between tasks: stop only on a `BLOCKED` after a variable change, or a spec / plan gap that survives a re-read. Never ask 'should I continue?'; an ended turn is a stop however it is worded.
- Every dispatch out and nothing unblocked → end the turn on something whose end wakes you, closing with the `ticket.sh status <plan>` output (no script → the same list, one line per task). Opening a PR → load `finish-work` first; no `finish-work` → one checks watch, no poll.
- Forced to end → one `## Changes during build` line: stopped after Task N · next Task M · how to start the env. A wait offers /compact only as a context-check relay (`manage-context`; none → one ~100-char line naming the plan and the next step).
- A new idea → one `## Follow-ups` line, never a mid-build redesign; a follow-up inside the approved spec → a new task, tiered and dispatched.
- The whole suite runs once per release, by you.

## Next phase

- A ready task remains → step 2.
- Plan done and reviewed, a phase of its spec set left → `write-plan` for the next phase, same turn, same branch, no menu, release, push, PR or merge.
- Plan done, no phase left, final review closed or ruled → `finish-work` with the plan, the receipts and the rulings (a spec set: every phase's; full diff `<base>...<set>`).
- `BLOCKED` survives context, tier, scope and a re-plan → `manage-context`; none → stop with the attempt log and 2-3 options.
- No other skill → stop and tell the user what changed, what was verified and what is still unverified or unreviewed, with the receipt paths and each failing Command tail quoted.
