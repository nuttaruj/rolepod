<!-- Load when a review-code Breaker trigger holds. The trigger list lives in review-code's SKILL.md (Breaker); this file is the steps. -->

# Breaker — steps

Two rounds is the budget: review, then confirm the fixes. A third round is a reassessment point, not another fix.

Round counting: one reviewer's dispatches less than 5 minutes apart on one uncommitted tree count as one round. `cross-family` Re-review a fix prints the count. Rounds never add up across tickets.

Run these steps in order.

## 0. Stop

Write no fix and dispatch no reviewer.
Collect or kill whatever is still running (a detached external: `cross-family` Read the return).

## 1. Ledger

Write `docs/rolepod/handoffs/<feature>-breaker-<date>.md` with three sections:
- `## Rounds` — per round: found → hypothesis → changed → test result → came back.
- `## Class` — the one root cause, its single point, and every consumer. Grep the call sites now.
- `## Decision` — the class fix chosen. Ask the user only when the breaker round fails.

## 2. Class

You cannot name the class or its single point → ONE consult asking exactly that: the CLI's native advisor, else `cross-family` kind consult with the ledger; neither → the user, with the ledger.
Never a second blind fix.

## 3. Class fix, once

- One source of truth; every consumer calls it; the per-site copies are deleted.
- Proof: a class test that fails on at least 2 old sites, plus the consumer list checked off.
- NEW findings outside the class → `## Follow-ups`.

## 4. One round, no stop

- The internal strong reviewer re-checks the class with the ledger + the fix delta (≤ 15 tool calls).
- No new external round — the external had its rounds. The runner refuses round 4 without the ledger and refuses round 5 outright.
- Keep the fix uncommitted until this round returns.
- APPROVED / APPROVED-WITH-NITS → the ship path; no question to the user.

## 5. Split and stop

REJECTED with any IN-FIX / REPEAT, or the user is absent:
- Commit the slices that carry no open finding.
- Park the churning surface as a delta spec or under `## Follow-ups`.
- End the turn with the decision brief: rounds · class · options.
- A resume prompt restates the brief; it never opens a round.
