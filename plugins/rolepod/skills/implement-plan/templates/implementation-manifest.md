<!-- Rolepod implementation manifest — the canonical Build-phase artifact. -->
<!-- What implement-plan returns. A subagent returns this; the Lead commits. -->
<!-- Delete the <hints>. -->

# <Task / Feature> Implementation Manifest

## Files changed
<Every path touched + a one-line what-changed.>
- `path` — <what changed>

## Tests added / changed
<Test files touched + what each new test asserts.>
- `path` — <assertion>

## Verification
<Exact commands run, each with its result, plus the proof — the specific
 test output lines / lint-typecheck result / screenshot path that show they
 passed, not the full log.>
- `<command>` — <result>

## Scope check
<Confirm the diff matches the task — no "while I'm here" extras. List any
 follow-up ideas deferred; do not act on them here.>

## Concerns
<Doubts to flag for the Lead — correctness ("not sure this covers the empty
 case"), scope ("this spilled into module Y"), or observation ("this file is
 getting large"). "None" is valid — state it deliberately.>

## Status
<COMPLETED — task done, evidence attached.
 PARTIAL — some done, what remains stated.
 BLOCKED — what blocks, and what is needed.>
COMPLETED | PARTIAL | BLOCKED
