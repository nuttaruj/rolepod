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
{"ts":"2026-07-31T01:45:00Z","phase":"dispatch","tier":"strong","override":"opus"}
{"ts":"2026-07-31T01:50:00Z","phase":"dispatch","tier":"strong","override":"none"}
{"ts":"2026-07-31T01:55:00Z","phase":"dispatch-proof","cli":"codex","agent_type":"qa-tester","model":"gpt-5.6-terra","provenance":"hook-stdin"}
{"ts":"2026-07-31T01:56:00Z","phase":"dispatch-proof","cli":"antigravity","agent_type":"","model":"gemini-3-pro","provenance":"hook-stdin"}
not json — must be skipped, not crash
EOF
printf '{"ts":"2026-07-31T01:15:00Z","hook":"precommit-gate","var":"ROLEPOD_GATES_SOFT","reason":"unreasoned"}\n' \
  > "$FIX/repo/.rolepod/evidence/bypass.log"

OUT=$(bash "$REPO_DIR/scripts/stats.sh" "$FIX/repo")
check "stats reports tier distribution"   "printf '%s' \"\$OUT\" | grep -q 'R2'"
check "stats reports verify fail rate"    "printf '%s' \"\$OUT\" | grep -q 'fail=1'"
check "stats reports review verdicts"     "printf '%s' \"\$OUT\" | grep -q 'APPROVED: 1'"
check "stats flags unreasoned bypasses"   "printf '%s' \"\$OUT\" | grep -q 'unreasoned'"
check "stats audits strong dispatches"    "printf '%s' \"\$OUT\" | grep -q 'Strong dispatches (2): 1 with explicit override, 1 inherit'"
check "stats reports hook-reported model proof" "printf '%s' \"\$OUT\" | grep -q 'Model proof — hook-reported (2'"
check "stats shows proof per cli+model"   "printf '%s' \"\$OUT\" | grep -q 'gpt-5.6-terra'"
printf '{"agent_type":"qa","model":"m1"}' > "$FIX/subagent-stop.json"
check "codex model-log hook is fail-open outside a repo" \
  "cd /tmp && bash '$REPO_DIR/adapters/codex/plugins/rolepod/hooks/subagent-model-log.sh' < '$FIX/subagent-stop.json'"
check "stats names the silent downgrade"  "printf '%s' \"\$OUT\" | grep -q 'silent downgrade'"
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

# ── shipped copies — installed users read evidence without the source repo ──
check "claude plugin tree ships stats.sh (byte-exact)" \
  "diff -q '$REPO_DIR/scripts/stats.sh' '$REPO_DIR/plugins/rolepod/scripts/stats.sh'"
check "claude plugin tree ships junit-summary.sh (byte-exact)" \
  "diff -q '$REPO_DIR/scripts/junit-summary.sh' '$REPO_DIR/plugins/rolepod/scripts/junit-summary.sh'"
check "codex plugin tree ships stats.sh" \
  "diff -q '$REPO_DIR/scripts/stats.sh' '$REPO_DIR/plugins/rolepod-codex/scripts/stats.sh'"
check "installer wires rolepod-stats launcher" \
  "grep -q 'rolepod-stats' '$REPO_DIR/install.sh'"
check "installer wires launcher removal on uninstall" \
  "grep -A6 'Removing rolepod-stats' '$REPO_DIR/install.sh' | grep -q 'rm -rf.*rolepod/bin'"
check "launcher install+removal guarded against ALL temp-target vars (test runs must never touch real HOME)" \
  "[ \"\$(grep -c 'ROLEPOD_TARGET:-}\${ROLEPOD_CLAUDE_TARGET:-}\${ROLEPOD_CODEX_TARGET:-}\${ROLEPOD_GEMINI_TARGET:-}\${ROLEPOD_CURSOR_TARGET:-}\${ROLEPOD_ANTIGRAVITY_TARGET:-}\${ROLEPOD_OPENCODE_TARGET' '$REPO_DIR/install.sh')\" = 2 ]"

exit $fail
