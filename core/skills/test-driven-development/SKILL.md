---
name: test-driven-development
description: Compatibility shim — TDD discipline (Red → Green → Refactor, failing-test-first for risky paths) is now part of `implement-plan` and the failing-test step inside `debug-issue`.
when_to_use: when fixing bugs (Prove-It pattern), when adding new logic, when changing behavior, or when you need proof that code works AND that the test actually exercises the change
tier: 3
redirect_to: implement-plan
---

# test-driven-development

Compatibility shim. TDD discipline now lives in **`implement-plan`** for new work and **`debug-issue`** for bug fixes.

→ Open `core/skills/implement-plan/SKILL.md` for new work, or `core/skills/debug-issue/SKILL.md` for bug fixes.

This shim preserves the legacy trigger phrase during the migration release.

## If `implement-plan` is not available

Minimum viable fallback:

1. Write the failing test first for any risky path (bug / new logic / billing / migration / auth / race / security)
2. Run the test — it must fail
3. Write the smallest code change that turns it green
4. Run the full touched suite — must stay green
5. Refactor only when green
6. Tighten assertions until a 1-character regression breaks the test
7. Tests-after is allowed only for pure mechanical work (rename / typo / comment)
