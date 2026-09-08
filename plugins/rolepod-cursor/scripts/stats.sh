#!/bin/bash
# rolepod stats — read the phase evidence log and answer "is the ceremony
# paying for itself" with numbers from real usage instead of feel.
#
# Data sources (all fail-open, written by the doctrine since v2.12):
#   <git-root>/.rolepod/evidence/phase-log.jsonl
#     {"ts","phase":"route|verify|review|ship|dispatch|consult|advise|external-fail", ...}
#     ship rows carry "commit":"<shipped head sha, or none>" (v2.87.0) — the anchor for
#     the 14-day corrective-commit rate read from git history
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

python3 -I - "$EV" <<'PY'
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
# A strong dispatch is either the Lead's class-labeled line (tier=strong) or a
# hook-auto row whose agent_type is a strong-named role (v2.86.0: the manual
# line is written only where the hook cannot see the tier). Mirrors
# session_state.STRONG_REVIEWER_AGENTS.
STRONG_ROLES = {"security-engineer", "universal-reviewer", "code-reviewer"}
def is_strong(d):
    if d.get("tier") == "strong":
        return True
    at = (d.get("agent_type") or "").split(":")[-1]
    return d.get("provenance") == "hook-auto" and at in STRONG_ROLES
if dispatches:
    strong = [d for d in dispatches if is_strong(d)]
    if strong:
        # Since v2.104.0 a strong role renders `model: opus`; only an EXPLICIT
        # cheap/balanced pin on a strong-role row is the silent downgrade.
        LOW_MODELS = ("haiku", "sonnet")
        low_pin = sum(1 for d in strong
                      if any(m in (d.get("override") or "") for m in LOW_MODELS))
        none_ov = [d for d in strong if (d.get("override") or "none") == "none"]
        # a pre-2.104 row logged model=inherit: it ran at the Lead, not opus
        inh_rows = sum(1 for d in none_ov if (d.get("model") or "") == "inherit")
        no_ov = len(none_ov) - inh_rows
        print(f"\n  Strong dispatches ({len(strong)}): "
              f"{len(strong) - len(none_ov)} with explicit override, {no_ov} frontmatter opus, "
              f"{inh_rows} inherit (pre-2.104), {low_pin} pinned low")
        if low_pin:
            print("    ⚠ an explicit cheap/balanced pin on a strong dispatch is the silent downgrade")
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
        frontmatter = sum(1 for d in auto if d.get("floor") == "frontmatter")
        missed = sum(1 for d in auto if d.get("floor") == "missed")
        if applied or frontmatter or missed:
            print(f"    strong-role floor (strong review roles): "
                  f"applied ×{applied}, frontmatter ×{frontmatter}, missed ×{missed}")
            print("      applied = the hook wrote opus (low Lead); frontmatter = the role's own "
                  "opus pin ran (v2.104.0); missed = an explicit low model on a strong role")
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
    if why.get("bare-fanout"):
        print("    ⚠ bare-fanout = a fan-out call with no pin under a strong Lead — every item inherited the Lead price; pin the fan-out sonnet/haiku (v2.107.0)")
    if why.get("strong-spread"):
        print("    ⚠ strong-spread = a strong pin on a FAN-OUT under any Lead (v2.107.0), or on every stage / a non-judge stage under a low Lead — the mirror "
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
    print(f"\n  Verify verdicts ({total}): pass={v.get('pass', 0)} partial={v.get('partial', 0)} fail={fails}", end="")
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
        # Round-2+ reviews carry the tag counts (v2.94.0): IN-FIX = the previous
        # round's fixes broke something (point-patching); REPEAT = a finding
        # still open (fix not landed, or the reviewer saw a partial slice).
        later = [r for r in own if str(r.get("round", "")).isdigit() and int(r["round"]) >= 2]
        if later:
            infix = sum(int(r.get("infix") or 0) for r in later)
            rep = sum(int(r.get("repeat") or 0) for r in later)
            print(f"    round-2+ reviews {len(later)}: IN-FIX {infix} · REPEAT {rep}"
                  + ("  ⚠ IN-FIX > REPEAT + NEW share → fixes are point-patches; zoom out (review-code §5)" if infix and infix >= len(later) else ""))
refused = [r for r in rows if r.get("phase") == "external-refused"]
if refused:
    print(f"\n  Cross-family refusals ({len(refused)}): "
          + ", ".join(f"{k}×{n}" for k, n in Counter(r.get("reason") or "?" for r in refused).items())
          + "  — partial-slice = a `--cached` diff sent while the tree had more; attach `git diff HEAD`")

strong_internal = [d for d in dispatches if d.get("tier") == "strong"]
if externals or xfails or strong_internal:
    print(f"\n  Cross-family (a different CLI than the Lead):")
    if externals:
        by = Counter((r.get("kind") or r.get("phase") or "?", r.get("cli") or "?", r.get("family") or "?") for r in externals)
        for (kind, cli, fam), n in sorted(by.items()):
            print(f"    {kind:<8} {cli:<9} {fam:<10} ×{n}")
    else:
        print("    passes: 0")
    if xfails:
        why = Counter((r.get("cli") or "-", (r.get("reason") or "?").split(":")[0][:40]) for r in xfails)
        print("    failures: " + ", ".join(f"{cli} {n}× ({reason})" for (cli, reason), n in sorted(why.items())))
    ran = Counter((r.get("cli") or "?", r.get("ran")) for r in externals if r.get("ran"))
    if ran:
        print("    ran (model the CLI reported): " + ", ".join(f"{cli}={m} ×{n}" for (cli, m), n in sorted(ran.items())))
    partial = sum(1 for r in externals if r.get("partial"))
    if partial:
        print(f"    partial answers (budget nearly spent): {partial} — raise `timeout=` for that CLI or --detach")
    ext_reviews = sum(1 for r in externals if r.get("phase") == "review")
    if strong_internal or ext_reviews:
        print(f"    strong pass source: external {ext_reviews} vs internal strong dispatch {len(strong_internal)}")
        cfg = None
        for cand in (os.path.join(os.path.dirname(ev.rstrip("/")), "cross-family"),
                     os.path.expanduser("~/.rolepod/cross-family")):
            if os.path.isfile(cand):
                cfg = cand
                break
        enabled = False
        if cfg:
            try:
                names = [w for w in open(cfg).read().lower().split() if not w.startswith("#")]
                enabled = bool(names) and "none" not in names
            except OSError:
                pass
        if strong_internal and not ext_reviews:
            if enabled:
                print("      ⚠ every strong pass ran in the Lead's own CLI although a cross-family pool is "
                      "configured — satellite-first wants `rolepod-cross-family --kind review` first")
            else:
                print("      cross-family is opt-in and not enabled here (no ~/.rolepod/cross-family) — "
                      "`rolepod-cross-family --pool` lists candidates")

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

# Self-test rows: doctor.sh and the integration suite exercise the bypass
# envs on purpose, tagged with the reserved reason `rolepod-selftest`
# (`doctor` = the pre-v2.85.1 tag, kept so old logs read the same). They are
# proof the logger works, not a human bypassing a gate — counted apart so
# the finding line stays a finding.
SELFTEST = ("rolepod-selftest", "doctor")
selftest = [b for b in bypasses if b.get("reason") in SELFTEST]
bypasses = [b for b in bypasses if b.get("reason") not in SELFTEST]
if bypasses:
    by_var = Counter(b.get("var", "?") for b in bypasses)
    unreasoned = sum(1 for b in bypasses if b.get("reason") == "unreasoned")
    print(f"\n  Bypasses ({len(bypasses)} — every one is a finding, not a workaround):")
    for k in sorted(by_var):
        print(f"    {k}: {by_var[k]}")
    if unreasoned:
        print(f"    ⚠ {unreasoned} unreasoned — set ROLEPOD_BYPASS_REASON when a bypass is truly needed")
    if selftest:
        print(f"    (self-test rows excluded: {len(selftest)} — reason rolepod-selftest/doctor)")
elif selftest:
    print(f"\n  Bypasses (0 findings; {len(selftest)} self-test rows excluded — reason rolepod-selftest/doctor)")

print()
PY
