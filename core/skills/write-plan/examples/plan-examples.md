<!-- Plan examples for write-plan. Two scenarios, each a good/bad pair. -->
<!-- Read the WHOLE file — the contrast between good and bad IS the lesson. -->
<!-- Scenario 1 is a sequential plan (one owner per task, no parallel tracks); scenario 2 is parallel -->
<!-- multi-agent. Most plans are sequential — parallel is the exception. -->
<!-- Changes during build and Follow-ups are empty at plan time and left out of both plans. -->

# Plan Examples

Each scenario shows the same feature planned badly and well, plus a table of
why the good version wins. Compare the pair — do not read one half alone.

---

## Scenario 1: Orders CSV export (sequential)

### Good

```text
# Orders CSV Export Plan

Goal: Users can export a filtered report as CSV with the correct columns in one click.
Architecture: Service layer (OrdersCsv) + REST endpoint + UI button.
Stack: Ruby + ERB + RSpec (units and requests).

## Source spec
docs/rolepod/specs/orders-csv-export-2026-05-20.md (approved)

## Files to touch
- app/services/orders_csv.rb — new — builds the CSV from the report query
- app/controllers/reports_controller.rb — add the export action
- app/views/reports/_toolbar.html.erb — add the Export CSV button

## Tasks

### Task 1: Orders CSV export
- Delivers: a user clicks Export CSV and gets the filtered table as a CSV file
- Blocked by: none
- [ ] Files: app/services/orders_csv.rb, app/controllers/reports_controller.rb,
  app/views/reports/_toolbar.html.erb, spec/services/orders_csv_spec.rb,
  spec/requests/reports_spec.rb, spec/system/reports_export_spec.rb
- Read first: app/services/orders_report.rb (the service-object shape to copy),
  app/controllers/reports_controller.rb#index (the filter scope),
  app/views/reports/_print_button.html.erb (the disable + spinner pattern)
- [ ] Change:
  - [ ] OrdersCsv.call(scope) builds the rows from the scope ReportsController#index uses
  - [ ] #export reuses the index filter scope and streams the CSV as an attachment
  - [ ] the Export CSV button calls #export, disabled with a spinner while generating
- [ ] Test / evidence: unit at OrdersCsv.call(scope) — a 3-order scope yields 1 header
  + 3 rows in on-screen column order; request spec at GET /reports/export — row count
  == table count, an empty range returns a header-only CSV; system spec at the button —
  click exports the current filter, the button is disabled mid-generation
- [ ] Expected failing signal: NameError: uninitialized constant OrdersCsv
- [ ] Command: bundle exec rspec spec/services/orders_csv_spec.rb spec/requests/reports_spec.rb spec/system/reports_export_spec.rb
- Owner: backend-developer (the button is a thin end)
- Done when: the three specs green; columns match spec Chosen approach: "id, name, total, status";
  30s timeout not exceeded on a 10k-order range
- On fail: timeout on the 10k range → switch to the chunked streamed
  response (Risks) instead of debugging the buffered path.

## High-risk surfaces touched
None — read-only export, no credential or billing change.

## Spec coverage (both directions)
Forward — each criterion names the task that proves it (one task may prove several):
- row set == filtered table → Task 1
- column order + headers match → Task 1
- loading state, no double-click → Task 1
- zero-match → header-only CSV → Task 1
Reverse — every task traces to a spec line; anything that does not is cut:
- Task 1 maps to every criterion above.
- "add an Excel (.xlsx) export too" — no spec line asked for it, and Non-goals
  excludes it → cut to a follow-up, not built here.

## Parallel layout
Sequential — one task, one owner.

## Done criteria
All 3 specs green; the exported CSV row set equals the filtered table.

## Failure policy
Template default. Also stop if a fix reopens a green task.

## Risks
Large exports near the 30s timeout — Task 1 verifies a 10k-order range; if it
fails, fall back to a chunked streamed response.
```

