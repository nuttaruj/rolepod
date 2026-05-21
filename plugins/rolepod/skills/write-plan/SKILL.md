---
name: write-plan
description: Use when turning an approved spec or a small clear goal into an executable implementation plan — ordered tasks, file list, test plan, agent routing, and parallel contracts if more than one agent will edit code. Phase = Plan.
when_to_use: when a spec or clear goal exists and the next step is to decide what to touch, in what order, by whom, with what tests, before any edits start
tier: 1
phase: plan
---

# Write Plan

Plan-phase entry skill. Convert an approved spec or a clear small goal into a concrete plan that another engineer (or specialist agent) can execute without re-asking the user.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER start editing code before the plan names the files, the order, and the verification per task.
2. NEVER spawn more than one parallel agent on the same feature without a written cohesion contract that pins file ownership and merge order.
3. NEVER write a vague task like "add tests" — every task must name a test or evidence that proves it is done.
4. Pick the simplest viable approach. Complexity needs an explicit reason and user awareness.
</EXTREMELY-IMPORTANT>

## When to use

- A spec exists and you are about to start implementation
- A goal is small but touches more than one file
- Multiple specialists may need to edit the same module
- The work could be parallelized across worktrees or sessions

Skip when:
- The task is a one-line fix on a single file (just do it)
- The user asks for a question / explanation only

## Boundary

Owns:
- HOW / WHO / WHERE / ORDER.
- File list, task order, test plan per task, agent routing, cohesion contract.

Does not own:
- Re-opening product scope or acceptance criteria unless the spec is incomplete.
- Editing files.
- Final verification evidence.

Return / hand off:
- Spec unclear → return to `write-spec`.
- Plan approved → `implement-plan`.

## Inputs to gather

- Approved spec or clear goal statement
- Repo layout for the touched module
- Existing patterns to match (read 2-3 nearby files)
- Known constraints: stack, style, no-touch zones
- Available specialist agents

## Workflow

### 1. List files likely to touch

Concrete paths, not categories. If `gitnexus_impact` is available, use it to widen blast radius. Otherwise read or `rg` adjacent code.

### 2. Order the tasks

Smallest reversible unit first. Tests-first for bugs, features, and high-risk surfaces. Migrations before code that depends on them. Public-API contract changes before consumers.

Prefer vertical slices — each task cuts through all layers and is demoable on its own — over horizontal layers (all schema, then all API). Many thin slices beat a few thick ones.

When one slice carries a major unknown (a new integration, an unproven assumption), sequence it first — fail fast before investing in dependent slices.

Break a task down further if any holds: >2hr of work, acceptance needs more than 3 bullets, it touches 2+ independent subsystems, or its title contains "and".

### 3. Test plan per task

For each task, name the test type (unit / integration / contract / E2E / smoke / benchmark / repro) and the assertion that would prove it works. "Adds tests" is not a test plan.

### 4. Decide if parallelism helps

Parallel agents only help when file ownership is genuinely disjoint and the work does not need handoff between agents. Otherwise sequential is faster and cheaper.

### 5. If parallel, write a cohesion contract

A short doc that pins: who owns which files, what interfaces they share, what merges first, what each agent must not touch. Save to `contract.md` or `specs/<feature>-cohesion.md`.

### 6. Route to agents

For each task, name the best specialist if one is available. Brief = task + files + tests + done criteria + handoff partner. Lead executes tasks for which no specialist fits.

### 7. Self-review the plan

Scan for placeholders, vague tasks, missing tests, untouched high-risk surfaces, and unowned files in a parallel layout.

## If a matching Rolepod agent is available

Route specialist work upfront:

- `system-architect` for API / interface / data-model decisions
- `backend-developer` / `frontend-developer` / `mobile-developer` for stack-specific implementation
- `qa-tester` for test plan depth
- `security-engineer` on touched auth / billing / migration / secret surfaces

Brief each agent with the spec, the file list, the test plan, and the handoff partner.

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Read 2-3 nearby files to match style
2. List files to touch (paths, not categories)
3. Order tasks smallest-reversible first
4. Name a test or evidence per task
5. Pick the simplest viable approach
6. Flag every high-risk surface explicitly
7. Note where the API or schema contract changes
8. Decide sequential vs parallel honestly — sequential is the default

## Output format

```
Files to touch
Tasks (ordered, with test plan per task)
High-risk surfaces touched
Parallel layout (if any) + cohesion contract path
Done criteria
Risks
```

For multi-session work, save to `docs/plans/<feature>.md`. For one-session work, inline is fine.

## Hard stops

- A task names a file you have not read → stop, read it
- A task touches a high-risk surface without a test plan → stop, add the test plan
- Two parallel agents end up needing the same file → drop to sequential or rewrite the contract
- Plan references a symbol that does not exist → verify or remove

## Full Rolepod enhancement

Full Rolepod improves this phase by adding agent-routing heuristics, cohesion contracts as a first-class artifact, model-tier / cost-aware routing across the 18 agents, and tests that prove every shipped plan named a test per task.

## Next phase

- If `implement-plan` is available, continue there with the plan artifact.
- If `implement-plan` is not available, hand off this plan directly to whoever will edit — the file list, the ordered tasks, the per-task tests, and the done criteria are enough.
