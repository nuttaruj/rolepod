<!-- Finish examples for finish-work. Two scenarios, each a good/bad pair. -->
<!-- Read the WHOLE file — the contrast IS the lesson. Scenario 1 is the -->
<!-- authorization discipline; scenario 2 is PR body quality. -->

# Finish Examples

Each scenario: the same situation handled badly and well, plus why the good
version wins.

---

## Scenario 1: Finishing a branch with green gates

### Good — present, recommend, wait

```text
# feat/csv-export — Finish

## Gate status
- Pre-merge gate: PASS
- Verify status: tasks 1-3 VERIFIED; full suite via check-work —
  docs/rolepod/tasks/csv-export/verify.md, Verified tree 4f2a9c1 = HEAD^{tree},
  VERIFIED
- QA pass: export flow (filter → Export → CSV matches table) → pass
- CI: Phase 1 + 2 green
- Review verdict: APPROVED
- Cross-model adversarial pass (Full R4 only): internal strong pass — no
  second-vendor CLI on PATH.

## Rulings made
none

## Options
1. Merge to main — ready, all gates green
2. Open PR — if upstream review is wanted
3. Keep open — no, the work is done

## Recommendation
Merge to main — gates are green and review is APPROVED. The adversarial pass
was internal only; the user can accept it or ask for a second-vendor review.

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
| Evidence | "gates green" — no tree id, no QA line | Verify status per receipt, the full-suite block's tree id, the QA pass |
| User control | Branch fate decided for the user | User picks merge / PR / keep open; discard only on request |
| Reversibility | Already pushed | Nothing irreversible done yet |

---

## Scenario 2: Composing the PR body

### Good

```text
## Summary
- Add an Export CSV button to the orders report; downloads the current
  filtered rows, built server-side.
- Scope: no XLSX export, no scheduled exports.

## Test plan
- [ ] bundle exec rspec spec/services/orders_csv_spec.rb — before: 0 examples
      → after: 6 examples, 0 failures
- [ ] Open /orders, apply a filter, click Export — CSV matches the table
- [ ] Export an empty filter range — header-only CSV, no error

## Risks
Low — read-only export, no schema or auth change. Door: two-way (a revert undoes it). Large exports verified against a 10k-order range within the 30s timeout.

## Linked artifacts
Decision: server-side CSV built from the filtered scope (docs untracked — summarized in Risks above).
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
| Summary | "export stuff and some other things" | Concrete — what, where, how, and what it leaves out |
| Test plan | "added tests" — a reviewer cannot run it | A runnable checklist with before → after |
| Risks | Omitted | Blast radius, door type, the 30s verification |
| Artifacts | None | Decision summarized inline — no dead link to untracked docs |
