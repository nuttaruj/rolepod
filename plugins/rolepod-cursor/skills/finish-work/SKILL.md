---
name: finish-work
description: Use at the end of a development branch — pre-merge gate, CI lane discipline, 3-option finish menu (merge, PR, keep open; discard only on explicit request), release checklist for production launches. Phase = Ship.
---

# Finish Work

Turns a verified, reviewed branch into one authorized finish — merge, PR, or keep open; discard only on explicit user request — after the pre-merge gate passes.

## Skip when

- The branch is not implementation-complete.
- The user said "don't ship, just experiment".

### 1. Pre-merge gate

One pre-merge gate: check-work's Status matches the current tree (else re-run the checks covering the change) · required CI lanes green · review reports and finding-closure provenance cover the current tree, and an R4 diff has its mode-required reports (see Snapshot and floor below) · one concern per PR.

Inputs: branch + base · diff summary (files, lines, risk surfaces) · CI per lane · review verdict · check-work's `Status:` · the user's intent.

A stale base or a conflict → rebase first; the target precedence, the published-branch case and the `check-work` re-run → `references/ci-triage.md` Merge conflicts. A failing gate → fix or report; never merge. A user waiver granted at an earlier phase carries forward: quote it in the finish menu's gate status (which gate, the user's words) instead of re-demanding the waived work or skipping silently.

- **Check-work Status** — `UNVERIFIED` or `PARTIAL` blocks merge unless the user explicitly waives it; green tests alone do not satisfy it. The block's `Verified tree` id equals `git rev-parse HEAD^{tree}` and the tree is clean → cite that block in any session, no local re-run (an ignored input the check reads that changed since → re-run it); another tree → re-run only the checks covering the change; the post-deploy smoke always runs. Fails → `check-work`.
- **Review evidence** — required `review-code` reports and provenance cover this tree. Each multi-code-task track needs its track-end report; a one-code-task track needs its owner's reports; a **Ship group** needs its drift-pass report (`implement-plan` → `references/subagent-dispatch.md`).
  Use named canonical pointers. Before worktree cleanup, retain required local-only proof at its named private path. Evidence already complete on base needs no export or merged copy.
- **Snapshot and floor** — a commit past the last Snapshot is a new delta for `review-code` at its own tier (an R1 delta needs none), never a full re-review. Use the active session mode carried from startup/manual selection; do not re-read configured mode at Ship. Report configured mode separately if inspected. Restart or open a new session to apply config changes.
  - Original lens reports are immutable at H1. A no-recheck branch may reuse H1 only with each finding's repro/test and result, exact bounded H1→H2 delta, and final verified H2 in the report; `check-work` must name a clean H2 tree.
  - Lite R4 requires two isolated reports on the same H1, or, only without agents, the Lead's two-axis walkthrough and independence limitation. No security or adversarial report applies. H1 closure covers H2 only when every delta is a verified finding fix; never relabel H1.
  - R2/R3 and Standard R4 follow their no-recheck rules with the same finding-specific H1→H2 closure evidence. Full R4 re-checks only code-touching fixes for findings raised by `security-engineer` or the adversarial pass, as `review-code` specifies.
  - With agents available, a missing, failed, empty or partial report keeps its same round open; its isolated reviewer completes the report on the same frozen diff before aggregation or ship. Never substitute a Lead review.
  - Unrelated or new changes after H1 are uncovered; surface and route them at their current tier and mode. A green suite alone is not finding-specific closure evidence.
  - Standard R4: the `security-engineer` report is required. Full R4 also needs the adversarial-pass report.
  - A missing required report blocks merge; only the user's waiver naming this gate, quoted in the finish menu, clears it.
- **PR scope** — one concern per PR / merge. Mixed concerns → split first (`git add -p`, separate branches); a mixed diff is unreviewable.

Done when: the gate passes, or each failure is fixed, reported, or waived in the user's quoted words.

### 2. CI lanes

Every required lane is green before merge. Read the repo's required checks first (branch protection, CI config): they decide what is required — never a lane the repo lacks, never a demoted one it requires. Phase 1 = its fast lane (whichever of lint · typecheck · smoke unit · auth / tenant guard · money core · migration apply · build it runs); Phase 2 = the touched module's full suite, when path-triggered; Phase 3 = nightly / manual (integration · E2E · chaos · security deep · perf benchmark), required only when those checks list it.
- No CI configured and the tree changed since check-work's recorded pass → run locally, BEFORE the merge / deploy, the checks the repo defines (its lint / typecheck / test / build scripts or targets that exist) covering the change; unchanged → cite the block. Always a post-deploy smoke (curl the live endpoint / health probe) as deploy evidence. Never invent a check the repo does not have.
- The full lane table and red-lane triage → `references/ci-triage.md`.
- A red required lane → the Lead triages it, then briefs the lane's owner: a diff-caused red → the path's owner fixes it, infra → `devops-sre`, an R1-sized fix or no subagents → the Lead. Several red lanes → triage all first; owners with disjoint files go out in ONE message, each in its OWN worktree (`implement-plan` Parallel-track dispatch), a file two fixes share goes to one owner; the Lead re-pushes once all return. No per-iteration permission once merge intent is approved. Never merge over a red required lane, and never auto-merge a PR with one.
- A required lane still running once the merge is authorized → the repo allows auto-merge (`gh api repos/{owner}/{repo} --jq .allow_auto_merge` prints true; a free private repo cannot) → `gh pr merge <n> --auto` (the user's merge authorization covers it). Never end the turn on "I'll merge when CI passes" with nothing running to wake you.
- No auto-merge, or a next task blocked on the merge → wait on the lane yourself with ONE blocking command that ends when CI does: `gh pr checks <n> --watch --fail-fast`, foreground, long timeout, ~10 s after the push (sooner it exits at once with "no checks reported"); never a poll loop, a schedule or a cron. Never hand the wait to the user ("tell me when CI is green"); no way to wait → tell the user the merge is not done.
- CI / deploy / rollback / monitoring → `devops-sre`; E2E / UI proof missing from check-work's block → back to `check-work` (its one E2E dispatch), never a dispatch from here — unless its Limitations already name it, then gate 4 (the user's waiver). Brief: branch, diff summary, CI status, review verdict, launch plan. No subagents → the Lead does it.

