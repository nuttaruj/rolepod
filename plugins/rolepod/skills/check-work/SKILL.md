---
name: check-work
description: Use after a change is made and before claiming the work is done — prove it with evidence (tests, build, typecheck, curl, logs, screenshot, browser). State limitations explicitly when verification is not possible. Phase = Verify.
when_to_use: after editing code, configs, content, or any artifact, and before reporting completion to the user or moving to the next phase
tier: 1
phase: verify
---

# Check Work

Verify-phase entry skill. Prove the change behaves as intended with concrete evidence before claiming done.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER claim done without evidence. "Looks right" is not evidence.
2. Verification must be FRESH in this turn. If you have not run the command in this message, you cannot claim it passes. Yesterday's green run does not count. "Should still work" does not count.
3. UI changes require a browser observation (screenshot, MCP devtools, Playwright). A passing typecheck does not prove the UI works.
4. If you cannot verify, STATE explicitly: what you cannot verify, why, and the risk if you are wrong.
5. NEVER ask the user to take a screenshot for you when you have browser automation available.
</EXTREMELY-IMPORTANT>

## When to use

- A code, config, or content change is complete
- A subagent returned COMPLETED — verify before trusting
- A bug fix needs regression-clean confirmation
- A UI change needs visual / interactive proof
- A spec / plan / docs change needs link and reference proof

Skip when:
- The change is a no-op (comment, whitespace, docstring) with no behavior risk
- The user explicitly said "just commit, I'll verify"

## Boundary

Owns:
- Fresh evidence that the change works: tests, build, curl, logs, screenshot / browser.
- Verification limits and the risk statement when evidence is impossible.

Does not own:
- Finding new design / code issues beyond verification failures.
- Merge / PR / branch fate.
- Rewriting implementation unless evidence fails.

