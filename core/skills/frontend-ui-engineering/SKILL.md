---
name: frontend-ui-engineering
description: Build production-quality UI. Use when creating components, implementing layouts, wiring state, or shipping user-facing screens. Covers component boundaries, state colocation, data fetching, and the discipline that keeps frontends maintainable as they grow.
---

# Frontend UI Engineering

Production UI is not a Figma export. It survives loading, errors, empty states, slow networks, screen sizes, keyboards, and the engineer who reads it next year. This skill is the operating discipline for getting there without piling up tech debt.

## When to use

- Building or modifying any user-facing screen
- Adding a new component to the system
- Wiring data into UI (fetch, mutate, cache)
- Refactoring components that have grown unwieldy
- Reviewing a teammate's UI PR

## Build order

1. **Static markup first** — render the happy state with hardcoded data. No interactivity. Confirm structure + a11y semantics.
2. **States second** — loading, empty, error, partial. Each is a real user-visible screen, not an afterthought.
3. **Interaction third** — handlers, validation, optimistic updates.
4. **Data last** — replace hardcoded with real fetch. The component already knows its shape.

Skipping steps 2-3 is how UIs ship "works on my machine" only.

## Component boundaries

| Question | Action |
|----------|--------|
| Component >200 lines? | Consider split — by responsibility, not by size |
| Same JSX repeated 3+ places? | Extract |
| Prop drilling 3+ levels? | Lift state OR colocate the consumer |
| Component takes 8+ props? | Probably 2 components in a trenchcoat |
| One file owns fetch + UI + business logic? | Separate concerns |

Don't pre-extract. Wait until the second use to abstract. First abstraction = guess; second = data.

## State placement

- **Colocate** state next to the component that uses it
- **Lift** only when 2+ siblings need it
- **Global** only for cross-route concerns (auth, theme, cart)
- **Server state ≠ client state** — use a server-state library (TanStack Query, SWR, RTK Query) instead of dumping API data into Redux

## Data fetching discipline

- Every fetch has a loading state, error state, and empty state. No exceptions.
- Show stale-while-revalidate when possible — beats spinners.
- Don't fetch in 5 components when 1 parent can fetch + pass down.
- Cancel on unmount or use a fetcher that does it for you.
- Optimistic updates need rollback paths — write them.

## Accessibility floor

Before merging, every UI must:

- Be keyboard reachable (Tab + Enter + Escape work)
- Have visible focus rings (don't `outline: none` without a replacement)
- Use semantic HTML (`button` for buttons, `a` for links — not `div onClick`)
- Label form controls (`label htmlFor` or `aria-label`)
- Pass color contrast at AA (4.5:1 body, 3:1 large)
- Announce dynamic changes via live regions where relevant

## Common mistakes

- Implementing happy state, ignoring loading/error/empty
- Using `useEffect` to fetch when a server-state lib exists
- Putting all state in a global store "just in case"
- Building a custom select/modal/tooltip instead of using an a11y-tested primitive
- Hardcoding spacing/colors instead of design tokens
- `div onClick` for things that should be buttons or links
- One mega-component because "it's easier to read in one file" — until it isn't
- Skipping memoization, then over-memoizing in panic

## Quick reference

| Concern | Default tool |
|---------|--------------|
| Forms | Schema validation (Zod, Yup) + form lib (React Hook Form) |
| Server state | TanStack Query / SWR |
| Client state (small) | useState / useReducer |
| Client state (cross-route) | Context for low-frequency, Zustand/Jotai for high-frequency |
| Routing | Framework router (don't roll your own) |
| Styling | Design tokens via CSS vars or Tailwind config |
| Modals/menus/tooltips | Headless UI primitive (Radix, React Aria) — never DIY |
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

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "Tailwind classes work, that's enough" | Tailwind ≠ accessible. Tailwind ≠ keyboard-navigable. Tailwind ≠ semantic HTML. Classes only style; structure has to be right under them. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
