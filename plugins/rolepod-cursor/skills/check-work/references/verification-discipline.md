<!-- Deep verification playbook for check-work. -->
<!-- Loaded on demand from SKILL.md §4 + Iron Rule 2. -->
<!-- Anti-self-deception kit. The author of work is the worst verifier. -->

# Verification discipline

The hardest verification problem is not the test — it is honesty about whether the test actually ran in this turn, against the actual change, with assertions strong enough to fail when wrong. This file is the kit for catching yourself.

## Iron Law

**No completion claims without fresh verification evidence run in THIS message.**

If you didn't run the command in this turn, you cannot claim it passes. Yesterday's green run does not count. The agent reporting `DONE` does not count. The linter passing does not count. Only output you produced in this turn counts.

## Gate function — before any completion wording

```
IDENTIFY  — what command proves this claim?
RUN       — execute the full command, fresh, complete
READ      — full output, exit code, failure count
VERIFY    — does output confirm the claim?
            NO  → state actual status with evidence
            YES → state claim with evidence
CLAIM     — only now, with evidence inline
```

Skip any step = lying, not verifying.

## Common failures — claim vs requires vs not-sufficient

| Claim | Requires | NOT sufficient |
|---|---|---|
| Tests pass | Test command output: `0 failed` | Previous run, "should still pass", "I'm confident" |
| Linter clean | Linter output: `0 errors` | Partial check, "looks ok" |
| Build succeeds | Build command: `exit 0` | Linter passing, logs "look good" |
| Bug fixed | Original failing test now passes + reverting the fix makes it fail | "Code changed, assumed fixed" |
| Regression test works | Red-green-revert cycle verified end-to-end | Test passes once |
| Agent completed | Diff inspected, evidence in manifest verified | Agent reports `success` |
| Requirements met | Each spec criterion → named evidence | "All tests pass" |
| UI works | Browser observation (screenshot / DOM / interaction) | Typecheck / build / "should render" |
| Schema migration safe | Forward + rollback dry run + row-count delta | "DDL applied, looks ok" |
| Performance ok | Before/after benchmark, p95 captured | "Feels fast" / "should be fine" |

Each row's "Requires" column is the only evidence that counts. The "NOT sufficient" column is the rationalization you will be tempted to make.

## Red-green-revert cycle (regression test protocol)

A regression test for a bug must follow this cycle. Skip any step → you don't know if the test tests the fix.

```
1. Write the test that captures the bug behavior
2. Run it — must FAIL with the bug present (RED)
3. Apply the fix
4. Run it — must PASS (GREEN)
5. Revert the fix (git stash / comment out)
6. Run it — MUST FAIL AGAIN (proves the test is testing the fix, not something else)
7. Restore the fix
8. Run it — must PASS (final GREEN)
```

If step 6 passes — the test is not actually testing the bug. The assertion is weak, or the test exercises unrelated code, or the bug was never the cause. Tighten the test before claiming the bug is fixed.

The "mentally flip `==` to `!=`" check is a cheap proxy for this; the revert cycle is the strong version. Use the revert cycle for any non-trivial bug fix.

## Anti-rationalization wording catalog

These wordings are the symptom of skipping the gate function. Trip wires:

| Phrase | Means | Action |
|---|---|---|
| "Should pass now" | Haven't run it | Run it |
| "Probably works" | Haven't verified | Verify |
| "Seems to be working" | Looked at output, didn't check exit code or count | Read output properly |
| "Looks right" | Eyeballed code, didn't execute | Execute |
| "I'm confident" | Confidence is not evidence | Get evidence |
| "Should still work" | Yesterday's run | Run fresh |
| "Great!" / "Perfect!" / "Done!" | Pre-completion celebration | Stop celebrating; run the command |
| "Just this once" | Rationalizing skipping discipline | No exceptions; run it |
| "The agent said success" | Trusting subagent self-report | Inspect diff + verify independently |
| "I'm tired, this is enough" | Exhaustion is not a verification mode | Stop; commit only what you ran |

If you catch yourself about to type any of these before evidence is captured in this turn — delete the response, run the command, then rewrite.

## Rationalization prevention — common excuses + reality

| Excuse | Reality |
|---|---|
| "It should work, I changed the right line" | Run the test |
| "I'm confident — the change is small" | Confidence ≠ evidence |
| "Just this once — it's only a typo" | Then it costs nothing to verify |
| "Linter passed, so the build will pass" | Linter ≠ compiler ≠ runtime |
| "Build passed, so tests will pass" | Build ≠ test |
| "Tests passed, so requirements are met" | Tests prove the test, not the spec |
| "Agent said success" | Agents lie about completion. Verify independently |
| "I already verified earlier in the conversation" | If not in THIS turn, doesn't count |
| "The change is so small it can't break anything" | Most regressions land in "small" changes |
| "Different word so the rule doesn't apply" | Spirit over letter; rule applies |

## Subagent completion claims

Subagents will report `COMPLETED`, `DONE`, or `success` and be wrong. Treat agent self-report as a hypothesis, not a conclusion.

Verification protocol for subagent work:

```
1. Read the diff (git diff against the brief's base SHA)
2. Run the test the brief named, fresh, in this turn
3. Check exit code + failure count yourself
4. Match the change against the brief's done criteria
5. Only then accept the manifest
```

If the diff is empty but the manifest says `DONE` → rejected, the subagent did nothing.
If the diff exists but the test wasn't run by you → not verified.
If the test was run but failed → manifest is lying about `DONE`, reject.

## When verification is genuinely impossible

Sometimes verification really cannot happen: no network, no test infra, no browser, no permission to run a destructive command. Be honest:

```
Cannot verify: <exactly what>
Reason: <why — no infra / no permission / no observable signal>
Risk if wrong: <what breaks, who is affected, recoverability>
Suggested check: <command or step the user can run to confirm>
```

Do not claim done. Do not say "should work". State the limitation with the four lines above, in that order.

## The bottom line

The author of work is the worst verifier of work. The mind that wrote the bug is the mind most motivated to believe the fix worked. This file exists because that motivation is stronger than discipline most days.

Run the command. Read the output. Then claim the result.

No shortcuts.
