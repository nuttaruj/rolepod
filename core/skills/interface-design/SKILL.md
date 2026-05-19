---
name: interface-design
description: Compatibility shim — dashboards, admin panels, and operational app interface design now flow through `implement-plan` with the `ui-ux-designer` agent adding depth when available.
when_to_use: when designing a dashboard, admin panel, settings UI, internal tool, or any operational app interface
tier: 3
redirect_to: implement-plan
---

# interface-design

Compatibility shim. Operational UI design now lives in **`implement-plan`**; the `ui-ux-designer` agent adds depth when installed.

→ Open `core/skills/implement-plan/SKILL.md` and follow that instead. Brief `ui-ux-designer` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `implement-plan` is not available

Minimum viable fallback:

1. Define the information hierarchy first — what does the user scan for, in what order
2. Optimize for return visits: keyboard nav, dense layout where appropriate
3. Empty / loading / error states designed before the happy path is "done"
4. Visual weight matches importance — primary action, then supporting, then meta
5. Match patterns from existing surfaces; new patterns need a real reason
6. Density vs whitespace tradeoff stated explicitly
7. Test the design with the real data shape, not a placeholder
