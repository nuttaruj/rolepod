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
5. CONTINUOUS execution between tasks AND between plan phases — no "should I continue?" check-ins, no progress summaries, and never end the turn mid-plan: an ended turn is a stop no matter how it is worded. Stop only on a BLOCKED, spec/plan gap, or scope ambiguity that SURVIVES a re-read of the plan and the touched files (BLOCKED: plus a variable change) — a wrinkle you can settle yourself is never grounds to stop.
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
- Stuck — `BLOCKED` survives context / model / scope changes and a re-plan → `manage-context` (escalate mode).

## Inputs to gather

- The plan or task list (file paths, ordered tasks, tests)
- The touched files (read them before editing)
- Style conventions from 2-3 nearby files
- The done criterion for this task

## Workflow

### 1. Read first

Read the touched files end-to-end (or the relevant region with line numbers). Don't pattern-match — verify the symbols and behavior exist where the plan expects.

**Shared plan (issues backend on — the plan header lists issue numbers per task):** claim the task's issue first (`gh issue edit <n> --add-assignee @me`) before touching any file — someone else assigned means take the next unblocked, unassigned issue instead; close the issue with the commit / PR pointer when the task's review passes. Details: write-plan's `references/team-issues.md`.

**The plan is the loop contract.** An R2 inline checklist (no artifact) is the same contract — run each step's command, and scope growing past one file → stop, write the real plan. Verify each task by running its **Command** verbatim — never a re-derived guess. When it passes, flip EVERY `- [ ]` under that task to `- [x]` in the plan artifact (tasks carry one checkbox per step; all flip together — that is how progress survives compaction). On a failing Command, follow the task's **On fail**, or the plan's **Failure policy** when the task has none.

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
- **Reuse ladder** — before adding a helper, constant, type, validation, or other new logic, stop at the first rung that holds: (1) already in this codebase — `rg` and extend, don't duplicate; (2) stdlib does it; (3) a native platform feature covers it — DB constraint over app code, CSS over JS, `<input type="date">` over a picker lib; (4) an already-installed dependency solves it; (5) only then write the minimum new code. A NEW dependency is the last rung and must be justified: maintained, reasonable size, compatible license. Unsure → ask.
- **Tests** — never mock the database in an integration test; prefer a real dependency over a fake / stub / mock.
- **Blast radius = caller count, not diff size** — changing the behavior, signature, or return shape of anything that already has callers → walk the callers FIRST (code-intel callers / impact when available, else `rg`) and decide per caller: absorb, adapt, or split. A 1-line change to a shared helper is a wide edit; an unvisited caller of a changed contract is the top write-time bug source.

### 4. Bounded delegation

First decide *whether* to delegate. The plan's **Owner:** line wins when set — `Owner: Lead` → self-do, a named agent → delegate to it. Only a task with no Owner runs the Q1-Q4 test:

```
Q1: More than 1 file to edit?        Q2: Run tests / build / server?
Q3: A real design-judgment call?     Q4: More than 3 tool calls total?
```
All "no" → self-do. Any "yes" → delegate to the closest specialist by path / concern / strategy.

When delegating, fill `templates/task-brief.md` — it scopes the task to 1-2 files, names allowed / forbidden paths, the test command, the done criteria, and the tool cap. Two rules are absolute: the subagent NEVER commits (it returns a manifest, the Lead commits), and it NEVER expands scope.

Pass the full task text + scene-setting context inline in the brief. Do not point the subagent at the plan file path — controller curates exactly the slice the subagent needs.

**Implementer self-review before manifest.** The subagent scans its own diff for placeholders, missing tests, and plan coverage before returning the manifest. Self-review is not a substitute for the §6 review pipeline; it is a cheap pre-filter.

**Implementer return status.** Manifest declares one of: `COMPLETED` with no concerns → §6 pipeline; `COMPLETED` with Concerns listed → address scope/correctness first, then §6; `PARTIAL` → review the done slice, redispatch the remainder narrowed; `BLOCKED` → change a variable (context / model / scope / escalate), never retry blind. Deep handling in `references/subagent-dispatch.md`.

### 5. Parallel tracks — the plan's layout is the dispatch signal

Plan declares a parallel layout with a cohesion contract → dispatch every track whose dependencies are met in ONE message (concurrent subagents), each brief scoped to the contract's file ownership. Review each track as it returns (§6) — never barrier-wait on the other tracks. The integration owner merges per the contract's merge order, then the final whole-implementation review runs on the cumulative diff. Two tracks reach for the same file mid-flight → stop: drop to sequential or rewrite the contract. Full protocol: `references/subagent-dispatch.md`.

Worktrees only when tracks truly collide on filesystem state (generated files, build artifacts, same-file edits a contract cannot split) — disjoint file ownership needs no isolation, and a branch is enough for sequential work.

### 6. Per-task review pipeline

