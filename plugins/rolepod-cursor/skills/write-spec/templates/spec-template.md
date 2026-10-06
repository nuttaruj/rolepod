<!-- Rolepod spec template — the canonical Define-phase artifact. -->
<!-- Fill every section. Replace every [[FILL: …]] marker. write-plan consumes this. -->

# [[FILL: feature name]] Spec

## Goal
[[FILL: One sentence. The outcome, not the implementation.]]

## User / actor
[[FILL: Who triggers this and benefits. Name a distinct role when it affects scope; keep an obvious actor brief.]]

## Non-goals
[[FILL: Exclude plausible scope that could be mistaken as included. Use `None` when there is no meaningful exclusion. Repeat feature may cite `Unchanged — <prior> §Non-goals` plus changes.]]

## Current behavior
[[FILL: Start `Product: change | new`. For change, describe current behavior and affected consumers of what moves; verify any prior spec against shipped code. For new, `Nothing — new surface` is valid. Each affected consumer maps to a task or a Non-goal.]]

## Desired behavior
[[FILL: Observable behavior. For a repeat change, list only the delta as Added / Changed (old → new) / Removed (+ why); unlisted behavior stays unchanged.]]

## Success criteria
[[FILL: Pass/fail conditions with a command, observation, or user action that proves each. Include a post-ship metric only when discovery settled one.]]
- [[FILL: criterion 1]] — proven by: [[FILL: command / observation]]
- [[FILL: criterion 2]] — proven by: [[FILL: command / observation]]

## Testing decisions
[[FILL: Name the fewest highest existing seams that reach behavior, expected assertion, and prior-art tests. Explain a new seam. Edge / error / race cases need a criterion or R4 risk. Name a permanent user-visible E2E only for a critical path; Verify observes other flows once. No logic change → `None — evidence-after: <check>`.]]

## Constraints
[[FILL: Stated stack, deadline, no-touch zones, compatibility, and settled rollout / rollback constraints. Repeat feature may cite `Unchanged — <prior> §Constraints`. Omit unstated details.]]

## High-risk surfaces
[[FILL: Touched surfaces among auth / billing / payments / credits / migration / data deletion / secrets / tokens / crypto / permissions / security. State `None` deliberately when none apply.]]
Cross-family critique: <status line, write-spec step 5>

## Chosen approach
[[FILL: Chosen direction and rationale. If DB table / migration, public API contract, or module boundary changes, include accepted interface, data shape, compatibility rule, and invariants. No file order here.]]

## Rejected approaches
[[FILL: Real alternatives and why rejected. If minimal is already clean, state what the clean lens checked. Never invent alternatives or write `None`. Repeat feature may cite `Unchanged — <prior> §Rejected approaches`.]]

## Open questions
[[FILL: Unresolved decisions only. Empty permits write-plan; any listed decision blocks it.]]
