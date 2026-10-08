#!/bin/bash
# load-lock — no reader's rendered load grows past tests/static/load-lock.baseline
# without an owner note. The measurement is tests/load/measure.sh (rendered payload,
# python len chars); this script does not render, run `make render` first.
#
# Env: LOAD_LOCK_MEASURED=<tsv> replaces the measure.sh run; LOAD_LOCK_BASELINE=<file>
# replaces the baseline (both exist for tests/integration/cases/load-lock.sh).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

BASELINE="${LOAD_LOCK_BASELINE:-tests/static/load-lock.baseline}"
MEASURED_FILE="${LOAD_LOCK_MEASURED:-}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ -n "$MEASURED_FILE" ]; then
  [ -f "$MEASURED_FILE" ] || { echo "load-lock: measured file missing: $MEASURED_FILE"; exit 1; }
  cp "$MEASURED_FILE" "$TMP/measured.tsv"
else
  bash tests/load/measure.sh > "$TMP/measured.tsv" 2> "$TMP/measure.err" \
    || { echo "load-lock: tests/load/measure.sh failed (run make render first):"; sed 's/^/  /' "$TMP/measure.err"; exit 1; }
fi
[ -f "$BASELINE" ] || { echo "load-lock: baseline missing: $BASELINE"; exit 1; }

python3 -I - "$BASELINE" "$TMP/measured.tsv" <<'PY'
import sys

def lines(p):
    with open(p, encoding="utf-8") as f:
        for n, raw in enumerate(f, 1):
            l = raw.rstrip("\n")
            if l.strip() and not l.startswith("#"):
                yield n, l.split("\t")

fails = 0
def fail(msg):
    global fails
    fails += 1
    print("  ✗ " + msg)

def is_int(s):
    return s.isascii() and s.isdigit()

rows, notes, row_line, note_line = {}, {}, {}, {}
n_rows = 0
for n, p in lines(sys.argv[1]):
    if p[0] == "note":
        if len(p) < 4 or len(p) > 5 or not is_int(p[3]):
            fail("malformed line %s:%d" % (sys.argv[1], n))
            continue
        key = (p[1], p[2])
        if key in notes:
            fail("duplicate owner note %s %s (lines %d and %d)" % (key[0], key[1], note_line[key], n))
            continue
        note_line[key] = n
        reason = p[4].strip() if len(p) == 5 else ""
        if not reason:
            fail("owner note without a reason: %s %s (line %d)" % (key[0], key[1], n))
            continue
        notes[key] = (int(p[3]), reason)
    else:
        if len(p) != 3 or not is_int(p[2]):
            fail("malformed line %s:%d" % (sys.argv[1], n))
            continue
        key = (p[0], p[1])
        if key in rows:
            fail("duplicate baseline row %s %s (lines %d and %d)" % (key[0], key[1], row_line[key], n))
            continue
        row_line[key] = n
        rows[key] = int(p[2])
        n_rows += 1
meas = {}
for n, p in lines(sys.argv[2]):
    if len(p) != 3 or not is_int(p[2]):
        fail("malformed line %s:%d" % (sys.argv[2], n))
        continue
    meas[(p[0], p[1])] = int(p[2])
if len(meas) == 0 or len(meas) * 2 < n_rows:
    fail("measured set empty or truncated: %d rows vs %d baseline rows" % (len(meas), n_rows))

def allow(pair):
    return max(rows.get(pair, 0), notes[pair][0] if pair in notes else 0)

base_total, meas_total = {}, {}
for pair in set(rows) | set(notes):
    base_total[pair[0]] = base_total.get(pair[0], 0) + allow(pair)
for (r, _), n in meas.items():
    meas_total[r] = meas_total.get(r, 0) + n

print("load-lock:")
for pair in sorted(meas):
    reader, art = pair
    m = meas[pair]
    row = rows.get(pair)
    note = notes.get(pair)
    if row is not None and m <= row:
        if m < row:
            print("  ✓ %s %s %d -> %d (%d)" % (reader, art, row, m, m - row))
        continue
    if note and m <= note[0]:
        print("  ✓ %s %s growth by owner note: %s" % (reader, art, note[1]))
        continue
    if row is None:
        if meas_total[reader] <= base_total.get(reader, 0):
            print("  ✓ %s %s moved (new pair, %d chars, reader total within baseline)" % (reader, art, m))
            continue
        fail("%s %s grew 0 -> %d (+%d), no owner note" % (reader, art, m, m))
    else:
        fail("%s %s grew %d -> %d (+%d), no owner note" % (reader, art, row, m, m - row))
for reader in sorted(meas_total):
    if meas_total[reader] > base_total.get(reader, 0):
        fail("reader %s total grew %d -> %d (+%d)" % (reader, base_total.get(reader, 0), meas_total[reader], meas_total[reader] - base_total.get(reader, 0)))
for pair in sorted(rows):
    if pair not in meas:
        print("  gone: %s %s" % pair)

print("siblings, forwarded to their repos and not measured here: rolepod-wplab about 2.5M chars / 5 days (2,099-char MCP instructions in every context); rolepod-brain about 2.8M + 0.4M chars / 5 days")
print("load-lock: pass" if fails == 0 else "load-lock: fail (%d)" % fails)
sys.exit(1 if fails else 0)
PY
