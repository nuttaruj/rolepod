---
name: using-worktrees
description: Compatibility shim — git worktree discipline (real filesystem isolation for parallel work) is now part of `implement-plan`.
when_to_use: when Lead is about to spawn parallel agents on overlapping paths, when a hotfix interrupts an in-progress feature, when running long-lived builds/tests that must not be disrupted, or when comparing two branches side-by-side in editors and shells
tier: 3
redirect_to: implement-plan
---

# using-worktrees

Compatibility shim. Worktree mechanics now live in **`implement-plan`** (the parallel-execution step).

→ Open `core/skills/implement-plan/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `implement-plan` is not available

Minimum viable fallback:

1. Use a worktree (not a fresh clone, not a branch swap in place) when two sessions truly need the same files at once
2. Sequential / branch swap in place is enough for solo work
3. Hotfix interrupting an in-progress feature → worktree, do not stash and lose context
4. Long-lived build / test that must not be disrupted → worktree
5. Comparing two branches in editor and shell side-by-side → worktree
6. Clean up the worktree when done (`git worktree remove`)
7. Do not run a worktree for "might be useful later" — only when isolation is real
