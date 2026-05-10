---
name: browser-testing-with-devtools
description: Verify browser code by inspecting the live page. Use when building or debugging anything that runs in a browser — read the DOM, capture console errors, watch network traffic, check computed styles. Don't ask the user for screenshots when DevTools can answer.
---

# Browser Testing with DevTools

When the bug is in a browser, the browser is the source of truth. DOM, console, network, and computed styles say what actually happened — not what the source says should happen. Drive DevTools yourself instead of guessing from code or asking the user.

## When to use

- UI change shipped, need proof it renders correctly
- "It works locally but not in browser" symptoms
- Console errors / unhandled rejections / hydration mismatches
- Layout breaks at specific viewport
- Network call fails and you need the actual request/response
- Click handler silently does nothing
- Style doesn't apply and you need to know which rule won

## How to apply

1. **Reproduce first** — load the page, perform the action that triggers the issue. No repro = no fix.
2. **Capture console** — error text + stack frame is half the diagnosis.
3. **Inspect DOM** — does the element exist? Right attributes? Right class list?
4. **Check computed styles** — not the source CSS, the computed value. Cascade overrides surprise people.
5. **Watch network** — request URL, headers, status, payload, response body.
6. **Set breakpoints sparingly** — only when reading the code can't explain the value.

Prefer scripted DevTools (Playwright, Chrome MCP, preview tools) over manual clicking. Scripted = repeatable + machine-readable.

## Diagnostic ladder

| Symptom | First check |
|---------|-------------|
| Element doesn't appear | DOM tab — does it exist? |
| Element exists but invisible | Computed styles — display, opacity, transform |
| Click does nothing | Event listeners panel + console for errors |
| Wrong data | Network — what did the API actually return? |
| Hydration mismatch | Compare server HTML vs client DOM after mount |
| Layout shifts | Performance recording with layout-shift events |
| Slow page | Performance + network waterfall |

## Common mistakes

- Trusting source code over the DOM (build step or framework may transform it)
- Reading Sources panel CSS instead of Computed styles
- Skipping console errors because "they look unrelated" — they often aren't
- Asking the user for a screenshot when you could open the browser yourself
- Filing the bug fix without re-checking the page after the change
- Reproducing once and assuming consistency — flake matters
- Testing only one viewport — mobile breaks differently

## Quick reference

| Need | DevTools surface |
|------|------------------|
| What's rendered | Elements / DOM tree |
| What style applies | Computed (not Styles) |
| Why click failed | Console + Event Listeners |
| What server returned | Network → request → Response tab |
| Why slow | Performance recording + Lighthouse |
| Memory leak | Memory → heap snapshot diff |
| Storage state | Application → Cookies / Local Storage |
| Accessibility tree | Elements → Accessibility pane |

## Verification loop

After every fix:

1. Hard reload (cache off) — stale assets lie
2. Reproduce the failing scenario
3. Check console clean
4. Check network for new errors
5. Verify at primary viewport + one secondary
6. Capture artifact (screenshot / HAR / console log) for the report
