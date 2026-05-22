<!-- Simplify examples for simplify-code. Two scenarios, each a good/bad pair. -->
<!-- Read the WHOLE file — the contrast IS the lesson. Scenario 1 is a -->
<!-- single-use helper; scenario 2 is a defensive check (the S4 case). -->

# Simplify Examples

Each scenario shows the same cut done badly and well, plus a table of why
the good version wins. Compare the pair — do not read one half alone.

---

## Scenario 1: A helper with exactly one caller

### Good — inline, nothing else

```text
Before — helper called from exactly one place:
  def formatted_total(order)
    "$#{'%.2f' % order.total}"
  end

After — inlined at the one call site:
  "$#{'%.2f' % order.total}"

Tests: bundle exec rspec spec/invoice_row_spec.rb — PASS before (4 examples),
PASS after (4 examples). Same assertions. Behavior preserved: YES.
```

### Bad — inline plus a "tidy up"

```text
Before — the same one-caller helper.

After — inlined, AND switched the rounding to .round(2) instead of '%.2f',
AND dropped the $ for a locale helper.

Tests: invoice_row_spec.rb — 1 example fails ("expected $9.90, got 9.9");
the test assertion was changed to match. Behavior preserved: NO.
```

### Why good wins

| Area | Bad | Good |
|------|-----|------|
| Scope | Inline + rounding change + locale change | Inline only |
| Tests | An assertion had to change | Same assertions, green before + after |
| Behavior | Changed ($9.90 → 9.9) | Preserved |
| Iron Rule 1 | Violated — not behavior-preserving | Satisfied — proven by unchanged tests |

---

## Scenario 2: A defensive null check

### Good — the bad state is structurally impossible

```text
Code:
  user = User.find(session[:user_id])   # raises if the row is absent
  name = user&.name || "Guest"

Cut: User.find raises RecordNotFound — it never returns nil. The value is
structurally non-nil here, so the &. and the "|| Guest" branch are dead.
Removed both; verified User.find's behavior first.

Tests: green before + after. Behavior preserved: YES.
```

### Bad — the check was load-bearing

```text
Code:
  customer = order.customer            # nil for guest-checkout orders
  name = customer&.name || "Guest"

Cut: "removed the defensive &. — looks like clutter."

Result: guest-checkout orders (customer = nil) now raise NoMethodError:
undefined method 'name' for nil. The check guarded a real case — customer
genuinely CAN be nil.
```

### Why good wins

| Area | Bad cut | Good cut |
|------|---------|----------|
| The value | `customer` CAN be nil (guest orders) | `user` CANNOT be nil (`find` raises) |
| The check | Load-bearing — guards a real case | Dead — guards an impossible case |
| After the cut | NoMethodError on guest orders | No behavior change |
| S4 reading | Misread a real case as "impossible" | Correctly cut a check for a structurally impossible state |
| Verification | Call site behavior not checked | Verified `find` raises, never returns nil |

> A defensive check is clutter only when the bad state is structurally
> impossible — the type or the API guarantees it. If the value genuinely can
> be bad (an external input, a nullable column), the check is load-bearing.
> Removing it is not simplification; it is a new bug.
