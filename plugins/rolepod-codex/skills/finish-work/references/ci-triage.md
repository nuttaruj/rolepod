<!-- Load when deciding which CI lanes a merge needs, when a required lane is red, or when a merge/rebase conflicts. -->

## CI lanes

The repo's required checks (branch protection, CI config) decide what is required; this table only sorts them. Never add a lane the repo lacks.

| Lane | Content | Required for merge? |
|------|---------|---------------------|
| Phase 1 (fast, < 5 min) | whichever of lint · typecheck · smoke unit · auth / tenant guard · money core · migration apply · build the repo runs | YES — each one the repo requires |
| Phase 2 (path-triggered) | the touched module's full suite | YES when triggered |
| Phase 3 (nightly / manual) | integration · E2E · chaos · security deep · perf benchmark | NO by default — YES if the repo's own required checks list it (read branch protection / CI config first; never demote a repo-required lane on this table's say-so) |

## Triage a red lane

A red required lane blocks the merge. Before re-running or escalating,
triage WHY it is red — the response differs by cause.

| First check | If yes | Action |
|-------------|--------|--------|
| Is the branch behind its base? | The failure is in code the diff does not touch | `git fetch`, then `git merge-base --is-ancestor origin/<base> HEAD`; not an ancestor → rebase (Merge conflicts below) and re-run, no regression trace |
| Did your diff cause it? | The failure is in a file / test your branch touched | Fix it on the branch, re-push |
| Is it flaky or infra? | Passes on re-run with no code change, or runner timeout / network error / image-pull fail | Re-run once. The same failure on the second run is not a flake → trace it on your diff, or `devops-sre` when it is infra. A real flake → debug-issue's `flake-triage.md`; fix it or quarantine it with an issue |
| Is it a real regression? | A test unrelated to your diff fails on a current base | Stop — your change has a wider blast radius than planned; trace it |
| Is the lane itself broken? | Lane config / a dependency changed on the target branch | Coordinate a fix on the target branch; do not merge on top of a broken lane |

## Merge conflicts

A conflicted merge or rebase is a STOP-and-decide, not a dead end — and not
free rein. Every line written during resolution is NEW, UNREVIEWED code.

Before touching a hunk, read WHY each side changed it — the commit messages,
the PR, the ticket. Resolve toward both intents where they fit; where they
clash, the side that matches the merge's goal wins and the commit message
names the trade-off. Never invent behaviour neither side had to paper over
the clash.

1. **Rebase onto the latest integration target BEFORE the pre-merge gate** — gates must never
   pass on a stale base and then meet the conflict after. The target, in
   precedence order: explicit user request > the PR's base > the repo's
   default branch. Conflicting signals → ask, never assume `main`. The
   branch is already published → merge the target in instead of rebasing.
2. **Trivial conflict** (imports, adjacent independent lines, lockfiles) —
   resolve by picking sides; regenerate lockfiles with their tool. Do not
   author logic inside conflict markers.
3. **Semantic conflict** (both sides changed the same behavior) — abort
   (`git merge --abort` / `git rebase --abort`), read the other side's
   change end-to-end, return to `orchestrating-plans` for a real reconciliation.
4. **After ANY resolution, re-verify** — re-run the commands recorded in the
   Evidence block through `check-work`, plus the tests covering any module
   the OTHER side of the conflict touched. A gate that passed pre-conflict
   has NOT passed on the resolved tree.
5. The resolution is a commit past the last Snapshot: a new delta reviewed at
   its own tier (`SKILL.md` Snapshot and floor).
