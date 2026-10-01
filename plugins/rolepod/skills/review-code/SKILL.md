---
name: review-code
description: Use before merging or shipping — review code with reviewers matched to risk across correctness, security, performance, UI, and architecture; an R4 (high-risk) diff adds one adversarial pass (`adversarial-review`). Pick reviewer by risk profile.
when_to_use: when a change is ready to ship and needs a second-pass read for correctness, regressions, security, performance, architecture, or UI compliance before merge
---

# Review Code

A finished diff → a severity-ordered review report, reviewers matched to risk.

## Skip when

- R1 (trivial edit): ≤ 5 lines, one file, zero logic (user-facing string text counts as zero off high-risk paths), NOT high-risk. The edit tool's echo is the evidence; no re-read turn.
- Docs-only at any size (pure docs / typo / whitespace): its own check (link check / static lint) is the verify; no reviewer of any kind.
- The user explicitly accepts the change unreviewed.

### 1. Freeze the diff

- The diff: the R4 task, or for an R2/R3 task in a track the track-end review covers it. A standalone R2 checklist (no plan): its own diff. Committed → `<base>...HEAD`; uncommitted → `git diff HEAD` (staged + unstaged; `--cached` alone is a slice).
- Preflight before any dispatch: each ref resolves (`git rev-parse --verify <ref>^{commit}`) and the diff is non-empty (`git diff --quiet <range>` exits 1); either fails → re-derive the range, never dispatch. Record the snapshot for the report's Scope: `<base sha>..<head sha>`, plus `git diff HEAD | git hash-object --stdin` for uncommitted work.
- Past ~15 files / ~800 lines in a track-end review it is two concerns: split it, one review each: a track-end review by size slice (`implement-plan` Review), any other diff by ship group.
- Gather the spec / plan / acceptance criteria, the touched files end-to-end, and the risk profile (high-risk surface? new dependency? schema change?).

Done when: the range resolves to a non-empty diff, its snapshot is recorded, and every input is in hand.

### 2. Pick reviewers

High-risk surface = auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security.

| Risk profile | Reviewer |
|--------------|----------|
| High-risk surface | `security-engineer` + the adversarial pass (`adversarial-review`) |
| Correctness / spec compliance; generic quality / DRY / smell | `universal-reviewer` (spec; standards) |
| Performance regression risk | `performance-engineer` |
| UI / interaction / a11y | `ui-ux-designer` |
| Architecture / cross-module | `system-architect` |

