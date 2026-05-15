#!/bin/bash
# Workflow behavior test runner.
# - Reads tests/workflow-behavior/cases/*.yml
# - Sends `prompt` to local `claude` CLI in headless mode
# - Asserts each `expected_skills` substring appears in response
# - Asserts no `must_not_contain` substring appears
# - Skips cleanly when `claude` CLI is missing
#
# Usage:
#   bash tests/workflow-behavior/run.sh                       # all cases
#   bash tests/workflow-behavior/run.sh case-01-vague-feature # one case
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CASES_DIR="$SCRIPT_DIR/cases"
PARSER="$SCRIPT_DIR/parse_case.py"
ONE_CASE="${1:-}"

# ─── Dependency check ────────────────────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not on PATH — workflow-behavior tests need YAML parsing"
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "SKIP: claude CLI not on PATH — workflow-behavior tests need model access"
  echo "Install: see Claude Code install docs"
  exit 0
fi

[ -d "$CASES_DIR" ] || { echo "ERROR: cases directory missing: $CASES_DIR" >&2; exit 2; }
[ -f "$PARSER" ]    || { echo "ERROR: parser missing: $PARSER" >&2; exit 2; }

# ─── Log dir per run ─────────────────────────────────────────────────────
LOG_DIR="/tmp/rolepod-workflow-behavior-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"
echo "logs: $LOG_DIR"
echo ""

# ─── Per-case execution ──────────────────────────────────────────────────
PASS=0
FAIL=0
FAILED_NAMES=()

run_case() {
  local case_file="$1"
  local case_name
  case_name="$(basename "$case_file" .yml)"

  echo "▸ $case_name"

  local parsed
  parsed="$(python3 "$PARSER" "$case_file" 2>"$LOG_DIR/$case_name.parse.err")" || {
    echo "  ✗ FAIL — parser error. See $LOG_DIR/$case_name.parse.err"
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$case_name (parse)"); return
  }

  local prompt
  prompt="$(echo "$parsed" | python3 -c 'import sys,json; print(json.load(sys.stdin)["prompt"])')"
  local expected_json
  expected_json="$(echo "$parsed" | python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin)["expected_skills"]))')"
  local forbidden_json
  forbidden_json="$(echo "$parsed" | python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin)["must_not_contain"]))')"

  local response_file="$LOG_DIR/$case_name.response.txt"
  if ! claude -p "$prompt" > "$response_file" 2>&1; then
    echo "  ✗ FAIL — claude CLI errored. See $response_file"
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$case_name (CLI error)"); return
  fi

  # Two-line output from parser: missing, then found.
  local result
  result="$(python3 "$PARSER" assert "$expected_json" "$forbidden_json" "$response_file" 2>"$LOG_DIR/$case_name.assert.err")" || {
    echo "  ✗ FAIL — assert helper errored. See $LOG_DIR/$case_name.assert.err"
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$case_name (assert)"); return
  }

  local missing found
  missing="$(echo "$result" | sed -n '1p')"
  found="$(echo "$result" | sed -n '2p')"

  if [ -z "$missing" ] && [ -z "$found" ]; then
    echo "  ✓ pass"
    PASS=$((PASS+1))
  else
    echo "  ✗ FAIL"
    [ -n "$missing" ] && echo "    missing expected: $missing"
    [ -n "$found" ] && echo "    forbidden found: $found"
    echo "    response: $response_file"
    FAIL=$((FAIL+1))
    FAILED_NAMES+=("$case_name")
  fi
}

# ─── Iterate cases ───────────────────────────────────────────────────────
if [ -n "$ONE_CASE" ]; then
  case_file="$CASES_DIR/$ONE_CASE.yml"
  [ -f "$case_file" ] || { echo "ERROR: case not found: $case_file" >&2; exit 2; }
  run_case "$case_file"
else
  for case_file in "$CASES_DIR"/*.yml; do
    [ -f "$case_file" ] || continue
    run_case "$case_file"
  done
fi

# ─── Summary ─────────────────────────────────────────────────────────────
echo ""
echo "─── Summary ───"
echo "  pass: $PASS"
echo "  fail: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "  failed cases:"
  for n in "${FAILED_NAMES[@]}"; do echo "    - $n"; done
  exit 1
fi

exit 0
