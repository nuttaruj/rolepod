---
name: check-work
description: Use after a change is made and before claiming the work is done — prove it with evidence (tests, build, typecheck, curl, logs, screenshot, browser). State limitations explicitly when verification is not possible. Phase = Verify.
when_to_use: after editing code, configs, content, or any artifact, and before reporting completion to the user or moving to the next phase
tier: 1
phase: verify
---

# Check Work

Prove the change behaves as intended with concrete evidence before claiming done.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER claim done without evidence. "Looks right" is not evidence.
2. Verification must be FRESH — run AFTER the last change to the tree. No run since the last edit → you cannot claim it passes; yesterday's green and "should still work" do not count. **Evidence cache:** tree unchanged since a pass recorded THIS session (same `git status` + `git diff` — neither sees untracked / ignored content, so hash or diff any untracked input the check reads) → cite that run's command + output and state "tree unchanged since" instead of re-running; ANY new edit invalidates the cache.
3. UI changes require a browser observation (screenshot, devtools, Playwright). A passing typecheck does not prove the UI works.
4. Cannot verify → STATE what you cannot verify, why, and the risk if you are wrong.
5. NEVER ask the user for a screenshot when you have browser automation available.
</EXTREMELY-IMPORTANT>

## When to use

- A code / config / content change is complete · a subagent returned COMPLETED · a bug fix needs regression-clean confirmation · a UI change needs visual proof · a spec / plan / docs change needs link and reference proof.

Skip when:
- A no-op (comment, whitespace, docstring) with no behavior risk · the user said "just commit, I'll verify".

## Boundary

Owns: fresh evidence that the change works — tests, build, curl, logs, screenshot / browser — and the risk statement when evidence is impossible. Runner emits JUnit/XUnit XML (`pytest --junitxml` / `--reporter=junit` / surefire)? Prefer it: cite counted totals + failed test names via `rolepod-junit <xml>` (installed launcher) or `scripts/junit-summary.sh` (source repo / plugin `scripts/`); counted results beat prose claims.

Does not own: new design / code issues beyond verification failures · merge / branch fate · rewriting the implementation unless evidence fails.

