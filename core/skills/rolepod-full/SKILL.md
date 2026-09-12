---
name: rolepod-full
description: Force-full Rolepod lifecycle — Define → Plan → Build → Verify → Review → Ship with no phase skips. Use only when the user explicitly invokes /rolepod-full or $rolepod-full for feature-scale work.
when_to_use: explicit user invocation only (/rolepod-full or $rolepod-full); never auto-trigger for normal requests
disable-model-invocation: true
tier: 0
phase: router
---

# Rolepod Full — force-full lifecycle entrypoint

The user typed `/rolepod-full` (or `$rolepod-full`). A **command alias**, not a new workflow: it forces the complete 6-phase lifecycle — `Define → Plan → Build → Verify → Review → Ship` — with no phase skips, even for a trivial-looking task. The user can still override mid-flow ("skip review", "just ship").

## Step 1 — defer to the router

`using-rolepod` available → load it plus `using-rolepod/references/force-full-lifecycle.md` and enter **force-full-lifecycle mode**; phase detail, backend table, start banner, careful-mode rigor live there. Not available (copied standalone) → the embedded fallback below.

## Boundary

Owns: detecting the explicit `/rolepod-full` intent and entering force-full mode.

Does not own: phase definitions, the execution backend, the Router table, the agent roster — `using-rolepod` and its force-full reference own these.

## Sanity check

`/rolepod-full` is for feature-scale work: new feature, major refactor, architecture change, product workflow, high-risk change. An obviously trivial prompt (`/rolepod-full what time is it`) → ask whether the user meant force-full before running the full ceremony.

## Embedded fallback — `using-rolepod` not available

Run the lifecycle directly as Lead:

1. **Define** — clarify goal, acceptance criteria, risk. Ask before assuming.
2. **Plan** — ordered task list; one verification command per task.
3. **Build** — implement surgically; every line traces to the goal.
4. **Verify** — fresh evidence (test / build / curl / screenshot). No completion claim without it.
5. **Review** — risk-appropriate review; external adversarial reviewers (an installed CLI different from the Lead's) when configured, otherwise the internal strong reviewer (security-engineer / universal-reviewer); qa-tester stays the test floor either way.
6. **Ship** — an explicit finish choice (merge / open PR / keep open / discard). Never auto-pick.

This fallback is ~70% of the full behavior; with `using-rolepod` present it is router-backed.
