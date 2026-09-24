<!-- Load when the cross-family pool is enabled, or an internal pass, apex or strong-class question comes up. -->
<!-- review-code's Pick reviewers carries the trigger; this file is the routing. -->

# External review routing

Rolepod's CLIs span model families — Claude, Codex (GPT), Google (served
by Antigravity `agy`; the standalone Gemini CLI is retired for individual
accounts and is never in the pool), plus the multi-model harnesses Cursor
and OpenCode (their model = whatever default their owner configured —
recorded, never a criterion). Any CLI can be the Lead. The adversarial
review pass routes to a **different CLI** than the Lead's, never to the
Lead's own; the model family is information, not a filter.

## When the external runs

- **The pool is the user's choice, and it is opt-in.** The runner reads `<git-root>/.rolepod/cross-family`, then `~/.rolepod/cross-family` (`rolepod-cross-family --setup`), minus the Lead's own CLI. No file or `none` = off. Never turn it on unasked.
- **Mandatory at the pool's tier.** Pool enabled + a logic-bearing code diff at the pool's tier (R4 unless the pool file sets `tier = R2|R3`) + a usable member → route the strong pass to it. Below that tier, and any doc / comment / config / rename-only diff, stay internal unless the user asks.
- **The external IS the strong pass (satellite-first).** `rolepod-cross-family --kind review --brief <brief> --attach <diff> --detach` runs read-only on another CLI and anchors itself. From the pool's tier up it replaces `universal-reviewer`, never both on round 1 (the user asks → one pass).
- **Detach by default.** The runner returns a job id and runs the chain (first member → fallbacks), each member on its own budget.
  - Dispatch `security-engineer` in the same message.
  - Then keep working OUTSIDE the diff, or end the turn.
  - `rolepod-cross-family --collect <job-id>` waits up to the budget, in the foreground.
- **An externally implemented ship group** (`--kind implement`) is reviewed by a DIFFERENT member; the runner skips the implementer while its ticket is uncommitted. A user-lifted risky scope (`risky:lifted`) → the external pass by a different member.

## When the internal general pass runs

`universal-reviewer` runs as the general strong pass when any of these holds:
- (a) cross-family is off, or the runner reports no usable member (every member failed / pool empty — logged);
- (b) the review-code Breaker fired — its one round goes to the internal strong reviewer (`breaker.md`);
- (c) the external came back weak — empty / partial return, bare verdict, or no claims walked;
- (d) an apex trigger holds (below) — external first, internal when (c);
- (e) re-reading a fix delta in the fix-verify rounds.

**Strong class.** Dispatch the internal general pass on a strong-class model, even under a balanced Lead — never a balanced model. `qa-tester` (E2E / UI) is never the strong pass and never counts as one.

## Apex escalation

Strong is the R4 default: "done right per the existing pattern?". Apex — the strongest model the CLI exposes — asks "is the pattern itself right?". Escalate only on:
1. irreversible with no rollback — destructive migration, key rotation, live money movement;
2. novel design with no pattern to diff against;
3. deep cross-system reasoning — races on financial invariants, distributed consistency;
4. the previous strong round missed blockers;
5. the user asks.

- No trigger → strong stands.
- A CLI whose strong pin IS its ceiling collapses apex into strong.
- A costlier rung is a cost decision: surface it first.
- A ceiling below frontier class still gets the full review; record the depth cap as a LIMITATION.
- The dispatch line's `override` records the rung sent.

## One command — the cross-family runner

Every external pass goes through `rolepod-cross-family` (installed on PATH by
`install.sh`; every plugin tree also ships it as `scripts/cross-family.sh` —
the SessionStart context names the path on marketplace installs):