Done when: every required lane is green, or with no CI its local equivalents passed (or check-work's block still holds: gate 4).

### 3. Detect the environment

Compare `git rev-parse --git-dir` with `git rev-parse --git-common-dir` (resolved to absolute paths; command in `references/environment.md`) and check `git symbolic-ref -q HEAD`: the same dir → a normal repo, 3 options (merge / PR / keep open) + discard on request, no worktree cleanup; different on a named branch → 3 options + discard on request + cleanup; detached HEAD → **2 options (PR / keep open) + discard on request**, externally managed cleanup.

Done when: the menu size and the cleanup owner are known.

### 4. Finish menu

| Option | When | Valid in detached HEAD? |
|--------|------|-------------------------|
| **Merge to main** | All gates green, user authorized | no |
| **Open PR** | Needs upstream review or CI on the PR runner | yes |
| **Keep open** | More work planned; checkpoint commit only | yes |

Fill `templates/finish-menu.md`: gate status, options, follow-ups carried, recommendation, awaiting authorization for.
- A follow-up the Lead can close now — a one-line fix, a command, or work inside the approved spec or context it already holds → closed before the menu (in-spec work: a new task, tiered, dispatched to an owner; a high-risk path → R4 with its workflow-mode review set), never carried; only a follow-up outside the spec or a user decision (money / auth / new scope) is carried, as a question. A leftover list without an action or a question is not a finish.
- Each carried line lands in the project's one follow-up list — its issue tracker when it keeps one, else `docs/rolepod/backlog.md`, one line per item with a pointer to the plan or commit it came from. A line this branch closed leaves that list in the same pass; the list holds only what is still open.
- State the recommendation and wait for the pick — unless the user's own message already named the action AND the target: that IS the pick; state the gate status plus the single action and act.
- Authorization never widens: a PR is not a merge, one target is not another.
- Keep open proceeds on the named ACTION alone (a checkpoint commit: no push, no merge, no cleanup). Merge and Open PR need action AND target.
- **Discard** — never offered; only when the user asks. List the branch, its commits and the worktree path that will be lost, suggest `git tag backup-<branch>` first, and proceed only when the user types the literal word `discard`; a generic yes / ok / sure is not enough.
- Open PR → `templates/pr-body.md` (summary, test plan, risks, linked artifacts), a title under 70 chars, `gh pr create` with a HEREDOC body; report the PR URL. Leave the worktree in place; the user iterates on PR feedback there.
- A genuine launch event → `templates/release-checklist.md` (rollback, monitoring, feature flag, migration, go / no-go) before traffic; any box unchecked → NO-GO. What counts as a launch → `references/launch.md`.
- After any merge: update the spec / plan where reality drifted; document the non-obvious decisions.

Before any push — **a push publishes the REF, not your commit.** Read `git log --oneline @{push}..HEAD` first; a branch you have not pushed has no `@{push}` (`fatal: no upstream configured`), so read `git log --oneline origin/<base>..HEAD` instead.
- Every commit on that list is yours or cleared by its author for PUBLICATION — approved work is not a cleared push (another session may hold an approved commit unpushed on purpose; your push ends that hold). Cannot tell → ask that session, then the user.
- Never force-push to unpublish one; that is a second unauthorized act on a shared ref.
- About to `push --force` or `reset --hard` published history → stop and confirm with the user.
- A 4th PR on the same surface → stop and ask the user. Failed fixes for the same unresolved repro or criterion carry a separate four-attempt cap across owners and phases; consult once after two, and stop earlier if no usable advisor exists.

Worktree cleanup after a merge, in this order: merge → verify → `cd` to the main root → `git worktree remove` → `git worktree prune` → delete the branch; the reversed order leaves stuck refs. Remove only worktrees we created (under `.worktrees/` or `worktrees/`), never from inside one and never before the merge succeeded; never touch harness-owned workspaces.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo.
Ship line, written only after the authorized action actually completed (a failed or pending command logs nothing — report that instead), chained onto the ship command itself (`gh pr create` included; `discard` logs unconditionally): `{"ts":"<iso8601>","phase":"ship","action":"<merge|pr|keep-open|discard>","commit":"<shipped head sha, or none>"}`.

Done when: the authorized action completed and its ship line is appended, or the menu waits on the user's pick.

## Guardrails

- Act on the user's explicit authorization for THIS specific action. Never push to main, force-push, merge a PR or stage a launch without it; approval for unrelated work does not count → stop and ask.

Authorization and PR body, good vs bad → `examples/finish-examples.md`.

## Next phase

- Branch closed (merged / PR / discarded) → return to `using-rolepod` for the next request.
- Branch kept open → continue in `implement-plan` or `debug-issue`.
- If the next skill is not available, report the branch state and the shipped action, and ask the user what comes next.
