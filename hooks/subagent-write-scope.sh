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
# is the line, checked by the hook, not judged at dispatch. 41 of 59 deny rows
# (30 days) were agents writing their own memory files outside the repo.
#
# Mechanism: Claude Code PreToolUse hook input carries `agent_id` +
# `agent_type` only for a sub-agent call (live-verified 2026-09-09: a spawn
# with subagent_type omitted OR 'general-purpose' arrives as
# agent_type='general-purpose'). Classes, namespace stripped:
#   generic   general-purpose / default / claude / workflow-subagent (a bare
#             Workflow agent(); live-verified 2026-09-09) → no product write at all
#   test-only qa-tester / security-engineer       → test paths + markdown only
#             (test path = test dir segment or test-named file; `specs/` is a
#             contract dir in rolepod's own convention and Python has no
#             `_test.py` guarantee — both stay product; `spec/` = RSpec root)
#   read-only universal-reviewer / adversarial-reviewer / scout → markdown only
# Every other role and every unknown type passes (fail-open). OS temp roots,
# scratchpad, .rolepod/, agent memory and docs/rolepod/ are always free. A path
# outside the git toplevel of the payload cwd (plus the main checkout of a linked
# worktree, which still counts as inside, so it stays guarded) is free too; no
# resolvable root, no skip. The denied agent returns the finding; the Lead
# dispatches the write to the owning role — nothing is lost but one spawn.
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
_rcfg="${BASH_SOURCE[0]%/*}"; [ "$_rcfg" != "${BASH_SOURCE[0]}" ] || _rcfg=.
. "$_rcfg/lib/session-mode.sh"
rolepod_session_profile_load "$INPUT" "${ROLEPOD_SESSION_CLI:-unknown}"
[[ "$INPUT" == *'"agent_id"'* ]] || exit 0         # Lead conversation: no python spawn
command -v python3 >/dev/null 2>&1 || exit 0

# One pass: parse, classify, decide. Prints nothing (pass), BYPASS, or three
# lines: the gate id (scope-*), the deny JSON, the warn JSON (C4 shape).
DECISION=$(printf '%s' "$INPUT" | python3 -I -c '
import sys, json, os, re, datetime, tempfile, subprocess
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not (d.get("agent_id") or ""):
    sys.exit(0)                                   # Lead conversation
atype = (d.get("agent_type") or "").strip()
bare = atype.split(":")[-1].lower()
GENERIC   = ("general-purpose", "default", "claude", "workflow-subagent")
TEST_ONLY = ("qa-tester", "security-engineer")
READ_ONLY = ("universal-reviewer", "adversarial-reviewer", "scout")
if bare in GENERIC:     cls = "generic"
elif bare in TEST_ONLY: cls = "test-only"
elif bare in READ_ONLY: cls = "read-only"
else:                   sys.exit(0)               # an owning role, or unknown → pass
tool = d.get("tool_name") or ""
cwd = d.get("cwd") or os.getcwd()
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
def outside_repo(p, cwd):
    # True only when a root resolved and p is outside every root (no root → no skip)
    try:   # timeout=1: the hook budget is 3 s
        r = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel", "--git-common-dir"],
                           capture_output=True, text=True, timeout=1)
        top, cdir = r.stdout.splitlines()[:2]
        ids = set()                                # (st_dev, st_ino) of each root: identity, not spelling
        for x in (top, os.path.dirname(os.path.realpath(cdir if os.path.isabs(cdir) else os.path.join(cwd, cdir)))):
            s = os.stat(x); ids.add((s.st_dev, s.st_ino))
        p = os.path.realpath(p if os.path.isabs(p) else os.path.join(cwd, p))
        while True:                                # nearest existing ancestor (a new file does not exist yet)
            try:
                os.stat(p); break
            except (FileNotFoundError, NotADirectoryError):
                p = os.path.dirname(p)
        while True:                                # walk up: inside when any ancestor is a root
            s = os.stat(p)
            if (s.st_dev, s.st_ino) in ids:
                return False
            q = os.path.dirname(p)
            if q == p:
                return True
            p = q
    except Exception:
        return False                               # any error → inside (no skip)
if outside_repo(path, cwd):
    sys.exit(0)                                   # outside this repo (e.g. agent memory): not guarded here
# evidence row (fail-open): stats can count out-of-scope denies per session
try:
    root = cwd
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
if bare == "workflow-subagent":
    gate = "scope-bare-workflow"
    body = ("a bare Workflow agent() attempted %s on %s. A writing stage needs a role. "
            "Fix: set agentType: \x27rolepod:<role>\x27 (backend-developer / frontend-developer / ...) on "
            "this agent() call and resume the workflow (finished stages replay from cache); "
            "NAMEPATH; a repro script goes to $TMPDIR or the scratchpad. "
            "Exception: none for a bare agent().") % (verb, short)
elif cls == "generic":
    gate = "scope-generic"
    body = ("generic sub-agent %r attempted %s on %s. A platform agent "
            "(general-purpose / default) never writes product files. Fix: stop and return "
            "the finding naming this path — the Lead re-dispatches the write to a rolepod role "
            "(backend-developer / frontend-developer / qa-tester / ...). "
            "Exception: none for a platform agent.") % (atype, verb, short)
elif cls == "test-only":
    gate = "scope-test-role"
    body = ("%r attempted %s on %s — not a test path. This role writes tests, "
            "fixtures, test config and markdown only; production code belongs to the owning "
            "role. Fix: return the finding (file:line + the exact change) — the Lead dispatches "
            "the domain role. Exception: none outside test paths and markdown.") % (atype, verb, short)
else:
    gate = "scope-readonly-role"
    body = ("%r attempted %s on %s. This role is read-only: report and point, "
            "never modify. Fix: put the change in the report (file:line + exact fix) — the "
            "Lead applies it or dispatches the owning role. Exception: markdown files.") % (atype, verb, short)
def out(**kw):
    h = {"hookEventName": "PreToolUse"}; h.update(kw)
    return json.dumps({"hookSpecificOutput": h})
print(gate)
print(out(permissionDecision="deny", permissionDecisionReason="BLOCKED: " + body.replace(
    "NAMEPATH", "put BLOCKED and this path in your StructuredOutput answer (or final text)")))
print(out(additionalContext="WARNING: " + body.replace("NAMEPATH", "name this path in your final answer")))
' 2>/dev/null || echo "")

[ -z "$DECISION" ] && exit 0
if [ "$DECISION" = "BYPASS" ]; then
  rolepod_log_bypass "subagent-write-scope" "ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE"
  exit 0
fi
{ IFS= read -r _gate; IFS= read -r _deny; IFS= read -r _warn; } <<EOF || true
$DECISION
EOF
case "$(rolepod_gate_action "$_gate")" in
  deny) printf '%s\n' "$_deny" ;;
  warn) printf '%s\n' "$_warn" ;;
esac
exit 0
