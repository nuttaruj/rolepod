#!/bin/bash
# SessionStart — inject the opt-in terse-output layer as context.
#
# Why separate from always-on-loader.sh: this layer is OPT-IN. A user who has
# not created the flag pays zero bytes, and a failure here can never take the
# always-on judgment core down with it — the two payloads are independent.
#
# Opt in:  touch ~/.claude/.rolepod-terse          (ultra — the default since v2.130.0)
#          echo lite > ~/.claude/.rolepod-terse    (full sentences, filler dropped)
# Opt out: rm ~/.claude/.rolepod-terse
#
# The flag lives in CLAUDE_CONFIG_DIR, not the git root: output shape is a
# property of the person reading, not of the project being read.
#
# The payload sits next to this script (hooks/terse-core.md), so the same
# resolution works in-repo and in the installed plugin — no dependency on
# ${CLAUDE_PLUGIN_ROOT}. Fires on the same events as the always-on loader so
# /clear and compaction restore it verbatim rather than as a paraphrase.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_FILE="$SCRIPT_DIR/terse-core.md"
FLAG_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rolepod-terse"

# Drain stdin so the hook does not block; input is unused.
cat >/dev/null 2>&1 || true

# Not opted in — emit nothing at all, not even an empty JSON object.
[ -f "$FLAG_FILE" ] || exit 0
[ -f "$CORE_FILE" ] || exit 0

# First word of the flag file selects the level. `lite` is the only opt-down;
# empty, `ultra` or anything unrecognised is ultra — the default, so a stray
# byte never changes behaviour silently (v2.130.0: ultra measured equal to
# caveman-ultra on the fidelity probe, so it became the default shape).
LEVEL="$(head -c 32 "$FLAG_FILE" 2>/dev/null | tr -d '[:space:]' || true)"
[ "$LEVEL" = "lite" ] || LEVEL="ultra"

python3 -I -c '
import json, sys
core, flag, level = sys.argv[1], sys.argv[2], sys.argv[3]
banner = (
    "TERSE OUTPUT ACTIVE (level: %s) — flag file: %s\n\n" % (level, flag)
)
content = banner + open(core, encoding="utf-8").read()
payload = json.dumps({"hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": content,
}}, ensure_ascii=False)
sys.stdout.buffer.write(payload.encode("utf-8") + b"\n")
' "$CORE_FILE" "$FLAG_FILE" "$LEVEL" 2>/dev/null || exit 0
