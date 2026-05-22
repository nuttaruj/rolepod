<!-- Load when routing the adversarial pass in a cross-CLI review. -->
<!-- review-code's step 1 carries the trigger; this file is the routing. -->

# External review routing

Rolepod runs on three CLIs — Claude, Codex, Gemini. Any one can be the Lead.
The adversarial review pass routes by model strength, never to the Lead's
own model.

## The pool

- **Lead** — the CLI running this session. It reviews its own work only
  through the Lead floor (below), never as the adversarial reviewer.
- **External pool** — the other two CLIs, when the binary is on PATH:
  `command -v codex` / `command -v gemini` / `command -v claude`.

## Model strength — one axis each, no overlap

| Model | Reviews best | Invoke |
|-------|--------------|--------|
| Codex | depth · security · logic rigor | `codex exec` |
| Gemini | breadth · cross-file · large-diff sweep | `gemini -m pro -p` |
| Claude | architecture · code quality · maintainability | `claude -p` |

## Routing

1. Read the diff; name the axes it needs (a diff can need several).
2. For each axis, route to the external whose strength matches — if that
   external is in the pool (installed AND not the Lead).
3. A diff spanning two axes uses two externals, one per axis.

**Lead-exclusion overrides strength.** If the strength-matched reviewer is
the Lead itself, that axis cannot go to it — route the axis to the next
available external, or to the Lead floor.

> Example: a breadth-heavy diff, Lead = Gemini. Gemini owns breadth but is
> the Lead — it cannot review its own work. The breadth axis falls to Claude
> or Codex; if neither is on PATH, to the Lead floor.

## The Lead floor — covers every axis

The Lead floor is `qa-tester` (a fresh-context subagent) plus the Lead's own
multi-axis read (the step-2 axis walk). It is the universal generalist: it
reviews **every** axis — correctness, security, breadth, architecture, perf,
UI — not one specialty.

Strength routing is an optimisation on top of the floor. It assigns a
specialist to an axis when one is available; it never removes an axis. If
the specialist for an axis is missing, is the Lead, or has failed, that axis
still gets reviewed — by the floor. No axis is ever skipped because "that
was the other CLI's job".

## Degradation

| External pool | Routing |
|---------------|---------|
| 2 externals | Route axes to both by strength; the floor backstops correctness |
| 1 external | It takes the diff's dominant axis; the Lead floor covers the rest |
| 0 externals | Lead floor only — `qa-tester` + the full multi-axis read |

On a high-risk surface with 0 externals, the floor still reviews every axis —
but `check-work` must record that no different-model adversarial pass ran.
That is a real verification limitation, not a pass.
