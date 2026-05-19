---
name: user-facing-content
description: Compatibility shim — user-facing copy (FAQ, errors, onboarding, empty states) now flows through `implement-plan` with the `customer-success` agent adding depth when available.
when_to_use: FAQs, error messages, onboarding flows, empty states, help articles, and any text the end user reads inside the product or in support contexts
tier: 3
redirect_to: implement-plan
---

# user-facing-content

Compatibility shim. User-facing content now lives in **`implement-plan`**; the `customer-success` agent adds depth when installed.

→ Open `core/skills/implement-plan/SKILL.md` and follow that instead. Brief `customer-success` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `implement-plan` is not available

Minimum viable fallback:

1. Plain language — no jargon, no internal team terms
2. Error message = what happened + what to do next, not "Error 500"
3. Empty state = orientation + next action, not a blank page
4. Onboarding = one task per step; defer everything else
5. Match brand voice from existing surfaces
6. Test reading level — should match the audience, not the author
7. Localize-friendly: avoid idioms and culturally specific references
