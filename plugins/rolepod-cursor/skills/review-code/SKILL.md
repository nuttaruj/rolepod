---
name: review-code
description: Use before merging or shipping — review code with risk-appropriate adversarial pressure across correctness, security, performance, UI, and architecture. Pick reviewer by risk profile. Phase = Review.
---

# Review Code

Turns a finished diff into a severity-ordered review report, with adversarial pressure matched to its risk.

## Skip when

- R1 (trivial edit): ≤ 5 lines, a single file, zero logic, NOT high-risk. User-facing string text alone counts as zero logic off high-risk paths. The edit tool's echo is the evidence; no re-read turn.
- A docs-only diff, at any size: pure docs / typo / whitespace. Its own check (link check / static lint) is the verify; no reviewer, internal or external.
- The user explicitly accepts the change unreviewed.

### 1. Freeze the diff

- The diff is the R4 task under review, or for R2/R3 the plan's combined range (`rolepod-ticket log` prints it).
- Committed branch → `<base>...HEAD`. Uncommitted → `git diff HEAD` (staged + unstaged).
- `--cached` alone is a slice; the runner refuses one whose files carry uncovered tree edits (`--partial-ok` only on request).
- Past ~15 files / ~800 lines it is two concerns: split into ship groups, one review each.
- Gather the spec / plan / acceptance criteria, the touched files end-to-end, and the risk profile (high-risk surface? new dependency? schema change?).

Done when: the diff range is named and every input above is in hand.

### 2. Pick reviewers

High-risk surface = auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security.

| Risk profile | Reviewer |
|--------------|----------|
| High-risk surface | `security-engineer` + adversarial fresh-context |
| Correctness / spec compliance | `universal-reviewer` (spec axis) |
| User-visible behaviour (UI / E2E / API contract) | `qa-tester` (E2E) |
| Performance regression risk | `performance-engineer` |
| UI / interaction / a11y | `ui-ux-designer` |
| Architecture / cross-module | `system-architect` |
| Generic quality / DRY / smell | `universal-reviewer` |

By rigor tier (R1 trivial edit · R2 one file + test · R3 multi-file · R4 high-risk):
- **R2** → TWO read-only `universal-reviewer` lenses in ONE message: `lens: spec` and `lens: standards` (no spec → standards only). A matched row (perf / UI / arch) → that role instead. The writer's unit tests are the floor.
- **R3** → the matched row, internal. A cross-family pool set to `tier = R2|R3` → a usable external replaces `universal-reviewer` from that tier up, never both.
- **R4** → `security-engineer` + ONE general strong pass: the external when the pool is usable, else `universal-reviewer`. Never external + `universal-reviewer` on round 1, money and auth included. A comment/blank-only R4 diff → ONE internal strong reviewer, no external.
- A high-risk path anywhere in the diff (the task or its ship group) makes that diff R4. The commission's tier (the max over its tasks) governs Define / Plan only; review tiers each diff.
- A diff reviewed at its tier is never reviewed again at ship. R2/R3 tasks get one combined review over the plan diff (`implement-plan` Review); R4 stays per task, and the combined review names R4 tasks as already reviewed without re-walking them.
- `qa-tester` joins only for user-visible behaviour and is never the strong pass.

Dispatch the internal general pass (`universal-reviewer`) on a strong-class model, never a balanced one. An external runs on its own CLI's default model.
The cross-family pool is enabled, or an internal pass, apex or strong-class question comes up → `references/external-review-routing.md` (when the external is mandatory, detach and collect, the internal-pass conditions, apex escalation).

Brief every reviewer with: the diff + spec + acceptance criteria + risk profile + the claimed behaviors to trace end-to-end + which roles already ran.
rolepod-brain: add `brain_seed(task, agent: <reviewer id>)` verbatim; no tool → skip.

