---
name: finish-work
description: Use at the end of a development branch — pre-merge gate, CI lane discipline, 4-option finish menu (merge, PR, keep open, discard), release checklist for production launches. Phase = Ship.
when_to_use: when implementation + verification + review are done and the next decision is about the fate of the branch — merge to main, open a PR, keep working, discard, or stage a production launch
tier: 1
phase: ship
---

# Finish Work

Ship-phase entry skill. Close out a branch safely. Run the pre-merge gate, decide between four finish options, and handle launch ritual when production traffic is involved.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER push to main, force-push, merge a PR, or stage a launch without explicit user authorization for THIS specific action. Prior approval for unrelated work does not transfer.
2. NEVER auto-merge a PR with a failing required CI lane.
3. NEVER skip the pre-merge gate (simplicity + tests + reviewer) because "the diff is small".
4. The reviewer who flagged a BLOCKER is not the final authority on whether it is fixed — the qa-tester / Lead floor confirms before merge.
5. Worktree cleanup follows order: merge → verify → `cd` to main root → `git worktree remove` → `git worktree prune` → delete branch. Reversed order leaves stuck refs. Only remove worktrees we created (path under `.worktrees/` or `worktrees/`); never touch harness-owned workspaces.
</EXTREMELY-IMPORTANT>

## When to use

- Implementation done, verified, reviewed
- Branch ready to merge or PR
- Long-running branch needs a stop decision (keep / discard)
- Production launch with rollback plan needed
- CI is red and needs to be triaged before merge

Skip when:
- The branch is not yet implementation-complete
- User explicitly said "don't ship, just experiment"

## Boundary

Owns:
- Branch fate: merge, PR, keep open, discard.
- Pre-merge gate, CI lane discipline, release / launch checklist.

Does not own:
- New feature scope.
- New review discovery except gate failures.
- Implementing fixes directly.

Return / hand off:
- Gate fails on evidence → `check-work`.
- Gate fails on reviewer / blocker → `review-code` or `implement-plan`.
- User has not authorized merge / push → ask, do not act.

## Inputs to gather

- The branch name and base
- Diff summary (files + line count + risk surfaces)
- CI status per lane (Phase 1 required, Phase 2 path-triggered, Phase 3 nightly)
- Review verdict (`APPROVED` / `APPROVED-WITH-NITS` / `REJECTED`)
- The user's stated intent (merge / PR / keep / discard / launch)

## Workflow

### 1. Pre-merge gate

Run all four gates before any merge / push action.

**Simplicity (S1-S5)** — revise on any "yes":

```
S1: Feature beyond request?            → cut
S2: Abstraction for single-use?        → inline
S3: Config / flexibility nobody asked? → cut
S4: Defensive code for impossible?     → make it structurally impossible
                                         (type system / data model / API
                                         constraint); if structure can't, the
                                         case is NOT impossible — handle it
S5: Same pattern in 3+ places?         → centralize before commit
```
Any "yes" → revise before commit. S4 example: a runtime null check becomes a compiler-enforced `Optional<T>`.

**Tests (T1-T6)** — block the commit on a failure:

```
T1: Task needs a test (bug / feature / migration / auth / billing / race /
    contract / perf / security) and none exists?   → write it
T2: New tests pass?      T3: Existing tests pass (no regression)?
T4: Tier-appropriate speed?    T5: Isolated (no order dependency)?
T6: Assertion tight — would a 1-char bug still pass?   → tighten
    (weak: `assert x is not None` · tight: `assert x == expected`)
```
Skip only when ALL hold: ≤5 lines · single file · zero logic-bearing · NOT a high-risk path. Any fail → write the test.

The PreCommit hook also enforces the T-gate.

**Failure-mode (F1-F5)** — run the `check-work` failure-mode gate; do
not merge with an unresolved F-finding.

**Reviewer** — risk-appropriate review completed (see `review-code`).

Any failure → fix or report; do not merge.

### 2. CI lane discipline

| Lane | Content | Required for merge? |
|------|---------|---------------------|
| Phase 1 (always-on, < 5 min) | lint · typecheck · smoke unit · auth / tenant guard · money core · migration apply · build | YES |
| Phase 2 (path-triggered) | the touched module's full test suite | YES when triggered |
| Phase 3 (nightly / manual) | integration · E2E · chaos · security deep · perf benchmark | NO (post-merge notify only) |

