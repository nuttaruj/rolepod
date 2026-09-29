<!-- Load when the cross-family pool is enabled at any tier, or on an internal-pass question. The adversarial pass (what counts, apex, strong class) is the `adversarial-review` skill. -->

# External review routing

An external review routes to a **different CLI** than the Lead's, never to the Lead's own; the model family is information, not a filter.

## When the external runs

- **The pool is the user's choice, and it is opt-in** (`.rolepod/cross-family`, then `~/.rolepod/cross-family`; no file or `none` = off). Never turn it on unasked.
- **Mandatory at the pool's tier.** Pool enabled + a logic-bearing code diff at the pool's tier (R4 unless the pool file sets `tier = R2|R3`) + a usable member → the strong pass is the external. Below that tier, and any doc / comment / config / rename-only diff, stay internal unless the user asks. At R4 it is the adversarial pass (`--adversarial`, the `adversarial-review` skill); at the pool's tier R2/R3 it is the standard pass.
- **What the external replaces.** At R4 it is the adversarial pass beside `security-engineer` and the lens pair; at the pool's tier R2/R3 it replaces the lens pair — never beside it on round 1.
- **Run it:** R4 → the `adversarial-review` skill; the pool's tier R2/R3 → `cross-family` kind review without `--adversarial`, else the lens pair.
- **An externally implemented ship group** is reviewed by a DIFFERENT member. A user-lifted risky scope (`risky:lifted`) → the external pass by a different member.
- **Money / auth** — billing · payments · credits · auth · crypto · secrets · data deletion: the full R4 round-1 set (`review-code` Pick reviewers); commit only after the adversarial pass has finished (the anchored external, or the internal strong pass).
## Round 2+

The external runs round 1 only; the fix deltas of its findings are re-checked internally — `security-engineer` for the security-class ones, `universal-reviewer` for the rest (`review-code` Fix-verify rounds).

## The Lead floor — covers every axis

The Lead floor is `universal-reviewer` (a read-only fresh-context subagent). When no reviewer can run (missing / failed / empty), the Lead's multi-axis read covers every axis — correctness, security, breadth, architecture, perf, UI — recorded as a LIMITATION.

Strength routing is an optimisation on top of the floor: it assigns a specialist to an axis when one is available; it never removes an axis. A specialist that is missing, is the Lead's own CLI, or has failed → that axis falls back to the floor.

On a high-risk surface the adversarial pass and its Cross-model line follow the `adversarial-review` skill.

This never widens WHO reviews: the pool reviews code at its tier (R4, or lower only when the pool file sets `tier = R2|R3`); below it stays internal.
