---
name: webapp-testing
description: Test local web apps with Playwright. Covers when to use Playwright over manual DevTools, scripted flows, and how to keep tests stable.
when_to_use: when verifying frontend functionality, debugging UI behavior, or capturing repeatable evidence of UI changes
paths:
  - "**/playwright.config.*"
  - "**/*.spec.{ts,js}"
  - "**/e2e/**"
---

# Webapp Testing

Manual DevTools answers once. Playwright answers same way next week. Use Playwright when verification repeats, flow is multi-step, or you need a PR artifact.

## When to use

- Multi-step E2E flow (login → action → result)
- Bug reproduces only under specific UI conditions
- Need regression test, not one-time check
- Need screenshot / video / trace as evidence
- Cross-viewport testing
- Lead verifying own change before merge

## When NOT to use

- One-off DOM inspection → DevTools directly
- Backend-only logic → unit/integration tests
- Visual design review → manual eye + screenshot faster
- Reproducing bug once for diagnosis → DevTools

## Test pyramid placement

| Layer | Tool | Speed | Use for |
|-------|------|-------|---------|
| Unit | Vitest / Jest | <100ms | Logic, hooks, utils |
| Component | Testing Library | <500ms | Single component |
| Integration | Testing Library + MSW | 1-3s | Component + data layer |
| E2E (Playwright) | Playwright | 5-30s | Full user flows in real browser |

E2E slowest. Use sparingly — 5-10 flows that must never break.

## How to apply

1. **Pick flow** — login, primary path, most-hit
2. **Stable selectors** — `data-testid` or accessible role/name. Never CSS classes or nth-child.
3. **One assertion path per test** — happy or one failure, not both
4. **Wait on conditions, not timers** — `expect(locator).toBeVisible()` not `setTimeout`
5. **Isolate state** — each test sets up own data, no order dependency
6. **Screenshot on failure** — Playwright default; keep on

## Stable selector ladder

Best to worst:
- `getByRole('button', { name: 'Save' })`
- `getByLabel('Email')`
- `getByTestId('save-button')`
- `getByText('Save')` (if unique)
- `locator('.save-btn')` — avoid (class changes)
- `locator(':nth-child(3)')` — avoid (position changes)

Tests failing when CSS restyles = noise. Target meaning, not pixels.

## Test shape

```
test('user can submit form', async ({ page }) => {
  await page.goto('/form')
  await page.getByLabel('Email').fill('test@example.com')
  await page.getByRole('button', { name: 'Submit' }).click()
  await expect(page.getByText('Thanks')).toBeVisible()
})
```

3 lines: setup, action, assertion. >10 lines = testing too much.

## Debugging flaky tests

| Symptom | Cause |
|---------|-------|
| Passes locally, fails CI | Animation timing, viewport, font loading |
| Passes alone, fails in suite | Shared state |
| 1 in 10 runs | Race between assertion and async update |
| Passes today, fails tomorrow | Date/timezone bug |

Fix before merge. Flaky test < no test — teaches team to ignore failures.

## Common mistakes

- E2E every path (slow, brittle)
- CSS class selectors that break on style changes
- `await page.waitForTimeout(2000)` instead of waiting on condition
- Sharing state between tests
- Skipping screenshot/trace artifact
- Testing one viewport only
- Mocking entire backend → not really testing E2E
- Flaky stays green via retry-on-fail without diagnosing

## Quick reference

| Need | API |
|------|-----|
| By accessible name | `getByRole('button', { name: 'Save' })` |
| By label | `getByLabel('Email')` |
| Wait for element | `await expect(locator).toBeVisible()` |
| Wait for URL | `await page.waitForURL('/dashboard')` |
| Screenshot | `await page.screenshot({ path: 'x.png' })` |
| Record trace | `--trace on` |
| Mock network | `page.route('**/api/x', route => route.fulfill(...))` |
| Set viewport | `page.setViewportSize({ width, height })` |
| Headed debug | `--headed --debug` |

## Verification report

```
Test run: <suite name>
- Passed: N
- Failed: N (file:line + screenshot path)
- Flaky: N (passed on retry — investigate)
- Duration: Ns

Evidence:
- <path to screenshot/trace>
```

Don't claim "tests pass" without numbers.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Manual click-through is faster" | Manual passes degrade as features grow; Playwright scales. Write once, runs forever. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
