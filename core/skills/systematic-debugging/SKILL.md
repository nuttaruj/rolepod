---
name: systematic-debugging
description: Reproduce → trace upstream to root cause → write failing test → minimal fix → verify regression-clean. Canonical bug / failure / root-cause workflow. Combines repro-discipline + upstream tracing in one path so Lead doesn't have to pick between two debugging skills.
when_to_use: when an error appears, a test fails, a build breaks, output is wrong, something worked before and stopped, the same bug keeps recurring with different surfaces, or a fix made one error go away and a similar one appeared nearby
---

# Systematic Debugging

Canonical debugging workflow. Replaces guess-and-check with disciplined narrowing: **reproduce → trace upstream to root → write failing test → minimal fix → verify clean**.

Folds `debugging-and-error-recovery` (full workflow) and `root-cause-tracing` (upstream-tracing primitive) into one route so the picker doesn't have two doors for the same task.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER fix before reproducing locally with a deterministic command. No repro = guess.
2. NEVER stop at first symptom fix. Trace upstream until you hit a legitimate stopping point (external input, system boundary, "designed this way"). Then fix at root.
3. ALWAYS rollback last action first when error appears immediately after your change.
4. ALWAYS write the failing test you wish had existed before shipping the fix.
</EXTREMELY-IMPORTANT>

## Red Flags — about to skip this skill

| Thought | Reality |
|---|---|
| "I know what's wrong, let me try X" | Verify by reading or running first. |
| "Can't reproduce, but I'll fix it" | You'll fix the wrong thing. |
| "Tests pass locally, must be env" | Name the env delta concretely. |
| "Tried 3 things, let me try 5 more" | Stop after 2 fails. Re-frame, don't escalate. |
| "Try/except to make error go away" | Silenced exceptions = tomorrow's incident. |
| "Add `?.` and ship" | Defensive patch ≠ root fix. Recurs at the next field. |
| "Recursing is expensive" | Recursing once is cheap; recurring bug 3× across codebase is expensive. |

## When to use

- Test was green, now red
- Unrecognized error / unfamiliar stack
- Wrong behavior, no exception thrown
- Build broke after a change
- Works locally, fails in CI (or reverse)
- 2 fix attempts didn't stick
- Symptom keeps returning with different surface
- Adding "defensive" null / undefined / try-catch handling without knowing why

## The full loop

### 1. Stop and read

Capture before editing:
- Exact error message
- Throw site (`file:line`)
- Stack trace (real cause often mid-stack, not at top)
- When it started failing (last green commit / deploy / data event)

### 2. Reproduce reliably

One command, same failure every time:
- Test: `pytest path/test_x.py::test_name -v`
- API: exact failing `curl`
- UI: steps + browser + console
- Intermittent: note frequency, find trigger

Can't repro locally → repro in CI/staging. Don't fix what you can't see fail.

### 3. Rollback reflex

Bug appeared right after your change? Undo, confirm green, re-apply piece by piece.

### 4. One hypothesis at a time

```
Hypothesis: <variable / state / condition> is <value> because <upstream cause>.
```

Cheapest falsifier first: log/print, breakpoint, read called function, check fixture.

Don't spray fixes. Pick one. Test. Accept or reject. Move on.

### 5. Bisect when stuck

- **Git bisect** — find the introducing commit
- **Code bisect** — comment out half the suspect block, recurse
- **Input bisect** — shrink input; boundary tells trigger

### 6. Trace upstream to root

For bad state at symptom site (null / wrong type / out-of-range / stale cache / missing record), recurse upstream:

```
Step 1: Identify proximate cause (file:line where error fires) — SYMPTOM, not cause.
Step 2: Ask "what made this state possible?"
        - Who wrote this value last?
        - Who *could* have written it?
        - Is value expected valid here, or is caller's job to validate?
Step 3: Recurse one layer up (caller → producer → deserializer → DB query → external API).
        Same question. Repeat until one of three LEGITIMATE STOPPING POINTS:

        (a) External input — value came from user / network / file / env.
            → Fix = validate at boundary.
        (b) System boundary — value crossed process / service / language barrier,
            malformed there.
            → Fix = contract at that boundary.
        (c) "Designed this way" — value legitimately allowed in this state at
            the producer; consumer was wrong to assume otherwise.
            → Fix = the design (consumer code, type, schema).

        None of three apply → not at root, keep recursing.

Step 4: Fix at the stopping point, NOT at symptom site.
```

Anti-pattern: stopping at first plausible cause and patching. Falsifier: *"if I fix this, can bad state still arrive through a different path?"* Yes → keep recursing.

Tools:
- `gitnexus_impact({ target, direction: "upstream" })` when indexed — fastest
- `git log -p <file>` on symptom file — fallback
- Manual data-flow reading — last resort

### 7. Read the data, not the code

