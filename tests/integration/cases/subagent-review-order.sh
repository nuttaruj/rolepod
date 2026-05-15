#!/bin/bash
# subagent-review-order — STUB.
# Expected behavior when implemented:
#   1. Fixture = small implementation plan with 2 independent tasks.
#   2. Send `claude -p "Execute the plan in docs/plans/<plan>.md"`.
#   3. Assert sub-agent order per skill `subagent-task-execution`:
#      - Stage 1: implementer subagent writes the code.
#      - Stage 2a: spec-compliance reviewer runs in independent context.
#      - Stage 2b: code-quality reviewer runs in independent context.
#      - Task marked done ONLY when both reviewers pass.
#      - Final review pass runs after both tasks complete.
#   4. Assert code-quality reviewer does NOT replace spec-compliance reviewer.
#
# Skip condition: claude CLI not on PATH.
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "SKIP: claude CLI not on PATH"
  exit 0
fi

echo "SKIP: subagent-review-order stub — fixture + assertions pending. See script header."
exit 0
