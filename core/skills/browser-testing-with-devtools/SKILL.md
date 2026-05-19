---
name: browser-testing-with-devtools
description: Compatibility shim — live-page DevTools inspection (DOM read, console, network, computed styles) now lives in `check-work`.
when_to_use: when building or debugging anything that runs in a browser
tier: 3
redirect_to: check-work
---

# browser-testing-with-devtools

Compatibility shim. DevTools-driven verification now lives in **`check-work`**.

→ Open `core/skills/check-work/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `check-work` is not available

Minimum viable fallback:

1. Use the browser DevTools MCP / extension to read the live page
2. Console errors are evidence — capture them, do not ignore them
3. Network log shows failed requests; check status + response shape
4. Computed styles tell you what the browser actually applied, not what the CSS said
5. Use DevTools for one-off checks; reach for Playwright when you need a persistent suite
6. Never ask the user for a screenshot when DevTools / MCP can answer
7. Include the DOM snippet / console line / network entry that proves the claim
