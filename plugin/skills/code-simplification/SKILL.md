---
name: code-simplification
description: Refactor for clarity without changing behavior. Behavior-preserving — every change is provable by tests staying green.
when_to_use: when code works but is hard to read, when nesting is deep, when a function is doing too much, or when the design fights you on every change
---

# Code Simplification

Zero new behavior, smaller mental footprint. Tests green start to finish = proof nothing changed.

## When to use

- Function >50 lines, doing >1 thing
- Nesting depth ≥4
- Comment explaining what code does (not why)
- Variable named `data` / `tmp` / `result` / `obj`
- "I'll come back to this" — you're back
- Adding feature feels disproportionately hard
- Review found logic but couldn't follow
- Same file keeps tripping new teammates

## How to apply

### Pre-flight

- Tests exist? No → write first (test-driven-development skill). Can't refactor safely without green safety net.
- Run tests, confirm green
- Commit clean baseline

### 1. Rename for intent

Highest leverage. Names describe what, not type/computation.

| Bad | Good |
|-----|------|
| `data` | `pendingOrders` |
| `tmp` | `normalizedAddress` |
| `result` | `discountedTotal` |
| `flag` | `isCheckoutOpen` |
| `process(x)` | `validatePayment(x)` |

Rename until comments redundant. Delete comment.

### 2. Extract for cohesion

Function does X-then-Y-then-Z where each fits a name → extract.

```
function placeOrder(input) {
  const validated = validateOrderInput(input)
  const priced = priceOrder(validated)
  return persistOrder(priced)
}
```

Each helper has single name-able purpose, ordered top-down.

### 3. Invert nested conditionals

Deep nesting hides happy path. Guard clauses flatten.

```
function ship(order) {
  if (!order) return
  if (!order.paid) return
  if (!order.address) return
  // 40 lines, no nesting
}
```

### 4. Flag arguments → separate functions

```
// Before
saveOrder(order, isDraft: true)
saveOrder(order, isDraft: false)

// After
saveDraftOrder(order)
finalizeOrder(order)
```

Boolean parameters that change behavior = two functions hiding as one.

### 5. Replace primitive obsession

`(number, number, number)` for RGB is footgun. `Color { r, g, b }` self-documents.

Same for: dates as strings, money as floats, IDs as unbranded strings.

### 6. Inline single-use abstractions

Called once, not reused → inline. No payoff.

Counter-test: does abstraction make caller more readable? Yes → keep. No → inline.

### 7. Remove dead branches

- `if (false)`
- Unreachable after `return`/`throw`
- `else` after `return` in `if`
- Checks types/contracts already prevent

### 8. Clever → obvious

| Clever | Obvious |
|--------|---------|
| `arr.reduce((a, b) => a + b, 0)` in hot re-read path | `let sum = 0; for (const x of arr) sum += x` |
| Nested ternary 3+ levels | `if/else if/else` |
| One-line lambda doing 5 things | Named function |
| Bit-twiddling without comment | Helper with intent name |

## Verifying

After every step:
1. Tests green? No → reverted behavior, revert + retry
2. Diff readable? Huge diff = bundled too much
3. New code shorter/clearer? Neither → undo

Commit each step or small group separately.

## Common mistakes

- Refactor without tests (can't prove preserved)
- Rename + extract + invert in one giant commit
- Extracting one-use helpers
- "While I'm here" feature additions
- Adding abstractions to "simplify" (often complicates)
- Touching code that wasn't hard to read
- Public API change in "simplification" PR = breaking
- Simplifying generated code — fix generator

## Quick reference

| Smell | Refactor |
|-------|----------|
| Long function | Extract by responsibility |
| Deep nesting | Guard clauses |
| Boolean argument | Split into two functions |
| `data`, `tmp` | Rename for intent |
| Comment explaining what | Rename until unneeded |
| Flag chains | Extract predicate function |
| Magic numbers/strings | Named constants |
| Primitive obsession | Domain type |
| Single-use helper | Inline |
| Dead branch | Delete |

## After simplification

- Tests green
- Each step diff small/reviewable
- No new behavior
- Docs updated if public surface changed
- Mention pre-existing dead code found but not deleted

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Code works, refactor risky" | Working ≠ understandable. Complexity tax accrues every read. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
