---
name: spec-driven-development
description: Compatibility shim — spec / discovery / scoping work is now handled by `write-spec`. Use `write-spec` directly for define-phase work.
when_to_use: at the start of a new feature, project, or significant change when requirements aren't yet pinned down
tier: 3
redirect_to: write-spec
---

# spec-driven-development

Compatibility shim. Spec writing now lives in **`write-spec`**.

→ Open `core/skills/write-spec/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release and will be removed after one release once behavior tests confirm the canonical route catches the trigger.

## If `write-spec` is not available

Minimum viable fallback:

1. Quote the user request literally
2. State the goal in one sentence
3. List non-goals and constraints
4. Name the high-risk surfaces touched
5. Ask one targeted question at a time (≤ 5 total)
6. Present 2-3 viable approaches with tradeoffs; recommend one
7. Wait for user approval before any implementation
8. Self-review the spec for placeholders, contradictions, ambiguity, scope creep
