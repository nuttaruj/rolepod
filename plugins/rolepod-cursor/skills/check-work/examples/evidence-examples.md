<!-- Evidence examples for check-work. Two scenarios, each a strong/weak pair. -->
<!-- Read the WHOLE file — the contrast between strong and false-green IS -->
<!-- the lesson. Scenario 1 is a bug fix; scenario 2 is a UI change. -->

# Evidence Examples

Each scenario shows the same change verified weakly (a false green) and
strongly. Compare the pair — do not read one half alone.

---

## Scenario 1: Bug fix — pagination drops the last row

### Strong

```text
## Change manifest
- lib/pagination.rb — fixed off-by-one in the last-page offset

## Evidence
- bundle exec rspec spec/pagination_spec.rb — PASS: 8 examples, 0 failures;
  the new test "last page includes the final row" was RED before the fix
- bundle exec rspec — PASS: 214 examples, 0 failures (full suite, no regression)

## Limitations
None — logic change, fully covered by the suite.

## Status
VERIFIED
```

### Weak (false green)

```text
## Evidence
- ran the tests, looks good
- assert page.rows.present?

## Status
VERIFIED
```

### Why good wins

| Area | Weak | Strong |
|------|------|--------|
| Command | "ran the tests" — not reproducible | Exact command quoted |
| Proof | "looks good" | "8 examples, 0 failures" + the named new test |
| Regression | Not checked | Full suite green — F3 cleared |
| Assertion | `rows.present?` passes even with one wrong row | Test was RED before the fix, GREEN after |
| Manifest | Missing | File + what changed |
| Limitations | Omitted | "None" stated deliberately |

---

## Scenario 2: UI change — empty-state message on the orders table

### Strong

```text
## Change manifest
- app/javascript/components/OrdersTable.tsx — added empty-state message

## Evidence
- npx tsc --noEmit — PASS: no type errors
- Browser (Playwright) — loaded /orders with a zero-order filter; DOM read
  shows <p data-testid="orders-empty">No orders match these filters</p>;
  screenshot saved to tmp/orders-empty.png
- npm test OrdersTable — PASS: 5 tests, incl. "renders empty state on []"

## Limitations
None.

## Status
VERIFIED
```

### Weak (false green)

```text
## Evidence
- npx tsc --noEmit — PASS: no type errors. The component compiles, so the
  empty state works.

## Status
VERIFIED
```

### Why good wins

| Area | Weak | Strong |
|------|------|--------|
| UI proof | "it compiles" — typecheck is not UI proof | Browser DOM read + screenshot of the real empty state |
| Evidence type | Typecheck only | Typecheck + browser observation + component test |
| Iron Rule #2 | Violated — UI claimed with no browser | Satisfied — page loaded, DOM observed |
| Status honesty | "VERIFIED" with no runtime proof | VERIFIED, backed by an observed render |

> A passing typecheck proves the code is type-correct — never that the UI
> renders, the flow works, or the user sees the right thing. UI claims need
> a browser observation. "It compiled" is the most common false green.
