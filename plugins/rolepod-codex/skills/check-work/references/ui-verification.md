<!-- Load when the change touches UI and needs a browser observation. -->

A UI change is verified only by observing the rendered result — never by a
passing typecheck or build. Pick the strongest tool available.

## Tool, in order of preference

1. **rolepod-mcp plugin** — if the `/verify-ui` skill is available
   (`rolepod-mcp` sibling plugin installed), invoke it. Multi-platform
   (web + iOS + Android). Pass target URL/app, step sequence, and expected
   assertions; the skill returns evidence paths under
   `./.rolepod-mcp/artifacts/{run_id}/`. Related capabilities the same
   plugin ships: `/audit-a11y` (WCAG audit) and `/visual-diff` (pixel
   baseline comparison).
2. **Playwright MCP** — if `browser_snapshot` is registered (Microsoft's
   Playwright MCP server installed), orchestrate atomic calls: open →
   snapshot → resolve refs from your step intent → click / type →
   re-snapshot → assert each expectation. Web only.
3. **Chrome DevTools MCP** — similar atomic orchestration if its tools are
   registered. Web only, Chromium-only.
4. **Playwright (direct)** — if the repo has its own Playwright setup:
   drive the real flow, assert on the DOM, capture a screenshot.
5. **Browser MCP / devtools** — navigate, read the DOM, take a screenshot.
6. **Component test renderer** (Testing Library, etc.) — renders the
   component in isolation; proves render + props, not full-page layout.
7. **Local dev server + manual screenshot** — last resort, still a real
   observation.

Never ask the user to screenshot for you when any tool above is available.

This is a fallback chain. Pick the first tier that is actually available
and use it; do not descend to a weaker tier when a stronger one is present.

## What to observe
- The changed element renders, with the expected text / state.
- The states the spec named: empty, loading, error, populated.
- The interaction: click / submit / navigate does what the spec says.
- No regression in the surrounding layout.

## What does NOT verify UI
- `tsc` / build success — proves types, not render.
- A unit test on a helper — proves logic, not the screen.
- "The component is exported correctly" — proves nothing visual.

## Evidence to record
The tool used, the DOM node or text observed, the screenshot path, and the
interaction performed. One line in the evidence block.
