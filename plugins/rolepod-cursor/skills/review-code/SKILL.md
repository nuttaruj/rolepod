---
name: review-code
description: Use before merging or shipping — review code with risk-appropriate adversarial pressure across correctness, security, performance, UI, and architecture. Pick reviewer by risk profile.
---

# Review Code

A finished diff → a severity-ordered review report, adversarial pressure matched to risk.

## Skip when

- R1 (trivial edit): ≤ 5 lines, one file, zero logic (user-facing string text counts as zero off high-risk paths), NOT high-risk. The edit tool's echo is the evidence; no re-read turn.
- Docs-only at any size (pure docs / typo / whitespace): its own check (link check / static lint) is the verify; no reviewer of any kind.
- The user explicitly accepts the change unreviewed.

### 1. Freeze the diff

- The diff: the R4 task, or for R2/R3 the plan's combined range — `<plan's first task commit>^..HEAD` (find that commit with `git log --oneline`). Committed → `<base>...HEAD`; uncommitted → `git diff HEAD` (staged + unstaged; `--cached` alone is a slice).
- Past ~15 files / ~800 lines it is two concerns: split into ship groups, one review each.
- Gather the spec / plan / acceptance criteria, the touched files end-to-end, and the risk profile (high-risk surface? new dependency? schema change?).

Done when: the range is named and every input is in hand.

### 2. Pick reviewers

High-risk surface = auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security.

| Risk profile | Reviewer |
|--------------|----------|
| High-risk surface | `security-engineer` + adversarial fresh-context |
| Correctness / spec compliance; generic quality / DRY / smell | `universal-reviewer` (spec; standards) |
| Performance regression risk | `performance-engineer` |
| UI / interaction / a11y | `ui-ux-designer` |
| Architecture / cross-module | `system-architect` |

By rigor tier (R1 trivial edit · R2 one file + test · R3 multi-file · R4 high-risk):
- **R2** → TWO read-only `universal-reviewer` lenses in ONE message, `lens: spec` + `lens: standards` (no spec → standards only); a matched row (perf / UI / arch) → that role instead. The writer's unit tests are the floor.
- **R3** → the matched row, internal, unless the pool's tier is R2 or R3 → a usable external replaces `universal-reviewer`.
- **R4** → `security-engineer` + ONE general strong pass: the external (`cross-family` kind review) when the pool is usable, else — or no `cross-family` — `universal-reviewer` on a strong-class model (never a balanced one), the reason on the Cross-model line. Never both on round 1, money and auth included. A comment/blank-only R4 diff → ONE internal strong reviewer, no external.
- Adversarial fresh-context = the reviewer reads only the artifact + acceptance criteria, tries to make the change fail, and hunts for what is missing as hard as for what is present. Adversarial = round 1 of an R4 task only; every later round is the normal two-axis review (Fix-verify rounds).
- A high-risk path anywhere in the diff (task or ship group) makes it R4; the commission's tier (max over its tasks) governs Define / Plan only.
- A diff reviewed at its tier is never reviewed again at ship: R2/R3 combine once per plan (`implement-plan` Review), naming R4 tasks as already reviewed.
- User-visible behaviour (UI / E2E flows) is no review row — `check-work` verifies it once per feature.

High-risk diff (adversarial mode, what counts), cross-family pool (any tier it sets), internal-pass or apex question → `references/external-review-routing.md`.

Brief every reviewer: diff + spec + acceptance criteria + risk profile + claimed behaviors to trace end-to-end + roles already run.
rolepod-brain → `brain_seed(task, agent: <reviewer id>)` verbatim; no tool → skip.

**One review round.** Dispatch every reviewer in ONE message on the same frozen diff; the round ends when the LAST one returns.
- Until then: no edit to a diff file, no `git stash / reset / checkout / add / commit` (a red-proof revert runs in a throwaway worktree) — reviewers read the live tree.
- An empty or partial return (`""`, one sentence, a turn-limit notice) is a failed reviewer: resume it or re-dispatch narrower; the round stays open, the report records a LIMITATION.
- Merge severity-ordered, deduped by file:line + root cause (the Lead's findings included; severity words per the template). The Lead spot-checks ONE finding, never re-walks a traced report.

No subagents, or a report missing / failed / empty → the Lead walks every Axes item cold, recorded as a LIMITATION; on a high-risk diff only when no dispatch is possible at all. The user forbade agents → surface the conflict; never self-set a bypass.

Done when: every dispatched reviewer has returned a full report and its findings are merged.

### 3. Axes

- **Depth** — R4: every axis, Trace in full. An R2/R3 lens: the diff + direct callers of what it changes; other axes that far only. Skip what tooling enforces (lint, formatter, typecheck, the commit gate). Never re-run the suite (the ship gate runs it once). A finding that needs a run: a reviewer with a shell runs only the diff's repro command; one without names it under Questions, and the task owner (else the Lead) runs it.
- **Intent** — first: the goal in one sentence; a smaller way, or should the change exist at all?
- **Trace** — the diff is the entry, not the scope: walk each claimed behavior (entry → call sites → branches → state → exit) through the seams into unchanged code; a surprise is a finding signal. Untouched code past the claims and seams is a Question, not a BLOCKER. Code-intel callers / impact when connected.
- **Correctness** — logic vs spec, edge cases, off-by-one, null / undefined / empty.
- **Security** — input validation, auth check, secrets, SSRF, injection, token leak in logs.
- **Performance** — N+1, blocking calls, unbounded loops, big payloads, missing index.
- **Architecture** — existing patterns? source-of-truth violations? a one-user abstraction? hand-rolled logic the stdlib or platform ships (native input, CSS, DB constraint, `Intl.*`)? A simplification finding names the replacement. A declared module boundary map (CLAUDE.md / ADR) → check every NEW cross-module import; a dependency-direction reversal or undeclared crossing is a BLOCKER.
- **Conventions** — a broken written rule (CLAUDE.md, lint / formatter config) = a MAJOR citing its line; an unwritten preference = a MINOR at most.
- **UI** — a11y, hierarchy, consistency, platform conventions.
- **Tests** — assertion strength, mocks at the right boundary, races for concurrent code. *Modifying an existing test* on the way to green is a finding until justified (loosened assertion, raised tolerance, deleted case, skip / only, absorbed snapshot). N call-site tests of one shared rule → one at the owner + at most one smoke per call site with wiring of its own. A new test naming a calendar date or the real clock → derive from one frozen now.

Done when: every axis the depth rule requires has run and each claim is traced to where it held or failed.

### 4. Report

Fill `templates/review-report.md`: Scope, Read, Risk surfaces touched, Reviewers (with its Cross-model adversarial pass line), Findings (BLOCKER / MAJOR / MINOR), Questions, Tests reviewed, Recommendation.
- Each finding: file:line, the issue, why it matters, a fix direction — the author writes the fix.
- A pre-existing issue on a path the diff does not touch → one note line, never a verdict driver.
- A clean review names what was read and the lenses run — never a bare APPROVED.
- Full report → `.rolepod/evidence/review/<task>-<role>.md`; the reviewer returns ≤ 12 lines + verdict.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo.
Review line: `{"ts":"<iso8601>","phase":"review","verdict":"<APPROVED|APPROVED-WITH-NITS|REJECTED>","blockers":<n>}`.

Done when: the report carries a Recommendation and the review line is appended.

### 5. Fix-verify rounds

- Round 1 = every axis in ONE message, ≤ 40 tool calls per reviewer.
- Round 2+ = a BLOCKER / MAJOR fix only, always internal and never adversarial: a normal re-check of the fix delta against the spec / acceptance criteria at the reviewer's own lens (`universal-reviewer`: two axes, spec compliance + standards; `security-engineer`: its security lens, confined to the finding's class), ≤ 15 tool calls, findings + delta only (no suite re-run, new mutant or new axis).
- `security-engineer` re-checks its own findings and the external's findings on a high-risk path; the external's other findings go to `universal-reviewer` on a strong-class model — never a new external round.
- A new issue found in round 2+ is a normal finding: fix it like any other (Author response).
- The flagging reviewer (for the external's findings, the round 2+ reviewer above) verifies a BLOCKER / MAJOR fix (the Lead's cold read only when it cannot run); the fix's writer never does. MINOR / NIT → the author's Command.
- A Lead-built fix → one read-only `universal-reviewer` pass (R4 → the strong pass).

Done when: every BLOCKER / MAJOR is closed by its round 2+ reviewer.

### 6. Author response

On the whole round's merged findings, never the first report: READ all without reacting → VERIFY each against the codebase (never implement an unverified one) → RESPOND with a technical ack or reasoned pushback. Clarify every unclear finding before touching anything linked to it. IMPLEMENT by provenance:
- introduced by this diff → fix now, blocking → simple → complex, testing each;
- pre-existing on a path this diff changes → fix only when it makes THIS change wrong; else a user decision (money / auth) or `## Follow-ups`;
- pre-existing on an untouched path → `## Follow-ups`, never this round.

