<!-- Load when routing the adversarial pass in a cross-CLI review. -->
<!-- review-code's step 1 carries the trigger; this file is the routing. -->

# External review routing

Rolepod's CLIs span three model families — Claude, Codex (GPT), and
Gemini (served by both `gemini` and `agy`/Antigravity). Any CLI can be the
Lead. The adversarial review pass routes by model strength, never to the
Lead's own model **family** — gemini and agy run the same family, so one
never reviews the other's work as "external".

## The pool

- **Lead** — the CLI running this session. It reviews its own work only
  through the Lead floor (below), never as the adversarial reviewer.
- **External pool** — the other model families, when a binary is on PATH:
  `command -v codex` / `command -v gemini` / `command -v claude` /
  `command -v agy`. When both `gemini` and `agy` are installed they count
  as ONE pool member (same family); prefer `gemini`.

## Model strength — one axis each, no overlap

| Model family | Reviews best | Invoke |
|-------|--------------|--------|
| Codex | depth · security · logic rigor | `codex exec` |
| Gemini | breadth · cross-file · large-diff sweep | `gemini -m pro -p`, or `agy -p` when only agy is installed |
| Claude | architecture · code quality · maintainability | `claude -p` |

## Routing

1. Read the diff; name the axes it needs (a diff can need several).
2. For each axis, route to the external whose strength matches — if that
   external is in the pool (installed AND not the Lead).
3. A diff spanning two axes uses two externals, one per axis.

**Lead-exclusion overrides strength — and it excludes the family, not just
the binary.** If the strength-matched reviewer runs the Lead's model family
(a Gemini Lead vs `agy`, an agy Lead vs `gemini`), that axis cannot go to
it — route the axis to the next available external, or to the Lead floor.

> Example: a breadth-heavy diff, Lead = Gemini. Gemini owns breadth but is
> the Lead — it cannot review its own work. The breadth axis falls to Claude
> or Codex; if neither is on PATH, to the Lead floor.

## The Lead floor — covers every axis

The Lead floor is `qa-tester` (a fresh-context subagent) plus the Lead's own
multi-axis read (the step-2 axis walk). It is the universal generalist: it
reviews **every** axis — correctness, security, breadth, architecture, perf,
UI — not one specialty.

Strength routing is an optimisation on top of the floor: it assigns a
specialist to an axis when one is available; it never removes an axis. A
specialist that is missing, is the Lead, or has failed → that axis falls
back to the floor.

## Degradation

| External pool | Routing |
|---------------|---------|
| 2 externals | Route axes to both by strength; the floor backstops correctness |
| 1 external | It takes the diff's dominant axis; the Lead floor covers the rest |
| 0 externals | Lead floor only — `qa-tester` + the full multi-axis read |

On a high-risk surface with 0 externals, the floor still reviews every axis —
but the review report's **Cross-model adversarial pass** line must record
NOT RUN and why, and `finish-work`'s Reviewer gate surfaces that limitation
to the user before merge. It is a real verification limitation, not a pass.