Code looks right, behavior wrong → data is lying. Print actual values, check DB rows directly (not ORM), check network payloads (not in-memory objects).

### 8. Question every assumption

- Function actually called? (Add log; no log = not called)
- Env var set? (Print it)
- Right version deployed? (Check SHA)
- Cache stale? (Bypass)
- `it.skip` vs `it.only` typo?

### 9. Fix root cause, not symptom

| Symptom fix | Root fix |
|---|---|
| Wrap try / catch, ignore | Why does it throw? |
| `if (x) return` to skip | Why is `x` falsy? |
| Bump retries | Why does first attempt fail? |
| Pin old version | Why does new version fail? |
| `?.email` defensive patch | What made the upstream return null? |

### 10. Write a regression test

The bug got past existing tests. Write the one that would have caught it. Now it stays dead.

Pair: `test-driven-development` skill for TDD style; the regression test goes red BEFORE the fix lands, green AFTER.

### 11. Verify regression-clean

- Original symptom: gone (re-run the repro command from step 2)
- Full test suite: green (not just the targeted test)
- Adjacent files: no new console errors, no new lint warnings

## Worked example — root-cause recursion

```
Symptom: TypeError: cannot read property 'email' of null
  at renderUserBadge (ui/user-badge.tsx:42)

Step 1 — Proximate: ui/user-badge.tsx:42, user is null
Step 2 — Who passes user? <UserBadge user={currentUser} /> from layout.tsx
Step 3 — Where does currentUser come from? useCurrentUser() hook
Step 4 — Hook returns null while loading. Designed to.
Step 5 — Stopping point: "designed this way" — hook documents null-while-loading.
         CONSUMER (UserBadge) assumed user always present.
Fix: at design boundary — UserBadge handles loading state, OR layout
     gates rendering until currentUser resolves. NOT a `?.email` patch.

Test: render UserBadge with user=null → expect loading state visible.
      Render with user={...} → expect email visible.
```

The `?.email` patch would have shipped "render empty badge" silently on every page load.

## Common error patterns

| Pattern | Likely cause |
|---|---|
| `undefined is not a function` | Optional chain missed; wrong import; typo |
| `Cannot read property X of null` | Async race; missing default; deleted record |
| `connection refused` | Service down; wrong port; firewall |
| `permission denied` | Auth scope; file mode; missing role |
| Timeout | Deadlock; N+1; missing index; slow upstream |
| Works locally, fails in CI | Env var; isolation; timezone; case sensitivity |
| Worked yesterday, fails today | Recent commit; data drift; cert expiry; quota |
| Heisenbug | Race; ordering; flaky test |

## When stuck (~30 min no progress)

1. Restate problem out loud (or in writing)
2. `mempalace_kg_query` for similar past bugs in this repo
3. Read docs for the library throwing
4. Ask the user — bring error + stack + tried + hypothesis (don't ask blind)

## Quick reference

```
1. Read error + stack
2. Reproduce reliably
3. Rollback last change?
4. State hypothesis
5. Cheapest falsifier
6. Stuck? Bisect
7. Trace upstream to root (3 stopping points)
8. Read the data, not just the code
9. Question every assumption
10. Fix at root, not symptom
11. Write regression test
12. Verify regression-clean (repro + full suite)
```

Each step gates the next.

## Pairs with

- `test-driven-development` — regression test is the failing test you wished existed
- `code-simplification` — once root cause found, simplest fix wins
- `post-change-verify` — verification gate after fix lands
- `gitnexus-debugging` — graph-driven upstream trace when GitNexus indexed

## Influence

Folds two prior skills:
- `debugging-and-error-recovery` — full reproduce → fix → regression workflow
- `root-cause-tracing` — upstream-tracing primitive with three legitimate stopping points (adapted from [obra/superpowers](https://github.com/obra/superpowers) `systematic-debugging/root-cause-tracing.md`)

Both old skills remain as compatibility shims pointing here.

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "I see the bug, I'll fix it" | What you see is the symptom. Root-cause discipline costs minutes; symptom fixes cost weeks of follow-up. |
| "Simple change, doesn't need this" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). |
| "Symptom fix works, ship it" | Works for the tested case. Bad state can still arrive via untested paths. |
| "Recursing is expensive" | Recursing once is cheap; recurring this bug 3× is expensive. |
| "`?.` is defensive coding" | Defensive coding = patch-on-patch. Defense-in-depth = structural fix at the producer. |
| "Root is in third-party code" | Wrap or validate at the boundary where third-party meets your code. |
| "I know the cause without tracing" | Trace exists to falsify the guess. Agrees → lost 2 minutes. Disagrees → avoided wrong fix. |
| "Time pressure, skip once" | 5 min saved = 50 min debugging later. |

Default: run the loop anyway. Bounded cost; skip-cost is not.
