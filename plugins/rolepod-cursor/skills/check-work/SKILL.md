---
name: check-work
description: Use after a change is made and before claiming the work is done — prove it with evidence (tests, build, typecheck, curl, logs, screenshot, browser). State limitations explicitly when verification is not possible. Phase = Verify.
---

# Check Work

Turns a finished change into an evidence block: fresh proof that it works, or an honest statement of what could not be proven.

## Skip when

- A no-op (comment, whitespace, docstring) with no behavior risk.
- The user said "just commit, I'll verify".

### 1. Pick the evidence type

Inputs: the diff · the acceptance criteria from the spec / plan / task · the tools at hand (runner, build, browser, curl) · the CI lane this change must pass.

| Change type | Required evidence |
|-------------|-------------------|
| Logic / bug fix | Red-green-revert: failing test → fix → green → prove red without the fix → green. Run the red proof as ONE call (`references/verification-discipline.md` Revert in one call): a throwaway `git worktree`, reverse-apply the source-only patch, run the one named test — a non-zero exit WITH the named assertion in the output (a collection / import error, a skip, or a 0-test run is not red); remove the worktree. The worktree cannot run the test → the three-step revert in place. A test that does not fail without the fix is not testing the fix. |
| New feature | Happy + edge + error tests pass |
| Refactor | Existing suite green before and after |
| Schema / migration | Forward + rollback dry run + row-count delta |
| API contract | Contract test + downstream consumer smoke |
| UI change | Browser observation (screenshot or DOM read) |
| Performance | Before / after benchmark — no baseline number, no change |
| Security | Exploit repro blocked, audit log clean |
| Config / infra | Smoke + restart confirmation |
| Docs / spec | Link check, render output, no placeholder leak |

Done when: every acceptance criterion has an evidence type from the table.

### 2. Run the evidence

- Run every check AFTER the last change to the tree. No run since the last edit → you cannot claim it passes; yesterday's green and "should still work" do not count.
- **Evidence cache:** the tree is unchanged since a pass recorded THIS session (same `git status` + `git diff` — neither sees untracked / ignored content, so hash or diff any untracked input the check reads) → cite that run's command + output and state "tree unchanged since" instead of re-running. ANY new edit invalidates the cache.
- Capture the exact command and the lines that prove the claim, not all output.
- A failure already in the baseline (recorded before the first edit) is a limitation, not a regression — cite the baseline line; a failure absent from it is this change's.
- The runner emits JUnit / XUnit XML (`pytest --junitxml` / `--reporter=junit` / surefire) → cite the counted totals + failed test names via `rolepod-junit <xml>` (installed launcher) or `scripts/junit-summary.sh` (source repo / plugin `scripts/`); counted results beat prose.
- Scope ladder: the task Command while building → the touched module's suite here → the full suite only on high-risk or at merge via CI (no CI → that scope runs locally at Ship). Map the changed paths to a subset by import graph / naming before going wider.
- Tests fail → fix or report; the work is not done.
- A `manifest.json` under `.rolepod/evidence/` (a sibling plugin ran) → `references/child-plugin-evidence.md`; any kept `fail` fails verify as a whole.

