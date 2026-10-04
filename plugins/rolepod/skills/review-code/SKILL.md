---
name: review-code
description: Use before merging or shipping — review code with reviewers matched to risk across correctness, security, performance, UI, and architecture; R4 adversarial review depends on workflow intensity (`workflow.mode`). Pick reviewer by risk profile and intensity.
when_to_use: when a change is ready to ship and needs a second-pass read for correctness, regressions, security, performance, architecture, or UI compliance before merge
---

# Review Code

A finished diff → a severity-ordered review report, reviewers matched to risk.

## Skip when

- R1 (trivial edit): ≤ 5 lines, one file, zero logic (user-facing string text counts as zero off high-risk paths), NOT high-risk. The edit tool's echo is the evidence; no re-read turn.
- Docs-only at any size (pure docs / typo / whitespace): its own check (link check / static lint) is the verify; no reviewer of any kind.
- The user explicitly accepts the change unreviewed.

### 1. Freeze the diff

- The diff: the R4 task, or for an R2/R3 task in a track with two or more code tasks the track-end review covers it (a track's only code task: its owner's two lenses). A standalone R2 checklist (no plan): its own diff. Committed → `<base>...HEAD`; uncommitted → `git diff HEAD` (staged + unstaged; `--cached` alone is a slice).
- Preflight before any dispatch: each ref resolves (`git rev-parse --verify <ref>^{commit}`) and the diff is non-empty (`git diff --quiet <range>` exits 1); either fails → re-derive the range, never dispatch. Record the snapshot for the report's Scope: `<base sha>..<head sha>`, plus `git diff HEAD | git hash-object --stdin` for uncommitted work.
- Past ~15 files / ~800 lines in a track-end review it is two concerns: split it, one review each: a track-end review by size slice (`implement-plan` Review), any other diff by ship group.
- Gather the spec / plan / acceptance criteria, the touched files end-to-end, and the risk profile (high-risk surface? new dependency? schema change?).

Done when: the range resolves to a non-empty diff, its snapshot is recorded, and every input is in hand.

### 2. Pick reviewers

Workflow intensity is the active session mode carried from startup or first manual `using-rolepod` entry. Do not re-read configured mode when review begins; config changes take effect in a new session/restart.
Configured-mode inspection through `rolepod_config.py mode` is separate and cannot replace the active profile. If a helper invocation lacks native mode environment, pass `ROLEPOD_SESSION_MODE` and `ROLEPOD_SESSION_SOURCE` from the carried profile.
Do not use `review-mode.sh` to choose workflow behavior: it reports compatibility review intensity `standard|full`; cross-family's `standard|adversarial` is a separate reviewer protocol argument.

High-risk surface = auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security.

| Risk profile | Reviewer |
|--------------|----------|
| High-risk surface | Lite: two lenses; Standard: `security-engineer` + two lenses; Full: `security-engineer` + two lenses + adversarial pass |
| Correctness / spec compliance; generic quality / DRY / smell | `universal-reviewer` (spec; standards) |
| Performance regression risk | `performance-engineer` |
| UI / interaction / a11y | `ui-ux-designer` |
| Architecture / cross-module | `system-architect` |

By workflow intensity, then risk tier (R1 trivial edit · R2 one file + test · R3 multi-file · R4 high-risk). Risk tier is independent of workflow intensity:
- **Lite (any tier, including R4)** → exactly two fresh, isolated read-only `universal-reviewer` contexts, dispatched in parallel: `lens: spec` and `lens: standards`.
  Freeze one diff and record its snapshot/hash; attach the identical snapshot to both briefs. Each reviewer receives its own lens only, cannot read the other reviewer's report or findings, and writes a separate report. Wait for both reports before aggregating and deduplicating findings.
  With no agents available, the Lead performs both axes and records the loss of reviewer independence. A missing formal spec uses the user's goal and acceptance criteria as the spec input.
  One round only: no automatic security/specialist/adversarial review, no same-lens rerun, and no round 2+, even on R4. The author fixes findings verified against the diff and attaches evidence. Lite review uses the standard reviewer protocol; this does not change the `standard|adversarial` argument's meaning.
