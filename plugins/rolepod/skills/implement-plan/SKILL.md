---
name: implement-plan
description: Use when executing an approved plan or a clear single-file edit — TDD at the plan's seams, surgical edits, bounded delegation, worktrees only when real filesystem isolation is needed. Phase = Build.
when_to_use: when a plan is approved (or the diff is small and obvious) and the next step is to actually edit code, tests, configs, content, or other artifacts
tier: 1
phase: build
---

# Implement Plan

Execute the approved plan with discipline: TDD at the seams the plan names, surgical edits, fresh-context review of delegated work, worktrees only when filesystem isolation is real.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER edit code without reading the plan and the touched files first.
2. NEVER expand scope mid-implementation. New idea → one line under the plan's `## Follow-ups`, then finish the planned task.
3. ALWAYS write the failing test first for every logic slice, at the plan's seam.
4. NEVER delegate without a written task scope and a clear done criterion.
5. CONTINUOUS execution between tasks AND between plan phases — no "should I continue?" check-ins, never end the turn mid-plan: an ended turn is a stop however it is worded. Stop only on a BLOCKED, spec / plan gap, or scope ambiguity that SURVIVES a re-read of the plan and the touched files (BLOCKED: plus a variable change).
6. Forced to end anyway (usage limit / context / user stop) → the last act is one line under the plan's `## Changes during build`: stopped after Task N · next Task M · how to start the env.
7. File changes go through the edit tool, never a shell heredoc / `sed -i` / `tee` — the self-do nudge, edit ledger and test-edit count see tool edits only.
</EXTREMELY-IMPORTANT>

## Skip when

- A question only · the plan is still vague → `write-plan` first.

## Boundary

Owns: executing the approved plan.

Does not own: changing product scope · Redesigning the plan silently · declaring final done · merging or branch fate.

Hand off:
- Plan vague / wrong / missing file → `write-plan`. Root cause unknown → `debug-issue`.
- Edits complete → `check-work`.
- `BLOCKED` survives context / model / scope changes and a re-plan → `manage-context` (escalate).

## Workflow

Inputs: the plan or task list · the touched files (read before editing) · style from 2-3 nearby files · the task's done criterion.

### 1. Read first — the plan is the loop contract

- **Lint the plan first:** `plan-lint.sh <plan>` (`~/.rolepod/bin/`) before the first task — FAIL (no **Command**, no checkboxes, a broken Blocked-by graph) → back to `write-plan`; never build on it.
Read the touched files end-to-end; verify the symbols the plan expects exist.

- **Baseline first:** before the first edit run the task's verify command once on the untouched tree and record what already fails as limitations — the task owner does it for a delegated task, the Lead only for its own R1/R2 work (never both).
- An R2 (one file + test) or spec-as-plan R3 inline checklist is the same contract: run each step's command; scope grows past one file (its test file included) → stop, write the real plan.
- Verify each task by running its **Command** verbatim — never a re-derived guess. Pass → flip EVERY `- [ ]` under that task to `- [x]`. A **Test / evidence** proof the Command does not run (browser, manual) is not covered by the flip — do it first. Fail → the task's **On fail**, else the plan's **Failure policy**.
- Shared plan (issues backend on — issue numbers in the plan header) → claim the task's issue (assign yourself) before touching a file; already assigned → take the next unblocked one; close it with the commit / PR pointer when review passes (write-plan's `references/team-issues.md`).

### 2. TDD at the plan's seams

Every logic slice: a failing unit test at the plan's seam (public interface, never internals) → must fail → smallest change → green → next; refactor at review, not in the loop. Prose / rename / config: no test. Matrix: `references/tdd-by-risk.md`.

### 3. Surgical edit + quality reflexes

Touch only what the task requires — no "while I'm here" refactors, no reformatting, no single-use abstraction.
- **Comments** — default none; only when the WHY is non-obvious (hidden constraint, workaround, surprising invariant). Never WHAT.
- **Reuse ladder** — before a new helper / constant / type / validation, stop at the first rung that holds:
  1. already in this codebase — extend, don't duplicate;
  2. stdlib;
  3. a native platform feature — DB constraint over app code, CSS over JS, `<input type="date">` over a picker lib;
  4. an installed dependency;
  5. only then the minimum new code — one line inline before a helper, a helper before a module.
  A NEW dependency is the last rung: maintained, reasonable size, compatible license; unsure → ask.
- **Tests** — never mock the database in an integration test; a real dependency over a fake / stub / mock.
- **Blast radius = caller count, not diff size** — changing the behavior, signature, or return shape of anything with callers → walk the callers FIRST (code-intel callers / impact when connected, else grep) and decide per caller: absorb, adapt, or split.

### 4. Bounded delegation

