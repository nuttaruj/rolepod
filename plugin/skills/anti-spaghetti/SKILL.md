---
name: anti-spaghetti
description: Prevent code rot — duplication, dead code, drift, circular dependencies, and creeping complexity. Universal hygiene rules that work across language and framework.
when_to_use: when adding new logic, when a pattern starts repeating, or when a module imports from where it shouldn't
---

# Anti-Spaghetti

Every line reinforces structure or erodes it. Catch rot before spread.

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER add 3rd copy of same pattern. Centralize at occurrence 3, before commit.
2. NEVER add 2nd copy of: auth, permissions, billing, credits, URL validation, SSRF guards, cookies, logging, retries, external API client. 1-copy-or-bug categories.
3. ALWAYS search repo (`rg`, `gitnexus_query`) before creating new helper/type/constant/schema. Found → reuse or extend.

"Just this one place" = the lie that produced every security incident in this category.
</EXTREMELY-IMPORTANT>

## Red Flags — about to skip this skill

| Thought | Meaning |
|---------|---------|
| "Just this one place, centralize next time" | Next time never comes. Copy 2 → copy 5. |
| "Slightly different so can't reuse" | Parameterize existing, don't fork. |
| "Faster to copy-paste" | Lose more time debugging divergence than save now. |
| "Centralizing now is premature" | At occurrence 3 it isn't. At occurrence 1 it is. |
| "`utils.ts` is right place" | Junk-drawer files become spaghetti epicenters. |

## When to use

- About to add helper, type, constant, schema
- Same pattern in 2 files (3 = mandatory centralize)
- Module A imports from B that imports from A
- Found dead code, stale comment, commented-out block
- "Quick" change keeps growing
- Circular import error
- New file could live in 3 places

## How to apply

### 1. Search before create

```bash
rg "function fooBar" src/
rg "type FooBar" src/
gitnexus_query "concept: input validation"
```

Found → reuse or extend. Only create new if truly doesn't fit.

### 2. Three strikes rule

| Occurrences | Action |
|-------------|--------|
| 1 | Inline, no abstraction |
| 2 | Note it, keep inline |
| 3+ | Centralize before commit |

No pre-extract at occurrence 1 — premature abstraction is its own spaghetti.

### 3. Dependency direction

```
features / pages / routes
    ↓
domain / business logic
    ↓
shared utilities / primitives
```

Shared imports from features → not shared, move back.

### 4. Dead code policy

| Code | Action |
|------|--------|
| Unused, you orphaned this PR | Delete |
| Unused, pre-existing | Mention, don't delete unless asked |
| Commented-out block | Delete (git remembers) |
| `// TODO from 2022` | Delete or convert to issue |
| Unused export | Mark, ask if needed elsewhere |

### 5. No "just this one place"

REQUIRES centralization regardless of count:
- Auth / authorization
- URL validation / SSRF
- Cookie handling
- Logging / metrics
- Retry / backoff
- External API client
- Money / credit / billing math
- Crypto
- Tenant / scope filter

2nd copy = security/correctness bug waiting.

### 6. Boundary discipline

Validate at boundaries (HTTP, queue, file parse). Inside trust boundary, types carry guarantee. Don't re-validate every call — noise hides real checks.

## Common mistakes

- `utils.ts` / `helpers.py` as junk drawer (organize by concern)
- Sibling-feature imports instead of via shared layer
- Copy-paste with "refactor later"
- Wrapping stdlib for no behavior change ("just in case")
- Config flag for single-caller branch
- Deprecated path "for backwards compat" with no callers
- Rename `unused` → `_unused` instead of delete
- Building "framework" for 2-call-site abstraction

## Quick reference

| Smell | Fix |
|-------|-----|
| Same 5-line block in 3 files | Extract function |
| Same magic string in 5 places | Extract constant |
| Same shape in 2 schemas | Extract type, derive both |
| File >500 lines, multiple concerns | Split by concern |
| Function >50 lines | Likely >1 thing — split |
| Import cycle | Move shared piece down a layer |
| "I'll need this later" code | Delete; add when needed |
| Comment explaining what code does | Rename until unnecessary |

## After cleanup

Re-run tests. Anti-spaghetti changes = behavior-neutral. Test broke → restored load-bearing thing, reassess.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Pattern only in 2 places now" | 3rd lands within 2 weeks on active codebases. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
