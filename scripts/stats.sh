#!/bin/bash
# rolepod stats — read the phase evidence log and answer "is the ceremony
# paying for itself" with numbers from real usage instead of feel.
#
# Data sources (both fail-open, written by the doctrine since v2.12):
#   <git-root>/.rolepod/evidence/phase-log.jsonl
#     {"ts","phase":"route|verify|review|ship", ...}
#   <git-root>/.rolepod/evidence/bypass.log
#     {"ts","hook","var","reason"}
#
# Usage: scripts/stats.sh [repo-root]   (default: current git root)
# Run via `make stats`. Read-only; exit 0 even with no data.
set -uo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
EV="$ROOT/.rolepod/evidence"

python3 - "$EV" <<'PY'
import json
import os
import sys
from collections import Counter

ev = sys.argv[1]
phase_log = os.path.join(ev, "phase-log.jsonl")
bypass_log = os.path.join(ev, "bypass.log")


def read_jsonl(path):
    rows = []
    try:
        with open(path, encoding="utf-8") as f:
            for ln in f:
                ln = ln.strip()
                if not ln:
                    continue
                try:
                    rows.append(json.loads(ln))
                except json.JSONDecodeError:
                    continue
    except OSError:
        pass
    return rows


rows = read_jsonl(phase_log)
bypasses = read_jsonl(bypass_log)

print("── rolepod stats ──")
print(f"  evidence dir: {ev}")

if not rows and not bypasses:
    print("  no data yet — phase-log.jsonl / bypass.log start filling once")
    print("  v2.12+ sessions run in this repo. Nothing to measure is itself")
    print("  a finding: the loop has not closed here.")
    sys.exit(0)

routes = [r for r in rows if r.get("phase") == "route"]
verifies = [r for r in rows if r.get("phase") == "verify"]
reviews = [r for r in rows if r.get("phase") == "review"]
ships = [r for r in rows if r.get("phase") == "ship"]

if routes:
    tiers = Counter(r.get("tier", "?") for r in routes)
    total = sum(tiers.values())
    print(f"\n  Tier distribution ({total} routed):")
    for tier in sorted(tiers):
        n = tiers[tier]
        pct = 100 * n // total
        print(f"    {tier:<4} {n:>4}  {pct:>3}%   {'#' * max(1, pct // 4)}")

if verifies:
    v = Counter(r.get("verdict", "?") for r in verifies)
    total = sum(v.values())
    fails = v.get("fail", 0)
    print(f"\n  Verify verdicts ({total}): pass={v.get('pass', 0)} fail={fails}", end="")
    print(f"  ({100 * fails // total}% fail rate)" if total else "")

if reviews:
    v = Counter(r.get("verdict", "?") for r in reviews)
    print(f"\n  Review verdicts ({sum(v.values())}):")
    for k in sorted(v):
        print(f"    {k}: {v[k]}")

if ships:
    a = Counter(r.get("action", "?") for r in ships)
    print(f"\n  Ship actions ({sum(a.values())}): "
          + ", ".join(f"{k}={a[k]}" for k in sorted(a)))

if bypasses:
    by_var = Counter(b.get("var", "?") for b in bypasses)
    unreasoned = sum(1 for b in bypasses if b.get("reason") == "unreasoned")
    print(f"\n  Bypasses ({len(bypasses)} — every one is a finding, not a workaround):")
    for k in sorted(by_var):
        print(f"    {k}: {by_var[k]}")
    if unreasoned:
        print(f"    ⚠ {unreasoned} unreasoned — set ROLEPOD_BYPASS_REASON when a bypass is truly needed")

print()
PY
