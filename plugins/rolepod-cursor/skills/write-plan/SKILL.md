---
name: write-plan
description: Use when turning an approved spec or a small clear goal into an executable implementation plan — ordered tasks, file list, test plan, agent routing, and parallel contracts if more than one agent will edit code. Phase = Plan.
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

Concrete paths, not categories. If code-intel index available, use it to widen blast radius. Otherwise `rg` + Read adjacent code.

### 2. Order the tasks

Smallest reversible unit first. Tests-first for bugs, features, and high-risk surfaces. Migrations before code that depends on them. Public-API contract changes before consumers.

Prefer vertical slices — each task cuts through all layers and is demoable on its own — over horizontal layers (all schema, then all API). Many thin slices beat a few thick ones.

When one slice carries a major unknown (a new integration, an unproven assumption), sequence it first — fail fast before investing in dependent slices.

Break a task down further if any holds: >2hr of work, acceptance needs more than 3 bullets, it touches 2+ independent subsystems, or its title contains "and".

### 3. Test plan per task

For each task, name the test type (unit / integration / contract / E2E / smoke / benchmark / repro) and the assertion that would prove it works. "Adds tests" is not a test plan.

### 4. Decide if parallelism helps

Parallel agents only help when file ownership is genuinely disjoint and the work does not need handoff between agents. Otherwise sequential is faster and cheaper. When the call is borderline (e.g. two slices that might overlap on a shared interface), present both shapes — sequential single-owner vs parallel + contract — with one-line trade-offs and let the user pick before drafting tasks.

### 5. If parallel, write a cohesion contract

Fill `templates/cohesion-contract-template.md` — it pins file ownership, shared interfaces, merge order, the do-not-touch list, and the integration owner. Save to `contract.md` or `docs/plans/<feature>-cohesion.md`.

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

## Output

The plan template is the canonical artifact: `templates/plan-template.md`. Fill every section — it is the contract `implement-plan` executes. A multi-agent plan adds a cohesion contract (`templates/cohesion-contract-template.md`). Do not restate the section list here; the templates are the single source of plan shape.

For one-session work, inline the filled template in chat. For multi-session work, save it to `docs/plans/<feature>.md`.

## Examples

Non-blocking — read only when the plan being drafted is unclear:
- `examples/plan-examples.md` — a sequential single-owner plan and a parallel multi-agent plan, each good/bad with a "why good wins" table. Read the whole file; the contrast is the lesson.

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
