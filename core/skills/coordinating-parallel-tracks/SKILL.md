---
name: coordinating-parallel-tracks
description: Use when a plan's Parallel layout names two or more tracks, a track's diff passes ~800 changed lines or ~15 files, or another session holds a live lock on the base checkout.
---

# Coordinating Parallel Tracks

Turns a plan's tracks into merged branches — each built in its own worktree and reviewed at its end — ready for the final branch review.
No worktrees or no parallel agents → run the tracks one after another in plan order; only time is lost.

## Skip when

- A Sequential plan with no live lock on the base checkout and every track under ~800 changed lines / ~15 files → `orchestrating-plans` alone.
- No plan (a standalone R2 checklist, a debug hand-off, CI red-lane fixes) → the calling skill's own step.

### 1. Lay out the tracks

Tracks come from the plan's `## Tracks`; their order comes from each task's **Blocked by** plus the cohesion contract's merge order, never from prose.
Parallel fires only when the plan's **Parallel layout** line declares Parallel with a contract path AND that contract exists. No contract → run the tracks one after another and say why.
A track's dependencies are the tasks in other tracks whose interfaces it consumes; the contract's merge order encodes them.

A track's tasks run in order in one worktree: each task builds, runs its Command and is committed there; its review sits at its seam (`orchestrating-plans` step 4).

A task Blocked by tasks in two or more tracks starts after those tracks merge, as the first task of a new track from the base.

A single-track plan runs on the base checkout unless another session holds a live lock on it when its first task starts; then the whole plan runs in one plan worktree.

Backward compatibility: a plan without `## Tracks` + Parallel layout treats every task as its own track (worktree per task); + Sequential means one track named `plan`.

Done when: every task has its track, and every track has its worktree, or the base checkout by the single-track rule.

### 2. Dispatch the tracks

Every unblocked track goes out in ONE message — one agent call per track, each owner in its OWN worktree named for the track. Serial needs a stated reason.
The brief and the worktree command → `../implement-plan/scripts/ticket.sh start <plan> <N>` (relative to this skill's folder; prints both); no script → the Lead writes the brief from the plan and runs `git worktree add` for the track.
Each brief carries all the track's tasks in order, its file-ownership slice (allowed = its own slice; forbidden = everything else, the do-not-touch list included), the frozen shared interfaces, the tests per task and the done criteria.
Copy the allowed / forbidden paths and the interfaces VERBATIM from the contract: a retyped path list is how a brief drifts from the ownership the contract pinned (`plan-lint.sh` proves plan ↔ contract; the verbatim copy covers contract ↔ brief).
Pipeline, never barrier: the Lead keeps working while owners build, integrates each track as it returns (step 3) without waiting for slower tracks, and answers owner questions inline.

Mid-flight conflicts:
- Two tracks reach for the same file → stop: run them one after another, or rewrite the contract.
- A track needs a file outside its slice → it returns `NEEDS: <path> — <one-line change>`; amend the contract (every owner re-briefed) or drop to sequential. Never widen a slice silently. A sequential wave takes `NEEDS:` by `orchestrating-plans` step 2.
- A frozen interface must change → stop every affected track, renegotiate the contract, redispatch; cheaper than merging two halves built against different contracts.
- One track `BLOCKED` while others run → let them finish; change a variable (context, model, scope) on the blocked one. Its dependents wait; independent tracks do not.

Parallel buys wall-clock, not tokens: dispatch it for speed, never to use more agents.

Session split — the contract's optional **Session split** section assigns tracks to separate CLI sessions (an API track on one CLI, a UI track on another), each with its kickoff prompt:
- Each session runs its own Lead: its track's tasks in one worktree, its own track-end review (step 4; R4 per task), and it COMMITS its own slice. The subagent commit ban binds subagents, not session Leads; branch isolation plus the contract's merge order keep the atomicity.
- Disk is the only shared truth: plan and contract are CLI-agnostic files; each session flips only its OWN tasks' checkboxes, so the union merges cleanly. A session that edits another track's tasks, files or checkboxes has broken the contract.
- One branch or worktree per track whenever slices share filesystem state (generated files, build artifacts, lockfiles); two sessions in one worktree stomp each other.
- The integration session named in the contract merges (step 5) and runs the final branch review (`orchestrating-plans` step 6). A per-track review never substitutes for it — cross-track drift is what no single track can see.
- A frozen interface change stops every affected session: renegotiate in the contract file, re-kickoff the affected tracks.

Done when: every ready track is out, or the reason for running them serially is stated.

### 3. Integrate in the track worktree

The Lead accepts and integrates each returned task in its track's worktree by `orchestrating-plans` step 3 (the ship line, the owner stopped, the track's last code-task owner kept for its track end, an unreviewed diff reviewed first); the commit gate finds the owner's reviewer evidence there. No `orchestrating-plans` → the commit check, `git commit` and one `## Changes during build` line per task.
- Each task in the track commits once ready; no `finish` until the track ends.
- A harness-made worktree, or a commit refused because the Lead's branch moved → `git cherry-pick <sha>` (a conflict ends with `git cherry-pick --continue`, never a new `git commit`), then (after all tasks integrate) remove the worktree, delete its branch, and record each task: `ticket.sh log <plan> <N> --sha <sha> --note '<text>'` flips its boxes and appends the Changes line; no script → flip the boxes by hand and add one `## Changes during build` line per task with the cherry-picked sha.
- Before any cleanup, preserve an older worktree receipt to the named base path first. A differing destination is a collision: stop cleanup and report it. Do not create another report or handoff.