By rigor tier (R1 trivial edit · R2 one file + test · R3 multi-file · R4 high-risk):
- **R2** → TWO read-only `universal-reviewer` lenses in ONE message, `lens: spec` + `lens: standards` (no spec → standards only); a matched row (perf / UI / arch) → that role instead. The pool's tier is R2 → ONE usable external (`--kind review`, the standard prompt — never `--adversarial`) replaces both lenses and reviews both axes, never beside them on round 1. The writer's unit tests are the floor.
- **R3** → the matched row, internal, unless the pool's tier is R2 or R3 → ONE usable external replaces the `universal-reviewer` lenses.
- **R4** → round 1 is ONE message, four dispatches (an external adversarial pass: its `--detach` runs just before that message): `security-engineer` · `universal-reviewer` `lens: spec` · `universal-reviewer` `lens: standards` (the R2/R3 pair, balanced; a concern-matched row takes the pair's place) · the adversarial pass (`adversarial-review`: the external with `--adversarial` when the pool is usable, else `universal-reviewer` `mode: adversarial` on a strong-class model), the reason on the Cross-model line. Money and auth included.
- Pool usable → the external is the only adversarial pass, no internal `mode: adversarial` beside it (an external that fails or comes back weak, per `adversarial-review` What counts → the internal pass then).
- The R4 floor is `security-engineer` + the adversarial pass; a missing lens report is a LIMITATION, never a merge block. A comment/blank-only R4 diff → ONE `security-engineer` pass, no external.
- Every `universal-reviewer` brief names its `mode`: `standard` (a lens, or both axes on a round 2+ re-check) or `adversarial` (R4 round 1 only — `adversarial-review`); no mode named → standard. Every later round is the standard review (Fix-verify rounds).
- A high-risk path anywhere in the unreviewed diff (a task, a ship group, or a track-end review's unreviewed delta) makes it R4; the commission's tier (max over its tasks) governs Define / Plan only.
- A diff reviewed at its tier is never reviewed again at ship. The track-end review (`implement-plan` Review, run by a fresh owner, or one per size slice when the delta is over ~800 changed lines or ~15 files over a track) reviews the R2/R3 task deltas and the Verify fixes nobody has reviewed; an R4 task's commits are context, covered by its reports — the Scope lists each with its report path — never tiered R4 again. The range stays the track's, so the Snapshot reaches the track head.
- A Verify fix on a high-risk path → the R4 round-1 set on that fix alone, before its commit. A fix for a review finding → round 2 (Fix-verify rounds), never a new external or adversarial pass.
- User-visible behaviour (UI / E2E flows) is no review row — `check-work` verifies it once per feature.

Cross-family pool (any tier it sets) or internal-pass question → `references/external-review-routing.md`. The adversarial pass — who runs it, what counts, apex → the `adversarial-review` skill.

Brief every reviewer: diff + spec + acceptance criteria + risk profile + claimed behaviors to trace end-to-end + roles already run + its `mode` (and `lens`) + the report path it writes + the bound: read-only, no sub-agent, no `review-code` run of its own.

**One review round.** Dispatch every reviewer in ONE message on the same frozen diff; the round ends when the LAST one returns.
- A sub-agent running its own round (a task owner) waits on every dispatch: return your brief only after each child's report is in — a child's end wakes you (the Claude desktop app sends it to the Lead, which relays it; on Codex, `wait_agent` returns it), so end a turn only to wait for one, its last line `WAITING: <report paths>`; no `name`, fork or remote isolation (such a child reports to the Lead). No way to wait → `REVIEW NEEDED:` for the Lead instead of a dispatch.
- Until then: no edit to a diff file, no `git stash / reset / checkout / add / commit` (a red-proof revert runs in a throwaway worktree) — reviewers read the live tree.
- An empty or partial return (`""`, one sentence, a turn-limit notice) is a failed reviewer: re-dispatch it narrower (the Lead may resume it instead; a resume runs in the background); the round stays open, the report records a LIMITATION.
- Whoever dispatched the round (the task owner, the track-end owner; the Lead only for a round it dispatched) merges severity-ordered, deduped by file:line + root cause (its own findings included; severity words per the template); each finding keeps its reviewer and axis (spec / standards / security / perf / UI / architecture). The Lead gets one merged brief, spot-checks ONE finding, never re-walks a traced report.

No subagents, or a report missing / failed / empty → the Lead walks every Axes item cold, recorded as a LIMITATION; on a high-risk diff only when no dispatch is possible at all, and that walk never meets the high-risk floor: the merge stays blocked until the user waives it in words naming it (finish-work Reviewer gate). The user forbade agents → surface the conflict; never self-set a bypass.

Done when: every dispatched reviewer has returned a full report and its findings are merged.

### 3. Axes

- **Depth** — R4: `security-engineer` and the adversarial pass trace in full. A lens at any tier: a file the task changed is read from the diff; open it only when a hunk you must judge is cut off. Callers and other unchanged files may be opened. Skip what tooling enforces (lint, formatter, typecheck, the commit gate). Never re-run the suite (check-work runs it once; the finish-work pre-merge gate verifies this). A finding that needs a run: a reviewer with a shell runs only the diff's repro command; one without names it under Questions, and the task owner (else the Lead) runs it.
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

Fill `templates/review-report.md`: Scope (with its Snapshot line), Read, Risk surfaces touched, Reviewers (R4: with its Cross-model adversarial pass line), Findings (BLOCKER / MAJOR / MINOR, each with its axis), Questions, Tests reviewed, Recommendation.
- Each finding: file:line, the issue, why it matters, a fix direction — the author writes the fix.
- A pre-existing issue on a path the diff does not touch → one note line, never a verdict driver.
- A clean review names what was read and the lenses run — never a bare APPROVED.
- Full report → `.rolepod/evidence/review/<task>-<role>.md` — a lens writes `<task>-spec.md` / `<task>-standards.md`, the internal adversarial pass `<task>-adversarial.md`; the reviewer returns ≤ 12 lines + verdict.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo.
Review line: `{"ts":"<iso8601>","phase":"review","verdict":"<APPROVED|APPROVED-WITH-NITS|REJECTED>","blockers":<n>}`.

Done when: the report carries a Recommendation and the review line is appended.

### 5. Fix-verify rounds

- Round 1 = every axis in ONE message, ≤ 40 tool calls for `security-engineer` and the adversarial pass, ≤ 20 per lens.
- Round 2+ — R2/R3: none; the owner fixes each BLOCKER / MAJOR and attaches its proof (the Command tail, the reviewer's repro re-run, or the grep showing the old line gone). R4: only a finding raised by `security-engineer` or the adversarial pass whose fix touches code — the flagging role re-checks the fix delta only, on a balanced model (an external's finding → `security-engineer` for security-class, else `universal-reviewer`); at most 5 rounds, rounds 4-5 a fresh fixer on a stronger model; still open after round 5 → stop and hand the user the open findings with the attempt log.
- A Lead-built fix follows the round 2+ rule at its tier.

Done when: every round-1 BLOCKER / MAJOR, and every issue its fix made, is closed by the owner's proof (R2/R3) or the R4 round 2+ re-check, and anything outside a fix delta sits in `## Follow-ups` with its axis. The review then stops — never a full re-review until clean.

### 6. Author response

On the whole round's merged findings, never the first report: READ all without reacting → VERIFY each against the codebase (never implement an unverified one) → RESPOND with a technical ack or reasoned pushback. Clarify every unclear finding before touching anything linked to it. IMPLEMENT by provenance:
- introduced by this diff → fix now, blocking → simple → complex, testing each; a behavior the diff changed or lost outside its own lines counts, even when the reviewer filed it as a question or follow-up;
- pre-existing on a path this diff changes → fix only when it makes THIS change wrong; else a user decision (money / auth) or `## Follow-ups`;
- pre-existing on an untouched path → `## Follow-ups`, never this round.

Reply "Fixed in <file:line>." — no gratitude. A test added to close a finding joins the fix delta for the next reviewer; the author's own green run closes nothing.
Every `## Follow-ups` line — each report's and your own — goes into the plan's `## Follow-ups` (no plan file → straight into the finish menu's Follow-ups carried), the one list `finish-work` works through (its closing rule decides what is closed before the menu and what is carried).
Pushback, YAGNI, disagreement on merits, PR thread replies → `references/receiving-findings.md`.

Done when: every finding is fixed, pushed back with a reason, or in `## Follow-ups`, and each BLOCKER / MAJOR fix carries its owner proof (R2/R3) or is back with its R4 round 2+ re-check.

## Guardrails

- A high-risk diff gets its adversarial pass (`adversarial-review`); never merge one without it (none yet → `security-engineer` first) unless the user waives it in words naming that review. The Lead's own walk is never that review.
- A fresh reviewer is the final judge; never the author, a Lead-built fix included.
- Evidence is the axis walk; never "tests pass" alone — tests prove the assertion, not the design.

Good / bad finding shapes → `examples/finding-examples.md`.

## Next phase

- Review-only ask (no fix, no ship) → none; the report is the deliverable.
- Findings need fixes → `implement-plan` or `debug-issue`; fixes landed → `check-work`. Neither available → the Lead fixes per Author response, then the round 2+ rule at its tier applies (Fix-verify rounds).
- No blockers, plan has unchecked tasks → `implement-plan` (Ship asks once per plan); plan exhausted → `finish-work` for the merge gate.
- If `finish-work` is not available, present the findings + recommendation and ask the user which finish path to take.
