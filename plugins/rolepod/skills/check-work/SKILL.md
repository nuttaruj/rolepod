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
2. UI changes require a browser observation (screenshot, MCP devtools, Playwright). A passing typecheck does not prove the UI works.
3. If you cannot verify, STATE explicitly: what you cannot verify, why, and the risk if you are wrong.
4. NEVER ask the user to take a screenshot for you when you have browser automation available.
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
- Evidence passes and risk exists → `review-code`.
- Evidence passes and low risk → `finish-work`.

## Inputs to gather

- The diff (file list + changed regions)
- The acceptance criteria from the spec / plan / task
- Available verification tools (test runner, build, browser MCP, Playwright, curl)
- The CI lane this change must pass

## Workflow

### 1. Pick the right evidence type

| Change type | Required evidence |
|-------------|-------------------|
| Logic / bug fix | Test pass (the failing test that proved the bug) |
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

### 3. UI verification when relevant

Open the page, render the component, interact with the affected flow. Use MCP browser tools, Playwright, or local devtools — never ask the user to do it for you when tools are available. For the tool order and what to observe, see `references/ui-verification.md`.

### 4. Watch for false greens

A passing test with weak assertions is a false green. Mentally flip `==` to `!=`. If the test still passes, the assertion is too weak — tighten it before trusting. For weak-vs-strong assertion patterns by type, see `references/assertion-strength.md`.

### 5. State limitations honestly

If you cannot verify (no test infra, no network, no browser):
```
Cannot verify: <what>
Reason: <why>
Risk if wrong: <impact>
Suggested check: <command / step user can run>
```

### 6. Failure-mode gate (F1-F5)

Before declaring done, clear all five — any "yes" → fix it first:
```
F1: Hallucinated a fn / file / API that does not exist? → Read / Grep to verify
F2: Scope creep — diff wider than the request?          → cut the extra
F3: Cascading error — the fix introduced a new bug?     → run the full suite
F4: Context loss — forgot an earlier constraint?        → re-read the request
F5: Tool misuse — ran something destructive unannounced? → review + announce
```
Skip this gate only when ALL hold: ≤5 lines · single file · zero
logic-bearing · NOT a high-risk path.

### 7. Compose the evidence block

Fill `templates/evidence-block.md` — exact commands, the specific proof line per check, the change manifest, and honest limitations.

## If a matching Rolepod agent is available

Delegate verification depth to the specialist:

- `qa-tester` for test suite design and failure analysis
- `performance-engineer` for p95 / p99 / bundle / benchmark proof
- `security-engineer` for exploit-blocked proof
- `devops-sre` for CI lane behavior and deploy smoke

Brief: change manifest + acceptance criteria + available tools.

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Run the tests for the touched module
2. Run typecheck and lint if the stack has them
3. For UI: take a screenshot or read the DOM with browser tools
4. For API: curl the endpoint and verify the response shape
5. For schema / migration: dry-run forward and rollback
6. For docs / spec: render output, check links, scan for placeholders
7. Compose an evidence block in the response
8. If a verification path is missing, state it explicitly with risk

## Output

The evidence block is the canonical artifact: `templates/evidence-block.md`. It carries the change manifest, per-check evidence, limitations, and the status verdict. Do not restate the block shape here; the template is the single source.

## Examples

Non-blocking — read only when unsure whether your evidence is strong enough:
- `examples/evidence-examples.md` — a bug-fix and a UI verification, each a strong/false-green pair with a "why good wins" table. Read the whole file; the contrast is the lesson.

## References

Load only when the task needs it:
- `references/ui-verification.md` — how to verify a UI change: tool order, what to observe
- `references/assertion-strength.md` — spot a weak assertion that passes with the bug present

## Hard stops

- Tests fail → fix or report; do not claim done
- UI change with no browser observation → not verified
- "It compiled" is offered as the only evidence for runtime behavior → not verified
- Subagent claims COMPLETED but evidence is absent → reject

## Full Rolepod enhancement

Full Rolepod improves this phase by adding hooks that nag for evidence on completion claims, the qa-tester floor, browser-MCP integration for UI verification, and CI lane configuration that catches missing evidence in PR review.

## Next phase

- If the work needs review, continue to `review-code`.
- If the work is review-already-done or trivial-no-review, continue to `finish-work`.
- If neither is available, attach the evidence block directly and ask the user whether to ship.
