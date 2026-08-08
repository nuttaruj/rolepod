#!/bin/bash
# Codex SubagentStop hook — record which model a finished subagent reported.
#
# The official hooks reference lists `model` among the common stdin fields
# and SubagentStop adds agent_id / agent_type / agent_transcript_path.
# One JSONL line per completed subagent goes to the project's evidence log
# as phase "dispatch-proof" — the runtime companion to the "dispatch"
# intent line. Provenance is recorded ("hook-stdin"): whether `model` is
# the subagent's own or the parent session's has not been live-verified
# upstream, so consumers must treat this as hook-reported, not gospel.
# `agent_transcript_path` is logged alongside for deeper manual audit.
#
# Fail-open everywhere: no git root, no JSON, missing fields → exit 0.

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
EV_DIR="$GIT_ROOT/.rolepod/evidence"
mkdir -p "$EV_DIR" 2>/dev/null || exit 0

printf '%s' "$INPUT" | python3 -c '
import json, sys, datetime
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
line = {
    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "phase": "dispatch-proof",
    "cli": "codex",
    "agent_type": d.get("agent_type") or "",
    "model": d.get("model") or "",
    "provenance": "hook-stdin",
    "transcript": d.get("agent_transcript_path") or "",
}
print(json.dumps(line, ensure_ascii=False))
' >> "$EV_DIR/phase-log.jsonl" 2>/dev/null || true

exit 0
