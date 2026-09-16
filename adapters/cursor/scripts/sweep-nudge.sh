#!/bin/bash
# Cursor sweep-nudge — the shared hooks/sweep-nudge.sh behind a Cursor→Claude
# translator (the scout rule at the point of action: ≥120 KB of raw reads in
# one turn with no scout / subagent / edit → ONE nudge).
#
# Cursor contract (measured on agent CLI 2026.09.10 / IDE 3.20, 2026-09-16):
#   beforeSubmitPrompt   {prompt, conversation_id, ...}          → reset (must answer {continue:true})
#   preToolUse           {tool_name Write|Edit, tool_input}       → edit flag, no output
#   postToolUse          {tool_name Read|Grep|Glob|…, tool_output}→ counts; Read's tool_output is
#                        a JSON string {"file_path","content_length"} — the bytes the model
#                        received are content_length, so that is what gets counted
#   afterShellExecution  {command, output}                        → counts the shell output
#                        silently: this event carries no additional_context, so a fire here
#                        is un-fired and the next Read/Grep delivers it
# Only postToolUse can put text in front of the model ({"additional_context": ...}).
set -uo pipefail

IN=$(cat 2>/dev/null || echo '{}')
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$HERE/shared/sweep-nudge.sh"
[ -f "$CORE" ] || exit 0

TRANS=$(printf '%s' "$IN" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ev = d.get("hook_event_name") or ""
sid = d.get("conversation_id") or d.get("session_id") or ""
out = {"session_id": sid}
if ev == "beforeSubmitPrompt":
    out.update(hook_event_name="UserPromptSubmit", prompt=d.get("prompt") or "")
elif ev == "preToolUse":
    out.update(hook_event_name="PreToolUse", tool_name=d.get("tool_name") or "",
               tool_input=d.get("tool_input") or {})
elif ev == "postToolUse":
    to = d.get("tool_output")
    size = None
    if isinstance(to, str):
        try:
            size = (json.loads(to) or {}).get("content_length")
        except Exception:
            size = None
        if not isinstance(size, int):
            size = len(to)
    else:
        size = len(json.dumps(to or ""))
    out.update(hook_event_name="PostToolUse", tool_name=d.get("tool_name") or "",
               tool_response="x" * max(0, min(size, 4 * 1024 * 1024)))
elif ev == "afterShellExecution":
    out.update(hook_event_name="PostToolUse", tool_name="Bash",
               tool_response=str(d.get("output") or ""), _nodeliver=1)
else:
    sys.exit(0)
print(json.dumps(out))
' 2>/dev/null)
[ -n "$TRANS" ] || exit 0

OUT=$(printf '%s' "$TRANS" | bash "$CORE" 2>/dev/null)

case "$TRANS" in *'"UserPromptSubmit"'*) printf '%s' '{"continue": true}'; exit 0;; esac
[ -n "$OUT" ] || exit 0

printf '%s' "$OUT" | ROLEPOD_TRANS="$TRANS" python3 -I -c '
import json, os, re, sys, tempfile
try:
    o = json.load(sys.stdin)
except Exception:
    sys.exit(0)
msg = (o.get("hookSpecificOutput") or {}).get("additionalContext") or ""
if not msg:
    sys.exit(0)
t = json.loads(os.environ["ROLEPOD_TRANS"])
if t.get("_nodeliver"):
    # afterShellExecution cannot carry context: un-fire so the next read delivers it.
    sid = re.sub(r"[^A-Za-z0-9_-]", "", t.get("session_id", ""))[:64]
    p = os.path.join(tempfile.gettempdir(), "rolepod-sweep-%s.json" % sid)
    try:
        s = json.load(open(p)); s["fired"] = 0
        json.dump(s, open(p, "w"))
    except Exception:
        pass
    sys.exit(0)
print(json.dumps({"additional_context": msg}))
' 2>/dev/null
exit 0
