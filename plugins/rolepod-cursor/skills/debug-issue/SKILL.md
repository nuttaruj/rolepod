---
name: debug-issue
description: Use when something is broken — error appears, test fails, build breaks, output is wrong, regression returns. Reproduce, trace upstream to root cause, write a failing test, ship a minimal fix. Phase = Build / Debug.
---

# Debug Issue

Canonical debug workflow. Replace guess-and-check with disciplined narrowing: reproduce → trace upstream to root → write failing test → minimal fix → verify regression-clean.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER fix before reproducing locally with a deterministic command. No repro = guess.
2. NEVER stop at the first symptom fix. Trace upstream to a legitimate stopping point (external input, system boundary, "designed this way"), then fix at root.
3. ALWAYS roll back your last action first when the error appeared right after your change.
4. ALWAYS write the failing test you wish had existed before shipping the fix.
</EXTREMELY-IMPORTANT>

## When to use

- Test was green, now red
- Unrecognized error / unfamiliar stack
- Wrong output, no exception thrown
- Build broke after a change
- Works locally, fails in CI (or the reverse)
- Two fix attempts did not stick
- Symptom keeps returning at a different surface
- About to add defensive `?.` / null-check / try-catch without knowing why

## Boundary

Owns:
- Unknown failure triage: reproduce, trace upstream, identify root cause, write a failing regression test, minimal fix.

Does not own:
- Planned feature work with known requirements.
- Broad refactor / simplification.
- Shipping decision.

Return / hand off:
- Requirements unclear → `write-spec`.
- Fix spans multiple files / needs sequencing → `write-plan`.
- Minimal fix applied → `check-work`.

## Inputs to gather

- Exact error message (literal quote)
- Throw site (file:line) and stack trace
- When it started failing (last green commit, deploy, data event)
- Steps to reproduce or the failing test command
- The diff since last green

## Workflow

### 1. Stop and read

Capture the exact error, the throw site, and the stack trace before editing. The real cause is often mid-stack, not at the top.

### 2. Reproduce reliably

One command, same failure every time. Pytest: `pytest path/test_x.py::name -v`. API: exact failing `curl`. UI: steps + browser + console. Intermittent: raise the rate first — loop the trigger, add stress, inject sleeps — until you have a 50%+ signal. A 1% flake is not yet debuggable. For the flake cause decision tree, see `references/flake-triage.md`.

If you cannot repro locally, reproduce in CI / staging. Do not fix what you cannot see fail.

### 3. Rollback reflex

If the bug appeared right after your change, undo first. Confirm green. Re-apply piece by piece.

If the bug predates your changes and the last-good commit is unknown, `git bisect run <test>` finds the breaking commit automatically.

### 4. One hypothesis at a time

State one hypothesis: `<variable / state / condition> is <value> because <upstream cause>`. Test the cheapest falsifier first — log, breakpoint, read the called function, check the fixture. Don't spray fixes. Tag every debug log with a unique prefix (`[DBG-a4f2]`) so cleanup is one grep.

Track experiments in `templates/hypothesis-ledger.md` — one row each. A new hypothesis must hold against every prior row, not just the last run.

### 5. Trace upstream

Symptom → caller → caller's caller, until one of:
- External input (user, API, env, file, DB row)
- System boundary (network, OS, third-party lib)
- "Designed this way" (intentional invariant)

Stop at one of those, not at the first place the value looks wrong. For the upstream-walk technique and the symptom-vs-root distinction, see `references/root-cause-tracing.md`.

### 6. Write the failing test

The test you wish had existed. It must fail before your fix and pass after. Tighten until a one-character regression would break it.

### 7. Minimal fix

Smallest change that turns the failing test green without breaking the rest of the suite. No "while I'm here" refactor.

### 8. Verify regression-clean

Run the full module suite (or full suite for high-risk surfaces). Confirm no new red.

## If a matching Rolepod agent is available

Delegate to the closest specialist:

- `qa-tester` for failing-test design and flake analysis
- `security-engineer` if the symptom is auth / token / injection
- `performance-engineer` for latency / memory regressions
- `devops-sre` for infra / deploy / CI failures

Brief: exact error, stack, repro command, hypothesis, files touched since last green.

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Capture the exact error and stack
2. Reproduce with one deterministic command
3. Roll back the last change if the timing matches
4. State one hypothesis at a time
5. Trace upstream until a legitimate stopping point
6. Write a failing test that captures the bug
7. Make the smallest fix that turns it green
8. Run the full touched suite to confirm no regression

## Output

The debug report is the canonical artifact: `templates/debug-report.md`. It carries the error, repro, root cause, the failing test, the fix, and verification. Do not restate the report shape here; the template is the single source.

## Examples

Non-blocking — read only when unsure whether a fix reaches the root:
- `examples/debug-examples.md` — a symptom-vs-root fix and a retry-hack-vs-triaged flake fix, each a good/bad pair with a "why good wins" table. Read the whole file; the contrast is the lesson.

## References

Load only when the task needs it:
- `references/root-cause-tracing.md` — the upstream walk: trace a bad value to where it is born
- `references/flake-triage.md` — diagnose an intermittent test instead of retrying it

## Hard stops

- Cannot reproduce after 30 minutes → escalate or expand repro environment
- Two upstream traces lead to contradictory causes → re-read; you missed an interaction
- Fix passes the test but the symptom returns → root cause is wrong, trace further
- Defensive null-check without a known cause → not a fix; remove and trace again

## Full Rolepod enhancement

Full Rolepod improves this phase by adding the qa-tester floor for test depth, hooks that flag silenced exceptions, and the adversarial reviewer pattern for fixes on high-risk surfaces.

## Next phase

- If `check-work` is available, continue there to verify the fix with evidence.
- If `check-work` is not available, attach the test command output, the diff, and any UI / log evidence directly to the user response.
