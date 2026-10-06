---
name: write-plan
description: Use when an approved spec or a small clear goal needs an executable plan before any edit; the next step is deciding files, task order, owners and tests; or two or more agents will edit code in parallel.
---

# Write Plan

Phase = Plan: turns an approved spec or clear goal into the shortest executable hand-off — files, order, tests and owner per task.
An unclear spec or an open decision → `write-spec` first (no `write-spec` → settle it with the user); the plan never reopens approved scope or acceptance criteria.

## Skip when

- A one-line fix on a single file, or a question / explanation only.
- **R2** (one file + its own test, clear scope, ≈≤30 logic lines) → a 3-5 line inline checklist in chat, each line with its verify command. No artifact: that checklist is the owner's brief (goal, done-when, Command); the Lead does not pre-explore. Scope grows past one file mid-flight (its own test file does not count) → stop and write the real plan here.
- **Spec-as-plan R3:** ≤3 tasks the approved spec — or an approved change list — already lists 1:1 (files, order, verify command, dependencies), one owner, no parallel work, no high-risk surface → the same inline checklist; the spec supplies the contract. Parallel work, a risk path, a 4th task or compaction → write the artifact.

Each `edge-cases:` pointer below → `references/edge-cases.md`; no reference → the step's own sentence is the rule.

### 1. Resolve scope and files

Read the approved spec or goal, concrete paths, constraints, relevant patterns, and any declared module boundary map.
2+ modules and no map → offer a one-time bootstrap (edge-cases: No module boundary map).
Name concrete paths — a directory or module when the slice's shape is still open (`hooks/lib/`; ownership then pins that directory), never a category (code-intel, else grep + read).

Done when: every path is concrete and read.

### 2. Order the tasks

- Smallest reversible unit first. Tests first for bugs, features and high-risk surfaces.
- Inside a slice, the migration and the public-API contract change land first; either becomes its own task only when several slices depend on it.
- A wide refactor with no safe single-commit path → expand → migrate → contract (edge-cases: Wide refactor).
- Thin slices beat thick ones. A slice carrying a major unknown (new integration, unproven assumption) goes first — fail fast.
- A task that guards, gates or restores (a security surface) → a **threat-model** task first: the attack list its reviewers verify against (edge-cases: Security-surface task).

Size each task for one fresh context, as a verifiable vertical slice. Split when outcomes touch different files or cannot be verified together; keep same-file halves together.
Every task states **Delivers** and **Blocked by**; the Blocked-by graph is the only statement of order, each edge naming what it consumes.
Two edge-free tasks on one file → **prefactor first** (an extract task giving them disjoint files), or Sequential with a reason (edge-cases: Prefactor).
A task builds and ships alone, never a batch. Tasks sharing a seam (a contract or interface) form one named ship group — the template's **Ship group** line, a seam list for the final branch review.
Tracks: tasks sharing files or chained by **Blocked by** form one track (one worktree, in order); a task Blocked by tasks in two or more tracks starts after those tracks merge, as the first task of a new track. Write them as the template's `## Tracks` lines and tag each task `**Track:** A`.
A task names a file you have not read → read it.

Done when: every task has Delivers and Blocked by with named edges, and every file it names is read.

### 3. Test plan per task

For each task: test or evidence type, assertion, seam, and an exact runnable **Command** (never the whole-repo suite). Use the spec's Testing decisions; no seam named → the highest existing seam, with why. The owner builds test-first at that seam (`tdd-flow`; no `tdd-flow` → one failing test, the smallest code that passes, then the next behavior).
Edge / error / race tests need a criterion or the R4 floor. Docs, comments, config text and string-only changes take a mechanical check, not a behavior test.
No test infrastructure → the first task bootstraps the minimal harness (edge-cases: No test infrastructure).

Done when: every task names a test or evidence and a runnable Command; a task on a high-risk surface without a test plan gets one.

### 4. Settle what the spec left open

Order, split, owner and seam are the plan's own calls — never stop for the user to approve the task list.
A task needs a choice the spec does not make and the user would weigh — a new dependency, a public API or schema change, a migration, anything irreversible → one question with the simplest option recommended, before writing the artifact.
Parallel only with genuinely disjoint file ownership and no handoff between tracks; edge-free tasks are candidates, never a mandate, and Sequential needs only a reason. Deciding the layout → `references/parallel.md`; no reference → shared files mean one track, and a borderline shared interface → show both shapes and let the user pick.

