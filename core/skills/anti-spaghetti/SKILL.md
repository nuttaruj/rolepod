---
name: anti-spaghetti
description: Prevent code rot — duplication, dead code, drift, circular dependencies, and creeping complexity. Apply when adding new logic, when a pattern starts repeating, or when a module imports from where it shouldn't. Universal hygiene rules that work across language and framework.
---

# Anti-Spaghetti

Codebases rot one "just this once" at a time. This skill catches the rot before it spreads. Every line you add either reinforces structure or erodes it — there's no neutral edit.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER add a 3rd copy of the same pattern. Centralize at occurrence 3, before commit. ห้ามฝืน.
2. NEVER add a 2nd copy of: auth, permissions, billing, credits, URL validation, SSRF guards, cookies, logging, retries, external API client. These are 1-copy-or-bug categories.
3. ALWAYS search the repo (`rg`, `gitnexus_query`) before creating a new helper / type / constant / schema. Found existing → reuse or extend. No exceptions.

"Just this one place" is the lie that produced every security incident in this category. The second copy is the bug.
</EXTREMELY-IMPORTANT>

## Red Flags — you are about to skip this skill

| Red flag (your thought) | What it actually means |
|-------------------------|------------------------|
| "Just this one place, I'll centralize next time" | Next time never comes. Copy 2 becomes copy 5. |
| "It's slightly different so I can't reuse" | "Slightly different" = parameterize the existing helper, not fork it. |
| "Faster to copy-paste than to find the original" | You will lose more time debugging the divergence than you save now. |
| "Centralizing now is premature abstraction" | At occurrence 3 it is not premature. At occurrence 1 it is. Know which. |
| "This `utils.ts` file is the right place" | Junk-drawer files become spaghetti epicenters. Organize by concern. |

## When to use

- About to add a helper, type, constant, or schema
- Noticed the same pattern in 2 files (3 = mandatory centralize)
- Module A wants to import from module B that already imports from A
- Found dead code, stale comment, or commented-out block
- "Quick" change keeps growing because the design fights back
- Circular import error appears
- New file you're writing feels like it could live in 3 different places

## How to apply

### 1. Search before you create

Before writing a new helper, util, type, validator, or constant — search the repo:

```
rg "function fooBar" src/
rg "type FooBar" src/
gitnexus_query "concept: input validation"
```

Found existing? **Reuse or extend.** Only create new if the existing one truly doesn't fit.

### 2. Three strikes rule

| Occurrences | Action |
|-------------|--------|
| 1 | Inline, no abstraction |
| 2 | Note it (mental or comment), keep inline |
| 3+ | Centralize before commit |

Don't pre-extract on first occurrence — premature abstraction is its own spaghetti.

### 3. Dependency direction

Layered architecture flows one way. Common layers (top imports from below, never reverse):

```
features / pages / routes
    ↓
domain / business logic
    ↓
shared utilities / primitives
```

If shared imports from features → that helper isn't shared, it's feature-specific. Move it back.

### 4. Dead code policy

| Code | Action |
|------|--------|
| Unused, you orphaned it this PR | Delete |
| Unused, pre-existing | Mention in summary, don't delete unless asked |
| Commented-out block | Delete (git history remembers) |
| `// TODO from 2022` | Delete or convert to issue |
| Unused export | Mark, ask if needed elsewhere |

### 5. No "just this one place"

These categories REQUIRE centralization regardless of count:
- Authentication / authorization
- URL validation / SSRF guards
- Cookie handling
- Logging / metrics emission
- Retry / backoff logic
- External API client setup
- Money / credit / billing math
- Cryptographic operations
- Tenant / scope filtering

A second copy of any of these = a security or correctness bug waiting to fire.

### 6. Boundary discipline

Validate at system boundaries (HTTP request, queue message, file parse). Inside the trust boundary, types carry the guarantee. Don't re-validate every function call — that's noise that hides real checks.

## Common mistakes

- Creating `utils.ts` / `helpers.py` as a junk drawer (organize by concern, not by type)
- Importing from a sibling feature instead of going through shared layer
- Copy-paste with "I'll refactor later" — later never comes
- Wrapping a stdlib function for no behavior change ("just in case we want to swap")
- Adding a config flag for a single-caller branch
- Keeping deprecated path "for backwards compat" in code nobody else calls
- Renaming `unused` → `_unused` instead of deleting
- Building a "framework" inside the app for a 2-call-site abstraction

## Quick reference

| Smell | Fix |
|-------|-----|
| Same 5-line block in 3 files | Extract function |
| Same magic string in 5 places | Extract constant |
| Same shape in 2 schemas | Extract type, derive both |
| File over 500 lines, multiple concerns | Split by concern |
| Function over 50 lines | Likely doing >1 thing — split |
| Import cycle | Move shared piece down a layer |
| "I'll need this later" code | Delete; add when actually needed |
| Comment explaining what code does | Rename until comment is unnecessary |

## After cleanup

Re-run tests. Anti-spaghetti changes should be behavior-neutral. If a test broke, you removed something load-bearing — restore and reassess.

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "Pattern only appears in 2 places right now" | 3rd repetition lands within 2 weeks on active codebases. Centralize at 2, not after the 3rd bug. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
