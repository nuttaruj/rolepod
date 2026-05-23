<!-- Execution examples for implement-plan. Two scenarios, each a good/bad pair. -->
<!-- Read the WHOLE file — the contrast IS the lesson. Scenario 1 is about -->
<!-- staying surgical; scenario 2 is about not trusting a subagent blindly. -->

# Execution Examples

Each scenario shows the same situation handled badly and well, plus a table
of why the good version wins. Compare the pair — do not read one half alone.

---

## Scenario 1: Task "fix the invoice header date format"

### Good — surgical

```text
Task: invoice header date — show "Jan 5, 2026" not "2026-01-05".

## Files changed
- app/javascript/components/InvoiceHeader.tsx — date now formatted with
  formatDate(); 1 line changed

## Tests added / changed
- InvoiceHeader.test.tsx — asserts the header renders "Jan 5, 2026"

## Commands run
- npm test InvoiceHeader — PASS: 4 tests, 0 failures

## Scope check
Diff is 1 line + 1 test. No refactor. Deferred: InvoiceHeader could use the
shared <DateText> component — noted as a follow-up, not done here.

## Status
COMPLETED
```

### Bad — scope creep

```text
Task: fix the invoice header date.

## Files changed
- app/javascript/components/InvoiceHeader.tsx — reformatted the whole file,
  renamed props for clarity, extracted a new useInvoiceMeta hook, fixed the
  date, tidied the imports
- app/javascript/hooks/useInvoiceMeta.ts — new
- app/javascript/components/InvoiceFooter.tsx — applied the same rename

## Status
COMPLETED
```

### Why good wins

| Area | Scope creep | Surgical |
|------|-------------|----------|
| Diff size | 3 files, a new hook, prop renames | 1 line + 1 test |
| Task match | Date fix buried in an unrelated refactor | Exactly the date fix |
| Reviewability | Every extra change needs its own review | Reviewable in seconds |
| Iron Rule 2 | Violated — scope expanded mid-task | Satisfied — follow-up written, not done |
| Tests | None added | Assertion on the new behavior |

---

## Scenario 2: A subagent returns its manifest

### Good — verify, then reject

```text
Subagent returned:
  ## Files changed
  - lib/rate_limiter.rb — added the sliding-window check
  ## Commands run
  - bundle exec rspec spec/rate_limiter_spec.rb — 6 examples, 1 failure
  ## Status
  COMPLETED

Lead: the manifest says COMPLETED, but the test output shows 1 failure —
reject. Re-brief: "rate_limiter_spec.rb has a failing example — fix the code
so all 6 pass, then return the manifest. Do not report COMPLETED while a
test is red."
```

### Bad — accept the status line blindly

```text
Subagent returned:
  Status: COMPLETED

Lead: "Subagent says COMPLETED — committing."
```

### Why good wins

| Area | Blind accept | Verified accept |
|------|--------------|-----------------|
| Evidence read | The status line only | The actual command output |
| Catch | Missed the 1 failing example | Caught COMPLETED over a red test |
| Action | Committed broken code | Rejected, re-briefed with a precise fix |
| Hard stop | Ignored ("subagent COMPLETED with failing tests → reject") | Applied |

> "Status: COMPLETED" is a claim, not proof. Read the evidence the manifest
> carries — a manifest can say COMPLETED over a failing test. The Lead, not
> the subagent, decides when a task is done.
