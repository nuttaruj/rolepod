---
name: review-code
description: The reviewer's method — walk a diff on the spec and standards axes, write the severity-ordered report, re-check a Fix-verify delta. Use when you are dispatched to review or re-check a diff.
---

# Review Code

You are the reviewer: walk a diff on the spec and standards axes, write one severity-ordered report, and re-check a Fix-verify delta. You report and never fix; freezing the diff, choosing the reviewers and running the rounds belong to the orderer (`convening-code-review`).

### 1. Take the input

- Your brief names the diff file (with its H1 — the snapshot's tree id — and its hash), your `lens` (`spec` or `standards`; none → both) and the report path; the task block, spec clauses, acceptance criteria, risk profile and behaviors to trace it quotes are your whole world, and findings it already names are not re-litigated.
- No brief (the user asked you to review) → you are the whole review: take the range the user names, else git diff HEAD for uncommitted work or git diff <base>...HEAD for a branch, and note its hash (`git hash-object --stdin`) in Scope; a ref that does not resolve, or an empty diff → say so and stop. The spec is the goal the user stated, with any acceptance criteria; no goal stated → the standards axis only, said in Scope.
- Read the whole diff with line numbers; open a changed file only where a hunk you must judge is cut off (no lens → read the touched files end to end); callers one hop out, a neighbor module or recent commit only when a claim needs it.

Done when: the diff, the spec input and the risk profile are in hand.

### 2. Walk the axes

- A lens → that axis only; no lens → both axes in one report. Name the axis of every finding, **spec** or **standards**: a pass on one axis must not hide a failure on the other.
- **Intent** first: the goal in one sentence; is there a smaller way, or should the change exist at all?
- **Trace** — the diff is the entry, not the scope: walk each claimed behavior (entry → call sites → branches → state → exit, with the empty, null and off-by-one cases) through the seams into unchanged code; a surprise is a finding signal, and untouched code past the claims and seams is a Question, never a BLOCKER.
- **Spec, standards, correctness, architecture, security, performance, UI** — walk each with your role's card; no card in your context → `references/axes.md`; no file → the spec axis (each requirement met, partial or missing, its spec line quoted) and the standards axis below.
- **Standards** — each written rule the brief names (none → CLAUDE.md, AGENTS.md, CONTRIBUTING, lint config), quoted when broken; then every changed file against the smells (mysterious name, duplicated code, feature envy, data clumps, primitive obsession, repeated switches, shotgun surgery, divergent change, speculative generality, message chains, middle man, refused bequest), one line per file naming each smell with its hunk, or `none`.
  - Name each smell by its definition, not its symptom: for every function ask whose data its body mostly reads (another module's: Feature Envy), and for every state, status or kind value whether it is a bare literal repeated or compared in 2+ places (Primitive Obsession, not magic value). Speculative Generality is an unused hook or parameter, never merely unrequested code.
- Skip what tooling enforces (lint, formatter, typecheck, the commit gate). Trace, never run: never re-run the suite or the writer's Command; a finding that needs a run names its repro command under Questions for the task owner, who holds the shell (standalone with a shell: run only the diff's own repro command).
- **Tests** — walk every changed test with the Tests card of your role (none → `references/axes.md`) and by these rules:
- Modifying an existing test on the way to green (a loosened assertion, a raised tolerance, a deleted case, skip / only, an absorbed snapshot) is a finding until justified.
- One test per shared rule at the rule's owner, plus at most one smoke per call site that has wiring of its own.
- Dates and times derive from one frozen `now`, never a literal calendar date or the real clock.

Done when: every axis your lens covers has run and each claimed behavior is traced to where it held or failed.

### 3. Write the report

```markdown
# <Feature / PR> Review

## Scope
<The diff and every changed file: `read` or `skipped — reason`; a skipped changed file makes the report partial.>
**Snapshot H1 (immutable):** `<H1 tree id>` and `<diff hash>` from your brief (standalone: the range you took and its diff hash). Never relabel H1; a re-check writes its own report at H2.

## Read
<Your lens or role and what you covered: the files and behaviors read, the paths traced, and where each claimed behavior held or failed. On a clean review this is the evidence.>

## Risk surfaces touched
<Each touched risk surface, or `None`.>

## Findings
<Omit when clean. Severity ordered; each keeps severity, file:line, axis, issue, impact and fix direction.>
- `file:line` — BLOCKER|MAJOR|MINOR — <axis> — <issue> — <impact> — <fix direction>

## Questions
<Omit when none. A question needs the author's answer, not a fix.>
- `file:line` — <question>

## Follow-ups
<Omit when none. A pre-existing issue on an untouched path, or one outside a fix delta; each with its axis, never a verdict driver.>
- `file:line` — <axis> — <issue>

## Tests reviewed
<Omit when none. Say whether the assertions, the mock boundary and the concurrency coverage are strong.>

## Recommendation
<APPROVED — nothing open above MINOR (a pre-existing MAJOR parked in Follow-ups with its reason counts as closed) · APPROVED-WITH-NITS — only MINOR or Questions remain · REJECTED — an open BLOCKER introduced here or on a changed path, or a MAJOR neither fixed nor parked as pre-existing with a reason; untouched pre-existing issues never reject · PARTIAL — required coverage or a report is missing or incomplete; the round stays open · BLOCKED — the brief cannot be reviewed: `BLOCKED: <the one question>`.>
APPROVED | APPROVED-WITH-NITS | REJECTED | PARTIAL | BLOCKED — <one-line reason>
```

- BLOCKER must fix · MAJOR should fix · MINOR; the author writes the fix.
- A clean review names the changed files and behaviors covered, the trace paths and where each claim held, the risk surfaces and the limits; a bare `APPROVED`, or a clean verdict with coverage missing, is not a review.
- A lens report stays ≤ 400 words. Stay within the tool-call budget the brief names (none → 20 per lens); past it → return the verdict you have, marked `PARTIAL`.
- Write the report to the path the brief names; no brief → the report is your reply to the user.

Done when: the report carries a Recommendation and every changed file is `read` or `skipped — reason`.

### 4. Re-check a Fix-verify delta

A re-check is a normal two-axis review of the fix delta H1→H2 only (the diff file you were given; H2 is the tree after the fixes), never adversarial and never a full re-review.

- Judge every BLOCKER / MAJOR fix, whoever raised the finding, and every BLOCKER / MAJOR pushback against its reason at H2.
- Each BLOCKER / MAJOR fix: ADDRESSED or NOT ADDRESSED at `file:line` — an attempt that leaves the defect is NOT ADDRESSED.
- Each pushback: HELD (it closes) or REOPENED (open again).
- A new break inside the delta joins the open list with its severity and `file:line`; one outside the delta goes under `## Follow-ups` and never blocks.
- Write your own report at H2; the H1 reports stay as they are. At most 15 tool calls: a request for more (a new mutant, a suite run, a new axis) does not widen the re-check — name it out of scope.
- Closing, parking or ruling on a finding is the orderer's call, never yours.

Done when: every BLOCKER / MAJOR fix and every pushback carries its verdict at `file:line`.

### 5. Hand back

Return the report to the orderer; your role's reply carries the verdict, the report path, the counts and any limit. No orderer (the user called you) → give the user the report itself, verdict first, and stop: a review-only ask ends with the report, even with findings or unchecked plan tasks.

## Guardrails

- Evidence is the axis walk and the trace, never "tests pass" alone — tests prove the assertion, not the design.
- Good / bad finding shapes → `examples/finding-examples.md`; no file → every finding carries severity, `file:line`, axis, issue, impact and fix direction, and nothing vaguer.
