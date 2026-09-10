<!-- Rolepod spec template — the canonical Define-phase artifact. -->
<!-- Fill every section. Replace every [[FILL: …]] marker. write-plan consumes this. -->
<!-- Repeat feature (a prior docs/rolepod/specs/<feature>-*.md exists): a section
     that did not move reads `Unchanged — <prior spec path> §<section>` instead of
     a re-write. Only Goal, User / actor, Non-goals, Constraints, Chosen approach and
     Rejected approaches may inherit. Current behavior, Desired behavior, Success
     criteria, High-risk surfaces and Open questions are ALWAYS written fresh. -->

# [[FILL: feature name]] Spec

## Goal
[[FILL: One sentence. The outcome, not the implementation.]]

## User / actor
[[FILL: Who triggers this and who benefits. Name the role, not "the user" if avoidable.]]

## Non-goals
[[FILL: What this explicitly does NOT do. Cut scope creep here. Repeat feature: carry the prior list forward — `Unchanged — <prior> §Non-goals` plus any new line.]]

## Current behavior
[[FILL: What happens today. "Nothing — new surface" is a valid answer. Repeat feature: seed from the latest docs/rolepod/specs/<feature>-*.md Desired behavior, but verify it shipped before trusting it. Legacy change (no prior spec): list every consumer of the behavior that moves — grep the call sites, code-intel callers when connected — each becomes a plan task or a Non-goal; unlisted consumers are the seams reviewers find one round at a time.]]

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
[[FILL: Stack, deadline, no-touch zones, compatibility the user already stated. Repeat feature: may inherit — `Unchanged — <prior> §Constraints`.]]

## High-risk surfaces
[[FILL: auth / billing / payments / credits / migration / data deletion / secrets /
 tokens / crypto / permissions / security touched.
 "None" is valid — but state it deliberately, do not omit the section.]]

## Chosen approach
[[FILL: The selected direction + one-line rationale. No file-by-file order —
 that is write-plan's job.]]

## Rejected approaches
[[FILL: The other lenses (minimal / clean / pragmatic — write-spec §3) + why not chosen, or "None — no material alternative existed". Keeps the decision auditable. Repeat feature: may inherit — `Unchanged — <prior> §Rejected approaches` — so a rejected path is never re-proposed from a blank slate.]]

## Open questions
[[FILL: Anything unresolved. Empty is the goal. A non-empty list blocks write-plan.]]
Cross-family critique: [[FILL: cli — N items, K settled from repo, M asked | NO FURTHER QUESTIONS | not run — off]]
