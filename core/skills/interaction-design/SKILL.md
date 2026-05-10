---
name: interaction-design
description: Design and implement microinteractions, motion, transitions, and feedback. Use when adding polish to UI, building hover/focus/press states, animating state changes, or making the interface feel responsive. Covers when motion helps, when it hurts, and the timing rules behind both.
---

# Interaction Design

Motion is communication. Used well, it tells the user what happened, what's coming, and where to look. Used badly, it slows them down and looks like decoration. This skill is the rules for using it well.

## When to use

- Adding hover, focus, active, or pressed states
- Transitioning between routes or panels
- Animating state changes (open/close, expand/collapse, mount/unmount)
- Designing feedback for async actions (loading, success, error)
- Drawing attention to a change in the UI
- Reviewing a UI that "feels off" but you can't say why

## Core principles

1. **Motion serves meaning** — every animation answers a user question (what changed? where did it go? did it work?). No animation without a reason.
2. **Fast by default** — 100-200ms for most UI motion. >300ms feels slow on a working interface.
3. **Easing matters more than duration** — `ease-out` for entrances, `ease-in` for exits, `ease-in-out` only for round trips.
4. **Respect reduced motion** — `prefers-reduced-motion: reduce` users get crossfades or instant changes, not slides.
5. **Direction encodes hierarchy** — children animate from their parent, not from the screen edge.

## Timing scale

| Type | Duration | Easing |
|------|----------|--------|
| Hover / focus | 80-120ms | ease-out |
| Press / tap | 60-80ms | ease-out |
| Tooltip / popover open | 120-180ms | ease-out |
| Modal / drawer | 200-280ms | ease-out (in), ease-in (out) |
| Page transition | 200-300ms | ease-in-out |
| Toast / snackbar | 180-240ms | ease-out |
| Skeleton shimmer | 1200-1600ms | ease-in-out, infinite |
| List reorder | 200-300ms | ease-in-out (FLIP) |

Anything longer than this for routine UI is decoration, not interaction.

## Feedback patterns

| Action | Feedback within |
|--------|-----------------|
| Button press | 100ms (visual state change) |
| Form submit (optimistic) | 0ms (UI updates, server confirms later) |
| Form submit (server-required) | <100ms loading indicator if response >300ms |
| Drag start | 0ms (cursor + element responds) |
| Drag drop | 200ms snap or settle |
| Network error | Immediate when known, with retry path |

User must always know: did my action register? If not within 100ms → show pending. If not within 1000ms → show progress. If >10s → show "still working" reassurance.

## Microinteraction anatomy

Every microinteraction has 4 parts:

1. **Trigger** — what starts it (hover, click, scroll, state change)
2. **Rules** — what's allowed during the interaction
3. **Feedback** — what the user sees/hears/feels
4. **Loop/end** — what happens after, and is it reversible

Skip any of these = jank. Get all four = it feels designed.

## Common mistakes

- Animating because you can, not because the user needs it
- 500ms+ transitions on routine UI (feels broken)
- Linear easing for entrances (looks mechanical)
- Animating layout properties (top, left, width, height) instead of transforms — janky
- No reduced-motion fallback — accessibility regression
- Different timings for the same action across the app (inconsistent)
- Spinner for fast operations (<400ms) — flashes and feels worse than nothing
- Toast notifications that auto-dismiss critical errors
- Hover-only affordances on touch devices

## Performance

- Animate `transform` and `opacity` — GPU-composited, cheap
- Avoid animating `width`, `height`, `top`, `left` — triggers layout
- `will-change` is a last resort, not a default
- 60fps target — 16ms budget per frame
- Long lists reordering → FLIP technique, not per-item transitions

## Quick reference — when motion helps

| Goal | Motion that delivers |
|------|---------------------|
| "Where did it go?" | Slide / morph from old position to new |
| "What happened?" | Color flash, scale pop, brief highlight |
| "Is it loading?" | Skeleton or shimmer (not always spinner) |
| "It worked" | Checkmark draw-in, brief scale, color shift |
| "It failed" | Shake (subtle), red border, persistent error message |
| "Click me" | Hover lift, focus ring, press depress |
| "I'm next" | Gentle pulse on primary action only |

## Reduced-motion fallback

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

Or: replace slides with fades, replace bounces with linear, kill auto-playing motion entirely.
