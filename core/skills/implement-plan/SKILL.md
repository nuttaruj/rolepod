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

- Lint a plan file before the first task: `plan-lint.sh <plan>` (`../write-plan/scripts/plan-lint.sh`, relative to this skill's folder). FAIL (no **Command**, no checkboxes, a broken Blocked-by graph) → back to `write-plan`; never build on it.
- No `plan-lint.sh` → check the plan file by eye: a **Command** and checkboxes per task, an acyclic Blocked-by graph, a **Failure policy**.
- An inline chat checklist (R2 one file + test, spec-as-plan R3) has no file: no lint, no temp file; its only check is a verify command on every step.
- Whoever builds the task reads the touched files end-to-end, matches the style of 2-3 nearby files (invent no patterns), and confirms every symbol the plan expects exists — the task owner on a delegated task, the Lead only on its own R1 (trivial edit) work (no subagents → the Lead). A planned file missing where expected → verify it, or re-plan. The Lead's part on a delegated task is the plan lint and the **Read first** names (Delegate).
- An R2 (one file + test) or spec-as-plan R3 (multi-file) inline checklist is the same contract: run each step's command. Scope grows past one file (its test file included) → stop and write the real plan.
- Whoever builds verifies the task by running its **Command** verbatim, never a re-derived check — the task owner on a delegated task (its decision brief carries the tail), the Lead only on its own R1 work. No Command named → `write-plan` for one.
- Command passes → flip EVERY `- [ ]` under that task to `- [x]` — on a delegated task the Lead flips them from the owner's Command tail (`scripts/ticket.sh log` in the ship line; without it, by hand). A **Test / evidence** proof the Command does not run (browser, manual) is not covered by the flip; do it first.
- Command fails → baseline first (never a run before the first edit): run only the failing tests once on the tree without this task's diff — a throwaway `git worktree` at HEAD; it cannot run them → set the diff aside in place, run, restore. Red there too → pre-existing: a limitation in the decision brief, and the Command counts as passing when the rest is green. Green there → this task's failure, handled below.
- This task's failure → the task's **On fail**, else the plan's **Failure policy**, else (an R2 checklist has neither) `debug-issue`. The same criterion failing a 2nd time → `debug-issue`, its brief carrying `Attempts: <n> used` with each failed fix and why it stayed red, so its Second opinion caps the attempts (no `debug-issue` → the runner (the Lead without sub-agents) re-traces once; a 2nd failure → stop and report to the user).
- Before the first task commit, record the base sha (`git rev-parse HEAD`) under the plan's `## Changes during build`.
- Shared plan (issue numbers in the header) → claim the task's issue before touching a file (write-plan's `references/team-issues.md`).

Done when: the plan lints clean (or passes the by-eye check; an inline checklist: every step names its verify command), and every file the task touches has been read — by the task owner on a delegated task, by the Lead on its own R1 work.

### 2. Test first at the agreed seams

- Every logic slice runs `tdd-flow` at the agreed seam — the spec's Testing decisions, else the plan task's seam, neither (an R2 checklist, a single-file edit) → the highest existing seam that reaches the behavior, stated `Seam: <interface>`: a failing test at that public interface (never internals) → watch it fail (green before the code → tighten the assertion) → the smallest change → green → the next behavior. Refactor at review, not in the loop.
- `tdd-flow` cannot be opened → these limits still hold: the agreed seam only; one behavior → one test; no test ahead of the behavior; edge / error / race only when an acceptance criterion names it or it is an R4 (high-risk) floor — deny path, money math, migration rollback, shared-state race. Mock only external boundaries, never the DB in an integration test.
- A test outside the agreed seam is scope creep → one line under `## Follow-ups`.
- Prose, a rename, config, wiring or CRUD pass-through with no rule of its own: no new test — the evidence-after proof its Test / evidence line names (render / lint, the suite green plus one smoke, smoke + restart).

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

{{INCLUDE: core/fragments/gates-q1-q4.md}}

