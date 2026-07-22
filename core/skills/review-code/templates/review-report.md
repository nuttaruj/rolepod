<!-- Rolepod review report — the canonical Review-phase artifact. -->
<!-- Findings before fixes — never a silent rewrite. Delete the <hints>. -->

# <Feature / PR> Review

## Scope
<What was reviewed — the diff, the files, the spec it implements.>

## Claims traced
<Each behavior the change claims → the path walked (entry → branches → exit)
 and where it held or failed. Findings marked TRACED must anchor to a step
 here. On a clean review this section IS the evidence — a bare APPROVED with
 an empty trace list is not a review.>

## Risk surfaces touched
<auth / billing / payments / credits / migration / data deletion / secrets /
 tokens / crypto / permissions / security — plus API contract / perf / UI.
 "None" is valid — state it deliberately.>

## Reviewers
<Which reviewer roles ran. For a high-risk diff, name the adversarial
 fresh-context reviewer and confirm its model differs from the Lead's.>

**Cross-model adversarial pass:** <ran on `model` (cross-family) |
 vertical — same family, reason (own CLI's stronger tier as cold reviewer;
 not a cross-family pass) | NOT RUN — reason (e.g., 0 external CLIs on PATH;
 Lead floor covered every axis instead). Anything other than a cross-family
 pass on a high-risk diff is a recorded verification limitation, not a pass —
 `finish-work`'s Reviewer gate surfaces it before merge.>

## Findings
<Severity-ordered. Each finding: file:line — issue — why it matters — fix
 direction (a direction, not a rewrite; the author fixes).>

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
<APPROVED — no BLOCKER / MAJOR.
 APPROVED-WITH-NITS — only MINOR / Questions remain.
 REJECTED — at least one BLOCKER.>
APPROVED | APPROVED-WITH-NITS | REJECTED — <one-line reason>
