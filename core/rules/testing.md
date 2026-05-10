# Testing — internal execution

**Scope:** when/what/how to test. Internal only (Lead + qa-tester subagent — no external AI).
**NOT this file:** post-change evidence reporting → `verification.md`. Reviewer routing → `reviewer-flow.md`.

Read when: planning task / before commit / question on what to test.

## Decision matrix — when to test

### MUST test (block commit if absent)

| Task type | Required test |
|-----------|---------------|
| Bug fix | Reproducing test (was failing → now passing) |
| New feature | Happy path + edge cases + error path |
| DB migration | Dry run + rollback test + row count delta |
| Auth / permission change | Access control matrix (allowed + denied cases) |
| Money / billing / credit | All flows + concurrent (race) tests |
| Race condition fix | Concurrent test (threads / async) |
| API contract change | Contract test (request shape + response shape) |
| Performance fix | Before/after benchmark with metric |
| Security fix | Exploit reproduction → blocked confirmed |
| File / data deletion | Idempotent + reversible-where-possible test |

### SHOULD test

| Task type | Recommended test |
|-----------|------------------|
| Refactor | Existing tests pass BEFORE AND AFTER (no behavior change) |
| Library upgrade | Smoke test + integration on critical paths |
| Config change | Restart service + functional smoke |
| New dependency | Integration test exercising the new dep |
| Background task | Trigger + verify side effect + verify idempotency |

### SKIP test (no behavior change)

- Typo / comment-only / docstring update
- Doc-only (`*.md`, README)
- Pure rename (compiler/typechecker catches)
- Dead code removal (verified unused)
- Code reformat / lint fix

## Test types (priority order by ROI)

| Type | Speed | Catches | When to use |
|------|-------|---------|-------------|
| **Unit** | fast | logic bugs, edge cases | Business logic, pure functions, calculations |
| **Integration** | slow | mock/prod divergence, API contracts | Auth, payments, migrations, external APIs, distributed locks |
| **Contract** | medium | FE↔BE drift, schema mismatch | API endpoint changes, response model edits |
| **E2E** | slowest | full-flow regression | Critical user journeys (login, checkout) |
| **Smoke** | fast | "does it boot" | After config change, before deploy |
| **Property/fuzz** | medium | unexpected inputs | Validation, parsers, security boundaries |
| **Benchmark** | slow | perf regression | Performance-sensitive code |

### Balance — when to pick what

- Unit for **business logic depth** (every branch covered)
- Integration for **critical paths** (auth/payments/migrations/external APIs/locks)
- **Never mock the database in integration tests** — mock/prod divergence has burned us
- Contract tests when changing API surface (catches FE breaking BE silently)
- E2E sparingly — slow + flaky, reserve for must-not-break user flows

## Workflow integration

- **Explore**: read existing tests for area touched, note flaky ones
- **Plan**: test plan in output (unit / integration / edge cases / existing-to-verify) — vague "add tests" rejected
- **Implement**: TDD-light for non-trivial (failing test → code → pass → refactor); tests AFTER code OK for mechanical changes
- **Pre-commit gate**: T1-T6 checklist canonical in `~/.claude/CLAUDE.md` Test gate
- **Post-merge**: CI runs critical paths every merge; CI lacks coverage → flag as future work

## Internal execution — no external AI

### Lead direct (fast path)

Use when: tests already exist, just need to run.

```bash
# Examples (project-specific commands vary)
pytest tests/ -v
npm test
go test ./...
cargo test
```

Lead reads output, reports pass/fail. Done.

### qa-tester subagent (complex path)

Use when:
- Need to **write** new tests (multi-file)
- Need to **fix** failing tests
- Need to **investigate** flaky test
- Need to test **business logic** with full context

qa-tester has `Write` tool + can iterate test/code cycle.

### Brief qa-tester (delegation template)

```
Task: <test goal>
Files to touch: <test file paths>
Test cases needed:
  - <case 1>: <expected behavior>
  - <case 2>: <edge case>
Constraints:
  - Use real DB (no mocks for integration)
  - Don't mock <X>
  - Match style of existing tests in <file>
Success criteria: all listed cases pass + no existing test broken
Cap: ≤12 tool_uses, ≤5 files
```

### TDD-light pattern (Lead direct)

For 1 file, 1 function: failing test → code → pass → refactor.
Deep guide: skill `test-driven-development`

## Test quality criteria

Bad test = false confidence. Quality bar:

| Bad | Good |
|-----|------|
| `assert x == x` (tautology) | `assert validate("invalid") == False` |
| Mock the system under test | Test the real code, mock only external deps |
| Test "it doesn't crash" | Test "it returns correct value" |
| 1 mega-test covering 10 things | 10 focused tests, 1 thing each |
| Test name: `test_function_works` | Test name: `test_validate_rejects_empty_string` |
| Hidden setup (test fails alone) | Self-contained — runs in isolation |
| Flaky (sometimes passes) | Deterministic — same result every time |

## T6 — assertion correctness (LLM-specific failure mode)

T6 in the pre-commit test gate: **would a 1-character bug in the code under test still let the assertion pass?** If yes, the assertion is too weak.

Background: arXiv 2402.13521 ("An Empirical Study on Test Case Generation by LLMs") found that **62% of LLM-generated tests contain incorrect or weak assertions** — they execute the code but don't actually validate behavior. They pass even when the system under test is broken.

Common weak assertions:

