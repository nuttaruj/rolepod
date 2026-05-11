---
name: test-driven-development
description: Drive implementation with a failing test first. Apply when fixing bugs (Prove-It pattern), when adding new logic, when changing behavior, or when you need proof that code works AND that the test actually exercises the change. Red → Green → Refactor.
---

# Test-Driven Development

The test goes first not because of dogma but because of feedback. A failing test is proof your code wasn't doing the thing yet. A passing test on code that already passed is proof of nothing — it might run zero of the relevant lines. TDD closes the gap between "I wrote a test" and "the test actually checks the thing."

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER write implementation before a failing test for the change you intend. ห้ามฝืน.
2. ALWAYS observe Red (test fails for the right reason — assertion mismatch, not import error) before writing implementation.
3. For bug fixes: ALWAYS run the Prove-It revert step (revert fix → test fails → re-apply → test passes). Without this step you have not proven the test catches the bug.

These rules do not bend for "simple change", "I already know it works", or time pressure. 62% of LLM-generated tests have wrong assertions (arXiv 2402.13521) precisely because the test was written after the code. Red-first is the only structural defense.
</EXTREMELY-IMPORTANT>

## Red Flags — you are about to skip this skill

| Red flag (your thought) | What it actually means |
|-------------------------|------------------------|
| "I'll add the test after the implementation" | Test will assert what the code does, not what the spec requires. |
| "The test passed on the first run" | You didn't see Red — the test isn't exercising the change. |
| "Reverting the fix to confirm the test fails is overkill" | Skipping Prove-It step 4 is the #1 way bugs ship with green tests. |
| "This bug is too obvious to need a regression test" | Obvious bugs reappear in 6 months when nobody remembers the obvious fix. |
| "Mocking the function under test is fine here" | You are testing the mock, not the code. The test proves nothing. |

## When to use

- Fixing any bug → write the reproducing test first
- Adding new business logic, validation, calculation
- Implementing edge cases that were previously broken
- Changing behavior of existing code (test the new behavior first)
- Working on high-risk code (auth, billing, migrations, races)
- Pairing with another agent / human and want a clear handoff artifact

Skip when: typo, comment, doc, pure rename, dead-code removal, build-config tweak.

## How to apply

### Red → Green → Refactor

#### Red — write the failing test first

Before changing implementation:

1. Write a test that describes the behavior you want
2. Run it
3. **Confirm it fails** — and fails for the **right reason** (assertion mismatch, not import error)

A test that fails for the wrong reason gives false confidence. If the failure is "module not found", fix that first, then re-confirm a real assertion failure.

For bugs: this is the **Prove-It** step. Reproduce the bug as a test, watch it fail. Now you know the test exercises the bug.

```
test('discount applies before tax', () => {
  expect(checkout({ price: 100, discount: 0.1, tax: 0.1 }))
    .toBe(99)  // 100 - 10 = 90, then 90 * 1.1 = 99
})
// Run: fails. Current code returns 100 (bug).
```

#### Green — minimum code to pass

Now write the simplest implementation that makes the test pass. Resist over-engineering.

- Hard-coding a return value is fine for the first test
- Add the second test → can't hard-code → forced to generalize
- Add the third → real implementation emerges

This step proves: the change you made is what made the test pass.

#### Refactor — clean up with tests as safety net

Tests green → simplify the implementation:
- Extract helpers
- Rename for intent
- Remove duplication

Re-run after each refactor. Stay green. (See `code-simplification` skill.)

### The Prove-It pattern (for bugs)

Specific to bug fixes. Proves the test catches the bug, then proves the fix works.

```
1. Reproduce bug locally
2. Write test reproducing bug → run → FAILS (proves test exercises bug)
3. Fix bug → run test → PASSES (proves fix works)
4. Revert fix → run test → FAILS (proves test catches regression)
5. Re-apply fix → run test → PASSES (final state)
```

Step 4 is the discipline that catches "test passes regardless of implementation" — a common bug-fix failure mode.

### Test quality bar

A bad test is worse than no test (false confidence + maintenance cost). A good test:

- **Specific** — one behavior per test
- **Named for behavior** — `test_validate_rejects_empty_email`, not `test_validate_works`
- **Self-contained** — runs in isolation, no shared state with other tests
- **Deterministic** — same result every run; flaky test = real bug or test bug, fix don't quarantine
- **Fast** — unit test in ms; if slow, move to integration tier
- **Failure-readable** — when it fails, the message tells you what broke

### Test types — pick the right tier

| Type | Use for | Speed |
|------|---------|-------|
| Unit | Pure functions, business logic, edge cases | Very fast |
| Integration | Auth, payments, migrations, real DB, external API contracts | Slow |
| Contract | Frontend ↔ backend agreement, schema match | Medium |
| E2E | Critical user journey (login, checkout) | Slowest |

Default: unit. Escalate to integration when mocks would lie (databases, payment providers, distributed locks). **Never mock the database in integration tests** — mock/prod divergence has burned countless teams.

### Edge cases to test

For any new logic, ask:

- Empty input
- Single-item input
- Maximum-size input
- Negative / zero / null
- Unicode / emoji / RTL
- Concurrent calls (if shared state)
- Boundary values (off-by-one territory)
- Invalid input (does it reject cleanly?)

Don't test all of these for trivial code. Do test all for: validation, parsers, math, security checks, state machines.

## When TDD is hard

Some code is awkward to test first. That's a signal:

| Difficulty | Likely meaning | Fix |
|------------|----------------|-----|
| Test setup is huge | Function has too many dependencies | Refactor to take what it needs |
| Need to mock 5 things | Function does too much | Split |
| Test is fragile | Testing implementation, not behavior | Test the public interface |
| Can't observe outcome | Function has hidden side effects | Make outcome visible (return value, event emit) |

Hard-to-test code is hard-to-change code. The friction is information.

## Common mistakes

- Writing the test after the implementation, then claiming TDD
- Test asserts `function_runs_without_error()` — proves nothing
- Test passes from the start (you didn't see Red — test isn't testing the change)
- Mocking the system under test (test mocks, not code)
- One mega-test covering 10 behaviors (when one assertion fails, you don't know which)
- Skipping Step 4 of Prove-It (revert fix, watch test fail again)
- Disabling a flaky test instead of fixing the underlying bug
- Adding tests just to hit coverage % with trivial assertions

## Quick reference

```
For a new feature:
  1. Write test for happy path → Red
  2. Implement minimum → Green
  3. Write test for edge case → Red
  4. Generalize implementation → Green
  5. Refactor → Stay Green

For a bug:
  1. Reproduce locally
  2. Write test reproducing bug → Red
  3. Fix → Green
  4. Revert fix → Red (proves test catches it)
  5. Re-apply fix → Green
  6. Commit
```

## Verification before commit

- [ ] Test was Red before implementation (or revert proves it)
- [ ] Test is Green now
- [ ] Existing tests still Green (no regression)
- [ ] Test name describes the behavior
- [ ] Test runs in isolation
- [ ] No mocking of the code under test

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "I'll write tests after the code, they're more obvious then" | Tests written after = wrong assertions; 62% of LLM-generated tests have wrong assertions per arXiv 2402.13521. Red-first proves the test catches the change. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
