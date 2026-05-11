---
name: web-design-guidelines
description: Review UI for Web Interface Guidelines compliance — accessibility, hierarchy, consistency, and platform conventions. Use when auditing design quality, checking a11y, or reviewing UX before merge. Outputs a structured review with severity-tagged findings.
---

# Web Design Guidelines

A guidelines review is not a taste critique. It's a checklist against rules that exist because users got hurt when the rules weren't followed. This skill applies that checklist and reports findings the same way each time.

## When to use

- Pre-merge UI review
- "Is this accessible?" question
- "Audit this design / page / component"
- After a designer handoff, before implementation
- After implementation, before ship

## Review axes

Review the UI against six axes. For each, output: PASS / WARN / FAIL with file:line evidence.

### A1 — Accessibility (WCAG 2.1 AA floor)

- Keyboard reach: every interactive element via Tab
- Visible focus indicators (not removed without replacement)
- Semantic HTML (`button`, `a`, `nav`, `main`, `h1-h6`)
- Form labels associated (`label htmlFor` or `aria-label`)
- Color contrast: 4.5:1 body, 3:1 large/UI components
- No info conveyed by color alone
- Alt text on meaningful images, empty alt on decorative
- Live regions for dynamic content
- Skip-to-content link on long pages
- Heading order not skipped (no h1→h3)

### A2 — Hierarchy

- One primary action per view (visually dominant)
- Most important data is largest / first / most prominent
- Type scale used (not arbitrary sizes)
- Spacing scale used (not magic numbers)
- Visual weight matches importance

### A3 — Consistency

- Same action, same component, same place across the app
- Color tokens used (no inline `#hex` outside theme)
- Spacing tokens used (no magic px values)
- Component reuse (no near-duplicate variants)
- Iconography from one set
- Naming convention consistent (sentence vs Title vs UPPER)

### A4 — Feedback

- Every action has visible feedback within 100ms
- Loading states shown if response >300ms
- Errors specific and actionable, not "Something went wrong"
- Success confirmation visible
- Destructive actions confirmed before execution
- Form validation inline + on submit, not only on submit

### A5 — Platform conventions

- Native scroll behavior preserved (don't hijack)
- Browser back/forward works
- URLs reflect state (deep-linkable)
- Right-click does what users expect
- Tab order follows visual order
- Dark mode respected if system uses it

### A6 — Resilience

- Loading state designed
- Empty state designed (with next action)
- Error state designed (with recovery)
- Partial / degraded state designed
- Long content doesn't break layout
- Short content doesn't look broken
- 1px to 100% width works

## Severity tags

| Tag | Meaning | Ship gate |
|-----|---------|-----------|
| BLOCKER | a11y violation, broken keyboard nav, color-only info, missing label | DO NOT MERGE |
| HIGH | inconsistent primary action, missing error state, no feedback | Fix before merge |
| MEDIUM | density inconsistency, magic spacing, suboptimal hierarchy | Fix this PR if cheap |
| LOW | nit on tone, minor polish, nice-to-have improvement | Ship, file follow-up |

## How to apply

1. Open the page / component being reviewed
2. Walk axes A1 → A6 in order
3. For each violation: note axis, severity, file:line, fix
4. Output structured report (template below)
5. Re-test after fixes — don't approve from memory

## Output template

```
Web Guidelines Review — <surface>

A1 Accessibility:
  [BLOCKER] <issue> at <file:line> — <fix>
  [PASS] keyboard reach
  ...

A2 Hierarchy:
  [HIGH] <issue> — <fix>
  ...

[continue through A6]

Summary:
  Blockers: N
  High: N
  Medium: N
  Low: N

Ship gate: PASS | FAIL
```

## Common mistakes

- Reviewing taste instead of guidelines (bikeshedding color choices)
- Approving with blockers because "it works"
- Missing keyboard testing (most common a11y miss)
- Skipping reduced-motion + dark mode + narrow viewport
- "LGTM" without walking the axes
- Filing every nit as a blocker (devalues the tag)
- Not re-checking after fix claimed

## Quick reference — fastest checks

| Tool | Catches |
|------|---------|
| Tab through page (keyboard only) | a11y reach + focus rings |
| axe DevTools / Lighthouse | a11y automated rules |
| Contrast checker on suspect colors | WCAG ratios |
| Disable CSS / use reader mode | semantic HTML quality |
| Resize to 320px | mobile / responsive breaks |
| `prefers-reduced-motion: reduce` | motion fallback |
| Dark mode toggle | theme parity |
| Disable JS | progressive enhancement (if relevant) |

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "Looks accessible, I checked the contrast" | Contrast is one of ~40 WCAG criteria. Keyboard-only navigation, focus indicators, ARIA roles, motion preferences — all fail silently to sighted-only checks. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
