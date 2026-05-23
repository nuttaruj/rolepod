---
name: rolepod-full
description: Force-full Rolepod lifecycle — Define → Plan → Build → Verify → Review → Ship with no phase skips. Use only when the user explicitly invokes /rolepod-full or $rolepod-full for feature-scale work.
---

# Rolepod Full — force-full lifecycle entrypoint

The user typed `/rolepod-full` (or `$rolepod-full`). This is a **command alias**, not a new workflow. It forces Rolepod's complete 6-phase lifecycle with no phase skips:

```
Define → Plan → Build → Verify → Review → Ship
```

Run every phase even if the task looks trivial — the user opted out of the auto-router's skip rules. They can still override mid-flow ("skip review", "just ship").

## Step 1 — defer to the router

If `using-rolepod` is available, load `using-rolepod` and `using-rolepod/references/force-full-lifecycle.md`, then enter **force-full-lifecycle mode**. The phase-by-phase detail, the execution backend table, the start banner, and careful-mode rigor all live in that reference — this alias does not duplicate them.

If `using-rolepod` is not available (this skill was copied standalone), run the embedded fallback below.

## Boundary

Owns:
- Detecting the explicit `/rolepod-full` intent and entering force-full mode.

Does not own:
- Phase definitions, the execution backend, the Router table, agent roster — `using-rolepod` and its `using-rolepod/references/force-full-lifecycle.md` reference own these.

Hand off:
- `using-rolepod` force-full mode when available; the embedded fallback when standalone.

## Sanity check — is this feature-scale work?

`/rolepod-full` is for feature-scale work: new feature, major refactor, architecture change, product workflow, high-risk change. If the prompt is obviously trivial (`/rolepod-full what time is it`), ask the user whether they meant force-full mode before running the full ceremony.

## Embedded fallback — `using-rolepod` not available

If copied standalone, run the lifecycle directly as Lead:

1. **Define** — clarify goal, acceptance criteria, risk. Ask before assuming.
2. **Plan** — ordered task list; one verification command per task.
3. **Build** — implement surgically; every line traces to the goal.
4. **Verify** — fresh evidence (test / build / curl / screenshot). No completion claim without it.
5. **Review** — risk-appropriate review; external adversarial reviewers (Codex / Gemini) when configured, otherwise qa-tester / security-engineer / universal-reviewer.
6. **Ship** — present an explicit finish choice (merge / PR / keep / discard). Never auto-pick.

This fallback is ~70% of the full behavior. With `using-rolepod` present it is router-backed; with a full Rolepod install it is best.
