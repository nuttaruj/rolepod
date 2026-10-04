<!-- Use these fields inside the named task receipt; do not create another manifest. -->
<!-- Owner status is distinct from Verify status. Delete the <hints>. -->

## Decision brief

### Change
<Every path touched + a one-line what-changed.>
- `path` — <what changed>

### Tests added / changed
<Test files touched + what each new test asserts.>
- `path` — <assertion>

### Commands
<Exact commands run, each with its result, plus the proof — the specific
 test output lines / lint-typecheck result / screenshot path that show they
 passed, not the full log.>
- `<command>` — <result>

### Scope check
<Confirm the diff matches the task — no "while I'm here" extras. List any
 follow-up ideas deferred; do not act on them here.>

### Concerns
<Doubts to flag for the Lead — correctness ("not sure this covers the empty
 case"), scope ("this spilled into module Y"), or observation ("this file is
 getting large"). "None" is valid — state it deliberately.>

### Author fix closure
<For each finding fixed, give report pointer, finding id/location, fix, and
proof pointer. Leave findings and full review rationale in the reviewer report.>
- Delta H1→H2: <changed paths + delta hash>
- H2: <verified snapshot after the fixes>
- Re-check: <report path of the Fix-verify re-check at H2, or `none — no BLOCKER / MAJOR fixed`>

### Owner status
COMPLETED | PARTIAL | BLOCKED

## Verify status
VERIFIED | PARTIAL | UNVERIFIED

## Handoff
<Only facts the next blocked task consumes: signatures, invariants, and pointers.>

## Reviews
<Pointers to reviewer reports; findings remain in their reports.>

## Lead notes
<Plan progress as one line: sha / verdict / receipt or evidence pointer.>
