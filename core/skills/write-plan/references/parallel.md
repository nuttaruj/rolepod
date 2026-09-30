<!-- Load when two or more plan tasks could run in parallel (write-plan steps 4-5). -->

# Parallel layout and the cohesion contract

## Deciding

Tracks group tasks that share files or are linked by **Blocked by** edges within that group. A track runs in one worktree under one owner (the role owning most of that track's code), with all tasks executing in order.

- Parallel tracks help only when file ownership is genuinely disjoint and the work needs no handoff between tracks — otherwise sequential is faster and cheaper.
- Two edge-free tasks on different files are parallel *track candidates*, never a mandate. Sequential anyway is fine — say why in the Parallel layout line.
- Tasks on shared files → same track, sequential within it.
- Borderline (a shared interface between tracks) → present both shapes with one-line trade-offs; the user picks.

## The contract

Fill `templates/cohesion-contract-template.md` — Shared goal · Owners · File ownership · Shared interfaces · Merge order · Do-not-touch list · Verification per agent · Integration owner · Session split (optional). Save it to `contract.md` or `docs/rolepod/plans/<feature>-cohesion-YYYY-MM-DD.md`.

- Every path sits under EXACTLY one owner: unowned = unplannable, dual-owned = a scheduled merge conflict.
- Two parallel tracks need the same file → sequential, or rewrite the contract, then re-run `plan-lint.sh <plan> <contract>`.

## Session split

Tracks run as SEPARATE CLI sessions (cross-CLI wall-clock parallelism) → fill the contract's optional **Session split** section: per-track CLI + branch + kickoff prompt, one integration session. Execution: implement-plan's `references/subagent-dispatch.md`, "Session-split tracks".
