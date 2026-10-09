<!-- Execution example for implement-plan: one good/bad pair about staying surgical. -->

# Execution Example

The same task handled badly and well, plus a table of why the good version
wins. Compare the pair — do not read one half alone.

---

## Task "fix the invoice header date format"

### Good — surgical

```text
# Task 3 — invoice header date: show "Jan 5, 2026" not "2026-01-05"

## Decision brief

### Change
- `app/javascript/components/InvoiceHeader.tsx` — date formatted with
  formatDate(); 1 line changed

### Tests added / changed
- `InvoiceHeader.test.tsx` — asserts the header renders "Jan 5, 2026"

### Commands
- `npm test InvoiceHeader` — PASS: 4 tests, 0 failures

### Scope check
Diff is 1 line + 1 test. No refactor. Deferred: InvoiceHeader could use the
shared <DateText> component — noted here, not done.

### Concerns
None

### Author fix closure
- Re-check: none — no BLOCKER / MAJOR fixed

### Owner status
COMPLETED

## Verify status
VERIFIED
```

### Bad — scope creep

```text
# Task 3 — fix the invoice header date

### Change
- InvoiceHeader.tsx — reformatted the whole file, renamed props for
  clarity, extracted a new useInvoiceMeta hook, fixed the date, tidied imports
- hooks/useInvoiceMeta.ts — new
- InvoiceFooter.tsx — applied the same rename

### Owner status
COMPLETED
```

### Why good wins

| Area | Scope creep | Surgical |
|------|-------------|----------|
| Diff size | 3 files, a new hook, prop renames | 1 line + 1 test |
| Task match | Date fix buried in an unrelated refactor | Exactly the date fix |
| Reviewability | Every extra change needs its own review | Reviewable in seconds |
| Scope guardrail | Violated — scope expanded mid-task | Satisfied — idea noted in Scope check, not done |
| Evidence | No test, no Command tail | Assertion on the new behavior, Command tail quoted |
