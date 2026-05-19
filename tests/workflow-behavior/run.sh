#!/bin/bash
# Workflow behavior test runner — 2 modes.
#
# CONTRACT mode (default · release gate):
#   - Prepend a routing-test harness that forbids edits / tools / new files /
#     subagent spawns / clarifying questions.
#   - Force a strict 4-line response format:
#       Routing: <phase> -> <skill>
#       Reason: ...
#       Skipping: ...
#       Next step: ...
#   - Assert `expected_skills` substrings appear in the response.
#   - REQUIRED for release — failure → exit 1.
#
# ORGANIC mode (advisory only):
#   - Send the raw user prompt as-is (no harness, no constraints).
#   - Assert the full case (expected_skills + must_contain + must_not_contain).
#   - Failure does NOT fail the gate — exit always 0.
#   - Use organic failures to decide whether the always-on entry instructions
#     in CLAUDE.md / AGENTS.md / GEMINI.md need tightening.
#
# Both modes:
#   - Live `claude -p` execution gated by ROLEPOD_RUN_LIVE=1 (default skip).
#   - Per-case timeout (default 60s, override ROLEPOD_CASE_TIMEOUT=N).
#   - Logs at /tmp/rolepod-workflow-behavior-<timestamp>/ (one prompt +
#     response + assert-err per case per mode).
#
# Usage:
#   bash tests/workflow-behavior/run.sh                            # contract (default)
#   bash tests/workflow-behavior/run.sh --mode=contract            # release gate
#   bash tests/workflow-behavior/run.sh --mode=organic             # advisory
#   bash tests/workflow-behavior/run.sh --mode=both                # both, in order
#   bash tests/workflow-behavior/run.sh --mode=contract <case>     # one case
#
# Exit codes:
#   0 — contract green (organic advisory may still report)
#   1 — contract failed (release gate)
#   2 — runner error (case malformed, missing dep, bad flag)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CASES_DIR="$SCRIPT_DIR/cases"
PARSER="$SCRIPT_DIR/parse_case.py"

MODE="contract"
ONE_CASE=""
for arg in "$@"; do
  case "$arg" in
    --mode=*) MODE="${arg#--mode=}" ;;
    -h|--help) sed -n '2,38p' "$0"; exit 0 ;;
    *) ONE_CASE="$arg" ;;
  esac
done

case "$MODE" in
  contract|organic|both) ;;
  *) echo "ERROR: --mode must be contract|organic|both (got: $MODE)" >&2; exit 2 ;;
esac

# ─── Live execution gate ────────────────────────────────────────────────
# Both modes send live prompts. Default behavior is skip — `make test`
# stays cheap. Operator opts in with ROLEPOD_RUN_LIVE=1.
if [ "${ROLEPOD_RUN_LIVE:-0}" != "1" ]; then
  case_count=0
  if [ -d "$CASES_DIR" ]; then
    case_count=$(find "$CASES_DIR" -maxdepth 1 -name '*.yml' | wc -l | tr -d ' ')
  fi
  echo "SKIP: workflow-behavior runs live \`claude -p\` prompts (mutates state, spends budget)."
  echo "      $case_count case(s) found. Mode: $MODE. To execute live:"
  echo "        ROLEPOD_RUN_LIVE=1 bash tests/workflow-behavior/run.sh --mode=$MODE"
  exit 0
fi

# ─── Dependency check (only after live opt-in) ──────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not on PATH — workflow-behavior tests need YAML parsing"; exit 0
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "SKIP: claude CLI not on PATH — workflow-behavior tests need model access"; exit 0
fi
[ -d "$CASES_DIR" ] || { echo "ERROR: cases directory missing: $CASES_DIR" >&2; exit 2; }
[ -f "$PARSER" ]    || { echo "ERROR: parser missing: $PARSER" >&2; exit 2; }

# ─── Per-case timeout ───────────────────────────────────────────────────
CASE_TIMEOUT="${ROLEPOD_CASE_TIMEOUT:-60}"
TIMEOUT_KIND=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_KIND="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_KIND="gtimeout"
elif command -v perl >/dev/null 2>&1; then
  TIMEOUT_KIND="perl"
fi

