#!/bin/bash
# Codex SessionStart bridge — invoke MemPalace's session-start hook so
# Codex sessions get the same cross-session KG recall that Claude sessions
# get via MemPalace's own integration.
#
# Why this exists: MemPalace supports `--harness codex`, but Rolepod needs
# to wire that command into Codex's plugin hook schema. Rolepod's install
# only registers this hook in the Codex plugin cache's hooks.json when
# `command -v mempalace` succeeds at install time. The script also self-
# guards on `mempalace` presence at runtime so an upgrade-then-uninstall
# of MemPalace does not leave a noisy hook.
#
# Codex Stop / PreCompact equivalents are not shipped — Codex 0.130+
# plugin hook schema exposes SessionStart / PreToolUse / PostToolUse
# only (no Stop event for "session ended", no PreCompact for "context
# compressed"). When upstream Codex adds those events, mirror this
# script for codex-stop.sh / codex-precompact.sh.
#
# Harness flag: try `--harness codex` first. Fall back to
# `--harness claude-code` only for older MemPalace releases.
set -euo pipefail

# Self-guard: silent no-op when MemPalace not installed. Same pattern
# the GitNexus add-on hooks use.
command -v mempalace >/dev/null 2>&1 || exit 0

if mempalace hook run --hook session-start --harness codex >/dev/null 2>&1; then
  exit 0
fi
mempalace hook run --hook session-start --harness claude-code >/dev/null 2>&1 || true
exit 0
