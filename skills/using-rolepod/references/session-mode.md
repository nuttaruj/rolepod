<!-- Load when the active workflow mode is in question after a startup, resume, clear or restart, for a configured-mode lookup, or when the user asks to set a mode. -->

# Session mode — per-CLI detail

The carry rule is in the always-on core (Route first); the router holds the no-profile fallback. This file holds only the per-CLI detail.

## Configured mode is not the active mode

Configured-mode inspection (`rolepod_config.py mode`, the config file) is separate and never overwrites the active session profile.

## Set a mode

- One project → `workflow.mode` in `<git root>/.rolepod/config.json`: `{"version": 1, "workflow": {"mode": "full"}}` (`lite` | `standard` | `full`); it wins over the machine-wide `~/.rolepod/config.json`. Merge into an existing file; never drop its other keys.
- The pool stays machine-wide (`cross-family`); a project file's pool is ignored.
- Tell the user the new mode applies from the next session (refresh table below); this session keeps its mode.

## Startup refresh boundaries

| CLI | The profile refreshes on |
|---|---|
| Claude Code | startup, resume, clear |
| Codex | startup, resume |
| Cursor | `sessionStart.env` |
| Antigravity | conversation identity (same-conversation CLI restart behavior is unverified) |
| OpenCode | plugin / backend restart |
