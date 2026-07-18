<!-- Plan examples for write-plan. Two scenarios, each a good/bad pair. -->
<!-- Read the WHOLE file — the contrast between good and bad IS the lesson. -->
<!-- Scenario 1 is a sequential single-owner plan; scenario 2 is parallel -->
<!-- multi-agent. Most plans are sequential — parallel is the exception. -->

# Plan Examples

Each scenario shows the same feature planned badly and well, plus a table of
why the good version wins. Compare the pair — do not read one half alone.

---

## Scenario 1: Orders CSV export (sequential, single owner)

### Good

```text
# Orders CSV Export Plan

## Source spec
docs/rolepod/specs/orders-csv-export-2026-05-20.md (approved)

## Files to touch
- app/services/orders_csv.rb — new — builds the CSV from the report query
- app/controllers/reports_controller.rb — add the export action
- app/views/reports/_toolbar.html.erb — add the Export CSV button

## Tasks

### Task 1: OrdersCsv service
- [ ] Files: app/services/orders_csv.rb, spec/services/orders_csv_spec.rb
- [ ] Change: build CSV rows from the same scope ReportsController#index uses
- [ ] Test / evidence: unit — a 3-order scope yields 1 header + 3 rows, columns
  in on-screen table order
- [ ] Expected failing signal: NameError: uninitialized constant OrdersCsv
- [ ] Command: bundle exec rspec spec/services/orders_csv_spec.rb
- Owner: Lead
- Done when: spec green, columns match the report table

### Task 2: export action
- [ ] Files: app/controllers/reports_controller.rb
- [ ] Change: add #export, reuse the index filter scope, stream as attachment
- [ ] Test / evidence: request spec — filtered export row count == table count;
  an empty range returns a header-only CSV
- [ ] Command: bundle exec rspec spec/requests/reports_spec.rb
- Owner: Lead
- Done when: request spec green; 30s timeout not exceeded on a 10k-order range
- On fail: timeout on the 10k range → switch to the chunked streamed
  response (Risks) instead of debugging the buffered path.

### Task 3: Export CSV button
- [ ] Files: app/views/reports/_toolbar.html.erb
- [ ] Change: add the button wired to #export; disable + spinner while generating
- [ ] Test / evidence: system spec — click exports the current filter; button
  is disabled mid-generation
- [ ] Command: bundle exec rspec spec/system/reports_export_spec.rb
- Owner: Lead
- Done when: system spec green

## High-risk surfaces touched
None — read-only export, no credential or billing change.

## Spec coverage (both directions)
Forward — every spec criterion has an owning task:
- row set == filtered table → Task 2
- column order + headers match → Task 1
- loading state, no double-click → Task 3
- zero-match → header-only CSV → Task 2
Reverse — every task traces to a spec line; anything that does not is cut:
- Task 1-3 each map to a criterion above.
- "add an Excel (.xlsx) export too" — no spec line asked for it, and Non-goals
  excludes it → cut to a follow-up, not built here.

## Parallel layout
Sequential — single owner. Task 1 → 2 → 3; each depends on the prior.

## Done criteria
All 3 specs green; the exported CSV row set equals the filtered table.

## Failure policy
Default: a failing Command → debug-issue (reproduce → minimal fix → re-run
the same Command). Stop and escalate after 3 failed attempts on one task
(debug-issue's one cross-model consult and its single advisor-informed
attempt happen inside this stop — never a 5th attempt), or if a fix reopens
a previously green task.

## Risks
Large exports near the 30s timeout — Task 2 verifies a 10k-order range; if it
fails, fall back to a chunked streamed response.
```

### Bad

```text
# CSV Export Plan

## Tasks
1. Build the export feature.
2. Add tests.
3. Make sure it works.

## Notes
Touch the reports stuff and the frontend. Should be quick.
```

### Why good wins

