---
name: web-design-guidelines
description: Review UI for Web Interface Guidelines compliance — accessibility, hierarchy, consistency, and platform conventions. Outputs a structured review with severity-tagged findings.
when_to_use: when auditing design quality, checking a11y, or reviewing UX before merge
---

# Web Design Guidelines

Checklist against rules that exist because users got hurt when ignored. Not taste critique.

## When to use

- Pre-merge UI review
- "Is this accessible?"
- "Audit this design / page / component"
- After designer handoff, before implementation
- After implementation, before ship

## Review axes

Six axes. For each: PASS / WARN / FAIL with file:line evidence.

### A1 — Accessibility (WCAG 2.1 AA floor)

- Keyboard reach: every interactive element via Tab
- Visible focus indicators (not removed without replacement)
- Semantic HTML (`button`, `a`, `nav`, `main`, `h1-h6`)
- Form labels associated (`label htmlFor` or `aria-label`)
- Color contrast: 4.5:1 body, 3:1 large/UI
- No info conveyed by color alone
- Alt text on meaningful images, empty alt on decorative
- Live regions for dynamic content
- Skip-to-content link on long pages
- Heading order not skipped (no h1→h3)

### A2 — Hierarchy

- One primary action per view (visually dominant)
- Most important data: largest / first / most prominent
- Type scale used (no arbitrary sizes)
- Spacing scale used (no magic numbers)
- Visual weight matches importance

### A3 — Consistency

- Same action, same component, same place across app
- Color tokens used (no inline `#hex` outside theme)
- Spacing tokens used (no magic px)
- Component reuse (no near-duplicate variants)
- Iconography from one set
- Naming convention consistent (sentence vs Title vs UPPER)

### A4 — Feedback

- Every action has visible feedback within 100ms
- Loading state shown if response >300ms
- Errors specific and actionable, not "Something went wrong"
- Success confirmation visible
- Destructive actions confirmed before execution
- Form validation inline + on submit, not only on submit

### A5 — Platform conventions

- Native scroll preserved (don't hijack)
- Browser back/forward works
- URLs reflect state (deep-linkable)
- Right-click does what users expect
- Tab order follows visual order
- Dark mode respected if system uses it

### A6 — Resilience

- Loading / Empty (with next action) / Error (with recovery) / Partial states designed
- Long content doesn't break layout
- Short content doesn't look broken
- 1px to 100% width works

## Severity tags

| Tag | Meaning | Ship gate |
|-----|---------|-----------|
| BLOCKER | a11y violation, broken keyboard nav, color-only info, missing label | DO NOT MERGE |
| HIGH | inconsistent primary action, missing error state, no feedback | Fix before merge |
| MEDIUM | density inconsistency, magic spacing, suboptimal hierarchy | Fix this PR if cheap |
| LOW | nit on tone, minor polish | Ship, file follow-up |

## How to apply

1. Open page/component
2. Walk A1 → A6 in order
3. Each violation: axis, severity, file:line, fix
4. Output structured report
5. Re-test after fixes — don't approve from memory

## Output template

```
Web Guidelines Review — <surface>

A1 Accessibility:
  [BLOCKER] <issue> at <file:line> — <fix>
  [PASS] keyboard reach

A2 Hierarchy:
  [HIGH] <issue> — <fix>

[continue A3-A6]

Summary:
  Blockers: N
  High: N
  Medium: N
  Low: N

Ship gate: PASS | FAIL
```

## Common mistakes

- Reviewing taste not guidelines (bikeshedding colors)
- Approving with blockers because "it works"
- Missing keyboard testing (most common a11y miss)
- Skipping reduced-motion + dark mode + narrow viewport
- "LGTM" without walking axes
- Every nit as blocker (devalues tag)
- Not re-checking after fix claimed

## Fastest checks

| Tool | Catches |
|------|---------|
| Tab through page (keyboard only) | a11y reach + focus rings |
| axe DevTools / Lighthouse | a11y automated rules |
| Contrast checker | WCAG ratios |
| Disable CSS / reader mode | semantic HTML quality |
| Resize to 320px | mobile / responsive breaks |
| `prefers-reduced-motion: reduce` | motion fallback |
| Dark mode toggle | theme parity |
| Disable JS | progressive enhancement |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Looks accessible, checked contrast" | Contrast = 1 of ~40 WCAG criteria. Keyboard, focus, ARIA, motion all fail silently to sighted checks. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