Hand off:
- Evidence fails → `debug-issue` or `implement-plan`.
- Passes with risk (fails review-code's skip test: >5 lines, multi-file, logic-bearing, or high-risk) → `review-code`.
- Passes, low risk, plan has unchecked tasks → `implement-plan` next task (Ship asks once per plan).
- Passes, low risk, plan exhausted → `finish-work`.

## Workflow

Inputs: the diff · acceptance criteria from spec / plan / task · available tools (runner, build, browser, curl) · the CI lane this change must pass.

### 1. Pick the evidence type

| Change type | Required evidence |
|-------------|-------------------|
| Logic / bug fix | Red-green-revert: failing test → fix → green → prove RED without the fix → green. Run the red proof as ONE call (`references/verification-discipline.md` §Revert in one call): throwaway `git worktree`, reverse-apply the source-only patch, run the one named test — non-zero exit WITH the named assertion in the output (a collection / import error, a skip, or a 0-test run is not red); remove the worktree. Worktree cannot run the test → three-step revert in place. A test that does not fail without the fix is not testing the fix. |
| New feature | Happy + edge + error tests pass |
| Refactor | Existing suite green before and after |
| Schema / migration | Forward + rollback dry run + row-count delta |
| API contract | Contract test + downstream consumer smoke |
| UI change | Browser observation (screenshot or DOM read) |
| Performance | Before / after benchmark |
| Security | Exploit repro blocked, audit log clean |
| Config / infra | Smoke + restart confirmation |
| Docs / spec | Link check, render output, no placeholder leak |

### 2. Run the evidence

Capture the exact command and the lines that prove the claim, not all output. A failure already in the baseline (recorded before the first edit) is a limitation, not a regression — cite the baseline line; a failure absent from it is this change's.

### 2b. Aggregate child-plugin evidence

Sibling plugins (`rolepod-uiproof`, `rolepod-wplab`, any Extension Protocol v1 plugin) write manifests automatically when the parent marker `.rolepod/parent-active` exists:

```bash
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo .)
find "$ROOT/.rolepod/evidence" -name manifest.json -type f 2>/dev/null
```

Each `manifest.json` carries `plugin`, `skill`, `phase`, `status` (pass/fail/warn), `summary`, `artifacts[]`. Keep only dirs whose `<ts>` postdates your last relevant edit and whose `skill` / `summary` names this task's target; older or unidentifiable runs are a named limitation. Any KEPT `fail` → verify fails as a whole (surface the summary + failing artifact path). All KEPT `pass` / `warn` → verify passes; list warnings inline. Reference child artifacts by relative path from the manifest directory.

### 3. UI verification

Open the page, render the component, interact with the affected flow — browser tools, Playwright, or local devtools; never ask the user when tools are available. Tool order + what to observe: `references/ui-verification.md`.

### 4. Anti-false-green discipline

- **Flip the assertion** — mentally flip `==` to `!=`; still passes → too weak, tighten.
- **Wording trip wires** — "should pass", "probably works", "seems right", "Great!", "Perfect!", "Done!" before running the command → stop, run it first.
- **False equivalences** — linter clean ≠ build passes ≠ tests pass ≠ requirements met ≠ agent COMPLETED. Each layer proves only what it ran.
- **Stale evidence** — a claim must come from a run AFTER the last change in this unit of work; re-run, never re-quote.
- **Attribution** — "the user approved X" must trace to a specific message stating X; a general "go ahead" authorizes nothing it did not name.

Weak-vs-strong assertions by type: `references/assertion-strength.md`. Common-failure + rationalization tables: `references/verification-discipline.md`.

### 4b. Spec back-reference

For every acceptance criterion, name the evidence that verifies it — `<criterion> → <evidence command + result line>` in the evidence block. A criterion with no named evidence = unverified, however many other tests pass.

### 5. State limitations honestly

No test infra, no network, no browser → the four-field block (Cannot verify / Reason / Risk if wrong / Suggested check) from `templates/evidence-block.md`; never claim done over an unstated limitation.

### 6. Failure-mode gate (F1-F5)

{{INCLUDE: core/fragments/gates-f1-f5.md}}

### 7. Compose the evidence block

Fill `templates/evidence-block.md` — exact commands, the proof line per check, the change manifest, honest limitations. R1/R2 (trivial edit / one file + test) single file with nothing to limit → the one-line form in Output.

## If a matching Rolepod agent is available

- `qa-tester` — test suite design / failure analysis
- `performance-engineer` — p95/p99 / bundle / benchmark proof
- `security-engineer` — exploit-blocked proof
- `devops-sre` — CI lane behavior / deploy smoke

Brief: change manifest + acceptance criteria + available tools. More than one evidence type → dispatch the verifiers in ONE message; each proves an independent claim on the same frozen change.

## If no matching agent is available

Execute as Lead: tests for the touched module + typecheck / lint (scope ladder: task Command while building → module suite here → full suite only on high-risk or at merge via CI; no CI → that scope runs locally at Ship; map changed paths → subset by import graph / naming before defaulting wider) → UI: screenshot or DOM read; API: curl + assert response shape → schema: dry-run forward + rollback; docs: render + link-check + placeholder scan → compose the block with any missing path + risk.

## Output

The evidence block is the canonical artifact: `templates/evidence-block.md` — change manifest, per-check evidence, limitations, and `## Status` = exactly one of `VERIFIED | PARTIAL | UNVERIFIED`, the literal word finish-work's merge gate reads (PARTIAL / UNVERIFIED block merge). R1/R2 single file, no QA test-case table, nothing to limit → one line: `<command> → PASS: <specific proof>. Status: VERIFIED`.

{{INCLUDE: core/fragments/phase-log.md}}
Verify line: `{"ts":"<iso8601>","phase":"verify","verdict":"pass|partial|fail","evidence":"<command run>"}` — the verdict is the lowercase mapping of the Status word: VERIFIED → `pass`, PARTIAL → `partial`, UNVERIFIED → `fail`, and no other value is valid. Nothing follows an R1/R2 verify → chain it onto the verify command's own call (`<verify cmd> && printf '…pass…' >> … || printf '…fail…' >> …`).

**P1 traceability.** A QA test-case table in play (this session or under `.rolepod/evidence/`) → every P1 row's ID must appear in a passing test's name: `grep` the RUNNER output for `TC<n>` (source presence proves authorship, not a pass; skipped / not-collected = missing). A P1 with no passing test = `verdict:"fail"` plus Status `PARTIAL` or `UNVERIFIED`, naming the missing IDs.

## References

Load only when needed:
- `references/ui-verification.md` — tool order, what to observe.
- `references/assertion-strength.md` — a weak assertion that passes with the bug present.
- `references/verification-discipline.md` — common failures, rationalization prevention, red-green-revert protocol.
- `examples/evidence-examples.md` — a bug-fix and a UI verification, strong vs false-green.

## Hard stops

- Tests fail → fix or report; not done.
- UI change with no browser observation → not verified.
- "It compiled" as the only runtime evidence → not verified.
- Subagent claims COMPLETED with no evidence → reject.
- About to say "should pass" / "looks right" / "Done!" without a run that post-dates the last edit (or a verified unchanged-tree cache cite) → stop; Iron Rule 2.
- An acceptance criterion with no named evidence → not verified.

## Next phase

- Needs review → `review-code`. Review done or trivial → `finish-work`, unless the plan has unchecked tasks → `implement-plan` first.
- If neither is available, attach the evidence block and ask the user whether to ship.
