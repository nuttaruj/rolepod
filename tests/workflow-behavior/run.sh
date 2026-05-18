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

# ─── Live execution gate ────────────────────────────────────────────────
# These cases send live prompts to `claude -p` (e.g. "Build a React todo
# list", "Ship it"). That costs API budget and produces real side-effect
# text. NEVER fire from a default `make test` invocation. Require the
# operator to opt in explicitly:
#
#   ROLEPOD_RUN_LIVE=1 bash tests/workflow-behavior/run.sh
#
# Default behavior (no flag): parse cases, report case count, skip clean
# with exit 0. CI Phase 1 calls `make test` which calls this script —
# without the flag it stays cheap.
if [ "${ROLEPOD_RUN_LIVE:-0}" != "1" ]; then
  case_count=0
  if [ -d "$CASES_DIR" ]; then
    case_count=$(find "$CASES_DIR" -maxdepth 1 -name '*.yml' | wc -l | tr -d ' ')
  fi
  echo "SKIP: workflow-behavior runs live \`claude -p\` prompts (mutates state, spends budget)."
  echo "      $case_count case(s) found. To execute live:"
  echo "        ROLEPOD_RUN_LIVE=1 bash tests/workflow-behavior/run.sh"
  exit 0
fi

# ─── Dependency check (only after live opt-in) ──────────────────────────
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

# Constrain live model spend: hard cap on turns + run from a temp cwd so
# the model can't accidentally edit the rolepod repo while answering
# "Build a React todo list".
LIVE_TMP="$(mktemp -d -t rolepod-workflow-XXXXXX)"
echo "live fixture cwd: $LIVE_TMP"
cd "$LIVE_TMP"
CLAUDE_FLAGS="-p"
# Per Anthropic Claude Code docs, --max-turns limits agent recursion. Keep low
# so prompts get one routing decision + one short response, not a full task.
if claude --help 2>&1 | grep -q -- "--max-turns"; then
  CLAUDE_FLAGS="$CLAUDE_FLAGS --max-turns 2"
fi

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
  local must_contain_json
  must_contain_json="$(echo "$parsed" | python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin).get("must_contain", [])))')"
  local forbidden_json
  forbidden_json="$(echo "$parsed" | python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin)["must_not_contain"]))')"

  local response_file="$LOG_DIR/$case_name.response.txt"
  # Use $CLAUDE_FLAGS (set in dep check block) so --max-turns applies when supported.
  if ! claude $CLAUDE_FLAGS "$prompt" > "$response_file" 2>&1; then
    echo "  ✗ FAIL — claude CLI errored. See $response_file"
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$case_name (CLI error)"); return
  fi

  # Three-line output from parser: missing-expected, missing-required (must_contain), found-forbidden.
  local result
  result="$(python3 "$PARSER" assert "$expected_json" "$must_contain_json" "$forbidden_json" "$response_file" 2>"$LOG_DIR/$case_name.assert.err")" || {
    echo "  ✗ FAIL — assert helper errored. See $LOG_DIR/$case_name.assert.err"
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$case_name (assert)"); return
  }

  local missing_expected missing_required found_forbidden
  missing_expected="$(echo "$result" | sed -n '1p')"
  missing_required="$(echo "$result" | sed -n '2p')"
  found_forbidden="$(echo "$result" | sed -n '3p')"

  if [ -z "$missing_expected" ] && [ -z "$missing_required" ] && [ -z "$found_forbidden" ]; then
    echo "  ✓ pass"
    PASS=$((PASS+1))
  else
    echo "  ✗ FAIL"
    [ -n "$missing_expected" ] && echo "    missing expected_skills: $missing_expected"
    [ -n "$missing_required" ] && echo "    missing must_contain: $missing_required"
    [ -n "$found_forbidden" ] && echo "    forbidden found: $found_forbidden"
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
