<!-- Load when routing the adversarial pass in a cross-CLI review. -->
<!-- review-code's step 1 carries the trigger; this file is the routing. -->

# External review routing

Rolepod's CLIs span model families — Claude, Codex (GPT), Google (served
by Antigravity `agy`; the standalone Gemini CLI is retired for individual
accounts and is never in the pool), plus the multi-model harnesses Cursor
and OpenCode (their family = whatever default model their owner configured).
Any CLI can be the Lead. The adversarial review pass routes to a **different
model family** than the Lead's, never to the Lead's own.

## One command — the cross-family runner

Every external pass goes through `rolepod-cross-family` (installed on PATH by
`install.sh`; every plugin tree also ships it as `scripts/cross-family.sh` —
the SessionStart context names the path on marketplace installs):

```bash
git diff <base>...HEAD > /tmp/diff.patch          # the frozen diff
rolepod-cross-family --kind review --brief /tmp/brief.md --attach /tmp/diff.patch --detach
#   → ROLEPOD-XFAM job=<id> kind=review members=codex agy budgets=codex=1800s agy=1800s …
rolepod-cross-family --collect <id>               # before the commit: waits, prints the review + receipt
rolepod-cross-family --jobs                       # running / done
# outside a hook the Lead CLI is auto-detected on Claude; elsewhere add --lead codex|agy|cursor|opencode
```

The runner does what used to be five manual steps, so the pass is never
skipped for friction: resolves the pool (below), invokes the first usable
member **read-only on its own default model**, prefixes
`ROLEPOD_BRAIN_SILENT=1` (clean room — no ambient memory leaks the author's
narrative into the cold run), tees the raw output to
`.rolepod/evidence/external/<utc>-<cli>.txt`, and appends the phase-log line
the commit gate reads. Its last stdout line is the receipt:
`ROLEPOD-XFAM ok kind=review cli=<cli> family=<family> raw=<path> secs=<n>`.
**Time is per member, and the model is told its budget.** `--timeout` >
`timeout=` in the config > kind default (review 1800 s detached / 600 s
foreground · consult 300 · advise 900 · critique 600). The prompt carries
"Time budget: about N minutes … do NOT run builds / tests / package
managers … output PARTIAL if nearly spent", so a slow-but-deep member
(Codex on its owner's `max` effort ran 10+ min exploring a repo before
this) plans instead of wandering. `--detach` makes the chain a job in its
own process group: the Lead keeps working, a member that overruns is
killed with its grandchildren and the next member runs, the receipt is
anchored when it lands, `--collect` waits for it, and the commit gate
reports a running job instead of asking you to start one. Foreground is
capped by the harness (Claude Bash: 600 s) — the runner warns when a
member's budget exceeds it.

The **brief** is the reviewer's whole world (cold context): the change's
intent in one sentence, the acceptance criteria, the settled decisions, the
risk profile, and the claimed behaviours to trace. Never a pointer to the
session or the plan file. The runner prepends the adversarial-reviewer
framing and the verdict-line contract itself.

**Never a model or effort flag.** `TIER_MODELS` (model-tier-policy) governs
the CLI that is the Lead. An external CLI runs whatever its owner set as its
default — that is their cost decision, not the Lead's — and the phase-log
records `model: default`.

## The pool

- **Opt-in, off by default.** `<git-root>/.rolepod/cross-family` (project)
  overrides `~/.rolepod/cross-family` (machine): one CLI per line in
  preference order (`codex` / `claude` / `agy` / `cursor` / `opencode`),
  options after the name (`codex timeout=1800`), optional per-kind order
  lines (`consult: agy codex` — the debug loop wants the fast answer first,
  review can wait for the deep one), `#` comments. **No file = off. `none`
  = off.** Rolepod never enables it on
  its own: the SessionStart context asks you to put the question to the
  user ONCE (installed candidates listed — `rolepod-cross-family
  --candidates`); yes → write their names in their order, no → write
  `none`. Off is a choice, not a limitation to nag about — the review
  report's Cross-model line says "NOT RUN — cross-family off (opt-in)" and
  the internal strong reviewer is the pass.
- **Family exclusion** — the Lead's own family is removed: `codex` =
  openai, `claude` = anthropic, `agy` = google (a Gemini-CLI Lead is the
  same family), `cursor` / `opencode` = the family of their configured
  default model (`~/.cursor/cli-config.json`, `opencode.json(c)`), else
  `unknown` — still used, flagged "decorrelation unverified" in
  `--pool`. Two members of one family: the second is a sequential
  fallback only (a harness is not a second opinion).
- **Installed ≠ usable** — the runner proves it at invoke: exit ≠ 0,
  timeout, or < 200 bytes → an `external-fail` phase-log line and the next
  member. Every member failed → exit 3; enabled but nothing usable → exit
  4; off → exit 5 (nothing logged). All mean:
  **fall back to the Lead's main path** — internal strong reviewer
  (security-engineer / universal-reviewer) — and the review report's
  Cross-model line records the reason. `rolepod-cross-family --pool` shows
  the resolved pool with reasons; `--probe` sends each member a one-line
  prompt (spends one call each) — `ROLEPOD_DOCTOR_PROBE=1 make doctor` does
  the same.
