---
name: finishing-a-development-branch
description: At the end of a development task, present a 4-option decision menu (merge, PR, keep open, discard) instead of silently guessing what to do next. Use whenever a feature / fix / refactor branch reaches a natural stopping point — work is committed, tests pass locally, and the next action depends on context Lead can detect (fork vs upstream, open PR vs not, ahead of main vs not) rather than guess. Pairs with pre-merge-gate.
---

# Finishing A Development Branch

The moment after the last green test on a feature branch is the moment most ad-hoc decisions get made: "I'll just merge," "I'll just push," "I'll come back to this tomorrow," "let's open a PR." All four are valid. Picking the wrong one silently ships work to prod, abandons it, or leaves it dangling for days.

This skill replaces the silent guess with an explicit 4-option menu, pre-filled with detected context, so the user picks rather than infers.

## When to use

Trigger this skill when:

- A development task hits a natural stopping point (feature done, fix verified, refactor compiled-and-tested)
- The branch has commits not yet on `main` (or the configured base branch)
- You're about to type `git push` or `gh pr create` or `git merge` without asking which one

Skip this skill when:

- The user already said exactly what they want ("merge it", "open a PR", "save for tomorrow")
- The change is doc-only and goes straight to `main` per project policy
- You're mid-task — this is end-of-task only

## The decision menu

Present these four options every time, with detected context filling in defaults:

```
This branch is ready. What next?

  [1] Merge to <base> (auto-merge if CI green)
  [2] Open PR against <base>
  [3] Keep branch open (push + come back later)
  [4] Discard (delete branch, throw away)

Detected:
- Repo: <fork|origin> of <upstream-or-self>
- Open PR for this branch: <yes #<num> | no>
- Commits ahead of <base>: <N>
- Pre-merge gate: <pass | not-yet-run>
```

Never auto-pick unless the user passes `--auto-pick` explicitly. The whole point of the menu is to surface the choice.

## Detection logic

Run these checks before presenting the menu (read-only; safe to run anywhere):

### Is this a fork?
```bash
gh repo view --json isFork --jq .isFork
# true → fork
# false → origin / upstream
```

Forks default to "open PR" (Option 2). Origins where the user has write access default to "merge" (Option 1) when CI is green.

### Is there an open PR for this branch?
```bash
gh pr list --head "$(git branch --show-current)" --state open --json number --jq '.[].number'
# empty → no PR
# number → PR exists, route findings there instead of opening a new one
```

PR exists → Option 2 becomes "comment on existing PR #N" not "create new PR."

### Is the branch ahead of the base?
```bash
git log "$(git merge-base HEAD <base>)..HEAD" --oneline | wc -l
# 0 → nothing to ship, skip the menu, just clean up
# N>0 → N commits to ship
```

Zero commits ahead → the menu is a no-op. Skip directly to "branch already in sync — delete? [y/N]."

### Pre-merge gate state
Check whether `pre-merge-gate.md` has been run for this batch (simplicity gate, test gate, reviewer rounds). If not — surface that, do NOT auto-pick Option 1 (Merge) even if everything else looks green.

## Option mechanics

### Option 1 — Merge

Pre-condition: not a fork, write access, CI green, pre-merge gate ran.

Action:
```bash
# Squash or merge per project convention — detect from .github/ settings
gh pr merge <PR-num> --auto --squash    # or --merge / --rebase
```

If no PR exists yet but Option 1 was chosen anyway → create + auto-merge in one step:
```bash
gh pr create --fill --base <base> && gh pr merge --auto --squash
```

### Option 2 — Open PR

Pre-condition: branch pushed (auto-push if needed).

Action:
```bash
git push -u origin HEAD
gh pr create --base <base> --title "<title>" --body "$(cat <<'EOF'
## Summary
<bullet points>

## Test plan
<checklist>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Existing PR detected → push and add a comment summarizing the new commits, don't recreate.

### Option 3 — Keep open

Action: push the branch so work survives a laptop crash; don't open PR; leave a TODO note in the user's task list (if integrated) or print a reminder.

```bash
git push -u origin HEAD
echo "Branch '$(git branch --show-current)' pushed. Resume with 'git checkout <branch>'."
```

### Option 4 — Discard

Confirmation required — this is destructive.

```
You picked Discard. This will:
  - delete the local branch
  - delete the remote branch (if pushed)
  - close any open PR
  - throw away N commits

Confirm with 'discard <branch-name>': _
```

Echoing the branch name is the safety interlock; bare `y` is not enough.

## Pre-merge gate dependency

This skill is downstream of `pre-merge-gate.md`. Option 1 (Merge) requires:

- Simplicity gate (S1-S5) passed
- Test gate (T1-T5) passed
- Reviewer cascade complete per `reviewer-flow.md`

If any of those are not done, surface them in the menu's "Detected" block and refuse Option 1 until they're complete (or the user explicitly overrides per pre-merge-gate.md's override clause).

## Pairs with

- `pre-merge-gate.md` (rule) — runs before this menu can offer Merge
- `reviewer-flow.md` (rule) — the reviewer cascade must complete first
- `using-worktrees` — if the user picks Option 3 (Keep open) and starts a new task, a worktree is the right way to switch without disturbing this branch

## Influence

Adapted from [obra/superpowers](https://github.com/obra/superpowers) `finishing-a-development-branch`. The 4-option menu shape and the never-auto-pick default are load-bearing. Detection blocks (`gh repo view`, `gh pr list`, `git log ahead-count`) and the pre-merge-gate dependency wiring are rolepod additions.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I always pick Merge, skip the menu" | Until the day you wanted PR review and merged direct to main. The 2-second menu is cheaper than the rollback. |
| "Just `git push` and figure it out later" | "Later" is when the work is forgotten on a branch nobody finds for a month. Pick an option now. |
| "Discard with `y` is fine, the branch is tiny" | Discarding without echoing the branch name has thrown away the wrong branch before. The interlock exists for a reason. |
| "CI will catch it if I merge wrong" | CI catches syntax and tests. CI does not catch "wrong base branch" or "this was supposed to go through PR review." |
| "The detected defaults are usually right, auto-pick" | "Usually" right is wrong sometimes; this is the moment where wrong is most expensive. Present the menu. |

Default when rationalizing: present the menu anyway. Cost of the menu is bounded (one prompt). Cost of the wrong silent choice is unbounded.
