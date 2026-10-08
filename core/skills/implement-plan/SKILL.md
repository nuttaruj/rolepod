---
name: implement-plan
description: The owner's build procedure — build one task from its brief, inline checklist or R1 edit, prove it, order its review, return the receipt. Use when you are dispatched to build a task.
---

# Implement Plan

The owner's Build: a brief, an inline checklist or an R1 edit → a built, proven, reviewed diff and its receipt.
A task in progress → resume Build at that task; never restart Define or Plan.
You never stop to ask: a question only the user can answer → `BLOCKED: <the one question>` with your checks and attempts; the Lead asks.
Paths are relative to this skill's folder (a named skill: `../<name>/SKILL.md`); no skill tool → Read it; no folder known (an inline copy) → each step's own fallback.

## Skip when

- A question only.
- You are the Lead running a plan → `orchestrating-plans`.
- The brief names a missing file, or contradicts itself or the codebase → `BLOCKED` with `SPEC CONFLICT: <line> vs <observed>`; never build to the broken line.
- A failure's root cause is unknown → `debug-issue` (none → step 3's fallback).

### 1. Read the brief

- The brief (or an inline chat checklist: no file, no lint, each step names its verify command) is your whole slice; never open the plan file.
- Read every touched file end to end, match 2-3 nearby files (invent no pattern), confirm every symbol the brief expects exists.
- A brief line or plan rule saying "ask the user" → `BLOCKED` naming the question.

Done when: you can name the files, the Test / evidence line and the Command.

### 2. Build

- The Test / evidence line picks the discipline. Logic, a test at a seam, or no such line → `tdd-flow` at the agreed seam (spec's Testing decisions, else the brief's, else the highest existing one; state `Seam: <interface>`); no `tdd-flow` → one behavior, one failing test, the smallest change to green, then the next; edge / error / race only with a criterion or an R4 floor; mock only external boundaries.
- Prose, a rename, config, wiring or CRUD pass-through with no rule of its own → evidence-after: change, then run the proof the line names; no new test.
- Reuse first: codebase → stdlib → platform feature → installed dependency → minimal new code; a new dependency the brief does not name → `BLOCKED` naming it.
- A behavior, signature or return shape with callers changes → walk the callers first (code-intel or grep); per caller: absorb, adapt or split.
- Edit through the edit tool, never a shell heredoc, `sed -i` or `tee`. A comment only for a non-obvious why.
- A sibling plugin covers the domain → `references/sibling-plugins.md`, else its installed edit primitive. A human-only step → `references/wizard.md`, else `BLOCKED` naming it.

Done when: the change matches the brief and its test or proof exists.

### 3. Prove

- Completion check: re-read each changed file; run test / lint / typecheck; no silent failure (a DB column needs its migration, an API field its schema and response). No shell tool → each check as `RUN NEEDED: <command>`, never marked passed.
- After each relevant edit: the narrowest check covering the change and its consumers (one test, or one section of a large test file via the repo's filter; a whole file only under ~30 s).
- Before returning: the brief's Command once, verbatim, or a cited green run whose scope, inputs, environment and provenance still match after the last relevant edit (HEAD equality alone is not enough); a phase change adds no check. Then the commit check once, never per fix round.
- A failure → those tests once on the base tree (a throwaway `git worktree` at the base sha, else the diff set aside, then restored): red there too → pre-existing, cited in Concerns, never a block on `COMPLETED` when the rest is green; green → yours to fix.
- A failing command → the task's **On fail**, else the plan's **Failure policy**, else `debug-issue` (none → reproduce, test one hypothesis at a time, fix at the root); at most two retries, then `BLOCKED` with the attempts.

Before you call it done, the five gates:

{{INCLUDE: core/fragments/gates-f1-f5.md}}

Done when: the Command is green (or red only on a cited pre-existing failure) and the commit check ran.

### 4. Order the review

- Round-1 set: the brief's Reviewers (or `Review:`) line; `none` → no in-task review (the track end covers it); no line → `../write-plan/scripts/plan-lint.sh --review-set --tier <the brief's tier> --mode <its Workflow mode>`.
- A set → freeze: `scripts/ticket.sh review-diff start <task> -- <the brief's Files and each Also touched path>` prints the diff file and H1 for `convening-code-review` step 1 (no script → `git add -A -- <those paths>`, the staged `-U10` diff into `.rolepod/evidence/review/<task>.diff`, H1 = `git write-tree`); `convening-code-review` then orders the round and runs Fix-verify.
- No `convening-code-review` → the whole set (a `rolepod-reviewer` per lens; no custom role but sub-agents → a default sub-agent given `review-code`) in ONE message on that diff, each writing `.rolepod/evidence/review/<task>-<lens>.md`; fix after every report; one fresh reviewer re-checks the fix delta, ≤ 4 rounds. No set and no script → two lenses, plus on R4 `lens: security` (`depth: checklist` in Standard; `depth: full` and one adversarial pass in Full).
- Fix the findings, re-run the checks covering the fix. Cannot dispatch a reviewer → return the diff unreviewed with `REVIEW NEEDED: <set>`; you cannot self-approve.

Done when: every round-1 report is in and each BLOCKER / MAJOR is fixed or pushed back, or `REVIEW NEEDED` is named.

### 5. Return

- Fill the skeleton `ticket.sh start` wrote at the absolute base receipt the brief names (`docs/rolepod/tasks/<plan>/task-NN.md`; none → `## Decision brief`, `## Verify status`, `## Handoff`, `## Reviews`); `## Lead notes` is the Lead's.
- Owner status (`COMPLETED | PARTIAL | BLOCKED`) and Verify status (`VERIFIED | PARTIAL | UNVERIFIED`) stay distinct; never `COMPLETED` over a failing or unrun Command.
- The receipt also holds the diff stat, reviewer verdicts, each pushed-back BLOCKER / MAJOR as `file:line` + one-line reason, `Assuming:` lines and actionable residuals. Handoff: at most ~15 lines, only what a Blocked-by task consumes (signatures, invariants).
- Pointers resolve after integration and worktree removal: proof complete at base needs no export; required local-only proof stays at its named private path through cleanup. Name a rerunnable command, never paste its log.
- Chat reply ≤ 12 lines: owner status, receipt path, Command tail, reviewer verdicts + report paths, residuals; no preamble, restatement, reading history, closing recap, copied report findings or detail the receipt holds. No file-writing tool → the whole receipt inline, naming the limitation; never claim an unwritten path.

Done when: the receipt is written and the reply sent.

## Guardrails

- Touch only the task: no "while I'm here" refactor, reformatting or single-use abstraction; adjacent dead code → flag it, delete nothing unasked.
- A needed path nobody owns → edit it, plus one `Also touched: <path>` line; a path another owner holds → `NEEDS: <path> — <one-line change>`, never an edit.
- Never commit, push or stash; the Lead integrates.
- Before you build: a migration, deploy, release or signing step states its rollback first, else BLOCKED.
- Before you return: a UI change you cannot observe → the receipt says 'not observed'; the QA pass observes it.
- A new idea → one receipt Scope check line (the Lead building R1 itself → one plan `## Follow-ups` line); never a mid-build redesign.

## Next phase

- A built diff, Command green → step 4. Reviewed, receipt written → return to your caller; the Lead's own R1 build → `orchestrating-plans` at the plan's next step.
- Not available → `review-code` on the diff.
- No other skill → stop and tell the user what changed, was verified and is still unverified or unreviewed, with the receipt path and each failing Command tail quoted.
