## Full-lifecycle trigger + team execution

Normal requests auto-route through the `using-rolepod` skill — lean, phase skips allowed, the user invokes nothing. For the deliberate full lifecycle the user invokes **`/rolepod-full`** (the `rolepod-full` skill): Define → Plan → Build → Verify → Review → Ship, no skips. `/rolepod-full` is `disable-model-invocation` — only the user fires it; Lead never forces full ceremony on its own.

`/rolepod-full` picks an execution backend by capability: **Claude + agent-teams enabled** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, v2.1.32+) → real multi-process teammates (~4× tokens; see [docs/agent-teams.md](docs/agent-teams.md)); **Claude without agent-teams**, or user-requested single-process → Subagent + Task + cohesion contract; **Codex / Gemini** → native subagent dispatch, inline fallback when unsupported. Default Subagent + Task spawn stays the everyday parallel mechanism for normal requests.

Mandatory gates (S1-S5 / T1-T6 / F1-F5 / verify-first / review-code) fire inside each teammate or subagent — rolepod CLAUDE.md + skills load in every session. Lead's job = coordination, not gate enforcement.
