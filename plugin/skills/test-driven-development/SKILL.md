---
name: test-driven-development
description: Drive implementation with a failing test first. Red → Green → Refactor.
when_to_use: when fixing bugs (Prove-It pattern), when adding new logic, when changing behavior, or when you need proof that code works AND that the test actually exercises the change
paths:
  - "**/*test*.{ts,js,py,go,rs}"
  - "**/__tests__/**"
---

# Test-Driven Development

Failing test = proof code wasn't doing the thing yet. Passing test on code that already passed = proof of nothing.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER write implementation before a failing test for the intended change.
2. ALWAYS observe Red (test fails for right reason — assertion mismatch, not import error) before writing implementation.
3. For bug fixes: ALWAYS run Prove-It revert step (revert fix → test fails → re-apply → passes).

Rules don't bend for "simple" / "I know it works" / time pressure. 62% of LLM-generated tests have wrong assertions (arXiv 2402.13521) precisely because tests were written after code. Red-first = only structural defense.
</EXTREMELY-IMPORTANT>

## Red Flags — you're about to skip this skill

| Thought | Reality |
|---------|---------|
| "I'll add test after implementation" | Test will assert what code does, not what spec requires. |
| "Test passed on first run" | You didn't see Red — test isn't exercising the change. |
| "Reverting the fix is overkill" | Skipping Prove-It step 4 = #1 way bugs ship with green tests. |
| "Bug is obvious, no regression test" | Obvious bugs reappear in 6 months. |
| "Mocking the function under test is fine" | You're testing the mock. Proves nothing. |

## When to use

- Fixing any bug → reproducing test first
- New business logic / validation / calculation
- Edge cases previously broken
- Changing existing behavior
- High-risk code (auth/billing/migrations/races)
- Handoff to another agent/human

Skip when: typo, comment, doc, pure rename, dead code, build-config.

## How to apply

### Red — write failing test first

1. Write test describing desired behavior
2. Run it
3. **Confirm it fails for right reason** (assertion mismatch, not import error)

For bugs: this is **Prove-It**. Reproduce bug as test, watch fail.

```
test('discount applies before tax', () => {
  expect(checkout({ price: 100, discount: 0.1, tax: 0.1 }))
    .toBe(99)  // 100 - 10 = 90, then 90 * 1.1 = 99
})
// Run: fails. Current code returns 100 (bug).
```

### Green — minimum code to pass

Simplest implementation that passes. Hard-code first test if needed; second test forces generalization; third → real implementation emerges.

Proves: your change made the test pass.

### Refactor — clean up with tests as safety net

Tests green → extract helpers, rename for intent, remove duplication. Re-run after each refactor. (See `code-simplification`.)

### Prove-It pattern (bugs)

```
1. Reproduce bug locally
2. Write test reproducing bug → run → FAILS (test exercises bug)
3. Fix bug → run test → PASSES (fix works)
4. Revert fix → run test → FAILS (test catches regression)
5. Re-apply fix → run test → PASSES (final state)
```

Step 4 catches "test passes regardless of implementation."

## Test quality bar

| Bad | Good |
|-----|------|
| `assert result is not None` | `assert result == expected_value` |
| Mock the system under test | Test real code, mock external deps only |
| "Doesn't crash" | Returns correct value |
| 1 mega-test, 10 things | 10 focused tests |
| `test_function_works` | `test_validate_rejects_empty_string` |
| Hidden setup | Self-contained |
| Flaky | Deterministic |

## Test types

| Type | Use for | Speed |
|------|---------|-------|
| Unit | Pure functions, business logic, edges | Very fast |
| Integration | Auth, payments, migrations, real DB | Slow |
| Contract | FE ↔ BE agreement, schema | Medium |
| E2E | Critical user journey | Slowest |

Default: unit. Escalate to integration when mocks would lie. **Never mock the database in integration tests.**

## Edge cases to test

Empty / single-item / max-size / negative / zero / null / unicode / emoji / RTL / concurrent / boundary / invalid input.

All needed for: validation, parsers, math, security, state machines.

## When TDD is hard = signal

| Difficulty | Meaning | Fix |
|------------|---------|-----|
| Huge test setup | Too many deps | Refactor to take what it needs |
| Mock 5 things | Does too much | Split |
| Fragile test | Testing implementation | Test public interface |
| Can't observe outcome | Hidden side effects | Make outcome visible |

## Quick reference

```
New feature:
  1. Test happy path → Red
  2. Implement minimum → Green
  3. Test edge case → Red
  4. Generalize → Green
  5. Refactor → Stay Green

Bug:
  1. Reproduce locally
  2. Test reproducing bug → Red
  3. Fix → Green
  4. Revert fix → Red
  5. Re-apply → Green
  6. Commit
```

## Verification before commit

- [ ] Test was Red before implementation
- [ ] Test Green now
- [ ] Existing tests still Green
- [ ] Test name describes behavior
- [ ] Runs in isolation
- [ ] No mocking of code under test

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests after code, more obvious then" | Tests-after = wrong assertions; 62% wrong (arXiv 2402.13521). |
| "Simple change" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). |
| "Time pressure" | 5 min saved = 50 min debugging later. |

Default: run anyway.
