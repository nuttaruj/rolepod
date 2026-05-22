<!-- Rolepod hypothesis ledger — the running debug experiment log. -->
<!-- One row per experiment. A new hypothesis must hold against EVERY -->
<!-- prior row, not just the last. Delete the <hint> row. -->

# <Bug> — Hypothesis Ledger

## Symptom
<The exact error / wrong output. Literal quote.>

## Repro
<The one deterministic command that reproduces it.>

## Experiments

| # | Hypothesis | Cheapest falsifier | Result | Ruled in / out |
|---|------------|--------------------|--------|----------------|
| 1 | <state X is wrong because upstream Y> | <log / read / breakpoint> | <what happened> | <what it eliminated> |

## Root cause
<Filled once the trace reaches a legitimate stopping point — external input,
 a system boundary, or an intentional invariant. file:line.>
