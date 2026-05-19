---
name: webapp-testing
description: Compatibility shim — Playwright-based webapp verification now lives in `check-work` (as one of the evidence modalities).
when_to_use: when verifying frontend functionality, debugging UI behavior, or capturing repeatable evidence of UI changes
tier: 3
redirect_to: check-work
---

# webapp-testing

Compatibility shim. Playwright verification now lives in **`check-work`**.

→ Open `core/skills/check-work/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `check-work` is not available

Minimum viable fallback:

1. Use Playwright for a persistent UI test suite (not one-off poking)
2. Real browser, not headless DOM emulation, when verifying user behavior
3. Test the user's path, not the implementation detail
4. Screenshot on failure for diagnosis
5. Mock at the network fixture boundary only; do not mock the system under test
6. Keep tests deterministic — no implicit waits on time, only on conditions
7. Run the test, capture the result, attach evidence to the response
