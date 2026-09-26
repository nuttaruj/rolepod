---
name: check-work
description: Use after a change is made and before claiming the work is done — prove it with evidence (tests, build, typecheck, curl, logs, screenshot, browser). State limitations explicitly when verification is not possible. Phase = Verify.
when_to_use: after editing code, configs, content, or any artifact, and before reporting completion to the user or moving to the next phase
---

# Check Work

Turns a finished change into an evidence block: fresh proof that it works, or an honest statement of what could not be proven.

## Skip when

- A no-op (comment, whitespace, docstring) with no behavior risk.
- The user said "just commit, I'll verify".

### 1. Pick the evidence type

| Change type | Required evidence |
|-------------|-------------------|
| Logic / bug fix | Red-green-revert: failing test → fix → green (the loop → `tdd-flow`) → prove red without the fix → green. The red proof is ONE command: remove the fix (a throwaway `git worktree` with the source-only patch reverse-applied; it cannot run the test → revert in place), run the one named test, restore. Red = a non-zero exit WITH the named assertion in the output; a collection / import error, a skip or a 0-test run is not red. Script: `references/verification-discipline.md` Revert in one call. A test that does not fail without the fix is not testing the fix. |
| New feature | Each acceptance criterion has a passing test at the agreed seam, or the observation the spec names |
| Refactor | Existing suite green before and after |
| Schema / migration | Forward + rollback dry run + row-count delta |
| API contract | Contract test + downstream consumer smoke |
| UI change | Browser observation (screenshot or DOM read) |
| Performance | Before / after benchmark — no baseline number, no change |
| Security | Exploit repro blocked, audit log clean |
| Config / infra | Smoke + restart confirmation |
| Docs / spec | Link check, render output, no placeholder leak |

Done when: each acceptance criterion has an evidence type.

### 2. Run the evidence

- Run every check AFTER the last change to the tree. No run since the last edit → you cannot claim it passes; yesterday's green and "should still work" do not count.
- **Evidence cache:** tree unchanged since a pass THIS session (same `git status` + `git diff`; they miss untracked / ignored content, so hash or diff any untracked input the check reads) → cite that run's command + output, "tree unchanged since". ANY new edit invalidates it.
- Capture the exact command and its proof lines. A failure the build already recorded as pre-existing → a limitation, cite that line. Any other failure → run only the failing tests once on the tree without this change (a throwaway `git worktree` at the base sha; it cannot run them → set the diff aside in place, run, restore): red there too → a limitation, cite that run; green there → this change's.
- JUnit / XUnit XML → counted totals + failed names via `scripts/junit-summary.sh <xml>` in this skill's folder (`references/verification-discipline.md`); no script → count the `<testcase>` and `<failure>` / `<error>` elements with `grep -c` and name the failed tests.
- Scope ladder: the task Command while building → the touched module's suite here → the full suite only on high-risk or at merge via the CI lane the change must pass (no CI → finish-work's local equivalents at Ship). Map changed paths to a subset by import graph / naming before going wider.
- Tests fail → fix or report; not done.
- A `manifest.json` under `.rolepod/evidence/` (a sibling plugin ran) → `references/child-plugin-evidence.md`; any kept `fail` fails verify as a whole.

Verifier per evidence type: `performance-engineer` · `security-engineer` · `devops-sre` (CI / deploy smoke). Performance built by a `performance-engineer` owner → its before / after numbers on the unchanged tree are the evidence (Evidence cache); no second dispatch. Brief: change manifest + acceptance criteria + tools; several types → ONE message, same frozen change.
**User-visible E2E — the one `qa-tester` point.** The feature (or ship group) changes what a user sees and every task that changes it is built → ONE `qa-tester` dispatch that runs only the user-visible flows the spec's Testing decisions / acceptance criteria name — a flow the spec gives no reason for is not tested (the `tdd-flow` rule). A new E2E test only for a flow the Testing decisions name as an E2E seam; every other flow is observed once. Never per task, never as a reviewer, never from finish-work; unit-suite failures are the writer's.
No E2E harness → that same `qa-tester` dispatch observes those flows in a browser (UI verification below; its role file grants the browser tools); no browser reachable → it reports "not observed" and the Lead observes those same flows; no subagents → the Lead's.
No subagents → the Lead runs the table's evidence itself: module tests + typecheck / lint; API → curl + assert the shape.
A subagent's COMPLETED is a claim: read its diff and run the named test; no evidence → reject.

Done when: every check has a command + proof line newer than the last edit, or a valid cache cite.

