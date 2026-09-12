---
name: finish-work
description: Use at the end of a development branch — pre-merge gate, CI lane discipline, 4-option finish menu (merge, PR, keep open, discard), release checklist for production launches. Phase = Ship.
---

# Finish Work

Close out a branch safely: pre-merge gate, four finish options, launch ritual when production traffic is involved.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER push to main, force-push, merge a PR, or stage a launch without explicit user authorization for THIS specific action. Prior approval for unrelated work does not transfer.
2. NEVER auto-merge a PR with a failing required CI lane.
3. NEVER skip the pre-merge gate (simplicity + tests + failure-mode + evidence + reviewer + PR scope) because "the diff is small". A user waiver granted at an earlier phase carries forward — quote it in the finish menu's gate status (which gate, the user's words) instead of re-demanding the waived work or skipping silently.
4. The reviewer who flagged a BLOCKER is not the final authority on whether it is fixed, and neither is its author — a reviewer who did not write the fix confirms before merge (Lead-built fix → qa-tester; R4 → the internal strong reviewer; the Lead never approves its own fix).
5. Worktree cleanup order: merge → verify → `cd` to the main root → `git worktree remove` → `git worktree prune` → delete branch. Reversed order leaves stuck refs. Only remove worktrees we created (under `.worktrees/` or `worktrees/`); never touch harness-owned workspaces.
</EXTREMELY-IMPORTANT>

## When to use

- Implementation done, verified, reviewed · branch ready to merge or PR · a long-running branch needs a keep / discard decision · a production launch needs a rollback plan · CI is red and needs triage before merge.

Skip when:
- The branch is not implementation-complete.
- The user said "don't ship, just experiment".

## Boundary

Owns: branch fate (merge, PR, keep open, discard) · pre-merge gate · CI lane discipline · release / launch checklist.

Does not own: new feature scope · new review discovery beyond gate failures · implementing fixes.

Hand off:
- Gate fails on evidence → `check-work`.
- Gate fails on reviewer / blocker → `review-code` or `implement-plan`.
- User has not authorized merge / push → ask, do not act.

## Workflow

Inputs: branch + base · diff summary (files, lines, risk surfaces) · CI status per lane · the review verdict (`APPROVED` / `APPROVED-WITH-NITS` / `REJECTED`) and check-work's evidence block (`Status:` line) · the user's stated intent.

### 1. Pre-merge gate

Run all six before any merge / push action. Any failure → fix or report; do not merge.

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

**Tests (T1-T6)** — block on a failure:

```
T1: Task needs a test (bug / feature / migration / auth / billing / race /
    contract / perf / security) and none exists?   → write it
T2: New tests pass?      T3: Existing tests pass — and none weakened
    to get there (loosened assertion / deleted case / skip = T3 fail)?
T4: Tier-appropriate speed?    T5: Isolated — no order, clock or seed
    dependency (no literal date · one frozen now · expectations from spec)?
T6: Assertion tight — a 1-char bug still passes? → tighten (`is not None` → `== expected`)
```
Skip only when ALL hold: ≤5 lines · single file · zero logic-bearing (user-facing string text alone counts as zero) · NOT a high-risk path (= rigor tier R1). Any fail → write the test.

**Failure-mode (F1-F5)** — check-work's gate; do not merge with an unresolved F-finding.

**Evidence** — check-work's `Status: UNVERIFIED` or `PARTIAL` blocks merge unless the user explicitly waives it (quote the waiver in the menu); green tests alone do not satisfy this gate. Tree unchanged since that block's recorded pass → cite it and skip the local re-run ONLY when a CI lane re-runs that scope on the merge path; no CI → run the Phase 1+2 equivalents locally before the irreversible act (§2).

**Reviewer** — risk-appropriate review completed (`review-code`). On a high-risk diff read the report's **Cross-model adversarial pass** line: `NOT RUN — cross-family off (opt-in)` is the user's own choice — one neutral line in the summary. `NOT RUN` for any other reason (pool failed / empty, family unknown) or `vertical — same family` is a verification limitation the user must see before merge; state it, never clear the gate silently.

**PR scope (P)** — one concern per PR / merge. Mixed concerns → split (`git add -p`, separate branches) first; a mixed diff is unreviewable.

### 2. CI lane discipline

| Lane | Content | Required for merge? |
|------|---------|---------------------|
| Phase 1 (always-on, < 5 min) | lint · typecheck · smoke unit · auth / tenant guard · money core · migration apply · build | YES |
| Phase 2 (path-triggered) | the touched module's full suite | YES when triggered |
| Phase 3 (nightly / manual) | integration · E2E · chaos · security deep · perf benchmark | NO by default — YES if the repo's own required checks list it (read branch protection / CI config first; never demote a repo-required lane on this table's say-so) |

