---
name: check-work
description: Use when a change is made and before claiming it is done or moving to the next phase; every track of a plan has merged; the user asks to verify, prove or test that a change works.
---

# Check Work

Phase = Verify: turns a finished change into an evidence block — fresh proof that it works, or an honest statement of what could not be proven.
A verify-only ask (the user asked only to verify, prove or test) ends at the evidence block; no next skill runs, unchecked plan tasks included.

## Skip when

- A no-op (comment, whitespace, docstring) with no behavior risk.
- The user said "just commit, I'll verify".

### 1. Pick the evidence type

| Change type | Required evidence |
|-------------|-------------------|
| Logic / bug fix | Failing test → fix → green (`tdd-flow`; no `tdd-flow` → one failing test at the seam, the smallest fix to green), then red without the fix → `references/verification-discipline.md` (Revert in one call; when a `tdd-flow` red run counts); no reference → remove the fix, run the one named test, restore; red = a non-zero exit WITH the named assertion (a collection error, a skip or a 0-test run is not red); green without the fix → the test does not test the fix, rewrite it. |
| New feature | Each acceptance criterion has a passing test at the agreed seam. An observation stands in only for a user-visible flow (the `qa-tester` point in step 2) or a task its plan marks evidence-after — never a test-first, contract, perf or security task |
| Refactor | The checks covering changed behavior and affected consumers pass, no assertion weakened; a failure → the base-tree run in step 2 tells pre-existing from this change's |
| Schema / migration | Forward + rollback dry run + row-count delta |
| API contract | Contract test + downstream consumer smoke |
| UI change | Browser observation (screenshot or DOM read) |
| Performance | Before / after benchmark — no baseline number, no change |
| Security | Exploit repro blocked, audit log clean |
| Config / infra | Smoke + restart confirmation |
| Docs / spec | Link check, render output, no placeholder leak |

Done when: each acceptance criterion has an evidence type.

### 2. Run the evidence

- Run checks for changed behavior, affected consumers and acceptance criteria. Reuse matching proof after the final relevant edit; a phase change adds no check.
- **Evidence cache:** reuse a passing run only when scope, relevant inputs, environment and provenance still match. Record its command, output, execution checkout or snapshot, and result; HEAD equality alone is insufficient.
  Compare tracked, untracked and ignored inputs the check reads, plus environment and provenance. After integration or helper updates, rerun only stale or uncovered claims; a relevant edit does not invalidate unrelated proof.
- Capture the exact command and its proof lines. A failure the build already recorded as pre-existing → a limitation, cite that line. Any other failure → run only the failing tests once on the tree without this change (a throwaway `git worktree` at the base sha; it cannot run them → set the diff aside in place, run, restore): red there too → a limitation, cite that run; green there → this change's.
- JUnit / XUnit XML → `scripts/junit-summary.sh <xml>` in this skill's folder (counted totals + failed names); no script → `grep -c` the `<testcase>` and `<failure>` / `<error>` elements and name the failed tests. Zero cases, or every case skipped → no test ran, never green.
- Select the narrowest covering check; retain required high-risk, integration, CI and post-deploy smoke gates. A changed tree alone does not require unrelated suites when scoped proof remains valid.
- Tests fail → fix or report; not done.
- A `manifest.json` under `.rolepod/evidence/` (a sibling plugin ran) → `references/child-plugin-evidence.md` (which runs to keep); no reference → keep only runs newer than your last relevant edit that name this target. Any kept `fail` fails verify as a whole.

Verifier per evidence type: `performance-engineer` · `security-engineer` · `devops-sre` (CI / deploy smoke). Performance built by a `performance-engineer` owner → its before / after numbers on the unchanged tree are the evidence (Evidence cache); no second dispatch. Brief: change manifest + acceptance criteria + tools; several types → ONE message, same frozen change.
**User-visible E2E — the one `qa-tester` point.** The feature (or ship group) changes what a user sees and every task that changes it is built → ONE `qa-tester` dispatch running only the flows the spec's Testing decisions / acceptance criteria name; a new E2E test only where Testing decisions name an E2E seam, every other flow observed once. Never per task, as a reviewer or from finish-work; unit-suite failures are the writer's. No E2E harness → it observes in a browser; no browser → it reports "not observed" and the Lead observes.
No subagents → the Lead runs the evidence and the flows itself, scoped to changed behavior and affected consumers: tests plus required typecheck / lint; API → curl + assert the shape.
A subagent's COMPLETED is a claim: read its diff and run the named test; no evidence → reject.

Done when: every check has a command + proof line newer than the last edit, or a valid cache cite.

### 3. UI verification

Observe the change in a browser: open the page, render the component, interact with the affected flow. A green typecheck or build is not UI proof; no observation → not verified.
Never ask the user for a screenshot when browser automation is available.
Tool order, what to observe, UI audits → `references/ui-verification.md`; no reference → the strongest browser tool present.

