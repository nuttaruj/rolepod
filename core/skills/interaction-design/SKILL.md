---
name: interaction-design
description: Compatibility shim — motion, microinteractions, and feedback design now flow through `implement-plan` with the `ui-ux-designer` agent adding depth when available.
when_to_use: when adding polish to UI, building hover/focus/press states, animating state changes, or making the interface feel responsive
tier: 3
redirect_to: implement-plan
---

# interaction-design

Compatibility shim. Microinteractions and motion now live in **`implement-plan`**; the `ui-ux-designer` agent adds depth when installed.

→ Open `core/skills/implement-plan/SKILL.md` and follow that instead. Brief `ui-ux-designer` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `implement-plan` is not available

Minimum viable fallback:

1. Motion serves comprehension first, delight second — never the other way around
2. Cover hover / focus / press / disabled states for every interactive element
3. Match platform conventions (iOS / Android / web) — do not invent unless the brand requires it
4. Avoid motion-driven layout shift — animate transform / opacity, not layout
5. Time the animation: ~150ms for affordance, ~250ms for transition, longer only when communicating state
6. Reduce-motion preference must be respected
7. Test with real device frame rates, not just the desktop dev tools
