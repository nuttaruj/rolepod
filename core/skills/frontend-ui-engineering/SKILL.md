---
name: frontend-ui-engineering
description: Compatibility shim — frontend implementation work now flows through `implement-plan` with the `frontend-developer` agent adding depth when available.
when_to_use: when creating components, implementing layouts, wiring state, or shipping user-facing screens
tier: 3
redirect_to: implement-plan
---

# frontend-ui-engineering

Compatibility shim. Frontend implementation now lives in **`implement-plan`**; the `frontend-developer` agent adds depth when installed.

→ Open `core/skills/implement-plan/SKILL.md` and follow that instead. Brief `frontend-developer` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `implement-plan` is not available

Minimum viable fallback:

1. Read 2-3 nearby components first to match style
2. Co-locate state with the component that owns it; lift only when shared
3. Pick the data-fetching pattern the codebase already uses (loader / hook / server-component)
4. Match the existing routing convention
5. A11y baseline: keyboard focus, ARIA where semantic HTML is not enough, color contrast
6. Match the existing component library — do not introduce a new one without justification
7. Loading / empty / error states are part of the deliverable, not a follow-up
