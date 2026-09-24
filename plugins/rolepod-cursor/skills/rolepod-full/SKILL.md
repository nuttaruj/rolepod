---
name: rolepod-full
description: Force-full Rolepod lifecycle — Define → Plan → Build → Verify → Review → Ship with no phase skips. Use only when the user explicitly invokes /rolepod-full or $rolepod-full for feature-scale work.
---

# Rolepod Full — force-full lifecycle entrypoint

Turns an explicit `/rolepod-full` (or `$rolepod-full`) into the complete `Define → Plan → Build → Verify → Review → Ship` lifecycle with no phase skipped, even for a trivial-looking task.
It is a command alias, not a new workflow. The user can still override mid-flow ("skip review", "just ship").

### 1. Sanity-check the scale

`/rolepod-full` is for feature-scale work: a new feature, a major refactor, an architecture change, a product workflow, a high-risk change.
An obviously trivial prompt (`/rolepod-full what time is it`) → ask whether the user meant force-full before running the full ceremony.

Done when: the task is feature-scale, or the user confirmed force-full.

### 2. Defer to the router

Load `using-rolepod` plus `using-rolepod/references/force-full-lifecycle.md` and enter **force-full-lifecycle mode**. The phase detail, the execution backend, the start banner and the careful-mode rigor live there; this skill owns only the explicit intent.

Done when: force-full mode is entered through the router, or step 3 runs.

### 3. Embedded fallback — `using-rolepod` absent

Either file is missing (this skill copied standalone) → run the lifecycle directly as the Lead:

1. **Define** — clarify the goal, the acceptance criteria and the risk. Ask before assuming.
2. **Plan** — an ordered task list with one verification command per task.
3. **Build** — implement surgically; every line traces to the goal.
4. **Verify** — fresh evidence (test / build / curl / screenshot). No completion claim without it.
5. **Review** — a risk-appropriate review: external adversarial reviewers (an installed CLI different from the Lead's) when configured, otherwise the internal strong reviewer (`security-engineer` / `universal-reviewer`). The writer's unit tests are the floor; `qa-tester` joins for user-visible behaviour. No subagents → the Lead's cold review per axis (correctness, security, performance, tests), recorded as a LIMITATION.
6. **Ship** — an explicit finish choice (merge / open PR / keep open / discard). Never auto-pick.

This fallback carries about 70% of the full behavior; with `using-rolepod` present the lifecycle is router-backed.

Done when: every phase has run and the user picked the finish.

## Next phase

- `using-rolepod` in force-full mode; it owns every phase from Define on.
- If `using-rolepod` is not available, the embedded fallback above runs to Ship.
