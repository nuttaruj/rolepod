<!-- Load when the active workflow mode is in question after a startup, resume, clear or restart, or for a configured-mode lookup. -->

# Session mode — per-CLI detail

The carry rule is in the always-on core (Route first); the router holds the no-profile fallback. This file holds only the per-CLI detail.

## Configured mode is not the active mode

Configured-mode inspection (`rolepod_config.py mode`, the config file) is separate and never overwrites the active session profile.

## Startup refresh boundaries

| CLI | The profile refreshes on |
|---|---|
| Claude Code | startup, resume, clear |
| Codex | startup, resume |
| Cursor | `sessionStart.env` |
| Antigravity | conversation identity (same-conversation CLI restart behavior is unverified) |
| OpenCode | plugin / backend restart |
