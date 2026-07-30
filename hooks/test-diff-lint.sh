#!/bin/bash
# test-diff-lint — warn-only lint of the STAGED diff for test tampering.
#
# The machine-checkable half of qa-tester's REJECT list, as grep-able diff
# signals. Called by precommit-gate.sh (not registered as an event hook);
# prints findings to stdout, one per line, and ALWAYS exits 0 — the lint
# informs, the reviewer judges. Over-firing a hard block here would train
# users to bypass gates, which is worse than no gate.
#
# What it can catch (mechanical):
#   - focus/skip added to a test on the way to green (.only / .skip / xit /
#     xdescribe / @pytest.mark.skip / it.todo)
#   - test cases deleted (removed it(/test(/def test_ lines)
#   - snapshot files updated with no test logic change (absorbing a failure)
#   - DB/repository mocking added under an integration/e2e path
#
# What it can NEVER catch (HUMAN-ONLY, stated so a green lint is not read as
# test quality): whether expected values were derived from the spec or
# captured from the code's current output. That judgment belongs to a person
# or a reviewer agent — not to this grep.
set -uo pipefail

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
DIFF=$(git diff --cached --unified=0 2>/dev/null || true)
[ -n "$DIFF" ] || exit 0

FINDINGS=""

# 1. Focus/skip markers ADDED (lines starting with +).
ADDED_SKIPS=$(printf '%s\n' "$DIFF" | grep -cE '^\+.*(\.only\(|\.skip\(|\bxit\(|\bxdescribe\(|\bxtest\(|@pytest\.mark\.skip|\bit\.todo\()' || true)
[ "${ADDED_SKIPS:-0}" -gt 0 ] && FINDINGS+="test-diff-lint: $ADDED_SKIPS focus/skip marker(s) ADDED (.only/.skip/xit/@pytest.mark.skip) — a diff that silences a test on the way to green is a finding until justified.
"

# 2. Test cases DELETED.
DELETED_CASES=$(printf '%s\n' "$DIFF" | grep -cE '^-\s*(it\(|test\(|def test_|it\.each|test\.each)' || true)
[ "${DELETED_CASES:-0}" -gt 0 ] && FINDINGS+="test-diff-lint: $DELETED_CASES test case line(s) DELETED — removed coverage must be named and justified, not slipped into a green diff.
"

# 3. Snapshot files updated while no test logic changed.
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
SNAP_TOUCHED=$(printf '%s\n' "$STAGED" | grep -cE '\.(snap|snapshot)$|__snapshots__/' || true)
TEST_LOGIC_TOUCHED=$(printf '%s\n' "$STAGED" | grep -vE '\.(snap|snapshot)$|__snapshots__/' | grep -cE '(^|/)(test|tests|__tests__|spec|specs|e2e)(/|\.|_)|\.(test|spec)\.' || true)
if [ "${SNAP_TOUCHED:-0}" -gt 0 ] && [ "${TEST_LOGIC_TOUCHED:-0}" -eq 0 ]; then
  FINDINGS+="test-diff-lint: $SNAP_TOUCHED snapshot file(s) updated with NO test logic change — a snapshot refreshed to absorb a failure enshrines the bug.
"
fi

# 4. DB mocking added under integration/e2e paths.
DB_MOCKS=$(printf '%s\n' "$DIFF" | grep -cE '^\+.*(mock|stub|fake)\w*\s*[(<].*(db|database|repository|prisma|sequelize|knex|pool|connection)' || true)
INTEG_TOUCHED=$(printf '%s\n' "$STAGED" | grep -cE '(^|/)(integration|e2e)(/|\.)' || true)
if [ "${DB_MOCKS:-0}" -gt 0 ] && [ "${INTEG_TOUCHED:-0}" -gt 0 ]; then
  FINDINGS+="test-diff-lint: DB mock/stub added under an integration/e2e path — integration tests run against a real dependency (qa-tester REJECT rule).
"
fi

if [ -n "$FINDINGS" ]; then
  printf '%s' "$FINDINGS"
  printf 'test-diff-lint: HUMAN-ONLY (not lintable): were expected values derived from the SPEC, or captured from the code'"'"'s current output? A green lint says nothing about this.\n'
fi
exit 0
