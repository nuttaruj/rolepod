<!-- Context examples for manage-context. Two scenarios, each a good/bad pair. -->
<!-- Read the WHOLE file — the contrast IS the lesson. Scenario 1 is a -->
<!-- zoom-out recovery; scenario 2 is a session handoff. -->

# Context Examples

Each scenario shows the same situation handled badly and well, plus a table
of why the good version wins. Compare the pair — do not read one half alone.

---

## Scenario 1: The same bug keeps coming back

### Good — catch the signal, zoom out

```text
Symptom: the "undefined customer" error has been fixed 3 times — it keeps
coming back at a different file each time.

Lead: 3 surfaces = a context-loss signal. Stop editing. Zoom out.
- Re-read the request: "make the orders report load for guest checkouts."
- The 3 fixes were all symptom patches (?. guards) in 3 consumers.
- The real goal needs ONE root fix in the serializer, not N guards.
Route: debug-issue, trace to the serializer. Stop patching consumers.
```

### Bad — keep patching

```text
Symptom: the same "undefined customer" error, fixed 3 times, back again.

Lead: "let me add a ?. guard here too." (4th patch)
... "and here." (5th) ... "and here." (6th)
```

### Why good wins

| Area | Bad | Good |
|------|-----|------|
| 3-surface signal | Ignored — kept patching | Caught — stopped at the signal |
| Iron Rule 1 | Violated (same bug 3+ angles → zoom out) | Satisfied |
| Re-read request | Never | Re-read; found the patches missed the goal |
| Outcome | 6 symptom patches, bug still alive | One root fix routed to debug-issue |

---

## Scenario 2: Context is heavy mid-refactor

### Good — write a handoff brief, then restart

```text
Context bar is red mid-refactor. Lead fills a handoff brief:
  Original request: "..."
  Branch: refactor/orders @ a4f2e1
  Files touched: orders_controller.rb (done), orders_csv.rb (in progress)
  Tests: orders_spec green; orders_csv_spec 1 red — the empty-range case
  Constraints: stay within the 30s timeout; no schema change
  Decisions: chose server-side CSV (client-side misses paginated rows)
  Resume with: implement-plan — fix the empty-range test in orders_csv.rb

A fresh session reads the brief and resumes exactly where work stopped.
```

### Bad — clear and start over

```text
Context bar is red mid-refactor. Lead runs /clear and starts over.

The fresh session has no record of the 30s constraint, re-chooses
client-side CSV, and re-introduces the paginated-rows bug already ruled out.
```

### Why good wins

| Area | Bad | Good |
|------|-----|------|
| Handoff | `/clear` with no brief | A complete handoff brief written first |
| Constraints | Lost — the 30s timeout forgotten | Carried — listed in the brief |
| Decisions | Re-litigated — the client-side bug returns | Pinned — "rejected client-side" recorded |
| Fresh session | Starts blind | Resumes exactly where work stopped |

> Context recovery is not "start over" — it is "carry the right things
> forward". The 3-surface bug is a signal to zoom out, not to patch again.
> A fresh session is only safe behind a handoff brief.
