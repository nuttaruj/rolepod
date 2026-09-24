---
name: finish-work
description: Use at the end of a development branch — pre-merge gate, CI lane discipline, 4-option finish menu (merge, PR, keep open, discard), release checklist for production launches. Phase = Ship.
when_to_use: when implementation + verification + review are done and the next decision is about the fate of the branch — merge to main, open a PR, keep working, discard, or stage a production launch
---

# Finish Work

Turns a verified, reviewed branch into one authorized finish — merge, PR, keep open or discard — after the six pre-merge gates pass.

## Skip when

- The branch is not implementation-complete.
- The user said "don't ship, just experiment".

### 1. Pre-merge gates

Inputs: branch + base · diff summary (files, lines, risk surfaces) · CI per lane · review verdict · check-work's `Status:` · the user's intent.

A stale base or a conflict → rebase first; the target precedence, the published-branch case and the `check-work` re-run → `references/ci-triage.md` Merge conflicts.

Run all six gates before any merge / push action. A failing gate → fix or report; never merge.
A small diff still runs all six. A user waiver granted at an earlier phase carries forward: quote it in the finish menu's gate status (which gate, the user's words) instead of re-demanding the waived work or skipping silently.

1. **Simplicity (S1-S5)** — revise on any failed check:

- **S1 extra feature** — the diff builds only what was requested; cut the rest.
- **S2 single-use abstraction** — an abstraction with one caller is inlined.
- **S3 unasked config** — no config or flexibility nobody asked for; cut it.
- **S4 impossible case** — defensive code for a case that cannot happen becomes structurally impossible (type system / data model / API constraint), e.g. a runtime null check becomes a compiler-enforced `Optional<T>`. Structure cannot rule it out → the case is NOT impossible: handle it.
- **S5 repeated pattern** — the same pattern in 3+ places is centralized before commit.

A check that fails → revise before commit.

2. **Tests (T1-T6)** — block on a failure:

- **T1 test exists** — a bug, feature, migration, auth, billing, race, contract, perf or security task has a test; none → write it.
- **T2 new tests pass.**
- **T3 existing tests pass, none weakened** — a loosened assertion, a deleted case or a skip to get green is a T3 fail.
- **T4 speed** — the tests run at the speed their tier allows.
- **T5 isolated** — no order, clock or seed dependency: no literal date, one frozen now, expectations taken from the spec.
- **T6 tight assertion** — a 1-char bug makes it fail; tighten a loose one (`is not None` → `== expected`).

Skip when the diff is docs-only (prose / comments / config text / string literals — any size: tests cover the work, not the words), or when ALL hold: ≤5 lines · single file · zero logic-bearing · NOT a high-risk path (= rigor tier R1, trivial edit). Otherwise → write the test.