| Area | Bad | Good |
|------|-----|------|
| Files | "the reports stuff" — no paths | Exact paths, one per line, with the change |
| Tasks | "Build the export feature" — one giant vague task | Ordered, each independently verifiable |
| Tests | "Add tests" — no assertion | Per task: test type + the assertion that proves done |
| Order | Unstated | Sequential, dependency named (1 → 2 → 3) |
| Commands | None | Exact `rspec` command per task |
| Loop | Not runnable — no checkboxes, no failure path | Checkbox state + Failure policy: the build loop executes, verifies, and recovers without re-asking |
| Scope | "Touch the reports stuff and the frontend" — unbounded | Two-way spec trace: every criterion has a task, every task has a spec line, and the unasked Excel export is cut |
| Risk | "Should be quick" | Timeout risk named with a fallback + a per-task On fail |

---

## Scenario 2: Notifications center (parallel, two agents)

### Good

```text
# Notifications Center Plan

## Source spec
docs/rolepod/specs/notifications-center-2026-05-20.md (approved)

## Files to touch
- app/models/notification.rb — new — backend
- app/controllers/api/notifications_controller.rb — new — backend
- app/javascript/api/notifications.ts — new — frontend API client
- app/javascript/components/NotificationBell.tsx — new — frontend
- app/javascript/components/NotificationDropdown.tsx — new — frontend

## Tasks

### Task 1: Notification model + API (backend)
- [ ] Files: app/models/notification.rb, app/controllers/api/notifications_controller.rb
- [ ] Change: model + GET /api/notifications + POST /api/notifications/:id/read
- [ ] Test / evidence: request spec — list returns unread first; read marks read
- [ ] Command: bundle exec rspec spec/requests/api/notifications_spec.rb
- Owner: backend-developer
- Done when: request spec green; API matches the frozen contract

### Task 2: API client + bell + dropdown (frontend)
- [ ] Files: app/javascript/api/notifications.ts, NotificationBell.tsx, NotificationDropdown.tsx
- [ ] Change: typed client, bell with unread count, dropdown with read-on-click
- [ ] Test / evidence: component test — bell shows the count; click marks read
- [ ] Command: yarn vitest run app/javascript/components/__tests__/notifications
- Owner: frontend-developer
- Done when: component tests green against the contract's mock

## High-risk surfaces touched
None.

## Parallel layout
Parallel — 2 agents, disjoint files.
Cohesion contract: docs/rolepod/plans/notifications-cohesion-2026-05-20.md
Merge order: Task 1 (backend) first — it provides the API contract.

## Done criteria
Both task sets green; the live bell updates against the real API.

## Failure policy
Default: a failing Command → debug-issue → re-run the same Command; stop
after 3 failed attempts on one task (the §9 cross-model consult + its one
advisor-informed attempt run inside this stop — never a 5th attempt).
Contract drift found at integration → STOP both agents, fix the contract
first (do not patch around it).

## Risks
Contract drift — the API shape is frozen in the cohesion contract; the
integration owner re-runs the full flow after merge.
```

### Bad

```text
# Notifications Plan

## Tasks
- backend-developer: build notifications.
- frontend-developer: build the notification UI.
- Both: wire it together.

Run them in parallel to go faster.
```

### Why good wins

| Area | Bad | Good |
|------|-----|------|
| Files | None listed | Exact paths, tagged by owner |
| Ownership | Both agents on "wire it together" — shared, no owner | Disjoint files, one owner each |
| Cohesion contract | None — parallel with no contract | Contract path named, interface frozen |
| Merge order | Unstated | Backend first — it provides the contract |
| API contract | Unstated — drift guaranteed | Frozen in the contract; integration owner re-verifies |
| Tests | None | Per task: request spec / component test with an assertion + a runnable Command |
| Loop | Not runnable | Checkboxes + Failure policy incl. the contract-drift stop rule |

> Scenario 2 is parallel — but the good plan still names a merge order and a
> single integration owner. Parallel is not "everyone edits at once"; it is
> disjoint ownership plus a contract. If files cannot be split cleanly, the
> good answer is sequential, not a vague contract.
