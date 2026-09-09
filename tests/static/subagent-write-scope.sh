#!/bin/bash
# Static test — hooks/subagent-write-scope.sh (v2.111.0).
#
# A generic platform sub-agent (general-purpose / default / claude) is denied
# any Edit/Write on a product path; the Lead, every rolepod role, an unknown
# type, and scratch / evidence paths pass. One case per rule.
# Wired into `make test-static`.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"
HOOK="hooks/subagent-write-scope.sh"
fail=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# run in a scratch cwd with no .git so the evidence row never lands in the repo
WORK="$TMP/work"; mkdir -p "$WORK"

# run <json> <expect: deny|allow> <label> [env]
run() {
  local got
  got=$(cd "$WORK" && printf '%s' "$1" | env ${4:-} bash "$REPO_DIR/$HOOK" 2>/dev/null || true)
  local verdict="allow"
  printf '%s' "$got" | grep -q '"permissionDecision": "deny"' && verdict="deny"
  if [ "$verdict" = "$2" ]; then
    echo "  ✓ $3"
  else
    echo "  ✗ $3 — expected $2, got $verdict"; fail=$((fail+1))
  fi
}

P='/Users/x/proj/src/booking.ts'
echo "── subagent-write-scope ──"

run '{"tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  allow "Lead (no agent_id) edits freely"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  deny "general-purpose Edit on a product path is denied"

run '{"agent_id":"a1","agent_type":"default","tool_name":"Write","tool_input":{"file_path":"'"$P"'"}}' \
  deny "default agent Write on a product path is denied"

run '{"agent_id":"a1","agent_type":"rolepod:backend-developer","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  allow "a rolepod role writes"

run '{"agent_id":"a1","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  allow "sub-agent with no agent_type passes (fail-open)"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Write","tool_input":{"file_path":"/Users/x/proj/scratchpad/notes.md"}}' \
  allow "general-purpose may write scratchpad"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Write","tool_input":{"file_path":"/Users/x/proj/.rolepod/evidence/r.md"}}' \
  allow "general-purpose may write evidence"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Write","tool_input":{"file_path":"/private/tmp/claude-501/x/probe.ts"}}' \
  allow "general-purpose may write under the OS temp root"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Edit","tool_input":{"file_path":"/Users/x/proj/src/tmp/fixture.json"}}' \
  deny "a repo-internal tmp/ directory is product, not scratch"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"NotebookEdit","tool_input":{"notebook_path":"/Users/x/proj/analysis.ipynb"}}' \
  deny "NotebookEdit on a product notebook is denied"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  allow "ROLEPOD_ALLOW_GENERIC_WRITE=1 bypasses" "ROLEPOD_ALLOW_GENERIC_WRITE=1"

# deny reason names the fix + exception, stays under the lean cap
REASON=$(cd "$WORK" && printf '%s' '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  | bash "$REPO_DIR/$HOOK" 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecisionReason"])')
if printf '%s' "$REASON" | grep -q "re-dispatches the write to a rolepod role" && printf '%s' "$REASON" | grep -q "ROLEPOD_ALLOW_GENERIC_WRITE=1" && [ "${#REASON}" -le 600 ]; then
  echo "  ✓ deny reason = fact → Fix → Exception, ${#REASON} chars"
else
  echo "  ✗ deny reason shape/length (${#REASON} chars)"; fail=$((fail+1))
fi

# bypass inside a git repo lands one row in bypass.log
REPO="$TMP/repo"; mkdir -p "$REPO"; (cd "$REPO" && git init -q)
(cd "$REPO" && printf '%s' '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  | ROLEPOD_ALLOW_GENERIC_WRITE=1 ROLEPOD_BYPASS_REASON=test bash "$REPO_DIR/$HOOK" >/dev/null 2>&1 || true)
if grep -q '"hook":"subagent-write-scope","var":"ROLEPOD_ALLOW_GENERIC_WRITE"' "$REPO/.rolepod/evidence/bypass.log" 2>/dev/null; then
  echo "  ✓ bypass is logged to bypass.log"
else
  echo "  ✗ bypass row missing from bypass.log"; fail=$((fail+1))
fi

# a deny with no .git and no .rolepod/evidence writes no evidence row
if [ ! -e "$WORK/.rolepod" ]; then
  echo "  ✓ no evidence dir created outside a repo"
else
  echo "  ✗ evidence dir created outside a repo"; fail=$((fail+1))
fi

[ "$fail" -eq 0 ] && echo "  → subagent-write-scope: all passed" || { echo "  → subagent-write-scope: $fail failed"; exit 1; }
