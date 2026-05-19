---
name: team-routing
description: Compatibility shim — agent selection and parallel multi-agent routing are now part of `write-plan`. Cohesion contracts also live there.
when_to_use: '"choose agent", "multi-agent parallel", "team layout", "agent picker", "unclear ownership", "cohesion contract"'
tier: 3
redirect_to: write-plan
---

# team-routing

Compatibility shim. Agent picking and parallel routing now happen inside **`write-plan`**.

→ Open `core/skills/write-plan/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `write-plan` is not available

Minimum viable fallback:

1. Map the task by path + concern + risk
2. Pick the closest specialist agent for each task
3. Use parallel only when file ownership is genuinely disjoint
4. If parallel, write a cohesion contract pinning ownership + merge order
5. Brief each agent with task + files + tests + done criterion + handoff partner
6. Sequential is the default — parallel needs an explicit reason
