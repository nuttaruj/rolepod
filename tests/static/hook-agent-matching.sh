#!/bin/bash
# Regression test — hooks must count plugin-namespaced reviewer agents.
#
# Bug: session_state.count_reviewers_dispatched matched bare agent names
# only. A plugin-installed reviewer is dispatched as 'rolepod:qa-tester';
# it counted as 0, so precommit-gate false-blocked a commit even after
# qa-tester + security-engineer had actually reviewed and APPROVED.
#
# Wired into `make test-static`.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"

SS="hooks/lib/session_state.py"
fail=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# run <transcript-jsonl> <query> <expected> <label>
run() {
  printf '%s\n' "$1" > "$tmp"
  local got
  got=$(printf '{"transcript_path":"%s"}' "$tmp" | python3 "$SS" "$2" 2>/dev/null || echo ERR)
  if [ "$got" = "$3" ]; then
    echo "  ✓ $4 (got $got)"
  else
    echo "  ✗ $4 — expected $3, got $got"
    fail=$((fail+1))
  fi
}

echo "── hook-agent-matching ──"

# The bug: a plugin-namespaced reviewer must count.
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:qa-tester"}}' \
  count-reviewers-dispatched 1 "rolepod:qa-tester counts as a reviewer"

# The 'Task' tool name must count too (CLI-version variance).
run '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer"}}' \
  count-reviewers-dispatched 1 "Task tool + rolepod:security-engineer counts"

# A bare (un-namespaced) name must still count — no regression.
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"qa-tester"}}' \
  count-reviewers-dispatched 1 "bare qa-tester still counts"

# A non-reviewer agent must NOT count.
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:backend-developer"}}' \
  count-reviewers-dispatched 0 "rolepod:backend-developer is not a reviewer"

echo ""
if [ $fail -eq 0 ]; then
  echo "hook-agent-matching: pass"
  exit 0
fi
echo "hook-agent-matching: $fail failure(s)"
exit 1
