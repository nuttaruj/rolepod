#!/bin/bash
# evidence-tools — locks the two evidence readers:
#   scripts/stats.sh          (phase-log/bypass observational readout)
#   scripts/junit-summary.sh  (JUnit XML → counted pass/fail + failed names)
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1"; fail=1
  fi
}

FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-evtools.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

# ── stats.sh ────────────────────────────────────────────────────────────
mkdir -p "$FIX/repo/.rolepod/evidence"
git -C "$FIX/repo" init -q
cat > "$FIX/repo/.rolepod/evidence/phase-log.jsonl" <<'EOF'
{"ts":"2026-07-31T01:00:00Z","phase":"route","tier":"R2","skill":"implement-plan"}
{"ts":"2026-07-31T01:05:00Z","phase":"route","tier":"R3","skill":"write-spec"}
{"ts":"2026-07-31T01:10:00Z","phase":"verify","verdict":"pass","evidence":"pytest -q"}
{"ts":"2026-07-31T01:20:00Z","phase":"verify","verdict":"fail","evidence":"pytest -q"}
{"ts":"2026-07-31T01:30:00Z","phase":"review","verdict":"APPROVED","blockers":0}
{"ts":"2026-07-31T01:40:00Z","phase":"ship","action":"pr"}
not json — must be skipped, not crash
EOF
printf '{"ts":"2026-07-31T01:15:00Z","hook":"precommit-gate","var":"ROLEPOD_GATES_SOFT","reason":"unreasoned"}\n' \
  > "$FIX/repo/.rolepod/evidence/bypass.log"

OUT=$(bash "$REPO_DIR/scripts/stats.sh" "$FIX/repo")
check "stats reports tier distribution"   "printf '%s' \"\$OUT\" | grep -q 'R2'"
check "stats reports verify fail rate"    "printf '%s' \"\$OUT\" | grep -q 'fail=1'"
check "stats reports review verdicts"     "printf '%s' \"\$OUT\" | grep -q 'APPROVED: 1'"
check "stats flags unreasoned bypasses"   "printf '%s' \"\$OUT\" | grep -q 'unreasoned'"
check "stats survives malformed lines"    "bash '$REPO_DIR/scripts/stats.sh' '$FIX/repo'"
OUT=$(bash "$REPO_DIR/scripts/stats.sh" "$FIX")
check "stats handles empty repo (no data)" "printf '%s' \"\$OUT\" | grep -q 'no data yet'"

# ── junit-summary.sh ────────────────────────────────────────────────────
cat > "$FIX/report.xml" <<'EOF'
<testsuite name="suite" tests="3" failures="1" errors="0" skipped="1">
  <testcase classname="pkg.TestA" name="test_TC1_boundary"/>
  <testcase classname="pkg.TestA" name="test_TC2_minimum">
    <failure message="expected 48 got 50"/>
  </testcase>
  <testcase classname="pkg.TestB" name="test_skipped"><skipped/></testcase>
</testsuite>
EOF
OUT=$(bash "$REPO_DIR/scripts/junit-summary.sh" "$FIX/report.xml" || true)
check "junit counts totals"               "printf '%s' \"\$OUT\" | grep -q '3 tests — 1 passed, 1 failed, 0 errors, 1 skipped'"
check "junit names the failed test"       "printf '%s' \"\$OUT\" | grep -q 'pkg.TestA::test_TC2_minimum'"
check "junit exits 1 on failures"         "! bash '$REPO_DIR/scripts/junit-summary.sh' '$FIX/report.xml'"

cat > "$FIX/green.xml" <<'EOF'
<testsuite name="suite" tests="1" failures="0" errors="0" skipped="0">
  <testcase classname="pkg.TestA" name="test_ok"/>
</testsuite>
EOF
check "junit exits 0 on green"            "bash '$REPO_DIR/scripts/junit-summary.sh' '$FIX/green.xml'"
check "check-work cites junit-summary"    "grep -q 'junit-summary.sh' '$REPO_DIR/core/skills/check-work/SKILL.md'"

exit $fail
