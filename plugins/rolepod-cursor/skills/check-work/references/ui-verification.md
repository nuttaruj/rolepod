<!-- Load when the change touches UI and needs a browser observation. -->

A UI change is verified only by observing the rendered result — never by a
passing typecheck or build. Pick the strongest tool available.

## Tool, in order of preference
1. **Playwright** — if the repo has a Playwright setup: drive the real flow,
   assert on the DOM, capture a screenshot.
2. **Browser MCP / devtools** — navigate, read the DOM, take a screenshot.
3. **Component test renderer** (Testing Library, etc.) — renders the
   component in isolation; proves render + props, not full-page layout.
4. **Local dev server + manual screenshot** — last resort, still a real
   observation.

Never ask the user to screenshot for you when any tool above is available.

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
