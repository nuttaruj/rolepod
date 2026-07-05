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
  never to decide cheaper.
- **Cold context.** The Anthropic advisor shares the executor's context. A
  cross-CLI advisor does not — it starts cold. The Lead must pack the decision,
  the options, and the constraints into the prompt; the advisor sees only what
  the Lead frames.

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
   uncertainty. Not a call the Lead can make cheaply.
2. **High-stakes** — at least one of: high-risk surface (auth / billing /
   migration / data-model / security), hard to reverse, or a new integration /
   unproven assumption.
3. **Opted in** — `/rolepod-full`, or the user explicitly asked other CLIs to
   help decide ("get Codex and Gemini to weigh in on the approach").

## Stuck-state consult (Build / Debug) — auto, NOT gated

The plan panel above is opt-in because a plan decision is speculative. The
debug variant is not: **three failed fix attempts** (debug-issue Iron Rule 5)
are objective evidence the Lead cannot resolve it alone. So there:

- the consult fires **automatically** — no `/rolepod-full`, no user ask;
- it uses **ONE advisor**, never a panel — debug-issue §9 fixes the pick
  deterministically (first installed non-family external, in §9's listed
  order). No strength-table routing mid-bug: a stuck Lead needs a recipe,
  not a judgment call;
- the advisor's correction unlocks exactly **one** advisor-informed fix
  attempt, then escalation to the user proceeds regardless.

The step-by-step recipe lives inline in debug-issue §9, so the Lead never
opens this file mid-bug; this file carries the shared machinery — pool
detection, the family rule, fail-at-invoke, cold-context framing.

## The pool

- **Lead (executor)** — this session's CLI. It frames the decision and owns the
  outcome; it is not a panelist (it is already the one deciding).
- **Advisor pool** — the other model **families** on PATH: `command -v codex` /
  `command -v gemini` / `command -v claude` / `command -v agy`. Same detection
  and family rule as review: gemini and agy are one family (one pool member,
  prefer `gemini`; invoke `agy -p` when only agy is installed), and a family
  matching the Lead's is excluded.

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

| Model family | Advises best on | Invoke |
|-------|-----------------|--------|
| Codex | correctness risk, security implications, logic depth of an approach | `codex exec` |
| Gemini | breadth, cross-file / large-surface impact, alternatives sweep | `gemini -m pro -p`, or `agy -p` when only agy is installed |
| Claude | architecture, maintainability, API / interface shape | `claude -p` |

Route the decision's dominant dimension to the model that owns it; a decision
spanning two dimensions can go to two advisors.

## Protocol — collect, then Lead decides

The panel is **input, not a binding vote**. The failure mode is three
conflicting plans and no decision — the protocol exists to prevent it.

1. **Frame once (cold context).** Lead writes the decision as: the question, the
   2-3 options, the constraints, the done-criteria — enough for a cold advisor
   to reason without the session. Send the *same* framing to each advisor.
2. **Poll in parallel.** Each advisor returns its option / correction / stop
   plus reasoning. Run concurrently where the harness allows.
3. **Reconcile.** Lead collects, dedups overlapping points, and marks where the
   panel agrees vs conflicts.
4. **Decide and own.** Lead picks the option and writes it into the plan —
   recording the choice, one line on why, and any dissent worth carrying into
   the plan's `## Risks`. The panel does not block or override the Lead.

## Degradation

| Advisor pool | Routing |
|---------------|---------|
| 2 advisors | Full panel by strength; Lead reconciles and decides |
| 1 advisor | Single advisor on the dominant dimension; Lead reasons through the rest |
| 0 advisors | Lead reasons through the options solo; record in the plan that no cross-model advice was gathered — a coverage note, not a failure |

**Installed ≠ usable.** An advisor that fails at invoke (auth error, quota
exhausted, empty output) → retry ONCE at most, then treat it as absent and
drop to the matching degradation row, noting the reason in the plan (e.g.
"agy: quota exhausted — advised by Codex only"). Never loop on a dead
advisor.

## Cost discipline

A better decision buys the cost — so spend it only where a better decision
pays. One panel per genuinely hard, high-stakes decision — not per task, not
per option. If two decisions are entangled, frame them together in a single
panel. Do not re-poll the panel for minor follow-ups the Lead can settle alone.
