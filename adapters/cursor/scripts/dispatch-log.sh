#!/bin/bash
# Cursor preToolUse(Task) — dispatch-proof line for the commit gate (v2.135.0).
#
# Cursor's Task tool carries the subagent type in tool_input.subagent_type
# (measured on agent CLI 2026.09.10, 2026-09-16: {"description","prompt",
# "subagent_type"}). The shared precommit-gate counts reviewer dispatches from
# phase-log "dispatch-proof" lines on every CLI without a Claude transcript, so
# this hook writes the same line Codex's SubagentStop and opencode's task hook
# write: {"ts","phase":"dispatch-proof","cli","agent_type","model","provenance"}.
# Prints nothing (a preToolUse answer is not needed to allow). Fail-open.
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
IFS=$'\t' read -r WS AGENT <<< "$(printf '%s' "$INPUT" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if (d.get("tool_name") or "") != "Task":
    sys.exit(0)
roots = d.get("workspace_roots") or []
ti = d.get("tool_input") or {}
print((roots[0] if roots else "") + "\t" + str(ti.get("subagent_type") or ""))
' 2>/dev/null || true)"
[ -n "${AGENT:-}" ] || exit 0
[ -n "${WS:-}" ] || WS="$PWD"
ROOT=$(git -C "$WS" rev-parse --show-toplevel 2>/dev/null) || exit 0
EV="$ROOT/.rolepod/evidence"
mkdir -p "$EV" 2>/dev/null || exit 0
ROLEPOD_AGENT="$AGENT" python3 -I -c '
import datetime, json, os
print(json.dumps({
    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "phase": "dispatch-proof", "cli": "cursor",
    "agent_type": os.environ.get("ROLEPOD_AGENT", ""), "model": "", "provenance": "hook-stdin",
}, ensure_ascii=False))
' >> "$EV/phase-log.jsonl" 2>/dev/null || true
exit 0
