#!/bin/bash
# Integration test runner. Slow, local-only. Skips per-case if deps missing.
#
# Usage:
#   bash tests/integration/run.sh                # all cases
#   bash tests/integration/run.sh install-parity # one case
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CASES_DIR="$SCRIPT_DIR/cases"
ONE_CASE="${1:-}"

LOG_DIR="/tmp/rolepod-integration-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"
echo "logs: $LOG_DIR"
echo ""

PASS=0
FAIL=0
SKIP=0
FAILED_NAMES=()

run_case() {
  local script="$1"
  local name
  name="$(basename "$script" .sh)"

  echo "▸ $name"
  local out="$LOG_DIR/$name.out"
  if bash "$script" > "$out" 2>&1; then
    # Convention: case prints SKIP: on first line if dep missing, then exit 0.
    if head -1 "$out" | grep -q "^SKIP:"; then
      echo "  ~ skip ($(head -1 "$out" | sed 's/^SKIP: //'))"
      SKIP=$((SKIP+1))
    else
      echo "  ✓ pass"
      PASS=$((PASS+1))
    fi
  else
    echo "  ✗ FAIL — see $out"
    FAIL=$((FAIL+1))
    FAILED_NAMES+=("$name")
  fi
}

if [ -n "$ONE_CASE" ]; then
  script="$CASES_DIR/$ONE_CASE.sh"
  [ -f "$script" ] || { echo "ERROR: case not found: $script" >&2; exit 2; }
  run_case "$script"
else
  for script in "$CASES_DIR"/*.sh; do
    [ -f "$script" ] || continue
    run_case "$script"
  done
fi

echo ""
echo "─── Summary ───"
echo "  pass: $PASS"
echo "  skip: $SKIP"
echo "  fail: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "  failed cases:"
  for n in "${FAILED_NAMES[@]}"; do echo "    - $n"; done
  exit 1
fi

exit 0
