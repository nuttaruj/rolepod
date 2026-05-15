#!/bin/bash
# bug-fix-workflow — STUB.
# Expected behavior when implemented:
#   1. Fixture = small Node or Python project with one failing test.
#   2. Send `claude -p "Fix the failing test"` to the Claude CLI.
#   3. Assert agent runs systematic-debugging:
#      - reproduces test failure with the exact pytest/npm test command
#      - identifies file:line of failure
#      - writes minimal fix at root cause (not symptom patch)
#      - re-runs test → green
#      - runs full suite → no regression
#   4. Assert tool-use log contains: `systematic-debugging` skill reference.
#   5. Assert response does NOT contain: "likely cause", "I think", "without running".
#
# Skip condition: claude CLI not on PATH.
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "SKIP: claude CLI not on PATH"
  exit 0
fi

# TODO: implement fixture + assertions once tests/workflow-behavior/ proves
# routing works. Until then, document expected behavior + exit clean.
echo "SKIP: bug-fix-workflow stub — fixture + assertions pending. See script header."
exit 0
