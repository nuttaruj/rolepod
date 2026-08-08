#!/usr/bin/env bash
# Antigravity PreInvocation hook — record which model agy auto-selected.
#
# agy picks the model per task and exposes no per-agent pin; the hook
# input schema carries `modelName` per invocation (official hooks doc).
# Logging every invocation would spam one line per model call, so this
# appends a "dispatch-proof" line only when the model CHANGES from the
# last logged one — the evidence log ends up with the sequence of models
# the session actually used. Provenance "hook-stdin"; fail-open always.
#
# Contract (agy hooks, gemini-compatible): stdout must stay clean (this
# hook prints nothing), exit 0 always.

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

PROJECT_DIR="${GEMINI_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}"
GIT_ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
EV_DIR="$GIT_ROOT/.rolepod/evidence"
mkdir -p "$EV_DIR" 2>/dev/null || exit 0

MODEL=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(d.get("modelName") or d.get("model") or "")
' 2>/dev/null || true)
[ -n "$MODEL" ] || exit 0

LAST_FILE="$EV_DIR/.last-model-agy"
LAST=$(cat "$LAST_FILE" 2>/dev/null || true)
[ "$MODEL" = "$LAST" ] && exit 0

printf '%s\n' "$MODEL" > "$LAST_FILE" 2>/dev/null || true
python3 -c '
import json, sys, datetime
print(json.dumps({
    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "phase": "dispatch-proof",
    "cli": "antigravity",
    "agent_type": "",
    "model": sys.argv[1],
    "provenance": "hook-stdin",
}, ensure_ascii=False))
' "$MODEL" >> "$EV_DIR/phase-log.jsonl" 2>/dev/null || true

exit 0
