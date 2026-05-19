---
name: triage-deep
description: Compatibility shim — deep triage for multi-file, scope-drift, and phase-abort situations now lives in `manage-context`.
when_to_use: '"multi-file task", "scope unclear", "drift suspected", "mid-implement creep", "phase abort", "lead drift", "rollback reflex"'
tier: 3
redirect_to: manage-context
---

# triage-deep

Compatibility shim. Deep triage now lives in **`manage-context`**.

→ Open `core/skills/manage-context/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `manage-context` is not available

Minimum viable fallback:

1. List every file you have edited or planned to edit
2. Group files by concern
3. Compare the actual surface against the plan
4. Surface wider than plan → write a new plan, do not keep widening edits
5. Multi-agent coordination drifting → re-check the cohesion contract
6. Phase abort: state which phase, why, what blocks restart
7. Rollback reflex: when in doubt, revert last commit and re-plan from green