After a subagent returns `COMPLETED`, dispatch two reviewers in order on the diff alone — no context from the implementer's session:

1. **Spec compliance** — does the diff match the task spec exactly? No missing requirements, no extras. Issue → implementer fixes → re-review. Approve before stage 2.
2. **Code quality** — patterns, DRY, smell, test strength. Issue → implementer fixes → re-review.

Both stages mandatory for delegated work. Lead-executed tasks: §6 collapses to one self-review read cold — run `git diff`, then re-read each touched file from disk (not from memory) before judging (fresh-context simulation).

After all tasks pass per-task review, dispatch a **final whole-implementation review** on the cumulative diff to catch cross-task drift (type/symbol/contract mismatch, unowned files in parallel layouts). Small clean plan (≤2 tasks, disjoint files, per-task reviews clean) → the Lead's own cold read of the cumulative diff stands in; dispatch the reviewer when cross-task seams exist. Hand off to `check-work` only after the final review clears.

### 7. Model selection by task complexity

Use the least powerful model that can handle each role — cost compounds across N tasks × M reviews. The task-type → tier table lives in `references/subagent-dispatch.md`.

## If a matching child plugin skill is available

Prefer sibling edit primitives over hand-rolled writes when the domain matches (Extension Protocol v1 — spec in the rolepod source repo):

- `rolepod-uiproof` `/scaffold-e2e` — e2e test scaffold from scenario + replay (playwright / vitest+playwright / pytest+selenium)
- `rolepod-wplab` `/wp-edit-{design,plugin,theme}`, `/wp-scaffold` — WP edit primitives + boilerplate inside `wp-content/`

Evidence auto-routes to `<git-root>/.rolepod/evidence/` under parent; standalone path otherwise. `check-work` aggregates.

## If a matching Rolepod agent is available

Delegate the bounded task to the closest specialist:

- `frontend-developer` / `ui-ux-designer` — UI / interaction
- `backend-developer` — API / business logic / DB models
- `mobile-developer` — iOS / Android / RN / Flutter
- `billing-engineer` — billing / credits / subscription
- `ai-ml-engineer` — LLM / RAG / Anthropic SDK / prompt cache
- `data-scientist` — analytics / pipelines / dashboards
- `content-strategist` — written output; pass `audience: dev|user|prospect`

Brief: spec + plan + files + tests + done criterion + handoff partner.

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Read the plan + touched files; write failing test first for risky paths
2. Make the smallest change that satisfies the test; run the full test suite (or the touched module's)
3. Match local style — naming, error handling, imports; do not invent new patterns unless the plan requires it
4. Flag dead code adjacent to your change; do not delete without asking
5. Verify before claiming done — see `check-work`

## Output

The implementation manifest is the canonical artifact: `templates/implementation-manifest.md`. It carries files changed, tests, commands, evidence, a scope check, and the status. A subagent returns this; the Lead commits. Do not restate the manifest shape here; the template is the single source.

## Examples

Non-blocking — read only when unsure about scope or whether to trust a subagent:
- `examples/execution-examples.md` — a surgical-vs-scope-creep execution and an accept-vs-reject subagent manifest, each a good/bad pair with a "why good wins" table. Read the whole file; the contrast is the lesson.

## References

Load only when the task needs it:
- `references/tdd-by-risk.md` — task type → test discipline: test-first vs evidence-after
- `references/wizard.md` — the task contains steps only the HUMAN can perform (credentials, vendor dashboards, CI secrets, a one-off cutover): generate an interactive bash wizard instead of a wall of chat instructions
- `references/subagent-dispatch.md` — implementer status taxonomy (COMPLETED ± concerns / PARTIAL / BLOCKED) and handling, parallel-track dispatch protocol, two-stage review prompt scaffolds (spec compliance / code quality), model selection table, continuous-execution rationale

## Hard stops

- A planned file does not exist where expected → stop, verify or re-plan
- A test you wrote passes before you added the code → assertion is too weak; tighten
- Subagent returns `COMPLETED` with failing tests, or `BLOCKED` re-dispatched unchanged → reject / change a variable (context / model / scope); never accept unchanged retry
- A subagent's diff accepted without spec-compliance + code-quality reviews → stop, run the §6 pipeline before building further
- Scope creep beyond the task list → stop, write a follow-up, finish current task
- About to ask "should I continue?" — or end the turn — between tasks or phases of a plan → don't; Iron Rule 5
- About to verify a task with a self-invented check while the plan names a **Command** → run the plan's Command
- A parallel-layout plan executed one track at a time with no stated reason → dispatch the ready tracks concurrently (§5)

## Full Rolepod enhancement

Adds cohesion contracts for parallel work, model-tier-aware agent routing, hooks that block subagent commits, the qa-tester floor, and the two-stage fresh-context review pattern.

## Next phase

- If `check-work` is available, continue there to prove the change works.
- If `check-work` is not available, run tests / build / curl / browser yourself and report evidence inline.
