#!/bin/bash
# load-lock — proves tests/static/load-lock.sh fails a reader's rendered load that
# grew past tests/static/load-lock.baseline without an owner note, and passes a
# shrink, a noted growth and a split. Fixtures are this file's own temp files.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail=0
T=$'\t'

# run <case-name> -> sets RC and OUT; baseline in $TMP/b, measured in $TMP/m
run() {
  OUT=$(LOAD_LOCK_BASELINE="$TMP/b" LOAD_LOCK_MEASURED="${MEASURED:-$TMP/m}" bash tests/static/load-lock.sh 2>&1)
  RC=$?
}
expect() { # $1 name, $2 want rc, $3 optional stdout regex
  if [ "$RC" -eq "$2" ] && { [ -z "${3:-}" ] || printf '%s\n' "$OUT" | /usr/bin/grep -qE -- "$3"; }; then
    echo "  ✓ $1"
  else
    echo "  ✗ FAIL $1 (rc=$RC want $2, pattern '${3:-}')"; printf '%s\n' "$OUT" | sed 's/^/      /'
    fail=$((fail+1))
  fi
}
rows() { # args: lines with literal \t -> TSV file $1
  local f="$1"; shift
  : > "$f"; for l in "$@"; do printf '%b\n' "$l" >> "$f"; done
}
base() { rows "$TMP/b" "# comment" "" "$@"; }
meas() { rows "$TMP/m" "$@"; }

echo "load-lock:"
unset MEASURED

base "lead\\tA\\t100" "lead\\tB\\t50"
meas "lead\\tA\\t100" "lead\\tB\\t50"
run; expect "1 equal rows pass" 0 'load-lock: pass'

meas "lead\\tA\\t99" "lead\\tB\\t50"
run; expect "2 one row -1 passes with the delta" 0 '100 -> 99 \(-1\)'

meas "lead\\tA\\t101" "lead\\tB\\t50"
run; expect "3 one row +1 without a note fails" 1 'lead A grew 100 -> 101 \(\+1\), no owner note'

base "lead\\tA\\t100" "lead\\tB\\t50" "note\\tlead\\tA\\t101\\tadded the actor rule"
run; expect "4 noted +1 passes with the reason" 0 'growth by owner note: added the actor rule'

base "lead\\tA\\t100" "lead\\tB\\t50" "note\\tlead\\tA\\t101\\t"
run; expect "5 note with an empty reason fails" 1 'owner note without a reason'

base "lead\\tA\\t100" "lead\\tB\\t50"
meas "lead\\tA\\t100" "lead\\tB\\t50" "lead\\tC\\t30"
run; expect "6 new pair raising the reader total fails" 1 'lead C grew'

base "lead\\tA\\t180" "lead\\tB\\t50"
meas "lead\\tA\\t80" "lead\\tB\\t50" "lead\\tC\\t80"
run; expect "7 a split with the reader total down passes as moved" 0 'moved'

MEASURED="$TMP/does-not-exist" run; expect "8 missing measured file fails" 1 'measured file missing'
unset MEASURED

base "lead\\tA\\t100" "lead\\tB\\t50" "lead\\tC\\t10" "lead\\tD\\t10"
: > "$TMP/m"
run; expect "9a empty measured set fails" 1 'measured set empty or truncated: 0 rows vs 4 baseline rows'
meas "lead\\tA\\t100"
run; expect "9b truncated measured set fails" 1 'measured set empty or truncated: 1 rows vs 4 baseline rows'

meas "lead\\tA\\t100" "lead\\tB\\t50" "lead\\tC\\t10" "lead\\tD\\t10"
base "lead\\tA\\t100" "lead\\tB\\t50" "lead\\tC\\t10" "lead\\tD\\t10" "lead\\tA\\t200"
run; expect "10a duplicate baseline row fails naming both lines" 1 'duplicate baseline row lead A .*lines 3 and 7'
base "lead\\tA\\t100" "lead\\tB\\t50" "lead\\tC\\t10" "lead\\tD\\t10" "note\\tlead\\tA\\t120\\tr1" "note\\tlead\\tA\\t130\\tr2"
run; expect "10b duplicate note fails naming both lines" 1 'duplicate owner note lead A .*lines 7 and 8'

base "lead\\tA\\t100" "lead\\tB\\t50" "lead\\tC\\t10" "lead\\tD"
run; expect "11a malformed baseline line fails" 1 'malformed line .*:6'
base "lead\\tA\\t100" "lead\\tB\\t50" "lead\\tC\\t10" "lead\\tD\\t10"
meas "lead\\tA\\t100" "lead\\tB\\t5x" "lead\\tC\\t10" "lead\\tD\\t10"
run; expect "11b non-integer measured chars fails" 1 'malformed line .*:2'
expect "11c malformed still ends with the fail line" 1 'load-lock: fail \('

[ "$fail" -eq 0 ] || exit 1
