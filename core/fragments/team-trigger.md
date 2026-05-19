## Team workflow trigger (Claude only)

Default = Subagent + Task spawn (single-process, all CLIs). Opt-in: **`/rolepod-team`** slash command — adapts silently to env (TEAMMATE mode when Claude v2.1.32+ + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, else FALLBACK via Subagent + Task + cohesion contract). Codex/Gemini don't ship `/rolepod-team`; use natural-language Subagent dispatch via `team-routing` skill. Power users want real teammates: see README. `/rolepod-team` is `disable-model-invocation: true` — only user can fire it.

Per-phase team commands (`/team-define`, `/team-plan`, `/team-build`, `/team-verify`, `/team-review`, `/team-ship`) have been removed — they were subagent recipes that Lead routinely pattern-matched into regular Subagent dispatch (drift documented in commits `0f8de4f`, `6da9fe0`). For phase-scoped parallel work, tell `/rolepod-team` to spawn teammates focused on that phase only.

Cost: each teammate = separate Claude instance with own context window. 4-teammate team ≈ 4× single-session tokens. Use for genuinely parallel work (cross-domain features, parallel investigation, multi-module refactor) — for sequential / trivial tasks, default Subagent + Task is more cost-effective.

Mandatory gates (S1-S5 / T1-T6 / F1-F5 / verify-first / reviewer-flow) fire inside each teammate — rolepod CLAUDE.md + skills load in every teammate session. Lead's job = coordination, not gate enforcement.
