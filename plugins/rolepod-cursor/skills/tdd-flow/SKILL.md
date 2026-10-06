---
name: tdd-flow
description: The owner's red-green procedure. Use when the user asks for test-first, TDD or a failing test first; a bug must be reproduced as a test; a skill or brief calls for one failing test at a seam.
---

# TDD Flow

Turns one logic slice into a test that was red before the change and is green after, at the seam a caller uses.

## Skip when

- Prose, a rename, config or doc text → evidence-after (step 1); no test.
- User-visible behaviour (a screen, a flow, an API contract end to end) → `qa-tester`'s E2E, named in the plan's Test line; never fake it with a unit test.

### 1. Pick the discipline by risk

Test-first — the failing test comes BEFORE the code — for a bug fix, new business logic, auth / permission (the deny path before the allow path), billing / credits / payment (the money math), a migration or backfill (forward + rollback), and concurrency (the interleaving the bug needs).
Evidence-after — make the change, then prove it — for UI copy or styling (a browser observation), config / infra (smoke + restart), docs (render + link check), a typecheck-safe rename (the suite green after, no assertion weakened), and wiring or CRUD pass-through with no rule of its own (the suite green plus one smoke through the path).
In doubt on a risk surface → test-first.

Done when: the slice is labelled test-first or evidence-after; evidence-after hands straight to the Next phase.

### 2. Take the agreed seam

Tests go only at an agreed seam, taken in this order: the plan task's seam (the spec's Testing decisions, or a planner-added one) → neither (no spec, no plan) → pick the highest existing seam that reaches the behavior and state it (`Seam: <interface>`) before any test; brand-new code with no existing seam → the new code's public interface, stated the same way.
Highest = closest to the caller while still reaching the behavior; the fewest seams; an existing seam over a new one.
The seam is the public interface a caller uses; the test goes there, never at internals.
A seam's interface is everything a caller must know: the signature plus its invariants, ordering, error modes and required config. The test asserts those, not the type alone.
Match the seam to the dependency: pure logic → a unit test through the interface; clock / random / filesystem / env → inject it and fake it (a fixed clock, a temp dir); your own DB or queue → an integration test against a real local instance; a third-party API → a contract test on a recorded response plus one live smoke.
A seam exists but none reaches the real behaviour (only a shallow single-caller test fits) → that is the finding: record it and stop; a test at a too-shallow seam is false confidence.

Done when: the agreed seam is stated with the interface contents the test will assert, or the missing seam is recorded.

### 3. Write one failing test

- Before the test body, name the production change that would turn it red; none you can name -> the test guards nothing: pick another assertion at the seam.
- One behavior, one test, at the agreed seam — the next behavior gets its own test after this one is green. Never a test ahead of a behavior not yet built; never every test up front.
- One logical assertion per test (several asserts on one outcome count as one).
- Edge / error / race cases only with a reason: an acceptance criterion names the case, or it is an R4 (high-risk) floor from step 1. A bug fix starts from the test that reproduces it.
- Changing an existing rule → the nearest inputs whose result must stay the same (the brief's Done when names them) get a pinning test first, green before and after, unless an existing test already holds them.
- Expected values come from the spec, never from the code's current output or the shared seed.
- Assert the contract — a value, code, structured field, state or side effect — never wording the requirement did not fix; machine-read tokens, public error codes and wording the spec quotes stay exact.
- A real dependency over a fake, stub or mock; mock only external boundaries; an integration test never mocks the DB.

- Modifying an existing test on the way to green (a loosened assertion, a raised tolerance, a deleted case, skip / only, an absorbed snapshot) is a finding until justified.
- One test per shared rule at the rule's owner, plus at most one smoke per call site that has wiring of its own.
- Dates and times derive from one frozen `now`, never a literal calendar date or the real clock.

Done when: the test exists at the seam and asserts the exact expected value.

### 4. Watch it fail

Run the one test. Red = it runs and fails on its named assertion.
A collection / import error, a skip or a 0-test run is not red: fix the harness and rerun.
Green before the code exists → the assertion is weak or the test misses the code: tighten it.
This run is the slice's red proof while no test file has changed since; a test file changed → remove the fix once, see the test red, restore it, and that run is the red proof.

Done when: the run shows the named assertion failing.

### 5. Smallest change to green

- The smallest change that turns the test green, at the root; no "while I'm here" edits.
- Checks per edit and the Command follow `implement-plan`'s Prove; no `implement-plan` → the narrowest covering check after each edit, the task's Command once before returning.

Done when: the new test is green and the checks covering the edited files pass; back to step 3 for the next behavior; after the last one, the task's Command passes.

### 6. Self-check the tests

- Weak assertion = still green after a one-character regression. High-risk logic: flip one operator in a throwaway worktree; nothing red → tighten.
- Skip a test whose failure an existing test already catches.
- A test at a seam nobody agreed, or an edge / error / race case with no reason → a finding: drop it, or record it under `## Follow-ups`.
- Implementation-coupled (reaches past the interface or mocks an internal), tautological (asserts what it set up) or wording-pinned tests → rewrite at the seam.

Done when: every new test survives the flip, sits at the seam, and each rule has exactly one owner test.

## Guardrails

- Refactor at review, not in the loop.
- The test's own file is part of the change; the shared fixture, helpers or seed is not — touching one to pass is a finding.

## Next phase

- Called from another skill → back to that skill's next step with the slice's proof: test-first → the red and green runs; evidence-after → the step 1 proof.
- Called alone → `convening-code-review` on the diff, with the red and green runs.
- Not available → `review-code` on the diff.
- No other skill → stop and tell the user what changed, the red and green runs, and what is still unverified or unreviewed.
