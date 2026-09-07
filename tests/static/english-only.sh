#!/bin/bash
# english-only — every tracked file is ASCII/English text: no Thai characters
# (U+0E00-U+0E7F). Mirrors the CI "Thai char scan" step so a Thai regex or
# a Thai test prompt fails `make test-static` before it fails the push
# (v2.98.1 — v2.98.0 shipped one and CI went red).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
echo "english-only:"
if python3 - <<'PY'
import subprocess, sys
tracked = subprocess.check_output(["git", "ls-files"], text=True).splitlines()
bad = []
for path in tracked:
    try:
        with open(path, "r", encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                if any(0x0E00 <= ord(ch) <= 0x0E7F for ch in line):
                    bad.append(f"{path}:{lineno}"); break
    except (IsADirectoryError, FileNotFoundError, UnicodeDecodeError):
        continue
for b in bad: print("  Thai char in", b)
sys.exit(1 if bad else 0)
PY
then echo "  ✓ no Thai characters in tracked files"; else echo "  ✗ Thai characters in tracked files (CI invariant)"; exit 1; fi
