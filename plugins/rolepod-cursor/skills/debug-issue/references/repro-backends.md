<!-- Load when the bug lives in a browser / UI or a WordPress runtime, or when a sibling plugin left evidence. -->

# Repro backends

## UI / browser bugs — backend order

Take the first one available:
1. `rolepod-uiproof` when installed: `/check-errors` returns console + network failures during the flow, `/verify-ui` returns minimized repro steps + artifacts — reuse those steps as the failing test.
2. Playwright MCP when connected — atomic `browser_*` calls; minimize the sequence yourself.
3. Chrome DevTools MCP when connected (Chromium only) for bugs whose cause sits below the rendered DOM.
4. Manual — describe the candidate repro and ask the user to confirm it.

## WordPress runtime / plugin / theme bugs

`rolepod-wplab` `/wp-diagnose` when installed (error log, hook trace, query log — WP findings only; the debug flow stays in debug-issue). Otherwise `wp-cli` or `wp-content/debug.log`.

## Sibling evidence

The marker `<git-root>/.rolepod/parent-active` confirms the protocol is live; with it, children write evidence under `<git-root>/.rolepod/evidence/` → reference those artifacts in the hypothesis ledger and the fix.
No marker → evidence in that directory is stale or from another task; verify it before trusting it.
