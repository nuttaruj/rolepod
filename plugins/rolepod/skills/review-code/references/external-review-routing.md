<!-- Load when the cross-family pool is enabled at any tier, or on an internal-pass question. The adversarial pass (what counts, apex, strong class) is the `adversarial-review` skill. -->

# External review routing

An external review routes to a **different CLI** than the Lead's, never to the Lead's own; the model family is information, not a filter.

## When the external runs

- **The pool is the user's choice, and it is opt-in** (set `pool` in `~/.rolepod/config.json` machine-wide only; unset key or `pool.cross-family: "off"` = off). Never turn it on unasked.
- **Mandatory only when the active mode requires it.** Pool enabled + a usable member does not by itself add an adversarial pass. Full R4 requires the adversarial pass and uses the external when available. Standard R4 requires security plus both lenses and has no adversarial field/pass. Lite uses its two isolated lenses only. The pool's R2/R3 tier may replace the lens pair with one standard external review. Below the configured tier, and for doc / comment / config / rename-only diffs, stay internal unless the user asks or a caller explicitly requests cross-family review.
- **What the external replaces.** Full R4 external is the adversarial pass alongside `security-engineer` and the lens pair. At the pool's R2/R3 tier it replaces the lens pair, never beside them on round 1. It does not alter Lite or Standard R4 review sets.
- **Run it:** Full R4 → the `adversarial-review` skill; the pool's tier R2/R3 → `cross-family` kind review without `--adversarial`, else the lens pair. Explicit user or caller requests for cross-family behavior remain in force.
- **An externally implemented ship group** is reviewed by a DIFFERENT member. A user-lifted risky scope (`risky:lifted`) → the external pass by a different member.
- **Money / auth** — billing · payments · credits · auth · crypto · secrets · data deletion: use the active mode's R4 set from `review-code`; require the adversarial pass only in Full (and keep the comment/blank-only exception).
## Round 2+

The external runs round 1 only; round 2+ — only a finding raised by the external whose fix touches code is re-checked internally on a balanced model (an external's finding → `security-engineer` for security-class, else `universal-reviewer`; `review-code` Fix-verify rounds).

## Fallback follows the active review contract

Fallback follows the active mode's contract. Lite may use the Lead's two-axis walkthrough with an independence limitation only when agents are unavailable. In Standard and Full, a missing, failed, empty, or partial required report keeps the same round open; the assigned reviewer completes it on H1. Never use a generic Lead floor to satisfy a required report. If dispatch is impossible or the user forbids agents, stop and record the limitation or waiver path required by `review-code` and `adversarial-review`.

Strength routing may assign a specialist to an axis when available; it never removes a required axis. A missing specialist does not make the Lead an independent reviewer.

Only Full R4 uses an adversarial pass and its Cross-model line, following the `adversarial-review` skill. Lite and Standard do not gain either from pool availability alone.

This never widens WHO reviews: a pool tier of R2/R3 may replace the lens pair only where the active mode permits it. It never adds adversarial review to Lite or Standard R4; an explicit user or caller request for cross-family review remains in force.
