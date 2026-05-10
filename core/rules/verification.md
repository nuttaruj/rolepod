# Verification — proving your change works

**Scope:** rules for verifying YOUR code change works (post-edit evidence).
**NOT this file:** confirming facts before claiming → `verify-first.md`. Test planning/types/internal execution → `testing.md`.

UI verification deep guide: skills `webapp-testing`, `browser-testing-with-devtools`

Read when: about to verify a code change / report task done.

## Core rule

Every implementation ends with **evidence**. Smallest command that proves changed behavior. Widen as risk grows.

Cannot verify → state why explicitly + remaining risk. **Don't claim success without proof.**

## Evidence by change type

| Change | Verify with |
|--------|-------------|
| Logic / function | Unit test pass output |
| API endpoint | `curl` / Postman / integration test response |
| DB migration | Dry run + reversible rollback check + row count delta |
| UI / frontend | Browser screenshot + console clean + network OK |
| CSS / styling | Browser screenshot at multiple viewports |
| Background task | Log output / queue state / task result |
| Config / env | Restart service + functional smoke test |
| Refactor | Tests pass before AND after (no behavior change) |
| Performance | Before/after metric (p95 latency / bundle size / etc.) |
| Type-only | `tsc --noEmit` / `mypy` clean |

## UI changes — drive browser yourself

**NEVER ask user for screenshot.** Drive browser yourself in this order:

1. **Playwright via Bash**
   - `chromium.launch_persistent_context(user_data_dir=...)`
   - First run headed → user logs in once → cookies persist
2. **`webapp-testing` skill** if present
3. **`browser-testing-with-devtools`** skill
4. **DevTools paste** as last resort

`mcp__Claude_in_Chrome__*` not connected → fall back to Playwright immediately. Don't pause to chase MCP setup.

### Preview tools (Claude Code preview MCP)

If `preview_*` tools available:

1. `preview_start` — launch dev server
2. `preview_eval` — `window.location.reload()` if needed (skip if HMR active)
3. `preview_console_logs` / `preview_logs` / `preview_network` — check errors
4. `preview_snapshot` — content + structure
5. `preview_inspect` — CSS values
6. `preview_click` / `preview_fill` — test interactions → snapshot to confirm
7. `preview_resize` — responsive / dark mode
8. `preview_screenshot` — visual proof for user

Skip steps not relevant to change.

## Test scope — minimum to widen

```
Targeted tests first    → 1-2 tests covering changed code path
↓ if change affects shared/public surface
Module tests           → all tests in changed module
↓ if change affects multiple modules
Integration tests      → critical paths
↓ if high-risk change (auth/billing/migrations)
Full suite             → before merge
```

## Integration vs Unit

| | Unit | Integration |
|---|---|---|
| Speed | Fast | Slow |
| Scope | Function/class isolated | Multi-component real deps |
| Mocks | Yes (deps) | Minimal — real DB/cache |
| Best for | Logic paths, edges | Mock/prod divergence, API contracts, races |
| Risk | Mocks diverge → prod breaks | Flaky, harder debug |

**Balance**: unit for business logic depth. Integration for critical paths (auth, payments, migrations, external APIs, distributed locks).

**Never mock the database in integration tests.** Mock/prod divergence has burned us before.

## Goal-driven verification

| Task type | Verify by |
|-----------|-----------|
| Add validation | Test with invalid input → expect rejection |
| Fix bug | Reproducing test → was failing → now passing |
| Add feature | New test for happy path + edge cases |
| Refactor | Existing tests pass unchanged |
| Performance | Metric before vs after |

## Reporting evidence to user

Format:
```
Changed: [what]
Verified: [how — test command + output snippet]
Risk: [what this doesn't cover]
Next: [what user should do / next step]
```

Example:
```
Changed: hold_credit() now returns 409 on race
Verified: pytest test_credit_race.py::test_concurrent_hold → 1 passed
Risk: Doesn't cover Redis failover; manual test needed for that
Next: Ship — gate is green
```

## Common mistakes — DO NOT

- "Should work" without running it
- Ask user to verify UI when you can drive browser
- Skip verification on "trivial" change — trivial changes break too
- Mock the database in integration test
- Verify only happy path — test edge cases
- Hide failed test output from user
