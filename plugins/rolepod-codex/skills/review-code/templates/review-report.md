<!-- Rolepod review report — the canonical Review-phase artifact. -->
<!-- Findings before fixes — never a silent rewrite. Delete the <hints>. -->

# <Feature / PR> Review

## Scope
<What was reviewed — the diff, the spec it implements, and every changed
 file once: `read` or `skipped — reason`. A changed file missing from this
 list makes the report a partial return.>

## Read
<R4: each claimed behavior → the path walked and where it held or failed. A
 lens (R2 / R3): the diff and the callers read. On a clean review this
 section IS the evidence.>

## Risk surfaces touched
<auth / billing / payments / credits / migration / data deletion / secrets /
 tokens / crypto / permissions / security — plus API contract / perf / UI.
 "None" is valid — state it deliberately.>

## Reviewers
<Which reviewer roles ran, and that the round is complete — every
 dispatched reviewer returned before any fix; N reports merged → U unique
 findings (dedup key: file:line + root cause). For a high-risk diff, name
 the adversarial fresh-context reviewer and confirm it ran on a different
 CLI than the Lead's, or is the internal strong pass.>

**Cross-model adversarial pass:** <ran on `<cli>` (cross-family, its default model — receipt: ROLEPOD-XFAM ok … raw=<path>) |
 ran on `<cli>`, model family not reported (a CLI preset with no family
 field — the receipt still clears the gate) | NOT RUN — cross-family off
 (opt-in; the user's choice — a note, not a limitation) | vertical — same
 CLI, reason (own CLI's stronger tier as cold reviewer; not a cross-family
 pass) | NOT RUN — reason (pool failed / empty; Lead floor covered every
 axis instead). Vertical or a NOT RUN other than opt-in-off on a high-risk
 diff is a recorded verification limitation — `finish-work`'s Reviewer gate
 surfaces it before merge.>

## Findings
<Severity-ordered. Each finding: file:line — issue — why it matters — fix
 direction (a direction, not a rewrite; the author fixes). Round 2+ (the
 previous report is in the brief): prefix each finding IN-FIX (a defect
 inside the previous round's fixes) / NEW (not flagged before) / REPEAT
 (flagged before, still open) — the Lead's phase-log line counts them.
 A pre-existing issue on a path the diff does not touch → list once under
 "Adjacent", never a verdict driver; the author parks it in Follow-ups.>

### BLOCKER — must fix before merge
- `file:line` — <issue> — <why it matters> — <fix direction>

### MAJOR — fix or explicitly document
- `file:line` — <issue> — <why it matters> — <fix direction>

### MINOR — nice to fix
- `file:line` — <issue> — <fix direction>

## Questions
<Anything unclear that needs an author answer, not a fix.>
- `file:line` — <question>

## Tests reviewed
<yes / no — and the verdict: assertions strong? mocks at the right boundary?
 concurrency covered?>

## Recommendation
<APPROVED — nothing open above MINOR.
 APPROVED-WITH-NITS — only MINOR / Questions remain, none of which would change a correctness or security verdict.
 REJECTED — any open BLOCKER introduced by this diff or pre-existing on a
 path it changes, or such a MAJOR neither fixed nor explicitly documented
 per its heading above. A pre-existing issue on an untouched path never
 makes a REJECTED.>
APPROVED | APPROVED-WITH-NITS | REJECTED — <one-line reason>
