---
name: debugging-and-error-recovery
description: Systematic root-cause debugging when tests fail, builds break, or behavior diverges from expectation. Apply when an error appears, when output is wrong, or when something worked before and stopped. Replaces guess-and-check with a disciplined narrowing process.
---

# Debugging and Error Recovery

Structured narrowing process to converge on cause, not chase symptoms.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER fix before reproducing locally with a deterministic command. No repro = guess.
2. NEVER fix first symptom and stop. Trace to root; decide explicitly: fix root or fix symptom.
3. ALWAYS rollback last action first when error appears immediately after your change.
</EXTREMELY-IMPORTANT>

## Red Flags — you're about to skip this skill

| Thought | Reality |
|---------|---------|
| "I know what's wrong, let me try X" | Verify by reading or running first. |
| "Can't reproduce, but I'll fix it" | You'll fix the wrong thing. |
| "Tests pass locally, must be env" | Name the env delta. |
| "Tried 3 things, let me try 5 more" | Stop after 2 fails. Re-frame. |
| "Try/except to make error go away" | Silenced exceptions = tomorrow's incident. |

## Boundary vs `root-cause-tracing`

This skill = full workflow (reproduce → hypothesis → bisect → fix → regression). `root-cause-tracing` = upstream-tracing primitive used inside step 8. Symptom downstream of cause (null at display layer caused by bad DB read) → invoke `root-cause-tracing` first.

## When to use

- Green test now red
- Unrecognized error
- Wrong behavior, no exception
- Build broke after change
- Works locally, fails in CI (or reverse)
- 2 fix attempts didn't work
- Symptom keeps returning

## How to apply

### 1. Stop and read

Error + stack usually point straight to it. Capture before editing:
- Exact error message
- Throw site (file:line)
- Stack trace (trigger often mid-stack)
- When it started failing

### 2. Reproduce reliably

Single command, same failure every time.
- Test: `pytest path/test_x.py::test_name -v`
- API: exact failing `curl`
- UI: steps + browser + console
- Intermittent: note frequency, find trigger

Can't repro locally → repro in CI/staging. Don't fix what you can't see fail.

### 3. Rollback reflex

Bug appeared right after your change? Undo, confirm green, re-apply piece by piece.

### 4. One hypothesis at a time

State it:
```
Hypothesis: input X is null because upstream Y returns undefined when Z.
```

Cheapest falsifier: log/print, breakpoint, read called function, check fixture.

Don't spray fixes. Pick one, test, accept/reject, move on.

### 5. Bisect when stuck

- **Git bisect** — find introducing commit
- **Code bisect** — comment out half the suspect block, recurse
- **Input bisect** — shrink input; boundary tells trigger

### 6. Read the data, not the code

Code looks right, behavior wrong → data is lying. Print actual values, check DB rows directly (not ORM), check network payloads (not in-memory objects).

### 7. Question every assumption

- Function actually called? (Add log; no log = not called)
- Env var set? (Print it)
- Right version deployed? (Check SHA)
- Cache stale? (Bypass)
- `it.skip` vs `it.only` typo?

### 8. Fix root cause, not symptom

| Symptom fix | Root fix |
|-------------|----------|
| Wrap try/catch, ignore | Why does it throw? |
| `if (x) return` to skip | Why is x falsy? |
| Bump retries | Why does first fail? |
| Pin old version | Why new version fails? |

### 9. Add a regression test

Bug got past existing tests. Write the one that would have caught it. Now it stays dead.

## Common error patterns

| Pattern | Likely cause |
|---------|--------------|
| `undefined is not a function` | Optional chain missed; wrong import; typo |
| `Cannot read property X of null` | Async race; missing default; deleted record |
| `connection refused` | Service down; wrong port; firewall |
| `permission denied` | Auth scope; file mode; missing role |
| Timeout | Deadlock; N+1; missing index; slow upstream |
| Works locally, fails in CI | Env var; isolation; timezone; case sensitivity |
| Worked yesterday, fails today | Recent commit; data drift; cert expiry; quota |
| Heisenbug | Race; ordering; flaky test |

## When stuck (~30 min no progress)

1. Restate problem out loud
2. `mempalace_kg_query` for similar past bugs
3. Read docs for the library throwing
4. Ask — bring error + stack + tried + hypothesis

## Quick reference

```
1. Read error + stack
2. Reproduce reliably
3. Rollback recent change?
4. State hypothesis
5. Cheapest falsifier
6. Stuck? Bisect
7. Locate root cause
8. Fix root, not symptom
9. Add regression test
10. Verify all tests green
```

Each step gates the next.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I see the bug, I'll fix it" | What you see is the symptom. Root-cause discipline costs minutes; symptom fixes cost weeks of follow-up. |
| "Simple change, doesn't need this" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). |
| "Time pressure, skip once" | 5 min saved = 50 min debugging later. |

Default: run anyway. Bounded cost; skip-cost is not.