Done when: each returned task is committed in its track worktree and its owner is stopped or kept for its track end.

### 4. Review the track

Track end → the `Track end:` and `Review:` lines `ticket.sh log` prints, run as `orchestrating-plans` step 4; no script → the last code task's owner runs `convening-code-review` on `git diff <base>...<track branch>` with `plan-lint.sh --review-set --tier R3`, and the Lead commits the fixes in the track worktree.

Over ~800 changed lines or ~15 files in one track → size slices:
- Slices by task, in plan order, each within that size; a single task over it is its own slice; a fix after verification joins the slice of the task it fixes.
- One fresh owner per slice, all dispatched in ONE message, each reviewing, fixing each BLOCKER / MAJOR and attaching proof on its slice and returning its own brief.
- A slice owner's Files allowed = its tasks' files only (a file two slices share goes to the earlier slice); it writes its slice's diff file for the lenses and runs only its own slice's checks.
- A finding in a file it does not own goes back as `NEEDS:`.
- All slices back → the Lead runs the plan's Command and the commit check once, then commits.
- The track-end review covers the R2/R3 tasks' deltas and any unreviewed fix after verification; an R4 task's commits are context, covered by their reports (listed in the Scope with their paths), never re-tiered.

A plan's **Ship group** lines are no review here: they are the seam list for the final branch review (`orchestrating-plans` step 6).

Done when: every track and slice review is closed at its receipts.

### 5. Merge and clean up

Merge the reviewed tracks in the contract's order, running the interface provider's tests before merging its consumers.
The merge → `../implement-plan/scripts/ticket.sh finish <worktree>` (merges the track, prints `ready now:` with each fan-in task the merge unblocked); no script → fast-forward the track branch into the base, `git worktree remove`, `git worktree prune`, delete the branch.
A fan-in task that is ready now starts its new track at step 1.

Done when: every track is merged, its worktree and branch are gone, and its owner is stopped.

## Guardrails

- Give each writer its own worktree. Never put two writers in one worktree.
- Move work between branches by commit (`git cherry-pick`). Never move a diff as a patch — a patch carries no review evidence.

## Next phase

- A fan-in task ready now → step 1 for its new track.
- Every track merged → back to `orchestrating-plans` step 6 (final branch review) with the merged tracks.
- No `orchestrating-plans` → stop and report the merged tracks, the tasks still open and the next command.
