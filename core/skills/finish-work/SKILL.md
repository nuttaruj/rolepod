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

Run the gate before any merge / push action:

```
Simplicity:  S1-S5 (cut beyond-request, abstraction-for-single-use,
             config-nobody-asked, defensive-for-impossible,
             pattern-in-3-places-centralized)
Tests:       T1-T6 (required test exists, new tests pass, existing pass,
             tier-appropriate speed, isolated, assertions tight)
Reviewer:    appropriate review for risk profile completed
Failure-mode: F1-F5 (no hallucinated action, no scope creep, no cascade
             error, no context loss, no destructive misuse)
```

Any failure → fix or report; do not merge.

### 2. CI lane discipline

| Lane | Required for merge? |
|------|---------------------|
| Phase 1 (always-on, < 5 min) | YES |
| Phase 2 (path-triggered) | YES when triggered |
| Phase 3 (nightly / manual) | NO (post-merge notify only) |

Red required lane → Lead fixes and re-pushes; do not ask user permission for each iteration of fix-and-rerun once the merge intent is approved.

### 3. 4-option finish menu

Present concrete options:

| Option | When |
|--------|------|
| **Merge to main** | All gates green, user authorized |
| **Open PR** | Needs upstream review or CI on PR runner |
| **Keep open** | More work planned; checkpoint commit only |
| **Discard** | Branch is an experiment that did not pan out |

State the recommendation. Wait for the user to pick before acting.

### 4. PR composition (if PR path)

Title under 70 chars. Body: Summary (1-3 bullets), Test Plan (checklist), risks. Use `gh pr create` with HEREDOC body. Cite touched files and the spec / plan artifact path if it exists.

### 5. Launch + post-merge (if production)

Launch ritual for production traffic: rollback plan (SHA + revert command), monitoring dashboard URL, alert thresholds named, on-call notified, feature flag default confirmed, migration forward + rollback safe.

Post-merge: update spec / plan if reality drifted, capture non-obvious decisions to MemPalace, queue `gitnexus analyze` if ≥ 5 files changed and the plugin is installed.

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

## Output format

```
Pre-merge gate: PASS / FAIL
CI: phase 1 = <status>, phase 2 = <status>
Review: <verdict>
Recommendation: <merge / PR / keep / discard / launch>
Awaiting user authorization for: <specific action>
```

## Hard stops

- User has not authorized THIS specific ship action → stop, ask
- Required CI lane red → fix or report; do not merge
- High-risk diff without adversarial review → route back to `review-code`
- About to push --force or reset --hard published history → stop, confirm

## Full Rolepod enhancement

Full Rolepod improves this phase by adding the 3-phase CI lane policy, auto-merge wiring when required lanes pass, and the qa-tester floor enforced via hooks. With MemPalace / GitNexus installed (their own vendor plugins), the agent also captures the ship decision and reindexes per the `code-intel` rules.

## Next phase

- Branch closed (merged / PR / discarded) → return to `using-rolepod` for the next request.
- Branch kept open → continue in `implement-plan` or `debug-issue` depending on what is next.
