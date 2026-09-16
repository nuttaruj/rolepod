#!/usr/bin/env bash
# rolepod / Antigravity PreToolUse(run_command) — the shared commit gate, translated.
#
# agy contract (measured on agy 1.2.3, 2026-09-16):
#   stdin  = {"toolCall": {"name": "run_command", "args": {"CommandLine": "...",
#             "Cwd": "..."}}, "workspacePaths": [...], "conversationId", ...}
#   result = {"decision": "deny", "reason": "..."}  → tool blocked, the model sees
#            "tool call denied by pre-tool hook: <reason>". ANY other output is a
#            hook error and ALSO blocks the tool — including `{}` — so this script
#            prints exactly one deny object or nothing at all.
#
# Behaviour: translate the agy call into the Claude-shape stdin the shared
# hooks/precommit-gate.sh expects (tool_name Bash, tool_input.command, cwd,
# session_id) and run it in the tool's cwd; translate its verdict back:
#   JSON hookSpecificOutput.permissionDecision == deny  → {"decision":"deny","reason"}
#   exit 2 (stderr = reason)                             → same
#   anything else (allow / advisory context / errors)   → silence
# The gate's advisory text (auto-pass note, emoji advisory, push-ref info) has no
# channel on agy and is dropped on purpose; the deny paths (high-risk diff without
# tests, private docs staged, review-round breaker) fire exactly as on Claude.
set -uo pipefail

IN=$(cat 2>/dev/null || true)
[ -n "$IN" ] || exit 0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/precommit-gate.sh"
[ -f "$GATE" ] || exit 0

# One python pass: bail (no output) unless this is run_command; otherwise emit
# the Claude-shape stdin and the cwd as two NUL-free, tab-separated fields.
TRANS=$(printf '%s' "$IN" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tc = d.get("toolCall") or {}
a = tc.get("args") or {}
ws = (d.get("workspacePaths") or [""])[0] or ""
name = tc.get("name") or ""
if name in ("write_to_file", "replace", "edit", "edit_file", "multi_replace_file_content"):
    # Edit tools → the edit ledger (v2.134.0), never a verdict.
    p = a.get("TargetFile") or a.get("AbsolutePath") or a.get("file_path") or a.get("path") or ""
    if p and ws:
        sys.stdout.write("EDIT\t" + ws + "\t" + p)
    sys.exit(0)
if name != "run_command":
    sys.exit(0)
cmd = a.get("CommandLine") or ""
cwd = a.get("Cwd") or ws
if not cmd or not cwd:
    sys.exit(0)
claude = {"hook_event_name": "PreToolUse", "tool_name": "Bash",
          "tool_input": {"command": cmd}, "cwd": cwd,
          "session_id": d.get("conversationId") or ""}
sys.stdout.write(cwd + "\t" + json.dumps(claude))
' 2>/dev/null || true)
[ -n "$TRANS" ] || exit 0
case "$TRANS" in
  EDIT$'\t'*)
    _rest="${TRANS#EDIT$'\t'}"; _ws="${_rest%%$'\t'*}"; _path="${_rest#*$'\t'}"
    [ -f "$HERE/edit-ledger.py" ] && python3 -I "$HERE/edit-ledger.py" append antigravity "$_path" --cwd "$_ws" >/dev/null 2>&1
    exit 0;;
esac
CWD="${TRANS%%$'\t'*}"
CLAUDE_IN="${TRANS#*$'\t'}"

ERR=$(mktemp "${TMPDIR:-/tmp}/rolepod-agy-gate.XXXXXX" 2>/dev/null || echo /dev/null)
OUT=$(cd "$CWD" 2>/dev/null && printf '%s' "$CLAUDE_IN" | CLAUDE_PLUGIN_ROOT="$HERE/.." bash "$GATE" 2>"$ERR"); RC=$?
STDERR=$(cat "$ERR" 2>/dev/null || true); [ "$ERR" = /dev/null ] || rm -f "$ERR"

# Back-translate: only a deny produces output.
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
print(json.dumps({"decision": "deny", "reason": os.environ.get("ROLEPOD_HOOK_MSG", "")[:1500]}))
' 2>/dev/null
exit 0
