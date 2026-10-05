<!-- Load when the active workflow mode is in question: a fresh startup or resume, a CLI's refresh boundary, a hookless session, or a configured-mode lookup. -->

# Session mode — per-CLI detail

The router's preamble holds the rule: mode is selected once, carried through briefs and compaction summaries, and never reselected by a tool call, config change or skill reload. This file holds the per-CLI detail behind it.

## Configured mode is not the active mode

Configured-mode inspection (`rolepod_config.py mode`, the config file) is separate and never overwrites the active session profile.

## When a new profile is captured

- After compaction or a skill reload within the same session, reload the skill text as needed and reuse the carried mode.
- A fresh native startup / resume / clear supplies its newly captured profile.
- Without startup capture, a standalone skill or manual entry selects the mode once; preserve it for that session.
- Skills remain executable without native hooks, though hook enforcement is absent.

## Startup refresh boundaries

| CLI | The profile refreshes on |
|---|---|
| Claude Code | startup, resume, clear |
| Codex | startup, resume |
| Cursor | `sessionStart.env` |
| Antigravity | conversation identity (same-conversation CLI restart behavior is unverified) |
| OpenCode | plugin / backend restart |
