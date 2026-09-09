#!/bin/bash
# PreToolUse Edit/Write/MultiEdit/NotebookEdit — a sub-agent writes only what
# its role owns.
#
# Rationale: measured across every product repo (30 days of subagent
# transcripts). Generic agents: 16 of 31 `general-purpose` dispatches edited
# product code with no role doctrine, no tool cap and no cohesion contract.
# Reviewer roles: qa-tester wrote 99 non-test product files (payments,
# account deletion, tenant erasure) and security-engineer edited auth routes —
# both agent files already say "the respective agent fixes", and the review
# floor then reads a diff its own role wrote. universal-reviewer, whose file
# says REJECT a fix request, wrote 0 of 21. Text works when it is a flat
# refusal; a "write-mode" that includes "fix code" does not. The write itself
# is the line, checked by the hook, not judged at dispatch.
#
# Mechanism: Claude Code PreToolUse hook input carries `agent_id` +
# `agent_type` only for a sub-agent call (live-verified 2026-09-09: a spawn
# with subagent_type omitted OR 'general-purpose' arrives as
# agent_type='general-purpose'). Classes, namespace stripped:
#   generic   general-purpose / default / claude  → no product write at all
#   test-only qa-tester / security-engineer       → test paths + markdown only
#             (test path = test dir segment or test-named file; `specs/` is a
#             contract dir in rolepod's own convention and Python has no
#             `_test.py` guarantee — both stay product; `spec/` = RSpec root)
#   read-only universal-reviewer / scout          → markdown only
# Every other role and every unknown type passes (fail-open). OS temp roots,
# scratchpad, .rolepod/, agent memory and docs/rolepod/ are always free. The
# denied agent returns the finding; the Lead dispatches the write to the
# owning role — nothing is lost but one spawn.
#
# Bypass: ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE=1 (user-set, logged to bypass.log).
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

# One pass: parse, classify, decide. Prints the deny JSON, BYPASS, or nothing.
DECISION=$(printf '%s' "$INPUT" | python3 -I -c '
import sys, json, os, re, datetime, tempfile
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not (d.get("agent_id") or ""):
    sys.exit(0)                                   # Lead conversation
atype = (d.get("agent_type") or "").strip()
bare = atype.split(":")[-1].lower()
GENERIC   = ("general-purpose", "default", "claude")
TEST_ONLY = ("qa-tester", "security-engineer")
READ_ONLY = ("universal-reviewer", "scout")
if bare in GENERIC:     cls = "generic"
elif bare in TEST_ONLY: cls = "test-only"
elif bare in READ_ONLY: cls = "read-only"
else:                   sys.exit(0)               # an owning role, or unknown → pass
tool = d.get("tool_name") or ""
ti = d.get("tool_input") or {}
path = ti.get("file_path") or ti.get("notebook_path") or ""
if not path:
    sys.exit(0)
TMP_ROOTS = ("/tmp/", "/private/tmp/", "/var/folders/", tempfile.gettempdir().rstrip("/") + "/")
if path.startswith(TMP_ROOTS):
    sys.exit(0)                                   # OS scratch — anchored, so repo/tmp/ stays product
SCRATCH = ("/scratchpad/", "/.rolepod/", "/.claude/agent-memory/", "/docs/rolepod/")
if any(s in path for s in SCRATCH):
    sys.exit(0)
TEST_DIR  = re.compile(r"(^|/)(tests?|__tests__|__mocks__|__snapshots__|spec|fixtures?|e2e|testdata|cypress|playwright)(/|$)")
TEST_FILE = re.compile(r"\.(test|spec|test-d|cy)\.[A-Za-z0-9]+(\.snap)?$|(^|/)test_[^/]+\.py$|_(test|spec)\.(go|rs|rb|ex|exs)$"
                       r"|(^|/)conftest\.py$|(^|/)(vitest|jest|playwright|cypress|karma)\.config\.[A-Za-z0-9.]+$"
                       r"|(^|/)(pytest\.ini|phpunit\.xml|\.mocharc[^/]*)$|(Test|Tests|Spec)\.(java|kt|cs|swift|php)$|\.feature$")
is_test = bool(TEST_DIR.search(path) or TEST_FILE.search(path))
is_md   = path.lower().endswith((".md", ".markdown"))
if cls == "test-only" and (is_test or is_md): sys.exit(0)
if cls == "read-only" and is_md:              sys.exit(0)
if os.environ.get("ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE", "0") == "1":
    print("BYPASS"); sys.exit(0)
# evidence row (fail-open): stats can count out-of-scope denies per session
try:
    root = d.get("cwd") or os.getcwd()
    ev = os.path.join(root, ".rolepod", "evidence")
    if os.path.isdir(os.path.join(root, ".git")) or os.path.isdir(ev):
        os.makedirs(ev, exist_ok=True)
        with open(os.path.join(ev, "phase-log.jsonl"), "a") as f:
            f.write(json.dumps({"ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                                "phase": "write-scope", "class": cls, "agent_type": atype, "tool": tool,
                                "path": path, "decision": "deny", "provenance": "hook-auto"}) + "\n")
except Exception:
    pass
short = path if len(path) <= 80 else "…" + path[-79:]
verb = tool or "a write"
if cls == "generic":
    reason = ("BLOCKED: generic sub-agent %r attempted %s on %s. A platform agent "
              "(general-purpose / default) never writes product files. Fix: stop and return "
              "BLOCKED naming this path — the Lead re-dispatches the write to a rolepod role "
              "(backend-developer / frontend-developer / qa-tester / ...). Exception: "
              "ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE=1 (user-set).") % (atype, verb, short)
elif cls == "test-only":
    reason = ("BLOCKED: %r attempted %s on %s — not a test path. This role writes tests, "
              "fixtures, test config and markdown only; production code belongs to the owning "
              "role. Fix: return the finding (file:line + the exact change) — the Lead dispatches "
              "the domain role. Exception: ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE=1 (user-set).") % (atype, verb, short)
else:
    reason = ("BLOCKED: %r attempted %s on %s. This role is read-only: report and point, "
              "never modify. Fix: put the change in the report (file:line + exact fix) — the "
              "Lead applies it or dispatches the owning role. Exception: "
              "ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE=1 (user-set).") % (atype, verb, short)
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                         "permissionDecision": "deny",
                                         "permissionDecisionReason": reason}}))
' 2>/dev/null || echo "")

[ -z "$DECISION" ] && exit 0
if [ "$DECISION" = "BYPASS" ]; then
  rolepod_log_bypass "subagent-write-scope" "ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE"
  exit 0
fi
printf '%s\n' "$DECISION"
exit 0
