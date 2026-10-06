---
name: implement-plan
description: The owner's build procedure — build one task from its brief, an inline checklist or an R1 edit, prove it, order its review, return the receipt. Use when you are dispatched to build a task.
---

# Implement Plan

The owner's Build: a brief, an inline checklist or an R1 edit → a built, proven, reviewed diff and its receipt.
A task in progress → resume Build at that task; never restart Define or Plan.
You never stop to ask: a question only the user can answer → return `BLOCKED: <the one question>` with what you checked and your attempts; the Lead asks.

## Skip when

- A question only.
- You are the Lead running a plan → `orchestrating-plans`.
- The brief names a missing file, or contradicts itself or the codebase → return `BLOCKED` with `SPEC CONFLICT: <line> vs <observed>`; never build to the broken line.
- The root cause of a failure is unknown → `debug-issue`.

### 1. Read the brief

- The brief is your whole slice; never open the plan file. An inline chat checklist has no file and no lint: it is the brief, and each step names its verify command.
- Read every touched file end to end, match 2-3 nearby files (invent no pattern), and confirm every symbol the brief expects exists.
- A brief line or plan rule that says "ask the user" → return `BLOCKED` naming the question.

Done when: you can name the files, the Test / evidence line and the Command.

### 2. Build

- The Test / evidence line picks the discipline. Logic, a test at a seam, or no such line → `tdd-flow` at the agreed seam (the spec's Testing decisions, else the brief's seam, else the highest existing seam, stated `Seam: <interface>`). No `tdd-flow` → one behavior, one failing test, the smallest change to green, then the next; edge / error / race only with a criterion or an R4 floor; mock only external boundaries.
- Prose, a rename, config, wiring or CRUD pass-through with no rule of its own → evidence-after: make the change, then run the proof the line names; no new test.
- Reuse first: codebase → stdlib → platform feature → installed dependency → minimal new code. A new dependency the brief does not name → `BLOCKED` naming it.
- Changing a behavior, signature or return shape with callers → walk the callers first (code-intel or grep) and decide per caller: absorb, adapt or split.
- Change files through the edit tool, never a shell heredoc, `sed -i` or `tee`. A comment only for a non-obvious why.
- Scratch output (a captured run, a count) → a `mktemp` file or `.rolepod/evidence/`, never a path outside the repo: a write there can wait on a prompt nobody sees.
- A sibling plugin covers the domain → `references/sibling-plugins.md`; no reference → its edit primitive when installed. A step only a human can perform → `references/wizard.md`; no reference → `BLOCKED` naming that step.

Done when: the change matches the brief and its test or proof exists.

### 3. Prove

- Completion check: read each file you claim you changed; run test / lint / typecheck; no silent failure (a DB column needs its migration, an API field needs its schema and response). No shell tool → name each check as `RUN NEEDED: <command>`, never marked passed.
- After each relevant edit, the narrowest check covering the changed behavior and its consumers: one test, or one section of a large test file through the repo's own filter (a whole file only under ~30 s).
- Before returning: the brief's Command once, verbatim, or a cited passing run whose scope, relevant inputs, environment and provenance still match after the final relevant edit (HEAD equality alone is not enough); a phase change adds no check. Then the repo commit check once, never per fix round. The whole suite is the Lead's, once per release.
- A failure → run just those tests once on the base tree (a throwaway `git worktree` at the base sha; else set the diff aside in place, run, restore). Red there too → pre-existing: a limitation cited in Concerns, never a block on `COMPLETED` when the rest is green. Green there → yours to fix.
- A failing command → the task's **On fail**, else the plan's **Failure policy**, else `debug-issue`; retry it at most twice, then return `BLOCKED` with the attempts.

Before you call it done, the five gates:

{{INCLUDE: core/fragments/gates-f1-f5.md}}

Done when: the Command is green (or red only on a cited pre-existing failure) and the commit check ran.

### 4. Order the review

- The round-1 set is the brief's Reviewers (or `Review:`) line; `none` → no in-task review (the track end covers it); no such line → `../write-plan/scripts/plan-lint.sh --review-set --tier <the brief's tier> --mode <its Workflow mode>`.
- A set → freeze first: `scripts/ticket.sh review-diff start <task> -- <the brief's Files and each Also touched path>`; the diff file and H1 it prints are `convening-code-review` step 1's input. Then `convening-code-review` orders the round and runs Fix-verify.
- No `convening-code-review` → dispatch the whole set in ONE message on that frozen diff, each reviewer writing `.rolepod/evidence/review/<task>-<lens|role>.md`; fix only after every report is in; one fresh `universal-reviewer` re-checks only the fix delta, at most four rounds. No set and no script → the two `universal-reviewer` lenses, plus on R4 `security-engineer` (`depth: checklist` in Standard; `depth: full` and one adversarial pass in Full).
- Fix the findings, then re-run the checks covering the fix. Cannot dispatch a reviewer → return the diff unreviewed with `REVIEW NEEDED: <set>`; you cannot self-approve.

Done when: every round-1 report is in and each BLOCKER / MAJOR is fixed or pushed back, or `REVIEW NEEDED` is named.

### 5. Return

- Write the decision brief to the absolute base receipt the brief names (`docs/rolepod/tasks/<plan>/task-NN.md`; `ticket.sh start` writes its skeleton): `## Decision brief` (Change, Tests added / changed, Commands, Scope check, Concerns, Author fix closure, Owner status), `## Verify status`, `## Handoff`, `## Reviews`. `## Lead notes` is the Lead's.
- Owner status (`COMPLETED | PARTIAL | BLOCKED`) and Verify status (`VERIFIED | PARTIAL | UNVERIFIED`) stay distinct. Never `COMPLETED` over a failing or unrun Command.
- The receipt holds the diff stat, the Command tail and proof lines, reviewer verdicts + report paths, each pushed-back BLOCKER / MAJOR as `file:line` + one-line reason, `Assuming:` lines and actionable residuals. Handoff: at most ~15 lines, only what a Blocked-by task consumes (signatures, invariants).
- Pointers resolve after integration and worktree removal: proof complete at base needs no export; keep required local-only proof at its named private path before cleanup. Name a command instead of pasting a rerunnable log.
- The chat reply stays within 12 lines: owner status, receipt path, Command tail, reviewer verdicts + report paths, residuals; never copy findings from a report. No file-writing tool → the whole receipt inline, naming the limitation; never claim an unwritten path.

Done when: the receipt is written and the reply sent.

## Guardrails

- Touch only the task: no "while I'm here" refactor, no reformatting, no single-use abstraction; adjacent dead code → flag it, delete nothing unasked.
- A path the task needs that nobody owns → edit it, plus one `Also touched: <path>` line; a path another owner holds → `NEEDS: <path> — <one-line change>`, never an edit.
- Never commit, push or stash; the Lead integrates.
- A new idea → one line in the receipt's Scope check (the Lead building R1 itself → one plan `## Follow-ups` line); never a mid-build redesign.

## Next phase

- A built diff, Command green → `convening-code-review` (step 4): a `universal-reviewer` role per lens; no custom role but sub-agents → a default sub-agent per lens given `review-code`; cannot dispatch → return the diff with `REVIEW NEEDED: <set>`.
- Reviewed, receipt written → return to your caller; the Lead's own R1 build → `orchestrating-plans` at the plan's next step.
- Not available → `review-code` on the diff.
- No other skill → stop and tell the user what changed, what was verified and what is still unverified or unreviewed, with the receipt path and each failing Command tail quoted.
