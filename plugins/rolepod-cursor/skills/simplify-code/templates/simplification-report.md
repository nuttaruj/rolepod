<!-- Rolepod simplification report — the canonical output of simplify-code. -->
<!-- Behavior-preserving: the same tests pass before AND after. Delete <hints>. -->

# <File / Region> Simplification Report

## Baseline
<The test suite, green BEFORE any cut. Simplifying on a red baseline is not
 allowed.>
- `<command>` — PASS: <proof line>

## Cuts made
<One entry per cut. Each cut is one commit.>
- `file:line` — <before> → <after>

## Patterns centralized
<Anything that appeared in 3+ places, and its new single home. "None" is
 valid.>
- <pattern> → <new home>

## Tests after
<The same suite, still green AFTER every cut.>
- `<command>` — PASS: <proof line>

## Behavior preserved
<YES — same tests, same assertions, all green.
 NO — a test assertion had to change; this is a behavior change. Route to
 write-spec / implement-plan; do not ship it as a simplification.>
YES | NO
