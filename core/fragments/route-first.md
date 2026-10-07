## Route first

Before acting, one test: will this change anything — a file written, edited or deleted, or a command with effects, anywhere?
- No → answer (a question, an opinion, an explanation, a read-only look).
- Yes, or unsure → load `using-rolepod` first.
Any skill that might fit, even a 1% chance → load it before acting; memory of a skill is not its text.

Re-entry, by name: an approved plan → `orchestrating-plans`; a bug, regression or failing test → `debug-issue`; a done claim past a trivial edit → `check-work`; a PR, a merge, a push to the base or a deploy → `finish-work`.

Workflow mode is selected once per session (the startup profile, else the first `using-rolepod` entry) and carried through briefs and compaction summaries; a tool call, config change or skill reload never reselects it or reroutes. After compaction or a skill reload, reload the skill text and reuse the carried mode.