Done when: the tool, the observed node or text, the screenshot path when one was taken, and the interaction are recorded.

### 4. Guard against a false green

- **Flip the assertion** — flip `==` to `!=` in your head; still passes → too weak, tighten (`references/assertion-strength.md`; no reference → assert the exact value, not truthiness or presence).
- **Wording trip wires** — completion words before the run ("should pass", "looks right", "Done!"; the full catalog in `references/verification-discipline.md`, else these three) → stop, run it first, or cite a valid evidence cache.
- **False equivalences** — linter clean ≠ build passes ≠ tests pass ≠ requirements met ≠ agent COMPLETED; "it compiled" alone is not runtime evidence.
- **Attribution** — "the user approved X" traces to a message stating X; a general "go ahead" authorizes nothing it did not name.
- **Spec back-reference** — each acceptance criterion names its evidence: `<criterion> → <evidence command + result line>`; none → unverified, whatever else passed.
- **P1 traceability** — a QA test-case table in play → each P1 ID shows in a passing test in the runner output, else Status `PARTIAL` / `UNVERIFIED`, never `VERIFIED`; a skipped or uncollected test counts as missing (`references/verification-discipline.md` P1 traceability).

Done when: every assertion survives the flip and each criterion names its evidence.

### 5. State limitations

No test infra, no network, no browser → Cannot verify / Reason / Risk if wrong / Suggested check. Never claim done over an unstated limitation.

Done when: everything unproven is listed with its risk, or Limitations reads "None".

### 6. Failure modes

Check the diff against F1-F5:

{{INCLUDE: core/fragments/gates-f1-f5.md}}

Done when: every check holds, or its failure is fixed.

### 7. Update the canonical task receipt

Fill the Evidence fields from `templates/evidence-block.md` in the task receipt named by the brief (no template → Change manifest, Evidence with the verified tree id (`git rev-parse HEAD^{tree}` on a clean tree, else `git add -A && git write-tree`) and one command + proof line per check, Limitations, Verify status); do not create a second report. Keep Verify status (`VERIFIED | PARTIAL | UNVERIFIED`) separate from the owner's task status (`COMPLETED | PARTIAL | BLOCKED`). Finish-work reads Verify status; PARTIAL / UNVERIFIED block merge.
A plan's full-diff verify (the one `implement-plan` runs after every track merges; no brief names a receipt) → write the block to `<base checkout>/docs/rolepod/tasks/<plan file name without .md>/verify.md`, replacing the previous run, so `finish-work` can read it after a compact. No plan (a standalone R2 checklist) → the block stays in chat.
R1 / R2 (trivial edit / one file + test), one file, no QA table, nothing to limit → `<command> → PASS: <specific proof>. Status: VERIFIED`.

{{INCLUDE: core/fragments/phase-log.md}}
Verify line: `{"ts":"<iso8601>","phase":"verify","verdict":"pass|partial|fail","evidence":"<command run>"}` — the verdict is the lowercase mapping of the Status word: VERIFIED → `pass`, PARTIAL → `partial`, UNVERIFIED → `fail`, and no other value is valid. Nothing follows an R1 / R2 verify → chain it onto the verify command's own call (`<verify cmd> && printf '…pass…' >> … || printf '…fail…' >> …`).

Done when: the block carries one Status word and the verify line is appended.

Examples → `examples/evidence-examples.md`; no examples → the one-line R1 / R2 form above.

## Next phase

- Verify-only ask → stop; the evidence block is the deliverable, and the lines below do not apply (not even to unchecked plan tasks).
- Evidence fails → `debug-issue` or `implement-plan`; the same criterion failing a 2nd verify round on one change → `debug-issue`, carrying `Attempts: <n> used` and each failed fix with why it stayed red. Verify rounds are not failed fixes; never make a blind fix. Neither skill available → the Lead fixes at the root, then repeats verification.
- Four failed fixes for one unresolved repro or criterion → stop and ask; one Second opinion after two (`debug-issue` Second opinion); review rounds count separately. The count carries across owners and phases.
- Passes with risk (fails review-code's skip test: >5 lines, multi-file, logic-bearing, or high-risk), no plan task left unchecked, and no review of this change yet → `review-code` (R2/R3: the track-end review (one code task: the owner's lenses) covers it; R4: per-task review before commit). An R4 task's report under `.rolepod/evidence/review/` covers that task only, and a report for another change does not count. A review that ran before a fix for a check that failed here does not cover that fix; a fix for review findings is covered (`review-code` Fix-verify).
- Otherwise → `implement-plan` while the plan has unchecked tasks (Ship asks once per plan), else `finish-work`.
- If neither `review-code` nor `finish-work` is available, attach the evidence block and ask the user whether to ship.
