---
name: implement-plan
description: Use when executing an approved plan or a clear single-file edit — TDD for risky paths, surgical edits, bounded delegation, worktrees only when real filesystem isolation is needed. Phase = Build.
---

# Implement Plan

Build-phase entry skill. Execute the approved plan with discipline: TDD where it matters, surgical edits, fresh-context reviewer pattern for delegated work, worktrees only when parallel filesystem isolation is real.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER edit code without reading the plan and the touched files first.
2. NEVER expand scope mid-implementation. New idea → write it down and finish the planned task first.
3. ALWAYS write the failing test first for bug fixes and high-risk-surface work.
4. NEVER delegate to a subagent without a written task scope and a clear done criterion.
</EXTREMELY-IMPORTANT>

## When to use

- A plan (formal or informal) exists and the next step is editing
- A small one-file edit is clear from the conversation
- Bounded delegation to a specialist is needed
- Two engineers (or sessions) need filesystem isolation

Skip when:
- The task is a question only
- The plan is still vague — go back to `write-plan` first

## Boundary

Owns:
- Executing the approved plan.
- Reading touched files, making surgical edits, writing/running task-level tests, bounded delegation.

Does not own:
- Changing product scope.
- Redesigning the plan silently.
- Declaring final done.
- Merging or branch fate.

Return / hand off:
- Plan vague / wrong / missing file → return to `write-plan`.
- Root cause unknown → `debug-issue`.
- Edits complete → `check-work`.

## Inputs to gather

- The plan or task list (file paths, ordered tasks, tests)
- The touched files (read them before editing)
- Style conventions from 2-3 nearby files
- The done criterion for this task

## Workflow

### 1. Read first

Read the touched files end-to-end (or the relevant region with line numbers). Don't pattern-match — verify the symbols and behavior exist where the plan expects.

### 2. TDD-light for risky paths

Bug / new logic / billing / migration / auth / race / security:
- Write the failing test that captures the desired behavior
- Run it (must fail)
- Write the smallest code change that makes it pass
- Run all tests (must stay green)

Pure rename / typo / comment fix: tests-after or skip per the test gate. For the full task-type → discipline matrix, see `references/tdd-by-risk.md`.

### 3. Surgical edit + quality reflexes

Touch only what the task requires. No "while I'm here" refactors. No reformatting. No new abstraction for single-use.

While editing, hold these reflexes:
- **Comments** — default to none. Add one only when the WHY is non-obvious (a hidden constraint, a workaround, a surprising invariant). Never comment WHAT the code does.
- **One source of truth** — before adding a helper, constant, type, or validation, search for an existing one (`rg`) and extend it instead of duplicating.
- **New dependency** — justify it: not already covered by stdlib or an existing dep, maintained, reasonable size, compatible license. Unsure → ask.
- **Tests** — never mock the database in an integration test; prefer a real dependency over a fake / stub / mock.
- **Code intel** — if code-intel index available, use it for blast radius before wide edits; otherwise `rg` + Read.

### 4. Bounded delegation

First decide *whether* to delegate — the Q1-Q4 test:

```
Q1: More than 1 file to edit?        Q2: Run tests / build / server?
Q3: A real design-judgment call?     Q4: More than 3 tool calls total?
```
All "no" → self-do. Any "yes" → delegate to the closest specialist by path / concern / strategy.

When delegating, pick from the agent list below.

When delegating, fill `templates/task-brief.md` — it scopes the task to 1-2 files, names allowed / forbidden paths, the test command, the done criteria, and the tool cap. Two rules are absolute: the subagent NEVER commits (it returns a manifest, the Lead commits), and it NEVER expands scope.

### 5. Worktrees only for real parallel

Use a git worktree when two sessions actually need the same files at the same time. A branch is enough for sequential work.

### 6. Fresh-context review of delegated work

After a subagent finishes, a fresh reviewer (Lead or another agent) reads the diff with no context from the implementer's session. Catches over-fitting and scope creep.

## If a matching Rolepod agent is available

Delegate the bounded task to the closest specialist:

- `frontend-developer` / `ui-ux-designer` for UI work and interaction design
- `backend-developer` for API / business logic / DB models
- `mobile-developer` for iOS / Android / React Native / Flutter
- `billing-engineer` for billing / credits / subscription paths
- `ai-ml-engineer` for LLM / RAG / Anthropic SDK / prompt-cache work
- `data-scientist` for analytics / pipelines / dashboards
- `content-strategist` for any human-readable written output — pass `audience: dev` for ADRs / runbooks / durable docs, `audience: user` for FAQ / onboarding / support content, `audience: prospect` for SEO / conversion copy

Brief: spec + plan + files + tests + done criterion + handoff partner.

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Read the plan and the touched files
2. Write the failing test first for risky paths
3. Make the smallest change that satisfies the test
4. Run the full test suite (or at least the touched module's suite)
5. Match local style — naming, error handling, imports
6. Do not invent new patterns unless the plan requires it
7. Mention any dead code adjacent to your change; do not delete it without asking
8. Verify the change before claiming done — see `check-work`

## Output

The implementation manifest is the canonical artifact: `templates/implementation-manifest.md`. It carries files changed, tests, commands, evidence, a scope check, and the status. A subagent returns this; the Lead commits. Do not restate the manifest shape here; the template is the single source.

## Examples

Non-blocking — read only when unsure about scope or whether to trust a subagent:
- `examples/execution-examples.md` — a surgical-vs-scope-creep execution and an accept-vs-reject subagent manifest, each a good/bad pair with a "why good wins" table. Read the whole file; the contrast is the lesson.

## References

Load only when the task needs it:
- `references/tdd-by-risk.md` — task type → test discipline: test-first vs evidence-after

## Hard stops

- A planned file does not exist where expected → stop, verify or re-plan
- A test you wrote passes before you added the code → assertion is too weak; tighten
- A subagent returns COMPLETED with failing tests → reject, re-brief
- A subagent's diff accepted without a fresh-context read of it → stop, review before building further
- Scope creep beyond the task list → stop, write a follow-up, finish current task

## Full Rolepod enhancement

Full Rolepod improves this phase by adding cohesion contracts for parallel work, model-tier-aware agent routing, hooks that block subagent commits, the qa-tester floor, and the two-stage fresh-context review pattern.

## Next phase

- If `check-work` is available, continue there to prove the change works.
- If `check-work` is not available, run tests / build / curl / browser yourself and report evidence inline.
