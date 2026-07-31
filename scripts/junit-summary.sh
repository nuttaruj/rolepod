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
    suites = [root] if root.tag == "testsuite" else root.iter("testsuite")
    for s in suites:
        total += int(s.get("tests", 0) or 0)
        failures += int(s.get("failures", 0) or 0)
        errors += int(s.get("errors", 0) or 0)
        skipped += int(s.get("skipped", 0) or 0)
    # ET.parse re-walk for failed case names (testcase children carrying
    # <failure> or <error>).
    for case in ET.parse(path).getroot().iter("testcase"):
        if case.find("failure") is not None or case.find("error") is not None:
            cls = case.get("classname", "")
            name = case.get("name", "?")
            failed_names.append(f"{cls}::{name}" if cls else name)

passed = total - failures - errors - skipped
print(f"junit: {total} tests — {passed} passed, {failures} failed, "
      f"{errors} errors, {skipped} skipped")
for n in failed_names:
    print(f"  ✗ {n}")
sys.exit(1 if (failures or errors) else 0)
PY
