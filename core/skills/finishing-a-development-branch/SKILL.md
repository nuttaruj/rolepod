---
name: finishing-a-development-branch
description: Compatibility shim — the 4-option branch finish menu (merge / PR / keep open / discard) now lives in `finish-work`.
when_to_use: whenever a feature / fix / refactor branch reaches a natural stopping point — work is committed, tests pass locally, and the next action depends on context Lead can detect (fork vs upstream, open PR vs not, ahead of main vs not) rather than guess
tier: 3
redirect_to: finish-work
---

# finishing-a-development-branch

Compatibility shim. The finish-ritual now lives in **`finish-work`**.

→ Open `core/skills/finish-work/SKILL.md` and follow that instead.

This shim preserves the legacy trigger phrase during the migration release.

## If `finish-work` is not available

Minimum viable fallback:

1. Detect context: fork vs upstream, branch ahead of base, PR open or not
2. Present the 4-option menu: merge to main, open PR, keep open, discard
3. State the recommendation with a one-line reason
4. Wait for the user to pick before acting
5. Run the pre-merge gate before any merge / push action
6. For keep-open: ensure a checkpoint commit exists; no dangling untracked work
7. For discard: confirm intent; suggest `git tag` or branch backup before delete
