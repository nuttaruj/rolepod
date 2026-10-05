---
name: review-code
description: Use when a finished diff needs review before merge or ship; a task, track end or R4 change reaches its review round; a fix needs its Fix-verify re-check; or the user asks to review a diff, branch or PR.
---

# Review Code

Phase = Review: a finished diff → a severity-ordered review report from reviewers matched to mode and risk, in one round, then Fix-verify on the fixes.

## Skip when

- R1 (trivial edit): ≤ 5 lines, one file, zero logic (user-facing string text counts as zero off high-risk paths), NOT high-risk. The edit tool's echo is the evidence; no re-read turn.
- Docs-only at any size (pure docs / typo / whitespace): its own check (link check / static lint) is the verify; no reviewer of any kind.
- The user explicitly accepts the change unreviewed.

### 1. Freeze the diff

- The diff: the R4 task, or for an R2/R3 task in a track with two or more code tasks the track-end review covers it (a track's only code task: its owner's two lenses). A standalone R2 checklist (no plan): its own diff. Committed → `<base>...HEAD`; uncommitted → `git diff HEAD` (staged + unstaged; `--cached` alone is a slice).
- Preflight before any dispatch: each ref resolves (`git rev-parse --verify <ref>^{commit}`) and the diff is non-empty (`git diff --quiet <range>` exits 1); either fails → re-derive the range, never dispatch. Record the snapshot for the report's Scope: `<base sha>..<head sha>`, plus `git diff HEAD | git hash-object --stdin` for uncommitted work.
- Past ~15 files / ~800 lines in a track-end review it is two concerns: split it, one review each: a track-end review by size slice (`run-tracks` step 4; no `run-tracks` → slices by task in plan order, each within that size), any other diff by ship group.
- Gather the spec / plan / acceptance criteria, the touched files end-to-end, and the risk profile (high-risk surface? new dependency? schema change?).

Done when: the range resolves to a non-empty diff, its snapshot is recorded, and every input is in hand.

### 2. Pick reviewers

Workflow mode = the active session mode carried from startup or the first `using-rolepod` entry; a helper call gets `ROLEPOD_SESSION_MODE` / `ROLEPOD_SESSION_SOURCE`.
No carried mode (a standalone run) → `using-rolepod`'s `scripts/workflow-mode.sh` once (prints the mode), then carry it; no `using-rolepod` → Lite.
A helper or `plan-lint.sh` call without the native mode environment → pass both variables from the carried profile.
Review never re-reads the configured mode (a config change takes effect in a new session), and `review-mode.sh` reports only a compatibility review intensity, never the mode.

