---
name: finishing-a-development-branch
description: At the end of a development task, present a 4-option decision menu (merge, PR, keep open, discard) instead of silently guessing what to do next. Use whenever a feature / fix / refactor branch reaches a natural stopping point — work is committed, tests pass locally, and the next action depends on context Lead can detect (fork vs upstream, open PR vs not, ahead of main vs not) rather than guess. Pairs with pre-merge-gate.
---

# Finishing A Development Branch

Replace silent guess with explicit 4-option menu, pre-filled with detected context.

## When to use

Trigger when:
- Task hits natural stopping point (feature done, fix verified, refactor tested)
- Branch has commits not on base
- About to `git push` / `gh pr create` / `git merge` without asking which

Skip when:
- User already said exactly what they want
- Doc-only goes straight to main per policy
- Mid-task (end-of-task only)

## The decision menu

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

Never auto-pick unless user passes `--auto-pick`.

## Detection

Run read-only checks before showing menu:

```bash
# Fork?
gh repo view --json isFork --jq .isFork

# Open PR?
gh pr list --head "$(git branch --show-current)" --state open --json number --jq '.[].number'

# Ahead of base?
git log "$(git merge-base HEAD <base>)..HEAD" --oneline | wc -l
```

| Signal | Default |
|--------|---------|
| Fork | Option 2 (PR) |
| Origin + write access + CI green | Option 1 (Merge) |
| PR exists | Option 2 becomes "comment on existing PR #N" |
| 0 ahead | Skip menu → "branch in sync — delete? [y/N]" |
| Pre-merge gate not run | Block Option 1 |

## Option mechanics

### Option 1 — Merge

Pre-condition: not fork, write access, CI green, pre-merge gate ran.

```bash
gh pr merge <PR-num> --auto --squash   # or --merge / --rebase per convention
# No PR yet:
gh pr create --fill --base <base> && gh pr merge --auto --squash
```

### Option 2 — Open PR

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

Existing PR → push + comment, don't recreate.

### Option 3 — Keep open

```bash
git push -u origin HEAD
echo "Branch '$(git branch --show-current)' pushed. Resume with 'git checkout <branch>'."
```

### Option 4 — Discard

Destructive. Echo branch name as interlock:

```
You picked Discard. This will:
  - delete the local branch
  - delete the remote branch (if pushed)
  - close any open PR
  - throw away N commits

Confirm with 'discard <branch-name>': _
```

Bare `y` is not enough.

## Pre-merge gate dependency

Downstream of `pre-merge-gate.md`. Option 1 requires:
- Simplicity gate (S1-S5) passed
- Test gate (T1-T6) passed
- Reviewer cascade complete

Missing → surface in "Detected" block, refuse Option 1 until done.

## Pairs with

- `pre-merge-gate.md` — runs before Merge offered
- `reviewer-flow.md` — reviewer cascade must complete first
- `using-worktrees` — for Option 3 + starting new task

## Influence

Adapted from [obra/superpowers](https://github.com/obra/superpowers). 4-option menu + never-auto-pick load-bearing. Detection blocks + pre-merge-gate wiring are rolepod additions.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Always pick Merge, skip menu" | Until the day you wanted PR review. 2-sec menu cheaper than rollback. |
| "Just push, figure out later" | "Later" = work forgotten on a branch nobody finds. |
| "Discard with `y` is fine" | Wrong-branch discard has happened. Interlock exists. |
| "CI will catch it" | CI catches syntax/tests, not wrong base branch. |
| "Defaults usually right, auto-pick" | "Usually" right is wrong sometimes — most expensive moment. |

Default: present menu. Bounded cost.