Decide *whether* first. The plan's **Owner:** line wins — `Owner: Lead` → self-do (R1/R2 only); a named role → dispatch the task brief to that role as the **task owner** — it builds, runs the Command, dispatches its own §6 reviewers, fixes, and returns a **decision brief** (agent-protocol **Ticket loop**). A task with no Owner runs Q1-Q4:

```
Q1: More than 1 file to edit?        Q2: Run tests / build / server?
Q3: A real design-judgment call?     Q4: More than 3 tool calls total?
```
All "no" → self-do. Any "yes" → delegate to the closest specialist by path / concern / strategy.

The brief comes from the plan, never hand-written: `plan-lint.sh --brief <N> <plan> [contract]` prints it (Goal / Blocked by / Read first / Files allowed + forbidden / Change / Command / Done when / Write / Reviewers — `none` only for a docs-only diff / Bounds). The Lead adds only **Read first** — the 2-3 files and the pattern to copy — and the owner starts there; it never re-surveys what the Lead already mapped. Key rules:
- `Owner: <role> · write: external` (pool opt-in, per task) — the owner, in its own worktree, writes the failing test at the seam first, then hands the draft that must turn it green to another CLI: `rolepod-cross-family --kind implement --brief <task-brief> --allow <path>... --detach` (edits outside `--allow` reverted; money / auth / data needs `--allow-risky`), `--collect`s in the FOREGROUND, then runs its own loop — the member never reviews it; the Lead never runs §6 for it.
  Not a token saver — for quota or a different vendor's draft only.
- Absolute: the task owner NEVER commits and NEVER expands scope. A path nobody in the wave owns → touch it, one `Also touched:` line in the brief; a path another owner holds → stop, `NEEDS: <path> — <one-line change>` in the brief; the Lead applies it at integration (R1/R2) or reassigns.
- A write mandate goes only to the role that owns the path — never a generic platform agent (`general-purpose` / `default` / `claude`, or a bare Workflow `agent()`; a writing stage carries `agentType: 'rolepod:<role>'`), never a reviewer (`qa-tester` / `security-engineer` write tests and markdown only; `universal-reviewer` / `scout` markdown only). A CLI with hooks denies the out-of-scope edit; elsewhere this rule is the gate.

Never point the owner at the plan file — the brief is its slice. Use the least powerful model that can handle the role.

**Return status:** a decision brief carries `COMPLETED` / `PARTIAL` / `BLOCKED` as its first word. `COMPLETED` with no concerns → §6; with Concerns → address scope / correctness first, then §6; `PARTIAL` → review the done slice, redispatch the remainder narrowed; `BLOCKED` → change a variable, never blind.

### 5. Parallel tracks — the plan's layout is the dispatch signal

Every unblocked task goes out in ONE message, each task owner in its OWN worktree named for the task (the brief prints the command), under the plan's cohesion contract; the Lead keeps working while task owners build. Integrate each as it returns (§6); merge in the contract's order. Two tracks reach for the same file → stop: sequential, or rewrite the contract.

### 6. Per-task review pipeline — the task owner's decision brief replaces Lead review

A task owner's **decision brief** replaces the Lead-run review — the Lead reads the brief, spot-checks ONE finding in its report file, runs the task's Command in the owner's worktree, then commits (ff-merge the owner's branch).
Every hop reads what the previous hop produced — brief, diff, report, decision brief — and opens the source only for that spot-check or a named residual, never by default. The task owner's reviewer — `universal-reviewer`, read-only, two axes (spec compliance + standards; or the concern-matched row) — plus `security-engineer` on a high-risk path and `qa-tester` (E2E / UI) when the slice changes what a user sees, in ONE message; the owner's own unit tests are the test floor.
An R4 slice with a usable pool: the external pass (`--kind review`, collected in the foreground) replaces `universal-reviewer` — the Lead runs no second external for the ship group. A Lead-built task (R1/R2) → the Lead runs §6 itself.

**One task per pass, then ship it.** Each task owner's Command → decision brief → Lead spot-check + commit → next unblocked task. Never batch tasks into one diff; the rhythm is a fresh context per task. A **whole-implementation review** on a cumulative diff runs only over a ship group (tasks sharing a seam, named in the plan) for cross-task drift — type / symbol / contract mismatch, unowned files. Build the next unblocked task in its OWN worktree while this one is under review — a tree under review never moves.

## If a matching child plugin skill is available

Prefer sibling edit primitives over hand-rolled writes when the domain matches: `rolepod-uiproof` `/scaffold-e2e`; `rolepod-wplab` `/wp-edit-{design,plugin,theme}`, `/wp-scaffold` (WP primitives inside `wp-content/`). Evidence auto-routes to `<git-root>/.rolepod/evidence/` (a child's own path when standalone); `check-work` aggregates.

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

Execute as Lead: read plan + touched files → failing test first at the plan's seam → smallest change → module or full suite green → match local style, invent no patterns → flag adjacent dead code, delete nothing unasked → `check-work` before claiming done.

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
