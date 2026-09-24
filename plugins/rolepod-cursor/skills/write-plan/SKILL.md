---
name: write-plan
description: Use when turning an approved spec or a small clear goal into an executable implementation plan — ordered tasks, file list, test plan, agent routing, and parallel contracts if more than one agent will edit code. Phase = Plan.
---

# Write Plan

Turns an approved spec or a clear small goal into a plan another engineer or specialist agent executes without re-asking the user.

## Skip when

- A one-line fix on a single file, or a question / explanation only.
- The router tiered the task **R2** (one file + its own test, clear scope, ≈≤30 logic lines) → the plan is a 3-5 line inline checklist in chat, each step with its verify command. No artifact: that checklist is the owner's brief (goal, done-when, Command); the Lead does not pre-explore.
  - Scope grows past one file mid-flight (the task's own test file does not count) → stop, write the real plan here.
- **Spec-as-plan R3 lane:** ≤3 tasks the approved spec — or a change list the user approved target by target — already lists 1:1 (files, order, verify command, dependencies), single-agent, no high-risk surface → the same inline checklist. A parallel layout, a risk path, a 4th task, or a compaction mid-plan → write the artifact.

### 1. List files to touch

Read the approved spec or goal, the touched module's layout, 2-3 nearby files for patterns, the constraints (stack, style, no-touch zones), and the module boundary map if the project declares one (CLAUDE.md / ADR / docs).
The spec is unclear or incomplete → back to `write-spec`; the plan never re-opens product scope or acceptance criteria.
Work spans 2+ modules and NO map exists → offer a ONE-TIME bootstrap: a scout + `system-architect` derive the module list, dependency direction and no-touch zones from the code into the project's CLAUDE.md for approval — recently-active modules first (`git log`), the whole repo only when small. No subagents → the Lead derives it.

Name concrete paths — a directory or module when the slice's shape is still open (`hooks/lib/`; ownership then pins that directory), never a category. Code-intel when connected, else grep + read the adjacent code.

Done when: every path is concrete and read.

### 2. Order the tasks

- Smallest reversible unit first. Tests first for bugs, features and high-risk surfaces.
- Inside a slice, the migration and the public-API contract change land first; either becomes its own task only when several slices depend on it.
- A wide refactor with no safe single-commit path: expand (new path beside the old) → migrate consumers in reviewable green batches → contract (delete the old path once no caller remains).
- Many thin slices beat a few thick ones. A slice carrying a major unknown (new integration, unproven assumption) goes first — fail fast.
- A task that guards, gates or restores (a security surface) gets a **threat-model** task first: the written attack list its reviewers verify against (symlinks, case-folded names, forged evidence, moved refs, ignore rules, the kill path…). Reviewers never discover it round by round.

Size every task to ONE fresh context window; its builder starts with no memory beyond the ticket.
A task is one vertical slice: narrow but complete through every layer it touches, demoable or verifiable on its own. No file or line count sizes it.
Split when Delivers needs "and" and the halves touch different files, or when a slice cannot be verified without the next task. Halves on the same files stay ONE task — that split only adds a dispatch, a review and an integration in sequence.
Every task states **Delivers** (one user-visible sentence) and **Blocked by** (the tasks that gate it, or none); the Blocked-by graph is the plan's only statement of order.
Each edge names what it consumes (`Blocked by: Task 2 (its snapshot)`); an edge naming nothing is a convenience edge — drop it.
Two edge-free tasks on one file → **prefactor first** (an extract task giving them disjoint files: "make the change easy, then make the easy change"), or declare Sequential and say why.
A task is a ticket: it builds and ships alone, never a batch. Tasks sharing a seam (a contract or interface) form one ship group, named in the plan — the review-split unit past ~15 files (`implement-plan` Review).

A task names a file you have not read → read it.

Done when: every task has Delivers and Blocked by, every edge names what it consumes, and every file a task names has been read.

### 3. Test plan per task

Name the test type (unit / integration / contract / E2E / smoke / repro), the assertion that proves it, and the exact **Command** — copy-paste runnable, never "run the tests". "Adds tests" is not a test plan.
Behaviour no test can express yet → **Test / evidence** carries 1-3 acceptance criteria the reviewer walks, and the Command is the nearest mechanical check (lint / typecheck / smoke) — never skipped.
Tests cover the work — logic, UI, behaviour. A doc, comment, config-text or string-literal change gets NO test; render / lint is its check.
One test per rule at its owner, one smoke per call site — never a test per copy of the rule.
Each logic task names its **seam** in Test / evidence — the public interface the test exercises; the owner writes the failing test there first, never against internals.
No test infrastructure at all → the FIRST task bootstraps the minimal harness (runner config + one passing smoke test). Never plan Commands against a runner that does not exist.

Done when: every task names a test or evidence and a runnable Command; a task on a high-risk surface without a test plan gets one.

### 4. Approve the task list

Before writing the artifact, quiz the user on the numbered task list — per task: title, Delivers, Blocked by. Ask: granularity right? edges right (each task blocked only by what genuinely gates it)? merge or split any? Iterate until approved; the approved list is what the file records.

Decide the Parallel layout: parallel only when file ownership is genuinely disjoint and no handoff is needed; two edge-free tasks are candidates, never a mandate. Borderline → both shapes, the user picks: `references/parallel.md`.

Done when: the user approved the task list and the Parallel layout is decided.

### 5. Cohesion contract (parallel only)

Fill `templates/cohesion-contract-template.md` — Shared goal · Owners · File ownership · Shared interfaces · Merge order · Do-not-touch list · Verification per agent · Integration owner · Session split (optional, for tracks run as separate CLI sessions). Where to save it, the ownership rules and the session split → `references/parallel.md`.

Done when: every path sits under exactly one owner.

### 6. Owners and briefs

Every task carries **Owner:** — the role the domain map in `templates/plan-template.md` assigns to the task's files (path first, then concern).
- `Owner: Lead` for R1-sized work (trivial edit) or when the user said self-do; from R3 up the map decides.
- Reviewer roles are never owners. `qa-tester` = user-visible verification (E2E / UI test tasks); `security-engineer` on every touched high-risk surface, per task (the brief's Tier line). Both are named in the task's Reviewer line.
- The brief is generated from the task block (`plan-lint.sh --brief <N> <plan> [contract]`), so the block carries everything the owner needs, plus the spec.
- **Read first:** the 2-3 files and the pattern to copy, named by the Lead who read them while planning. The owner starts there and never re-surveys the repo.

No subagents → the Lead builds every task from the same blocks.

Done when: every task names its Owner and Read first.

### 7. Self-review

- **Placeholders** — never: `TBD` / `TODO` / "implement later" · "add appropriate error handling / validation / edge cases" without naming them · "write tests" without type, assertion and command · "similar to Task N" (repeat the shape — tasks are read out of order) · steps with no file path · symbols defined in no task and absent from the codebase.
- **Spec-coverage trace, both directions** — each requirement names its task; each task names the spec line that asked for it. No spec line = scope creep: cut it or move it to `## Follow-ups`.
- **Symbol consistency** — names match across tasks (`clearLayers()` in Task 3 vs `clearFullLayers()` in Task 7 is a bug); a symbol that does not exist → verify or remove.
- **Missing tests**, and **untouched high-risk surfaces**.
- **Boundary violations** — a map exists → every new cross-module import or dependency-direction reversal is called out and justified; an undeclared crossing = fix the plan, or update the map with the user.
- **Unowned or dual-owned files** in a parallel layout.
- **Loop-runnable** — `plan-lint.sh <plan> [contract]` (`~/.rolepod/bin/`, the plugin's `scripts/`, or `scripts/` in the source repo) checks the Failure policy, a Command per task, acyclic Blocked-by edges and parallel ownership. No plan-lint → `grep -q '^## Failure policy' <plan> && awk '/^### (Task ?|T)[0-9]/{t++;c[t]=0;i=1;next} /^## /{i=0} i&&/Command:/{c[t]=1} END{if(!t)exit 1;for(k=1;k<=t;k++)if(!c[k])exit 1}' <plan>`.

A risky plan (high-risk surface, ~8+ tasks, several specialists, an unfamiliar module) or the user asks for a second opinion → an independent reviewer: `references/plan-reviewer-prompt.md`.

Done when: every check above passes on the draft; the mechanical Loop-runnable check runs on the saved file in Write the artifact.

### 8. Write the artifact

Fill `templates/plan-template.md`, every section, in order: Source spec · Files to touch · Tasks · High-risk surfaces touched · Spec coverage (both directions) · Parallel layout · Done criteria · Failure policy · Risks · Changes during build · Follow-ups. A multi-agent plan adds the cohesion contract.
A task block, in order, one bold label per bullet: Delivers · Blocked by · Files · Read first · Change · Test / evidence · Proof · Expected failing signal · Command · Owner · Done when · On fail.
Tasks use `- [ ]` checkboxes so progress survives compaction. Status is the checkbox; a deviation is one line under `## Changes during build`, never build narrative in a task block.

One-session work → inline in chat. Multi-session → `docs/rolepod/plans/<feature>-YYYY-MM-DD.md`; re-planning never overwrites — a new dated file, `-v2` only when the date is the same.
`docs/rolepod/` is private by default: before the first save run `grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore`; a repo that tracks its working docs creates `.rolepod/docs-tracked`.
Harness plan mode active (a read-only planning state with its own approval gate) → present the plan through that gate and defer every disk write until it approves; do not fight the block.
Several people or machines build it → publish to the issue tracker: `references/team-issues.md`. Solo work never needs it.
Plan shapes, good and bad → `examples/plan-examples.md`.

Done when: every section is filled, and the plan is inline or saved with plan-lint (or its fallback) passing on the file.

## Guardrails

- The plan names the files, the order and the verification per task before any edit. Never start editing earlier.
- Parallel agents on one feature work under a written cohesion contract pinning file ownership and merge order. Never spawn more than one without it.
- Pick the simplest viable approach. Complexity needs an explicit reason and the user's awareness.

## Next phase

- `implement-plan` with the plan artifact.
- If `implement-plan` is not available, hand the plan to whoever will edit — file list, ordered tasks, per-task tests and done criteria are enough.