### 3. UI verification

Observe the change in a browser: open the page, render the component, interact with the affected flow. A green typecheck or build is not UI proof; no observation → not verified.
Never ask the user for a screenshot when browser automation is available.
Tool order, what to observe, UI audits → `references/ui-verification.md`.

Done when: the tool, the observed node or text, the screenshot path when one was taken, and the interaction are recorded.

### 4. Guard against a false green

- **Flip the assertion** — flip `==` to `!=` in your head; still passes → too weak, tighten (`references/assertion-strength.md`).
- **Wording trip wires** — completion words before the run ("should pass", "looks right", "Done!"; the full catalog and the rationalization tables in `references/verification-discipline.md`) → stop, run it first, or cite a valid evidence cache.
- **False equivalences** — linter clean ≠ build passes ≠ tests pass ≠ requirements met ≠ agent COMPLETED; "it compiled" alone is not runtime evidence.
- **Attribution** — "the user approved X" traces to a message stating X; a general "go ahead" authorizes nothing it did not name.
- **Spec back-reference** — each acceptance criterion names its evidence: `<criterion> → <evidence command + result line>`; none → unverified, whatever else passed.
- **P1 traceability** — a QA test-case table in play → each P1 ID shows in a passing test in the runner output, else Status `PARTIAL` / `UNVERIFIED`, never `VERIFIED` (`references/verification-discipline.md` P1 traceability).

Done when: every assertion survives the flip and each criterion names its evidence.

### 5. State limitations

No test infra, no network, no browser → Cannot verify / Reason / Risk if wrong / Suggested check. Never claim done over an unstated limitation.

Done when: everything unproven is listed with its risk, or Limitations reads "None".

### 6. Failure modes

Check the diff against F1-F5:

- **F1 invented name** — every function, file and API used exists (Read / Grep).
- **F2 scope creep** — the diff is no wider than the request; cut the extra.
- **F3 cascading error** — the fix brought no new bug; run the full suite.
- **F4 context loss** — every earlier constraint holds (re-read the request).
- **F5 tool misuse** — nothing destructive ran unannounced; review and announce it.

A failed check → fix it before declaring done.
Skip only when ALL hold: ≤5 lines · single file · zero logic-bearing (user-facing string text alone counts as zero) · NOT a high-risk path (= rigor tier R1, trivial edit).

Done when: every check holds, or its failure is fixed.

### 7. Compose the evidence block

Fill `templates/evidence-block.md` (change manifest, evidence, limitations, status). `## Status` is exactly one of `VERIFIED | PARTIAL | UNVERIFIED` — finish-work's Pre-merge gates read the word; PARTIAL / UNVERIFIED block merge.
R1 / R2 (trivial edit / one file + test), one file, no QA table, nothing to limit → `<command> → PASS: <specific proof>. Status: VERIFIED`.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo.
Verify line: `{"ts":"<iso8601>","phase":"verify","verdict":"pass|partial|fail","evidence":"<command run>"}` — the verdict is the lowercase mapping of the Status word: VERIFIED → `pass`, PARTIAL → `partial`, UNVERIFIED → `fail`, and no other value is valid. Nothing follows an R1 / R2 verify → chain it onto the verify command's own call (`<verify cmd> && printf '…pass…' >> … || printf '…fail…' >> …`).

Done when: the block carries one Status word and the verify line is appended.

Examples → `examples/evidence-examples.md`.

## Next phase

- Verify-only ask → stop; the evidence block is the deliverable, and the lines below do not apply (not even to unchecked plan tasks).
- Evidence fails → `debug-issue` or `implement-plan`; the same criterion failing a 2nd verify round on one change → `debug-issue` (its Second opinion cap), never a 3rd blind fix. Neither skill available → the Lead fixes at the root, then re-runs this skill; a 2nd failure → stop and report the attempts to the user.
- Passes with risk (fails review-code's skip test: >5 lines, multi-file, logic-bearing, or high-risk), no plan task left unchecked, and no review of this change yet → `review-code` (R2/R3: the plan's ONE combined review). An R4 task's report under `.rolepod/evidence/review/` covers that task only, and a report for another change does not count. A review that ran before a fix for a check that failed here does not cover that fix; a fix for review findings is covered (any round 2 is `review-code`'s Fix-verify rounds).
- Otherwise → `implement-plan` while the plan has unchecked tasks (Ship asks once per plan), else `finish-work`.
- If neither `review-code` nor `finish-work` is available, attach the evidence block and ask the user whether to ship.
