# Verification — proving your change works

**Scope:** verify YOUR code change (post-edit evidence).
**NOT this file:** confirming facts before claiming → `verify-first.md`. Test planning → `testing.md`.

UI verification: skills `webapp-testing`, `browser-testing-with-devtools`.

Read when: about to verify code change / report task done.

## Core rule

Every implementation ends with **evidence**. Smallest command that proves changed behavior. Widen as risk grows.

Can't verify → state why + risk. **Don't claim success without proof.**

## Evidence by change type

| Change | Verify with |
|--------|-------------|
| Logic / function | Unit test pass output |
| API endpoint | `curl` / Postman / integration response |
| DB migration | Dry run + rollback check + row count delta |
| UI / frontend | Browser screenshot + console clean + network OK |
| CSS / styling | Screenshot at multiple viewports |
| Background task | Log / queue state / task result |
| Config / env | Restart + functional smoke |
| Refactor | Tests pass before AND after |
| Performance | Before/after metric (p95 / bundle / etc.) |
| Type-only | `tsc --noEmit` / `mypy` clean |

## UI — drive browser yourself

**NEVER ask user for screenshot.** Order:

1. **Playwright via Bash** — `chromium.launch_persistent_context(user_data_dir=...)`. First run headed → user logs in → cookies persist.
2. **`webapp-testing` skill**
3. **`browser-testing-with-devtools`** skill
4. **DevTools paste** last resort

`mcp__Claude_in_Chrome__*` not connected → Playwright. Don't pause to chase MCP setup.

### Preview tools (Claude Code preview MCP)

If `preview_*` available:
1. `preview_start` — launch dev server
2. `preview_eval` — reload if needed (skip if HMR active)
3. `preview_console_logs` / `preview_logs` / `preview_network` — errors
4. `preview_snapshot` — content + structure
5. `preview_inspect` — CSS values
6. `preview_click` / `preview_fill` → snapshot to confirm
7. `preview_resize` — responsive / dark mode
8. `preview_screenshot` — visual proof

Skip irrelevant steps.

## Test scope — widen as needed

```
Targeted    → 1-2 tests covering changed path
↓ shared / public surface
Module      → all tests in changed module
↓ multiple modules
Integration → critical paths
↓ high-risk (auth/billing/migrations)
Full suite  → before merge
```

## Integration vs Unit

| | Unit | Integration |
|---|---|---|
| Speed | Fast | Slow |
| Scope | Function isolated | Multi-component real deps |
| Mocks | Yes (deps) | Minimal — real DB/cache |
| Best for | Logic paths, edges | Mock/prod divergence, contracts, races |
| Risk | Mocks diverge | Flaky, harder debug |

**Balance**: unit for business logic depth. Integration for critical paths (auth/payments/migrations/external/locks).

**Never mock DB in integration tests.** Mock/prod divergence burns.

## Goal-driven verification

| Task | Verify by |
|------|-----------|
| Add validation | Invalid input → expect rejection |
| Fix bug | Reproducing test was failing → now passing |
| Add feature | New test for happy path + edges |
| Refactor | Existing tests pass unchanged |
| Performance | Metric before vs after |

## Reporting to user

```
Changed: [what]
Verified: [how — command + output snippet]
Risk: [what this doesn't cover]
Next: [what user should do]
```

Example:
```
Changed: hold_credit() now returns 409 on race
Verified: pytest test_credit_race.py::test_concurrent_hold → 1 passed
Risk: Doesn't cover Redis failover
Next: Ship — gate is green
```

## Common mistakes — DO NOT

- "Should work" without running
- Ask user to verify UI when you can drive browser
- Skip verification on "trivial" change
- Mock DB in integration
- Verify only happy path
- Hide failed test output
