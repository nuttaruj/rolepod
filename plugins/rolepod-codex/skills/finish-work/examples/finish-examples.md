<!-- Finish examples for finish-work. Two scenarios, each a good/bad pair. -->
<!-- Read the WHOLE file — the contrast IS the lesson. Scenario 1 is the -->
<!-- authorization discipline; scenario 2 is PR body quality. -->

# Finish Examples

Each scenario shows the same situation handled badly and well, plus a table
of why the good version wins. Compare the pair — do not read one half alone.

---

## Scenario 1: Finishing a branch with green gates

### Good — present, recommend, wait

```text
Branch feat/csv-export — gates green, CI Phase 1 + 2 pass, review APPROVED.

# feat/csv-export — Finish

## Gate status
- Evidence: VERIFIED — check-work ran the 4 rspec specs, all green
- Cross-model adversarial pass: vertical — same family (no second-vendor CLI
  on PATH; the Lead's own stronger tier ran the cold review). Recorded as a
  verification limitation, not a cross-family pass — surfaced here, not hidden.

## Options
1. Merge to main — ready, all gates green
2. Open PR — if upstream review is wanted
3. Keep open — no, the work is done
4. Discard — no

## Recommendation
Merge to main — gates are green and review is APPROVED. The cross-model pass
was vertical only; call that out to the user so they can accept it or ask for
a second-vendor review before merge.

## Awaiting authorization for
merge feat/csv-export to main.

[waits for the user to choose]
```

### Bad — act without authorization

```text
Branch feat/csv-export — gates green, CI pass, review APPROVED.

Lead: "All gates passed, so I merged feat/csv-export to main and pushed."
```

### Why good wins

| Area | Bad | Good |
|------|-----|------|
| Authorization | Merged without the user choosing | Presented the menu, waited for explicit auth |
| Iron Rule 1 | Violated — "gates green" is not authorization | Satisfied — auth requested for the specific action |
| User control | Branch fate decided for the user | User picks merge / PR / keep / discard |
| Reversibility | The push already happened | Nothing irreversible done yet |

---

## Scenario 2: Composing the PR body

### Good

```text
## Summary
- Add an Export CSV button to the orders report; downloads the current
  filtered rows, built server-side.

## Test plan
- [ ] bundle exec rspec spec/services/orders_csv_spec.rb
- [ ] Open /orders, apply a filter, click Export — CSV matches the table
- [ ] Export an empty filter range — header-only CSV, no error

## Risks
Low — read-only export, no schema or auth change. Large exports verified
against a 10k-order range within the 30s timeout.

## Linked artifacts
Spec: docs/rolepod/specs/orders-csv-export-2026-05-20.md
```

### Bad

```text
## Summary
- fixed the export stuff and some other things

added tests
```

### Why good wins

| Area | Bad | Good |
|------|-----|------|
| Summary | "export stuff and some other things" | Concrete — what, where, how |
| Test plan | "added tests" — a reviewer cannot run it | A runnable checklist |
| Risks | Omitted | Blast radius + the 30s verification |
| Artifacts | None | Spec linked |

> Finishing a branch is the one phase where the agent must not act alone.
> Gates green means ready to merge — not merged. Present the menu, recommend,
> and wait for the user to authorize the specific action.