**No CI configured** (local-only repo, direct deploy — `wrangler deploy` / `flyctl` / rsync): CI is a runner, not the requirement. Run the Phase 1 equivalent (lint · typecheck · smoke) + Phase 2 equivalent (touched module's full suite) locally BEFORE the merge / deploy, and a post-deploy smoke (curl the live endpoint / health probe) as deploy evidence.

Red required lane → the Lead fixes and re-pushes; no per-iteration permission once merge intent is approved. Triage the cause before re-running: `references/ci-triage.md`.

### 3. Detect environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P); GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

- `GIT_DIR == GIT_COMMON` → normal repo: 4-option menu, no worktree cleanup.
- `GIT_DIR != GIT_COMMON`, named branch → 4-option menu, cleanup per Iron Rule 5.
- `GIT_DIR != GIT_COMMON`, detached HEAD → **3-option menu (no local merge)**, externally managed cleanup.

### 4. Finish menu

| Option | When | Valid in detached HEAD? |
|--------|------|-------------------------|
| **Merge to main** | All gates green, user authorized | no |
| **Open PR** | Needs upstream review or CI on the PR runner | yes |
| **Keep open** | More work planned; checkpoint commit only | yes |
| **Discard** | An experiment that did not pan out | yes |

**Stale base / conflict.** Rebase onto the latest integration target — explicit user request > the PR's base > the repo's default branch; conflicting signals → ask, never assume `main` (merge the target in instead when the branch is already published) — before the gate. Resolution rules (pick-sides vs abort-and-reconcile) and the mandatory `check-work` re-run: `references/ci-triage.md` (Merge conflicts).

**Typed confirmation for Discard.** The user types the literal word `discard`. Generic yes / ok / sure is not enough — destructive ops need shape-matching confirmation.

Fill `templates/finish-menu.md` — gate status, the 3 or 4 options, the recommendation, the one action awaiting authorization. State the recommendation and wait for the pick — unless the user's own message already named the action AND the target: that IS the pick; state gate status plus the single action and act. Authorization never widens (a PR is not a merge, one target is not another). Keep open proceeds on the named ACTION alone (a checkpoint commit: no push, no merge, no cleanup); Merge, Open PR and Discard need action AND target; Iron Rule 1 and the typed-`discard` rule stand.

### 5. PR composition

Fill `templates/pr-body.md` — summary, test plan checklist, risks, linked artifacts. Title under 70 chars. `gh pr create` with a HEREDOC body. Do NOT clean up the worktree on this path — the user iterates on PR feedback there.

### 6. Launch + post-merge

A genuine launch event (first traffic to a new surface, a staged rollout, a migration) — not a routine merge riding the existing deploy pipeline (its evidence is §2) — fills `templates/release-checklist.md`: rollback, monitoring, on-call, feature-flag default, migration safety confirmed before traffic. Post-merge: update spec / plan if reality drifted; document non-obvious decisions.

## If a matching Rolepod agent is available

- `devops-sre` — CI / deploy / rollback / monitoring
- `qa-tester` — final pre-merge correctness floor
- `security-engineer` — security gate on high-risk diffs

Brief: branch, diff summary, CI status, review verdict, launch plan if any.

## If no matching agent is available

Execute as Lead: §1 gate (S+T+F + Evidence + Reviewer + PR scope) → §2 lanes green → §3 detect → §4 menu, wait for the pick unless the message named action AND target (or Keep open alone) → PR: title + body + test plan; merge: only with explicit authorization; launch: rollback + monitoring + on-call confirmed first; discard: typed `discard`, suggest a `git tag` or branch backup before delete.

## Output

The finish menu is the canonical artifact: `templates/finish-menu.md` — gate status, the options, the plan's `## Follow-ups` each with a destination (next spec / issue / dropped + why — a parked idea never leaves silently), the recommendation, the action awaiting authorization. PR path adds `templates/pr-body.md`; a launch adds `templates/release-checklist.md`.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo. On a CLI without hooks the Lead writes every line itself.
Ship line, written only after the authorized action actually completed (a failed or pending command logs nothing — report that instead), chained onto the ship command itself (`discard` logs unconditionally): `{"ts":"<iso8601>","phase":"ship","action":"<merge|pr|keep-open|discard>","commit":"<shipped head sha, or none>"}`.

## References

Load only when needed:
- `references/ci-triage.md` — triage a red required lane by cause before re-running; merge-conflict resolution.
- `examples/finish-examples.md` — an authorization-discipline finish and a PR-body pair, good/bad.

## Hard stops

- User has not authorized THIS specific ship action → stop, ask.
- Required CI lane red → fix or report; do not merge.
- High-risk diff without adversarial review → back to `review-code`.
- About to push --force or reset --hard published history → stop, confirm.
- 3rd PR on the same surface, or 3rd agent on the same issue → stop, ask.
- Launch with no rollback plan, monitoring, or on-call confirmed → do not send traffic.
- About to `git worktree remove` from inside the worktree, before merge succeeded, or outside `.worktrees/` / `worktrees/` → stop; Iron Rule 5.
- Discard requested with generic confirmation ("ok" / "yes" / "sure") → require typed `discard`.

## Next phase

- Branch closed (merged / PR / discarded) → return to `using-rolepod` for the next request.
- Branch kept open → continue in `implement-plan` or `debug-issue`.
