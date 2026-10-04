<!-- Rolepod hypothesis ledger — the running debug experiment log. -->
<!-- One row per experiment. A new hypothesis must hold against EVERY -->
<!-- prior row, not just the last. Delete the <hint> row. -->

# <Bug> — Hypothesis Ledger

## Symptom
<The exact error / wrong output. Literal quote.>

## Repro
<The one command that reproduces it. Intermittent: the N-run loop — N, the
 per-run failure rate, the conditions (order, load, seed, clock).>

## Experiments

| # | Hypothesis | Cheapest falsifier | Result | Ruled in / out |
|---|------------|--------------------|--------|----------------|
| 1 | <state X is wrong because upstream Y> | <log / read / breakpoint> | <what happened> | <what it eliminated> |

## Fix attempts
<A fix attempt = a change meant to turn the repro green that left it red; a
 falsifier, a log or a revert is not one. The brief's `Attempts:` line rows
 come first.>

| # | From | Fix (file — change) | Repro after | Why it stayed red |
|---|------|---------------------|-------------|-------------------|
| 1 | <implement-plan / check-work / this run> | <path — change> | <red: literal line> | <what the fix missed> |

Failed fixes: <n> of 4 · Second opinion: pending | done — <correction / confirmation / stop / no usable advisor: reason>. After two failures, consult once before another fix; no usable advisor means stop. Carry this count across owners and phases for the same repro or criterion.

## Root cause
<Filled once the trace reaches a legitimate stopping point — external input,
 a system boundary, or an intentional invariant. file:line.>
