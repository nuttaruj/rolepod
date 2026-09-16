#!/bin/bash
# Cursor beforeShellExecution(git commit) — the SHARED commit gate, translated.
#
# v2.134.0: this used to be a Cursor-only gate (any staged high-risk path →
# HARD, no session evidence). It is now a translator around the shared
# scripts/shared/precommit-gate.sh (byte-identical to hooks/precommit-gate.sh),
# so Cursor runs the same tiering, the same evidence window (since the last
# commit: edit ledger + phase-log reviewer lines + anchored cross-family
# passes) and the same auto-pass as every other CLI.
#
# Cursor stdin: {"command", "cwd", "conversation_id", ...}. Cursor output:
#   {"permission": "deny", "user_message", "agent_message"} + exit 2 → blocked,
#   the reason reaches the model through agent_message (fed back only on deny).
#   Anything the gate says on an ALLOW (soft warn, auto-pass note) has no
#   channel here — agent_message is dropped on allow — so the translator
#   prints nothing in that case.
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/shared/precommit-gate.sh"
[ -f "$GATE" ] || exit 0

TRANS=$(printf '%s' "$INPUT" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
cmd = d.get("command") or ""
if not cmd:
    sys.exit(0)
roots = d.get("workspace_roots") or []
cwd = d.get("cwd") or (roots[0] if roots else "")
if not cwd:
    sys.exit(0)
claude = {"hook_event_name": "PreToolUse", "tool_name": "Bash",
          "tool_input": {"command": cmd}, "cwd": cwd,
          "session_id": d.get("conversation_id") or d.get("session_id") or ""}
sys.stdout.write(cwd + "\t" + json.dumps(claude))
' 2>/dev/null || true)
[ -n "$TRANS" ] || exit 0
CWD="${TRANS%%$'\t'*}"
CLAUDE_IN="${TRANS#*$'\t'}"

ERR=$(mktemp "${TMPDIR:-/tmp}/rolepod-cursor-gate.XXXXXX" 2>/dev/null || echo /dev/null)
OUT=$(cd "$CWD" 2>/dev/null && printf '%s' "$CLAUDE_IN" | CLAUDE_PLUGIN_ROOT="$HERE/.." ROLEPOD_LEAD_CLI="${ROLEPOD_LEAD_CLI:-cursor}" bash "$GATE" 2>"$ERR"); RC=$?
STDERR=$(cat "$ERR" 2>/dev/null || true); [ "$ERR" = /dev/null ] || rm -f "$ERR"

REASON=$(printf '%s' "$OUT" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
h = d.get("hookSpecificOutput") or {}
if h.get("permissionDecision") == "deny":
    print(h.get("permissionDecisionReason") or "blocked by rolepod precommit-gate")
' 2>/dev/null || true)
if [ -z "$REASON" ] && [ "$RC" -eq 2 ]; then
  REASON="${STDERR:-blocked by rolepod precommit-gate}"
fi
[ -n "$REASON" ] || exit 0

ROLEPOD_HOOK_MSG="$REASON" python3 -I -c '
import json, os
m = os.environ.get("ROLEPOD_HOOK_MSG", "")[:1500]
print(json.dumps({"permission": "deny", "user_message": m, "agent_message": m}))
' 2>/dev/null
exit 2
