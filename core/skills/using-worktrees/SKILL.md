---
name: using-worktrees
description: Use a git worktree (not a fresh clone, not a branch swap in place) when you need real filesystem isolation for parallel feature work, hotfix-on-top-of-feature, or experimental refactors that should not touch the main checkout.
when_to_use: when Lead is about to spawn parallel agents on overlapping paths, when a hotfix interrupts an in-progress feature, when running long-lived builds/tests that must not be disrupted, or when comparing two branches side-by-side in editors and shells
---

# Using Worktrees

Branch switch in single checkout = cheap but fragile: stomps uncommitted edits, invalidates watchers, forces stash. Worktree = second checkout, different ref, separate working tree, shared object DB → parallel work can't collide on filesystem.

Physical-isolation companion to `parallel-contract-orchestration`. Contract = shared interface. Worktrees = disjoint directories.

## When to use

- **Sibling Claude session detected** — SessionStart hook `session-lock.sh` emits `⚠️ Sibling Claude session(s) detected`. Spawn worktree FIRST before any Edit/Write to prevent stomp (see Auto-spawn pattern below).
- **Parallel feature dev** — two features, different owners, don't disturb each other's watchers/dev server
- **Hotfix while feature ongoing** — prod fix urgent, main checkout mid-feature with uncommitted state
- **Isolated test branches** — compare perf/behavior between two refs in parallel
- **Long-running builds** — keep editing while build runs against frozen ref
- **Multiple parallel implementer agents** — each gets own worktree. Pairs with `parallel-contract-orchestration`.

## Auto-spawn pattern — Lead-driven, no user command

Trigger: SessionStart additionalContext contains `Sibling Claude session(s) detected`.

Lead's first turn (BEFORE any Edit/Write):

```bash
BRANCH=$(git branch --show-current)
WORKTREE_PATH="$(git rev-parse --show-toplevel)-task-$(date +%s)"
git worktree add "$WORKTREE_PATH" "$BRANCH"
cd "$WORKTREE_PATH"
```

Then reply to user:

```
Detected sibling session in this worktree → spawned isolated tree at:
  <path>
Continuing work there. To follow along in your shell: cd <path>
```

User does ONE thing — `cd <path>` in their terminal. Lead handles spawn + work.

**Override:** `ROLEPOD_ALLOW_SHARED_WORKTREE=1` suppresses the warning for intentional shared sessions (read-only review, paired exploration). Don't override silently — explain to user why this session shares.

## When NOT to use

- Single-file edit on branch you have checked out → just edit
- Read-only inspection → `git show` / `git diff` is cheaper
- Inside a submodule (guard below)
- Tiny repo + fast build → branch swap fine

## Detection — am I in a worktree?

```bash
[ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ]
```

True → already in secondary worktree. Nesting allowed but rarely wanted — surface before adding.

## Guard — submodules

Refuse worktree inside submodule. Mixes ref semantics, breaks parent-repo updates.

```bash
if [ -f "$(git rev-parse --show-toplevel)/.git" ]; then
  echo "Refusing: inside submodule. Run from parent repo instead." >&2
  exit 1
fi
```

## Native first

If harness exposes `EnterWorktree`, use it. Native wires editor + search index + terminal cwd + harness state in one step. Hand-rolled leaves these out of sync.

`EnterWorktree({ ref: "<branch-or-sha>" })` → harness creates worktree, switches session, returns path. `ExitWorktree` returns to primary.

## Fallback — `git worktree add`

Directory priority:
1. `.worktrees/<name>` inside repo (gitignored, simplest)
2. `worktrees/<name>` inside repo (if `.worktrees/` taken)
3. `~/.config/rolepod/worktrees/<project>/<name>` (out-of-repo)

```bash
mkdir -p .worktrees
git worktree add .worktrees/hotfix-auth main
cd .worktrees/hotfix-auth
```

Add `.worktrees/` to `.gitignore` once. Never commit worktree path.

## Cleanup

```bash
git worktree remove .worktrees/hotfix-auth
git branch -d hotfix-auth
git worktree prune
```

Skipping `prune` → dangling refs in `.git/worktrees/` confuse future `worktree add`.

## Pairs with

- `parallel-contract-orchestration` — contract + worktrees together for ≥2 parallel implementers on overlapping paths
- `finishing-a-development-branch` — handles merge/PR per branch after convergence

## Influence

Detection + submodule guard are load-bearing — silent `git worktree add` inside a submodule corrupts state. Directory priority + native-first are rolepod additions on top.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll `git stash`" | Stash accumulates; year-old stash list = sign someone skipped worktree too often. |
| "Both branches build fast, swapping fine" | Until watcher restarts mid-thought, lose 3 min. Worktree cost = one command. |
| "Don't want another dir" | `.worktrees/` is gitignored. Remote cost zero, local 100KB. |
| "I'll clean up" | You won't. Add `git worktree prune` to end-of-feature checklist. |

Default: spend 5s to create worktree.
