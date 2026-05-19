---
name: parallel-contract-orchestration
description: Compatibility shim — cohesion contracts for parallel multi-agent work are now part of `write-plan`. The contract must be written BEFORE any parallel spawn.
when_to_use: when Lead is about to spawn multiple agents in parallel and they will produce code that has to compose together
tier: 3
redirect_to: write-plan
---

# parallel-contract-orchestration

Compatibility shim. Cohesion contracts now live inside **`write-plan`**.

→ Open `core/skills/write-plan/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `write-plan` is not available

Minimum viable fallback:

1. Write the contract BEFORE any parallel spawn
2. Pin which agent owns which files (disjoint sets)
3. Pin the shared interfaces between owned regions
4. Pin merge order — who merges first, who follows
5. State what each agent must NOT touch
6. Save to `contract.md` or `specs/<feature>-cohesion.md`
7. If file ownership cannot be disjoint, drop to sequential — do not spawn parallel