Dispatch the verifier that matches each evidence type: `qa-tester` (user-visible E2E / UI; unit-suite failures are the writer's) · `performance-engineer` (p95 / p99 / bundle / benchmark) · `security-engineer` (exploit blocked) · `devops-sre` (CI lane / deploy smoke). Brief: the change manifest + acceptance criteria + available tools.
More than one evidence type → dispatch the verifiers in ONE message, each proving an independent claim on the same frozen change.
No subagents → the Lead does it: module tests + typecheck / lint; API → curl + assert the response shape; schema → dry-run forward + rollback; docs → render + link check + placeholder scan.

A subagent's COMPLETED is a claim: read its diff and run the named test yourself; COMPLETED with no evidence → reject.

Done when: every check has its command and proof line from a run after the last edit, or a valid cache cite.

### 3. UI verification

A UI change needs a browser observation: open the page, render the component, interact with the affected flow — browser tools, Playwright, or local devtools.
A passing typecheck or build does not prove the UI works; no browser observation → not verified.
Never ask the user for a screenshot when browser automation is available.
Tool order, what to observe, and a UI audit with no diff → `references/ui-verification.md`.

Done when: the changed flow was observed, and the tool, the observed node or text, the screenshot path when one was taken, and the interaction are recorded.

### 4. Guard against a false green

- **Flip the assertion** — mentally flip `==` to `!=`; it still passes → too weak, tighten. Weak vs strong by type → `references/assertion-strength.md`.
- **Wording trip wires** — "should pass", "probably works", "seems right", "looks right", "Great!", "Perfect!", "Done!" before running the command → stop, run it first, or cite a valid evidence cache (Run the evidence).
- **False equivalences** — linter clean ≠ build passes ≠ tests pass ≠ requirements met ≠ agent COMPLETED. Each layer proves only what it ran; "it compiled" as the only runtime evidence is not verified.
- **Stale evidence** — a claim comes from a run AFTER the last change in this unit of work; re-run, never re-quote.
- **Attribution** — "the user approved X" traces to a specific message stating X; a general "go ahead" authorizes nothing it did not name.
- **Spec back-reference** — every acceptance criterion names its evidence: `<criterion> → <evidence command + result line>`. A criterion with no named evidence is unverified, however many other tests pass.
- **P1 traceability** — a QA test-case table in play (this session or under `.rolepod/evidence/`) → every P1 row's ID appears in a passing test's name: `grep` the RUNNER output for `TC<n>` (source presence proves authorship, not a pass; skipped / not collected = missing). A P1 with no passing test → Status `PARTIAL` or `UNVERIFIED` (never `VERIFIED`), naming the missing IDs.

Common failures and the rationalization tables → `references/verification-discipline.md`.

Done when: every assertion survives the flip and every acceptance criterion names its evidence.

### 5. State limitations

No test infra, no network, no browser → the four fields from `templates/evidence-block.md`: Cannot verify / Reason / Risk if wrong / Suggested check.
Never claim done over an unstated limitation.

Done when: everything unproven is listed with its risk, or Limitations reads "None".

### 6. Failure modes

Answer the five failure-mode checks (F1-F5) on the diff:

- **F1 invented name** — every function, file and API the diff uses exists; confirm with Read / Grep.
- **F2 scope creep** — the diff is no wider than the request; cut the extra.
- **F3 cascading error** — the fix brought no new bug; run the full suite.
- **F4 context loss** — every earlier constraint still holds; re-read the request.
- **F5 tool misuse** — nothing destructive ran unannounced; review it and announce it.

A check that fails → fix it before declaring done.
Skip only when ALL hold: ≤5 lines · single file · zero logic-bearing (user-facing string text alone counts as zero) · NOT a high-risk path (= rigor tier R1, trivial edit).

Done when: every check holds, or its failure is fixed.

### 7. Compose the evidence block

Fill `templates/evidence-block.md`: the change manifest, the exact command and proof line per check, the limitations, and `## Status` = exactly one of `VERIFIED | PARTIAL | UNVERIFIED` — the literal word finish-work's Pre-merge gates read (PARTIAL / UNVERIFIED block merge).
R1 / R2 (trivial edit / one file + test), a single file, no QA test-case table, nothing to limit → one line: `<command> → PASS: <specific proof>. Status: VERIFIED`.

Evidence log: append the line to `<git-root>/.rolepod/evidence/phase-log.jsonl` chained onto the next command you run anyway (`<cmd> && printf '…' >> phase-log.jsonl`), never as a standalone turn; skip silently outside a git repo.
Verify line: `{"ts":"<iso8601>","phase":"verify","verdict":"pass|partial|fail","evidence":"<command run>"}` — the verdict is the lowercase mapping of the Status word: VERIFIED → `pass`, PARTIAL → `partial`, UNVERIFIED → `fail`, and no other value is valid. Nothing follows an R1 / R2 verify → chain it onto the verify command's own call (`<verify cmd> && printf '…pass…' >> … || printf '…fail…' >> …`).

Done when: the block carries one Status word and the verify line is appended.

## Guardrails

- Claim done with evidence from a run after the last edit. Never "looks right".
- Say what you cannot verify, why, and the risk if wrong. Never let a limitation pass unstated.

A bug-fix and a UI verification, strong vs false-green → `examples/evidence-examples.md`.

## Next phase

- Verify-only ask (no fix, no ship requested) → none; the evidence block is the deliverable.
- Evidence fails → `debug-issue` or `implement-plan`.
- Passes with risk (fails review-code's skip test: >5 lines, multi-file, logic-bearing, or high-risk) → `review-code`, unless the diff already has a report under `.rolepod/evidence/review/` → the next task or `finish-work`.
- Passes, low risk, the plan has unchecked tasks → `implement-plan` next task (Ship asks once per plan).
- Passes, low risk, the plan is exhausted → `finish-work`.
- If neither `review-code` nor `finish-work` is available, attach the evidence block and ask the user whether to ship.
