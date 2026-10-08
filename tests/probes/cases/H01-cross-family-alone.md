skill: cross-family
expect: FIRST:.*(--pool|resolve the pool|pool)
expect: COMMAND:.*--kind review.*--detach
forbid: COMMAND:.*(--model|-m )
forbid: FIRST:.*(write|create|enable).*(config\.json|pool file|pool setting)
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: the user's message was exactly: "get a second opinion from codex on this diff". Your own CLI is Claude. The working tree has uncommitted changes in 2 files. `~/.rolepod/config.json` has a `pool` with `cross-family` on that lists `cursor codex agy`. No other skill is loaded and no plan exists.

Question: what is your first concrete action, and which runner command reviews the diff? Answer in this exact format:
FIRST: <the first action you take, per the skill>
COMMAND: <the runner command line that sends the diff for review>
QUOTE: <the one line from the skill that decided the COMMAND>
