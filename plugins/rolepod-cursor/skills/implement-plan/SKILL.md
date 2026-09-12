---
name: implement-plan
description: Use when executing an approved plan or a clear single-file edit — TDD for risky paths, surgical edits, bounded delegation, worktrees only when real filesystem isolation is needed. Phase = Build.
---

# Implement Plan

Execute the approved plan with discipline: TDD where it matters, surgical edits, fresh-context review of delegated work, worktrees only when filesystem isolation is real.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER edit code without reading the plan and the touched files first.
2. NEVER expand scope mid-implementation. New idea → one line under the plan's `## Follow-ups`, then finish the planned task.
3. ALWAYS write the failing test first for bug fixes and high-risk-surface work.
4. NEVER delegate without a written task scope and a clear done criterion.
5. CONTINUOUS execution between tasks AND between plan phases — no "should I continue?" check-ins, no progress summaries, never end the turn mid-plan: an ended turn is a stop however it is worded. Stop only on a BLOCKED, spec / plan gap, or scope ambiguity that SURVIVES a re-read of the plan and the touched files (BLOCKED: plus a variable change) — a wrinkle you can settle yourself is never grounds to stop.
6. Forced to end anyway (usage limit / context / user stop) → the last act is one line under the plan's `## Changes during build`: stopped after Task N · next Task M · how to start the env — the next session reads it before anything else.
</EXTREMELY-IMPORTANT>

## When to use

- A plan (formal or inline) exists and editing is next · a small one-file edit is clear · bounded delegation to a specialist · two engineers / sessions need filesystem isolation.

Skip when:
- A question only · the plan is still vague → `write-plan` first.

## Boundary

Owns: executing the approved plan — reading touched files, surgical edits, task-level tests, bounded delegation.

Does not own: changing product scope · Redesigning the plan silently · declaring final done · merging or branch fate.

Hand off:
- Plan vague / wrong / missing file → `write-plan`. Root cause unknown → `debug-issue`.
- Edits complete → `check-work`.
- `BLOCKED` survives context / model / scope changes and a re-plan → `manage-context` (escalate).

## Workflow

Inputs: the plan or task list · the touched files (read before editing) · style from 2-3 nearby files · the task's done criterion.

### 1. Read first — the plan is the loop contract

Read the touched files end-to-end (or the region with line numbers); verify the symbols the plan expects exist.

- **Baseline first:** before the first edit run the task's verify command once on the untouched tree (a throwaway worktree, never a stash) and record what already fails as limitations — never re-prove a baseline failure per round.
- An R2 (one file + test) or spec-as-plan R3 inline checklist is the same contract: run each step's command; scope grows past one file (its own test file is the same change) → stop, write the real plan.
- Verify each task by running its **Command** verbatim — never a re-derived guess. Pass → flip EVERY `- [ ]` under that task to `- [x]` (progress survives compaction). A **Test / evidence** line naming proof the Command does not run (browser, manual) is not covered by the flip — do that proof first. Fail → the task's **On fail**, else the plan's **Failure policy**.
- Shared plan (issues backend on — issue numbers in the plan header) → claim the task's issue (assign yourself) before touching a file; already assigned → take the next unblocked one; close it with the commit / PR pointer when review passes (write-plan's `references/team-issues.md`).

### 2. TDD-light for risky paths

Bug / new logic / billing / migration / auth / race / security: failing test → run (must fail) → smallest change → all tests green. Pure rename / typo / comment: tests-after or skip per the test gate. Task-type → discipline matrix and test hygiene (one frozen now, no literal dates, expectations from the spec, one test per rule): `references/tdd-by-risk.md`.

### 3. Surgical edit + quality reflexes

Touch only what the task requires — no "while I'm here" refactors, no reformatting, no single-use abstraction.
- **Comments** — default none; only when the WHY is non-obvious (hidden constraint, workaround, surprising invariant). Never WHAT.
- **Reuse ladder** — before a new helper / constant / type / validation, stop at the first rung that holds: (1) already in this codebase — extend, don't duplicate; (2) stdlib; (3) a native platform feature — DB constraint over app code, CSS over JS, `<input type="date">` over a picker lib; (4) an installed dependency; (5) only then the minimum new code — one line inline before a helper, a helper before a module. A NEW dependency is the last rung: maintained, reasonable size, compatible license; unsure → ask.
- **Tests** — never mock the database in an integration test; a real dependency over a fake / stub / mock.
- **Blast radius = caller count, not diff size** — changing the behavior, signature, or return shape of anything with callers → walk the callers FIRST (code-intel callers / impact when connected, else grep) and decide per caller: absorb, adapt, or split. An unvisited caller of a changed contract is the top write-time bug source.

### 4. Bounded delegation

Decide *whether* first. The plan's **Owner:** line wins — `Owner: Lead` → self-do; a named agent → delegate. A task with no Owner runs Q1-Q4:

```
Q1: More than 1 file to edit?        Q2: Run tests / build / server?
Q3: A real design-judgment call?     Q4: More than 3 tool calls total?
```
All "no" → self-do. Any "yes" → delegate to the closest specialist by path / concern / strategy.

Delegating → fill `templates/task-brief.md`: 1-2 files or one module, allowed / forbidden paths, test command, done criteria, tool cap.
- Absolute: the subagent NEVER commits (returns a manifest; the Lead commits) and NEVER expands scope.
- The brief names its **Reviewer** (a role that reads the diff on return, or `N/A` + why) — no reviewer, no dispatch.
- A write mandate goes only to the role that owns the path — never a generic platform agent (`general-purpose` / `default` / `claude`, or a bare Workflow `agent()`; a writing stage carries `agentType: 'rolepod:<role>'`), never a reviewer (`qa-tester` / `security-engineer` write tests and markdown only; `universal-reviewer` / `scout` markdown only). A CLI with hooks denies the out-of-scope edit; elsewhere this rule is the gate.

