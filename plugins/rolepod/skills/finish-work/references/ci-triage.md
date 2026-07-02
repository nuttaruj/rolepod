<!-- Load when a required CI lane is red before merge, or a merge/rebase conflicts. -->

A red required lane blocks the merge. Before re-running or escalating,
triage WHY it is red — the response differs by cause.

## Triage a red lane

| First check | If yes | Action |
|-------------|--------|--------|
| Did your diff cause it? | The failure is in a file / test your branch touched | Fix it on the branch, re-push |
| Is it flaky? | The lane passes on re-run with no code change | Do not paper over it — see debug-issue's `flake-triage.md`; fix the flake or quarantine with an issue |
| Is it infra? | Runner timeout, network error, image-pull fail — unrelated to code | Re-run once; if it persists, escalate to devops-sre |
| Is it a real regression? | A test unrelated to your diff now fails | Stop — your change has a wider blast radius than planned; trace it |
| Is the lane itself broken? | Lane config / a dependency changed on main | Coordinate a main fix; do not merge on top of a broken lane |

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

1. **Rebase onto latest main BEFORE the pre-merge gate** — gates must never
   pass on a stale base and then meet the conflict after.
2. **Trivial conflict** (imports, adjacent independent lines, lockfiles) —
   resolve by picking sides; regenerate lockfiles with their tool. Do not
   author logic inside conflict markers.
3. **Semantic conflict** (both sides changed the same behavior) — abort
   (`git merge --abort` / `git rebase --abort`), read the other side's
   change end-to-end, return to `implement-plan` for a real reconciliation.
4. **After ANY resolution, re-verify** — re-run `check-work` with the same
   Commands. A gate that passed pre-conflict has NOT passed on the resolved
   tree.
5. High-risk surface in the conflict → the adversarial review re-runs on
   the resolved diff before merge.
