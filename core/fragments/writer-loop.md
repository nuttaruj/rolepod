## Writer loop

For task owners — skip the whole block when the brief is report-only.

- **Completion check** — Grep/Read each file you claim you changed; run
  test / lint / typecheck; confirm no silent failure (a DB column needs its
  migration, an API field needs schema + response). Never report COMPLETED
  with a failing or unrun check.
- **Autonomous errors** — never blind-edit; on a failing command analyze,
  retry at most twice, then escalate.
- **Ticket loop** — Writers: build test-first at the brief's seam; after each edit run only the checks covering the file just edited (its case section on a slow file); the brief's full Command runs ONCE, last before returning, then the repo commit check once — never per fix round. Stay inside the brief's Files and Change: no side harness a case can hold, no fix beyond a finding; a residual goes into the brief. A brief with no Reviewers line (a check-work Verify run, a debug hand-off, an ad-hoc task) → no reviewer dispatch; return the shape your Return section names. Reviewers `none` (an R2/R3 task in a plan) → return with no reviewer; the Lead reviews the plan once before release. A standalone R2 brief → dispatch the two lenses yourself with the diff as a file (`git diff > .rolepod/evidence/review/<task>.diff`): a reviewer has no shell. Otherwise (R4) → dispatch `universal-reviewer` (read-only, two axes; or the concern-matched row; the external CLI instead when the brief's Reviewers line names one) — plus `security-engineer` on a high-risk path — in ONE message, the diff as a file; each writes its report to `.rolepod/evidence/review/<task>-<role>.md`; a detached external running → fix the internal findings first, then collect it. Fix, re-run the checks covering the fix.
  - A logic slice → call the `tdd-flow` skill; no Skill tool → test-first at the brief's seam: one behavior, one failing test, the smallest code that passes, then the next behavior.
  - Round 2 only for a BLOCKER / MAJOR fix, internal and non-adversarial: the reviewer who flagged it re-checks that finding on the delta (a read-only reviewer re-traces; one with a shell re-runs its repro); an external's finding goes to `security-engineer` on a high-risk path, else to strong `universal-reviewer` — never a new external round; a new issue it finds is a normal finding to fix.
  - A plan task returns the **decision brief**: diff stat, Command tail, reviewer verdicts + report paths, residuals. No dispatch tool → add `REVIEW NEEDED: <what to check>` instead — Lead runs review after you return. Cannot self-approve; never commit.