```bash
git diff <base>...HEAD > /tmp/diff.patch          # committed branch — the frozen diff
git diff HEAD > /tmp/diff.patch                   # uncommitted work — staged + unstaged together
# `--cached` alone is a slice: the runner refuses it (exit 7) when the same files carry edits
# it does not contain; `--partial-ok` only when the user asked for the staged part
rolepod-cross-family --kind review --brief /tmp/brief.md --attach /tmp/diff.patch --detach
#   → ROLEPOD-XFAM job=<id> kind=review members=codex agy budgets=codex=1800s agy=1800s …
rolepod-cross-family --collect <id> --root <git-root>   # before the commit: waits, prints the review + receipt (any cwd)
rolepod-cross-family --jobs                       # running / done
# outside a hook the Lead CLI is auto-detected on Claude; elsewhere add --lead codex|agy|cursor|opencode
```

The runner does what used to be five manual steps, so the pass is never
skipped for friction: resolves the pool (below), invokes the first usable
member **read-only on its own default model**, prefixes
`ROLEPOD_BRAIN_SILENT=1` (clean room — no ambient memory leaks the author's
narrative into the cold run), tees the raw output to
`.rolepod/evidence/external/<utc>-<cli>.txt`, and appends its own
`"reviewer":"external"` phase-log line. Its last stdout line is the receipt:
`ROLEPOD-XFAM ok kind=review cli=<cli> family=<family> raw=<path> secs=<n>`.
**Time is per member, and the model is told its budget.** `--timeout` >
`timeout=` in the config > kind default (review 1800 s detached / 600 s
foreground · consult 300 · critique 600). The prompt carries
"Time budget: about N minutes … do NOT run builds / tests / package
managers … output PARTIAL if nearly spent", so a slow-but-deep member
(Codex on its owner's `max` effort ran 10+ min exploring a repo before
this) plans instead of wandering. `--detach` makes the chain a job in its
own process group: the Lead keeps working, a member that overruns is
killed with its grandchildren and the next member runs, the receipt is
anchored when it lands, and `--collect` waits for it. Foreground is
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
  review can wait for the deep one; a `timeout=` on a kind line binds to
  that kind only), `#` comments. Timeouts are whole seconds — anything else
  is ignored with a warning, never a watchdog that compares against a word. **No file = off. `none`
  = off.** Rolepod never enables it on
  its own: the SessionStart context asks you to put the question to the
  user ONCE (installed candidates listed — `rolepod-cross-family
  --candidates`); yes → write ALL of them in their order, the Lead's own
  CLI included (it is skipped at run time, so one file serves every
  Lead — switching Lead never means editing the pool), no → write
  `none`. Off is a choice, not a limitation to nag about — the review
  report's Cross-model line says "NOT RUN — cross-family off (opt-in)" and
  the internal strong reviewer is the pass.
- **Family is information, not a filter.** Only the Lead's own CLI is
  excluded. The runner records each member's model family (`agy` = google;
  `cursor` / `opencode` from their configured or last-used default — Cursor
  `auto` has no fixed family; after a run, from the model the CLI *reports*
  it ran: Codex banner, OpenCode header → `ran:` in the receipt and
  phase-log). A member whose default happens to be the Lead's vendor still
  counts — the other harness, context and defaults are the decorrelation
  (owner rule: a different CLI is the point). `--all` runs every usable
  member; each CLI is one opinion.