- **Vertical fallback — same family, stronger tier.** Empty pool or all
  failed: the Lead's own CLI at its strongest model (`claude -p --model
  <name>` / `codex exec -m <name>` — the Lead CLI, so a model flag IS
  allowed here), cold context, only when that model differs from the one
  running. Same family — it never counts as the cross-family pass; it
  upgrades the Lead floor. Never pin model names in a skill or plan.

## Model strength — one axis each, no overlap

| Family (CLI) | Reviews best |
|-------|--------------|
| OpenAI (`codex`) | depth · security · logic rigor |
| Google (`agy`) | breadth · cross-file · large-diff sweep |
| Anthropic (`claude`) | architecture · code quality · maintainability |
| Cursor / OpenCode | the family of their default model — the runner tells you |

## Routing

1. Read the diff; name the axes it needs (a diff can need several).
2. Order the pool so the member owning the dominant axis goes first —
   `.rolepod/cross-family` is the order, so a project can pin it.
3. A diff spanning two axes → `--all`: one member per family, concurrently,
   each anchored.
4. Launch every routed reviewer — the runner and internal agents alike — in
   ONE dispatch; they read the same frozen diff independently, so nothing
   is gained by waiting for one before starting the next.

## The Lead floor — covers every axis

The Lead floor is `qa-tester` (a fresh-context subagent) plus the Lead's own
multi-axis read (the step-2 axis walk). It is the universal generalist: it
reviews **every** axis — correctness, security, breadth, architecture, perf,
UI — not one specialty.

Strength routing is an optimisation on top of the floor: it assigns a
specialist to an axis when one is available; it never removes an axis. A
specialist that is missing, is the Lead's family, or has failed → that axis
falls back to the floor.

## Degradation

| Pool | Routing |
|---------------|---------|
| ≥2 families usable | dominant axis to the first member; `--all` when two axes matter |
| 1 usable | it takes the dominant axis; the Lead floor covers the rest |
| 0 usable (exit 3 / 4) | internal strong reviewer + vertical fallback when one exists; Cross-model line records "NOT RUN — <reason from the runner>" |
| off (exit 5 — no config / `none`) | internal strong reviewer is the pass; Cross-model line records "NOT RUN — cross-family off (opt-in)"; ask the user once if the session context says so, never enable unasked |

On a high-risk surface with no usable cross-family member, the floor (plus
the vertical fallback) still reviews every axis — but the review report's
**Cross-model adversarial pass** line must record NOT RUN and why, and
`finish-work`'s Reviewer gate surfaces that limitation before merge. It is a
real verification limitation, not a pass.

## Satellite-first — the external IS the strong pass, and the gate enforces it

Real installs run one main subscription (any family) plus cheaper satellite
plans that would otherwise idle. Each plan is a separate flat-rate quota
pool; the scarce resource is the MAIN plan's quota window, and the main
always carries implementation — so one-shot cold-context work routes to a
satellite first whenever a usable non-Lead family exists:

- **R4 strong adversarial pass** — the routed cross-family external IS the
  strong pass (better decorrelated than a same-family strong reviewing its
  own family's work). `precommit-gate` counts it from the runner's anchor
  (raw file ≥ 500 bytes + the `reviewer:external` review line). While the
  pool is usable, an internal strong reviewer does **not** clear a
  high-risk commit — only after the runner reports exit 3 / 4 (logged as
  `external-fail`); a machine where cross-family is off (opt-in not given,
  or `none`) is never held.
- **Money / auth = BOTH.** billing · payments · credits · auth · crypto ·
  secrets · data deletion (and the gate's money-term content hit): the
  external pass AND the internal strong reviewer, launched in the same
  dispatch on the same frozen diff — the external buys decorrelation, the
  internal buys project-context depth (conventions, risk-paths, the
  cohesion contract). The gate requires both anchors on these paths while
  the pool is usable; external failed (logged) → internal alone clears.
  migration / permission / token / webhook paths stay external-is-the-pass.
- **Weak external → add internal.** Receipt family `unknown` (cursor /
  opencode with no declared default model), no TRACED finding, or a bare
  verdict → dispatch the internal strong reviewer too; record why.
  Internal strong otherwise
  fires on the three carve-outs in review-code §1: empty / failed pool,
  apex trigger (then BOTH passes), fix-verify re-read.
- **Outside opinion** (debug-issue §9, `--kind consult`), **advisory panel**
  (write-plan, `--kind advise --all`) — already cold one-shot by shape; same
  satellite-first order.

This never widens WHO reviews (R1-R3 routing unchanged) — it only moves the
strong-class tokens R4 already spends off the main plan. `rolepod-stats`
reports external passes vs internal strong dispatches so the split is
visible.
