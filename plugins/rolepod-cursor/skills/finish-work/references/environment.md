<!-- Load before the finish menu to tell a normal repo from a worktree or a detached HEAD. -->

# Detect the environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P); GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

- `GIT_DIR == GIT_COMMON` → a normal repo: 3-option menu (merge / PR / keep open), discard on request only, no worktree cleanup.
- `GIT_DIR != GIT_COMMON`, named branch → 3-option menu, discard on request only, worktree cleanup below.
- `GIT_DIR != GIT_COMMON`, detached HEAD → **2-option menu (PR / keep open, no local merge)**, discard on request only, externally managed cleanup.

## Worktree cleanup order

After a merge, in this order: merge → verify → `cd` to the main root → `git worktree remove` → `git worktree prune` → delete the branch. The reversed order leaves stuck refs.
Remove only worktrees we created (under `.worktrees/` or `worktrees/`), never from inside one and never before the merge succeeded; never touch harness-owned workspaces.
