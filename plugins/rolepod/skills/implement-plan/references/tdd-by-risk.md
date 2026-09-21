<!-- Load when unsure whether a task is test-first or evidence-after, and for the writer's test self-check. -->

Test discipline is not one rule — it scales with the task's risk. Match the
task type to its discipline.

## Test-first — write the failing test BEFORE the code
The test must run and FAIL first. A test that passes before the code exists
has a weak assertion (see check-work's `assertion-strength.md`).

| Task type | Test-first because |
|-----------|--------------------|
| Bug fix | The failing test reproduces the bug; its flip to green proves the fix |
| New business logic | The test pins intended behavior before the code can drift |
| auth / permission | A safety test must prove the deny path before the allow path |
| billing / credits / payment | A test must pin the money math before it ships |
| Migration / backfill | Forward + rollback proven before data moves |
| Concurrency / race | A test must exercise the interleaving the bug needs |

## Evidence-after — make the change, then prove it
Lower-risk work where a test-first cycle adds ceremony without catching more.

| Task type | Evidence that suffices |
|-----------|------------------------|
| UI copy / styling | Browser observation of the rendered result |
| Config / infra | Smoke test + restart confirmation |
| Docs / ADR | Render output + link check |
| Pure rename / typecheck-safe refactor | Existing suite green before and after |

## Rule
When in doubt on a risk surface, test-first. Then size the suite by rules,
not call-sites: one test per rule, at the rule's owner; each call-site gets
one smoke; a test whose failure an existing test already catches is not
written; collapsing N copies of a rule into one function collapses their
tests the same way. A suite that only ever grows is read less each round.

## Hygiene — what keeps a green suite green
- Dates and times derive from ONE frozen `now` (fake timers / injected
  clock). A literal calendar date expires; the real clock drifts across
  midnight, weekday and DST; both come back as a red that is not a
  regression and cost a review round to prove it.
- Expected values come from the spec, never read off the shared seed — a
  seed edit is not a behavior change, and a test that assumes seed prices
  or rows breaks on the next fixture change.
- The test's own file is part of the change; the shared fixture is not.
  Touching `helpers/` or a seed to make one test pass is a finding.
- Assert the contract — type, code, structured field, state, side effect —
  never human-readable wording the requirement did not fix (UI copy, a log
  line, error prose, prompt text). "Implemented as a string" is not "the
  string is a contract": would rewording it break a consumer? No → not a
  contract, and the test breaks on the next copy edit. Machine-read tokens,
  public error codes and wording the spec quotes stay exact.

## The writer's self-check (unit tests are yours; the reviewer reads the same list)
- Design at the seam: happy + edge + error (+ race on shared state); call the
  plan's public interface, never internals.
- A bug fix starts from a reproducing failing test; its flip to green is the proof.
- Expected values derive from the spec, never from the code's current output.
- Weak assertion = still green after a one-character regression. High-risk
  logic: flip one operator in a throwaway worktree — nothing red → tighten.
- Mock only external boundaries; an integration test never mocks the DB.
- Migration → forward + rollback. Billing / credits → a race test.
- User-visible behaviour (screen / flow / API contract) is `qa-tester`'s E2E
  work — name it in the Test line, never fake it with a unit test.
