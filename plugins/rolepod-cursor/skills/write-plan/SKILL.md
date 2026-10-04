---
name: write-plan
description: Use when turning an approved spec or a small clear goal into an executable implementation plan — ordered tasks, file list, test plan, agent routing, and parallel contracts if more than one agent will edit code. Phase = Plan.
---

# Write Plan

Turns an approved spec or a clear small goal into a plan another engineer or agent executes without re-asking the user.

## Skip when

- A one-line fix on a single file, or a question / explanation only.
- The router tiered the task **R2** (one file + its own test, clear scope, ≈≤30 logic lines) → the plan is a 3-5 line inline checklist in chat, each step with its verify command. No artifact: that checklist is the owner's brief (goal, done-when, Command); the Lead does not pre-explore.
  - Scope grows past one file mid-flight (the task's own test file does not count) → stop, write the real plan here.
- **Spec-as-plan R3 lane:** ≤3 tasks the approved spec — or a change list the user approved target by target — already lists 1:1 (files, order, verify command, dependencies), single owner, no parallel work or high-risk surface → the same inline checklist. A parallel layout, a risk path, a 4th task, or a compaction mid-plan → write the artifact. Otherwise write the plan artifact before building.

Each `edge-cases:` pointer below → `references/edge-cases.md`.

### 1. List files to touch

Read the spec or goal, the module layout, 2-3 nearby files for patterns, the constraints (stack, style, no-touch zones), and the module boundary map if one is declared (CLAUDE.md / ADR / docs).
The spec is unclear or incomplete → back to `write-spec`; the plan never re-opens product scope or acceptance criteria.
2+ modules and no map → offer a one-time bootstrap (edge-cases: No module boundary map).
Name concrete paths — a directory or module when the slice's shape is still open (`hooks/lib/`; ownership then pins that directory), never a category (code-intel, else grep + read).

Done when: every path is concrete and read.

### 2. Order the tasks

- Smallest reversible unit first. Tests first for bugs, features and high-risk surfaces.
- Inside a slice, the migration and the public-API contract change land first; either becomes its own task only when several slices depend on it.
- A wide refactor with no safe single-commit path → expand → migrate → contract (edge-cases: Wide refactor).
- Thin slices beat thick ones. A slice carrying a major unknown (new integration, unproven assumption) goes first — fail fast.
- A task that guards, gates or restores (a security surface) → a **threat-model** task first (edge-cases: Security-surface task).

Size every task to ONE fresh context window; its builder knows only the ticket.
A task is one vertical slice through every layer it touches, demoable or verifiable on its own; no file or line count sizes it.
Split when Delivers needs "and" and the halves touch different files, or when a slice cannot be verified without the next task. Halves on the same files stay ONE task — that split only adds a dispatch, a review and an integration in sequence.
Every task states **Delivers** and **Blocked by**; the Blocked-by graph is the only statement of order, each edge naming what it consumes (the template's Blocked by line).
Two edge-free tasks on one file → **prefactor first**, or Sequential with a reason (edge-cases: Prefactor).
A task builds and ships alone, never a batch. Tasks sharing a seam (a contract or interface) form one named ship group, written as the template's **Ship group** line — the unit that bounds its own review (`implement-plan` Review; a size split applies inside it).

In a parallel layout with multiple tracks: tasks that edit the same files or are chained by **Blocked by** edges within the same task group belong to one track (they run together in one worktree). A task that **Blocked by** tasks in two or more tracks starts after those tracks merge, as the first task of a new track. Document tracks in the plan's **Parallel layout** section as `## Tracks` (one line per track: `- A — <short name>: Task 1, Task 2 · branch <feature>/a-<short-slug>`), and tag each task with its track: `**Track:** A`.

A task names a file you have not read → read it.

Done when: every task has Delivers and Blocked by with named edges, and every file it names is read.

### 3. Test plan per task

Per task: the test type, the assertion, the **seam** (the public interface the test exercises; the failing test goes there first → `tdd-flow`) taken from the spec's Testing decisions (a seam the spec does not name gets one line of why in the task; no spec → the planner names the highest existing seam); an edge / error / race test only with its reason (a Success criterion names it, or an R4 (high-risk) floor → `tdd-flow`); and the exact **Command** — copy-paste runnable, never "run the tests". "Adds tests" is not a test plan.
The template's Test / evidence line carries the rest (no-test cases, one test per rule).
No test infrastructure → the first task bootstraps the harness (edge-cases: No test infrastructure).

Done when: every task names a test or evidence and a runnable Command; a task on a high-risk surface without a test plan gets one.

### 4. Settle what the spec left open

Order, split, owner and seam are the plan's own calls — never stop for the user to approve the task list.
A task needs a choice the spec does not make and the user would weigh — a new dependency, a public API or schema change, a migration, anything irreversible → one question with the simplest option recommended, before writing the artifact.
Parallel only with genuinely disjoint file ownership and no handoff; track-free tasks are candidates, never a mandate. Tracks share files and **Blocked by** relationships; organize by track, write the cohesion contract (section 5) → `references/parallel.md`.

Done when: every open choice is the plan's own or answered by the user, and the Parallel layout (with tracks) is decided.

### 5. Cohesion contract (parallel only)

Fill `templates/cohesion-contract-template.md` — Shared goal · Owners · File ownership · Shared interfaces · Merge order · Do-not-touch list · Verification per agent · Integration owner · Session split (optional). Save path, ownership rules, session split → `references/parallel.md`.
Wording several owners must write the same (a rule sentence, a message, a command) → one Shared interfaces entry per sentence: a label line starting with its id `C<n>`, then the sentence as a `> ` quote. A task that uses it cites the id in Change, and its Proof greps the sentence verbatim (`grep -F`); the brief then quotes it for the owner.

Done when: every path sits under exactly one owner.

### 6. Owners and briefs

**Owner:** the role the domain map in `templates/plan-template.md` assigns to the task's files (path first, then concern; `Lead` for R1-sized work or when the user said self-do). No template → API / services / models → `backend-developer`, UI components → `frontend-developer`, infra / CI / release → `devops-sre`, docs → `content-strategist`; else the closest writer role by path (`implement-plan`'s `references/subagent-dispatch.md` Picking the owner) — `Owner: Lead` only for R1-sized work.
Reviewer roles are never owners. Each high-risk surface names every task that touches it under **High-risk surfaces touched** (`- session-cookie validation (auth) → Task 2`): the brief tiers that task R4 and routes `security-engineer`, even when no file name looks risky (a docs-only task stays R1). A user-visible E2E flow the spec names gets no task owner and no reviewer role — `check-work` verifies it once the feature is built.
`plan-lint.sh --brief <N> <plan> [contract]` (`scripts/plan-lint.sh` in this skill's folder) builds the owner's brief from the task block, Expected failing signal and On fail included; the brief is the owner's whole slice, so the block carries everything it needs.
A task that builds or consumes the spec's agreed contract (Chosen approach: interface, data shape, compatibility rule, invariant) quotes the clause it must keep in its Change or Done when; its Blocked by edge names the symbol it consumes.
**Read first:** the 2-3 files and the pattern to copy, named by the Lead who read them; the owner never re-surveys the repo.
No subagents → the Lead builds every task from the same blocks.

Done when: every task names its Owner and Read first.

### 7. Self-review

- **Placeholders** — never `TBD` / `TODO` / "implement later" · "add appropriate error handling / validation / edge cases" unnamed · "write tests" without type, assertion and command · "similar to Task N" (repeat the shape; tasks are read out of order) · a step with no file path · a symbol defined in no task and absent from the codebase.
- **Spec coverage, both directions** — each requirement names its task; each task names its spec line. No spec line = scope creep: cut it or move it to `## Follow-ups`.
- **Symbol consistency** — `clearLayers()` in Task 3 vs `clearFullLayers()` in Task 7 is a bug; a missing symbol → verify or remove.
- **Granularity and edges** — each task fits one fresh context and passes the split rule (step 2); each Blocked-by edge names what it consumes, and no task blocks one it does not gate.
- **Missing tests**, **untouched high-risk surfaces**, **unowned or dual-owned files** in a parallel layout.
- **Boundary violations** against a declared module map (edge-cases: Module boundary map).
- **Loop-runnable** — `plan-lint.sh <plan> [contract]` checks the Failure policy, a Command per task, acyclic Blocked-by edges and parallel ownership. No plan-lint → check these four by eye (or the one-line check in edge-cases: No plan-lint).

The plan touches a high-risk surface or the user asks for a second opinion → an independent plan review: `references/plan-reviewer-prompt.md` (its When to dispatch adds ~8+ tasks, several specialists, an unfamiliar module).

Done when: every check passes on the draft; Loop-runnable runs on the saved file (step 8).

### 8. Write the artifact

Fill `templates/plan-template.md`, every section, in order: Source spec · Files to touch · Tasks · High-risk surfaces touched · Spec coverage (both directions) · Parallel layout · Done criteria · Failure policy · Risks · Changes during build · Follow-ups. Changes during build holds one line per task (`- Task N (`sha`): <verdict> -> <task file>`, at most 300 chars) and one line per deviation; review rounds, findings and handoffs live in the task file, never here.
A task block, in order, one bold label per bullet: Delivers · Blocked by · Files · Read first · Change · Test / evidence · Proof · Expected failing signal · Command · Owner · Done when · On fail.
Write the plan's prose in the user's language unless they ask for another; section headings, the field labels plan-lint reads, identifiers, paths, commands and quoted code stay verbatim.
One-session work → inline in chat. Multi-session → a dated file under the private `docs/rolepod/plans/`, never overwritten (edge-cases: Saving the plan).
Harness plan mode → present through its gate, defer disk writes (edge-cases: Harness plan mode).
Several people or machines build it → `references/team-issues.md`; solo work never needs it.
Several plans asked at once (a phase each, for separate sessions) → one agent per plan on the CLI's default agent, no role and no `model`, so each runs on the model the user chose for the Lead; its brief names the spec, the phase, the output file and a `plan-lint.sh` run on it; the Lead reads each lint and spot-checks each plan. No default agent → the Lead writes them in turn.
Plan shapes, good and bad → `examples/plan-examples.md`.

Done when: every section is filled, and a saved plan passes plan-lint (or the four Loop-runnable checks by eye).

## Guardrails

- The plan names the files, the order and the verification per task before any edit. Never start editing earlier.
- Parallel writers on one feature work under a written ownership map pinning file ownership and merge order — a cohesion contract, or a Workflow script that gives each writer a disjoint slice. Never spawn a second writer without one; read-only fleets are exempt.
- Pick the simplest viable approach. Complexity needs an explicit reason and the user's awareness.
- **Backward compatibility:** a plan without `## Tracks` + Parallel layout treats every task as its own track (worktree per task, old behavior); + Sequential means one track named `plan`. Plans with `## Tracks` use the new track-end review model.

## Next phase

- `implement-plan` with the plan artifact, or the inline checklist (R2, spec-as-plan R3), which is the owner's brief as written. A saved plan → show its task list first, one line each (title · Delivers · Blocked by), then start without waiting for a reply.
- If `implement-plan` is not available, hand the plan to whoever will edit — file list, ordered tasks, per-task tests and done criteria are enough.
