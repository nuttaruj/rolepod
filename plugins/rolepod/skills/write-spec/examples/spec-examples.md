<!-- Spec examples for write-spec. Two scenarios, each a good/bad pair. -->
<!-- Read the WHOLE file — the contrast between good and bad IS the lesson. -->
<!-- Scenario 1 touches a high-risk surface (auth); scenario 2 touches none. -->
<!-- A spec is NOT security-heavy by default — risk depth matches the surface. -->

# Spec Examples

Each scenario shows the same feature specced badly and well, plus a table of
why the good version wins. Compare the pair — do not read one half alone.

---

## Scenario 1: Password reset via email (touches auth + security)

### Good

```text
# Password Reset via Email Spec

## Goal
Let a locked-out user regain account access without contacting support.

## User / actor
A registered user who has forgotten their password and can still access
their account email.

## Non-goals
- No SMS / 2FA-based reset (email only this round).
- No admin-initiated reset flow.
- No password strength rule changes — reuse the existing validator.

## Current behavior
No reset path exists. A locked-out user emails support, who resets
manually. ~15 tickets/week.

## Desired behavior
User requests a reset on the login page, receives an email with a
time-limited link, sets a new password, and is logged in.

## Success criteria
- Reset link works once and expires 30 minutes after issue.
- A used or expired link shows a clear error and a re-request option.
- An unknown email returns the same neutral response as a known one
  (no account enumeration).
- A new password runs through the existing strength validator.

## Constraints
- Stack: existing Rails app + Postgres + the current SMTP provider.
- Reset tokens stored hashed, never plaintext.
- Ship behind the `password_reset` feature flag.

## High-risk surfaces
- auth — issues a credential-changing capability.
- security — token must resist guessing and replay; flow must not leak
  account existence.

## Chosen approach
Single-use signed token, SHA-256 hashed at rest, 30-minute TTL, consumed
on first successful password set. Reuses the existing mailer + validator.

## Rejected approaches
- Stateless JWT reset link — cannot be revoked once issued; a leaked link
  stays valid for its whole TTL with no server-side kill switch.
- 6-digit email code — larger brute-force surface, needs rate-limit
  infrastructure not in scope this round.

## Open questions
None.
```

### Bad

```text
# Password Reset Spec

## Goal
Improve the login experience and make auth better.

## Non-goals
TBD

## Desired behavior
First add a reset_tokens table. Then build the mailer. Then add the
controller action and wire the route.

## Success criteria
- Password reset works well and is secure.

## Constraints
We should probably store tokens safely if needed.

## Approach
Use a JWT link. Also add SMS reset and a new password strength meter
while we are in there.
```

### Why good wins

| Area | Bad | Good |
|------|-----|------|
| Goal | Vague, two outcomes ("experience" + "auth better") | One checkable outcome — regain access |
| Non-goals | `TBD` placeholder shipped | SMS / admin / strength-rules explicitly cut |
| Behavior | Implementation order leaked in (write-plan's job) | Observable behavior only |
| Success criteria | "works well and is secure" — not pass/fail | Single-use, 30-min TTL, neutral response — each pass/fail |
| Constraints | Hedged ("should", "probably", "if needed") | Binding: hashed tokens, feature flag |
| Risk | No `High-risk surfaces` section at all | auth + security named with reasons |
| Approach | Unaudited JWT + scope creep (SMS, meter) | Chosen token + rejected JWT/code with reasons |

---

## Scenario 2: CSV export on the orders report (no high-risk surface)

### Good

```text
# Orders CSV Export Spec

## Goal
Let a user download the currently filtered orders list as a CSV file.

## User / actor
Any logged-in user who can already view the orders report. No new role
or permission.

## Non-goals
- No scheduled / recurring exports.
- No PDF or Excel formats — CSV only.
- No export of fields beyond what the report table already shows.

## Current behavior
The orders report renders on screen only. To get data out, users copy
rows by hand or ask an analyst for a database dump.

## Desired behavior
An "Export CSV" button downloads a CSV of exactly the rows the current
filters produce, with the same columns as the on-screen table.

## Success criteria
- The CSV row set equals the filtered table row set — same filters,
  same count.
- Column order and headers match the on-screen table.
- While the file generates, the button shows a loading state and is not
  double-clickable.
- Exporting a filter range with zero orders downloads a header-only CSV,
  not an error.

## Constraints
- Stack: existing React frontend + the current reports API.
- Generation must stay within the existing 30-second API timeout.

## High-risk surfaces
None — read-only export of data the user can already see on screen. No
credential, billing, or permission change.

## Chosen approach
Server builds the CSV from the same query the report table uses, streamed
as an attachment. Reusing the filter query means the export can never
drift from the table.

## Rejected approaches
- Client-side CSV from already-loaded rows — the table is paginated, so
  the client holds only one page; the export would silently miss rows.

## Open questions
None.
```

### Bad

```text
# Export Spec

## Goal
Make the orders report more useful and let people get data out.

## Non-goals
None really.

## Desired behavior
Add an export button, then build a /export endpoint, then add a queue
worker for big files.

## Success criteria
- Export is fast and gives users what they need.

## Approach
Generate the CSV on the client. Also add Excel and PDF export and a
scheduled-email option.
```

### Why good wins

| Area | Bad | Good |
|------|-----|------|
| Goal | "more useful" — two vague outcomes | One outcome — download filtered rows as CSV |
| Non-goals | "None really" hides scope creep | Excel / PDF / scheduled explicitly cut |
| Behavior | Implementation order leaked in | Observable behavior only |
| Success criteria | "fast" / "what they need" — not pass/fail | Row set == filtered table, header-only on empty — each pass/fail |
| Risk | Section omitted entirely | `None` stated deliberately, with the reason |
| Approach | Client-side, unaudited against pagination | Server-side + rejected client-side with the pagination reason |

> Scenario 2 has no high-risk surface — and the good spec still states
> `High-risk surfaces: None` on purpose. Omitting the section is the bug;
> a deliberate "None" is correct. Do not invent security depth that the
> feature does not have.
