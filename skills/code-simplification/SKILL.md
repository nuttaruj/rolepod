---
name: code-simplification
description: Refactor for clarity without changing behavior. Apply when code works but is hard to read, when nesting is deep, when a function is doing too much, or when the design fights you on every change. Behavior-preserving — every change is provable by tests staying green.
---

# Code Simplification

Working code that's hard to read is a tax every future change pays. This skill is the inverse of feature work: zero new behavior, smaller mental footprint. Tests stay green from start to finish — that's the proof you didn't change anything that mattered.

## When to use

- Function over ~50 lines, doing more than one thing
- Nesting depth ≥ 4
- Comment explaining what code does (instead of why)
- Variable named `data`, `tmp`, `result`, `obj`
- "I'll come back to this" — you're back, simplify it now
- Adding a feature feels disproportionately hard — design pushback signal
- Code review found the logic but couldn't follow it
- Onboarding a new teammate keeps tripping on the same file

## How to apply

### Pre-flight check

- Tests exist for the behavior? If no, **write them first** (test-driven-development skill). You can't safely refactor without a green safety net.
- Run tests, confirm green
- Commit (clean baseline to revert to)

### 1. Rename for intent

Cheapest, highest-leverage refactor. Names describe **what** the value represents, not its type or computation.

| Bad | Good |
|-----|------|
| `data` | `pendingOrders` |
| `tmp` | `normalizedAddress` |
| `result` | `discountedTotal` |
| `flag` | `isCheckoutOpen` |
| `process(x)` | `validatePayment(x)` |

Rename until comments become redundant. Delete the comment.

### 2. Extract for cohesion

When a function does X-then-Y-then-Z and X/Y/Z each fit a name → extract.

```
function placeOrder(input) {
  // 20 lines of validation
  // 30 lines of pricing
  // 15 lines of persistence
}
```

becomes:

```
function placeOrder(input) {
  const validated = validateOrderInput(input)
  const priced = priceOrder(validated)
  return persistOrder(priced)
}
```

Each helper has a single name-able purpose. Place them in order of use, top-down.

### 3. Invert nested conditionals

Deep nesting hides the happy path. Use guard clauses to flatten.

Before:
```
function ship(order) {
  if (order) {
    if (order.paid) {
      if (order.address) {
        // 40 lines of actual work
      }
    }
  }
}
```

After:
```
function ship(order) {
  if (!order) return
  if (!order.paid) return
  if (!order.address) return
  // 40 lines, no nesting
}
```

### 4. Replace flag arguments with separate functions

```
// Before
saveOrder(order, isDraft: true)
saveOrder(order, isDraft: false)

// After
saveDraftOrder(order)
finalizeOrder(order)
```

Boolean parameters that change behavior = two functions hiding as one.

### 5. Replace primitive obsession with types

`(number, number, number)` for an RGB color is a footgun. `Color { r, g, b }` documents itself.

Same for: dates as strings, money as floats, IDs as plain strings without a brand.

### 6. Inline single-use abstractions

If `function helper()` is called from exactly one place and isn't reused — inline it. The abstraction has no payoff.

Counter-test: does the abstraction make the caller more readable? If yes, keep. If no, inline.

### 7. Remove dead branches

- `if (false)` blocks
- Unreachable code after `return` / `throw`
- `else` after a `return` in `if`
- Checks for conditions that types/contracts already prevent

### 8. Replace clever with obvious

| Clever | Obvious |
|--------|---------|
| `arr.reduce((a, b) => a + b, 0)` (in a hot path you'll re-read) | `let sum = 0; for (const x of arr) sum += x` |
| Nested ternary (3+ levels) | `if/else if/else` block |
| One-line lambda doing 5 things | Named function |
| Bit-twiddling without comment | Helper with intent name |

Clever code looks impressive. Obvious code ships.

## Verifying

After every step:

1. Tests still green? If no, you changed behavior — revert and try again.
2. Diff readable? If your diff is huge, you bundled too many simplifications.
3. New code shorter or clearer (ideally both)? If neither, undo.

Commit each step or small group of steps separately. Reviewer can verify each refactor is behavior-preserving.

## Common mistakes

- Refactoring without tests (you can't prove behavior preserved)
- Renaming + extracting + inverting in one giant commit (un-reviewable)
- Extracting helpers that are used once (just-in-case, no payoff)
- "While I'm here" feature additions (scope creep — separate PR)
- Adding new abstractions to "simplify" (often complicates)
- Touching code that wasn't actually hard to read
- Changing public API in a "simplification" PR — that's a breaking change
- Simplifying generated code (will be regenerated — fix the generator instead)

## Quick reference

| Smell | Refactor |
|-------|----------|
| Long function | Extract by responsibility |
| Deep nesting | Guard clauses |
| Boolean argument | Split into two functions |
| `data`, `tmp` | Rename for intent |
| Comment explaining what | Rename until comment unneeded |
| Flag chains (`if a && !b && c`) | Extract predicate function |
| Magic numbers/strings | Named constants |
| Primitive obsession | Domain type |
| Single-use helper | Inline |
| Dead branch | Delete |

## After simplification

- Tests green
- Diff each step is small and reviewable
- No new behavior
- Documentation updated if public surface (signatures, types) changed
- Mention to user any pre-existing dead code you found but didn't delete
