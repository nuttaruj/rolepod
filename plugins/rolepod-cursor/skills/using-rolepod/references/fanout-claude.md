<!-- Load when fanning out on Claude Code: a Workflow script or ultracode. -->

# Fan-out mechanics on Claude Code

A Workflow script fans out with `agent()` / `pipeline()`; ultracode is the `/effort` setting that makes a Workflow the default for substantive work. The tier per stage is `model-tiers.md` Fleets; this file is how to write it.

## Pin every stage

- Prefer `agentType: 'rolepod:<role>'` for a native named role. If custom roles are unavailable but a default/general child exists, use the portable role dispatch contract in `model-tiers.md`; a bare, unbriefed `agent()` never edits product files. Roles: `rolepod-builder` · `rolepod-reviewer` (+ `lens:`) · `rolepod-qa` · `rolepod-scout`.
- ≥3 dependent dispatches → a Workflow pipeline, not a Lead loop of dispatch → wait → dispatch: every Lead round-trip re-reads the whole context at the Lead's price.
- Pin every fan-out `agent()` call — a `model:` class or a rolepod `agentType:`; no script comment excuses a bare fan-out.
- A read-only file or web sweep stage that needs no Bash or MCP → `agentType: 'rolepod:rolepod-scout'`: measured fixed context about 15k tokens (median, n=50) against about 71k for a bare `agent()` (n=146). A stage that needs Bash or an MCP tool takes the role that carries it, or a bare `agent()` pinned with `model:`.
- Set `effort:` per stage; it overrides the role's default; never `max` on a fan-out.

## The inherit trap

A scripted fan-out defaults every agent to the Lead's own model. On a strong-tier Lead that silently runs the whole fleet at the top tier; on a balanced-class Lead the INVERSE trap: inherit silently DOWNGRADES the verify/judge stages below what a high-risk diff requires.

On a non-strong Lead the per-stage tier (`model-tiers.md` Fleets) is an EXPLICIT `opts.model` / effort override — "high-risk review at the session's model" is the silent downgrade the tier policy forbids. A high-risk fleet's judge stage carries a strong tier under any Lead: the tier follows the work, not the Lead.

## The fleet-tier gate

The fleet-tier gate denies in every workflow mode; a plan fleet (every agent() bare, each prompt naming docs/rolepod/plans/) passes.

The gate reads each Workflow script at submit. A fan-out is a `.map` / `.flatMap` / `.forEach`, `pipeline(`, `Array.from`, a loop or a `${}` label; a hand-written `parallel([...])` is not one.
- `bare-fanout` — a fan-out `agent()` with no tier pin (no `model:`, no rolepod `agentType:`; a platform agent type pins nothing) under a strong or unknown Lead.
- `strong-fanout` — a strong model or strong role pinned on a fan-out, under any Lead.
- `bare-writer` — a role-less `agent()` on a stage that writes.
Each deny names its fix; keep ONE strong call outside the fan-out for the judge.

## One task as one Workflow

A script may run one task end to end: build → review → fix → re-check. The script is then the orderer; every `convening-code-review` rule still holds.
- One task per script, and the script never commits: it returns to the Lead, who accepts and integrates (`orchestrating-plans` step 3) before the next task.
- Build: `rolepod-builder`, its brief saying "your caller runs the round"; its schema returns the decision-brief fields, the Command tail, and the frozen diff file, H1 and hash. Continue only on `COMPLETED` with a non-empty tail; anything else returns to the Lead.
- Review: the set `plan-lint.sh --review-set --tier <tier> --mode <carried mode>` prints. Ultracode deepens each lens, never widens the set (Lite = spec + standards); a lens past it only on the user's ask. Each brief carries `convening-code-review` step 3's brief and names `.rolepod/evidence/review/<task>-<lens>.md`.
- Write the lenses as a hand-written `parallel([...])`, not a `.map`, so a `lens: security` / `lens: adversarial` call can carry a strong `model:`; cannot → it runs balanced and the receipt says so.
- A null, failed or partial reviewer keeps the round open: re-dispatch that lens once on the same frozen diff, else return to the Lead. Never `.filter(Boolean)` a reviewer away.
- Fix: one fresh `rolepod-builder` (a script cannot resume the build agent) given the build return and every BLOCKER / MAJOR verbatim; it runs `ticket.sh review-diff delta` and returns the delta file and H2. Re-check: ONE fresh `rolepod-reviewer` on that delta only.
- At most four rounds, the round 3-4 fixer one tier up; still open → return the open findings to the Lead.
