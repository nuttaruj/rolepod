<!-- Load when deciding which CI lanes a merge needs, when a required lane is red, or when a merge/rebase conflicts. -->

## CI lanes

| Lane | Content | Required for merge? |
|------|---------|---------------------|
| Phase 1 (always-on, < 5 min) | lint · typecheck · smoke unit · auth / tenant guard · money core · migration apply · build | YES |
| Phase 2 (path-triggered) | the touched module's full suite | YES when triggered |
| Phase 3 (nightly / manual) | integration · E2E · chaos · security deep · perf benchmark | NO by default — YES if the repo's own required checks list it (read branch protection / CI config first; never demote a repo-required lane on this table's say-so) |

**No CI configured** (local-only repo, direct deploy — `wrangler deploy` / `flyctl` / rsync): CI is a runner, not the requirement. Run the Phase 1 equivalent (lint · typecheck · smoke) + the Phase 2 equivalent (the touched module's full suite) locally BEFORE the merge / deploy, and a post-deploy smoke (curl the live endpoint / health probe) as deploy evidence.

**Citing check-work's block (the Evidence gate).** The tree is unchanged since that block's recorded pass → cite it and skip the local re-run ONLY when a CI lane re-runs that scope on the merge path; no CI → run the Phase 1 + 2 equivalents locally before the irreversible act.

## Triage a red lane

A red required lane blocks the merge. Before re-running or escalating,
triage WHY it is red — the response differs by cause.

| First check | If yes | Action |
|-------------|--------|--------|
| Did your diff cause it? | The failure is in a file / test your branch touched | Fix it on the branch, re-push |
| Is it flaky? | The lane passes on re-run with no code change | Do not paper over it — see debug-issue's `flake-triage.md`; fix the flake or quarantine with an issue |
| Is it infra? | Runner timeout, network error, image-pull fail — unrelated to code | Re-run once; if it persists, escalate to devops-sre |
| Is it a real regression? | A test unrelated to your diff now fails | Stop — your change has a wider blast radius than planned; trace it |
| Is the lane itself broken? | Lane config / a dependency changed on the target branch | Coordinate a fix on the target branch; do not merge on top of a broken lane |

## Rule
Never merge with a required lane red, and never make a lane green by
deleting or skipping the failing test. A red lane is information — find what
it is telling you before you silence it.

## Once the merge intent is approved
Fix-and-rerun does not need per-iteration user permission. Iterate until the
required lanes are green, then proceed with the authorized merge.

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
   change end-to-end, return to `implement-plan` for a real reconciliation.
4. **After ANY resolution, re-verify** — re-run `check-work` with the
   commands recorded in its evidence block, plus the tests covering any
   module the OTHER side of the conflict touched that those commands never
   ran. A gate that passed pre-conflict has NOT passed on the resolved tree.
5. High-risk surface in the conflict → the adversarial review re-runs on
   the resolved diff before merge.
