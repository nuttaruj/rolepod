---
name: post-change-verify
description: Prove a code change works with evidence (test pass, screenshot, curl, log) before reporting completion.
when_to_use: '"verify change", "evidence after edit", "verify build", "verify task done", "show test pass output"'
---

# Verification — proving your change works

**Scope:** verify YOUR code change (post-edit evidence).
**NOT this file:** confirming facts before claiming → rule `always-on/verify-first.md`. Test planning → rule `test/testing.md`.

UI verification: skills `webapp-testing`, `browser-testing-with-devtools`.

Read when: about to verify code change / report task done.

## Iron Law

<EXTREMELY-IMPORTANT>
**NO COMPLETION CLAIM WITHOUT FRESH VERIFICATION EVIDENCE IN THIS MESSAGE.**

If you haven't run the verification command in this message, you cannot claim it passes. Previous run in earlier message ≠ fresh. "Should pass" ≠ pass. Linter clean ≠ tests pass. Agent self-report ≠ verified.

Violating the letter = violating the spirit. Different wording ("seems to work" / "logic looks right" / "the fix should hold") = same violation.
</EXTREMELY-IMPORTANT>

## Gate function — before ANY completion / "done" / "fixed" claim

```
1. IDENTIFY: What command proves this claim?
2. RUN:      Execute the full command — fresh, complete, this message
3. READ:     Full output. Check exit code. Count failures.
4. VERIFY:   Does output confirm the claim?
              NO  → state actual status with evidence, do NOT claim done
              YES → state claim WITH evidence (command + output snippet)
5. ONLY THEN make the claim
```

Skip any step = lying, not verifying.

## Red flag words — STOP if you're about to type these without fresh evidence

- "should work" / "should pass" / "should be fine"
- "probably" / "likely" / "I think"
- "seems to" / "looks right" / "appears to"
- "this is done" / "fix is in" / "all green"
- "" / "" / "" — any expression of satisfaction before verification command ran in current message
- "trust me" / "I'm confident" / "it's a small change"

Any of these → STOP, run gate function, then speak.

## Claim → proof mapping

| Claim | Sufficient proof | NOT sufficient |
|-------|------------------|----------------|
| Tests pass | Test command output: 0 failures, this message | Previous run, "should pass", linter green |
| Linter clean | Linter output: 0 errors, this message | "I fixed the warnings" |
| Build succeeds | Build command: exit 0, this message | "Type-check passed" |
| Bug fixed | Reproducer test was red → now green, both runs shown | "Code changed, assumed fixed" |
| Regression test works | Red-green cycle in same diff (test fails without fix, passes with) | Test passes once |
| Agent completed task | Diff inspected + verify command ran | Agent's "success" report |
| Requirements met | Line-by-line spec checklist + verify command | "Tests passing" |
| UI works | Screenshot + console clean + interaction confirmed | "Page renders" |

## Core rule

Every implementation ends with **evidence**. Smallest command that proves changed behavior. Widen as risk grows.

Can't verify → state why + risk. **Don't claim success without proof.**

## Evidence by change type

| Change | Verify with |
|--------|-------------|
| Logic / function | Unit test pass output |
| API endpoint | `curl` / Postman / integration response |
| DB migration | Dry run + rollback check + row count delta |
| UI / frontend | Browser screenshot + console clean + network OK |
| CSS / styling | Screenshot at multiple viewports |
| Background task | Log / queue state / task result |
| Config / env | Restart + functional smoke |
| Refactor | Tests pass before AND after |
| Performance | Before/after metric (p95 / bundle / etc.) |
| Type-only | `tsc --noEmit` / `mypy` clean |

## UI — drive browser yourself

**NEVER ask user for screenshot.** Order:

1. **Playwright via Bash** — `chromium.launch_persistent_context(user_data_dir=...)`. First run headed → user logs in → cookies persist.
2. **`webapp-testing` skill**
3. **`browser-testing-with-devtools`** skill
4. **DevTools paste** last resort

`mcp__Claude_in_Chrome__*` not connected → Playwright. Don't pause to chase MCP setup.

### Preview tools (Claude Code preview MCP)

If `preview_*` available:
1. `preview_start` — launch dev server
2. `preview_eval` — reload if needed (skip if HMR active)
3. `preview_console_logs` / `preview_logs` / `preview_network` — errors
4. `preview_snapshot` — content + structure
5. `preview_inspect` — CSS values
6. `preview_click` / `preview_fill` → snapshot to confirm
7. `preview_resize` — responsive / dark mode
8. `preview_screenshot` — visual proof

Skip irrelevant steps.

## Test scope — widen as needed

```
Targeted    → 1-2 tests covering changed path
↓ shared / public surface
Module      → all tests in changed module
↓ multiple modules
Integration → critical paths
↓ high-risk (auth/billing/migrations)
Full suite  → before merge
```

## Integration vs Unit

| | Unit | Integration |
|---|---|---|
| Speed | Fast | Slow |
| Scope | Function isolated | Multi-component real deps |
| Mocks | Yes (deps) | Minimal — real DB/cache |
| Best for | Logic paths, edges | Mock/prod divergence, contracts, races |
| Risk | Mocks diverge | Flaky, harder debug |

**Balance**: unit for business logic depth. Integration for critical paths (auth/payments/migrations/external/locks).

**Never mock DB in integration tests.** Mock/prod divergence burns.

## Goal-driven verification

| Task | Verify by |
|------|-----------|
| Add validation | Invalid input → expect rejection |
| Fix bug | Reproducing test was failing → now passing |
| Add feature | New test for happy path + edges |
| Refactor | Existing tests pass unchanged |
| Performance | Metric before vs after |

## Reporting to user

```
Changed: [what]
Verified: [how — command + output snippet]
Risk: [what this doesn't cover]
Next: [what user should do]
```

Example:
```
Changed: hold_credit() now returns 409 on race
Verified: pytest test_credit_race.py::test_concurrent_hold → 1 passed
Risk: Doesn't cover Redis failover
Next: Ship — gate is green
```

## Common mistakes — DO NOT

- Use red flag words ("should work" / "looks right" / "seems to") before running gate function in this message
- Cite previous-message test run as proof for current claim — re-run, paste fresh output
- Express satisfaction ("", "", "all green") before verify command ran in current message
- Ask user to verify UI when you can drive browser
- Skip verification on "trivial" change
- Mock DB in integration
- Verify only happy path
- Hide failed test output
- Treat agent's self-report as verification — inspect diff + run verify yourself

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "Looks right to me" | Reviewing the diff isn't verification. Run the command. |
| "Tests passed locally before, no need to re-run" | Re-run after the fix lands. State counts. |
| "Trivial change, skip" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). Skip rule is mechanical (≤5 lines / single file / zero logic / not high-risk), not "I think it's trivial". |
| "I'll let CI catch it" | CI catches regressions slowly. Local verify catches them now and saves a round-trip. |
| "Can't drive browser easily" | Playwright / Chrome MCP both available. Asking the user for a screenshot is the last resort, not the default. |
| "Evidence section adds noise" | Evidence-free claims are the noise. One short paste of pass output beats a paragraph of confidence. |
