<!-- Load when two or more plan tasks could run in parallel (write-plan steps 4-5). -->

# Parallel layout and the cohesion contract

## Deciding

- Parallel agents help only when file ownership is genuinely disjoint and the work needs no handoff between agents — otherwise sequential is faster and cheaper.
- Two tasks with no edge are parallel *candidates*, never a mandate. Sequential anyway is fine — say why in the Parallel layout line.
- Borderline (a shared interface) → present both shapes with one-line trade-offs; the user picks.

## The contract

Fill `templates/cohesion-contract-template.md` — Shared goal · Owners · File ownership · Shared interfaces · Merge order · Do-not-touch list · Verification per agent · Integration owner · Session split (optional). Save it to `contract.md` or `docs/rolepod/plans/<feature>-cohesion-YYYY-MM-DD.md`.

- Every path sits under EXACTLY one owner: unowned = unplannable, dual-owned = a scheduled merge conflict.
- Two parallel agents need the same file → sequential, or rewrite the contract, then re-run `plan-lint.sh <plan> <contract>`.

## Session split

Tracks run as SEPARATE CLI sessions (cross-CLI wall-clock parallelism) → fill the contract's optional **Session split** section: per-track CLI + branch + kickoff prompt, one integration session. Execution: implement-plan's `references/subagent-dispatch.md`, "Session-split tracks".
