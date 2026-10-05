---
name: run-tracks
description: Use when a plan's Parallel layout names two or more tracks, a plan names a ship group, a track's diff passes ~800 changed lines or ~15 files, or another session holds a live lock on the base checkout.
---

# Run Tracks

Turns a plan's tracks into merged branches — each built in its own worktree and reviewed at its end.
No worktrees or no parallel agents → run the tracks one after another on the base checkout in plan order; a ship group still gets its drift pass (step 4) and a live lock still moves the plan into one plan worktree (step 1) — only time is lost.

## Skip when

- A Sequential plan with no ship group, no live lock on the base checkout and every track under ~800 changed lines / ~15 files → `implement-plan` alone.
- No plan (a standalone R2 checklist, a debug hand-off, CI red-lane fixes) → the calling skill's own step.

### 1. Lay out the tracks

Tiers here: R2 (routine) and R3 (multi-file) review at track end; R4 (high-risk) reviews per task.
Tracks come from the plan's `## Tracks`; their order comes from each task's **Blocked by** plus the cohesion contract's merge order, never from prose.
Parallel fires only when the plan's **Parallel layout** line declares Parallel with a contract path AND that contract exists. No contract → run the tracks one after another and say why.
A track's dependencies are the tasks in other tracks whose interfaces it consumes; the contract's merge order encodes them.

A track's tasks run in order in one worktree: each task builds, runs its Command and is committed there; an R4 task keeps its round-1 review before its commit, and an R2/R3 task gets no review until the track ends (a track's only code task runs its own two lenses before returning).

A task Blocked by tasks in two or more tracks starts after those tracks merge, as the first task of a new track from the base.

A single-track plan runs on the base checkout unless another session holds a live lock on it when its first task starts; then the whole plan runs in one plan worktree.

Backward compatibility: a plan without `## Tracks` + Parallel layout treats every task as its own track (worktree per task); + Sequential means one track named `plan`. Plans with `## Tracks` use the track-end review of step 4.

Done when: every task has its track, and every track has its worktree, or the base checkout by the single-track rule.

### 2. Dispatch the tracks

Every unblocked track goes out in ONE message — one agent call per track, each owner in its OWN worktree named for the track. Serial needs a stated reason.
The brief and the worktree command → `implement-plan`'s `scripts/ticket.sh start <plan> <N>` (prints both); no `ticket.sh` → the Lead writes the brief from the plan and runs `git worktree add` for the track.
Each brief carries all the track's tasks in order, its file-ownership slice (allowed = its own slice; forbidden = everything else, the do-not-touch list included), the frozen shared interfaces, the tests per task and the done criteria.
Copy the allowed / forbidden paths and the interfaces VERBATIM from the contract: a retyped path list is how a brief drifts from the ownership the contract pinned (`plan-lint.sh` proves plan ↔ contract; the verbatim copy covers contract ↔ brief).
Pipeline, never barrier: the Lead keeps working while owners build, integrates each track as it returns (step 3) without waiting for slower tracks, and answers owner questions inline.

Mid-flight conflicts:
- Two tracks reach for the same file → stop: run them one after another, or rewrite the contract.
- A track needs a file outside its slice → it returns `NEEDS: <path> — <one-line change>`; amend the contract (every owner re-briefed) or drop to sequential. Never widen a slice silently.
- A frozen interface must change → stop every affected track, renegotiate the contract, redispatch; cheaper than merging two halves built against different contracts.
- One track `BLOCKED` while others run → let them finish; change a variable (context, model, scope) on the blocked one. Its dependents wait; independent tracks do not.

Parallel buys wall-clock, not tokens: dispatch it for speed, never to use more agents.

Session split — the contract's optional **Session split** section assigns tracks to separate CLI sessions (an API track on one CLI, a UI track on another), each with its kickoff prompt:
- Each session runs its own Lead: its track's tasks in one worktree, its own track-end review (step 4; R4 per task), and it COMMITS its own slice. The subagent commit ban binds subagents, not session Leads; branch isolation plus the contract's merge order keep the atomicity.
- Disk is the only shared truth: plan and contract are CLI-agnostic files; each session flips only its OWN tasks' checkboxes, so the union merges cleanly. A session that edits another track's tasks, files or checkboxes has broken the contract.
- One branch or worktree per track whenever slices share filesystem state (generated files, build artifacts, lockfiles); two sessions in one worktree stomp each other.
- The integration session named in the contract merges (step 5) and runs the ship-group drift pass (step 4). A per-track review never substitutes for that pass — cross-task drift is what no single track can see.
- A frozen interface change stops every affected session: renegotiate in the contract file, re-kickoff the affected tracks.

Done when: every ready track is out, or the reason for running them serially is stated.

### 3. Integrate in the track worktree