Reply "Fixed in <file:line>." — no gratitude. A test added to close a finding joins the fix delta for the next reviewer; the author's own green run closes nothing.
Pushback, YAGNI, disagreement on merits, PR thread replies, rolepod-brain notes → `references/receiving-findings.md`.

Done when: every finding is fixed, pushed back with a reason, or in `## Follow-ups`, and each BLOCKER / MAJOR fix is back with its round 2+ reviewer.

## Guardrails

- A high-risk diff gets an adversarial fresh-context review; never merge one without it (none yet → `security-engineer` first).
- A fresh reviewer is the final judge; never the author, a Lead-built fix included.
- Evidence is the axis walk; never "tests pass" alone — tests prove the assertion, not the design.

Good / bad finding shapes → `examples/finding-examples.md`.

## Next phase

- Review-only ask (no fix, no ship) → none; the report is the deliverable.
- Findings need fixes → `implement-plan` or `debug-issue`; fixes landed → `check-work`. Neither available → the Lead fixes per Author response, then its round 2+ reviewer re-checks (Fix-verify rounds).
- No blockers, plan has unchecked tasks → `implement-plan` (Ship asks once per plan); plan exhausted → `finish-work` for the merge gate.
- If `finish-work` is not available, present the findings + recommendation and ask the user which finish path to take.
