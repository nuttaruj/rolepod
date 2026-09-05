<!-- Load when a plan decision is high-stakes AND the Lead cannot confidently resolve it AND advisory mode is on. -->
<!-- write-plan step 4 carries the trigger; this file is the routing + protocol. -->

# Advisory routing

A cross-CLI **advisory panel** for open plan decisions — the other CLIs weigh
in on which approach to take, *before* the plan is drafted. The Lead frames the
decision, the advisors return guidance, the Lead decides.

## Lineage — Anthropic's advisor strategy, made multi-CLI

This is Anthropic's **advisor strategy** adapted across vendors. There an
**executor** model drives the task and consults a stronger **advisor** model on
decisions it cannot reasonably resolve; the advisor returns *a plan, a
correction, or a stop signal* and never executes tools or writes user-facing
output — the executor keeps control. Here:

- **Lead = executor.** It drives the plan and owns every decision.
- **Other CLIs = advisors.** Consulted on-demand for a hard call; they advise, they do not execute.

Two deliberate divergences from the single-vendor version:

- **Effectiveness, not cost — and peers, not a stronger boss.** Anthropic's
  version is a *cost* play: a *weaker* executor pairs with a *stronger* advisor
  to claw back frontier reasoning cheaply (asymmetric). Cross-vendor is the
  opposite on both counts. The advisors are not stronger — they are **frontier
  peers from a different lineage** (symmetric), and it costs *more*, not less.
  The win is a **better decision**: the Codex, Gemini, and Claude frontier
  models reason, fail, and notice differently, so a panel surfaces approaches
  and risks any single model misses. This holds *even when the Lead is already
  the strongest model available* — a Lead on the top Claude model still
  consults the other two families, because cross-vendor frontier diversity
  beats one model on a hard call. You spend the extra tokens to decide better,
  never to decide cheaper. (One exception: on a single-family machine the
  **vertical fallback** below reverts to Anthropic's original vertical shape —
  the Lead's own family at a stronger tier.)
- **Cold context.** The Anthropic advisor shares the executor's context. A
  cross-CLI advisor does not — it starts cold. The Lead must pack the decision,
  the options, and the constraints into the prompt; the advisor sees only what
  the Lead frames. Enforce the cold start: prefix every advisor invocation with
  `ROLEPOD_BRAIN_SILENT=1` — ambient memory systems (rolepod-brain and kin)
  may otherwise inject the project's shared narrative into the headless run,
  anchoring the advisor to the very framing it exists to challenge. Public
  contract; harmless when nothing honoring it is installed.

## Advisory vs review — same pool, opposite ends of the phase

| | When | Mode |
|---|---|---|
| **Advisory** (this file) | before the decision — options still open | generative / comparative — "which approach, and why" |
| **Review** (`review-code`'s `external-review-routing.md`) | after the work is done | adversarial — "what is wrong with this diff" |

## When to invoke — gated, not default

A panel costs one full context per advisor (~3× tokens + latency) and buys a
better decision, not a cheaper one. It is **off by default**. Invoke it only
when ALL hold:

1. **Hard to resolve** — the Lead cannot confidently settle the call alone:
   two or more genuinely viable approaches, or a decision blocked on real
   uncertainty. Not a call the Lead can make cheaply. A Lead running a
   small / fast tier sets this bar lower — the tier gap is itself uncertainty.
2. **High-stakes** — at least one of: high-risk surface (auth / billing /
   payments / credits / migration / data deletion / secrets / tokens / crypto /
   permissions / security), hard to reverse, or a new integration / unproven
   assumption.
3. **Opted in** — `/rolepod-full`, or the user explicitly asked other CLIs to
   help decide ("get Codex and Gemini to weigh in on the approach").

## Stuck-state consult (Build / Debug) — auto, NOT gated

The plan panel above is opt-in because a plan decision is speculative. The
debug variant is not: **two failed fix attempts** (debug-issue Iron Rule 5)
are objective evidence the Lead cannot resolve it alone. So there:

- the consult fires **automatically** at the second fail — no `/rolepod-full`, no user ask;
- it uses **ONE advisor**, never a panel — debug-issue §9 fixes the pick
  deterministically (first installed non-family external in §9's listed
  order, or §9's vertical fallback on a single-family machine). No
  strength-table routing mid-bug: a stuck Lead needs a recipe, not a
  judgment call;
- the advisor's correction unlocks exactly **one** advisor-informed fix
  attempt, then escalation to the user proceeds regardless.

The step-by-step recipe lives inline in debug-issue §9, so the Lead never
opens this file mid-bug; this file carries the shared machinery — pool
detection, the family rule, fail-at-invoke, cold-context framing.

## The pool

- **Lead (executor)** — this session's CLI. It frames the decision and owns the
  outcome; it is not a panelist (it is already the one deciding).
- **Advisor pool** — the user's **opt-in** cross-family pool, resolved by
  the runner (`rolepod-cross-family --pool`): `<git-root>/.rolepod/cross-family`,
  then `~/.rolepod/cross-family`, one CLI per line (`codex` / `claude` /
  `agy` / `cursor` / `opencode`); no file or `none` = off (exit 5 → vertical
  fallback; never enable unasked) — minus the Lead's own family (`agy` =
  google; cursor / opencode = the family of their configured default model).
  Same detection and family rule as review. Each advisor runs on its **own
  default model** — no model or effort flag; `TIER_MODELS` governs only the
  CLI that is the Lead.
- **Vertical fallback — same family, stronger tier.** When the runner
  reports an empty pool (exit 4) or every member failed at invoke (exit 3),
  the advisor is the Lead's **own CLI at its strongest model** — ask the CLI
  which models it exposes (`--help` / model list), then invoke `claude -p
  --model <that name>` / `codex exec -m <that name>` with the same brief.
  Valid only when that model differs from the one now running; never pin
  model names in a skill or plan, they go stale. Same-lineage advice trades
  cross-vendor diversity for a second frontier opinion — strictly better than
  solo. Already running the strongest model of the only family, or cannot
  tell which model is running → vertical is unavailable; solo row below.

## What an advisor returns

Exactly what the executor/advisor split allows — **guidance, never action**:

- a **recommended option** + reasoning + the risks it sees, OR
- a **correction** — if the framing or all the options are flawed, it says so
  and reframes, OR
- a **stop signal** — "don't take this path" with the reason.

An advisor never edits files, never runs the plan, never addresses the user.
Its output is input to the Lead.

## Model strength → decision dimension

Mirrors the review axes — same strengths, applied to *advising on an approach*
instead of *reviewing a diff*.

| Family (CLI) | Advises best on |
|-------|-----------------|
| OpenAI (`codex`) | correctness risk, security implications, logic depth of an approach |
| Google (`agy`) | breadth, cross-file / large-surface impact, alternatives sweep |
| Anthropic (`claude`) | architecture, maintainability, API / interface shape |
| Cursor / OpenCode | the family of their default model — the runner's `--pool` tells you |

Route the decision's dominant dimension to the family that owns it (the
config file's order is the routing order); a decision spanning two
dimensions goes to the whole panel.

## Protocol — collect, then Lead decides

The panel is **input, not a binding vote**. The failure mode is three
conflicting plans and no decision — the protocol exists to prevent it.

1. **Frame once (cold context).** Lead writes the decision to a file as: the
   question, the 2-3 options, the constraints, the done-criteria — enough
   for a cold advisor to reason without the session. Every advisor gets the
   same file.
2. **Poll in parallel.** `rolepod-cross-family --kind advise --brief
   <decision.md> --all` runs one member per family concurrently, read-only
   on each CLI's default model, clean room, each reply anchored under
   `.rolepod/evidence/external/` with a `phase: advise` line (15-minute
   budget per member by default; add `--detach` and `--collect` when a slow
   member is in the pool). Drop `--all` for a single advisor on the
   dominant dimension.
3. **Reconcile.** Lead collects, dedups overlapping points, and marks where the
   panel agrees vs conflicts.
4. **Decide and own.** Lead picks the option and writes it into the plan —
   recording the choice, one line on why, and any dissent worth carrying into
   the plan's `## Risks`. The panel does not block or override the Lead.

## Degradation

| Advisor pool | Routing |
|---------------|---------|
| ≥2 families | Full panel (`--all`); Lead reconciles and decides |
| 1 usable | Single advisor on the dominant dimension; Lead reasons through the rest |
| 0 usable (runner exit 3 / 4) or off (exit 5) | **Vertical fallback**: the Lead's own CLI at its strongest model (≠ the running model) as the single advisor; record "vertical consult — same family" (or "cross-family off — opt-in") in the plan |
| 0 + no vertical | Lead reasons through the options solo; record in the plan that no cross-model advice was gathered — a coverage note, not a failure |

**Installed ≠ usable.** The runner proves it at invoke: an advisor that
fails (auth error, quota exhausted, timeout, empty output) is logged as an
`external-fail` line and skipped — with `--all` the panel simply shrinks
(the receipt names who answered). Note the reason in the plan (e.g. "agy:
quota exhausted — advised by Codex only"). Never loop on a dead advisor.

## Cost discipline

A better decision buys the cost — so spend it only where a better decision
pays. One panel per genuinely hard, high-stakes decision — not per task, not
per option. If two decisions are entangled, frame them together in a single
panel. Do not re-poll the panel for minor follow-ups the Lead can settle alone.
