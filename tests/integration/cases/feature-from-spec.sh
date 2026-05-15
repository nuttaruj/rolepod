#!/bin/bash
# feature-from-spec — STUB.
# Expected behavior when implemented:
#   1. Fixture = small project + a `docs/plans/<feature>.md` task list.
#   2. Send `claude -p "Implement the plan in docs/plans/<feature>.md"`.
#   3. Assert agent runs in order:
#      - planning-and-task-breakdown (reads + confirms tasks)
#      - subagent-task-execution (spawns implementer + reviewers per task)
#      - test-driven-development for each task
#      - post-change-verify before claiming done
#   4. Assert no implementation code lands before the plan is read.
#
# Skip condition: claude CLI not on PATH.
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "SKIP: claude CLI not on PATH"
  exit 0
fi

echo "SKIP: feature-from-spec stub — fixture + assertions pending. See script header."
exit 0
