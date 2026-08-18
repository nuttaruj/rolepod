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
autopasses, autopass_risky, autopass_unlabeled = [], [], []
try:
    with open(autopass_log, encoding="utf-8") as f:
        for ln in f:
            if "auto-pass" not in ln:
                continue
            autopasses.append(ln.strip())
            # v2.46.0+ lines carry "risk=<path|none>"; older lines lack the
            # field — reported SEPARATELY (a reader once summed both as
            # "all high-risk"): labeled risky vs pre-v2.46 unlabeled.
            if "risk=" not in ln:
                autopass_unlabeled.append(ln.strip())
            elif "risk=none" not in ln:
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
        inh = [d for d in auto if (d.get("model") or "inherit") == "inherit"]
        if inh:
            low = sum(1 for d in inh if d.get("lead_class") in ("cheap", "balanced"))
            print(f"    ⚠ {len(inh)} inherited the Lead's model — tier-per-stage "
                  "wants an explicit per-stage choice or a stated reason")
            if low:
                print(f"      {low} of them under a cheap/balanced Lead — the fleet ran "
                      "low-class; the strong pass must come from an Agent-tool "
                      "reviewer dispatch (hook-lifted) before commit")
        applied = sum(1 for d in auto if d.get("floor") == "applied")
        missed = sum(1 for d in auto if d.get("floor") == "missed")
        if applied or missed:
            print(f"    strong-role floor (low-class Lead dispatching a strong review role): "
                  f"applied ×{applied}, missed ×{missed}")
            if missed:
                print("      ⚠ missed = the review ran at the Lead's class — first dispatch of a "
                      "fresh session (no prior turn to read the Lead from), ROLEPOD_NUDGE_OFF, "
                      "or an explicit low model")
        leads = Counter(d.get("lead_class") or "n/a" for d in auto if d.get("lead_class"))
        if leads:
            print("    Lead class at dispatch: " + ", ".join(
                f"{k}={v}" for k, v in sorted(leads.items())))
        costly = sum(1 for d in inh if d.get("tool") == "Workflow"
                     and d.get("lead_class") in ("strong", "unknown"))
        if costly:
            print(f"    ⚠ {costly} Workflow fleet(s) inherited a strong/unknown-class Lead — the "
                  "whole fleet ran at the Lead's price (pre-v2.48 or `fleet-inherit:` stated)")

gated = [r for r in rows if r.get("phase") == "dispatch-gate"]
if gated:
    denies = [g for g in gated if g.get("action") == "deny"]
    calls = sum(int(g.get("agent_calls") or 0) for g in denies)
    print(f"\n  Fleet-tier gate (v2.48.0): denied ×{len(denies)} — {calls} agent() call(s) "
          "kept off a strong-class Lead's price until the script named a tier per stage")

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
    print(f"    on a HIGH-RISK diff (labeled, v2.46+): {len(autopass_risky)}")
    if autopass_unlabeled:
        print(f"    pre-v2.46 unlabeled (risk unknown, other repos likely — this log"
              f" is machine-global): {len(autopass_unlabeled)}")
    if autopass_risky:
        print("    ⚠ each risky auto-pass = a high-risk commit cleared on windowed"
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
