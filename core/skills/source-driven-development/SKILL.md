---
name: source-driven-development
description: Compatibility shim — official-doc grounding for SDK / API / schema / platform integration decisions now lives inside `write-plan` (and `implement-plan` for in-edit fetches).
when_to_use: writing framework code, integrating an SDK, an API call enters the diff, authoring a plugin/extension/marketplace manifest (plugin.json / marketplace.json / *-extension.json / hooks.json / .mcp.json), targeting any schema-bound config format, any new external-system integration where wrong fields fail silently
tier: 3
redirect_to: write-plan
---

# source-driven-development

Compatibility shim. Official-doc grounding now lives in **`write-plan`** for design decisions and **`implement-plan`** for in-edit fetches.

→ Open `core/skills/write-plan/SKILL.md` for design grounding, then `core/skills/implement-plan/SKILL.md` for in-edit verification.

This shim preserves the legacy trigger phrase during the migration release.

## If `write-plan` is not available

Minimum viable fallback:

1. WebFetch the official documentation BEFORE writing any external-integration code
2. Cite the source URL inline in the artifact
3. Verify schema fields against the spec, not against a blog or community example
4. Never assume a field shape from training data
5. New schema-bound config (plugin.json, manifest, hooks.json) → fetch the spec first
6. Wrong field = silent install / runtime failure later
7. State explicitly what you could not verify if the docs are missing or offline
