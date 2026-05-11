---
description: Invoke Team-define phase — frame intent → spec (parallel strategy agents)
---

# Team Define Recipe

You are entering Team-define phase. Orchestrate intent-framing across strategy agents.

## Spawn parallel via Task tool

1. `product-manager` — write user stories, problem statement, scope boundaries
2. `business-analyst` — cost / ROI / pricing impact / commercial fit
3. `system-architect` — technical feasibility, integration touchpoints, risk

Brief each with the user's raw intent. Each agent writes to its own artifact (no overlap).

## Synthesize

Lead reads all three reports + merges into a single `SPEC.md` containing:
- Problem statement
- User stories + acceptance criteria
- Commercial assumptions (cost, pricing, ROI sketch)
- Technical feasibility notes + open questions
- Out-of-scope list

## Gate focus

- **verify-first** — every "fact" in SPEC.md cited (file path / link / measurement). No memory recall.
- Ambiguity → ask user before declaring SPEC.md done.

## Next phase

When user confirms SPEC.md → suggest `/team-plan` to break spec into ordered tasks + cohesion contract.

## When NOT to use

- Spec already exists → skip to `/team-plan`
- Single-file fix / typo → default Subagent pattern, not team
