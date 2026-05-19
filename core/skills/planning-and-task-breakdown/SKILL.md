---
name: planning-and-task-breakdown
description: Compatibility shim — task breakdown, file list, ordering, and test-per-task planning now live in `write-plan`.
when_to_use: when work feels too big for a single session, when dependencies are unclear, or when the next step isn't obvious
tier: 3
redirect_to: write-plan
---

# planning-and-task-breakdown

Compatibility shim. Planning now lives in **`write-plan`**.

→ Open `core/skills/write-plan/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `write-plan` is not available

Minimum viable fallback:

1. List the files likely to touch (concrete paths, not categories)
2. Order tasks smallest-reversible first
3. Name a test or evidence per task — "adds tests" is not a test plan
4. Flag every high-risk surface explicitly
5. State the done criteria
6. List risks and what could break
7. Save the plan inline or to `docs/plans/<feature>.md` if multi-session