Return / hand off:
- Evidence fails → `debug-issue` or `implement-plan`.
- Evidence passes and risk exists (fails review-code's skip test: >5 lines, multi-file, logic-bearing, or a high-risk surface) → `review-code`.
- Evidence passes and low risk (review-code's skip test passes) → `finish-work`.

## Inputs to gather

- The diff (file list + changed regions)
- The acceptance criteria from the spec / plan / task
- Available verification tools (test runner, build, browser MCP, Playwright, curl)
- The CI lane this change must pass

## Workflow

### 1. Pick the right evidence type

| Change type | Required evidence |
|-------------|-------------------|
| Logic / bug fix | Red-green-revert cycle: failing test → fix → green → revert fix → MUST fail → restore fix → green. A test that does not fail without the fix is not testing the fix. |
| New feature | Happy + edge + error test pass |
| Refactor | Existing suite green before and after |
| Schema / migration | Forward + rollback dry run + row count delta |
| API contract | Contract test + downstream consumer smoke |
| UI change | Browser observation (screenshot or DOM read) |
| Performance | Before / after benchmark |
| Security | Exploit repro blocked, audit log clean |
| Config / infra | Smoke + restart confirmation |
| Docs / spec | Link check, render output, no placeholder leak |

### 2. Run the evidence

Run the test, build, curl, browser observation. Capture the exact command and the relevant output (not all of it — the lines that prove the claim).

### 2b. Aggregate child plugin evidence

If sibling plugins ran during this work (`rolepod-uiproof`, `rolepod-wplab`, or any future Extension Protocol v1 plugin), check for their output under `<git-root>/.rolepod/evidence/`:

```bash
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo .)
find "$ROOT/.rolepod/evidence" -name manifest.json -type f 2>/dev/null
```

Each `manifest.json` describes one child run with fields `plugin`, `skill`, `phase`, `status` (pass/fail/warn), `summary`, and `artifacts[]`. Aggregation rules:

- Any child manifest with `status: fail` → verify fails as a whole. Surface the summary + path to the failing artifact.
- All `pass` or `warn` → verify passes; list warnings inline so they don't get lost.
- Child artifacts (screenshots, HARs, reports) are referenced by relative path from the manifest directory — include those paths in the evidence block.

Schema details and the full protocol live in `docs/EXTENSION-PROTOCOL.md` (rolepod source repo; the aggregation rules above are self-sufficient). Children write manifests automatically when they detect the rolepod parent marker (`.rolepod/parent-active`); no manual wiring needed.

### 3. UI verification when relevant

Open the page, render the component, interact with the affected flow. Use MCP browser tools, Playwright, or local devtools — never ask the user to do it for you when tools are available. For the tool order and what to observe, see `references/ui-verification.md`.

### 4. Anti-false-green discipline

A passing test with weak assertions is a false green. Three trip wires:

- **Flip-the-assertion check** — mentally flip `==` to `!=`. If the test still passes, assertion is too weak. Tighten before trusting.
- **Wording trip wires** — about to say "should pass", "probably works", "seems right", "Great!", "Perfect!", "Done!" before running the command? Stop. Run it first. Pre-completion wording without fresh evidence is the same lie in two registers.
- **Common false equivalences** — "linter clean ≠ build passes". "Build passes ≠ tests pass". "Tests pass ≠ requirements met". "Agent reports COMPLETED ≠ verified". Each layer proves only what it actually ran.

Weak-vs-strong assertion patterns by type: `references/assertion-strength.md`. Common-failure table + rationalization-prevention table: `references/verification-discipline.md`.

### 4b. Spec-back-reference

For every acceptance criterion in the spec / plan / task, name the evidence that verifies it. A criterion with no named evidence = unverified, regardless of how many other tests pass. Mirror of plan's spec-coverage trace, applied to evidence instead of tasks.

Format inline in the evidence block: `<criterion> → <evidence command + result line>`.

### 5. State limitations honestly

If you cannot verify (no test infra, no network, no browser), fill the four-field limitation block — Cannot verify / Reason / Risk if wrong / Suggested check — shaped in `templates/evidence-block.md`; never claim done over an unstated limitation.

### 6. Failure-mode gate (F1-F5)

Before declaring done, clear all five:

```
F1: Hallucinated a fn / file / API that does not exist?  → Read / Grep to verify
F2: Scope creep — diff wider than the request?           → cut the extra
F3: Cascading error — the fix introduced a new bug?      → run the full suite
F4: Context loss — forgot an earlier constraint?         → re-read the request
F5: Tool misuse — ran something destructive unannounced? → review + announce
```
Any "yes" → fix before declaring done. Skip only when ALL hold: ≤5 lines · single file · zero logic-bearing · NOT a high-risk path.

### 7. Compose the evidence block

Fill `templates/evidence-block.md` — exact commands, the specific proof line per check, the change manifest, and honest limitations.

## If a matching Rolepod agent is available

Delegate verification depth:

- `qa-tester` — test suite design / failure analysis
- `performance-engineer` — p95/p99/bundle/benchmark proof
- `security-engineer` — exploit-blocked proof
- `devops-sre` — CI lane behavior / deploy smoke

Brief: change manifest + acceptance criteria + available tools.

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Run tests for the touched module + typecheck/lint if the stack has them
2. UI → screenshot or DOM read via browser tools; API → curl + assert response shape
3. Schema/migration → dry-run forward + rollback; docs → render + link-check + placeholder scan
4. Compose evidence block; state any missing verification path with risk

## Output

The evidence block is the canonical artifact: `templates/evidence-block.md`. It carries the change manifest, per-check evidence, limitations, and the status verdict. Do not restate the block shape here; the template is the single source.

## Examples

Non-blocking — read only when unsure whether your evidence is strong enough:
- `examples/evidence-examples.md` — a bug-fix and a UI verification, each a strong/false-green pair with a "why good wins" table. Read the whole file; the contrast is the lesson.

## References

Load only when the task needs it:
- `references/ui-verification.md` — how to verify a UI change: tool order, what to observe
- `references/assertion-strength.md` — spot a weak assertion that passes with the bug present
- `references/verification-discipline.md` — common-failures table (Claim / Requires / Not Sufficient), rationalization-prevention table, red-green-revert protocol, anti-rationalization wording catalog

## Hard stops

- Tests fail → fix or report; do not claim done
- UI change with no browser observation → not verified
- "It compiled" is offered as the only evidence for runtime behavior → not verified
- Subagent claims COMPLETED but evidence is absent → reject
- About to say "should pass" / "looks right" / "Great!" / "Done!" without running the command fresh in this turn → stop; Iron Rule 2
- Acceptance criterion has no named evidence in the evidence block → not verified, even if other tests pass

## Full Rolepod enhancement

Full Rolepod improves this phase by adding hooks that nag for evidence on completion claims, the qa-tester floor, browser-MCP integration for UI verification, and CI lane configuration that catches missing evidence in PR review.

## Next phase

- If the work needs review, continue to `review-code`.
- If the work is review-already-done or trivial-no-review, continue to `finish-work`.
- If neither is available, attach the evidence block directly and ask the user whether to ship.