Pass the full task text + scene-setting context inline; never point the subagent at the plan file — the Lead curates the slice it needs. Use the least powerful model that can handle the role — cost compounds across N tasks × M reviews; the task-type → tier table is in `references/subagent-dispatch.md`.

**Self-review before manifest:** the subagent scans its own diff for placeholders, missing tests, plan coverage — a cheap pre-filter, not a substitute for §6.

**Return status:** `COMPLETED` with no concerns → §6; `COMPLETED` with Concerns → address scope / correctness first, then §6; `PARTIAL` → review the done slice, redispatch the remainder narrowed; `BLOCKED` → change a variable (context / model / scope / escalate), never retry blind. Deep handling: `references/subagent-dispatch.md`.

### 5. Parallel tracks — the plan's layout is the dispatch signal

Plan declares a parallel layout with a cohesion contract → dispatch every track whose dependencies are met in ONE message, each brief scoped to the contract's file ownership. Review each track as it returns (§6) — never barrier-wait. The integration owner merges per the contract's order; the final whole-implementation review runs on the cumulative diff. Two tracks reach for the same file → stop: sequential, or rewrite the contract. Protocol: `references/subagent-dispatch.md`.

Worktrees only when tracks truly collide on filesystem state (generated files, build artifacts, same-file edits a contract cannot split); disjoint ownership needs no isolation, a branch is enough for sequential work.

### 6. Per-task review pipeline — two-stage, fresh-context

A subagent returns `COMPLETED` → two reviewers in order on the diff alone (no implementer context). Each stage closes the same way — issue → implementer fixes → re-review — and stage 1 must approve before stage 2 starts: (1) **Spec compliance** — matches the task spec exactly, nothing missing, nothing extra; (2) **Code quality** — patterns, DRY, smell, test strength.

- Both stages mandatory for a delegated task touching a seam (caller / callee or shared-contract pair), an exported symbol, or >1 production file (its own test file does not count).
- A delegated single-file seam-free task skips §6 and is covered by the final review — which then must be a dispatched reviewer (`universal-reviewer` or review-code's concern-matched row) holding the cumulative diff + the acceptance criteria.
- Lead-executed tasks enter the same pipeline — the author never reviews own logic: seam / exported symbol / >1 production file → stage 2 (code-quality reviewer, balanced) on the diff alone; otherwise the task counts as one that skipped §6.

After all tasks: a **final whole-implementation review** on the cumulative diff for cross-task drift (type / symbol / contract mismatch, unowned files). Small clean plan (≤2 tasks, disjoint files, per-task reviews clean, no cross-task seam, every task subagent-built) → the Lead's cold read stands in. Dispatch the reviewer when a cross-task seam exists, ANY task skipped §6, or the Lead built any task. Hand off to `check-work` only after it clears.

## If a matching child plugin skill is available

Prefer sibling edit primitives over hand-rolled writes when the domain matches (Extension Protocol v1): `rolepod-uiproof` `/scaffold-e2e` (e2e scaffold from scenario + replay); `rolepod-wplab` `/wp-edit-{design,plugin,theme}`, `/wp-scaffold` (WP primitives inside `wp-content/`). Evidence auto-routes to `<git-root>/.rolepod/evidence/` under a rolepod parent, and to the child's own standalone path otherwise; `check-work` aggregates.

## If a matching Rolepod agent is available

- `frontend-developer` / `ui-ux-designer` — UI / interaction
- `backend-developer` — API / business logic / DB models
- `mobile-developer` — iOS / Android / RN / Flutter
- `billing-engineer` — billing / credits / subscription
- `ai-ml-engineer` — LLM / RAG / SDK / prompt cache
- `data-scientist` — analytics / pipelines / dashboards
- `content-strategist` — written output; pass `audience: dev|user|prospect`

Brief: spec + plan + files + tests + done criterion + handoff partner.

## If no matching agent is available

Execute as Lead: read plan + touched files → failing test first on risky paths → smallest change → module or full suite green → match local style, invent no patterns → flag adjacent dead code, delete nothing unasked → `check-work` before claiming done.

## Output

The implementation manifest is the canonical artifact: `templates/implementation-manifest.md` — files changed, tests, commands, evidence, scope check, status. A subagent returns it; the Lead commits.

## References

Load only when needed:
- `references/tdd-by-risk.md` — task type → test discipline.
- `references/wizard.md` — steps only the HUMAN can perform (credentials, vendor dashboards, CI secrets, a cutover) → an interactive bash wizard instead of a wall of instructions.
- `references/subagent-dispatch.md` — status taxonomy, parallel-track protocol, two-stage review prompts, model table, continuous-execution rationale.
- `examples/execution-examples.md` — surgical-vs-scope-creep and accept-vs-reject manifest, good/bad pairs.

## Hard stops

- A planned file does not exist where expected → verify or re-plan.
- A test you wrote passes before the code → assertion too weak; tighten.
- Subagent `COMPLETED` with failing tests, or `BLOCKED` re-dispatched unchanged → reject / change a variable.
- A subagent's diff accepted without the §6 reviews → stop, run them before building further.
- Scope creep → one line under `## Follow-ups`, finish the current task.
- About to ask "should I continue?" or end the turn between tasks → don't; Iron Rule 5.
- About to verify with a self-invented check → run the plan's **Command** verbatim; none named → `write-plan` for one.
- A parallel-layout plan executed one track at a time with no stated reason → dispatch the ready tracks concurrently (§5).

## Next phase

- `check-work` proves the change works.
- If `check-work` is not available, run tests / build / curl / browser yourself and report evidence inline.