Tier is the risk tier, independent of mode: R2 one file + test · R3 multi-file · R4 high-risk.
High-risk surface = auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security. Money and auth are R4.
A high-risk path anywhere in the unreviewed diff (a task, a ship group, or a track-end review's unreviewed delta) makes it R4; the commission's tier (max over its tasks) governs Define / Plan only.

"The two lenses" = two fresh, isolated, read-only `universal-reviewer` contexts in parallel, `lens: spec` and `lens: standards`. A missing formal spec → the user's goal and acceptance criteria are the spec input. Standard / Full R2 with no plan or spec → standards only.

| Mode | R2 | R3 | R4 (round 1) |
|---|---|---|---|
| Lite | the two lenses | the two lenses | the two lenses only — no security, specialist or adversarial reviewer |
| Standard | the two lenses; a matched row → that role instead | the matched rows: the two lenses + each matched specialist | the two lenses + `security-engineer` (`depth: checklist`) |
| Full | as Standard | as Standard | the two lenses + `security-engineer` (`depth: full`) + one adversarial pass |

Matched rows: performance regression risk → `performance-engineer` · UI / interaction / a11y → `ui-ux-designer` · architecture / cross-module → `system-architect`; correctness, spec compliance and generic quality are the lenses. The writer's unit tests are the floor.

- Pool on and an R3 or R4 diff: round 1 runs each lens as its own external instead, in every mode — `cross-family` kind review with `--lens spec`, and a separate run with `--lens standards`, on the same frozen diff. An R2 diff keeps the internal lenses. A comment-only, config-only or rename-only diff and a wide-effort session stay internal. The pool is opt-in; never turn it on unasked.
  `security-engineer` and every specialist stay internal; Full R4's adversarial pass is external too, and then the only adversarial pass. A lens whose run fails, comes back weak (an empty or PARTIAL return, a changed file missing from its Scope, a bare verdict with no claim walked) or is refused → `universal-reviewer` with that lens, same round.
- Pool routing (order, anchors, degradation) → the cross-family skill (references/review.md); no cross-family → the internal lenses.
- The adversarial pass (who runs it, what counts, apex) → the `adversarial-review` skill; no `adversarial-review` → `universal-reviewer` with `mode: adversarial` on a strong-class model, writing `<task>-adversarial.md`.
- A comment/blank-only R4 diff → the R4 set of the active mode, with no external or adversarial pass.
- A Verify fix on a high-risk path → the workflow-mode R4 set on that fix alone, before its commit. A fix for a review finding → Fix-verify (step 5).
- A diff reviewed at its tier is never reviewed again at ship. The track-end review (`implement-plan` step 4) covers the R2/R3 task deltas and the Verify fixes nobody has reviewed; an R4 task's commits are context, covered by its reports — the Scope lists each with its report path — never tiered R4 again. The range stays the track's, so the Snapshot reaches the track head.
- User-visible behaviour (UI / E2E flows) is no review row — `check-work` verifies it once per feature.
- Every `universal-reviewer` brief names its `mode`: `standard` (a lens, or both axes on a Fix-verify re-check) or `adversarial` (Full R4 round 1 only); no mode named → standard. Lite uses the standard protocol.

A reviewer's brief carries the diff, the task block and the spec clauses it covers, quoted — never the path of the whole plan or spec.

The `security-engineer` brief (R4) also carries, only when they exist: the result of a security scanner the repo already runs locally (audit, secret scan, a security lint config), run on the changed files; and the security rules the project states (a CLAUDE.md or standards-file section), quoted as its checklist. None present → none added; never invent a scanner or a rule.

Brief every reviewer: diff + spec + acceptance criteria + risk profile + claimed behaviors to trace end-to-end + roles already run + its `mode` (and `lens`) + the report path it writes + the bound: read-only, no sub-agent, no `review-code` run of its own.
Axes → references/axes.md (the walk per axis); no file → walk intent, trace, correctness, security, performance, architecture, conventions, UI and tests; Full R4 security and adversarial passes trace in full; a lens reads changed files from the diff.

Done when: every required reviewer of the active mode and tier is named with its brief.

### 3. Run the round

- Dispatch every reviewer of the round in ONE message on the same frozen diff, with the identical recorded snapshot / hash in every brief; the round ends when the LAST one returns. Round 1 budget: ≤ 40 tool calls for `security-engineer` and the adversarial pass, ≤ 20 per lens.
- Each reviewer receives its own lens or role only, never sees another reviewer's report or findings, and writes a separate report. Aggregate and deduplicate only after every report is in.
- A task owner running its own round orders it through `run-review`. The fixes wait for every report: dispatch the whole set in ONE message, then take every report in before you fix anything. Cannot dispatch a reviewer → return the diff unreviewed to your caller, naming the set: `REVIEW NEEDED: <set>`.
- Until the round ends: no edit to a diff file, no `git stash / reset / checkout / add / commit` (a red-proof revert runs in a throwaway worktree) — reviewers read the live tree.
- With agents available, a missing, failed, empty or partial internal reviewer report keeps the same round open (an external lens falls back per step 2): that same isolated reviewer completes its own report on the same frozen diff in that round, before aggregation or ship. Never substitute a Lead review. Recommendation stays `PARTIAL` until every report is complete.
- No agents available → Lite: the Lead walks both axes and records the loss of reviewer independence, with no added specialist or round. Standard / Full: the gate stays blocked unless the user explicitly waives it. The Lead's own walk is never an independent reviewer; strength routing may give an axis to a specialist but never removes a required axis. The user forbids agents → surface the conflict.
- The task owner records each reviewer's immutable H1 report at its canonical path; the canonical task receipt holds the report pointers and each finding's closure (step 5); no merged report required (an existing one stays readable). The Lead spot-checks one claim from the receipt and never re-walks a traced report.

Done when: every required report is complete, and the receipt points to each.

### 4. Report

Report shape → `templates/review-report.md` (the section layout); no template → the compact report below still completes the step.
- The compact report is `Scope` (changed files, snapshot H1 and hash), `Read`, `Risk surfaces touched`, `Reviewers`, and `Recommendation`; add Findings, Questions, Follow-ups, Tests reviewed only when applicable, and the Cross-model adversarial pass section only for Full R4. Omit empty optional sections; no mode-specific report formats.
- Each finding states severity, file:line, axis, issue, impact (why it matters), and fix direction; the author writes the fix. A pre-existing issue on a path the diff does not touch → one note line, never a verdict driver.
- A clean review names the reviewer lens/role, changed files and behaviors covered, trace paths and where claims held, risk surfaces, and limitations; security and Full adversarial reviews keep their depth trace. Never accept bare `APPROVED` or infer clean from an absent finding list when coverage is missing or partial.
- Each report → `.rolepod/evidence/review/<task>-<lens|role>.md`, `<task>` = the brief's `<plan-slug>-task<N>` (a lens writes `<task>-spec.md` / `<task>-standards.md`, the internal adversarial pass `<task>-adversarial.md`); an external lens's report is the raw file named in `ROLEPOD-XFAM ok … raw=<path>`.
- Return verdict + report path + finding counts + any limitation or decision in ≤ 12 lines; never repeat findings. No tool can write the report → return the complete compact report inline, coverage, limitations, findings and verdict included, at any length; never claim a path that was not written.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo.
Review line: `{"ts":"<iso8601>","phase":"review","verdict":"<APPROVED|APPROVED-WITH-NITS|REJECTED>","blockers":<n>}`.

Done when: the report carries a Recommendation and the review line is appended.

### 5. Fix-verify rounds

- Round 2+ (every mode, every tier): ONE fresh `universal-reviewer` (balanced) re-checks only the fix delta H1→H2 of every BLOCKER / MAJOR fix, and every BLOCKER / MAJOR pushback against its reason at H2, in one pass, whoever raised the finding; never the original role. A pushback the re-check marks held closes; one it marks reopened goes back to the author as an open finding. MINOR closes on author evidence. At most four rounds including round 1; still open → stop and hand the user the findings and the fix log.
- Review-round count is separate from failed-fix count; changing reviewers or owners resets neither. A review rejection is not a failed fix.
- Four failed fixes for one unresolved repro or criterion → stop and ask; one Second opinion after two (`debug-issue` Second opinion); review rounds count separately.
- A finding closes at the receipt only: the canonical task receipt records, per finding, the author's finding-specific repro or test and result, the bounded fix delta H1→H2 (changed paths + delta hash) and the verified H2; a green suite alone closes nothing. Reports stay immutable at H1; the re-check writes its own report at H2.
- The re-check's diff file is the delta only. The owner records the H1 tree when it stages the round-1 diff (`git add -A && git write-tree`, the `check-work` Verified-tree recipe); after the fixes it writes `git add -A && git diff <H1-tree> $(git write-tree) -U10 -- . ':!docs/rolepod' ':!*.lock' ':!package-lock.json' ':!pnpm-lock.yaml'` to `.rolepod/evidence/review/<task>-r2.diff` and hands the re-check that file, never the cumulative diff. A committed H1 → its commit sha for the tree. No H1 tree kept → the cumulative diff plus the paths the fixes touched, and say so.

Done when: every BLOCKER / MAJOR and every issue its fix made is closed at the receipt after the re-check above; a pushed-back finding closes only when the re-check marks it held. Anything outside a finding fix delta sits in `## Follow-ups` with its axis. The review then stops — never a full re-review until clean.

### 6. Author response

READ all → VERIFY each against the code → RESPOND (fix or reasoned pushback; "Fixed in <file:line>.", no thanks); fix by provenance: introduced by this diff → now; pre-existing on a changed path → only when it makes this change wrong; untouched path → ## Follow-ups. Every Follow-up goes into the plan's list. Pushback, YAGNI, PR threads → references/receiving-findings.md.
- Work the round's merged findings, never the first report.
- Clarify an unclear finding before touching what it links to.
- Fix blocking → simple → complex, testing each.
- A behavior the diff changed or lost outside its own lines counts as introduced, even when the reviewer filed it as a question or follow-up.
- A pre-existing issue on a changed path that does not make this change wrong → a user decision (money / auth) or `## Follow-ups`.
- "The plan's list" = the plan's `## Follow-ups`; no plan file → the finish menu's Follow-ups carried, the one list `finish-work` works through.
- No `references/receiving-findings.md` → per finding, reply with the fix or a reasoned pushback.
- BLOCKER / MAJOR fixes or pushbacks recorded → dispatch the Fix-verify re-check (step 5) against H2; a pushback goes in with its reason, and the re-check marks it held or reopened.

Done when: every finding is fixed, pushed back with a reason, or in `## Follow-ups`; each fixed finding's closure is in the receipt, and each BLOCKER / MAJOR pushback is marked held there by the re-check.

## Guardrails

- Keep original reports immutable at H1. Record the verified H2 tree and the exact bounded H1→H2 delta; never relabel H1 as H2. Unrelated or new H2 changes are uncovered: surface them and route them at their current tier and mode.
- Evidence is the axis walk; never "tests pass" alone — tests prove the assertion, not the design.
- Good / bad finding shapes → `examples/finding-examples.md`; no file → every finding carries severity, file:line, axis, issue, impact and fix direction, and nothing vaguer.

## Next phase

- Review-only ask (no fix, no ship) → none: stop after handing over the report, even with findings or unchecked plan tasks; the report is the deliverable.
- Findings need fixes → `implement-plan` or `debug-issue`; fixes landed → `check-work`. Neither available → the Lead fixes per Author response, then runs Fix-verify (step 5).
- No blockers, plan has unchecked tasks → `implement-plan` (Ship asks once per plan); plan exhausted → `finish-work` for the merge gate.
- If `finish-work` is not available, present the findings + recommendation and ask the user which finish path to take.