3. **Failure modes (F1-F5)** — check-work Failure modes; an unresolved F-finding blocks merge. The tree is unchanged since check-work's block → cite its Status for T + F.
4. **Evidence** — check-work's `Status: UNVERIFIED` or `PARTIAL` blocks merge unless the user explicitly waives it; green tests alone do not satisfy this gate. The tree is unchanged since that block's pass → cite it and skip the local re-run ONLY when a CI lane re-runs that scope on the merge path; no CI → run the local equivalents (CI lanes) before the irreversible act. Fails → `check-work`.
5. **Reviewer** — the `review-code` its Pick reviewers asks for is done; an R4 (high-risk) task's reports sit under `.rolepod/evidence/review/`, missing → `review-code` for that task's diff, never the whole branch. The plan names a ship group → its drift-pass report is there too (`implement-plan` Review, `implement-plan`'s `references/subagent-dispatch.md` Ship-group drift pass). Fails, or a BLOCKER is open → `review-code` or `implement-plan`.
   - A BLOCKER fix is confirmed before merge by a reviewer who did not write it — neither the flagging reviewer nor the author is the final authority (Lead-built fix → `universal-reviewer`; R4 → the internal strong reviewer; the Lead never approves its own fix).
   - A high-risk diff → read the report's Cross-model adversarial pass line (`references/reviewer-gate.md`); the report has no such line → read its Reviewers and LIMITATION lines instead. Any limitation recorded is shown to the user before merge, never cleared silently.
6. **PR scope (P)** — one concern per PR / merge. Mixed concerns → split first (`git add -p`, separate branches); a mixed diff is unreviewable.

Done when: all six gates pass, or each failure is fixed, reported, or waived in the user's quoted words.

### 2. CI lanes

Every required lane is green before merge. Phase 1 = the always-on fast lane (lint · typecheck · smoke unit · auth / tenant guard · money core · migration apply · build), always required; Phase 2 = the touched module's full suite, required when path-triggered; Phase 3 = nightly / manual (integration · E2E · chaos · security deep · perf benchmark), required only when the repo's own required checks list it.
- No CI configured → run lint · typecheck · smoke + the touched module's full suite · build locally BEFORE the merge / deploy, and a post-deploy smoke (curl the live endpoint / health probe) as deploy evidence.
- The full lane table and red-lane triage → `references/ci-triage.md`.
- A red required lane → triage it, then the Lead fixes and re-pushes; no per-iteration permission once merge intent is approved. Never merge over a red required lane, and never auto-merge a PR with one.
- CI / deploy / rollback / monitoring → `devops-sre`; E2E / UI proof missing from check-work's block → `qa-tester`. Brief: branch, diff summary, CI status, review verdict, launch plan. No subagents → the Lead does it.

Done when: every required lane is green, or with no CI its local equivalents passed.

### 3. Detect the environment

Compare `git rev-parse --git-dir` with `git rev-parse --git-common-dir` (resolved to absolute paths; command in `references/environment.md`) and check `git symbolic-ref -q HEAD`: the same dir → a normal repo, 4 options, no worktree cleanup; different on a named branch → 4 options + cleanup; detached HEAD → **3 options (no local merge)**, externally managed cleanup.

Done when: the menu size and the cleanup owner are known.

### 4. Finish menu

| Option | When | Valid in detached HEAD? |
|--------|------|-------------------------|
| **Merge to main** | All gates green, user authorized | no |
| **Open PR** | Needs upstream review or CI on the PR runner | yes |
| **Keep open** | More work planned; checkpoint commit only | yes |
| **Discard** | An experiment that did not pan out | yes |

Fill `templates/finish-menu.md`: gate status, options, follow-ups carried, recommendation, awaiting authorization for.
- State the recommendation and wait for the pick — unless the user's own message already named the action AND the target: that IS the pick; state the gate status plus the single action and act.
- Authorization never widens: a PR is not a merge, one target is not another.
- Keep open proceeds on the named ACTION alone (a checkpoint commit: no push, no merge, no cleanup). Merge, Open PR and Discard need action AND target.
- Discard → the user types the literal word `discard`; a generic yes / ok / sure is not enough. Suggest a `git tag` or branch backup before the delete.
- Open PR → `templates/pr-body.md` (summary, test plan, risks, linked artifacts), a title under 70 chars, `gh pr create` with a HEREDOC body; report the PR URL. Leave the worktree in place; the user iterates on PR feedback there.
- A genuine launch event → `templates/release-checklist.md` (rollback, monitoring, feature flag, migration, go / no-go) before traffic; any box unchecked → NO-GO. What counts as a launch → `references/launch.md`.
- After any merge: update the spec / plan where reality drifted; document the non-obvious decisions.

Before any push — **a push publishes the REF, not your commit.** Read `git log --oneline @{push}..HEAD` first; a branch you have not pushed has no `@{push}` (`fatal: no upstream configured`), so read `git log --oneline origin/<base>..HEAD` instead.
- Every commit on that list is yours or cleared by its author for PUBLICATION — approved work is not a cleared push (another session may hold an approved commit unpushed on purpose; your push ends that hold). Cannot tell → ask that session, then the user.
- Never force-push to unpublish one; that is a second unauthorized act on a shared ref.
- About to `push --force` or `reset --hard` published history → stop and confirm with the user.
- A 3rd PR on the same surface, or a 3rd agent on the same issue → stop and ask the user.

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
