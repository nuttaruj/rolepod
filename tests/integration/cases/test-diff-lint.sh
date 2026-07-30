#!/bin/bash
# test-diff-lint — the machine-checkable half of qa-tester's REJECT list.
# Proves each detector on a synthetic staged diff, proves silence on a clean
# diff, and proves the HUMAN-ONLY caveat always accompanies findings (a green
# lint must never be readable as "tests are good").
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
LINT="$REPO_DIR/hooks/test-diff-lint.sh"

fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1"; fail=1
  fi
}

FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-lint.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
git -C "$FIX" init -q
git -C "$FIX" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init

run_lint() { (cd "$FIX" && bash "$LINT" 2>/dev/null); }
reset_stage() { git -C "$FIX" reset -q; git -C "$FIX" checkout -q -- . 2>/dev/null || true; git -C "$FIX" clean -qfd; }

# 1. Added .only → finding + HUMAN-ONLY caveat.
mkdir -p "$FIX/tests"
printf 'it.only("works", () => {});\n' > "$FIX/tests/a.test.js"
git -C "$FIX" add -A
OUT=$(run_lint)
check "detects added .only"            "printf '%s' \"\$OUT\" | grep -q 'focus/skip marker'"
check "findings carry HUMAN-ONLY caveat" "printf '%s' \"\$OUT\" | grep -q 'HUMAN-ONLY'"
check "lint exits 0 (warn-only)"       "(cd '$FIX' && bash '$LINT')"
reset_stage

# 2. Deleted test case → finding.
mkdir -p "$FIX/tests"
printf 'it("keeps", () => {});\nit("drops", () => {});\n' > "$FIX/tests/b.test.js"
git -C "$FIX" add -A && git -C "$FIX" -c user.email=t@t -c user.name=t commit -qm add
printf 'it("keeps", () => {});\n' > "$FIX/tests/b.test.js"
git -C "$FIX" add -A
OUT=$(run_lint)
check "detects deleted test case"      "printf '%s' \"\$OUT\" | grep -q 'DELETED'"
reset_stage

# 3. Snapshot updated with no test logic change → finding.
mkdir -p "$FIX/__snapshots__"
printf 'snapshot v2\n' > "$FIX/__snapshots__/ui.snap"
git -C "$FIX" add -A
OUT=$(run_lint)
check "detects snapshot-only absorb"   "printf '%s' \"\$OUT\" | grep -q 'snapshot'"
reset_stage

# 4. Clean non-test diff → silent.
printf 'const x = 1;\n' > "$FIX/app.js"
git -C "$FIX" add -A
OUT=$(run_lint)
check "clean diff stays silent"        "[ -z \"\$OUT\" ]"

# 5. precommit-gate carries the lint (wired, both copies in sync).
check "precommit-gate invokes the lint" "grep -q 'test-diff-lint.sh' '$REPO_DIR/hooks/precommit-gate.sh'"
check "codex mirror carries lint + gate wiring" "cmp -s '$REPO_DIR/hooks/precommit-gate.sh' '$REPO_DIR/adapters/codex/plugins/rolepod/hooks/precommit-gate.sh' && cmp -s '$REPO_DIR/hooks/test-diff-lint.sh' '$REPO_DIR/adapters/codex/plugins/rolepod/hooks/test-diff-lint.sh'"

exit $fail
