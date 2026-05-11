---
name: interface-design
description: Design dashboards, admin panels, and tool/app interfaces — interfaces users return to and operate. NOT for marketing pages. Covers information density, navigation, data display, and the patterns that make complex products feel coherent.
---

# Interface Design

For things people work in, not land on. Power user uses dashboard 200x/month — they don't want hero animation.

## When to use

- Dashboard, admin panel, internal tool, SaaS app
- Data tables, metric cards, filter bars, settings
- Navigation structure (sidebar vs top vs combo)
- Density decisions (compact vs comfortable)
- NOT for: landing pages, marketing, blog, product pages

## Core principles

1. **Density rewards expertise** — power users want more on screen
2. **Predictability over delight** — same action, same place, same feedback
3. **Defaults matter most** — 80% never change settings
4. **Surface next action** — user came to do something, make it obvious
5. **Information hierarchy beats visual** — important data most prominent, not prettiest

## Layout primitives

| Element | Default behavior |
|---------|------------------|
| Sidebar nav | Persistent, collapsible, sectioned by domain |
| Top bar | Account, search, global actions, breadcrumb |
| Page header | Title, subtitle, primary action (right), tabs (under) |
| Content area | Cards OR tables OR split-pane — one per page |
| Footer | Rare in apps; reserve for dense settings |

Don't mix navigation paradigms on same page.

## Data display

| Use | When |
|-----|------|
| Metric card | 1-4 KPIs at dashboard top |
| Table | 5+ rows of comparable records — workhorse |
| List | Variable-shape, item clickable to detail |
| Chart | Trend over time, comparison across categories |
| Detail page | One record, all attrs, history, actions |

Tables: sticky header, sortable columns, row actions in last column or hover, density toggle if >50 rows.

## Navigation hierarchy

```
Primary nav     → top-level domains (Dashboard, Users, Reports, Settings)
Secondary nav   → sub-sections (tabs or sub-sidebar)
Tertiary        → in-page filters, segments, view modes
Action          → verb user came to do (create, export, archive)
```

4+ levels = structural problem, not UI problem.

## Density tiers

| Tier | Row height | Use case |
|------|-----------|----------|
| Compact | 28-32px | Spreadsheet-replacement, traders, ops |
| Default | 40-48px | Most SaaS dashboards |
| Comfortable | 56-64px | Consumer or low-frequency apps |

One per surface. Mixing = visual noise.

## Empty / loading / error / partial

Every data surface has 4 states. Design all 4:

- **Empty** — what's missing? next action? CTA, not just "No data"
- **Loading** — skeleton matching final layout, not centered spinner
- **Error** — what failed, what to try, where for help
- **Partial** — show what worked, mark what didn't

## Common mistakes

- Marketing-style hero on dashboard ("Welcome back!" eats fold)
- Whitespace-maxxing tool that needs density
- Primary action hidden behind kebab menu
- Card-ifying everything when table clearer
- Custom date picker/dropdown/modal instead of primitive
- Different button styles for same severity across pages
- "Empty state" = sad illustration, no path forward
- Modal-stacking (modal opens modal)
- Infinite scroll on data needing compare/jump
- Sidebar that hides at `<lg` with no replacement nav

## Quick reference

| Decision | Default |
|----------|---------|
| Primary action position | Top-right of page header |
| Destructive action | Confirm + red + away from primary |
| Save behavior | Autosave continuous, explicit Save atomic |
| Pagination | Pages for browse, cursor for feeds, "Load more" short |
| Filter UI | Persistent bar above table, chips for active |
| Search | Top of page or top bar, debounced, inline results |
| Settings page | Left nav sub-sections, right pane fields, sticky save |
| Notifications | Top-right toast ephemeral, banner persistent, inbox log |

## Pre-ship review

- [ ] Primary action = highest-contrast button
- [ ] All 4 states designed (empty/loading/error/partial)
- [ ] No mystery icons (icon + label unless universal)
- [ ] Keyboard shortcuts for 3 most-used actions
- [ ] Density consistent within surface
- [ ] Works at 1280px, 1440px, 1920px
- [ ] Settings discoverable (not 3 clicks deep)
- [ ] Destructive actions require explicit confirm

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Users will figure out the layout" | They don't — they leave. Live or die in first 30s. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
