---
name: webapp-testing
description: Test local web apps with Playwright. Use when verifying frontend functionality, debugging UI behavior, or capturing repeatable evidence of UI changes. Covers when to use Playwright over manual DevTools, scripted flows, and how to keep tests stable.
---

# Webapp Testing

Manual DevTools answers a one-time question. Playwright answers it the same way next week. Use Playwright when the verification needs to repeat, the flow has multiple steps, or you need an artifact to attach to a PR.

## When to use

- Multi-step flow needs end-to-end verification (login → action → result)
- Bug reproduces only under specific UI conditions
- Need a regression test, not just a one-time check
- Need a screenshot / video / trace as evidence
- Testing across viewports
- Lead is verifying their own change before merge

## When NOT to use

- One-off DOM inspection → use DevTools directly
- Backend-only logic → use unit/integration tests
- Visual design review → manual eye + screenshot is faster
- Reproducing a bug once for diagnosis → DevTools

## Test pyramid placement

| Layer | Tool | Speed | Use for |
|-------|------|-------|---------|
| Unit | Vitest / Jest | <100ms | Logic, hooks, utils |
| Component | Testing Library | <500ms | Single component behavior |
| Integration | Testing Library + MSW | 1-3s | Component + data layer |
| E2E (Playwright) | Playwright | 5-30s | Full user flows in real browser |

E2E is the slowest layer. Use it sparingly — for the 5-10 user flows that must never break.

## How to apply

1. **Pick the flow** — login, primary path through your feature, the one users hit most. Don't E2E everything.
2. **Stable selectors** — `data-testid` or accessible role/name. Never CSS classes or nth-child.
3. **One assertion path per test** — happy path or one failure mode, not both.
4. **Wait on conditions, not timers** — `expect(locator).toBeVisible()` not `setTimeout`.
5. **Isolate state** — each test sets up its own data, doesn't depend on test order.
6. **Screenshot on failure** — Playwright does this by default; keep it on.

## Stable selector ladder

| Best to worst |
|---------------|
| `getByRole('button', { name: 'Save' })` |
| `getByLabel('Email')` |
| `getByTestId('save-button')` |
| `getByText('Save')` (if unique) |
| `locator('.save-btn')` (avoid — class can change) |
| `locator(':nth-child(3)')` (avoid — position can change) |

Tests that fail when the CSS is restyled are noise. Selectors should target meaning, not pixels.

## Common test shapes

```
test('user can submit form', async ({ page }) => {
  await page.goto('/form')
  await page.getByLabel('Email').fill('test@example.com')
  await page.getByRole('button', { name: 'Submit' }).click()
  await expect(page.getByText('Thanks')).toBeVisible()
})
```

Three lines: setup, action, assertion. If a test grows past 10 lines, it's testing too much.

## Debugging a flaky test

| Symptom | Likely cause |
|---------|--------------|
| Passes locally, fails CI | Animation timing, viewport, font loading |
| Passes alone, fails in suite | Shared state between tests |
| Fails 1 in 10 runs | Race between assertion and async update |
| Passes today, fails tomorrow | Date-dependent or timezone bug |

Fix before merging. A flaky test is worse than no test — it teaches the team to ignore failures.

## Common mistakes

- E2E-ing every code path (slow, brittle, expensive)
- Using CSS class selectors that break on style changes
- `await page.waitForTimeout(2000)` instead of waiting on a condition
- Sharing state between tests
- Skipping the screenshot/trace artifact
- Testing in only one viewport
- Mocking the entire backend so you're not really testing E2E
- Letting flaky tests stay green by retry-on-fail without diagnosing

## Quick reference

| Need | Playwright API |
|------|---------------|
| Find by accessible name | `getByRole('button', { name: 'Save' })` |
| Find by label | `getByLabel('Email')` |
| Wait for element | `await expect(locator).toBeVisible()` |
| Wait for URL change | `await page.waitForURL('/dashboard')` |
| Capture screenshot | `await page.screenshot({ path: 'x.png' })` |
| Record trace | Run with `--trace on` |
| Mock network | `page.route('**/api/x', route => route.fulfill(...))` |
| Set viewport | `page.setViewportSize({ width, height })` |
| Run headed for debug | `--headed --debug` |

## Verification report format

After running tests, report:

```
Test run: <suite name>
- Passed: N
- Failed: N (with file:line + screenshot path)
- Flaky: N (passed on retry — investigate)
- Duration: Ns

Evidence:
- <path to screenshot/trace>
```

Don't claim "tests pass" without numbers.
