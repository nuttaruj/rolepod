<!-- Finding examples for review-code. Two scenarios, each an actionable/vague pair. -->
<!-- Read the WHOLE file — the contrast between actionable and vague IS the -->
<!-- lesson. Scenario 1 is a security BLOCKER; scenario 2 a performance MAJOR. -->

# Finding Examples

Each scenario shows the same real issue written as a vague finding and an
actionable one. Compare the pair — do not read one half alone.

---

## Scenario 1: Security BLOCKER — missing ownership check

### Actionable

```text
### BLOCKER — must fix before merge
- app/controllers/api/invoices_controller.rb:24 — #show loads the invoice
  by params[:id] with no ownership check; any logged-in user can read any
  invoice by guessing the id (IDOR on a billing surface) — scope the lookup
  to current_user.invoices.find(params[:id]).
```

### Vague

```text
- Security looks a bit off in the invoices controller, someone should
  double-check the auth there.
```

### Why good wins

| Area | Vague | Actionable |
|------|-------|------------|
| Location | "the invoices controller" | `invoices_controller.rb:24` |
| Issue | "looks a bit off" | IDOR — id-guessable, no ownership check |
| Why it matters | Not stated | Any user reads any user's billing data |
| Severity | None | BLOCKER — high-risk surface |
| Fix direction | "someone should double-check" | Scope to `current_user.invoices.find` |
| Author action | Unclear what to do | Exact — can fix immediately |

---

## Scenario 2: Performance MAJOR — N+1 query

### Actionable

```text
### MAJOR — fix or explicitly document
- app/controllers/orders_controller.rb:18 — the orders.each { |o| o.customer.name }
  loop fires one query per order (N+1); a 200-order page issues 201 queries
  — preload with .includes(:customer).
```

### Vague

```text
- The orders page might be slow, performance could be better.
```

### Why good wins

| Area | Vague | Actionable |
|------|-------|------------|
| Location | "the orders page" | `orders_controller.rb:18` |
| Issue | "might be slow" | N+1 — 201 queries for 200 orders |
| Evidence | A guess | The counted query cost |
| Severity | None | MAJOR |
| Fix direction | "could be better" | `.includes(:customer)` |

> A finding the author cannot act on is not a finding — it is a worry.
> Every finding names a file:line, the concrete failure, why it matters, and
> a fix direction. "Looks off" sends the author hunting; it does not review.
