## Team workflow trigger (Claude only)

Default = Subagent + Task spawn (single-process, all CLIs). Opt-in: **`/team-all`** slash command. Behavior adapts to environment — smooth UX, no friction on missing config:

| Env state | `/team-all` mode |
|---|---|
| Claude v2.1.32+ + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | **TEAMMATE MODE** — real multi-process teammates per [official agent-teams spec](https://code.claude.com/docs/en/agent-teams), shared task list + mailbox messaging |
| Claude v2.1.32+ + env flag NOT set | **FALLBACK MODE** — Lead orchestrates parallel Subagent + Task with cohesion contract, single-process. Lead announces the fallback briefly + suggests enabling the flag if user wants real teammates |
| Claude < v2.1.32 | **FAIL-FAST** — upgrade required (teammate API unavailable; contract requires multi-process API) |
| Codex / Gemini | `/team-all` not installed there. Use natural-language Subagent dispatch via `team-routing` skill |

`/team-all` is `disable-model-invocation: true` — only user can fire it. Lead never auto-spawns a team.

Per-phase team commands (`/team-define`, `/team-plan`, `/team-build`, `/team-verify`, `/team-review`, `/team-ship`) have been removed — they were subagent recipes that Lead routinely pattern-matched into regular Subagent dispatch (drift documented in commits `0f8de4f`, `6da9fe0`). For phase-scoped parallel work, tell `/team-all` to spawn teammates focused on that phase only.

Cost: each teammate = separate Claude instance with own context window. 4-teammate team ≈ 4× single-session tokens. Use for genuinely parallel work (cross-domain features, parallel investigation, multi-module refactor) — for sequential / trivial tasks, default Subagent + Task is more cost-effective.

Mandatory gates (S1-S5 / T1-T6 / F1-F5 / verify-first / reviewer-flow) fire inside each teammate — rolepod CLAUDE.md + skills load in every teammate session. Lead's job = coordination, not gate enforcement.
