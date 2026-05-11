---
name: frontend-ui-engineering
description: Build production-quality UI. Use when creating components, implementing layouts, wiring state, or shipping user-facing screens. Covers component boundaries, state colocation, data fetching, and the discipline that keeps frontends maintainable as they grow.
---

# Frontend UI Engineering

Production UI survives loading, errors, empty states, slow networks, screen sizes, keyboards, and next year's engineer.

## When to use

- Building/modifying user-facing screen
- Adding new component
- Wiring data (fetch, mutate, cache)
- Refactoring unwieldy components
- Reviewing teammate's UI PR

## Build order

1. **Static markup first** — happy state, hardcoded data, no interactivity. Confirm structure + a11y semantics.
2. **States second** — loading, empty, error, partial. Each is real screen, not afterthought.
3. **Interaction third** — handlers, validation, optimistic updates
4. **Data last** — replace hardcoded with real fetch

Skipping 2-3 = "works on my machine" ships.

## Component boundaries

| Question | Action |
|----------|--------|
| Component >200 lines | Consider split by responsibility |
| Same JSX in 3+ places | Extract |
| Prop drilling 3+ levels | Lift state OR colocate consumer |
| 8+ props | Probably 2 components in a trenchcoat |
| One file owns fetch + UI + business logic | Separate concerns |

Don't pre-extract. Wait for second use. First abstraction = guess; second = data.

## State placement

- **Colocate** state next to consumer
- **Lift** only when 2+ siblings need it
- **Global** only for cross-route (auth, theme, cart)
- **Server state ≠ client state** — use server-state lib (TanStack Query, SWR, RTK Query), not Redux dump

## Data fetching

- Every fetch has loading, error, empty states. No exceptions.
- Stale-while-revalidate > spinners
- Don't fetch in 5 components when 1 parent + pass down works
- Cancel on unmount or use fetcher that does
- Optimistic updates need rollback paths — write them

## Accessibility floor

- Keyboard reachable (Tab + Enter + Escape work)
- Visible focus rings (don't `outline: none` without replacement)
- Semantic HTML (`button` for buttons, `a` for links, not `div onClick`)
- Form labels (`label htmlFor` or `aria-label`)
- Color contrast AA (4.5:1 body, 3:1 large)
- Live regions for dynamic changes

## Common mistakes

- Happy state only, ignoring loading/error/empty
- `useEffect` to fetch when server-state lib exists
- All state in global store "just in case"
- Custom select/modal/tooltip instead of a11y-tested primitive
- Hardcoding spacing/colors instead of tokens
- `div onClick` for things that should be buttons/links
- Mega-component "easier in one file" — until it isn't
- Skipping memoization, then over-memoizing in panic

## Quick reference

| Concern | Default tool |
|---------|--------------|
| Forms | Schema validation (Zod, Yup) + React Hook Form |
| Server state | TanStack Query / SWR |
| Client state (small) | useState / useReducer |
| Client state (cross-route) | Context low-freq, Zustand/Jotai high-freq |
| Routing | Framework router |
| Styling | Design tokens via CSS vars or Tailwind config |
| Modals/menus/tooltips | Radix / React Aria — never DIY |
| Tables | TanStack Table or framework-native |

## Pre-merge checklist

- [ ] All four states render (happy / loading / error / empty)
- [ ] Keyboard navigable end-to-end
- [ ] No console warnings
- [ ] No layout shift on load
- [ ] Tested at narrow viewport
- [ ] Tokens used (no magic colors / spacing)
- [ ] No new global state without justification

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tailwind works, that's enough" | Tailwind ≠ accessible, ≠ keyboard-navigable, ≠ semantic. Classes only style. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
