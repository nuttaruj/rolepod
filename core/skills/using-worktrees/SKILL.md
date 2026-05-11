---
name: using-worktrees
description: Use a git worktree (not a fresh clone, not a branch swap in place) when you need real filesystem isolation for parallel feature work, hotfix-on-top-of-feature, or experimental refactors that should not touch the main checkout. Triggers when Lead is about to spawn parallel agents on overlapping paths, when a hotfix interrupts an in-progress feature, when running long-lived builds/tests that must not be disrupted, or when comparing two branches side-by-side in editors and shells.
---

# Using Worktrees

Branch switching in a single checkout is cheap but fragile: it stomps on uncommitted edits, invalidates running watchers, and forces you to stash to context-switch. A git worktree gives you a second checkout of the same repo at a different ref — separate working tree, shared object database — so parallel work doesn't collide on the filesystem.

This is the physical-isolation companion to `parallel-contract-orchestration`. The contract pattern gives agents a shared interface contract. Worktrees give them disjoint directories so they cannot trample each other's files.

## When to use

Use a worktree when any of these are true:

- **Parallel feature dev** — two features in flight, each owned by a different agent or human, and you don't want one's edits to disturb the other's running dev server / file watcher.
- **Hotfix while feature ongoing** — production needs an urgent fix and the main checkout is mid-feature with uncommitted state. Worktree on `main`, fix, ship, return.
- **Isolated test branches** — comparing perf or behavior between two refs; running both in parallel is faster than ping-pong checkouts.
- **Long-running builds** — your build takes minutes and you want to keep editing while it runs against a frozen ref.
- **Spawning multiple parallel implementer agents** — each agent gets its own worktree so their edits don't race. Pairs with `parallel-contract-orchestration`.

## When NOT to use

- Single-file edit on a branch you already have checked out → just edit
- Read-only inspection of another ref → `git show` / `git diff` is cheaper
- You're inside a submodule (see guard below) → fix in the parent repo instead
- The repo is tiny + your build is fast → branch swap is fine

## Detection — am I already inside a worktree?

```bash
[ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ]
```

True → you're already in a secondary worktree. Nesting worktrees is allowed but rarely what you want — surface this to the user before adding another.

## Guard — submodules

Refuse to create a worktree inside a submodule. Submodules already point at a different commit in a different repo; adding a worktree there mixes ref semantics in ways that confuse `git status` and break parent-repo updates.

```bash
if [ -f "$(git rev-parse --show-toplevel)/.git" ]; then
  echo "Refusing: inside submodule. Run from parent repo instead." >&2
  exit 1
fi
```

## Native first — prefer the harness tool

If the harness (Claude Code, Cursor, etc.) exposes an `EnterWorktree` tool, use it. The native tool wires up the editor, search index, terminal cwd, and any harness-side state in one step. Hand-rolled `git worktree add` leaves these out of sync.

Lead invokes `EnterWorktree({ ref: "<branch-or-sha>" })` → harness creates the worktree, switches the active session into it, and returns the path. `ExitWorktree` returns you to the primary checkout.

## Fallback — `git worktree add`

When the harness has no native tool, create one yourself. Directory priority:

1. `.worktrees/<name>` inside the repo (gitignored, simplest)
2. `worktrees/<name>` inside the repo (if `.worktrees/` is already in use for something else)
3. `~/.config/rolepod/worktrees/<project>/<name>` (when you don't want any in-repo path)

```bash
# Preferred — in-repo, gitignored
mkdir -p .worktrees
git worktree add .worktrees/hotfix-auth main

# Returns: a new checkout at .worktrees/hotfix-auth on branch main
cd .worktrees/hotfix-auth
# ... do work ...
```

Add `.worktrees/` to `.gitignore` once; never commit a worktree path.

## Cleanup

```bash
# When the branch is merged / abandoned:
git worktree remove .worktrees/hotfix-auth   # removes the directory
git branch -d hotfix-auth                    # deletes the branch
git worktree prune                           # cleans stale admin entries
```

Forgetting `prune` leaves dangling references in `.git/worktrees/` that confuse future `worktree add` runs.

## Pairs with

- `parallel-contract-orchestration` — contract gives shared interface, worktrees give disjoint filesystems. Use both when spawning ≥2 parallel implementer agents on overlapping paths.
- `finishing-a-development-branch` — after the parallel work converges, the finishing flow handles merge/PR per branch.

## Influence

Adapted from [obra/superpowers](https://github.com/obra/superpowers) `using-git-worktrees/SKILL.md`. Their detection logic + submodule guard are load-bearing; the directory-priority list and native-first preference are rolepod additions.

## Common Rationalizations

When you're tempted to skip the worktree and just swap branches, watch for these:

| Excuse | Reality |
|--------|---------|
| "I'll just `git stash` first" | Stash accumulates across context switches; a year-old stash list is the canonical sign someone skipped a worktree once too often. |
| "Both branches build fast, swapping is fine" | True until your file watcher restarts mid-thought and you lose 3 minutes hunting the next edit point. Worktree cost is one `git worktree add`. |
| "I don't want another directory in my tree" | `.worktrees/` is gitignored. The cost is zero on the remote and 100KB of admin files locally. |
| "I'll remember to clean it up" | You won't. Add a `git worktree prune` to your end-of-feature checklist instead of trusting memory. |

Default response when rationalizing: spend the 5 seconds to create the worktree. The cost of skipping is bounded by how badly the branch swap stomps your in-flight state, which is unknowable in advance.
