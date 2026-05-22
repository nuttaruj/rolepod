<!-- Rolepod debug report — the canonical output of debug-issue. -->
<!-- Delete the <hints>. -->

# <Bug> Debug Report

## Error
<The literal error message / wrong output.>

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
