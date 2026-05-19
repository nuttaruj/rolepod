---
name: pre-merge-gate
description: Compatibility shim — pre-merge gate (simplicity + tests + reviewer + CI lanes) now lives in `finish-work`.
when_to_use: 'before `git push` to tracked branch, `gh pr merge`, "ship it", "before push", "before merge", "ship gate", PR ready to merge'
tier: 3
redirect_to: finish-work
---

# pre-merge-gate

Compatibility shim. The pre-merge gate now lives in **`finish-work`**.

→ Open `core/skills/finish-work/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `finish-work` is not available

Minimum viable fallback:

1. Simplicity (S1-S5): cut features beyond request, single-use abstractions, config nobody asked for, defensive-for-impossible, same-pattern-in-3+
2. Test (T1-T6): required test exists, new tests pass, existing pass, tier-appropriate speed, isolated, tight assertions
3. Reviewer routed by risk profile (qa-tester floor; security-engineer on high-risk)
4. Failure-mode (F1-F5): no hallucinated action, no scope creep, no cascade error, no context loss, no destructive misuse
5. Phase 1 CI required green for merge
6. Phase 2 path-triggered CI required green when triggered
7. Phase 3 nightly = notify, not block
8. Never merge without explicit user authorization for THIS specific action
