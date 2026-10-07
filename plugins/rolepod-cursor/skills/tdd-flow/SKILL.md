---
name: tdd-flow
description: The owner's red-green procedure. Use when the user asks for test-first, TDD or a failing test first; a bug must be reproduced as a test; a skill or brief calls for one failing test at a seam.
---

# TDD Flow

Turns one logic slice into a test that was red before the change and is green after, at the seam a caller uses.

## Skip when

- User-visible behaviour (a screen, a flow, an API contract end to end) → `rolepod-qa`'s E2E, named in the plan's Test line; never fake it with a unit test.

### 1. Pick the discipline by risk

Test-first for a bug fix, new business logic, auth / permission (the deny path before the allow path), billing / credits / payment (the money math), a migration or backfill (forward + rollback), and concurrency (the interleaving the bug needs).
Evidence-after for UI copy or styling (a browser observation), config / infra (smoke + restart), docs (render + link check), a typecheck-safe rename (the suite green after, no assertion weakened), and wiring or CRUD pass-through with no rule of its own (the suite green plus one smoke through the path).
In doubt on a risk surface → test-first.

Done when: the slice is labelled test-first or evidence-after; evidence-after hands straight to the Next phase.

### 2. Take the agreed seam

Tests go only at an agreed seam, taken in this order: the plan task's seam (the spec's Testing decisions, or a planner-added one) → neither (no spec, no plan) → pick the highest existing seam that reaches the behavior and state it (`Seam: <interface>`) before any test; brand-new code with no existing seam → the new code's public interface, stated the same way.
Highest = closest to the caller while still reaching the behavior; the fewest seams; an existing seam over a new one.
A seam's interface is everything a caller must know: the signature plus its invariants, ordering, error modes and required config. The test asserts those, not the type alone.
Match the seam to the dependency: pure logic → a unit test through the interface; clock / random / filesystem / env → inject it and fake it (a fixed clock, a temp dir); your own DB or queue → an integration test against a real local instance; a third-party API → a contract test on a recorded response plus one live smoke.
No seam reaches the real behaviour at a practical cost (only a shallow single-caller test fits, or it needs broad harness setup or production-only state) → no new test: prove it with the closest executable check (a repro command or script, a log assertion, a browser observation), red before the change and green after, and record the missing seam under `## Follow-ups`; a test at a too-shallow seam is false confidence. An R4 floor case stays a finding that stops the slice.

Done when: the agreed seam is stated with the interface contents the test will assert, or the closest executable check is named and the missing seam recorded.

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
This run is the slice's red proof while no test file has changed since; a test file changed → remove the fix once, see the test red, restore it (`references/red-proof.md` runs it as one command; no file → in place), and that run is the red proof.

Done when: the run shows the named assertion failing.

### 5. Smallest change to green

- The smallest change that turns the test green, at the root; no "while I'm here" edits.

Done when: the new test is green and the checks covering the edited files pass; back to step 3 for the next behavior; after the last one, the task's Command passes.

### 6. Self-check the tests

- Weak assertion = still green after a one-character regression. High-risk logic: flip one operator in a throwaway worktree; nothing red → tighten.
- Skip a test whose failure an existing test already catches.
- Would it still pass if every function it imports returned `undefined`? Then it observes nothing. That covers an implementation-coupled test (reaches past the interface, or only checks that a mock was called), a tautological one (asserts what it set up, or the expected value comes from the code under test), a constant pin (restates a config value or table row) and a wording-pinned one → rewrite at the seam with a literal expected value, or delete it.

Done when: every new test survives the flip and sits at the seam.

## Guardrails

- Refactor at review, not in the loop.
- The test's own file is part of the change; the shared fixture, helpers or seed is not — touching one to pass is a finding.

## Next phase

- Called from another skill → back to that skill's next step with the slice's proof: test-first → the red and green runs; evidence-after → the step 1 proof.
- Called alone → `convening-code-review` on the diff, with the red and green runs.
- Not available → `review-code` on the diff.
- No other skill → stop and tell the user what changed, the red and green runs, and what is still unverified or unreviewed.
