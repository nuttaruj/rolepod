<!-- Debug examples for debug-issue. Two scenarios, each a good/bad pair. -->
<!-- Read the WHOLE file — the contrast IS the lesson. Scenario 1 is symptom -->
<!-- fix vs root fix; scenario 2 is retry hack vs triaged flake fix. -->

# Debug Examples

Each scenario shows the same bug fixed badly and well, plus a table of why
the good version wins. Compare the pair — do not read one half alone.

---

## Scenario 1: TypeError — undefined customer

### Good — root fix

```text
Error: TypeError: Cannot read property 'name' of undefined
  at OrderRow.render (OrderRow.tsx:14)

Trace:
- OrderRow:14 — order.customer is undefined
- who passed `order`? — OrdersList:30 maps over data.orders
- who built `data`? — useOrders() — the /api/orders response
- the API: orders from guest checkouts have customer_id = null, so the
  serializer omits `customer` entirely

Root cause: api/orders_serializer.rb:22 — omits `customer` for guest orders
instead of sending an explicit null the frontend expects.

Fix: serializer always includes `customer`, set to null for guest orders.
Failing test: orders_serializer_spec.rb — "guest order includes customer: null"
The `?.` was not added — the data shape is now correct at the source.
```

### Bad — symptom fix

```text
Error: TypeError: Cannot read property 'name' of undefined
  at OrderRow.render (OrderRow.tsx:14)

Fix: changed order.customer.name to order.customer?.name ?? "—".
Error gone. Done.
```

### Why good wins

| Area | Symptom fix | Root fix |
|------|-------------|----------|
| Where fixed | OrderRow.tsx:14 — where the value is used | The serializer — where the value is born |
| The bad value | Still produced; resurfaces on any other consumer of `customer` | Never produced again |
| Iron Rule 2 | Violated — stopped at the first symptom | Satisfied — traced to a system boundary |
| `?.` | Added blindly, no known cause | Not needed — shape correct at source |
| Test | None | Failing test pins the serializer contract |

---

## Scenario 2: Intermittent test failure

### Good — triaged fix

```text
Test checkout_spec.rb "applies the discount" fails ~1 in 5 runs.

Triage:
- raised the signal: ran the file in a loop — fails ~60% when run after
  cart_spec.rb, never when run alone
- → order dependency, not a code race

Cause: cart_spec.rb leaves a coupon row in the test DB; checkout_spec picks
it up and the discount math doubles.

Fix: cart_spec.rb cleans up its coupon in teardown; checkout_spec builds its
own fixture. Ran the suite 20x — 0 failures.
The retry was removed — it hid the shared-state bug.
```

### Bad — retry hack

```text
Test checkout_spec.rb "applies the discount" fails ~1 in 5 runs.

Fix: wrapped it in a retry — retry: 3. Now it passes. Done.
```

### Why good wins

| Area | Retry hack | Triaged fix |
|------|------------|-------------|
| Diagnosis | None — retried until green | Raised the signal, found the order dependency |
| Cause | Unknown, still there | Shared coupon row across tests |
| Fix | `retry: 3` masks it | Each test owns its fixture |
| Recurrence | Will flake again, and may hide a real regression | Gone — ran 20x clean |

> Both bad fixes make the error vanish — neither makes the bug go away. A
> symptom fix patches the use site; a retry patches the test runner. The bug
> still produces the bad value. Trace to where the value is born.
