---
name: browser-testing-with-devtools
description: Verify browser code by inspecting the live page — read the DOM, capture console errors, watch network traffic, check computed styles. Don't ask the user for screenshots when DevTools can answer.
when_to_use: when building or debugging anything that runs in a browser
paths:
  - "**/*.{tsx,jsx,vue,svelte}"
  - "**/components/**"
  - "**/playwright.config.*"
  - "**/*.spec.{ts,js}"
  - "**/e2e/**"
---

# Browser Testing with DevTools

Browser is source of truth. DOM, console, network, computed styles say what actually happened. Drive DevTools yourself instead of guessing from code or asking user.

## Tool: chrome-devtools-mcp (preferred driver)

Live Chrome session via Chrome DevTools Protocol MCP server. No test file, no assertions — interactive inspection + ad-hoc verify. Companion to Playwright (which owns persistent CI suite, this skill owns interactive debug + verify-first).

Install check: `claude mcp list | grep chrome-devtools`. Not installed → fall back to manual DevTools / Playwright.

| Need | MCP tool |
|------|---------|
| Open URL | `mcp__chrome-devtools__navigate_page` |
| Click element | `mcp__chrome-devtools__click` |
| Fill form | `mcp__chrome-devtools__fill` / `fill_form` |
| Read DOM | `mcp__chrome-devtools__take_snapshot` |
| Screenshot | `mcp__chrome-devtools__take_screenshot` |
| Console errors | `mcp__chrome-devtools__list_console_messages` |
| Network requests | `mcp__chrome-devtools__list_network_requests` |
| Eval JS | `mcp__chrome-devtools__evaluate_script` |
| Lighthouse audit | `mcp__chrome-devtools__lighthouse_audit` |
| Perf trace | `mcp__chrome-devtools__performance_start_trace` / `_stop_trace` |
| Mobile emulate | `mcp__chrome-devtools__emulate` |
| Wait for | `mcp__chrome-devtools__wait_for` |

## DevTools MCP vs Playwright — boundary

| Use case | Pick |
|----------|------|
| Persistent E2E suite (CI gate, PR check) | **Playwright** (`webapp-testing` skill) |
| Cross-browser (Firefox / WebKit) | **Playwright** |
| Visual regression w/ snapshot diff | **Playwright** |
| Quick "did fix work?" verify | **DevTools MCP** |
| Console error / network req inspect | **DevTools MCP** |
| Lighthouse / perf trace | **DevTools MCP** |
| Repro bug interactively | **DevTools MCP** |
| Ad-hoc form fill + verify | **DevTools MCP** |

Complementary, not competitor. QA/frontend-dev: write Playwright suite for CI **and** use DevTools MCP for live verify before commit.

## When to use

- UI change shipped, need proof it renders correctly
- "Works locally but not in browser"
- Console errors / unhandled rejections / hydration mismatches
- Layout breaks at specific viewport
- Network call fails, need actual request/response
- Click handler silently does nothing
- Style doesn't apply, need to know which rule won

## How to apply

1. **Reproduce first** — load page, perform action. No repro = no fix.
2. **Capture console** — error text + stack frame = half the diagnosis
3. **Inspect DOM** — element exists? Right attributes? Right classes?
4. **Check computed styles** — not source CSS, computed value. Cascade overrides surprise.
5. **Watch network** — URL, headers, status, payload, response body
6. **Set breakpoints sparingly** — only when reading code can't explain the value

Prefer scripted (Playwright, Chrome MCP, preview tools) over manual clicking. Scripted = repeatable + machine-readable.

## Diagnostic ladder

| Symptom | First check |
|---------|-------------|
| Element doesn't appear | DOM tab — exists? |
| Exists but invisible | Computed styles — display, opacity, transform |
| Click does nothing | Event listeners panel + console errors |
| Wrong data | Network — what did API return? |
| Hydration mismatch | Compare server HTML vs client DOM after mount |
| Layout shifts | Performance recording with layout-shift events |
| Slow page | Performance + network waterfall |

## Common mistakes

- Trust source code over DOM (build/framework may transform)
- Read Sources panel CSS instead of Computed
- Skip console errors as "unrelated" — they often aren't
- Ask user for screenshot when you could open browser
- File fix without re-checking page after change
- Reproduce once, assume consistency — flake matters
- Test one viewport — mobile breaks differently

## Quick reference

| Need | DevTools surface |
|------|------------------|
| What's rendered | Elements / DOM tree |
| What style applies | Computed (not Styles) |
| Why click failed | Console + Event Listeners |
| What server returned | Network → request → Response |
| Why slow | Performance + Lighthouse |
| Memory leak | Memory → heap snapshot diff |
| Storage state | Application → Cookies / Local Storage |
| A11y tree | Elements → Accessibility pane |

## Verification loop

After every fix:
1. Hard reload (cache off) — stale assets lie
2. Reproduce failing scenario
3. Console clean?
4. Network for new errors
5. Verify at primary viewport + one secondary
6. Capture artifact (screenshot / HAR / console log)

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Looks fine on my machine, ship" | Cached state, dev source maps, your zoom. Drive real session. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
