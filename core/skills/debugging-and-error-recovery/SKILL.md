---
name: debugging-and-error-recovery
description: Systematic root-cause debugging when tests fail, builds break, or behavior diverges from expectation. Apply when an error appears, when output is wrong, or when something worked before and stopped. Replaces guess-and-check with a disciplined narrowing process.
---

# Debugging and Error Recovery

Bugs hide in the gap between what you think the code does and what it actually does. The fix is to close that gap — not by guessing, but by checking. This skill imposes structure on debugging so you converge on the cause instead of chasing symptoms.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER apply a fix before reproducing the bug locally with a deterministic command. No repro = no diagnosis = no fix, only guesses.
2. NEVER fix the first symptom and stop. Trace to the root cause and decide explicitly whether to fix root or symptom — both are valid, silent symptom-patching is not.
3. ALWAYS rollback last action first when an error appears immediately after your change. Don't chain downstream fixes on top of a broken state.

Guess-and-check debugging is how 4-hour bugs turn into 4-day bugs.
</EXTREMELY-IMPORTANT>

## Red Flags — you are about to skip this skill

| Red flag (your thought) | What it actually means |
|-------------------------|------------------------|
| "I think I know what's wrong, let me just try X" | You don't know — verify by reading code or running it. |
| "Can't reproduce, but I'll fix it anyway" | You will fix the wrong thing. Get a repro first. |
| "Tests pass on my machine, must be environmental" | "Environmental" is a diagnosis, not a hand-wave. Name the env delta. |
| "I've tried 3 things, let me try 5 more" | After 2 failed attempts, stop and re-frame. More guesses ≠ progress. |
| "Just add a try/except to make the error go away" | Silenced exceptions are tomorrow's mystery production incident. |

## Boundary vs `root-cause-tracing`

This skill = the broader debugging workflow (reproduce → hypothesis → bisect → fix → regression test). `root-cause-tracing` = the focused upstream-tracing primitive used **inside** step 8 (fix root cause, not symptom).

**When symptom is downstream of cause** (null pointer at the display layer caused by bad data at the DB query, recurring bug under different surfaces), invoke `root-cause-tracing` first — then continue this workflow with the trace result. Don't try to handle deep upstream tracing inline here; that's what the dedicated primitive is for.

## When to use

- A test that was green is red
- An error message you don't immediately recognize
- Behavior is wrong but no exception thrown
- Build broke after a change
- Worked locally, fails in CI (or vice versa)
- Two attempts at a fix didn't work
- Symptom keeps reappearing after each "fix"

## How to apply

### 1. Stop and read

The error message and stack trace usually contain the answer or point straight to it. Read every line. Resist the urge to immediately edit.

- What is the exact error message?
- Where is the throw site (file:line)?
- What's the stack trace? (often the trigger is mid-stack, not the top)
- When did this start failing? (test runner timestamp, last green commit)

Write these down before changing anything.

### 2. Reproduce reliably

You cannot fix a bug you cannot reproduce. Get to a single command that fails the same way every time.

- Failing test? Run it in isolation: `pytest path/test_x.py::test_name -v`
- API failure? Get the exact `curl` that fails
- UI bug? Steps to reproduce, browser, console output
- Intermittent? Note frequency — every run? 1 in 10? Find the trigger.

If you can't reproduce locally → reproduce in CI / staging / production environment. Don't fix what you can't see fail.

### 3. Rollback reflex

Did the bug appear immediately after **your** last change? Undo it first, confirm green, then re-apply piece by piece.

This is often the entire fix. Don't chain downstream patches onto a broken upstream change.

### 4. Form one hypothesis at a time

State it explicitly:

```
Hypothesis: input X is null because upstream Y returns undefined when Z.
```

Then design the cheapest test that would falsify it:
- Add a log/print at the suspect site
- Run with debugger breakpoint
- Read the function being called
- Check the test fixture / input

Don't form 5 hypotheses and "spray fixes." Pick one, test it, accept or reject, then move on.

### 5. Bisect when stuck

If hypotheses keep failing → narrow by bisection:

- **Git bisect** — find the commit that introduced the regression: `git bisect start; git bisect bad; git bisect good <known-good-sha>`
- **Code bisect** — comment out half the suspect block. Still fails? Bug is in the other half. Recurse.
- **Input bisect** — does it fail with smaller input? Trim until it doesn't. The boundary tells you the trigger.

Bisection finds bugs that hypothesis-driven debugging misses.

### 6. Read the data, not the code

When you believe code is correct but behavior is wrong, the data is lying somewhere:

- Print or log the actual values at suspect points
- Check DB rows directly (not through ORM)
- Check API request/response in network tab
- Check serialized payload (not the in-memory object)

Most "impossible" bugs turn out to be: the data wasn't what you assumed.

### 7. Question every assumption

What you "know" about the system might be stale:

- Is the function actually called? (Add a log; if no log, it's not called)
- Is the env var actually set? (Print it)
- Is the right version deployed? (Check the SHA / build ID)
- Is the cache stale? (Bypass it)
- Is there a typo in the test name? (`it.skip` vs `it.only` accidents)

Verify, don't assume.

### 8. Fix root cause, not symptom

Once located:

| Symptom fix | Root fix |
|-------------|----------|
| Wrap in try/catch and ignore | Why does it throw? Fix that |
| Add `if (x) return` to skip the case | Why is x falsy when it shouldn't be? |
| Bump retries | Why is the first attempt failing? |
| Pin to old version | Why does new version fail? |

Symptom fixes ship the bug forward in disguise. Root fixes end it.

### 9. Add a regression test

The bug got past existing tests. Write the test that would have caught it. Failing → fix → passing. Now the bug stays dead.

## Common error patterns

| Pattern | Likely cause |
|---------|--------------|
| `undefined is not a function` | Optional chain missed; wrong import; typo |
| `Cannot read property X of null` | Async race; missing default; deleted record |
| `connection refused` | Service not running; wrong port; firewall |
| `permission denied` | Auth scope; file mode; missing role |
| Timeout | Deadlock; N+1 query; missing index; external slow |
| Works locally, fails in CI | Env var; test isolation; timezone; case sensitivity |
| Worked yesterday, fails today | Recent commit; data drift; cert expiry; quota hit |
| Heisenbug (varies by run) | Race condition; ordering assumption; flaky test |

## When you're stuck

After ~30 minutes with no progress:

1. **Step away** — restate the problem out loud (or in chat). Often the act of explaining surfaces the gap.
2. **Check past sessions** — `mempalace_kg_query` for similar bugs
3. **Read the docs** — for the library throwing, not Stack Overflow guesses
4. **Ask** — bring: error, stack, what you tried, current hypothesis. Not "it doesn't work."

## Common mistakes

- Editing before reading the error message in full
- Multiple hypotheses, multiple fixes, lost track of what changed
- Wrapping the throw in try/catch and calling it fixed
- "It's flaky, let me retry the test" — flaky = real bug, just intermittent
- Pin / disable / skip instead of root-cause
- Fix without regression test (bug returns)
- Trusting the comment / docs over the runtime behavior
- Trusting your assumption over the actual data

## Quick reference — debug loop

```
1. Read error + stack
2. Reproduce reliably
3. Rollback recent change?
4. State hypothesis
5. Cheapest experiment to falsify
6. Stuck? Bisect
7. Locate root cause
8. Fix root, not symptom
9. Add regression test
10. Verify all tests green
```

Each step gates the next. Don't skip ahead.

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "I see the bug, I'll just fix it" | What you 'see' is usually the symptom. Root-cause discipline costs minutes; fixing the symptom costs follow-up PRs for weeks. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
