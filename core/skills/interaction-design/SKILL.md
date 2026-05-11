---
name: interaction-design
description: Design and implement microinteractions, motion, transitions, and feedback. Covers when motion helps, when it hurts, and the timing rules behind both.
when_to_use: when adding polish to UI, building hover/focus/press states, animating state changes, or making the interface feel responsive
---

# Interaction Design

Motion is communication. Tells user what happened, what's coming, where to look.

## When to use

- Hover, focus, active, pressed states
- Route or panel transitions
- State change animations (open/close, expand/collapse, mount/unmount)
- Async action feedback (loading, success, error)
- Drawing attention to UI change
- UI that "feels off" but you can't say why

## Core principles

1. **Motion serves meaning** — every animation answers a question (what changed? where did it go? did it work?)
2. **Fast by default** — 100-200ms most UI. >300ms feels slow.
3. **Easing > duration** — `ease-out` entrances, `ease-in` exits, `ease-in-out` only for round trips
4. **Respect reduced motion** — `prefers-reduced-motion: reduce` → crossfade or instant
5. **Direction encodes hierarchy** — children from parent, not screen edge

## Timing scale

| Type | Duration | Easing |
|------|----------|--------|
| Hover / focus | 80-120ms | ease-out |
| Press / tap | 60-80ms | ease-out |
| Tooltip / popover open | 120-180ms | ease-out |
| Modal / drawer | 200-280ms | ease-out in, ease-in out |
| Page transition | 200-300ms | ease-in-out |
| Toast / snackbar | 180-240ms | ease-out |
| Skeleton shimmer | 1200-1600ms | ease-in-out infinite |
| List reorder | 200-300ms | ease-in-out (FLIP) |

Longer than this for routine UI = decoration.

## Feedback patterns

| Action | Feedback within |
|--------|-----------------|
| Button press | 100ms (visual state) |
| Form submit (optimistic) | 0ms (UI updates, server confirms later) |
| Form submit (server-required) | <100ms loading if response >300ms |
| Drag start | 0ms |
| Drag drop | 200ms snap |
| Network error | Immediate when known, with retry path |

Rules: did action register within 100ms? Not within 1000ms → show progress. >10s → "still working" reassurance.

## Microinteraction anatomy

4 parts:
1. **Trigger** — hover, click, scroll, state change
2. **Rules** — what's allowed during interaction
3. **Feedback** — what user sees/hears/feels
4. **Loop/end** — what after, reversible?

Skip any = jank. All four = designed.

## Common mistakes

- Animate because you can, not because needed
- 500ms+ on routine UI (feels broken)
- Linear easing for entrances (mechanical)
- Animating layout (top, left, width, height) — janky. Use transforms.
- No reduced-motion fallback — a11y regression
- Different timings for same action across app
- Spinner for fast ops (<400ms) — flashes worse than nothing
- Toast auto-dismiss for critical errors
- Hover-only affordances on touch

## Performance

- Animate `transform` and `opacity` — GPU-composited, cheap
- Avoid `width`, `height`, `top`, `left` — triggers layout
- `will-change` = last resort, not default
- 60fps target — 16ms budget per frame
- Long lists reorder → FLIP, not per-item transitions

## When motion helps

| Goal | Motion |
|------|--------|
| "Where did it go?" | Slide / morph old → new |
| "What happened?" | Color flash, scale pop, brief highlight |
| "Is it loading?" | Skeleton or shimmer (not always spinner) |
| "It worked" | Checkmark draw-in, brief scale, color shift |
| "It failed" | Subtle shake, red border, persistent error |
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

Or: slides → fades, bounces → linear, kill auto-playing motion.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Animations are polish, skip for v1" | Microinteractions ARE perceived performance. 200ms shimmer > 200ms latency reduction. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
