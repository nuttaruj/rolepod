---
name: doc-coauthoring
description: Compatibility shim — interview-style document and spec shaping now starts in `write-spec`. Final-form docs and ADRs are an artifact produced inside `implement-plan` once the spec is approved.
when_to_use: when the user wants to write a document together instead of "just write me one"
tier: 3
redirect_to: write-spec
---

# doc-coauthoring

Compatibility shim. The collaborative-shaping entry point now lives in **`write-spec`** (interview + approval gate). Producing the final document is handled by `implement-plan` (or the relevant writing agent) once the spec is approved.

→ Open `core/skills/write-spec/SKILL.md` for shaping, then `core/skills/implement-plan/SKILL.md` for the final draft.

This shim preserves the legacy trigger phrase during the migration release.

## If `write-spec` is not available

Minimum viable fallback:

1. Interview to discover the user's intent (one question at a time)
2. Sketch an outline before drafting
3. Iterate section by section
4. Get user approval at each section
5. Self-review for clarity, contradictions, placeholders
6. Produce the final document only after the outline is accepted
