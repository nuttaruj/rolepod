<!-- Rolepod review report — the canonical Review-phase artifact. -->
<!-- Findings before fixes — never a silent rewrite. Delete the <hints>. -->

# <Feature / PR> Review

## Scope
<What was reviewed — the diff, the files, the spec it implements.>

## Risk surfaces touched
<auth / billing / migration / secret / payment / API contract / perf / UI.
 "None" is valid — state it deliberately.>

## Reviewers
<Which reviewer roles ran. For a high-risk diff, name the adversarial
 fresh-context reviewer and confirm its model differs from the Lead's.>

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
