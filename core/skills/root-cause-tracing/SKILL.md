---
name: root-cause-tracing
description: Trace an error upstream from where it fires to where it was actually caused, instead of patching the proximate symptom. Use when a stack trace points at a display / boundary / late-stage symptom (e.g. null pointer in the render layer, but the null was produced three layers up at DB read time), when the same bug keeps recurring with different surfaces, or when a "fix" makes the original error go away but a similar one appears nearby. Standalone tracing primitive that the broader debugging-and-error-recovery skill pulls in.
---

# Root Cause Tracing

Most bug fixes that "don't stick" share one pattern: the fix patched the place where the error became visible, not the place where the bad state was created. The display layer reports `null.name`, the engineer adds `?.name`, ships, and three weeks later a different field on the same null object throws somewhere else.

This skill is the upstream-tracing primitive — recurse from the symptom toward the source until you hit one of three legitimate stopping points. Stop earlier than that and you ship a patch on a patch.

## Fire this skill (not `debugging-and-error-recovery`) when…

`debugging-and-error-recovery` is the broader bug-fix workflow (reproduce → hypothesis → bisect → fix). This skill is the **upstream-tracing primitive** inside that workflow. Pick this one (or invoke it as a sub-step of the broader skill) when:

- The **symptom is downstream of the cause** — e.g. null pointer at the display layer, but the null was produced three layers up at DB-read time
- You need to **trace upstream through multiple layers** to reach the producer
- "First plausible cause" isn't enough — you need the **root**, not the first place that *could* be it
- The same bug keeps **recurring with different surfaces** after each fix at the symptom site

Stay with `debugging-and-error-recovery` (don't drop into this skill) when:

- Bug is at the source already (validation rejecting bad input at the boundary)
- Pure mechanical fix (typo, off-by-one, wrong constant in the same function)
- You haven't reproduced yet — get the repro first, then come back here if needed

## When to use

Trigger this skill when:

- A stack trace points at code that is clearly downstream of where the bad state was introduced (rendering / serializing / asserting an invariant that should have held earlier)
- The same bug recurs with different surfaces after each fix
- A fix makes one error go away and a structurally similar one appears nearby
- You catch yourself adding "defensive" null/undefined/optional handling without knowing why the value can be missing

## When NOT to use

- Error is at the source already (e.g. validation function rejecting bad input at the boundary — that's where bad state is supposed to be rejected; nothing upstream)
- Pure mechanical fix (typo, wrong constant, off-by-one in the same function)
- Time-boxed hotfix where you must stop the bleed first — patch the symptom now, file the root-cause trace as follow-up

## The recursion

### Step 1 — Identify the proximate cause

Where does the error actually fire? Read the stack trace, find the file:line where the assertion / exception / wrong-output happens. This is the **symptom**, not the cause.

### Step 2 — Ask "what made this state possible?"

For the bad state at the proximate cause site (null, wrong type, out-of-range value, stale cache, missing record):

- Who wrote this value last?
- Who could have written it?
- Is the value expected to be valid here, or is it the caller's responsibility to validate?

Tools:
- `gitnexus_impact({ target, direction: "upstream" })` when available — lists callers and data producers
- `git log -p <file>` on the symptom file to see recent state-mutating changes
- Plain reading of the data flow when graph tools unavailable

### Step 3 — Recurse

Move up one layer (caller, data producer, deserializer, database query, external API response). Ask the same question. Repeat until you reach a **legitimate stopping point**:

1. **External input** — value came from user / network / file / env. Fix = validate at the boundary, not at the symptom.
2. **System boundary** — value crossed a process / service / language barrier and was malformed there. Fix = the contract at that boundary.
3. **"It was designed this way"** — the value is legitimately allowed to be in this state at the producer. Fix = the *design*, not the consumer. The consumer was wrong to assume otherwise.

If none of the three apply yet, you have not reached the root — keep recursing.

### Step 4 — Fix at the root, not the symptom

The fix lands at the stopping point. The symptom site may also need a small change (e.g. removing the now-unnecessary defensive check), but the load-bearing fix is upstream.

### Anti-pattern: "first plausible cause"

The seductive trap is stopping at the first layer that *could* be the cause and patching there. Test: ask "if I fix this, can the bad state still arrive here through a different path?" If yes — keep recursing. If no — you're at the root.

## Worked example shape

```
Symptom: TypeError: cannot read property 'email' of null
  at renderUserBadge (ui/user-badge.tsx:42)

Step 1 — Proximate: ui/user-badge.tsx:42, user is null
Step 2 — Who passes user? <UserBadge user={currentUser} /> from layout.tsx
Step 3 — Where does currentUser come from? useCurrentUser() hook
Step 4 — Hook: returns null while loading. Designed to.
Step 5 — Stopping point: "designed this way" — hook documents null-while-loading.
         The CONSUMER (UserBadge) assumed the value was always present.
Fix: at the design boundary — UserBadge handles loading state, OR layout
     gates rendering until currentUser resolves. NOT a `?.email` at line 42.
```

The `?.email` patch would have shipped a render-empty-badge bug to production for every page load.

## Tools

- **GitNexus impact (upstream)** when indexed — fastest data-flow lookup
- **`git log -p` on the symptom file** when GitNexus unavailable — shows recent state mutations
- **Manual data-flow reading** as fallback — slower but always works

Pair with `gitnexus-debugging` skill for graph-driven traces.

## Pairs with

- `debugging-and-error-recovery` — broader debugging skill that includes this primitive among others (reproduction, bisection, hypothesis-testing). Use this skill for the upstream-trace step; use the broader one for end-to-end debugging.
- **Defense-in-depth** — once you find the root, the strongest fix is "make the bad state structurally impossible" (type-level, schema-level, invariant-level), not just patched at one site. Root cause + structural impossibility = the bug class is dead.

## Influence

Adapted from [obra/superpowers](https://github.com/obra/superpowers) `systematic-debugging/root-cause-tracing.md`. The three-stopping-points framing is the load-bearing idea. Worked-example structure and the "first plausible cause" anti-pattern naming are rolepod additions.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "The fix at the symptom works, ship it" | Works for the case you tested. Bad state can still arrive via a different path you didn't test. |
| "Recursing upstream is too expensive" | Recursing once is cheap. Recurring this bug three more times across the codebase is expensive. |
| "Adding `?.` here is just defensive coding" | Defensive coding is the patch-on-patch pattern. Defense-in-depth is a structural fix at the boundary. |
| "The root is in third-party code, can't fix there" | Yes you can — wrap or validate at the boundary where third-party meets your code. That IS the stopping point. |
| "I already know the cause without tracing" | The trace exists to falsify your guess. If the trace agrees, you've lost 2 minutes. If it disagrees, you've avoided a wrong fix. |

Default when rationalizing: run the trace anyway. The asymmetric cost is large — symptom patches that ship to prod are the most expensive bugs to discover later.