The brief comes from the plan, generated when plan-lint exists: `plan-lint.sh --brief <N> <plan> [contract]` prints it; add `--main` for a task that runs on the main checkout (a sequential track), so the brief names no worktree. No plan-lint → the brief is the task block verbatim, plus the spec path and the Bounds: never commit, stay in scope, run the Command, return a decision brief.
- The Lead adds only **Read first** (the 2-3 files and the pattern to copy) and facts the brief lacks. Never extra steps, runs or scope, a reviewer round 2 included.
- A wide-effort session (the `cross-family` skill's rule) → every owner brief carries `External: off — wide-effort session`: the owner cannot see the Lead's mode, and its cross-family kinds take their pool-off path.
- Never point the owner at the plan file; the brief is its slice.

The task owner NEVER commits and NEVER expands scope:
- A path nobody in the wave owns → touch it, plus one `Also touched:` line in the brief.
- A path another owner holds → leave it, put `NEEDS: <path> — <one-line change>` in the brief and finish the rest; the Lead applies it at integration (R1-sized) or reassigns.

A write mandate goes only to the path's owning role, never a generic agent or a reviewer; a writing stage carries `agentType: 'rolepod:<role>'`, never a bare `agent()` (`references/subagent-dispatch.md`: role, model, brief fields). `write: external` → the owner writes the failing test first, then `cross-family` kind implement; pool off, wide-effort session, or `cross-family` absent → the owner writes the task.

Handle the brief's status (its first word):
- `COMPLETED` over a failing test → reject and re-brief.
- `COMPLETED`, no concerns → Review; with Concerns → resolve correctness and scope concerns first.
- `PARTIAL` → review the done slice, redispatch the remainder narrowed.
- `BLOCKED` → change a variable (context, model, scope); never redispatch unchanged.
- A question or any other first word → answer it or ask for the status, then redispatch.

No subagents → the Lead does it: steps 1-3 on each task, the module (or full) suite green, then `check-work` before claiming done.

Done when: every task has an owner and each dispatched owner has returned a decision brief.

### 5. Parallel tracks

A parallel layout → every unblocked track in ONE message, each owner in its OWN worktree; serial needs a stated reason. Shared files, merge order, track layout → `references/subagent-dispatch.md` Parallel-track dispatch.

C1:
> A track's tasks run in order in one worktree: each task builds, runs its Command and is committed there; an R4 task keeps its round-1 review before its commit, and an R2/R3 task gets no review until the track ends.

The Lead integrates each task in the track's worktree (the ship line per task; a harness-made worktree the same way): the commit gate finds the owner's reviewer evidence there.
- Each task in the track commits once ready, no `finish` until the track ends.
- A harness-made worktree, or a commit refused because the Lead's branch moved → `git cherry-pick <sha>` (a conflict ends with `git cherry-pick --continue`, never a new `git commit`), then (after all tasks integrate) remove the worktree, delete its branch, and run the `log` step.
- Never move the diff as a patch: a patch carries no evidence, and the gate asks for the whole R4 set again.
- Integrated → stop the owner (TaskStop, or the CLI's close) in the same turn; its return notes it stopped with background work still running → stop it at once, since that leftover work runs for hours unwatched (`references/subagent-dispatch.md` Close what finished).
- An owner's return whose last line is `WAITING: <report paths>` is mid-task — never integrate or stop it. A report it names reaches you instead of the owner (the Claude desktop app sends a nested child's end to the Lead) → SendMessage the owner `Report in: <path>` in the same turn — never merge or fix its findings yourself: the owner holds the files in a smaller context, so the relay costs one call.

Done when: every ready track is dispatched and each returned track is integrated in contract order.

### 6. Build and review per track

C2:
> Track end: one fresh owner (the role owning most of the track's code) runs the two lenses in ONE message on the track diff and fixes each BLOCKER / MAJOR with its proof, no round 2; the Lead commits the fixes in the track worktree, then `ticket.sh finish <worktree>` merges the track.

C3:
> A task Blocked by tasks in two or more tracks starts after those tracks merge, as the first task of a new track from the base.

C4:
> A single-track plan runs on the base checkout unless another session holds a live lock on it when its first task starts; then the whole plan runs in one plan worktree.

A task owner's decision brief carries its Command tail. The Lead spot-checks ONE claim (the Proof, or one finding in an R4 report; never an axis walk), then commits the task in the track's worktree.
- A report the brief requires — R4, or a standalone R2 checklist's — missing, failed or empty → a fresh owner runs `review-code` Axes (no review-code → intent, trace, correctness, tests on the diff), recorded as a LIMITATION; its findings go to the task owner as the fix task (a fresh owner of the path once it has stopped), never a Lead edit. An R2/R3 task in a track returns no report by design: its review is the track-end review.
- A diff accepted without its review → stop and have its owner run the review before committing further.

The Lead never runs a review loop itself; it talks to owners. A docs-only track takes no track-end review.
- Over ~800 changed lines or ~15 files in one track → size slices by task, in plan order, each within that size (a single task over it is its own slice; a Verify fix joins the slice of the task it fixes); one fresh owner per slice, all dispatched in ONE message, each reviewing, fixing each BLOCKER / MAJOR and attaching proof on its slice and returning its own brief. Within the size → one owner, as above.
- A slice owner's Files allowed = its tasks' files only (a file two slices share goes to the earlier slice), and it writes its slice's diff file for the lenses. A named ship group still bounds its own review; the size split applies inside it, and one seams-only drift pass by a fresh owner still covers the group. A slice owner runs only its own slice's checks; a finding in a file it does not own goes back as `NEEDS:`. All slices back → the Lead runs the plan's Command and the commit check once, then commits.
- The track-end review reviews the R2/R3 tasks' deltas and any unreviewed Verify fixes; an R4 task's commits are context, covered by their reports (listed in the Scope with their paths), never re-tiered. A Verify fix on a high-risk path gets the R4 round-1 set on that fix alone, before its commit; with no track-end review (docs-only), a Verify fix nobody reviewed → its owner runs the two lenses on that fix alone.
- A plan that names a ship group within a track → after all its tasks, one drift pass over the group's range, a normal review of the cross-task seams (never adversarial): `security-engineer` when it holds an R4 task, else the track-end review owner's pass is the drift pass (split by size → a fresh owner's seams-only pass). Ship groups across tracks: drift pass after all tracks of the group merge.
- Findings → ONE fix task to the owning role (`review-code` Fix-verify rounds).
- Round 2+ — R2/R3: none; the owner fixes each BLOCKER / MAJOR and attaches its proof (the Command tail, the reviewer's repro re-run, or the grep showing the old line gone). R4: only a finding raised by `security-engineer` or the adversarial pass whose fix touches code — the flagging role re-checks the fix delta only, on a balanced model (an external's finding → `security-engineer` for security-class, else `universal-reviewer`); at most 5 rounds, rounds 4-5 a fresh fixer on a stronger model; still open after round 5 → stop and hand the user the open findings with the attempt log.
- Nothing pushes or releases before it.

R4 tasks keep per-task review: the owner dispatches its reviewers before returning. Who reviews at each tier → `review-code` Pick reviewers.

One task per pass: brief → spot-check + commit in track worktree → next task. Never batch tasks into one diff.

Artifact: `templates/implementation-manifest.md` — Files changed, Tests added / changed, Verification, Scope check, Concerns, Status. A subagent returns it; the Lead integrates it in the track worktree.

Done when: every track is shipped with its track-end review (or no review for docs-only tracks); then the Lead runs `check-work` on the full diff before release.

## Guardrails

- Finish the planned task as planned. Never expand scope or silently redesign the plan mid-build: a new idea is one line under the plan's `## Follow-ups`.
- Run continuously between tasks and plan phases. Never ask "should I continue?" or end the turn mid-plan; an ended turn is a stop however it is worded. Stop only on a BLOCKED (after a variable change), a spec / plan gap, or a scope ambiguity that SURVIVES a re-read of the plan and the touched files. Forced to end anyway (usage limit, context, user stop) → the last act is one line under the plan's `## Changes during build`: stopped after Task N · next Task M · how to start the env.
- Every ready dispatch out, sub-agents running in the background, nothing unblocked left → the turn ends as a wait, not a stop: a return resumes the Lead. A wait counts only on something whose end wakes you (a sub-agent, a background command); CI or any other external job returns nothing → `finish-work` CI lanes (the pending-lane wait).
- A wait offers the compact only as the relay of a context-check line (context past the hook's line) that arrived since the last compact and is not yet relayed; none → no offer. The offer is ONE line of ~100 characters or fewer, never a question: your CLI's compact command (Claude `/compact <focus>`), the focus naming the plan path (or "inline checklist") and the next step. A longer one wraps in the terminal, and a multi-line paste reaches the CLI as text, not a command.
- Read the evidence, not the status. Never accept `COMPLETED` without its Command tail.

Scope and manifest pairs, good and bad → `examples/execution-examples.md`.

## Next phase

- After all tracks are shipped and reviewed, `check-work` proves the full change works; then the merge and the branch's fate belong to `finish-work`.
- `BLOCKED` survives context, model and scope changes and a re-plan → `manage-context` (escalate); if it is not available, stop and hand the user the attempt log and 2-3 options.
- If `check-work` is not available, run tests / build / curl / browser yourself and report evidence inline.
