<!-- Load when fanning out on Claude Code: a Workflow script or ultracode. -->

# Fan-out mechanics on Claude Code

A Workflow script fans out with `agent()` / `pipeline()`; ultracode is the `/effort` setting that makes a Workflow the default for substantive work. The tier per stage is `model-tiers.md` Fleets; this file is how to write it.

## Pin every stage

- Prefer `agentType: 'rolepod:<role>'` for a native named role. If custom roles are unavailable but a default/general child exists, use the portable role dispatch contract in `model-tiers.md`; a bare, unbriefed `agent()` never edits product files.
- ≥3 dependent dispatches → a Workflow pipeline, not a Lead loop of dispatch → wait → dispatch: every Lead round-trip re-reads the whole context at the Lead's price.
- Pin every fan-out `agent()` call — a `model:` class or a rolepod `agentType:`; no script comment excuses a bare fan-out.
- A read-only file or web sweep stage that needs no Bash or MCP → `agentType: 'rolepod:scout'`: measured fixed context about 15k tokens (median, n=50) against about 71k for a bare `agent()` (n=146). A stage that needs Bash or an MCP tool takes the role that carries it, or a bare `agent()` pinned with `model:`.
- Set `effort:` per stage; it overrides the role's default; never `max` on a fan-out.

## The inherit trap

A scripted fan-out defaults every agent to the Lead's own model. On a strong-tier Lead that silently runs the whole fleet at the top tier; on a balanced-class Lead the INVERSE trap: inherit silently DOWNGRADES the verify/judge stages below what a high-risk diff requires.

On a non-strong Lead the per-stage tier (`model-tiers.md` Fleets) is an EXPLICIT `opts.model` / effort override — "high-risk review at the session's model" is the silent downgrade the tier policy forbids. A high-risk fleet's judge stage carries a strong tier under any Lead: the tier follows the work, not the Lead.

## The fleet-tier gate

The fleet-tier gate denies in every workflow mode.

The gate reads each Workflow script at submit. A fan-out is a `.map` / `.flatMap` / `.forEach`, `pipeline(`, `Array.from`, a loop or a `${}` label; a hand-written `parallel([...])` is not one.
- `bare-fanout` — a fan-out `agent()` with no tier pin (no `model:`, no rolepod `agentType:`; a platform agent type pins nothing) under a strong or unknown Lead.
- `strong-fanout` — a strong model or strong role pinned on a fan-out, under any Lead.
- `bare-writer` — a role-less `agent()` on a stage that writes.
Each deny names its fix; keep ONE strong call outside the fan-out for the judge.
