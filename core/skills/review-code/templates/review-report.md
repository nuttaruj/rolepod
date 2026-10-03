<!-- Rolepod review report — the canonical Review-phase artifact. -->
<!-- Findings before fixes — never a silent rewrite. Delete the <hints>. -->

# <Feature / PR> Review

## Scope
<What was reviewed — the diff, the spec it implements, and every changed
 file once: `read` or `skipped — reason`. A changed file missing from this
 list makes the report a partial return.>
**Snapshot H1 (immutable):** `<base sha>..<head sha>` <+ `diff <git diff HEAD | git hash-object --stdin>` for uncommitted work. Lite lens reports must record the identical frozen snapshot/hash; each report names only its own lens. Never relabel H1 as a later snapshot; a reviewer re-check gets a separate report.

## Read
<`security-engineer` and the adversarial pass: each claimed behavior → the
 path walked and where it held or failed. A lens (any tier): the diff and the
 callers read. On a clean review this
 section IS the evidence.>

## Risk surfaces touched
<auth / billing / payments / credits / migration / data deletion / secrets /
 tokens / crypto / permissions / security — plus API contract / perf / UI.
 "None" is valid — state it deliberately.>

## Reviewers
<Which reviewer roles ran, and that the round is complete — every
 dispatched reviewer returned before any fix; N reports merged → U unique
 findings (dedup key: file:line + root cause). For an R4 (high-risk)
 diff, name the adversarial pass (`adversarial-review`) and confirm it ran on
 a different CLI than the Lead's, or is the internal strong pass.>

**Lite isolation** (Lite only — remove otherwise): <lens: spec | lens: standards>; fresh context: yes; received only this lens: yes; other report/findings visible: no; snapshot/hash matches paired report: yes.

## Author fix closure
<For Lite and other no-recheck branches, the merged report records each finding's author closure. Keep the original lens reports immutable at H1.>

| Finding | Closure evidence (repro/test + result) | Bounded fix delta H1→H2 (paths + delta hash) | Final verified snapshot H2 | Covered by finding fix? |
|---|---|---|---|---|
| `<finding id>` | `<specific evidence>` | `<paths; hash>` | `<tree id>` | yes / no |

<A green suite alone does not close a finding. Unrelated or new changes are uncovered and must be surfaced and routed at their current tier and mode.>

**Cross-model adversarial pass** (R4 only — delete the line otherwise): <ran on `<cli>` (cross-family, its default model — receipt: ROLEPOD-XFAM ok … raw=<path>) |
 ran on `<cli>`, model family not reported (a CLI preset with no family
 field — the receipt still clears the gate) | NOT RUN — cross-family off
 (opt-in; the user's choice — a note, not a limitation) | NOT RUN — wide-effort session
 (the user's choice — a note, not a limitation) | vertical — same
 CLI, reason (own CLI's stronger tier as cold reviewer; not a cross-family
 pass) | NOT RUN — reason (pool failed / empty; the internal strong
 pass ran instead). Vertical or a NOT RUN other than
 opt-in-off or wide-effort session on a high-risk diff is a recorded verification limitation —
 `finish-work`'s Reviewer gate surfaces it before merge. No fresh reviewer
 at all (the Lead's own walk in its place) blocks the merge until the user
 waives it.>

## Findings
<Severity-ordered. Each finding: file:line — axis — issue — why it matters —
 fix direction (a direction, not a rewrite; the author fixes). The axis
 (spec / standards / security / perf / UI / architecture) and, in a merged
 report, the reviewer stay on every finding. A reviewer's
 other scale maps in: CRITICAL/HIGH → BLOCKER, WARNING/MEDIUM → MAJOR,
 SUGGESTION/LOW → MINOR. A pre-existing issue on a path the diff does
 not touch → one line under `## Follow-ups` below, never a verdict driver.>

### BLOCKER — must fix before merge
- `file:line` — <axis> — <issue> — <why it matters> — <fix direction>

### MAJOR — fix; only a pre-existing one may be parked in Follow-ups with its reason
- `file:line` — <axis> — <issue> — <why it matters> — <fix direction>

### MINOR — nice to fix
- `file:line` — <axis> — <issue> — <fix direction>

## Questions
<Anything unclear that needs an author answer, not a fix.>
- `file:line` — <question>

## Follow-ups
<Issues this review will not fix: pre-existing on an untouched path, or
 outside a round 2+ fix delta — each with its axis, never a verdict driver.
 The author copies every line into the plan's `## Follow-ups`, the list
 finish-work carries. "none" when empty.>
- `file:line` — <axis> — <issue>

## Tests reviewed
<yes / no — and the verdict: assertions strong? mocks at the right boundary?
 concurrency covered?>

## Recommendation
<APPROVED — nothing open above MINOR; a pre-existing MAJOR parked in Follow-ups with its reason is closed.
 APPROVED-WITH-NITS — only MINOR / Questions remain, none of which would change a correctness or security verdict.
 REJECTED — any open BLOCKER introduced by this diff or pre-existing on a
 path it changes, or such a MAJOR neither fixed nor — pre-existing only —
 parked in Follow-ups with its reason. A pre-existing issue on an untouched
 path never makes a REJECTED.>
APPROVED | APPROVED-WITH-NITS | REJECTED — <one-line reason>
