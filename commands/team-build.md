---
description: Invoke Team-build phase — parallel engineers via cohesion contract
---

# Team Build Recipe

You are entering Team-build phase. Orchestrate multi-agent build:

1. `system-architect` already owns the cohesion contract (from team-plan output)
2. Identify which path(s) the task touches:
   - backend → spawn `backend-developer`
   - frontend → spawn `frontend-developer`
   - mobile → spawn `mobile-developer`
   - billing → spawn `billing-engineer`
   - ai/ml → spawn `ai-ml-engineer`
   - data → spawn `data-scientist`
3. Spawn matched engineers in parallel via Task tool, each with:
   - Contract reference (from team-plan)
   - Their specific task slice
   - Instruction to RED → GREEN → REFACTOR per cycle
4. `system-architect` monitors contract adherence
5. Apply gates: S1-S5 (simplicity) + F1-F5 (failure-mode) per agent's output
6. Merge results when all agents pass their RED → GREEN → REFACTOR cycle

If any engineer hits blocker → spawn `root-cause-tracing` skill workflow → fix → resume.

For high-risk surface (auth / billing / migrations): also spawn `security-engineer` in parallel (catches issues early, not at `/team-verify`).

## Output

- Code merged against the contract
- All RED integration tests now GREEN
- Each engineer reports diff + test evidence

## Gate focus

- **S1-S5 simplicity** — every commit run through 5-question gate
- **F1-F5 failure-mode** — before declaring task done

## Next phase

All engineers green → `/team-verify` for evidence pass.
