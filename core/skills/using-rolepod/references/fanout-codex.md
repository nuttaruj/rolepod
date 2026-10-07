<!-- Load when spawning sub-agents on Codex, or running at ultra or persistent. -->

# Fan-out mechanics on Codex

A Codex Lead fans out with `spawn_agent` and collects with `wait_agent`. The tier per stage is `model-tiers.md` Fleets; this file is how to spawn it.

## Spawn a rolepod role

Prefer the native Codex role — `agent_type` = its `name` (`scout`, not `rolepod-scout`) — with `fork_turns="none"` and a self-contained brief. If custom roles are unavailable but a default/general child exists, use the portable role dispatch contract in `model-tiers.md`; never infer hook evidence from prompt text. At `ultra`, keep the child brief explicit and bounded. A read-only sweep with no shell need → `agent_type` = `scout`.

- A generic child uses `reasoning_effort` of `xhigh` or lower and `fork_turns="none"` where available; carry unsupported limits as instructions and report them.
- `[agents] default_subagent_model` and `default_subagent_reasoning_effort` apply to every spawn, role spawns included; a rolepod role overrides only the effort, so its child runs `default_subagent_model` when set, else your model.
- A role's pinned effort beats the parent's: a `scout` child under an `ultra` parent runs at its own `low` (live probe 2026-09-30).
- Wait for children with `wait_agent`; their result comes back there.

## Ultra

`ultra` runs the model's multi-agent effort (a catalog value, else `max`) and switches delegation to proactive: the model may spawn on its own, and may spawn none. The tier table still decides who does which job. A rolepod role child runs at its own effort, so it is explicit-only: it spawns only when its brief says so.

A role child whose model has the collaboration tools (`spawn_agent`, `wait_agent`) runs its own reviewers; without them it returns `REVIEW NEEDED:` for the Lead.

## Persistent

`persistent` is a follow-up mode, not deeper thinking: follow-ups stay inside the scope the user asked for, and delegation is explicit-only. Carry the role's effort through controls the CLI exposes; never pin `persistent`, `ultra` or `max` on a role: the effort ceiling on every role is `xhigh`.

## What the hooks see

Codex's PreToolUse sees every spawn (`spawn_agent`, or `collaborationspawn_agent` on V2); rolepod registers no spawn gate. A sub-agent's `git commit` / `git push` is denied — a child's PreToolUse carries `agent_id` (live probe 2026-09-30, Codex 0.159). `sandbox_mode` in a role file is advisory: Codex 0.159 does not apply it, so a read-only role keeps itself read-only.
