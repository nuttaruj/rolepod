<!-- Load when unsure why a task is test-first or evidence-after, which seam a dependency needs, or why a hygiene rule exists. -->

# Test discipline by risk

Test discipline scales with the task's risk. SKILL.md holds the rules; this file holds the reasons.

## Test-first — why

| Task type | Test-first because |
|-----------|--------------------|
| Bug fix | The failing test reproduces the bug; its flip to green proves the fix |
| New business logic | The test pins intended behavior before the code can drift |
| auth / permission | A safety test must prove the deny path before the allow path |
| billing / credits / payment | A test must pin the money math before it ships |
| Migration / backfill | Forward + rollback proven before data moves |
| Concurrency / race | A test must exercise the interleaving the bug needs |

## Evidence-after — why

Lower-risk work where a test-first cycle adds ceremony without catching more.

| Task type | Evidence that suffices |
|-----------|------------------------|
| UI copy / styling | Browser observation of the rendered result |
| Config / infra | Smoke test + restart confirmation |
| Docs / ADR | Render output + link check |
| Pure rename / typecheck-safe refactor | Existing suite green before and after |

## Sizing by rules

Collapsing N copies of a rule into one function collapses their tests the same way. A suite that only ever grows is read less each round.

## Seams by dependency kind — what the test crosses

Cut a seam only where something varies; one implementation behind an interface is indirection, not a seam.

| Dependency | Seam | Test |
|-----------|------|------|
| In-process (pure logic, same module) | none | unit test through the public interface |
| Local-substitutable (clock, random, filesystem, env) | inject at the seam | fake it in the unit test (frozen `now`, temp dir) |
| Remote-but-owned (your DB, queue, own service) | thin adapter | integration test against a real local instance — never a mocked DB |
| True-external (third-party API, payment, email) | adapter behind an interface you own | contract test on a recorded / fake response + ONE live smoke |

## Hygiene — why a green suite stays green

- **One frozen `now`.** A literal calendar date expires; the real clock drifts across midnight, weekday and DST. Both come back as a red that is not a regression and cost a review round to prove it.
- **Expected values from the spec, not the seed.** A seed edit is not a behavior change; a test that assumes seed prices or rows breaks on the next fixture change.
- **The shared fixture is not part of the change.** Touching `helpers/` or a seed to make one test pass moves every other test that reads it.
- **Assert the contract, not the wording.** "Implemented as a string" is not "the string is a contract": would rewording it break a consumer? No → not a contract, and the test breaks on the next copy edit. Machine-read tokens, public error codes and wording the spec quotes stay exact.
