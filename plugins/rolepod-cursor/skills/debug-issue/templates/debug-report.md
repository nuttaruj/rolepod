<!-- Rolepod debug report — the canonical output of debug-issue. -->
<!-- Delete the <hints>. -->

# <Bug> Debug Report

<!-- Report-only mode (QA hand-off): fill Error / Repro / Severity, Root
     cause only if cheap to trace; leave Failing test + Fix empty — the
     owning dev continues from this artifact. -->

## Error
<The literal error message / wrong output.>

## Severity
<BLOCKER / MAJOR / MINOR — user impact + affected flows. Required in
 report-only mode; optional when the same person fixes it below.>

## Repro
<The one deterministic command that reproduces it.>

## Root cause
<The upstream condition that caused it — file:line — and why the trace
 legitimately stops here (external input / system boundary / by design).>

## Failing test
<The test written to capture the bug — path::name. RED before the fix,
 GREEN after.>

## Fix
<Files changed + the minimal change made. No "while I'm here" refactor.>
- `path` — <change>

## Verification
<Commands run + result. Full module suite green, no new red.>
- `<command>` — <result>

## Status
<COMPLETED — bug fixed, the failing test now green, suite clean.
 COMPLETED (report-only) — repro + severity documented; fix intentionally
 handed to the owning dev, not in scope.
 PARTIAL — root cause found, fix incomplete — what remains.
 BLOCKED — cannot reproduce or cannot fix — what is needed.>
COMPLETED | PARTIAL | BLOCKED