- **A review pass must be complete.** A review that comes back `PARTIAL`
  (budget nearly spent) or without its `VERDICT:` line is kept as
  `*.partial.txt` for you to read, logged as `external-fail`, and the chain
  moves to the next member — it never anchors the strong pass (consult /
  critique answers marked PARTIAL still count; only the review pass
  is strict). Every anchor carries `brief_sha` and, in a job,
  the job id, so an evidence line is tied to what was reviewed.
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
- **Vertical fallback — same CLI, stronger tier.** Empty pool or all
  failed: the Lead's own CLI at its strongest model (`claude -p --model
  <name>` / `codex exec -m <name>` — the Lead CLI, so a model flag IS
  allowed here), cold context, only when that model differs from the one
  running. Same CLI — it never counts as the cross-family pass; it
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
3. ONE member — the first usable in pool order — reviews every axis the diff needs; `--all` (every usable member, concurrently, each anchored) only on the user's ask.
4. Launch every routed reviewer — the runner and internal agents alike — in
   ONE dispatch; they read the same frozen diff independently, so nothing
   is gained by waiting for one before starting the next. Frozen holds for
   the whole round: no edit to the diff's files, no `git stash` / `reset` /
   `checkout`, until the last member returns — each reads the live tree for
   context, and an early fix makes its verdict an artifact.

## The Lead floor — covers every axis

The Lead floor is `universal-reviewer` (a read-only fresh-context subagent). When no reviewer can run (missing / failed / empty), the Lead's multi-axis read covers every axis — correctness, security, breadth, architecture, perf, UI — recorded as a LIMITATION.

Strength routing is an optimisation on top of the floor: it assigns a
specialist to an axis when one is available; it never removes an axis. A
specialist that is missing, is the Lead's own CLI, or has failed → that axis
falls back to the floor.

## Degradation

| Pool | Routing |
|---------------|---------|
| ≥2 families usable | the first member by dominant axis reviews the whole diff; `--all` only on the user's ask |
| 1 usable | it reviews the whole diff |
| 0 usable (exit 3 / 4) | internal strong reviewer + vertical fallback when one exists; Cross-model line records "NOT RUN — <reason from the runner>" |
| off (exit 5 — no config / `none`) | internal strong reviewer is the pass; Cross-model line records "NOT RUN — cross-family off (opt-in)"; ask the user once if the session context says so, never enable unasked |

On a high-risk surface with no usable cross-family member, the floor (plus
the vertical fallback) still reviews every axis — but the review report's
**Cross-model adversarial pass** line must record NOT RUN and why, and
`finish-work`'s Reviewer gate surfaces that limitation before merge. It is a
real verification limitation, not a pass.

## Satellite-first — the external IS the strong pass

Real installs run one main subscription (any family) plus cheaper satellite
plans that would otherwise idle. Each plan is a separate flat-rate quota
pool; the scarce resource is the MAIN plan's quota window, and the main
always carries implementation — so one-shot cold-context work routes to a
satellite first whenever a usable non-Lead family exists:

- **R4 strong adversarial pass** — the routed cross-family external IS the
  strong pass (better decorrelated than a same-family strong reviewing its
  own family's work). Only the runner's anchor counts — the raw file under
  `.rolepod/evidence/external/` plus its `"reviewer":"external"` phase-log
  line (cli, family, `model:"default"`, raw path); a hand-typed line or a
  hand-rolled external call is ignored. The Lead still appends its own
  merged review verdict line. While the
  pool is usable, an internal strong reviewer does **not** replace the
  external on a high-risk diff — only after the runner reports exit 3 / 4
  (logged as `external-fail`). Cross-family off (opt-in not given, or
  `none`) → the internal strong reviewer is the pass.
- **Money / auth — R4 rule applies.** billing · payments · credits · auth ·
  crypto · secrets · data deletion: `security-engineer` + ONE general strong
  pass (external when the pool is usable, else `universal-reviewer`). Never
  external + `universal-reviewer` on round 1. The internal general pass joins
  an external only when the external came back weak; the Breaker's one round
  is internal only, with no new external round (`breaker.md`).
  Pool off / failed → `universal-reviewer` + `security-engineer`. Commit only
  after one strong pass has finished (the anchored external, or an internal
  strong pass).
- **Weak external → add internal.** Empty / partial return (a changed file
  missing from the report's Scope list counts), a bare verdict, or
  no claims walked → dispatch the internal general pass too; record why.
  Internal otherwise
  fires on the carve-outs under "When the internal general pass runs"
  above: empty / failed pool, apex trigger (external first), fix-verify
  re-read, the Breaker.
- **Outside opinion** (`debug-issue` Second opinion, `--kind consult`) and the spec
  **critique** (`write-spec` Cross-family critique, `--kind critique`) — already cold one-shot by
  shape; same satellite-first order.

This never widens WHO reviews (the pool reviews code at its tier — R4, or lower only when the pool
file sets `tier = R2|R3`; below it stays internal) — it only moves the
strong-class tokens that review already spends off the main plan. `rolepod-stats`
reports external passes vs internal strong dispatches so the split is
visible.
