---
name: api-and-interface-design
description: Compatibility shim — API / interface / module boundary design now starts inside `write-plan` and escalates to `system-architect` when depth is needed.
when_to_use: when creating REST/GraphQL endpoints, RPC methods, public package exports, or internal module interfaces
tier: 3
redirect_to: write-plan
---

# api-and-interface-design

Compatibility shim. API and interface design now lives in **`write-plan`** for routing and decision shaping; depth lives in the `system-architect` agent.

→ Open `core/skills/write-plan/SKILL.md` and follow that instead. Brief `system-architect` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `write-plan` is not available

Minimum viable fallback:

1. Design the contract before any implementation
2. Match naming conventions of existing endpoints / modules
3. Pick a versioning + deprecation strategy
4. Use a consistent error shape across the API
5. Confirm backward compatibility or flag the break explicitly
6. Verify request / response shape with a real example
7. Cross-check BE model + FE type + tests agree (one source of truth)
