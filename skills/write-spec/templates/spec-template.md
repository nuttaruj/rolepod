<!-- Rolepod spec template — the canonical Define-phase artifact. -->
<!-- Fill every section; one that does not apply = one line `None — <why>`. Replace every [[FILL: …]] marker. write-plan consumes this. -->

# [[FILL: feature name]] Spec

## Goal
[[FILL: One sentence. The outcome, not the implementation.]]

## User / actor
[[FILL: Who triggers this and benefits. Name a distinct role when it affects scope; keep an obvious actor brief.]]

## Non-goals
[[FILL: Exclude plausible scope that could be mistaken as included. Repeat feature may cite `Unchanged — <prior> §Non-goals` plus changes.]]

## Current behavior
[[FILL: Start `Product: change | new`. For change, describe current behavior and affected consumers of what moves, naming modules or files, never line numbers; verify any prior spec against shipped code. New → `Nothing — new surface`. Each affected consumer is in scope or a Non-goal.]]

## Desired behavior
[[FILL: Observable behavior. For a repeat change, list only the delta as Added / Changed (old → new) / Removed (+ why); unlisted behavior stays unchanged.]]

## Success criteria
[[FILL: Observable behavior only — never a review, rule map, build order, task, receipt or commit / release gate. Include a post-ship metric only when discovery settled one.]]
- [[FILL: criterion]] — proven by: [[FILL: command, case file or observation; no line ranges]]

## Testing decisions
[[FILL: Name the fewest highest existing seams that reach behavior, expected assertion, and prior-art tests. Explain a new seam. Edge / error / race cases need a criterion or R4 risk. Name a permanent user-visible E2E only for a critical path; Verify observes other flows once. No logic change → `None — evidence-after: <check>`. A one-off review → last bullet `- **Phase-end review:** <what the spec lens checks>`.]]

## Constraints
[[FILL: Stated stack, deadline, no-touch zones, compatibility, and settled rollout / rollback constraints. Repeat feature may cite `Unchanged — <prior> §Constraints`. Omit unstated details.]]

## High-risk surfaces
[[FILL: Touched surfaces on the high-risk list (`using-rolepod` Stop conditions).]]

## Chosen approach
[[FILL: Chosen direction and rationale. If DB table / migration, public API contract, or module boundary changes, include accepted interface, data shape, compatibility rule, and invariants. No file order here.]]

## Rejected approaches
[[FILL: Real alternatives and why rejected. Minimal already clean → `None — <what the clean lens checked>`; never invent alternatives. Repeat feature may cite `Unchanged — <prior> §Rejected approaches`.]]

## Open questions
[[FILL: Unresolved decisions only. Empty permits write-plan; any listed decision blocks it.]]
