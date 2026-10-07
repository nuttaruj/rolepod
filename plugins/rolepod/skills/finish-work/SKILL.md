---
name: finish-work
description: Use when implementation, verification and review are done and the branch's fate is next; the user asks to merge, open a PR, keep the branch open or discard it; or a production launch needs staging.
---

# Finish Work

Phase = Ship: turns a built, reviewed branch into one authorized finish — merge, PR or keep open; discard only on explicit user request — after the pre-merge gate passes.

## Skip when

- The branch is not implementation-complete → `orchestrating-plans` at the plan's next step.
- The user said "don't ship, just experiment".

### 1. Pre-merge gate

One gate, five checks below; required CI lanes are step 2. Workflow mode is the session's carried mode (`using-rolepod`), never re-read at Ship.

Inputs: branch + base · diff summary (files, lines, risk surfaces) · CI per lane · each receipt's Verify status and review reports · the rulings · the user's intent.

A stale base or a conflict → rebase first (`references/ci-triage.md` Merge conflicts; no file → onto the PR's base, merging it in on a published branch, then re-run the Evidence check). A failing gate → fix or report; never merge.

Waiver: a failing check blocks merge unless the user waives that gate by name. A waiver granted at an earlier phase carries forward: quote it in the finish menu (which gate, the user's words), never re-demand the waived work or skip it silently.

- **Evidence** — each receipt's Verify status, plus ONE full-suite run through `check-work` on the plan's full diff, whose block names the `Verified tree` id. `UNVERIFIED` or `PARTIAL` blocks merge; green tests alone do not satisfy it. Wrong-surface, flaky or skipped evidence → `check-work` Run it. The `Verified tree` equals `scripts/docs-mode.sh tree HEAD` on a clean tree → cite the block, no re-run (an ignored input the check reads changed since → re-run it).
- **Review reports** — the required set comes per track: the `Review:` and `Track end:` lines `ticket.sh log` printed, never per R4 task; no script → the set below. Every floor stays; a missing, empty or partial required report keeps its round open: its assigned isolated reviewer completes it in that round on the frozen H1, never a Lead substitute (`convening-code-review`).
  - Two or more tracks, or a size-sliced track → the final branch review report from `orchestrating-plans` Final branch review is required; its rulings reach the menu.
- **Snapshot and floor** — a commit past the last Snapshot is a new delta reviewed at its own tier (an R1 delta needs none), never a full re-review.
  - H1 reports stay immutable; never relabel H1.
  - H1 is reused at H2 only when every H1→H2 change is a verified finding fix closed at the receipt (`convening-code-review` Fix-verify); any other change after H1 is uncovered: surface it and route it at its current tier and mode.
- **QA pass** — once per branch, after the final-review fixes and before the menu: ONE `qa-tester` over `<base>...HEAD` on the flows you name in its brief. No subagents → the Lead does it.
  - Flows = the spec's Testing decisions, else the flows behind the user-visible files the diff touches; none → no pass, one receipt line saying so.
  - A QA finding → `convening-code-review` Fix-verify, with `qa-tester` rerunning only the failed flows. An open user-visible failure is the user's call at the menu.
  - QA tests or fixes are commits past the last Snapshot: a new delta at its own tier.
- **PR scope** — one concern per PR / merge. Mixed concerns → split first (`git add -p`, separate branches); a mixed diff is unreviewable.

**Review set** (round 1; mode unknown → Lite). Lite, any tier: the two lenses only. Standard: R2 the two lenses, a matched row adds that role · R3 the two lenses + each matched specialist · R4 the two lenses + `security-engineer` (`depth: checklist`). Full: as Standard, but R4 `depth: full` + one adversarial pass.

Done when: the gate passes, or each failure is fixed, reported, or waived in the user's quoted words.

### 2. CI lanes

Every required lane is green before merge. The required lanes come from the repo's branch protection / CI config (`references/ci-triage.md`); no file → read them and run those.
- No CI configured (a direct deploy included) and the tree changed since the Evidence block → run locally, BEFORE the merge / deploy, the checks the repo defines (lint / typecheck / test / build) covering the change; unchanged → cite the block. Never invent a check the repo does not have. A deploy always gets one post-deploy smoke (curl the live endpoint / health probe) as its evidence.
- A red required lane → triage it by cause (`references/ci-triage.md`; no file → your diff, a flake, infra, a wider regression or a broken lane), then brief the lane's owner: diff-caused → the path's owner, infra → `devops-sre`, an R1-sized fix or no subagents → the Lead. Never merge over a red required lane or auto-merge a PR with one; never delete or skip a failing test to go green. Several red lanes → `coordinating-parallel-tracks` for disjoint owners; none → one owner at a time.
  - Merge intent approved → triage, fix and re-run until the required lanes are green, without asking again each round.
- A required lane still running once the merge is authorized, and the repo allows auto-merge (`gh api repos/{owner}/{repo} --jq .allow_auto_merge` prints true) → `gh pr merge <n> --auto --match-head-commit <the head sha the gate passed>`. Every `gh pr merge` carries `--match-head-commit`; a push after the gate → re-arm only once that delta is reviewed at its tier (Snapshot and floor).
- Armed auto-merge is not a merge: report "merge pending (auto)"; the ship line and cleanup wait until `gh pr view <n> --json state` prints `MERGED`.
- A PR open with required lanes, merge authorized or not → in that same turn ONE `gh pr checks <n> --watch --fail-fast` ~10 s after the push, as a background command whose exit wakes you; foreground only on a CLI with no background command. Never a poll loop, schedule or cron.
  On wake: red → triage and fix on the PR branch; green and the merge authorized → merge (with the head guard above); green, not authorized → ask once, naming the PR. Never end a turn on "ping me", "I'll merge when CI passes" or the like, in any language, while a lane runs with nothing to wake you; no way to wait → tell the user the merge is not done.
- CI / deploy / rollback / monitoring → `devops-sre`. Brief: branch, diff summary, CI status, review verdict, launch plan. No subagents → the Lead does it.

Done when: every required lane is green, or with no CI its local equivalents passed or the Evidence block still covers this tree.

### 3. Detect the environment

`GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P); GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)`, then `git symbolic-ref -q HEAD`: the same dir → a normal repo, 3 options (merge / PR / keep open) + discard on request, no worktree cleanup; different on a named branch → 3 options + discard on request + cleanup; detached HEAD → **2 options (PR / keep open) + discard on request**, externally managed cleanup.

Done when: the menu size and the cleanup owner are known.

### 4. Finish menu

| Option | When | Valid in detached HEAD? |
|--------|------|-------------------------|
| **Merge to main** | All gates green, user authorized | no |
| **Open PR** | Needs upstream review or CI on the PR runner | yes |
| **Keep open** | More work planned; checkpoint commit only | yes |

Fill `templates/finish-menu.md` (no template → gate status, Rulings made, options, follow-ups carried, recommendation, awaiting authorization for).
- Rulings made, shown before the menu: every `Ruling:` line in this work's receipts, each with what it costs if the ruling is wrong; a parked BLOCKER on a high-risk path is the user's call here, at ship, never mid-plan.
- A follow-up the Lead can close now (a one-line fix, a command, work inside the approved spec) → closed before the menu; in-spec work → a new task through `orchestrating-plans`. Only a follow-up outside the spec or a user decision (money / auth / new scope) is carried, as a question.
- Each carried line lands in the project's one follow-up list — its issue tracker, else `docs/rolepod/backlog.md` — one line per item pointing at its plan or commit; a line this branch closed leaves that list in the same pass.
- State the recommendation and wait for the pick — unless the user's own message already named the action AND the target: that IS the pick; state the gate status plus the single action and act.
- **Keep open** — inspect the gate status first, then a checkpoint commit only: no push, no merge, no cleanup, no new pick.
- **Discard** — never offered; only on the user's request, confirmed per `templates/finish-menu.md` (no template → list the branch, its commits and the worktree path, suggest `git tag backup-<branch>`, proceed only on the literal word `discard`).
- **Merge to main** (local) — `cd` to the main root checkout, check out the base, pull, `git merge <branch>`, then compare `scripts/docs-mode.sh tree HEAD` with the `Verified tree` id. Same tree → reuse the run; different → the full suite once on the merged result before push or cleanup; red → stop, the branch and worktree stay.
- **Open PR** → `templates/pr-body.md`, a title under 70 chars, `gh pr create` with a HEREDOC body; report the PR URL. The worktree stays for PR feedback; review comments on it → `review-code`'s `references/receiving-findings.md`.
- A genuine launch event (first traffic to a new surface, a staged rollout, a migration) → `templates/release-checklist.md` before traffic (no template → rollback, success signal and operational safety, each checked); infrastructure fields only when applicable, else a short omission reason. Any applicable unchecked box → NO-GO. A routine merge on the existing deploy pipeline is no launch: its evidence is the CI lanes, no checklist.
- After any merge: update the spec / plan where reality drifted; document the non-obvious decisions.

Before any merge or push from a worktree: no dispatched agent is still writing there (stop it or ask), then re-read `git status`.

Before any push — **a push publishes the REF, not your commit.** Read `git log --oneline @{push}..HEAD` first; a branch you have not pushed has no `@{push}` (`fatal: no upstream configured`), so read `git log --oneline origin/<base>..HEAD` instead.
- Every commit on that list is yours or cleared by its author for PUBLICATION — approved work is not a cleared push (another session may hold an approved commit unpushed on purpose). Cannot tell → ask that session, then the user.
- Never force-push to unpublish one; that is a second unauthorized act on a shared ref. About to `push --force` or `reset --hard` published history → stop and confirm with the user.
- A 4th PR on the same surface → stop and ask the user.

Worktree cleanup after a merge, in this order: merge → verify → `cd` to the main root → `scripts/docs-mode.sh rescue <wt>` exits 0 → `git worktree remove --force <wt>` → `git worktree prune` → delete the branch. Remove only worktrees we created (under `.worktrees/` or `worktrees/`), never from inside one and never before the merge succeeded; never touch harness-owned workspaces. Save local-only proof first.
- `rescue` exits anything but 0, or `git worktree remove` fails → never add `--force`; show `git -C <wt> status --porcelain -uall` and ask: commit it, move it to the main root, or delete it.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo.
Ship line, written only after the authorized action actually completed (a failed or pending command logs nothing — report that instead), chained onto the ship command itself (`gh pr create` included; `discard` logs unconditionally): `{"ts":"<iso8601>","phase":"ship","action":"<merge|pr|keep-open|discard>","commit":"<shipped head sha, or none>"}`.

Done when: the authorized action completed and its ship line is appended, or the menu waits on the user's pick.

## Guardrails

- Act on the user's explicit authorization for THIS specific action. Never push to main, force-push, merge a PR or stage a launch without it; approval for unrelated work does not count, a PR is not a merge, one target is not another → stop and ask.

Authorization and PR body, good vs bad → `examples/finish-examples.md`.

## Next phase

- Branch closed (merged / PR / discarded) → `using-rolepod` for the next request, with the shipped action and its ship line.
- Branch kept open → `orchestrating-plans` at the plan's next step, or `debug-issue` with the failing command tail quoted.
- No other skill → stop and tell the user the shipped action, each open ruling, and what is still unverified or unreviewed, with the receipt and `verify.md` paths.
