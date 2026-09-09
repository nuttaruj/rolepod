#!/bin/bash
# PreToolUse Edit/Write/MultiEdit/NotebookEdit — a generic platform sub-agent
# never writes product files.
#
# Rationale: measured across every product repo (30 days of subagent
# transcripts): 16 of 31 `general-purpose` dispatches edited product code —
# booking, payments-adjacent schema, admin pages — with no role doctrine, no
# tool cap, and (because cohesion-contract-check whitelists general-purpose
# as read-only) no cohesion contract. The leak is always the same shape: the
# Lead judges a write "shallow enough" for the catch-all agent. A rule that
# needs that judgment fires below 1; a rule the hook checks fires every time.
#
# Mechanism: Claude Code PreToolUse hook input carries `agent_id` +
# `agent_type` only for a sub-agent call (live-verified 2026-09-09: an Agent
# spawn with subagent_type omitted OR 'general-purpose' arrives as
# agent_type='general-purpose'). Generic types — general-purpose / default /
# claude — are denied any write outside scratch + evidence paths; every
# rolepod role and every unknown type passes (fail-open). The Lead re-
# dispatches the write to a rolepod role; nothing is lost but one spawn.
#
# Bypass: ROLEPOD_ALLOW_GENERIC_WRITE=1 (user-set, logged to bypass.log).
set -euo pipefail

rolepod_log_bypass() {
  _rlb_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  [ -n "$_rlb_root" ] || return 0
  mkdir -p "$_rlb_root/.rolepod/evidence" 2>/dev/null || return 0
  _rlb_reason="${ROLEPOD_BYPASS_REASON:-unreasoned}"
  _rlb_reason="${_rlb_reason//\"/ }"
  printf '{"ts":"%s","hook":"%s","var":"%s","reason":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$_rlb_reason" \
    >> "$_rlb_root/.rolepod/evidence/bypass.log" 2>/dev/null || true
}

INPUT=$(cat 2>/dev/null || echo '{}')
command -v python3 >/dev/null 2>&1 || exit 0

# One pass: parse, classify, decide. Prints the deny JSON or nothing.
DECISION=$(printf '%s' "$INPUT" | python3 -I -c '
import sys, json, os, re, datetime
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not (d.get("agent_id") or ""):
    sys.exit(0)                                   # Lead conversation
atype = (d.get("agent_type") or "").strip()
bare = atype.split(":")[-1].lower()
if bare not in ("general-purpose", "default", "claude"):
    sys.exit(0)                                   # a role, or unknown → pass
tool = d.get("tool_name") or ""
ti = d.get("tool_input") or {}
path = ti.get("file_path") or ti.get("notebook_path") or ""
if not path:
    sys.exit(0)
import tempfile
TMP_ROOTS = ("/tmp/", "/private/tmp/", "/var/folders/", tempfile.gettempdir().rstrip("/") + "/")
if path.startswith(TMP_ROOTS):
    sys.exit(0)                                   # OS scratch — anchored, so repo/tmp/ stays product
SCRATCH = ("/scratchpad/", "/.rolepod/", "/.claude/agent-memory/", "/docs/rolepod/")
if any(s in path for s in SCRATCH):
    sys.exit(0)
if os.environ.get("ROLEPOD_ALLOW_GENERIC_WRITE", "0") == "1":
    print("BYPASS"); sys.exit(0)
# evidence row (fail-open): stats can count generic-write denies per session
try:
    root = d.get("cwd") or os.getcwd()
    ev = os.path.join(root, ".rolepod", "evidence")
    if os.path.isdir(os.path.join(root, ".git")) or os.path.isdir(ev):
        os.makedirs(ev, exist_ok=True)
        with open(os.path.join(ev, "phase-log.jsonl"), "a") as f:
            f.write(json.dumps({"ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                                "phase": "write-scope", "agent_type": atype, "tool": tool,
                                "path": path, "decision": "deny", "provenance": "hook-auto"}) + "\n")
except Exception:
    pass
short = path if len(path) <= 80 else "…" + path[-79:]
reason = ("BLOCKED: generic sub-agent %r attempted %s on %s. A platform agent "
          "(general-purpose / default) never writes product files. Fix: stop and return "
          "BLOCKED naming this path — the Lead re-dispatches the write to a rolepod role "
          "(backend-developer / frontend-developer / qa-tester / ...). Exception: "
          "ROLEPOD_ALLOW_GENERIC_WRITE=1 (user-set).") % (atype, tool or "a write", short)
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                         "permissionDecision": "deny",
                                         "permissionDecisionReason": reason}}))
' 2>/dev/null || echo "")

[ -z "$DECISION" ] && exit 0
if [ "$DECISION" = "BYPASS" ]; then
  rolepod_log_bypass "subagent-write-scope" "ROLEPOD_ALLOW_GENERIC_WRITE"
  exit 0
fi
printf '%s\n' "$DECISION"
exit 0
