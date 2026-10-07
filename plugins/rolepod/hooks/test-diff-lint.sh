#!/bin/bash
# test-diff-lint — warn-only lint of the STAGED diff for test tampering.
#
# Grep-able signals of test tampering (`core/fragments/test-quality.md`) and of an integration test that mocks its dependency (`tdd-flow`). Called by precommit-gate.sh (not registered as an event hook);
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
#   - a literal calendar date added under a test path (expires → false red)
set -uo pipefail

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
DIFF=$(git diff --cached --unified=0 2>/dev/null || true)
[ -n "$DIFF" ] || exit 0

FINDINGS=""

# 1. Focus/skip markers ADDED (lines starting with +).
ADDED_SKIPS=$(printf '%s\n' "$DIFF" | grep -cE '^\+.*(\.only\(|\.skip\(|\bxit\(|\bxdescribe\(|\bxtest\(|@pytest\.mark\.skip|\bit\.todo\()' || true)
[ "${ADDED_SKIPS:-0}" -gt 0 ] && FINDINGS+="test-diff-lint: $ADDED_SKIPS focus/skip marker(s) ADDED (.only/.skip/xit/@pytest.mark.skip). Fix: remove the marker, or state why it stays.
"

# 2. Test cases DELETED.
DELETED_CASES=$(printf '%s\n' "$DIFF" | grep -cE '^-\s*(it\(|test\(|def test_|it\.each|test\.each)' || true)
[ "${DELETED_CASES:-0}" -gt 0 ] && FINDINGS+="test-diff-lint: $DELETED_CASES test case line(s) DELETED. Fix: restore the case, or name the coverage removed and why.
"

# 3. Snapshot files updated while no test logic changed.
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
SNAP_TOUCHED=$(printf '%s\n' "$STAGED" | grep -cE '\.(snap|snapshot)$|__snapshots__/' || true)
TEST_LOGIC_TOUCHED=$(printf '%s\n' "$STAGED" | grep -vE '\.(snap|snapshot)$|__snapshots__/' | grep -cE '(^|/)(test|tests|__tests__|spec|specs|e2e)(/|\.|_)|\.(test|spec)\.' || true)
if [ "${SNAP_TOUCHED:-0}" -gt 0 ] && [ "${TEST_LOGIC_TOUCHED:-0}" -eq 0 ]; then
  FINDINGS+="test-diff-lint: $SNAP_TOUCHED snapshot file(s) updated with NO test logic change. Fix: revert it, or name the output change it records.
"
fi

# 4. DB mocking added under integration/e2e paths.
DB_MOCKS=$(printf '%s\n' "$DIFF" | grep -cE '^\+.*(mock|stub|fake)\w*\s*[(<].*(db|database|repository|prisma|sequelize|knex|pool|connection)' || true)
INTEG_TOUCHED=$(printf '%s\n' "$STAGED" | grep -cE '(^|/)(integration|e2e)(/|\.)' || true)
if [ "${DB_MOCKS:-0}" -gt 0 ] && [ "${INTEG_TOUCHED:-0}" -gt 0 ]; then
  FINDINGS+="test-diff-lint: DB mock/stub added under an integration/e2e path. Fix: run the test against the real dependency.
"
fi

# 5. Literal calendar dates ADDED under a test path. A date written as a
#    future day expires; the test then fails on HEAD for clock reasons and
#    burns a review round proving it is not a regression (`core/fragments/test-quality.md`: dates derive from one frozen now).
TEST_FILES=()
while IFS= read -r f; do
  [ -n "$f" ] && TEST_FILES+=("$f")
done < <(printf '%s\n' "$STAGED" | grep -E '(^|/)(test|tests|__tests__|spec|specs|e2e)(/|\.|_)|\.(test|spec)\.' || true)
if [ "${#TEST_FILES[@]}" -gt 0 ]; then
  LITERAL_DATES=$(git diff --cached --unified=0 -- "${TEST_FILES[@]}" 2>/dev/null | grep -cE "^\+.*[\"'\`]20[2-9][0-9]-[01][0-9]-[0-3][0-9]" || true)
  [ "${LITERAL_DATES:-0}" -gt 0 ] && FINDINGS+="test-diff-lint: $LITERAL_DATES literal calendar date(s) ADDED under a test path. Fix: derive every date from one frozen now (fake timers / injected clock). Exception: a test of date parsing names its date on purpose.
"
fi

if [ -n "$FINDINGS" ]; then
  printf '%s' "$FINDINGS"
fi
exit 0
