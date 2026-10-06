<!-- Rolepod simplification report — the canonical output of simplify-code. -->
<!-- Behavior-preserving: the same tests pass before AND after. Delete <hints>. -->

# <File / Region> Simplification Report

## Baseline
<The test suite, green BEFORE any cut.>
- `<command>` — PASS: <proof line>

## Cuts made
<One entry per cut. "None — <why nothing met the bar>" is a complete finding;
 do not force a cut to have something to show.>
- `file:line` — <before> → <after> — <why: caller needs to know less / one
  fewer edit point for the next change to this rule>

## Patterns centralized
<Anything that appeared in 3+ places, and its new single home. "None" is
 valid.>
- <pattern> → <new home>

## Tests after
<The Baseline suite, run once after the last cut (each cut passed its own
 narrow check before the next).>
- `<command>` — PASS: <proof line>

## Behavior preserved
<YES — the tests covering the affected inputs and failure modes are green
 with the same expected values.
 NO — an expected value changed, or the green tests do not cover the affected
 inputs / failure modes; this is a behavior change (or insufficient coverage),
 never shipped as a simplification.>
YES | NO