run_with_timeout() {
  # Usage: run_with_timeout <seconds> <cmd> <args...>
  local seconds="$1"; shift
  case "$TIMEOUT_KIND" in
    timeout)  timeout  "$seconds" "$@"; return $? ;;
    gtimeout) gtimeout "$seconds" "$@"; return $? ;;
    perl)     perl -e 'alarm shift @ARGV; exec @ARGV' "$seconds" "$@"; return $? ;;
    *)        "$@"; return $? ;;
  esac
}

# ─── Sandbox cwd so the model cannot edit the rolepod repo ─────────────
LIVE_TMP="$(mktemp -d -t rolepod-workflow-XXXXXX)"
echo "live fixture cwd: $LIVE_TMP"
cd "$LIVE_TMP"

CLAUDE_FLAGS="-p"
if claude --help 2>&1 | grep -q -- "--max-turns"; then
  CLAUDE_FLAGS="$CLAUDE_FLAGS --max-turns 2"
fi

LOG_DIR="/tmp/rolepod-workflow-behavior-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"
echo "logs: $LOG_DIR"
echo "mode: $MODE · timeout: ${CASE_TIMEOUT}s · timeout-kind: ${TIMEOUT_KIND:-none}"
echo ""

# ─── Contract-mode harness prompt ───────────────────────────────────────
# The harness wraps the raw user prompt so the model returns the routing
# decision in a structured form we can grep. It explicitly forbids tools
# and follow-up questions so the test never mutates state.
HARNESS_HEAD=$(cat <<'HARNESS_EOF'
You are responding to a Rolepod routing test.

STRICT RULES — do not violate any:
- Do NOT edit any file.
- Do NOT create any file.
- Do NOT run shell commands, Bash, Edit, Write, MultiEdit, Read, or any tool.
- Do NOT spawn subagents.
- Do NOT ask clarifying questions.

Your only task: identify which Rolepod skill should fire for the user prompt
below, and answer in exactly this format (four lines, no extra prose):

Routing: <phase> -> <skill-name>
Reason: <one sentence on why this skill fires>
Skipping: <one sentence — name any skipped phase + why, or none>
Next step: <one sentence — which skill or hand-off comes next>

---USER-PROMPT-START---
HARNESS_EOF
)
HARNESS_TAIL='---USER-PROMPT-END---'

# ─── Per-case execution ─────────────────────────────────────────────────
PASS=0
GATE_FAIL=0
ADVISORY_FAIL=0
FAILED_NAMES=()

run_case_for_mode() {
  local case_file="$1"
  local mode="$2"
  local case_name
  case_name="$(basename "$case_file" .yml)"
  echo "▸ $case_name [$mode]"

  local parsed
  parsed="$(python3 "$PARSER" "$case_file" 2>"$LOG_DIR/$case_name.$mode.parse.err")" || {
    echo "  ✗ FAIL — parser error. See $LOG_DIR/$case_name.$mode.parse.err"
    FAILED_NAMES+=("$case_name [$mode] (parse)")
    return 1
  }

  local raw_prompt
  raw_prompt="$(echo "$parsed" | python3 -c 'import sys,json; print(json.load(sys.stdin)["prompt"])')"
  local expected_json
  expected_json="$(echo "$parsed" | python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin)["expected_skills"]))')"
  local must_contain_json
  local forbidden_json
  if [ "$mode" = "contract" ]; then
    # Contract mode asserts routing only. must_contain / must_not_contain
    # are organic-only — under the harness the model never produces them
    # naturally (no dialogue, no implementation prose).
    must_contain_json="[]"
    forbidden_json="[]"
  else
    must_contain_json="$(echo "$parsed" | python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin).get("must_contain", [])))')"
    forbidden_json="$(echo "$parsed" | python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin)["must_not_contain"]))')"
  fi

  local prompt
  if [ "$mode" = "contract" ]; then
    prompt="${HARNESS_HEAD}
${raw_prompt}
${HARNESS_TAIL}"
  else
    prompt="$raw_prompt"
  fi

  local prompt_file="$LOG_DIR/$case_name.$mode.prompt.txt"
  local response_file="$LOG_DIR/$case_name.$mode.response.txt"
  printf '%s' "$prompt" > "$prompt_file"

  local rc=0
  run_with_timeout "$CASE_TIMEOUT" claude $CLAUDE_FLAGS "$prompt" > "$response_file" 2>&1 || rc=$?
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 142 ]; then
    echo "  ✗ TIMEOUT after ${CASE_TIMEOUT}s. See $response_file"
    FAILED_NAMES+=("$case_name [$mode] (timeout)")
    return 1
  fi
  if [ "$rc" -ne 0 ]; then
    echo "  ✗ FAIL — claude CLI errored (rc=$rc). See $response_file"
    FAILED_NAMES+=("$case_name [$mode] (CLI error)")
    return 1
  fi

  local result
  result="$(python3 "$PARSER" assert "$expected_json" "$must_contain_json" "$forbidden_json" "$response_file" 2>"$LOG_DIR/$case_name.$mode.assert.err")" || {
    echo "  ✗ FAIL — assert helper errored. See $LOG_DIR/$case_name.$mode.assert.err"
    FAILED_NAMES+=("$case_name [$mode] (assert)")
    return 1
  }

  local missing_expected missing_required found_forbidden
  missing_expected="$(echo "$result" | sed -n '1p')"
  missing_required="$(echo "$result" | sed -n '2p')"
  found_forbidden="$(echo "$result" | sed -n '3p')"

  if [ -z "$missing_expected" ] && [ -z "$missing_required" ] && [ -z "$found_forbidden" ]; then
    echo "  ✓ pass"
    return 0
  fi

  echo "  ✗ FAIL"
  [ -n "$missing_expected" ] && echo "    missing expected_skills: $missing_expected"
  [ -n "$missing_required" ] && echo "    missing must_contain: $missing_required"
  [ -n "$found_forbidden" ] && echo "    forbidden found: $found_forbidden"
  echo "    response: $response_file"
  FAILED_NAMES+=("$case_name [$mode]")
  return 1
}

