---
name: finish-work
description: Use when implementation, verification and review are done and the branch's fate is next; the user asks to merge, open a PR, keep the branch open or discard it; or a production launch needs staging.
---

# Finish Work

Phase = Ship: turns a verified, reviewed branch into one authorized finish — merge, PR or keep open; discard only on explicit user request — after the pre-merge gate passes.

## Skip when

- The branch is not implementation-complete → `implement-plan`.
- The user said "don't ship, just experiment".

### 1. Pre-merge gate

One gate, four checks below; required CI lanes are step 2.

Inputs: branch + base · diff summary (files, lines, risk surfaces) · CI per lane · review verdict · check-work's `Status:` · the user's intent.

A stale base or a conflict → rebase first (`references/ci-triage.md` Merge conflicts; no file → onto the PR's base, merging it in on a published branch, then re-run `check-work`). A failing gate → fix or report; never merge. A user waiver granted at an earlier phase carries forward: quote it in the finish menu's gate status (which gate, the user's words) instead of re-demanding the waived work or skipping silently.

- **Check-work Status** — `UNVERIFIED` or `PARTIAL` blocks merge unless the user explicitly waives it; green tests alone do not satisfy it. The block's `Verified tree` id equals `git rev-parse HEAD^{tree}` and the tree is clean → cite that block (the plan's `docs/rolepod/tasks/<plan file name without .md>/verify.md`, else this session's chat), no local re-run (an ignored input the check reads that changed since → re-run it); another tree → re-run only the checks covering the change; the post-deploy smoke always runs. Fails → `check-work`.
- **Review evidence** — required `review-code` reports and provenance cover this tree. Each multi-code-task track needs its track-end report; a one-code-task track needs its owner's reports; a **Ship group** needs its drift-pass report (`implement-plan` step 5; no `implement-plan` → a fresh reviewer's seams-only pass over the group's range).
  Use named canonical pointers. Before worktree cleanup, retain required local-only proof at its named private path. Evidence already complete on base needs no export or merged copy.
- **Snapshot and floor** — a commit past the last Snapshot is a new delta for `review-code` at its own tier (an R1 delta needs none), never a full re-review.
  Workflow mode = the active session mode carried from startup or the first `using-rolepod` entry; a helper call gets `ROLEPOD_SESSION_MODE` / `ROLEPOD_SESSION_SOURCE`. Never re-read the configured mode at Ship (an inspected one is reported apart); a config change applies in a new session.
  - R4 floors — Lite: the two `universal-reviewer` lenses · Standard: + `security-engineer` (checklist) · Full: + `security-engineer` (full) + one adversarial pass; a missing required report keeps the round open.
  - With agents, the same isolated reviewer completes a missing, failed, empty or partial report on the frozen H1 in that same round; never a Lead substitute. Lite without agents → the Lead's two-axis walkthrough, independence limitation recorded.
  - Full's adversarial evidence = a `ran on <cli>` receipt or an internal strong pass with its reason, never `NOT RUN` or `vertical — same CLI` alone; a CLI that reports no model family is no limitation. A comment/blank-only R4 diff → `review-code`'s exception (no `review-code` → the mode's R4 set, no adversarial pass).
  - H1 reports stay immutable; legacy merged reports stay readable, none newly required.
  - H1 is reused at H2 only when every H1→H2 change is a verified finding fix closed at the receipt (review-code Fix-verify) and check-work names a clean H2 tree.
  - Changes after H1 that are not finding fixes are uncovered: surface and route them at their current tier and mode; never relabel H1.
  - A missing required report blocks merge; only the user's waiver naming this gate, quoted in the finish menu, clears it.
- **PR scope** — one concern per PR / merge. Mixed concerns → split first (`git add -p`, separate branches); a mixed diff is unreviewable.

Done when: the gate passes, or each failure is fixed, reported, or waived in the user's quoted words.

### 2. CI lanes

Every required lane is green before merge. The required lanes come from the repo's branch protection / CI config (`references/ci-triage.md`); no file → read them and run those.
- No CI configured (a direct deploy included; CI is a runner, not the requirement) and the tree changed since check-work's recorded pass → run locally, BEFORE the merge / deploy, the checks the repo defines (its lint / typecheck / test / build scripts or targets that exist) covering the change; unchanged → cite the block. Always a post-deploy smoke (curl the live endpoint / health probe) as deploy evidence. Never invent a check the repo does not have.
- A red required lane → the Lead triages it by cause (`references/ci-triage.md`; no file → your diff, a flake, infra, a wider regression or a broken lane), then briefs the lane's owner: a diff-caused red → the path's owner, infra → `devops-sre`, an R1-sized fix or no subagents → the Lead. Never merge over a red required lane or auto-merge a PR with one; never delete or skip a failing test to go green.
- Several red lanes → triage all first; owners with disjoint files go out in ONE message, each in its OWN worktree (`git worktree add .worktrees/<lane> -b <branch>`), a file two fixes share goes to one owner; no worktrees → one owner at a time. Once all return, the Lead cherry-picks each lane's commits onto the branch and re-pushes; lane worktrees are scratch, removed once their commits are on the branch. No per-iteration permission once merge intent is approved.
- A required lane still running once the merge is authorized, and the repo allows auto-merge (`gh api repos/{owner}/{repo} --jq .allow_auto_merge` prints true; a free private repo cannot) → `gh pr merge <n> --auto` (the merge authorization covers it).
- No auto-merge, or a next task blocked on the merge → ONE blocking `gh pr checks <n> --watch --fail-fast`, foreground, long timeout, ~10 s after the push (sooner it exits with "no checks reported"); never a poll loop, schedule or cron. Never end the turn on "I'll merge when CI passes" with nothing running to wake you, never hand the wait to the user; no way to wait → tell the user the merge is not done.
- CI / deploy / rollback / monitoring → `devops-sre`; E2E / UI proof missing from check-work's block → back to `check-work` (its one E2E dispatch), never a dispatch from here — unless its Limitations already name it, then the user's waiver (step 1). Brief: branch, diff summary, CI status, review verdict, launch plan. No subagents → the Lead does it.

Done when: every required lane is green, or with no CI its local equivalents passed or check-work's block still covers this tree.

### 3. Detect the environment

Compare `git rev-parse --git-dir` with `git rev-parse --git-common-dir`, each resolved by `cd` + `pwd -P` (`references/environment.md` has the line), and check `git symbolic-ref -q HEAD`: the same dir → a normal repo, 3 options (merge / PR / keep open) + discard on request, no worktree cleanup; different on a named branch → 3 options + discard on request + cleanup; detached HEAD → **2 options (PR / keep open) + discard on request**, externally managed cleanup.

Done when: the menu size and the cleanup owner are known.

### 4. Finish menu

| Option | When | Valid in detached HEAD? |
|--------|------|-------------------------|
| **Merge to main** | All gates green, user authorized | no |
| **Open PR** | Needs upstream review or CI on the PR runner | yes |
| **Keep open** | More work planned; checkpoint commit only | yes |

Fill `templates/finish-menu.md` (no template → gate status, Rulings made, options, follow-ups carried, recommendation, awaiting authorization for).
- Rulings made, shown before the menu: every `Ruling:` line in this work's receipts, each with what it costs if the ruling is wrong; a parked BLOCKER on a high-risk path is the user's call here, at ship, never mid-plan.
- A follow-up the Lead can close now — a one-line fix, a command, or work inside the approved spec or context it already holds → closed before the menu (in-spec work: a new task, tiered, dispatched to an owner; a high-risk path → R4 with its workflow-mode review set), never carried; only a follow-up outside the spec or a user decision (money / auth / new scope) is carried, as a question. A leftover list without an action or a question is not a finish.
- Each carried line lands in the project's one follow-up list — its issue tracker when it keeps one, else `docs/rolepod/backlog.md`, one line per item with a pointer to the plan or commit it came from. A line this branch closed leaves that list in the same pass; the list holds only what is still open.
- State the recommendation and wait for the pick — unless the user's own message already named the action AND the target: that IS the pick; state the gate status plus the single action and act.
- Authorization never widens: a PR is not a merge, one target is not another.
- Keep open proceeds on the named ACTION alone (a checkpoint commit: no push, no merge, no cleanup, no new pick). Merge and Open PR need action AND target.
- **Discard** — never offered; only when the user asks. List the branch, its commits and the worktree path that will be lost, suggest `git tag backup-<branch>` first, and proceed only when the user types the literal word `discard`; a generic yes / ok / sure is not enough.
- Open PR → `templates/pr-body.md` (summary, test plan, risks, linked artifacts), a title under 70 chars, `gh pr create` with a HEREDOC body; report the PR URL. Leave the worktree in place; the user iterates on PR feedback there.
- A genuine launch event (first traffic to a new surface, a staged rollout, a migration; `references/launch.md`) → `templates/release-checklist.md` before traffic (no `templates/release-checklist.md` → list rollback, success signal and operational safety, each checked); include infrastructure fields only when applicable, with a short omission reason otherwise. Required rollback, success signal, and operational safety remain; any applicable unchecked box → NO-GO. A routine merge on the existing deploy pipeline is no launch: its evidence is the CI lanes, no checklist.
- After any merge: update the spec / plan where reality drifted; document the non-obvious decisions.

Before any push — **a push publishes the REF, not your commit.** Read `git log --oneline @{push}..HEAD` first; a branch you have not pushed has no `@{push}` (`fatal: no upstream configured`), so read `git log --oneline origin/<base>..HEAD` instead.
- Every commit on that list is yours or cleared by its author for PUBLICATION — approved work is not a cleared push (another session may hold an approved commit unpushed on purpose; your push ends that hold). Cannot tell → ask that session, then the user.
- Never force-push to unpublish one; that is a second unauthorized act on a shared ref.
- About to `push --force` or `reset --hard` published history → stop and confirm with the user.
- A 4th PR on the same surface → stop and ask the user. Four failed fixes for one unresolved repro or criterion → stop and ask; one Second opinion after two (`debug-issue` Second opinion); review rounds count separately.

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
