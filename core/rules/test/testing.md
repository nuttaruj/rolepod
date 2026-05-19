---
paths:
  - "**/test/**"
  - "**/tests/**"
  - "**/__tests__/**"
  - "**/*test*.{ts,tsx,js,jsx,py,go,rs}"
  - "**/*_test.{go,rs}"
  - "**/*spec*.{ts,tsx,js,jsx}"
  - "**/*.test.{ts,tsx,js,jsx,py}"
  - "**/*.spec.{ts,tsx,js,jsx,py}"
---

# Testing — internal execution

**Scope:** when/what/how to test. Internal only (Lead + qa-tester — no external AI).
**NOT this file:** post-change evidence → skill `check-work`. Reviewer routing → skill `review-code`.

Read when: planning task / before commit / question on what to test.

## Decision matrix

### MUST test (block commit if absent)

| Task type | Required test |
|-----------|---------------|
| Bug fix | Reproducing test (failing → passing) |
| New feature | Happy path + edge cases + error path |
| DB migration | Dry run + rollback + row count delta |
| Auth / permission | Access matrix (allowed + denied) |
| Money / billing / credit | All flows + concurrent (race) |
| Race condition fix | Concurrent test (threads / async) |
| API contract change | Contract test (request + response shape) |
| Performance fix | Before/after benchmark |
| Security fix | Exploit repro → blocked confirmed |
| File / data deletion | Idempotent + reversible test |

### SHOULD test

| Task | Test |
|------|------|
| Refactor | Existing tests pass before AND after |
| Library upgrade | Smoke + integration on critical paths |
| Config change | Restart + functional smoke |
| New dependency | Integration exercising new dep |
| Background task | Trigger + side-effect + idempotency |

### SKIP (no behavior change)

- Typo / comment / docstring
- Doc-only (`*.md`, README)
- Pure rename (typechecker catches)
- Dead code removal (verified unused)
- Reformat / lint fix

## Test types (priority order)

| Type | Speed | Catches | When |
|------|-------|---------|------|
| **Unit** | fast | logic, edges | Business logic, pure fns |
| **Integration** | slow | mock/prod drift, contracts | Auth, payments, migrations, external APIs, locks |
| **Contract** | medium | FE↔BE drift | API endpoint / response model changes |
| **E2E** | slowest | full-flow regression | Critical journeys (login, checkout) |
| **Smoke** | fast | "does it boot" | After config / before deploy |
| **Property/fuzz** | medium | unexpected input | Validation, parsers, security boundary |
| **Benchmark** | slow | perf regression | Perf-sensitive code |

### Balance

- Unit = business logic depth (every branch)
- Integration = critical paths (auth/payments/migrations/external/locks)
- **Never mock DB in integration tests** — mock/prod divergence burns
- Contract when changing API surface
- E2E sparingly — slow + flaky

## Workflow integration

- **Explore**: read existing tests, note flaky ones
- **Plan**: test plan in output (unit / integration / edges / existing-to-verify). Vague "add tests" rejected.
- **Implement**: TDD-light non-trivial (failing test → code → pass → refactor); tests-after OK for mechanical
- **Pre-commit**: T1-T6 (canonical in CLAUDE.md)
- **Post-merge**: CI runs critical paths

## Internal execution

### Lead direct (fast)

Tests exist, just run.

```bash
pytest tests/ -v   # or: npm test / go test ./... / cargo test
```

Read output, report pass/fail.

### qa-tester subagent (complex)

Use when: write new tests (multi-file) / fix failing / investigate flaky / business logic with full context.

### Brief qa-tester

```
Task: <test goal>
Files: <test file paths>
Cases:
  - <case 1>: <expected>
  - <case 2>: <edge>
Constraints: Real DB (no mocks for integration). Don't mock <X>. Match style of <file>.
Success: all cases pass + no existing test broken
Cap: ≤12 tool_uses, ≤5 files
```

### TDD-light (Lead)

1 file, 1 function: failing test → code → pass → refactor. Deep guide: skill `implement-plan`.

## Test quality

| Bad | Good |
|-----|------|
| `assert x == x` | `assert validate("invalid") == False` |
| Mock system under test | Test real code, mock external deps |
| "doesn't crash" | "returns correct value" |
| 1 mega-test, 10 things | 10 focused tests |
| `test_function_works` | `test_validate_rejects_empty_string` |
| Hidden setup | Self-contained |
| Flaky | Deterministic |

## T6 — assertion correctness (LLM-specific)

**Would a 1-character bug still let the assertion pass?** Yes → too weak.

Background: 62% of LLM-generated tests have weak assertions (arXiv 2402.13521).

| Weak | Strong |
|------|--------|
| `assert result is not None` | `assert result == expected_value` |
| `assert len(items) > 0` | `assert items == [a, b, c]` |
| `assert status != 500` | `assert status == 200` |
| `assert "error" not in out` | `assert out == "user created: alice"` |
| `assert isinstance(x, dict)` | `assert x == {"id": 1}` |

Verify: mentally flip `==` to `!=` or return `None`. Assertion still passes → tighten.

## Coverage (floor, not goal)

- Critical paths (auth/billing/migrations): 80%+ branch
- Business logic: 70%+ statement
- UI: smoke main paths
- Utils: unit edge cases

Don't game coverage. 95% of `assert function_returns()` = false confidence.

## Test tiers + CI lanes

### Local

| Tier | Speed | When | Scope |
|------|-------|------|-------|
| Hot loop | <5s | every save | Unit for changed file |
| Pre-commit | <30s | before commit | Fast subset + new tests |

### CI — 3-phase

#### Phase 1 — Fast critical (every PR, REQUIRED, <5 min)

Universal invariants. Run regardless of touched path:

- Lint / Format
- Typecheck
- Smoke unit (<2 min)
- Auth / session guard
- Tenant isolation (if multi-tenant)
- Money / credit core (if handles money)
- Migration apply (fresh DB)
- Build

#### Phase 2 — Path-triggered (REQUIRED when triggered)

Module's full test suite when its path touched. Untouched module = lane skipped.

Examples: billing path → billing tests. Schema path → migration forward + rollback dry-run.

#### Phase 3 — Nightly / manual (NOT required for merge)

Full stable suite (daily) / integration full (daily) / docker / chaos (weekly) / security deep (weekly) / E2E (daily) / perf benchmark (weekly) / manual.

### Path filter example

```yaml
on:
  pull_request:
    paths:
      - 'backend/auth/**'
      - 'backend/permissions/**'
```

### Required vs informational

| Phase | Required? |
|-------|-----------|
| 1 (always-on) | YES |
| 2 (path-triggered) | YES when triggered |
| 3 (nightly/manual) | NO |

### Auto-merge

User OK'd commit + PR → wait CI → ALL required green → merge auto, no re-ask.

Re-ask only if: required lane fails → Lead fix + re-push (no ask). Phase 3 catches post-merge → notify.

## Common mistakes — DO NOT

- Skip test plan in Plan phase
- Add code without test for non-trivial logic
- Tautology assert
- Mock DB in integration
- Disable failing test
- Test after bug ships
- Test implementation, not behavior
- Game coverage
- Skip race test for concurrent code
- Skip rollback test for migrations
- Run flaky silently
- "Hard to write" = refactor first
