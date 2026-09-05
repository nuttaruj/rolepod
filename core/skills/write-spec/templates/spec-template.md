<!-- Rolepod spec template — the canonical Define-phase artifact. -->
<!-- Fill every section. Replace every [[FILL: …]] marker. write-plan consumes this. -->

# [[FILL: feature name]] Spec

## Goal
[[FILL: One sentence. The outcome, not the implementation.]]

## User / actor
[[FILL: Who triggers this and who benefits. Name the role, not "the user" if avoidable.]]

## Non-goals
[[FILL: What this explicitly does NOT do. Cut scope creep here.]]

## Current behavior
[[FILL: What happens today. "Nothing — new surface" is a valid answer. Repeat feature: seed from the latest docs/rolepod/specs/<feature>-*.md Desired behavior, but verify it shipped before trusting it.]]

## Desired behavior
[[FILL: What should happen after. Observable, not internal.
 Repeat feature (a Current behavior exists): enumerate the delta explicitly —
 **Added:** / **Changed:** (old → new) / **Removed:** (+ why) bullets against
 the verified Current behavior. A reviewer then reads what MOVES, not two
 prose blocks to diff by eye; anything unlisted is asserted unchanged.]]

## Success criteria
[[FILL: Checkable conditions. Each must be pass/fail, not "works well", and each
 names how it will be proven — a command, an observation, or a user action.]]
- [[FILL: criterion 1]] — proven by: [[FILL: command / observation]]
- [[FILL: criterion 2]] — proven by: [[FILL: command / observation]]

## Constraints
[[FILL: Stack, deadline, no-touch zones, compatibility the user already stated.]]

## High-risk surfaces
[[FILL: auth / billing / payments / credits / migration / data deletion / secrets /
 tokens / crypto / permissions / security touched.
 "None" is valid — but state it deliberately, do not omit the section.]]

## Chosen approach
[[FILL: The selected direction + one-line rationale. No file-by-file order —
 that is write-plan's job.]]

## Rejected approaches
[[FILL: Other viable options + why not chosen, or "None — no material alternative existed". Keeps the decision auditable.]]

## Open questions
[[FILL: Anything unresolved. Empty is the goal. A non-empty list blocks write-plan.]]
Cross-family critique: [[FILL: cli — N items, K settled from repo, M asked | NO FURTHER QUESTIONS | not run — off]]