Done when: every open choice is the plan's own or answered by the user, and the Parallel layout is decided.

### 5. Parallel ownership (only when needed)

Fill `templates/cohesion-contract-template.md` (no template → Shared goal · Owners · File ownership · Shared interfaces · Merge order · Do-not-touch list · Verification per agent · Integration owner). Every path sits under exactly one owner; save path and session split → `references/parallel.md` (no reference → save it beside the plan under `docs/rolepod/plans/`).
Wording several owners must write the same (a rule sentence, a message, a command) → one Shared interfaces entry per sentence: a label line starting with its id `C<n>`, then the sentence as a `> ` quote. A task that uses it cites the id in Change, and its Proof greps the sentence verbatim (`grep -F`); the brief then quotes it for the owner.

Done when: every path sits under exactly one owner.

### 6. Owners and briefs

**Owner:** the role you pick for the task's files from the agent listing (each description names its scope); `Lead` only for R1-sized work or when the user said self-do. No listing → the closest writer role by path.
Reviewer roles are never owners. Each high-risk surface names every task that touches it under **High-risk surfaces touched** (`- session-cookie validation (auth) → Task 2`): the brief tiers that task R4 and routes its reviewers (Standard / Full → `security-engineer`; Lite → the two `universal-reviewer` lenses, `review-code` step 2; no `review-code` → `lens: spec` + `lens: standards`), even when no file name looks risky (a docs-only task stays R1). A user-visible E2E flow gets no task: `finish-work`'s QA pass checks it once per branch.
`plan-lint.sh --brief <N> <plan> [contract]` (`scripts/plan-lint.sh` in this skill's folder) builds the owner's brief from the task block, Expected failing signal and On fail included; no `plan-lint.sh` → the task block verbatim is the brief. The brief is the owner's whole slice, so the block carries everything it needs.
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

An independent plan review runs under write-spec's Cross-family critique trigger (Full, pool on, R4 — or the user asks) → `references/plan-reviewer-prompt.md` (the reviewer's prompt; no `references/plan-reviewer-prompt.md` → hand the reviewer step 7's checks). Otherwise self-review and the lint decide.

Done when: every check passes on the draft; Loop-runnable runs on the saved file (step 8).

### 8. Write the artifact

Fill `templates/plan-template.md` in its order: task blocks, dependencies, high-risk surfaces, parallel layout, failure policy, changes during build, follow-ups; a conditional section stays concise, or is omitted when it does not apply. Changes during build keeps one line per task and deviation; review rounds, findings and hand-offs belong in task records.
A task block, in order, one bold label per bullet: Delivers · Blocked by · Files · Read first · Change · Test / evidence · Proof · Expected failing signal · Command · Owner · Done when · On fail.
Write the plan's prose in the user's language unless they ask for another; section headings, the field labels plan-lint reads, identifiers, paths, commands and quoted code stay verbatim.
One-session work → inline in chat. Multi-session → a dated file under the private `docs/rolepod/plans/`, never overwritten (edge-cases: Saving the plan).
Harness plan mode, team issues, several plans at once → references/edge-cases.md; no file → present the plan through the harness gate / solo / one plan at a time.
Plan shapes, good and bad → `examples/plan-examples.md`; no examples → the template's own placeholders.

Done when: every applicable section is filled, and a saved plan passes plan-lint (or the four Loop-runnable checks by eye).

## Guardrails

- The plan names the files, the order and the verification per task before any edit. Never start editing earlier.
- Parallel writers on one feature work under a written ownership map pinning file ownership and merge order — a cohesion contract, or a Workflow script that gives each writer a disjoint slice. Never spawn a second writer without one; read-only fleets are exempt.
- Pick the simplest viable approach. Complexity needs an explicit reason and the user's awareness.

## Next phase

- `orchestrating-plans` with the plan artifact, or the inline checklist (R2, spec-as-plan R3), which is the owner's brief as written. A saved plan → show its task list first, one line each (title · Delivers · Blocked by), then start without waiting for a reply.
- If `orchestrating-plans` is not available, hand the plan to whoever will edit — file list, ordered tasks, per-task tests and done criteria are enough.
