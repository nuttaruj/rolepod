#!/bin/bash
# sweep-nudge — the scout rule at the point of action (v2.126.0).
#
# The always-on says: a broad sweep or any raw read past ~10k tokens →
# dispatch ONE read-only scout, never sweep yourself. That sentence sits far
# up the context; the moment it matters is the 20th grep of a research turn,
# where the CLI's own tool prompt ("continue locally") is the nearest voice.
# Measured 2026-09-14 on this machine: Codex 5.6 Leads swept 322 KB, 768 KB
# and 1,895 KB of raw output in single research turns with zero spawns,
# while astra / opus Leads on the same rule dispatched a scout. Compliance
# was the Lead's choice; nothing mechanical spoke at the moment of choice.
#
# Mechanics — state per session in $TMPDIR/rolepod-sweep-<session_id>.json,
# reset on every UserPromptSubmit (= a new turn), so no transcript scan:
#   UserPromptSubmit                     → reset {bytes, reads, disp, edit, fired}
#   PreToolUse  Edit/Write/…/apply_patch → edit=1  (a build turn: reading the
#                                           files you edit is not a sweep)
#   PostToolUse Agent/Task/Workflow/
#               spawn_agent, SubagentStart → disp=1 (the Lead already delegated)
#   PostToolUse Read/Grep/Glob/Bash/
#               WebFetch/WebSearch/
#               read_file/grep_files/
#               list_dir/exec*           → bytes += size(tool_response)
#     bytes ≥ LIMIT, no edit, no dispatch, not yet fired → ONE additionalContext
#     nudge this turn, then silent.
#
# Threshold 120 KB (≈30k tokens) of raw tool output per turn: three times
# the doctrine's per-read line. On the measured turns it catches every
# swept research turn (322–1,895 KB) and fires on 0 of the Claude turns and
# 17% of the Codex research turns; 40 KB would have fired on 35% of them —
# a nudge that fires on every third turn is wallpaper.
#
# Advisory only — never blocks. Fail-open everywhere: no JSON, no
# session_id, unwritable state → exit 0. ROLEPOD_NUDGE_OFF=1 silences.
# Codex: fires for Bash / read_file / grep_files / list_dir / MCP tool calls
# made as direct tool calls; reads made inside a code-mode `exec` script do
# not reach PostToolUse (upstream: code-mode tools opt out) — the always-on
# sentence stays the gate there.

set -uo pipefail

[ "${ROLEPOD_NUDGE_OFF:-}" = "1" ] && exit 0
INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

printf '%s' "$INPUT" | python3 -I -c '
import json, os, re, sys, tempfile

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

sid = re.sub(r"[^A-Za-z0-9_-]", "", str(d.get("session_id") or ""))[:64]
if not sid:
    sys.exit(0)

ev = d.get("hook_event_name") or (
    "UserPromptSubmit" if "prompt" in d else
    "PostToolUse" if "tool_response" in d else "PreToolUse")
tool = str(d.get("tool_name") or "")

READ = {"Read", "Grep", "Glob", "Bash", "WebFetch", "WebSearch",
        "read_file", "grep_files", "list_dir", "exec", "exec_command", "shell"}
EDIT = {"Edit", "Write", "MultiEdit", "NotebookEdit", "apply_patch"}
DISPATCH = {"Agent", "Task", "Workflow", "spawn_agent"}
LIMIT = 120 * 1024

path = os.path.join(tempfile.gettempdir(), "rolepod-sweep-%s.json" % sid)
FRESH = {"bytes": 0, "reads": 0, "disp": 0, "edit": 0, "fired": 0}

def load():
    try:
        with open(path) as f:
            s = json.load(f)
        return s if isinstance(s, dict) and all(k in s for k in FRESH) else dict(FRESH)
    except Exception:
        return dict(FRESH)

def save(s):
    try:
        with open(path, "w") as f:
            json.dump(s, f)
    except Exception:
        pass

if ev == "UserPromptSubmit":
    save(dict(FRESH))
    sys.exit(0)

s = load()
if ev == "SubagentStart" or tool in DISPATCH:
    s["disp"] = 1
    save(s)
    sys.exit(0)
if tool in EDIT:
    s["edit"] = 1
    save(s)
    sys.exit(0)
if ev != "PostToolUse" or tool not in READ:
    sys.exit(0)

resp = d.get("tool_response")
size = len(resp) if isinstance(resp, str) else len(json.dumps(resp or "", ensure_ascii=False))
s["bytes"] += size
s["reads"] += 1
fire = not s["fired"] and not s["disp"] and not s["edit"] and s["bytes"] >= LIMIT
if fire:
    s["fired"] = 1
save(s)
if not fire:
    sys.exit(0)

msg = (
    "⟂ sweep: ~%d KB of raw tool output across %d calls this turn, no scout or "
    "subagent dispatched, no edit yet. Fix: dispatch ONE read-only scout on the cheap "
    "tier (`scout`) with the question and the paths seen so far; read only what its "
    "report points at. Exception: test / build output, or one file the task needs "
    "whole → continue (fires once per turn). (off: ROLEPOD_NUDGE_OFF=1)"
    % (s["bytes"] // 1024, s["reads"])
)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": msg,
}}))
' 2>/dev/null || true
exit 0
