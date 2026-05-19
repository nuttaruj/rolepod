---
name: context-engineering
description: Compatibility shim — context budget and load discipline now live in `manage-context`.
when_to_use: when starting a new session, when output quality degrades, when costs spike, or when designing multi-agent systems
tier: 3
redirect_to: manage-context
---

# context-engineering

Compatibility shim. Context budget discipline now lives in **`manage-context`**.

→ Open `core/skills/manage-context/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `manage-context` is not available

Minimum viable fallback:

1. Load only what the current task actually needs (touched files + relevant skills)
2. Lazy-load by trigger phrase — do not preload every skill
3. Compress / summarize when the context bar goes yellow
4. Multi-agent: isolate contexts; each subagent gets only its own scope
5. Long-running tasks → /compact <focus> mid-session
6. Switching tasks → /clear between unrelated work
7. Cost spike → check which skill / agent is preloading content it does not need