The Lead integrates each returned task in its track's worktree (the ship line per task [`implement-plan` step 3: `ticket.sh integrate` → commit → `log`]; no `ticket.sh` → the commit check, `git commit`, one `## Changes during build` line; a harness-made worktree the same way): the commit gate finds the owner's reviewer evidence there.
- Each task in the track commits once ready; no `finish` until the track ends.
- A harness-made worktree, or a commit refused because the Lead's branch moved → `git cherry-pick <sha>` (a conflict ends with `git cherry-pick --continue`, never a new `git commit`), then (after all tasks integrate) remove the worktree, delete its branch, and run the `log` step (record each task: `ticket.sh log <plan> <N> --sha <sha> --note '<text>'` flips its boxes and appends the Changes line; no `ticket.sh` → flip the boxes by hand and add one `## Changes during build` line per task with the cherry-picked sha).
- Integrated → stop the owner (TaskStop, or the CLI's close) in the same turn. Its return notes background work still running → stop that at once; leftover work runs for hours unwatched.
- An owner's return whose last line is `WAITING: <report paths>` is mid-task → `implement-plan` step 3 (the relay); no `implement-plan` → never integrate or stop it, and a report that reaches you goes to the owner as `Report in: <path>` in the same turn.
- Before any cleanup, preserve an older worktree receipt to the named base path first. A differing destination is a collision: stop cleanup and report it. Do not create another report or handoff.

Done when: each returned task is committed in its track worktree and its owner is stopped.

### 4. Review the track

Track end: a track with two or more code tasks → one fresh owner (the role owning most of the track's code) runs the two `universal-reviewer` lenses in ONE message on the track diff `ticket.sh log` names and fixes each BLOCKER / MAJOR (`review-code` Fix-verify); a track with one code task → its owner ran them before returning; a docs-only track → none.
No `ticket.sh` → the track diff is `git diff <base>...<track branch>`.
The fix re-check → `review-code` Fix-verify (rounds and closure); no `review-code` → one fresh `universal-reviewer` re-checks only each fix's delta, at most four rounds in all.
The Lead commits the fixes in the track worktree.

Over ~800 changed lines or ~15 files in one track → size slices:
- Slices by task, in plan order, each within that size; a single task over it is its own slice; a Verify fix joins the slice of the task it fixes.
- One fresh owner per slice, all dispatched in ONE message, each reviewing, fixing each BLOCKER / MAJOR and attaching proof on its slice and returning its own brief.
- A slice owner's Files allowed = its tasks' files only (a file two slices share goes to the earlier slice); it writes its slice's diff file for the lenses and runs only its own slice's checks.
- A finding in a file it does not own goes back as `NEEDS:`.
- All slices back → the Lead runs the plan's Command and the commit check once, then commits.
- The track-end review covers the R2/R3 tasks' deltas and any unreviewed Verify fixes; an R4 task's commits are context, covered by their reports (listed in the Scope with their paths), never re-tiered.
- A Verify fix on a high-risk path gets the workflow-mode R4 set on that fix alone before its commit; with no track-end review (docs-only, one code task), a Verify fix nobody reviewed → its owner runs the workflow-mode review set on that fix alone.

A plan's **Ship group** line names tasks that ship under one final review → one drift pass over the group's range after all its tasks:
- A normal review of the cross-task seams at the reviewer's own lens, never adversarial and never a re-review of a task's own diff.
- Scope: symbol / type / method-name drift across tasks, API contract mismatch between producer and consumer, unowned files touched by group members, architecture consistency.
- Reviewer: `security-engineer` when the group holds an R4 task; else the track-end review owner's pass is the drift pass (split by size → a fresh owner's seams-only pass).
- A group spanning tracks → one pass on the cumulative diff after all its tracks merge. Tracks sharing a frozen interface are one group.
- No group named → no drift pass. `check-work` waits until the group clears.

Done when: every track, slice and drift-pass review is closed at its receipts.

### 5. Merge and clean up

Merge the reviewed tracks in the contract's order, running the interface provider's tests before merging its consumers.
The merge → `implement-plan`'s `scripts/ticket.sh finish <worktree>` (merges the track, prints `ready now:` with each fan-in task the merge unblocked); no `ticket.sh` → fast-forward the track branch into the base, `git worktree remove`, `git worktree prune`, delete the branch.
A fan-in task that is ready now starts its new track at step 1.

Done when: every track is merged, its worktree and branch are gone, and its owner is stopped.

## Guardrails

- Give each writer its own worktree. Never put two writers in one worktree.
- Move work between branches by commit (`git cherry-pick`). Never move a diff as a patch — a patch carries no review evidence.

## Next phase

- Back to `implement-plan` step 6 (prove the whole) with the merged tracks.
- If `implement-plan` is not available, report the merged tracks, the tasks still open and the next command.
