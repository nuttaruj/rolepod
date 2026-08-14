#!/bin/bash
# junit-summary — turn JUnit/XUnit XML into machine totals for check-work
# evidence. Nearly every runner emits the format (pytest --junitxml,
# vitest/jest --reporter=junit, go-junit-report, gradle, maven surefire) —
# parsing it replaces "tests look green" prose with counted pass/fail/skip
# and the exact failed test names.
#
# Usage: scripts/junit-summary.sh <report.xml> [more.xml ...]
# Exit 0 = all parsed suites green. Exit 1 = any failure/error present.
set -uo pipefail

if [ $# -eq 0 ]; then
  echo "usage: junit-summary.sh <report.xml> [more.xml ...]" >&2
  exit 2
fi

python3 - "$@" <<'PY'
import sys
import xml.etree.ElementTree as ET

total = failures = errors = skipped = 0
failed_names = []

for path in sys.argv[1:]:
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as e:
        print(f"  ✗ unreadable JUnit XML: {path} ({e})")
        failures += 1
        continue
    # Per-suite DIRECT children only — nested <testsuite> counts roll up
    # into the parent's attributes, so summing every suite's attributes
    # double-counted (outer tests=5 + inner tests=2 reported 7). A
    # testcase belongs to exactly one suite; counting direct children
    # makes double-count impossible. root.iter includes root itself when
    # root is a <testsuite>.
    for s in root.iter("testsuite"):
        cases = s.findall("testcase")
        if cases:
            for case in cases:
                total += 1
                cls = case.get("classname", "")
                name = case.get("name", "?")
                label = f"{cls}::{name}" if cls else name
                if case.find("failure") is not None:
                    failures += 1
                    failed_names.append(label)
                elif case.find("error") is not None:
                    errors += 1
                    failed_names.append(label)
                elif case.find("skipped") is not None:
                    skipped += 1
        elif s.find("testsuite") is None:
            # Leaf suite with attribute-only counts (no <testcase>
            # children) — trust its attributes. Container suites whose
            # counts roll up from children are skipped, never added on
            # top of the cases already counted.
            total += int(s.get("tests", 0) or 0)
            failures += int(s.get("failures", 0) or 0)
            errors += int(s.get("errors", 0) or 0)
            skipped += int(s.get("skipped", 0) or 0)

passed = total - failures - errors - skipped
print(f"junit: {total} tests — {passed} passed, {failures} failed, "
      f"{errors} errors, {skipped} skipped")
for n in failed_names:
    print(f"  ✗ {n}")
sys.exit(1 if (failures or errors) else 0)
PY
