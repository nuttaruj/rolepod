#!/bin/bash
# rolepod stats — read the phase evidence log and answer "is the ceremony
# paying for itself" with numbers from real usage instead of feel.
#
# Data sources (all fail-open, written by the doctrine since v2.12):
#   <git-root>/.rolepod/evidence/phase-log.jsonl
#     {"ts","phase":"route|verify|review|ship", ...}
#   <git-root>/.rolepod/evidence/bypass.log
#     {"ts","hook","var","reason"}
#   $HOME/.rolepod/gate-bypass.log            (plain text, machine-global)
#     precommit-gate evidence auto-passes — the single most likely path for
#     a weakly-evidenced high-risk commit; invisible here until v2.46.0
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

# precommit auto-passes (plain-text, machine-global — every rolepod repo on
# this machine appends here; shown so weakly-evidenced high-risk commits are
# observable at all).
autopass_log = os.path.expanduser("~/.rolepod/gate-bypass.log")
autopasses, autopass_risky = [], []
try:
    with open(autopass_log, encoding="utf-8") as f:
        for ln in f:
            if "auto-pass" not in ln:
                continue
            autopasses.append(ln.strip())
            # v2.46.0+ lines carry "risk=<path|none>"; older lines lack the
            # field — count those as risky=unknown, not as safe.
            if "risk=none" not in ln:
                autopass_risky.append(ln.strip())
except OSError:
    pass

print("── rolepod stats ──")
print(f"  evidence dir: {ev}")

if not rows and not bypasses and not autopasses:
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

dispatches = [r for r in rows if r.get("phase") == "dispatch"]
if dispatches:
    strong = [d for d in dispatches if d.get("tier") == "strong"]
    if strong:
        no_ov = sum(1 for d in strong if (d.get("override") or "none") == "none")
        print(f"\n  Strong dispatches ({len(strong)}): "
              f"{len(strong) - no_ov} with explicit override, {no_ov} inherit")
        if no_ov:
            print("    ⚠ inherit on a strong dispatch is the silent downgrade "
                  "unless the Lead itself is strong-class")
    auto = [d for d in dispatches if d.get("provenance") == "hook-auto"]
    if auto:
        combo = Counter(
            (d.get("tool") or "?", d.get("model") or "inherit") for d in auto
        )
        print(f"\n  Dispatch intent — hook-auto ({len(auto)}):")
        for (tool, model), n in sorted(combo.items()):
            print(f"    {tool:<10} {model:<28} ×{n}")
        inh = sum(1 for d in auto if (d.get("model") or "inherit") == "inherit")
        if inh:
            print(f"    ⚠ {inh} inherited the Lead's model — tier-per-stage "
                  "wants an explicit per-stage choice or a stated reason")

proofs = [r for r in rows if r.get("phase") == "dispatch-proof"]
if proofs:
    combo = Counter(
        (p.get("cli", "?"), p.get("model") or "?", p.get("agent_type") or "-")
        for p in proofs
    )
    print(f"\n  Model proof — hook-reported ({len(proofs)}; provenance: hook stdin, "
          "not independently verified):")
    for (cli, model, agent), n in sorted(combo.items()):
        print(f"    {cli:<12} {model:<28} {agent:<20} ×{n}")

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

if autopasses:
    print(f"\n  Precommit auto-passes ({len(autopasses)}, machine-global"
          " ~/.rolepod/gate-bypass.log):")
    print(f"    on a HIGH-RISK diff (or pre-v2.46 unlabeled): {len(autopass_risky)}")
    if autopass_risky:
        print("    ⚠ each risky auto-pass = a high-risk commit cleared on session"
              " evidence — audit the newest ones against actual review dispatches")

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
