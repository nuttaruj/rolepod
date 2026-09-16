#!/usr/bin/env bash
# Antigravity PreInvocation hook — record which model agy auto-selected.
#
# agy picks the model per task and exposes no per-agent pin; the hook
# input carries `modelName` per invocation. Logging every invocation would
# spam one line per model call, so this appends a "dispatch-proof" line
# only when the model CHANGES from the last logged one — the evidence log
# ends up with the sequence of models the session actually used.
# Provenance "hook-stdin"; fail-open always.
#
# agy contract (measured 2026-09-16): stdin is camelCase and carries the
# workspace as workspacePaths[0] (no cwd, no GEMINI_/CLAUDE_ env; hook cwd
# is the plugin dir). stdout must stay EMPTY — agy rejects any field on a
# PreInvocation result and turns it into a hook error.
set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

IFS=$'\t' read -r WS MODEL <<< "$(printf '%s' "$INPUT" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ws = (d.get("workspacePaths") or [""])[0] or ""
print(ws + "\t" + (d.get("modelName") or d.get("model") or ""))
' 2>/dev/null || true)"
[ -n "${WS:-}" ] && [ -n "${MODEL:-}" ] || exit 0

GIT_ROOT=$(git -C "$WS" rev-parse --show-toplevel 2>/dev/null) || exit 0
EV_DIR="$GIT_ROOT/.rolepod/evidence"
mkdir -p "$EV_DIR" 2>/dev/null || exit 0

LAST_FILE="$EV_DIR/.last-model-agy"
LAST=$(cat "$LAST_FILE" 2>/dev/null || true)
[ "$MODEL" = "$LAST" ] && exit 0

printf '%s\n' "$MODEL" > "$LAST_FILE" 2>/dev/null || true
python3 -I -c '
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
