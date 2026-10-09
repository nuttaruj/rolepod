<!-- Load when two or more plan tasks could run in parallel (write-plan steps 4-5). -->

# Parallel layout and the cohesion contract

## Deciding

Tracks group tasks that share files or are linked by **Blocked by** edges within that group. A track runs in one worktree, tasks in order.

- Parallel tracks help only when file ownership is disjoint and the work needs no handoff between tracks — else sequential.
- Two edge-free tasks on different files are parallel *track candidates*, never a mandate. Sequential anyway: say why in the Parallel layout line.
- Tasks on shared files → same track, sequential within it.
- Borderline (shared interface) → present both shapes with one-line trade-offs; the user picks.

## The contract

Fill `templates/cohesion-contract-template.md`. Save it to `docs/rolepod/plans/<feature>-cohesion-YYYY-MM-DD.md` (first save: `edge-cases.md` Saving the plan).

- Two parallel tracks need the same file → sequential, or rewrite the contract, then re-run `plan-lint.sh <plan> <contract>`.
- A role that owns files in two tasks → one File ownership line per task, each tagged `<role> (T<N>)`; plan-lint fails two untagged lines for one role.

## Session split

Tracks as separate CLI sessions → the coordinating-parallel-tracks skill; none → fill the contract's optional **Session split** section: per-track CLI + branch + kickoff prompt, one integration session merging in order.
