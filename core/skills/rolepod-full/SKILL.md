---
name: rolepod-full
description: Force-full Rolepod lifecycle — Define → Plan → Build → Verify → Review → Ship with no phase skips. Use only when the user explicitly invokes /rolepod-full or $rolepod-full for feature-scale work.
when_to_use: explicit user invocation only (/rolepod-full or $rolepod-full); never auto-trigger for normal requests
disable-model-invocation: true
tier: 0
phase: router
---

# Rolepod Full — force-full lifecycle entrypoint

The user typed `/rolepod-full` (or `$rolepod-full`). This is a **command alias / full-lifecycle entrypoint**, not a new workflow. It forces Rolepod's complete 6-phase lifecycle with no phase skips:

```
Define → Plan → Build → Verify → Review → Ship
```

Run every phase even if the task looks trivial — the user opted out of the auto-router's skip rules on purpose. They can still override mid-flow ("skip review", "just ship").

## Step 1 — defer to the real router

If the `using-rolepod` skill is available, use it in **force-full-lifecycle mode**. `using-rolepod` owns the phase-by-phase definition, the state machine, and the gates — this alias does not duplicate them.

If `using-rolepod` is not available (this skill was copied standalone), run the embedded fallback at the bottom.

## Boundary

Owns:
- Explicit `/rolepod-full` intent and execution backend selection.
- Start banner: phase, execution backend, no phase skips.

Does not own:
- Router table, phase definitions, agent roster, domain expertise.

Hand off:
- Use `using-rolepod` force-full mode when available.
- If standalone, run the fallback checklist only.

## Step 2 — pick the execution backend

Every CLI runs the same intent; only the backend differs by capability. Pick the best available and announce it at the start.

| Environment | Backend |
|---|---|
| Claude + agent-teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, v2.1.32+) | teammate mode — real multi-process team ([docs/agent-teams.md](../../../docs/agent-teams.md)) |
| Claude without agent-teams, or the user asked for single-process | Task / subagent dispatch + cohesion contract |
| Codex | Codex subagents |
| Gemini | Gemini subagents; inline fallback when subagents are unsupported |

Teammate mode costs ~4× tokens (one context window per teammate). It is the default heavy backend for `/rolepod-full` on a teams-enabled Claude — `/rolepod-full` already signals feature-scale, full ceremony. If the user wants the lighter single-process path, they say so and the backend drops to Task / subagents.

## Step 3 — announce + run

```
Routing: Force full lifecycle via /rolepod-full
Phase: Define
Execution: <teammate mode | Task/subagents | Codex subagents | Gemini subagents | inline fallback>
Skipping: none (user opted out of router skip rules)
Next step: <first discovery question or context read>
```

Then run Define → Plan → Build → Verify → Review → Ship through `using-rolepod` force-full mode.

## Sanity check — is this feature-scale work?

`/rolepod-full` is for feature-scale work: new feature, major refactor, architecture change, product workflow, high-risk change. If the prompt is obviously non-workflow or trivial (`/rolepod-full what time is it`), ask the user whether they meant force-full mode before running the full ceremony.

## Embedded fallback — `using-rolepod` not available

If copied standalone, run the lifecycle directly as Lead:

1. **Define** — clarify goal, acceptance criteria, risk. Ask before assuming.
2. **Plan** — ordered task list; one verification command per task.
3. **Build** — implement surgically; every line traces to the goal.
4. **Verify** — fresh evidence (test / build / curl / screenshot). No completion claim without it.
5. **Review** — risk-appropriate review; external adversarial reviewers (Codex / Gemini) when configured, otherwise qa-tester / security-engineer / universal-reviewer.
6. **Ship** — present an explicit finish choice (merge / PR / keep / discard). Never auto-pick.

This fallback is ~70% of the full behavior. With `using-rolepod` present it is router-backed; with a full Rolepod install it is best.
