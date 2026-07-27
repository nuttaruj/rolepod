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

---

## Scenario 3: The plan declares a parallel layout (API track + UI track)

### Good — one dispatch, pipelined reviews

```text
Plan: Parallel layout — backend-developer owns app/api/**, frontend-developer
owns app/ui/**. Contract: docs/rolepod/plans/export-cohesion-2026-07-27.md.
Merge order: API first (interface provider). Frozen interface:
GET /export?filter= → 202 {job_id}.

Lead: both tracks' dependencies are met → ONE message, two Agent calls:
- backend-developer — Tasks 1-2; allowed app/api/**; forbidden everything
  else incl. the do-not-touch list; the frozen interface verbatim
- frontend-developer — Tasks 3-4; allowed app/ui/**; same frozen interface

UI track returns first → its spec-compliance + code-quality review runs NOW,
not after the API track lands. API track returns → same pipeline. Merge per
contract order: API slice, its tests green, then UI slice. Final
whole-implementation review on the cumulative diff → check-work.
```

### Bad — serial by habit

```text
Same plan. Lead: "I'll dispatch the API track first; once it's done and
reviewed I'll start the UI track."

Track A 18 min + track B 14 min = 32 min wall-clock for work the plan
declared disjoint. No stated reason for serial.
```

### Why good wins

| Area | Serial by habit | One dispatch |
|------|-----------------|--------------|
| Wall-clock | Sum of tracks (32 min) | Slowest track (~18 min) |
| Plan respected | Parallel layout silently ignored | Layout executed as written |
| Review latency | All reviews wait for the last track | Each track reviewed as it returns |
| Hard stop | Trips "parallel-layout plan executed one track at a time with no stated reason" | Clean |
| Merge safety | Identical either way — contract order governs | Identical — contract order governs |

> Parallel buys wall-clock, not tokens. The plan already paid for the
> cohesion contract — executing its tracks serially throws that payment away.