**One review round.** Dispatch every reviewer in ONE message on the same frozen diff. The round ends when the LAST reviewer returns (`rolepod-cross-family --collect` for a detached job).
- Until then the diff is frozen: no edit to a file it touches, no `git stash / reset / checkout / add / commit` (a red-proof revert runs in a throwaway worktree). Reviewers read the live tree, so one early fix voids every in-flight verdict.
- An empty or partial return is a failed reviewer, never a clean pass — a `""` answer, a one-sentence result, a turn-limit notice. Resume it or re-dispatch on a narrower brief; until it reports, the round stays open and the report records a LIMITATION.
- Merge the reports severity-ordered, deduped by file:line + root cause (the Lead's own findings included). Map vocabulary: CRITICAL/HIGH → BLOCKER, WARNING/MEDIUM → MAJOR, SUGGESTION/LOW → MINOR.
- The Lead never re-walks a traced report; it spot-checks ONE finding.

No subagents → the Lead walks every Axes item on the diff cold, and the report records the missing reviewer as a LIMITATION. The same holds when a reviewer's report is missing, failed or empty. The user forbade agents → surface the conflict; never self-set a bypass.

Done when: every dispatched reviewer has returned a full report and the findings are merged into one list.

### 3. Axes

- **Depth** — R4: every axis below, Trace in full. An R2/R3 lens: the diff and the direct callers of what it changes; the other axes only as far as that reach. Skip what tooling already enforces (lint, formatter, typecheck, the commit gate). Re-run the suite only when a finding needs it.
- **Intent** — the goal in one sentence; is there a smaller way, or should the change exist at all? Surface this before the line read.
- **Trace** — the diff is the entry point, not the scope. For each claimed behavior walk the real path (entry → call sites → branches → state → exit) through the seams into unchanged code; every surprise on the walk is a finding signal. Bound the walk to the change's claims and seams: untouched code is a Question, not a BLOCKER. Use code-intel callers / impact when connected.
- **Correctness** — logic vs spec, edge cases, off-by-one, null / undefined / empty.
- **Security** — input validation, auth check, secret handling, SSRF, injection, token leak in logs.
- **Performance** — N+1, blocking calls, unbounded loops, big payloads, missing index.
- **Architecture** — matches existing patterns? source-of-truth violations? a new abstraction with one user? hand-rolled logic the stdlib or platform already ships (native input, CSS, DB constraint, `Intl.*`)? A simplification finding names the concrete replacement. A declared module boundary map (CLAUDE.md / ADR) → check every NEW cross-module import; a dependency-direction reversal or an undeclared crossing is a BLOCKER.
- **Conventions** — a written project rule (CLAUDE.md, lint / formatter config) the diff breaks is a MAJOR, citing the rule's line; an unwritten preference is a MINOR at most.
- **UI** — a11y, hierarchy, consistency, platform conventions.
- **Tests** — assertion strength, mocks at the right boundary, race coverage for concurrent code. A diff that *modifies an existing test* on the way to green is a finding until justified (loosened assertion, raised tolerance, deleted case, skip / only, absorbed snapshot). N call-site tests of one shared rule → one at the owner plus a smoke test each. A new test naming a calendar date or reading the real clock → derive it from one frozen now.

Done when: every axis the depth rule requires has run and each claimed behavior is traced to where it held or failed.

### 4. Adversarial mode

For a high-risk diff, a fresh-context reviewer reads only the artifact + acceptance criteria, tries to make the change fail, and hunts for what is missing as hard as for what is present.
- The external adversarial pass runs in a CLI different from the Lead's, on that CLI's own default model (same vendor is fine).
- The vertical fallback (same CLI, stronger tier) and an inline advisor never satisfy it; both only raise the Lead floor, recorded as a LIMITATION.

Done when: the adversarial reviewer has returned a full report. Only when no dispatch is possible at all (the user forbade agents / no subagent support) does the Lead's cold self-review stand in, recorded as a LIMITATION.

### 5. Report

Fill `templates/review-report.md`: Scope, Read, Risk surfaces touched, Reviewers, Findings (BLOCKER / MAJOR / MINOR), Questions, Tests reviewed, Recommendation.
- Each finding: file:line, the issue, why it matters, a fix direction — the author writes the fix.
- A pre-existing issue on a path the diff does not touch → one note line; it never drives the verdict.
- A clean review names what was read and which lens or axes ran; a bare APPROVED is not a report.
- Write the full report to `.rolepod/evidence/review/<task>-<role>.md`; the reviewer returns ≤ 12 lines + verdict.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo.
Review line: `{"ts":"<iso8601>","phase":"review","verdict":"<APPROVED|APPROVED-WITH-NITS|REJECTED>","blockers":<n>}` (round 2+: add `"round":<n>,"infix":<n>,"repeat":<n>`).

Done when: the report is written with a Recommendation and the review line is appended.

### 6. Fix-verify rounds

- Round 1 = every axis in ONE message, ≤ 40 tool calls per reviewer.
- Round 2 = a BLOCKER / MAJOR fix only: the flagging reviewer re-checks its finding on the fix delta, ≤ 15 tool calls. Its dispatch carries the findings + delta only — no suite re-run, no new mutant, no new axis.
- External round 2+: `rolepod-cross-family --kind review --brief <brief> --since <previous job> --detach` — the runner attaches the fix delta plus the previous report, and findings come back tagged IN-FIX / NEW / REPEAT.
- The external re-runs only when its previous report carried a BLOCKER and the fix delta is logic-bearing code; otherwise the internal reviewer verifies the fix delta alone.
- The reviewer who flagged a BLOCKER / MAJOR verifies its fix; the Lead's cold read stands in only when that reviewer cannot run. Whoever wrote the fix never verifies it. A MINOR / NIT fix is verified by the author's Command.
- A Lead-built fix → one read-only `universal-reviewer` pass (R4 → the strong pass).
- Author and reviewer disagree on merits → technical data > documented style guide > engineering principle > codebase consistency.

Done when: every BLOCKER / MAJOR is closed by the reviewer that flagged it, or the Breaker fired.

#### Breaker

Any one of these triggers the Breaker:
- one reviewer's round 3 on one uncommitted tree (`rolepod-cross-family --rounds` counts it);
- blockers tagged IN-FIX two rounds running;
- BLOCKER / MAJOR tagged NEW in files the previous round never touched, two rounds running;
- the same defect class at a new site;
- any REPEAT.

Then stop fixing and follow `references/breaker.md`: ledger, class, one class fix, ONE internal round with no stop, else split and stop.

### 7. Author response

Wait for the whole round's merged findings — never act on the first report alone. Then:
1. READ every finding without reacting.
2. VERIFY each one against the codebase. Never implement a finding you have not verified.
3. RESPOND with a technical ack or reasoned pushback.
4. Clarify every unclear finding before touching anything linked to it.
5. IMPLEMENT by provenance:
   - introduced by this diff → fix now, ordered blocking → simple → complex, testing each;
   - pre-existing on a path this diff changes → fix now only when it makes THIS change wrong; otherwise a user decision (money / auth) or `## Follow-ups`;
   - pre-existing on an untouched path → `## Follow-ups`, never fixed this round.

Reply with the fix location only — "Fixed in <file:line>." — no gratitude phrases.
A test the author adds to close a finding joins the fix delta; the next round's reviewer judges it, and the author's own green run closes nothing.
rolepod-brain: `brain_note(agent: <reviewer id>, text: "avoid:|refine:|keep: <class>…")` per finding not applied as written, and always on a user overrule.

Pushback, YAGNI on additive findings, PR thread replies → `references/receiving-findings.md`.

Done when: every finding is fixed, pushed back with a reason, or parked in `## Follow-ups`, and each BLOCKER / MAJOR fix is back with its reviewer.

## Guardrails

- A high-risk diff gets an adversarial fresh-context review. Never merge one without it; none dispatched yet → `security-engineer` first.
- A fresh reviewer is the final judge of every change. Never the author, a Lead-built fix included.
- Review evidence is the axis walk. Never "tests pass" alone — tests prove the assertion, not the design.

Finding shapes, good and bad → `examples/finding-examples.md`.

## Next phase

- Review-only ask (no fix, no ship requested) → none; the report is the deliverable.
- Findings need fixes → `implement-plan` or `debug-issue`; fixes landed → `check-work`.
- No blockers and the plan has unchecked tasks → `implement-plan` (Ship asks once per plan). Plan exhausted → `finish-work` for the merge gate.
- If `finish-work` is not available, present the findings + recommendation and ask the user which finish path they want.
