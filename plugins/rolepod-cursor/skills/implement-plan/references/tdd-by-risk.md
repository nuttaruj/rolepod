<!-- Load when unsure whether a task is test-first or evidence-after. -->

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
When in doubt, treat the task as test-first. The cost of an unneeded test is
minutes; the cost of a missed regression on a risk surface is unbounded.
