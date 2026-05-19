---
name: subagent-task-execution
description: Compatibility shim — the two-stage delegated-task protocol (bounded scope + fresh reviewer) is now part of `implement-plan`.
when_to_use: when Lead is about to delegate a non-trivial implementation task and the cost of a silent regression or spec drift is higher than the cost of two extra review rounds
tier: 3
redirect_to: implement-plan
---

# subagent-task-execution

Compatibility shim. The delegated-task protocol now lives in **`implement-plan`**.

→ Open `core/skills/implement-plan/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `implement-plan` is not available

Minimum viable fallback:

1. Bound the task scope: 1-2 files or one module
2. Brief: spec / plan reference, exact files, test plan, done criterion
3. Tool cap: ≤ 12 tool uses per subagent
4. Subagent NEVER commits — returns a manifest, Lead commits
5. Fresh-context reviewer reads the diff with no prior chat state
6. Reject COMPLETED with failing tests or with scope creep
7. Mark task done only when implementer + reviewer both pass