- **R2** → TWO read-only `universal-reviewer` lenses in ONE message, `lens: spec` + `lens: standards` (no spec → standards only); a matched row (perf / UI / arch) → that role instead. The pool's tier is R2 → ONE usable external (`--kind review`, the standard prompt — never `--adversarial`) replaces both lenses and reviews both axes, never beside them on round 1. The writer's unit tests are the floor.
- **R3** → the matched row, internal, unless the pool's tier is R2 or R3 → ONE usable external replaces the `universal-reviewer` lenses.
- **R4 in Standard**: R4 round 1 is `security-engineer` (`depth: checklist`) + `lens: spec` + `lens: standards` in ONE message — no adversarial pass, no round 2+ (the owner fixes each BLOCKER / MAJOR and attaches its proof). **R4 in Full**: R4 round 1 is `security-engineer` at `depth: full`, both lenses, and the adversarial pass in ONE round; round 2+ follows Fix-verify below. Money and auth included. Lite is handled by the preceding Lite rule and never inherits these overrides.
- Pool usable in Full → the external is the only adversarial pass, no internal `mode: adversarial` beside it (an external that fails or comes back weak, per `adversarial-review` What counts → the internal pass then).
- R4 review floors follow intensity: Lite uses its two lenses; Standard requires `security-engineer` and both lenses; Full also requires the adversarial pass. Missing required reports keep the round open. A comment/blank-only R4 diff → Lite follows its two lenses; Standard or Full uses ONE `security-engineer` pass, no external or adversarial pass.
- Every `universal-reviewer` brief names its `mode`: `standard` (a lens, or both axes on a round 2+ re-check) or `adversarial` (R4 round 1 only — `adversarial-review`); no mode named → standard. Every later round is the standard review (Fix-verify rounds).
- A high-risk path anywhere in the unreviewed diff (a task, a ship group, or a track-end review's unreviewed delta) makes it R4; the commission's tier (max over its tasks) governs Define / Plan only.
- A diff reviewed at its tier is never reviewed again at ship. The track-end review (`implement-plan` Review, for a track with two or more code tasks, run by a fresh owner, or one per size slice when the delta is over ~800 changed lines or ~15 files over a track) reviews the R2/R3 task deltas and the Verify fixes nobody has reviewed; an R4 task's commits are context, covered by its reports — the Scope lists each with its report path — never tiered R4 again. The range stays the track's, so the Snapshot reaches the track head.
- A Verify fix on a high-risk path → the workflow-mode R4 set on that fix alone, before its commit (Lite follows its two-lens rule; Standard and Full follow their R4 rules). A fix for a review finding → the applicable Fix-verify rule; Lite never adds a same-lens review or automatic round 2+.
- User-visible behaviour (UI / E2E flows) is no review row — `check-work` verifies it once per feature.

Cross-family pool (any tier it sets) or internal-pass question → `references/external-review-routing.md`. The adversarial pass — who runs it, what counts, apex → the `adversarial-review` skill.

A reviewer's brief carries the diff, the task block and the spec clauses it covers, quoted — never the path of the whole plan or spec.

The `security-engineer` brief (R4) also carries, only when they exist: the result of a security scanner the repo already runs locally (audit, secret scan, a security lint config), run on the changed files; and the security rules the project states (a CLAUDE.md or standards-file section), quoted as its checklist. None present → none added; never invent a scanner or a rule.

Brief every reviewer: diff + spec + acceptance criteria + risk profile + claimed behaviors to trace end-to-end + roles already run + its `mode` (and `lens`) + the report path it writes + the bound: read-only, no sub-agent, no `review-code` run of its own.

**One review round.** Dispatch every reviewer in ONE message on the same frozen diff; the round ends when the LAST one returns.
- A sub-agent running its own round (a task owner) waits on every dispatch: return your brief only after each child's report is in — a child's end wakes you (the Claude desktop app sends it to the Lead, which relays it; on Codex, `wait_agent` returns it), so end a turn only to wait for one, its last line `WAITING: <report paths>`; no `name`, fork or remote isolation (such a child reports to the Lead). No way to wait → `REVIEW NEEDED:` for the Lead instead of a dispatch.
- Until then: no edit to a diff file, no `git stash / reset / checkout / add / commit` (a red-proof revert runs in a throwaway worktree) — reviewers read the live tree.
- With agents available, a missing, failed, empty or partial reviewer report keeps the same round open; that same isolated reviewer completes its own report on the same frozen diff in that round before aggregation or ship. Never substitute a Lead review.
- Keep the diff frozen and Recommendation `PARTIAL` until every report is complete.
- The task owner records each reviewer's immutable H1 report at its canonical path. The canonical task receipt holds report pointers, finding-specific author proof, the bounded H1→H2 delta, and verified H2; do not require a merged report. Existing valid merged reports remain readable. The Lead spot-checks one claim from the receipt and never re-walks a traced report.

Only when agents are unavailable, the Lead records the applicable limitation and performs the allowed fallback. Lite's fallback is its two axes, without added specialists or rounds. Standard and Full cannot replace required isolated reviewer reports with a Lead walk; keep the gate blocked unless the user explicitly waives it. If the user forbids agents, surface the conflict.

Done when: every required reviewer has returned a complete report, required findings are resolved or dispositioned, and the canonical task receipt points to the reports and closure proof.

### 3. Axes

- **Depth** — Full R4: `security-engineer` and the adversarial pass trace in full; Lite and Standard use their intensity-specific reviewer sets above.
  A lens at any tier: a file the task changed is read from the diff; open it only when a hunk you must judge is cut off. Callers and other unchanged files may be opened. Skip what tooling enforces (lint, formatter, typecheck, the commit gate). Never re-run the suite (check-work runs it once; the finish-work pre-merge gate verifies this). A finding that needs a run: a reviewer with a shell runs only the diff's repro command; one without names it under Questions, and the task owner (else the Lead) runs it.
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

Store scope, immutable snapshot, reviewer lens/role, coverage/read trace, limitations, and verdict once in the report. The compact report is `Scope` (including H1 and hash), `Read`, `Risk surfaces touched`, `Reviewers`, and `Recommendation`; add Findings, Questions, Follow-ups, Tests reviewed, and Author fix closure only when applicable. Add the Cross-model adversarial pass section only for Full R4. Each finding states severity, file:line, axis, issue, impact (why it matters), and fix direction; the author writes the fix. Omit empty optional sections and use no mode-specific report formats.
- A pre-existing issue on a path the diff does not touch → one note line, never a verdict driver.
- A clean review names the reviewer lens/role, changed files and behaviors covered, trace paths and where claims held, risk surfaces, and limitations. Preserve the required depth trace for security and Full adversarial reviews. Never accept bare `APPROVED` or infer clean from an absent finding list when coverage is missing or partial.
- Full report → `.rolepod/evidence/review/<task>-<role>.md` — a lens writes `<task>-spec.md` / `<task>-standards.md`, the internal adversarial pass `<task>-adversarial.md`. Return verdict + report path + finding counts + any limitation or action requiring a decision in ≤ 12 lines; do not repeat findings. If no tool can write the report, return the complete compact schema inline, including coverage, limitations, findings and verdict, even when it exceeds 12 lines; never claim a path that was not written.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo.
Review line: `{"ts":"<iso8601>","phase":"review","verdict":"<APPROVED|APPROVED-WITH-NITS|REJECTED>","blockers":<n>}`.

Done when: the report carries a Recommendation and the review line is appended.

### 5. Fix-verify rounds

- Round 1 = every axis in ONE message, ≤ 40 tool calls for `security-engineer` and the adversarial pass, ≤ 20 per lens.
- Fix verification follows workflow intensity: Lite and Standard R4 have no automatic reviewer round; Full R4 re-checks only code-touching fixes for findings raised by `security-engineer` or the adversarial pass (external security-class finding → `security-engineer`, else `universal-reviewer`). At most four Full R4 rounds total, including round 1; round 4 uses a fresh fixer on a stronger model. Still open after round 4 → stop and hand the user the findings and fix-attempt log. Review-round count is separate from failed-fix count; changing reviewers or owners resets neither.
- For the same unresolved repro or criterion, allow at most four failed fixes across owners and phases. Consult once after two; attempts three and four require a fresh trace and use the advice. No usable advisor or failed fix four → stop and ask; never repeat the consult. A review rejection is not a failed fix.
- R2/R3 also have no round 2+. In every no-recheck branch, the author closes each verified finding with finding-specific evidence and an exact bounded fix delta; a green suite alone does not close findings. See Author response and the report template.

Done when: every BLOCKER / MAJOR and every issue its fix made is closed by its applicable intensity rule: author evidence plus bounded delta where no re-check applies, or the specified Full R4 re-check. Anything outside a finding fix delta sits in `## Follow-ups` with its axis. The review then stops — never a full re-review until clean.

### 6. Author response

On the whole round's merged findings, never the first report: READ all without reacting → VERIFY each against the codebase (never implement an unverified one) → RESPOND with a technical ack or reasoned pushback. Clarify every unclear finding before touching anything linked to it. IMPLEMENT by provenance:
- introduced by this diff → fix now, blocking → simple → complex, testing each; a behavior the diff changed or lost outside its own lines counts, even when the reviewer filed it as a question or follow-up;
- pre-existing on a path this diff changes → fix only when it makes THIS change wrong; else a user decision (money / auth) or `## Follow-ups`;
- pre-existing on an untouched path → `## Follow-ups`, never this round.

Reply "Fixed in <file:line>." — no gratitude. Preserve each original lens report and its H1 snapshot unchanged. In a no-recheck branch, the canonical task receipt records each finding's closure evidence (a finding-specific repro or test and result), the exact bounded fix delta H1→H2 (changed paths and delta hash), and the final verified snapshot H2. A passing suite alone is not finding-specific evidence. If the applicable Full R4 rule requires a reviewer re-check, dispatch that re-check against H2 and keep it in a separate report.
Every `## Follow-ups` line — each report's and your own — goes into the plan's `## Follow-ups` (no plan file → straight into the finish menu's Follow-ups carried), the one list `finish-work` works through (its closing rule decides what is closed before the menu and what is carried).
Pushback, YAGNI, disagreement on merits, PR thread replies → `references/receiving-findings.md`.

Done when: every finding is fixed, pushed back with a reason, or in `## Follow-ups`. No-recheck branches carry finding-specific author proof and the H1→H2 delta record; only specified Full R4 findings require a reviewer re-check.

## Guardrails

- Required reviewers follow workflow intensity: Lite R4 requires its two lenses; Standard R4 requires `security-engineer` and both lenses; only Full R4 also requires the adversarial pass. No-recheck branches close verified finding fixes with author evidence and the H1→H2 delta record; Full R4 re-checks only its specified security/adversarial code fixes. The Lead's own walk is never an independent reviewer.
- Original reports remain immutable at H1. Record the verified H2 tree and exact bounded H1→H2 delta; never relabel H1 as H2. Unrelated or new H2 changes are uncovered and must be surfaced and routed at their current tier and mode.
- Evidence is the axis walk; never "tests pass" alone — tests prove the assertion, not the design.

Good / bad finding shapes → `examples/finding-examples.md`.

## Next phase

- Review-only ask (no fix, no ship) → none; the report is the deliverable.
- Findings need fixes → `implement-plan` or `debug-issue`; fixes landed → `check-work`. Neither available → the Lead fixes per Author response, then applies the workflow-mode Fix verification rule above.
- No blockers, plan has unchecked tasks → `implement-plan` (Ship asks once per plan); plan exhausted → `finish-work` for the merge gate.
- If `finish-work` is not available, present the findings + recommendation and ask the user which finish path to take.
