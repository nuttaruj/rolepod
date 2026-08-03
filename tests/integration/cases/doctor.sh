#!/bin/bash
# doctor — the enforcement self-test must itself stay green.
# Runs scripts/doctor.sh end-to-end (syntax sweep, loader banner, the three
# deny-path proofs, bypass logging) and requires a clean exit. This is the
# regression net for "a vendor hook API moved and a deny path silently died".
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1"; fail=1
  fi
}

check "doctor exits 0 (all self-checks pass)" "bash scripts/doctor.sh"

OUT=$(bash scripts/doctor.sh 2>/dev/null || true)
check "doctor proves subagent-commit deny"   "printf '%s' \"\$OUT\" | grep -q '✓ block-subagent-commit denies'"
check "doctor proves precommit deny"         "printf '%s' \"\$OUT\" | grep -q '✓ precommit-gate denies'"
check "doctor proves worktree-guard deny"    "printf '%s' \"\$OUT\" | grep -q '✓ worktree-guard denies'"
check "doctor proves bypass logging"         "printf '%s' \"\$OUT\" | grep -q '✓ precommit-gate bypass was logged'"
check "doctor reports per-CLI tier table"    "printf '%s' \"\$OUT\" | grep -q 'doctrine-only (no hook API)'"
check "doctor runs the tier-mapping check"   "printf '%s' \"\$OUT\" | grep -q 'tier mapping'"
check "doctor lists rot-prone pinned ids"    "printf '%s' \"\$OUT\" | grep -q 'pinned ids rot'"

exit $fail
