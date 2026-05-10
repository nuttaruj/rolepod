---
name: interface-design
description: Design dashboards, admin panels, and tool/app interfaces — interfaces users return to and operate. NOT for marketing pages. Covers information density, navigation, data display, and the patterns that make complex products feel coherent.
---

# Interface Design

Marketing pages persuade once. Interfaces are inhabited. A dashboard is used 200 times a month by a power user who does not want a hero animation. This skill is for designing things people work in, not things people land on.

## When to use

- Designing or auditing a dashboard, admin panel, internal tool, or SaaS app
- Laying out data tables, metric cards, filter bars, settings pages
- Choosing navigation structure (sidebar vs top nav vs combo)
- Density decisions (compact vs comfortable)
- NOT for: landing pages, marketing sites, blog posts, product pages

## Core principles

1. **Density rewards expertise** — power users want more on screen, not less. Don't whitespace yourself into uselessness.
2. **Predictability over delight** — same action, same place, same feedback, every time.
3. **Defaults matter most** — 80% of users will never change settings. Pick defaults that serve them.
4. **Surface the next action** — the user came here to do something. Make that obvious.
5. **Information hierarchy beats visual hierarchy** — the most important data should be most prominent, not the prettiest block.

## Layout primitives

| Element | Default behavior |
|---------|------------------|
| Sidebar nav | Persistent, collapsible, sectioned by domain |
| Top bar | Account, search, global actions, breadcrumb |
| Page header | Title, subtitle, primary action (right-aligned), tabs (under) |
| Content area | Cards, tables, or split-pane — pick one per page |
| Footer | Rare in apps; reserve for dense settings pages |

Don't mix navigation paradigms on the same page. Sidebar + tabs + top nav = the user can't predict where to click next.

## Data display rules

| Use | When |
|-----|------|
| Metric card | 1-4 KPIs at the top of a dashboard |
| Table | 5+ rows of comparable records — the workhorse |
| List | Variable-shape items, item is clickable to detail |
| Chart | Trend over time, comparison across categories |
| Detail page | One record, all attributes, history, actions |

Tables: sticky header, sortable columns, per-row actions in last column or hover-revealed, density toggle if rows >50.

## Navigation hierarchy

```
Primary nav     → top-level domains (Dashboard, Users, Reports, Settings)
Secondary nav   → sub-sections within a domain (tabs or sub-sidebar)
Tertiary        → in-page filters, segments, view modes
Action          → the verb the user came to do (create, export, archive)
```

If you need 4+ levels you have a structural problem, not a UI problem.

## Density tiers

| Tier | Row height | Use case |
|------|-----------|----------|
| Compact | 28-32px | Spreadsheet-replacement tools, traders, ops |
| Default | 40-48px | Most SaaS dashboards |
| Comfortable | 56-64px | Consumer-facing or low-frequency apps |

Pick one per surface. Mixing densities in one table = visual noise.

## Empty / loading / error / partial

Every data surface has 4 states. Design all 4:

- **Empty** — what's missing? what's the next action to fix it? show a CTA, not just "No data"
- **Loading** — skeleton matching the final layout, not a centered spinner
- **Error** — what failed, what to try, where to get help
- **Partial** — some loaded, some failed — show what worked, mark what didn't

## Common mistakes

- Marketing-style hero on a dashboard ("Welcome back!" eats the fold)
- Whitespace-maxxing a tool that needs density
- Hiding primary action behind a kebab menu
- Card-ifying everything when a table would be clearer
- Inventing a custom date picker / dropdown / modal instead of using a primitive
- Different button styles for the same severity across pages
- "Empty state" that's just a sad illustration with no path forward
- Modal-stacking (modal opens modal opens modal)
- Infinite scroll on data the user needs to compare or jump within
- Sidebar that hides in `<lg` breakpoint with no replacement nav

## Quick reference — interface decisions

| Decision | Default |
|----------|---------|
| Primary action position | Top-right of page header |
| Destructive action | Confirm step + red color + away from primary |
| Save behavior | Autosave for forms with continuous edits, explicit Save for atomic changes |
| Pagination | Page numbers for browsing, cursor for feeds, "Load more" for short lists |
| Filter UI | Persistent bar above table; chips for active filters |
| Search | Top of page or top bar; debounced; results inline if possible |
| Settings page | Left nav of sub-sections, right pane of fields, sticky save |
| Notifications | Top-right toast for ephemeral, banner for persistent, inbox for log |

## Pre-ship review

- [ ] Primary action is the highest-contrast button on the page
- [ ] Every state designed (empty / loading / error / partial)
- [ ] No mystery icons (icon + label, not icon-only, unless universal)
- [ ] Keyboard shortcuts for the 3 most-used actions
- [ ] Density consistent within the surface
- [ ] Page works at 1280px, 1440px, 1920px
- [ ] Settings discoverable (not hidden behind 3 clicks)
- [ ] Destructive actions require explicit confirmation
