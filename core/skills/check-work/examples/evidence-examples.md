<!-- Evidence examples for check-work. Two scenarios, each a strong/weak pair. -->
<!-- Read the WHOLE file — the contrast between strong and false-green IS -->
<!-- the lesson. Scenario 1 is a bug fix; scenario 2 is a wrong-surface UI claim. -->

# Evidence Examples

Each scenario shows the same change verified weakly (a false green) and
strongly. Compare the pair — do not read one half alone.

---

## Scenario 1: Bug fix — pagination drops the last row

### Strong

```text
## Decision brief
### Change manifest
- lib/pagination.rb — fixed off-by-one in the last-page offset

### Evidence
Verified tree 4b1e9c0
- bundle exec rspec spec/pagination_spec.rb — PASS: 8 examples, 0 failures;
  the new test "last page includes the final row" was RED before the fix
- bundle exec rspec spec/requests/orders_spec.rb — PASS: 14 examples,
  0 failures (the one consumer of the paginator)

### Limitations
None.

## Verify status
VERIFIED
```

### Weak (false green)

```text
## Decision brief
### Evidence
- ran the tests, looks good
- assert page.rows.present?

## Verify status
VERIFIED
```

### Why strong wins

| Area | Weak | Strong |
|------|------|--------|
| Command | "ran the tests" — not reproducible | Exact command quoted |
| Proof | "looks good" | "8 examples, 0 failures" + the named new test |
| Consumers | Not checked | The paginator's caller re-run |
| Assertion | `rows.present?` passes even with one wrong row | Test was RED before the fix, GREEN after |
| Manifest | Missing | File + what changed |
| Limitations | Omitted | "None" stated deliberately |

---

## Scenario 2: UI change — empty-state message on the orders table

### Strong (honest about the surface)

```text
## Decision brief
### Change manifest
- app/javascript/components/OrdersTable.tsx — added empty-state message

### Evidence
- npx tsc --noEmit — PASS: no type errors
- npm test OrdersTable — PASS: 5 tests, incl. "renders empty state on []"

### Limitations
- Cannot verify: the empty state on the rendered /orders page
- Reason: no browser tool reachable in this session; typecheck and unit
  test are the wrong surface for a UI claim
- Risk if wrong: users with no orders see a blank table
- Suggested check: open /orders with a zero-order filter and read
  [data-testid="orders-empty"]

## Verify status
UNVERIFIED
```

### Weak (false green)

```text
## Decision brief
### Evidence
- npx tsc --noEmit — PASS: no type errors. The component compiles, so the
  empty state works.

## Verify status
VERIFIED
```

### Why strong wins

| Area | Weak | Strong |
|------|------|--------|
| Surface | Typecheck claimed as UI proof | Typecheck and unit test named as the wrong surface |
| Limitations | Omitted | The unobserved page named, with risk and the check to run |
| Status honesty | VERIFIED with no observation | UNVERIFIED with the reason |
