<!-- Rolepod spec template — the canonical Define-phase artifact. -->
<!-- Fill every section. Delete the <hints>. write-plan consumes this. -->

# <Feature> Spec

## Goal
<One sentence. The outcome, not the implementation.>

## User / actor
<Who triggers this and who benefits. Name the role, not "the user" if avoidable.>

## Non-goals
<What this explicitly does NOT do. Cut scope creep here.>

## Current behavior
<What happens today. "Nothing — new surface" is a valid answer. Repeat feature: seed from the latest docs/rolepod/specs/<feature>-*.md Desired behavior, but verify it shipped before trusting it.>

## Desired behavior
<What should happen after. Observable, not internal.>

## Success criteria
<Checkable conditions. Each must be pass/fail, not "works well", and each
 names how it will be proven — a command, an observation, or a user action.>
- <criterion 1> — proven by: <command / observation>
- <criterion 2> — proven by: <command / observation>

## Constraints
<Stack, deadline, no-touch zones, compatibility the user already stated.>

## High-risk surfaces
<auth / billing / payments / credits / migration / data deletion / secrets /
 tokens / crypto / permissions / security touched.
 "None" is valid — but state it deliberately, do not omit the section.>

## Chosen approach
<The selected direction + one-line rationale. No file-by-file order —
 that is write-plan's job.>

## Rejected approaches
<Other viable options + why not chosen. Keeps the decision auditable.>

## Open questions
<Anything unresolved. Empty is the goal. A non-empty list blocks write-plan.>