iterate_cases() {
  local mode="$1"
  local fail_kind="$2"   # "gate" | "advisory"
  if [ -n "$ONE_CASE" ]; then
    local case_file="$CASES_DIR/$ONE_CASE.yml"
    [ -f "$case_file" ] || { echo "ERROR: case not found: $case_file" >&2; return 2; }
    if run_case_for_mode "$case_file" "$mode"; then
      PASS=$((PASS+1))
    else
      [ "$fail_kind" = "gate" ] && GATE_FAIL=$((GATE_FAIL+1)) || ADVISORY_FAIL=$((ADVISORY_FAIL+1))
    fi
  else
    for case_file in "$CASES_DIR"/*.yml; do
      [ -f "$case_file" ] || continue
      if run_case_for_mode "$case_file" "$mode"; then
        PASS=$((PASS+1))
      else
        [ "$fail_kind" = "gate" ] && GATE_FAIL=$((GATE_FAIL+1)) || ADVISORY_FAIL=$((ADVISORY_FAIL+1))
      fi
    done
  fi
}

case "$MODE" in
  contract)
    echo "── contract mode (release gate) ──"
    iterate_cases contract gate
    ;;
  organic)
    echo "── organic mode (advisory) ──"
    iterate_cases organic advisory
    ;;
  both)
    echo "── contract mode (release gate) ──"
    iterate_cases contract gate
    echo ""
    echo "── organic mode (advisory) ──"
    iterate_cases organic advisory
    ;;
esac

# ─── Summary ─────────────────────────────────────────────────────────────
echo ""
echo "─── Summary ───"
echo "  pass:                            $PASS"
echo "  contract fail (release-gate):    $GATE_FAIL"
echo "  organic fail (advisory only):    $ADVISORY_FAIL"
if [ ${#FAILED_NAMES[@]} -gt 0 ]; then
  echo "  failed cases:"
  for n in "${FAILED_NAMES[@]}"; do echo "    - $n"; done
fi

# Exit policy: contract failures block release, organic stays advisory.
if [ "$GATE_FAIL" -gt 0 ]; then
  echo ""
  echo "release gate FAILED — contract-mode regression. Fix routing or always-on entry instructions in CLAUDE.md / AGENTS.md / GEMINI.md."
  exit 1
fi
if [ "$ADVISORY_FAIL" -gt 0 ]; then
  echo ""
  echo "advisory: $ADVISORY_FAIL organic case(s) drifted. Consider tightening always-on entry instructions in CLAUDE.md / AGENTS.md / GEMINI.md. Does NOT fail \`make test\`."
fi
exit 0
