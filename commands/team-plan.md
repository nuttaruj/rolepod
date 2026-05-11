---
description: Invoke Team-plan phase — spec → ordered tasks + cohesion contract + RED tests
---

# Team Plan Recipe

You are entering Team-plan phase. Convert SPEC.md into ordered tasks + cohesion contract before building.

## Prerequisites

- SPEC.md exists (from `/team-define` or user-provided)
- Lead has read SPEC.md end-to-end

## Spawn via Task tool

1. `system-architect` — writes:
   - `.claude/orchestration/<topic>-contract.md` with shared types, invariants, integration touchpoints
   - Named integration tests written RED (failing) to file BEFORE any engineer touches code
2. `product-manager` — break work into ordered, verifiable tasks with acceptance criteria

## Path-triggered joiners

Pull these into planning only when SPEC touches their surface:
- `billing-engineer` → billing / payments / credits
- `ai-ml-engineer` → LLM / RAG / agents / prompts
- `security-engineer` → auth / permissions / data sensitivity
- `data-scientist` → analytics / ETL / statistical models

## Output

- Cohesion contract path (agents may NOT mutate it)
- RED integration tests (failing — pinpoint missing implementation)
- Task list with dependency ordering
- Specialist assignments per task (matched by path)

## Gate focus

- **Q1-Q4 delegation** — verify each task crosses delegation threshold (>1 file / runs tests / design judgment / >3 tool calls)
- **Simplicity check** — simplest viable approach per task; no speculative abstraction

## Next phase

When contract + RED tests + task list complete → `/team-build` to spawn parallel engineers.