A second full-depth layer (say, a public CSV API another team consumes) would be its own task: `Blocked by: Task 1 (OrdersCsv.call(scope))`.

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
| Tasks | "Build the export feature" — one giant vague task | One reviewable task; its steps are ordered checkboxes |
| Tests | "Add tests" — no assertion | Per task: test type + the assertion that proves done |
| Order | Unstated | Blocked by on every task (here: none) — the graph IS the order; Delivers gives the one-line why |
| Commands | None | Exact `rspec` command per task |
| Loop | Not runnable — no checkboxes, no failure path | Checkbox state + Failure policy: the build loop executes, verifies, and recovers without re-asking |
| Scope | "Touch the reports stuff and the frontend" — unbounded | Two-way spec trace: every criterion names the task that proves it, every task has a spec line, and the unasked Excel export is cut |
| Risk | "Should be quick" | Timeout risk named with a fallback + a per-task On fail |
| Hand-off | Nothing | Read first names the patterns to copy; spec contract quoted in the task |

---

## Scenario 2: Notifications center (parallel, two agents)

### Good

```text
# Notifications Center Plan

Goal: Users see an unread notification count and can mark items as read from a dropdown.
Architecture: Backend API (list + read endpoints) + frontend client + bell + dropdown component.
Stack: Ruby + PostgreSQL (backend), TypeScript + React (frontend), frozen API contract.

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
- Delivers: the API lists a user's notifications, unread first, and marks one read
- Blocked by: none
- [ ] Files: app/models/notification.rb, app/controllers/api/notifications_controller.rb
- Read first: docs/rolepod/plans/notifications-cohesion-2026-05-20.md (contract),
  spec/fixtures/notifications.json (shape)
- [ ] Change: model + GET /api/notifications + POST /api/notifications/:id/read
- [ ] Test / evidence: request spec at GET /api/notifications and
  POST /api/notifications/:id/read — list returns unread first; read marks read
- [ ] Command: bundle exec rspec spec/requests/api/notifications_spec.rb
- Owner: backend-developer
- Done when: request spec green; the frozen contract holds — GET /api/notifications
  returns [{id, title, read_at, created_at}] unread first; POST .../:id/read returns 204

### Task 2: API client + bell + dropdown (frontend)
- Delivers: a user sees an unread count on the bell and clears items from the dropdown
- Blocked by: none — builds against the contract's mock; the live wiring is Done criteria
- [ ] Files: app/javascript/api/notifications.ts, NotificationBell.tsx, NotificationDropdown.tsx
- Read first: docs/rolepod/plans/notifications-cohesion-2026-05-20.md (contract),
  app/javascript/api/orders.ts (the typed-client pattern to copy)
- [ ] Change: typed client for the frozen contract ([{id, title, read_at, created_at}],
  POST .../:id/read → 204), bell with unread count, dropdown with read-on-click
- [ ] Test / evidence: component test at NotificationBell and NotificationDropdown —
  bell shows the count; click marks read
- [ ] Command: yarn vitest run app/javascript/components/__tests__/notifications
- Owner: frontend-developer
- Done when: component tests green against the contract's mock

## High-risk surfaces touched
None.

## Spec coverage (both directions)
Forward — each criterion names the task that proves it:
- list endpoint, unread first → Task 1
- read endpoint, marks read → Task 1
- bell shows unread count → Task 2
- dropdown reads on click → Task 2

Reverse — every task traces to a spec line; anything that does not is cut:
- Task 1-2 each map to a criterion above.
- "add email notifications too" — no spec line asked for it → cut to a follow-up.

## Parallel layout
Parallel — contract: `docs/rolepod/plans/notifications-cohesion-2026-05-20.md` (merge order there: backend first, it provides the API contract).

## Done criteria
Both task sets green; the live bell updates against the real API.

## Failure policy
Template default. Also stop on contract drift — fix the contract first at integration.

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
| Merge order | Unstated | In the contract, backend first — the plan's Blocked by stays "none" on both because each builds against the frozen mock |
| API contract | Unstated — drift guaranteed | Frozen in the contract; integration owner re-verifies |
| Tests | None | Per task: request spec / component test with an assertion + a runnable Command |
| Loop | Not runnable | Checkboxes + Failure policy incl. the contract-drift stop rule |

> Scenario 2 is parallel — but the good plan still names a merge order and a
> single integration owner. Parallel is not "everyone edits at once"; it is
> disjoint ownership plus a contract. If files cannot be split cleanly, the
> good answer is sequential, not a vague contract.

