<!-- Load when spawning sub-agents on Codex, or running at ultra or persistent. -->

# Fan-out mechanics on Codex

A Codex Lead fans out with `spawn_agent` and collects with `wait_agent`. The tier per stage is `model-tiers.md` Fleets; this file is how to spawn it.

## Spawn a rolepod role

For rolepod work spawn only a rolepod role — `agent_type` = its `name` (`scout`, not `rolepod-scout`), `fork_turns="none"`, a self-contained brief. Never `default`, `explorer`, `worker` or a role-less spawn: they inherit your effort, and at `ultra` they delegate again with no depth cap.

- A role-less spawn you cannot avoid → set `reasoning_effort` to `xhigh` or lower and `fork_turns="none"`.
- `[agents] default_subagent_model` and `default_subagent_reasoning_effort` apply to every spawn, role spawns included; a rolepod role overrides only the effort, so its child runs `default_subagent_model` when set, else your model.
- A role's pinned effort beats the parent's: a `scout` child under an `ultra` parent runs at its own `low` (live probe 2026-09-30).
- Wait for children with `wait_agent`; their result comes back there.

## Ultra

`ultra` runs the model's multi-agent effort (a catalog value, else `max`) and switches delegation to proactive: the model may spawn on its own, and may spawn none. The tier table still decides who does which job. A rolepod role child runs at its own effort, so it is explicit-only: it spawns only when its brief says so.

A role child whose model has the collaboration tools (`spawn_agent`, `wait_agent`) runs its own reviewers; without them it returns `REVIEW NEEDED:` for the Lead.

## Persistent

`persistent` is a follow-up mode, not deeper thinking: follow-ups stay inside the scope the user asked for, a wait uses the sleep tool (never a watcher left running), and delegation is explicit-only. A role-less child inherits it; a rolepod role's pinned effort turns it off. Never pin `persistent`, `ultra` or `max` on a role: the effort ceiling on every role is `xhigh`.

## What the hooks see

Codex's PreToolUse sees every spawn (`spawn_agent`, or `collaborationspawn_agent` on V2); rolepod registers no spawn gate. A sub-agent's `git commit` / `git push` is denied — a child's PreToolUse carries `agent_id` (live probe 2026-09-30, Codex 0.159). `sandbox_mode` in a role file is advisory: Codex 0.159 does not apply it, so a read-only role keeps itself read-only.
