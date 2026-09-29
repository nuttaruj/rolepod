## Writer loop

For task owners — skip the whole block when the brief is report-only.
A report-only brief (you are the reviewer for your `review-code` row, or an audit) → edit no file but the report; each Hard stop becomes a finding for the author — never a fix, a measurement of your own or a `BLOCKED`. A `review-code` brief → fill its report template (Skill tool; none → findings at `file:line`, BLOCKER / MAJOR / MINOR, fix direction) into the named report file, and return its verdict first (`APPROVED | APPROVED-WITH-NITS | REJECTED`), then the report path and ≤ 12 lines — not your Return section's build shape.

- **Completion check** — Grep/Read each file you claim you changed; run
  test / lint / typecheck; confirm no silent failure (a DB column needs its
  migration, an API field needs schema + response). Never report COMPLETED
  with a failing or unrun check; no shell tool → name each check for the
  Lead to run (`RUN NEEDED: <command>`) and never mark it passed.
- **Autonomous errors** — on a failing command, analyze and retry at most
  twice, then escalate.
- **Nothing left running** — a command your tool moved to the background
  (it outran its timeout) reports its end to nobody: stop it (TaskStop its
  id, or kill it) before you return, then re-run it in smaller pieces or
  return `RUN NEEDED: <command>` for the Lead.
- **Ticket loop** — Writers: build to the brief's Test / evidence line (next bullet); after each edit run only the checks covering the file just edited (its case section on a slow file); the brief's full Command runs ONCE, last before returning, then the repo commit check once — never per fix round. Stay inside the brief's Files allowed and Change: no side harness a case can hold, no fix beyond a finding; a residual goes into the brief.
  - The Test / evidence line picks the discipline. Test-first — a test at a seam, or no such line (an R2 checklist, a debug hand-off) → call the `tdd-flow` skill; no Skill tool → one behavior, one failing test at the brief's seam, the smallest code that passes, then the next behavior. Evidence-after — acceptance criteria plus a mechanical check (config, docs, a rename, wiring or CRUD pass-through with no rule of its own) → make the change, then run the proof the line names; no new test.
  - Scratch output (a captured run, a count) → a `mktemp` file or `.rolepod/evidence/`, never a path typed outside the repo: a write there can wait on a permission prompt a background owner never sees.
  - Reviewer dispatch — the first match wins; every reviewer gets the diff as a file, `git add -A && git diff --cached > .rolepod/evidence/review/<task>.diff` (staged, so new files count; leave it staged for the Lead), because a reviewer has no shell. Every dispatch is waited on: return your brief only after each child's report is in — a child's end wakes you (the Claude desktop app sends it to the Lead, which relays it), so end a turn only to wait for one, its last line `WAITING: <report paths>`; no `name`, fork or remote isolation (such a child reports to the Lead). No shell to write the diff, or no way to wait → `REVIEW NEEDED:` instead of a dispatch:
    - a `check-work` Verify run → no reviewer;
    - a high-risk path, or a Tier line naming R4 → the R4 round-1 set in ONE message: `security-engineer` + `universal-reviewer` `lens: spec` + `universal-reviewer` `lens: standards` (or the concern-matched row in the pair's place) + the adversarial pass the brief's Reviewers line names (the external CLI runner with `--adversarial`, else `universal-reviewer` `mode: adversarial` at strong class; pool usable → the external is the only adversarial pass, no internal `mode: adversarial` beside it; an external that fails or comes back weak, per `adversarial-review` What counts → the internal pass then);
      each writes its report to `.rolepod/evidence/review/<task>-<role>.md` — a lens `<task>-<lens>.md`, the internal adversarial pass `<task>-adversarial.md`; an external pass → its `--detach` first (it returns at once), then the internal reviewers, so both run together; a detached external running → fix the internal findings first, then collect it;
    - Reviewers `none` (an R2/R3 task nothing depends on, beside another such task) → no reviewer; a combined-review owner reviews the plan diff once before release;
    - a Reviewers line naming roles → those roles, in ONE message; each writes `.rolepod/evidence/review/<task>-<role>.md`, a lens `<task>-<lens>.md`;
    - any other brief (a standalone R2 checklist, a debug hand-off) → the two lenses yourself (`universal-reviewer` with `lens: spec` and `lens: standards`), in ONE message; each lens writes `.rolepod/evidence/review/<task>-<lens>.md`.
  - Fix the findings, re-run the checks covering the fix.
  - Round 2 only for a BLOCKER / MAJOR fix, internal and non-adversarial: the reviewer who flagged it re-checks that finding on the delta (a read-only reviewer re-traces; one with a shell re-runs its repro) — a fresh dispatch of that role, its report and the delta in the brief, never a message that resumes it (a resume runs in the background); an external's security-class finding (the class list is in `review-code` Fix-verify rounds) goes to `security-engineer`, its other findings to `universal-reviewer` — never a new external round; a new issue it finds is a normal finding to fix.
  - Return: a plan task returns the **decision brief** — diff stat, Command tail, reviewer verdicts + report paths, `Assuming:` lines, residuals; any other brief returns the shape your Return section names, with the reviewer verdicts + report paths appended. A reviewer is due and you have no dispatch tool → add `REVIEW NEEDED: <what to check>` — the Lead dispatches a fresh owner to run the review after you return. Cannot self-approve.