| Weak (passes for broken code) | Strong (fails for broken code) |
|-------------------------------|-------------------------------|
| `assert result is not None` | `assert result == expected_value` |
| `assert len(items) > 0` | `assert items == [a, b, c]` |
| `assert response.status_code != 500` | `assert response.status_code == 200` |
| `assert "error" not in output.lower()` | `assert output == "user created: alice"` |
| `assert isinstance(x, dict)` | `assert x == {"id": 1, "name": "alice"}` |
| `assert fn() != fn()` (just "different") | `assert fn() == specific_expected_value` |

How to verify T6 yourself:
1. Mentally introduce a 1-character bug in the function under test (flip `==` to `!=`, change `+` to `-`, return `None`)
2. Would the assertion still pass?
3. Yes → assertion too weak, tighten it to a specific expected value
4. No → assertion is doing its job

This applies especially when **you (the LLM) wrote the test**. Human-authored tests fail this less often; LLM tests fail it 62% of the time without explicit pressure to tighten.

## Coverage targets (not goals)

Coverage is a **floor not a goal**:
- Critical paths (auth/billing/migrations): aim 80%+ branch coverage
- Business logic: 70%+ statement coverage
- UI components: smoke test main paths
- Utilities: unit-test edge cases

**Don't game coverage.** A 95% coverage suite full of `assert function_returns()` tests = false confidence.

## When tests are too slow

Slow tests get skipped → tests get useless. Tier them.

## Test tiers + CI lanes

### Local tiers (Lead/dev machine)

| Tier | Speed | When | Scope |
|------|-------|------|-------|
| **Hot loop** | <5 sec | every save | Unit tests for changed file |
| **Pre-commit** | <30 sec | before commit | Fast subset + new tests |

### CI lanes — 3-phase model

Split CI into 3 phases by trigger + scope. Phase 1 = universal invariants. Phase 2 = touched-only. Phase 3 = comprehensive.

#### Phase 1 — Fast critical lane (every PR, REQUIRED, <5 min)

Universal invariants that MUST always pass — regardless of what was touched.
Catches: "did you accidentally break a foundational guarantee?"

Standard set (project picks subset that applies):
- **Lint / Format** — style enforcement
- **Typecheck** — type safety
- **Smoke unit** — fast unit test subset (highest-signal tests, <2 min)
- **Auth / session guard** — login + session validity tests
- **Tenant isolation** — cross-tenant access tests (if multi-tenant)
- **Money / credit core** — basic payment + credit flow (if app handles money)
- **Migration apply** — schema migrations apply cleanly to fresh DB
- **Build** — production build succeeds

→ Runs on EVERY PR. Independent of file paths touched.
→ All green = foundational invariants intact.

#### Phase 2 — Path-triggered (added to Phase 1 when path touched, REQUIRED when triggered)

Module-specific full test suite, runs in addition to Phase 1.
Catches: "did you break the module you actually touched?"

Pattern: `<path-glob>` touched → `<module>` test suite runs.

Project defines its own path → module mapping. Examples:
- Touch billing module path → billing module's full tests
- Touch publisher module path → publisher module's full tests
- Touch indexation module path → indexation module's full tests
- Touch frontend component path → frontend component tests
- Touch schema/migration path → migration forward + rollback dry-run

→ Module untouched = its lane skipped = not in required set for that PR.
→ Each module owns its own test lane definition.

#### Phase 3 — Nightly / manual (NOT required for merge)

Broad suite, slow, expensive. Cron or manual trigger.
Catches: regression caught next cycle, not blocking current PR.

Standard set:
- **Full stable suite** — cron daily, broader stable subset
- **Integration full** — cron daily, real dependencies
- **Docker / container** — build + run + health check
- **Chaos / fault injection** — cron weekly, partition/failover/OOM
- **Security scan deep** — cron weekly, dep audit + SAST + secret + OWASP
- **E2E** — cron daily, critical user journeys
- **Perf benchmark** — cron weekly, p95 latency / throughput regression
- **Manual trigger** — on-demand for investigation

### Lane principle

- **Phase 1 = fast feedback** (every PR, <5 min)
- **Phase 2 = depth where it matters** (only when path touched, parallel to Phase 1)
- **Phase 3 = comprehensive coverage** (slow, not blocking)
- **Each lane independent** — one fail ≠ others affected
- **Path filter mandatory** for Phase 2 (don't run all conditional lanes on every PR)

### Path filter example (GitHub Actions)

```yaml
# Phase 2 — only when path touched
on:
  pull_request:
    paths:
      - 'backend/auth/**'
      - 'backend/permissions/**'
```

Touching frontend → auth lane skipped → not in required list for that PR.

### Required vs informational

| Phase | Required for merge? |
|-------|---------------------|
| Phase 1 (always-on) | YES — all green required |
| Phase 2 (path-triggered) | YES — when triggered, must pass |
| Phase 3 (nightly/manual) | NO — informational, regression next cycle |

### Auto-merge rule

User OK'd commit + PR → Lead waits for CI → ALL required (Phase 1 + triggered Phase 2) green → **merge auto, no re-ask**.

Re-ask only if:
- Required lane fails → Lead fix + re-push (no ask)
- Phase 3 catches material issue post-merge → notify user
- User requests changes mid-CI

## Common mistakes — DO NOT

- Skip test plan in Plan phase ("I'll figure it out")
- Add code without test for non-trivial logic
- Add test that just asserts no exception (tautology)
- Mock database in integration tests (mock/prod divergence)
- Disable failing test instead of fixing or quarantining
- Write test AFTER bug ships (TDD: failing test first)
- Test implementation details, not behavior
- Game coverage % with trivial tests
- Run only happy path, skip error paths
- Skip race-condition test for concurrent code
- Skip rollback test for migrations
- Run flaky test silently — flag, fix, or quarantine
- Skip test because "hard to write" — that's a code smell, refactor first
