---
name: root-cause-tracing
description: Trace an error upstream from where it fires to where it was actually caused, instead of patching the proximate symptom. Use when a stack trace points at a display / boundary / late-stage symptom (e.g. null pointer in the render layer, but the null was produced three layers up at DB read time), when the same bug keeps recurring with different surfaces, or when a "fix" makes the original error go away but a similar one appears nearby. Standalone tracing primitive that the broader debugging-and-error-recovery skill pulls in.
---

# Root Cause Tracing

Bug fixes that don't stick share a pattern: patched where error became visible, not where bad state was created. Display reports `null.name` → engineer adds `?.name` → ships → 3 weeks later different field on same null throws elsewhere.

Upstream-tracing primitive — recurse from symptom to source until you hit one of three legitimate stopping points.

## Fire this skill (not `debugging-and-error-recovery`) when…

`debugging-and-error-recovery` = broader workflow. This skill = upstream-tracing primitive inside it. Pick this when:

- Symptom downstream of cause (null at display layer, produced 3 layers up at DB read)
- Need to trace upstream through multiple layers
- "First plausible cause" isn't enough — need root
- Same bug recurs with different surfaces after each fix

Stay with broader skill when:
- Bug at source already (validation rejecting bad input at boundary)
- Pure mechanical (typo, off-by-one)
- Haven't reproduced yet — get repro first

## When to use

- Stack points at code clearly downstream of where bad state was introduced
- Same bug recurs with different surfaces
- Fix makes one error go away, structurally similar appears nearby
- You're adding "defensive" null/undefined handling without knowing why

## When NOT to use

- Error at source already (boundary validation rejecting bad input)
- Pure mechanical fix
- Time-boxed hotfix — patch symptom now, file follow-up

## The recursion

### Step 1 — Identify proximate cause

Where does error fire? Read stack, find file:line. This is **symptom**, not cause.

### Step 2 — Ask "what made this state possible?"

For bad state at symptom site (null, wrong type, out-of-range, stale cache, missing record):
- Who wrote this value last?
- Who could have written it?
- Is value expected valid here, or is caller's job to validate?

Tools:
- `gitnexus_impact({ target, direction: "upstream" })` when available
- `git log -p <file>` on symptom file
- Plain data-flow reading when graph unavailable

### Step 3 — Recurse

Move up one layer (caller, producer, deserializer, DB query, external API). Same question. Repeat until one of three **legitimate stopping points**:

1. **External input** — value came from user / network / file / env. Fix = validate at boundary.
2. **System boundary** — value crossed process/service/language barrier, malformed there. Fix = contract at that boundary.
3. **"Designed this way"** — value legitimately allowed in this state at producer. Fix = the design (consumer was wrong to assume otherwise).

None of three apply → not at root, keep recursing.

### Step 4 — Fix at root, not symptom

Fix lands at stopping point. Symptom site may need small change (remove now-unnecessary defensive check), but load-bearing fix is upstream.

### Anti-pattern: "first plausible cause"

Stopping at first layer that *could* be cause and patching. Test: "if I fix this, can bad state still arrive through a different path?" Yes → keep recursing.

## Worked example

```
Symptom: TypeError: cannot read property 'email' of null
  at renderUserBadge (ui/user-badge.tsx:42)

Step 1 — Proximate: ui/user-badge.tsx:42, user is null
Step 2 — Who passes user? <UserBadge user={currentUser} /> from layout.tsx
Step 3 — Where does currentUser come from? useCurrentUser() hook
Step 4 — Hook: returns null while loading. Designed to.
Step 5 — Stopping point: "designed this way" — hook documents null-while-loading.
         CONSUMER (UserBadge) assumed always present.
Fix: at design boundary — UserBadge handles loading state, OR layout
     gates rendering until currentUser resolves. NOT a `?.email` patch.
```

The `?.email` patch would have shipped render-empty-badge bug for every page load.

## Tools

- **GitNexus impact (upstream)** when indexed — fastest
- **`git log -p` on symptom file** — when GitNexus unavailable
- **Manual data-flow reading** — fallback

Pair with `gitnexus-debugging` for graph-driven traces.

## Pairs with

- `debugging-and-error-recovery` — broader skill that includes this primitive among others
- **Defense-in-depth** — strongest fix: make bad state structurally impossible (type/schema/invariant), not just patched at one site

## Influence

Adapted from [obra/superpowers](https://github.com/obra/superpowers) `systematic-debugging/root-cause-tracing.md`. Three-stopping-points framing = load-bearing idea.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Symptom fix works, ship it" | Works for tested case. Bad state can arrive via untested paths. |
| "Recursing is expensive" | Recursing once is cheap; recurring this bug 3 times across codebase is expensive. |
| "`?.` is defensive coding" | Defensive coding = patch-on-patch. Defense-in-depth = structural fix at boundary. |
| "Root is in third-party code" | Wrap or validate at boundary where third-party meets your code. |
| "I know the cause without tracing" | Trace exists to falsify guess. Agrees = lost 2 min. Disagrees = avoided wrong fix. |

Default: run trace anyway. Symptom patches in prod = most expensive bugs to find later.
