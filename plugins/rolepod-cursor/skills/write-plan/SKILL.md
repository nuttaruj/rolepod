---
name: write-plan
description: Use when turning an approved spec or a small clear goal into an executable implementation plan — ordered tasks, file list, test plan, agent routing, and parallel contracts if more than one agent will edit code. Phase = Plan.
---

# Write Plan

Convert an approved spec or a clear small goal into a plan another engineer (or specialist agent) can execute without re-asking the user.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER start editing before the plan names the files, the order, and the verification per task.
2. NEVER spawn more than one parallel agent on the same feature without a written cohesion contract that pins file ownership and merge order.
3. NEVER write a vague task like "add tests" — every task names a test or evidence that proves it done AND the exact runnable command that checks it, so the build loop verifies without guessing.
4. Pick the simplest viable approach. Complexity needs an explicit reason and user awareness.
</EXTREMELY-IMPORTANT>

## When to use

- A spec exists and implementation is next · a small goal touches more than one file · several specialists may edit the same module · work could parallelize across worktrees or sessions.

Skip when:
- A one-line fix on a single file · a question / explanation only.
- The router tiered the task **R2** (1 file + its own test, clear scope, ≈≤30 logic lines) → the plan is a 3-5 line inline checklist in chat, each step with its verify command; no artifact. Scope grows past one file mid-flight (the task's own test file does not count) → stop, write the real plan here. **Spec-as-plan R3 lane:** ≤3 tasks the approved spec already lists 1:1 (files, order, verify command, dependencies), single-agent, no high-risk surface → the same inline checklist; a parallel layout, a risk path, a 4th task, or a compaction mid-plan → write the artifact.

## Boundary

Owns: HOW / WHO / WHERE / ORDER — file list, task order, test plan per task, agent routing, cohesion contract.

Does not own: re-opening product scope or acceptance criteria unless the spec is incomplete · editing files · final verification evidence.

Hand off:
- Spec unclear → `write-spec`. Plan approved → `implement-plan`.

## Workflow

Inputs: the approved spec or goal · repo layout for the touched module · 2-3 nearby files for patterns · constraints (stack, style, no-touch zones) · available specialist agents · the module boundary map if the project declares one (CLAUDE.md / ADR / docs).

Work spans 2+ modules and NO map exists → offer a ONE-TIME bootstrap: scout + `system-architect` derive module list, dependency direction, and no-touch zones from the code into the project's CLAUDE.md for approval — recently-active modules first (`git log`), the whole repo only when small. Paid once; every later session reads boundaries instead of re-inferring them.

### 1. List files to touch

Concrete paths, not categories. Code-intel index when connected widens the blast radius; otherwise grep + Read adjacent code.

### 2. Order the tasks

Smallest reversible unit first. Tests-first for bugs, features, high-risk surfaces. Migrations before code that depends on them; public-API contract changes before consumers. A wide refactor with no safe single-commit path: expand (new path beside the old) → migrate consumers in reviewable green batches → contract (delete the old path once no caller remains).

Prefer vertical slices — each cuts through all layers and is demoable alone — over horizontal layers. Many thin slices beat a few thick ones. A slice carrying a major unknown (new integration, unproven assumption) goes first — fail fast.

Break a task down further if any holds: >2 h of work · acceptance needs >3 bullets · touches 2+ independent subsystems · its title contains "and". Every task states **Delivers** (one user-visible sentence) and **Blocked by** (the tasks that gate it, or none) — the Blocked-by graph is the plan's only statement of order.

### 3. Test plan per task

Name the test type (unit / integration / contract / E2E / smoke / benchmark / repro), the assertion that proves it, and the exact command — copy-paste runnable, not "run the tests". "Adds tests" is not a test plan. Size by rules: one test per rule at its owner, one smoke per call site — never a test per copy of the rule.

No test infrastructure at all → the FIRST task bootstraps the minimal harness (runner config + one passing smoke test) so every later Command is runnable. Never plan Commands against a runner that does not exist.

### 4. Decide if parallelism helps

Before writing the artifact, quiz the user on the numbered task list — per task: title, Delivers, Blocked by. Three questions: granularity right? edges right (each task blocked only by what genuinely gates it)? merge or split any? Iterate until approved; the approved list is what the file records.

Parallel agents help only when file ownership is genuinely disjoint and the work needs no handoff between agents — otherwise sequential is faster and cheaper. Two tasks with no edge are parallel *candidates*, never a mandate; sequential anyway is fine — say why in the Parallel layout line. Borderline (a shared interface) → present both shapes with one-line trade-offs; the user picks.

High-stakes multi-option decisions (approach, architecture, sequencing) → a **cross-CLI advisory panel** only when opted in (`/rolepod-full` or an explicit ask) and the decision earns ~3× tokens; the Lead reconciles and owns the choice. Gating, strengths, collect-then-decide protocol, single-CLI vertical fallback: `references/advisory-routing.md`.

### 5. If parallel, write a cohesion contract

Fill `templates/cohesion-contract-template.md` — file ownership, shared interfaces, merge order, do-not-touch list, integration owner. Save to `contract.md` or `docs/rolepod/plans/<feature>-cohesion-YYYY-MM-DD.md`.

Tracks can also run as SEPARATE CLI sessions (cross-CLI wall-clock parallelism) → fill the contract's optional **Session split** section (per-track CLI + branch + kickoff prompt, one integration session). Execution: implement-plan's `references/subagent-dispatch.md`, "Session-split tracks".

### 6. Route to agents

Per task, the best specialist when one fits; the Lead executes the rest. Brief = task + files + tests + done criteria + handoff partner.

### 7. Self-review the plan

- **Placeholders** — the six patterns below.
- **Spec-coverage trace, both directions** — each requirement names the task that implements it; each task names the spec line that asked for it (no spec line = scope creep: cut or follow-up).
- **Symbol consistency** — names match across tasks (`clearLayers()` in Task 3 vs `clearFullLayers()` in Task 7 is a bug).
- **Missing tests** on any task.
- **Loop-runnable** — every task carries an exact Command and the plan states a Failure policy. Deterministic check: `plan-lint.sh <plan> [contract]` (`~/.rolepod/bin/` installed, the plugin's `scripts/`, or `scripts/` in the source repo) — Failure policy + Command per task + Blocked-by edges acyclic + parallel ownership completeness. Inline fallback: `grep -q '^## Failure policy' <plan> && awk '/^### (Task ?|T)[0-9]/{t++;c[t]=0;i=1;next} /^## /{i=0} i&&/Command:/{c[t]=1} END{if(!t)exit 1;for(k=1;k<=t;k++)if(!c[k])exit 1}' <plan>`
- **Boundary violations** — a map exists → every new cross-module import or dependency-direction reversal is called out and justified; undeclared crossing = fix the plan or update the map with the user.
- **Untouched high-risk surfaces.**
- **Unowned or dual-owned files** in a parallel layout — every path sits under EXACTLY one owner (unowned = unplannable, dual-owned = a scheduled merge conflict).

## Anti-placeholder

Never ship a plan containing: `TBD` / `TODO` / "implement later" · "add appropriate error handling / validation / edge cases" without naming them · "write tests" without type, assertion, and command · "similar to Task N" (repeat the shape — tasks are read out of order) · steps with no file path · symbols defined in no task and absent from the codebase. Fix inline before `implement-plan`.

## Owner per task

Every task carries **Owner:** — the role the domain map in `templates/plan-template.md` assigns to the task's files (path first, then concern). `Owner: Lead` for R1/R2-sized work (≤2 files) or when the user said self-do; from R3 up the map decides. Reviewer roles are never owners: `qa-tester` = test plan depth; `security-engineer` on every touched high-risk surface (auth / billing / payments / credits / migration / data deletion / secrets / tokens / crypto / permissions / security) — both named in the task's Reviewer line. Brief each owner per §6, plus the spec.

## If no matching agent is available

Execute as Lead: read 2-3 nearby files → list paths → order smallest-reversible first → a test or evidence + command per task → simplest viable approach → flag every high-risk surface and contract change → sequential unless parallel is genuinely disjoint.

## Output

The plan template is the canonical artifact: `templates/plan-template.md` — fill every section; it is the contract `implement-plan` executes. A multi-agent plan adds `templates/cohesion-contract-template.md`.

Tasks use `- [ ]` checkboxes so progress survives compaction. The file never absorbs build-time narrative: status is the checkbox; a deviation is one line under `## Changes during build`.

One-session work → inline in chat. Multi-session → `docs/rolepod/plans/<feature>-YYYY-MM-DD.md`; re-planning never overwrites — a new dated file, `-v2` only when the date is the same (the diff between versions is the record). **`docs/rolepod/` is private by default:** before the first save run `grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore` — a repo that deliberately tracks its working docs creates `.rolepod/docs-tracked`.

More than one person or machine builds the plan → tasks can also publish to the repo's issue tracker (claim by assignee, frontier visible): `references/team-issues.md`. Solo work never needs it.

Harness plan mode active (a read-only planning state with its own approval gate) → present the plan through that gate and defer every disk write until it approves; do not fight the block — it is the same boundary as Iron Rule 1.

## References

Load only when needed:
- `references/plan-reviewer-prompt.md` — independent plan reviewer prompt for a risky or large plan (Agent tool, subagent_type=universal-reviewer).
- `references/advisory-routing.md` — cross-CLI advisory panel for high-stakes decisions; the advisory mirror of review-code's external review.
- `references/team-issues.md` — optional GitHub Issues backend for team-built plans.
- `examples/plan-examples.md` — a sequential single-owner plan and a parallel multi-agent plan, good/bad pairs.

## Hard stops

- A task names a file you have not read → read it.
- A task touches a high-risk surface without a test plan → add it.
- Two parallel agents need the same file → sequential or rewrite the contract, then re-run `plan-lint.sh <plan> <contract>`.
- The plan references a symbol that does not exist → verify or remove.

## Next phase

- `implement-plan` with the plan artifact.
- If `implement-plan` is not available, hand the plan to whoever will edit — file list, ordered tasks, per-task tests, done criteria are enough.
