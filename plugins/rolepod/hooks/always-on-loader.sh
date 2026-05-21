#!/bin/bash
# SessionStart — inject the rolepod always-on judgment core as context.
#
# Why: a Claude Code plugin has no always-on instruction surface — a
# plugin-root CLAUDE.md is not loaded. This hook is that surface: it reads
# the judgment core shipped inside the plugin and emits it as SessionStart
# additionalContext, so rolepod's verify-first / simplicity / communication
# judgment is present every session without writing into the user's global
# ~/.claude/CLAUDE.md.
#
# The core file sits next to this script (hooks/always-on-core.md), so the
# same resolution works in-repo and in the installed plugin — no dependency
# on ${CLAUDE_PLUGIN_ROOT}.
#
# Fires on SessionStart (startup | resume). Re-injection after compaction is
# handled by the same event firing again on resume.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_FILE="$SCRIPT_DIR/always-on-core.md"

# Drain stdin so the hook does not block; input is unused.
cat >/dev/null 2>&1 || true

[ -f "$CORE_FILE" ] || exit 0

python3 -c '
import json, sys
content = open(sys.argv[1], encoding="utf-8").read()
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": content,
}}))
' "$CORE_FILE" 2>/dev/null || echo '{}'
