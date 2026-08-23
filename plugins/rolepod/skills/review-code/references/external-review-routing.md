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
- **Vertical fallback — same family, stronger tier.** When the external pool
  is empty (single-CLI machine) or every member failed at invoke: the Lead's
  own CLI at its strongest model — ask the CLI which models it exposes
  (`--help` / model list), then invoke `claude -p --model <that name>` /
  `codex exec -m <that name>` / `gemini -m pro -p` — cold context, only valid
  when that model differs from the one now running (cannot tell which model
  is running → vertical unavailable, record NOT RUN). Same family — it never
  counts as the cross-family adversarial pass; it upgrades the Lead floor.

## Clean-room invocation — prefix every external reviewer call

Prefix EVERY external reviewer / vertical-fallback invocation with
`ROLEPOD_BRAIN_SILENT=1` (e.g. `ROLEPOD_BRAIN_SILENT=1 codex exec …`).
Ambient memory systems (rolepod-brain, or anything hook-based) may inject the
project's shared memory into headless runs — the reviewer then inherits the
author's own narrative ("we fixed X correctly"), which destroys the
decorrelation the adversarial pass exists for, and its review process gets
captured back into shared memory. The flag is a public rolepod-brain contract
(no injection, no capture); harmless when nothing honoring it is installed.
The reviewer's input is the CURATED brief you write (artifact + acceptance
criteria + settled decisions) — never ambient memory.

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
4. Launch every routed reviewer — externals and internal agents alike — in
   ONE dispatch; they read the same frozen diff independently, so nothing
   is gained by waiting for one before starting the next.

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
| 0 cross-family | Vertical fallback takes the dominant axis as a cold-context reviewer; the floor covers the rest. Record "vertical — same family" in the Cross-model line |
| 0 + no vertical | Lead floor only — `qa-tester` + the full multi-axis read |

**Installed ≠ usable.** A binary on PATH can still fail at invoke — auth
error, quota exhausted, empty output. On failure: retry ONCE at most, then
treat that external as not installed — route the axis to the next external
or the Lead floor, and record the failure reason (e.g. "gemini: quota
exhausted") in the review report's Cross-model line. Never loop on a dead
external, never silently drop the axis.

On a high-risk surface with no cross-family external, the floor (plus the
vertical fallback when one exists) still reviews every axis — but the review
report's **Cross-model adversarial pass** line must record NOT RUN (or
"vertical — same family") and why, and `finish-work`'s Reviewer gate surfaces
that limitation to the user before merge. It is a real verification
limitation, not a pass.

## Satellite-first — the external IS the strong pass

Real installs run one main subscription (any family) plus cheaper satellite
plans that would otherwise idle. Each plan is a separate flat-rate quota
pool; the scarce resource is the MAIN plan's quota window, and the main
always carries implementation — so one-shot cold-context work routes to a
satellite first whenever a healthy non-Lead family is on PATH:

- **R4 strong adversarial pass** — the routed cross-family external IS the
  strong pass (better decorrelated than a same-family strong reviewing its
  own family's work). Anchor it per review-code §Output — raw output saved
  under `.rolepod/evidence/external/` + the extended review line — or the
  commit gate ignores it. Internal strong (security-engineer /
  universal-reviewer) fires only on the three carve-outs in review-code §1:
  empty pool, apex trigger (then BOTH passes), fix-verify re-read.
- **Outside opinion** (debug-issue §9), **judge / second opinion** on a
  design — already cold one-shot by shape; same satellite-first order.

This never widens WHO reviews (R1-R3 routing unchanged) — it only moves the
strong-class tokens R4 already spends off the main plan. A satellite that
fails at invoke follows the degradation table above; the internal strong
reviewer is the fallback, never skipped silently.