Red required lane → Lead fixes and re-pushes; do not ask user permission for each iteration of fix-and-rerun once the merge intent is approved. Triage the cause before re-running — see `references/ci-triage.md`.

### 3. Detect environment

Before presenting the menu, detect the workspace state — it changes which options are valid:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

- `GIT_DIR == GIT_COMMON` → normal repo, 4-option menu, no worktree cleanup
- `GIT_DIR != GIT_COMMON`, named branch → 4-option menu, worktree cleanup per Iron Rule 5
- `GIT_DIR != GIT_COMMON`, detached HEAD → **3-option menu (no local merge)**, externally managed cleanup

### 4. Finish menu

Present concrete options:

| Option | When | Valid in detached HEAD? |
|--------|------|-------------------------|
| **Merge to main** | All gates green, user authorized | no |
| **Open PR** | Needs upstream review or CI on PR runner | yes |
| **Keep open** | More work planned; checkpoint commit only | yes |
| **Discard** | Branch is an experiment that did not pan out | yes |

**Typed confirmation for Discard.** Before destructive deletion, require the user to type the literal word `discard`. Generic yes / ok / sure is not enough — destructive ops need shape-matching confirmation to defeat reflex assent.

Fill `templates/finish-menu.md` — gate status, the available options (3 or 4 per the detection above), the recommendation, and the one specific action awaiting authorization. State the recommendation, then wait for the user to pick before acting.

### 5. PR composition (if PR path)

Fill `templates/pr-body.md` — summary, test plan checklist, risks, linked artifacts. Title under 70 chars. Open with `gh pr create` using a HEREDOC body. **Do not** clean up the worktree on this path — the user iterates on PR feedback in the same workspace.

### 6. Launch + post-merge (if production)

Launch ritual for production traffic: fill `templates/release-checklist.md` — rollback, monitoring, on-call, feature flag default, and migration safety all confirmed before traffic.

Post-merge: update spec / plan if reality drifted, document non-obvious decisions.

## If a matching Rolepod agent is available

Delegate ship work to the closest specialist:

- `devops-sre` for CI / deploy / rollback / monitoring
- `qa-tester` for the final pre-merge correctness floor
- `security-engineer` for the security gate on high-risk diffs
- `product-manager` for launch sequencing and stakeholder comms

Brief: branch, diff summary, CI status, review verdict, launch plan if any.

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Run the pre-merge gate (S+T+F)
2. Confirm Phase 1 + triggered Phase 2 CI lanes are green
3. Present the 4-option finish menu
4. Wait for the user to pick
5. For PR: open with title + body + test plan
6. For merge: run the merge command with the user's explicit authorization
7. For launch: confirm rollback + monitoring + on-call before traffic
8. For discard: confirm intent; suggest a `git tag` or branch backup before delete

## Output

The finish menu is the canonical artifact: `templates/finish-menu.md`. It carries the gate status, the four options, the recommendation, and the specific action awaiting authorization. The PR path adds `templates/pr-body.md`; a production launch adds `templates/release-checklist.md`. Do not restate these shapes here; the templates are the single source.

## Examples

Non-blocking — read only when unsure about authorization or PR quality:
- `examples/finish-examples.md` — an authorization-discipline finish and a PR-body pair, each good/bad with a "why good wins" table. Read the whole file; the contrast is the lesson.

## References

Load only when the task needs it:
- `references/ci-triage.md` — triage a red required CI lane by cause before re-running

## Hard stops

- User has not authorized THIS specific ship action → stop, ask
- Required CI lane red → fix or report; do not merge
- High-risk diff without adversarial review → route back to `review-code`
- About to push --force or reset --hard published history → stop, confirm
- 3rd PR on the same surface, or 3rd agent on the same issue → stop, ask
- Production launch with no rollback plan, monitoring, or on-call confirmed → stop, do not send traffic
- About to `git worktree remove` from inside the worktree, or before merge succeeded, or on a path outside `.worktrees/` / `worktrees/` → stop, Iron Rule 5
- Discard action requested with generic confirmation only ("ok" / "yes" / "sure") → stop, require typed `discard`

## Full Rolepod enhancement

Full Rolepod improves this phase by adding the 3-phase CI lane policy, auto-merge wiring when required lanes pass, and the qa-tester floor enforced via hooks.

## Next phase

- Branch closed (merged / PR / discarded) → return to `using-rolepod` for the next request.
- Branch kept open → continue in `implement-plan` or `debug-issue` depending on what is next.
