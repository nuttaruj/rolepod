---
name: claude-api
description: Compatibility shim — Claude / Anthropic SDK integration work now flows through `implement-plan` with the `ai-ml-engineer` agent adding depth when available.
when_to_use: when integrating the Anthropic Python or TypeScript SDK, when migrating between Claude model versions, when tuning cache hit rate, or when implementing tool use, streaming, or batching
tier: 3
redirect_to: implement-plan
---

# claude-api

Compatibility shim. Anthropic SDK integration now lives in **`implement-plan`**; the `ai-ml-engineer` agent adds depth when installed.

→ Open `core/skills/implement-plan/SKILL.md` and follow that instead. Brief `ai-ml-engineer` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `implement-plan` is not available

Minimum viable fallback:

1. WebFetch the current Anthropic API docs before writing — do not recall from training
2. Use the latest stable SDK version; pin it in the dependency manifest
3. Default to prompt-caching for repeat-context calls (system prompt, tool definitions)
4. Verify the model ID against the docs page; do not assume a name from memory
5. Tool-use schema must match the Anthropic Tool spec exactly
6. Stream long outputs; do not block on full-response retrieval
7. Cite the docs URL in the code comment or PR body for any non-obvious API choice
