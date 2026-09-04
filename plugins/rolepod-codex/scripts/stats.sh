#!/bin/bash
# rolepod stats — read the phase evidence log and answer "is the ceremony
# paying for itself" with numbers from real usage instead of feel.
#
# Data sources (all fail-open, written by the doctrine since v2.12):
#   <git-root>/.rolepod/evidence/phase-log.jsonl
#     {"ts","phase":"route|verify|review|ship|dispatch|consult|advise|external-fail", ...}
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
        with open(path, encoding="utf-8", errors="replace") as f:
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
# errors="replace": this log is machine-global and append-only, so one bad
# byte from any rolepod version on this machine would otherwise crash every
# reader. A reader that dies on its own evidence file is the opposite of the
# fail-open rule the hooks follow.
autopass_log = os.path.expanduser("~/.rolepod/gate-bypass.log")
autopasses, autopass_risky, autopass_unlabeled = [], [], []
try:
    with open(autopass_log, encoding="utf-8", errors="replace") as f:
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
        wfs = [d for d in auto if d.get("tool") == "Workflow" and "tier_mix" in d]
        if wfs:
            def _label(d):
                mix = d.get("tier_mix") or []
                if not mix:
                    return "inherit"
                if len(mix) == 1 and mix[0] in ("cheap", "balanced", "strong"):
                    return f"single-tier {mix[0]}"
                return "multi-tier " + "+".join(mix)
            spread = Counter(_label(d) for d in wfs)
            print("    Fleet tier spread (Workflow scripts): " + ", ".join(
                f"{k} ×{v}" for k, v in sorted(spread.items())))
            mono = sum(1 for d in wfs if _label(d) == "single-tier balanced")
            if mono and mono == len(wfs):
                print("      ⚠ every fleet pinned ONE tier for every stage — tier-per-stage means "
                      "sweep=cheap, build=balanced, judge=strong; the Lead is passing the gate, "
                      "not applying the policy")
        costly = sum(1 for d in inh if d.get("tool") == "Workflow"
                     and d.get("lead_class") in ("strong", "unknown"))
        if costly:
            print(f"    ⚠ {costly} Workflow fleet(s) inherited a strong/unknown-class Lead — the "
                  "whole fleet ran at the Lead's price (pre-v2.48 or `fleet-inherit:` stated)")

gated = [r for r in rows if r.get("phase") == "dispatch-gate"]
if gated:
    denies = [g for g in gated if g.get("action") == "deny"]
    calls = sum(int(g.get("agent_calls") or 0) for g in denies)
    why = Counter(g.get("reason") or "no-tier" for g in denies)
    print(f"\n  Fleet-tier gate: denied ×{len(denies)} — {calls} agent() call(s) held until the "
          "script named a tier per stage  (" + ", ".join(f"{k} ×{v}" for k, v in sorted(why.items())) + ")")
    yields = [g for g in gated if g.get("action") == "yield"]
    if yields:
        print(f"    ↳ yielded ×{len(yields)} — the loop valve let a fleet through after 2 denies; "
              "those fleets ran without the spread (audit them)")
    if why.get("single-tier") or why.get("no-strong-judge"):
        print("    ⚠ single-tier / no-strong-judge = the Lead pasted one balanced model on every "
              "stage (or ran its judge below itself) to pass the gate — the v2.50.0 rules catch it")
    if why.get("strong-spread"):
        print("    ⚠ strong-spread = a low Lead pinned strong on a fan-out / every stage — the mirror "
              "trap; the fix is ONE strong slot (v2.74.0), this deny never yields")

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

# External (cross-family) passes — written by scripts/cross-family.sh. The
# review line with reviewer:external is what precommit-gate counts as the
# strong pass; consult / advise lines are the debug + plan channels.
externals = [r for r in rows if r.get("reviewer") == "external"]
xfails = [r for r in rows if r.get("phase") == "external-fail"]
if reviews:
    own = [r for r in reviews if r.get("reviewer") != "external"]
    v = Counter(r.get("verdict", "?") for r in own)
    if own:
        print(f"\n  Review verdicts ({sum(v.values())}):")
        for k in sorted(v):
            print(f"    {k}: {v[k]}")

strong_internal = [d for d in dispatches if d.get("tier") == "strong"]
if externals or xfails or strong_internal:
    print(f"\n  Cross-family (different model family than the Lead):")
    if externals:
        by = Counter((r.get("kind") or r.get("phase") or "?", r.get("cli") or "?", r.get("family") or "?") for r in externals)
        for (kind, cli, fam), n in sorted(by.items()):
            print(f"    {kind:<8} {cli:<9} {fam:<10} ×{n}")
    else:
        print("    passes: 0")
    if xfails:
        why = Counter((r.get("cli") or "-", (r.get("reason") or "?").split(":")[0][:40]) for r in xfails)
        print("    failures: " + ", ".join(f"{cli} {n}× ({reason})" for (cli, reason), n in sorted(why.items())))
    ext_reviews = sum(1 for r in externals if r.get("phase") == "review")
    if strong_internal or ext_reviews:
        print(f"    strong pass source: external {ext_reviews} vs internal strong dispatch {len(strong_internal)}")
        if strong_internal and not ext_reviews:
            print("      ⚠ every strong pass ran on the Lead's own family — satellite-first wants the "
                  "cross-family runner first (`rolepod-cross-family --pool` shows what is usable here)")

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
