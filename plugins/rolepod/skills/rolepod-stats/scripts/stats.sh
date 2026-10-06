#!/bin/bash
# rolepod stats — read the phase evidence log and answer "is the ceremony
# paying for itself" with numbers from real usage instead of feel.
#
# Data sources (all fail-open, written by the doctrine since v2.12):
#   <git-root>/.rolepod/evidence/phase-log.jsonl
#     {"ts","phase":"route|verify|review|ship|dispatch|dispatch-proof|consult|critique|external-fail|external-refused", ...}
#     ship rows carry "commit":"<shipped head sha, or none>" (v2.87.0) — the anchor for
#     the 14-day corrective-commit rate read from git history
#   <git-root>/.rolepod/evidence/bypass.log
#     {"ts","hook","var","reason"}
#   $HOME/.rolepod/gate-bypass.log            (plain text, machine-global)
#     precommit-gate evidence auto-passes — the single most likely path for
#     a weakly-evidenced high-risk commit; invisible here until v2.46.0
#   $HOME/.claude/projects/<root with / as ->/*/subagents/**/agent-*.jsonl
#     Claude Code subagent transcripts (v2.108.0): the model each fleet agent
#     actually ran on + its usage — the only place the fan-out price is visible
#
# Usage: scripts/stats.sh [repo-root]   (default: current git root)
# Run via `make stats`. Read-only; exit 0 even with no data.
set -uo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
EV="$ROOT/.rolepod/evidence"

python3 -I - "$EV" "$ROOT" <<'PY'
import json
import os
import sys
from collections import Counter

ev = sys.argv[1]
root = sys.argv[2] if len(sys.argv) > 2 else ""
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
STRONG_ROLES = {"security-engineer"}
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
        # no model on the call: a rolepod role still runs its frontmatter model
        # (measured 2026-09-17: 0 fable subagents under a fable Lead); only a
        # generic agent type truly inherits the Lead's model
        ROLEPOD_ROLES = {"adversarial-reviewer", "ai-ml-engineer", "backend-developer", "billing-engineer", "content-strategist",
                         "devops-sre", "frontend-developer", "mobile-developer",
                         "performance-engineer", "qa-tester", "scout", "security-engineer",
                         "system-architect", "ui-ux-designer", "universal-reviewer"}
        def generic(d):   # anything that is not a shipped role has no frontmatter model
            return (d.get("agent_type") or "").rsplit(":", 1)[-1] not in ROLEPOD_ROLES
        role_pinned = sum(1 for d in inh if not generic(d))
        if role_pinned:
            print(f"    · {role_pinned} with no model on the call ran the role's frontmatter model (see Model proof)")
        inh = [d for d in inh if generic(d)]
        if inh:
            low = sum(1 for d in inh if d.get("lead_class") in ("cheap", "balanced"))
            print(f"    ⚠ {len(inh)} generic dispatch(es) inherited the Lead's model — tier-per-stage "
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

# Task-owner dispatch bursts (v2.146.0) — writer-role hook-auto dispatches
# grouped by time gap (≤ 90 s apart = one burst). Reviewer / scout / generic
# rows are not tasks. Dispatch times only — no end time is logged — so a burst
# shows tasks dispatched together, never proof that they ran concurrently.
NON_TASK_ROLES = {"qa-tester", "security-engineer", "universal-reviewer", "adversarial-reviewer", "code-reviewer",
                  "scout", "general-purpose", "default", "claude", "workflow-subagent", ""}
def _task_role(d):
    at = (d.get("agent_type") or "").strip().rsplit(":", 1)[-1]
    return at[len("rolepod-"):] if at.startswith("rolepod-") else at
def _epoch(d):
    import datetime as _dt
    try:
        return _dt.datetime.fromisoformat((d.get("ts") or "").replace("Z", "+00:00")).timestamp()
    except Exception:
        return None
task_rows = [(_epoch(d), _task_role(d)) for d in dispatches
             if d.get("provenance") == "hook-auto" and _task_role(d) not in NON_TASK_ROLES]
task_rows = sorted(t for t in task_rows if t[0] is not None)
if task_rows:
    bursts = []
    for t, r in task_rows:
        if bursts and t - bursts[-1][-1][0] <= 90:
            bursts[-1].append((t, r))
        else:
            bursts.append([(t, r)])
    widths = [len(b) for b in bursts]
    partnered = sum(w for w in widths if w >= 2)
    pct = partnered * 100 // len(task_rows)
    print(f"\n  Task-owner dispatch bursts ({len(task_rows)} task dispatches, {len(bursts)} bursts; ≤ 90 s apart = one burst — dispatch time only, not proof of concurrent runs):")
    print(f"    widths: {', '.join(str(w) for w in widths)} · dispatched within 90 s of another: {partnered}/{len(task_rows)} ({pct}%)"
          + ("  — every burst width 1: no two task dispatches within 90 s" if max(widths) == 1 else ""))

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
    prov = Counter(p.get("provenance") or "hook-stdin" for p in proofs)
    prov_s = ", ".join(f"{k} ×{n}" for k, n in sorted(prov.items()))
    gloss = "hook-stdin = the CLI's own report, not independently verified"
    if prov.get("cross-family"):
        gloss += "; cross-family = older rows only (legacy external implementer), model = the member CLI's own banner ('default' when it prints none)"
    print(f"\n  Model proof — as recorded ({len(proofs)}; provenance: {prov_s} — {gloss}):")
    for (cli, model, agent), n in sorted(combo.items()):
        print(f"    {cli:<12} {model:<28} {agent:<20} ×{n}")

if verifies:
    v = Counter(r.get("verdict", "?") for r in verifies)
    total = sum(v.values())
    fails = v.get("fail", 0)
    print(f"\n  Verify verdicts ({total}): pass={v.get('pass', 0)} partial={v.get('partial', 0)} fail={fails}", end="")
    print(f"  ({100 * fails // total}% fail rate)" if total else "")

# External (cross-family) passes — written by scripts/cross-family.sh. The
# review line with reviewer:external records an external pass (the commit
# gate never counts it, C4); consult lines are the debug channel.
externals = [r for r in rows if r.get("reviewer") == "external"]
xfails = [r for r in rows if r.get("phase") == "external-fail"]
if reviews:
    own = [r for r in reviews if r.get("reviewer") != "external"]
    v = Counter(r.get("verdict", "?") for r in own)
    if own:
        print(f"\n  Review verdicts ({sum(v.values())}):")
        for k in sorted(v):
            print(f"    {k}: {v[k]}")
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
        if ext_reviews:
            review_rows = [r for r in externals if r.get("phase") == "review"]
            adv = sum(1 for r in review_rows if r.get("mode") == "adversarial")
            std = ext_reviews - adv
            print(f"    external review mode: adversarial {adv} · standard {std}")

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

# Fleet token footprint (v2.108.0) — what each Workflow / Agent fleet ran
# on, in output + cache-read tokens per model cell (input + cache-write in one
# total line; no prices — not a cost). Usage counts once per API call (message.id).
# Source: Claude Code subagent transcripts under ~/.claude/projects/<key>/
# <session>/subagents/{workflows/<wf>/,}agent-*.jsonl; <key> = repo root with
# "/" replaced by "-". Read-only. Measured need (CourtBook readiness audit):
# 57 subagents with a model = 44 opus + 13 fable + 0 sonnet — visible nowhere in the
# phase-log, which only records the script's declared tiers.
import glob, time
def _cls(m):
    m = (m or "").lower()
    if "haiku" in m: return "cheap"
    if "sonnet" in m: return "balanced"
    if any(k in m for k in ("opus", "fable", "mythos")): return "strong"
    return "unknown"
def _short(m):
    m = (m or "?")
    for k in ("haiku", "sonnet", "opus", "fable", "mythos"):
        if k in m.lower(): return k
    return m[:12]
fleets = {}
bases, cutoff = [], time.time() - 14 * 86400
if root:
    # the harness keys the project dir by the cwd it saw — try the literal and the resolved path
    bases = [os.path.join(os.environ.get("HOME", ""), ".claude", "projects", p.replace("/", "-"))
             for p in {os.path.abspath(root), os.path.realpath(root)}]
    files = []
    for base in bases:
        files += glob.glob(os.path.join(base, "*", "subagents", "**", "agent-*.jsonl"), recursive=True)
    for f in sorted(set(files)):
        try:
            if os.path.getmtime(f) < cutoff: continue
        except OSError:
            continue
        parts = f.split(os.sep)
        # the path relative to <session>/subagents/, so a `workflows` dir above the session never counts;
        # workflows/<wf>/... at any depth (a workflow agent may spawn its own subagents/)
        si = parts.index("subagents") if "subagents" in parts else -1
        rel = parts[si + 1:] if si >= 0 else parts
        sess = parts[si - 1] if si >= 0 else ""
        # one agent-tool bucket per session, so a fleet's ultracode tag reads its own session's turns
        grp = rel[1] if len(rel) > 2 and rel[0] == "workflows" else "agent-tool:" + sess[:8]
        calls, first, eff = {}, None, "-"    # one API call is written as several rows (thinking/text/tool_use) sharing message.id and usage — keep the row with the highest output_tokens per id
        try:
            with open(f, encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    if '"type":"assistant"' not in line and '"type": "assistant"' not in line: continue
                    try: e = json.loads(line)
                    except Exception: continue
                    msg = e.get("message") or {}
                    m = msg.get("model")
                    if not m or m.startswith("<"):   # "<synthetic>" = harness placeholder, not a model
                        continue
                    u = msg.get("usage") or {}
                    o = u.get("output_tokens", 0) or 0
                    key = msg.get("id") or ("row", len(calls))    # no id → its own call
                    if key not in calls or o >= calls[key][1]:
                        calls[key] = (m, o, u.get("cache_read_input_tokens", 0) or 0,
                                      u.get("input_tokens", 0) or 0, u.get("cache_creation_input_tokens", 0) or 0)
                    first = first or e.get("timestamp")
                    if e.get("effort"): eff = str(e.get("effort"))
        except OSError:
            continue
        per = {}     # per model: [out, cache-read, input, cache-write] — a file may switch model mid-way (retry / fallback)
        for m, o, cr, i, cw in calls.values():
            p = per.setdefault(m, [0, 0, 0, 0])
            p[0] += o; p[1] += cr; p[2] += i; p[3] += cw
        if not per: continue
        g = fleets.setdefault(grp, {"first": first or "", "models": {}, "files": 0, "sess": sess, "effort": Counter()})
        g["files"] += 1
        g["effort"][eff] += 1
        if first and (not g["first"] or first < g["first"]): g["first"] = first
        for m, (out, cache, inp, cw) in per.items():   # an agent counts under every model it ran on
            mm = g["models"].setdefault(m, [0, 0, 0, 0, 0]); mm[0] += 1; mm[1] += out; mm[2] += cache; mm[3] += inp; mm[4] += cw
# ultracode turns — main-session rows {"type":"attachment","attachment":{"type":"workflow_keyword_request"}}
# (one per turn whose prompt carried the keyword). A marker opens a keyword turn at its timestamp; the turn ends at the next
# typed user prompt of the main session. A fleet is tagged when it started inside a keyword turn of its session.
# ultracode as a SESSION setting (/effort ultracode) writes no keyword row: one main-session row
# {"type":"attachment","attachment":{"type":"ultra_effort_enter"}} opens a window at its timestamp, the next
# ultra_effort_exit closes it, no exit = open to the end of the session. The row `effort` (xhigh) cannot tell it apart.
marks, wins = {}, {}
def _typed_prompt(e):
    if e.get("type") != "user" or not e.get("promptId") or e.get("isMeta"): return False
    c = (e.get("message") or {}).get("content")
    return not (isinstance(c, list) and any(isinstance(b, dict) and b.get("type") == "tool_result" for b in c))
if root:
    for base in bases:
        for f in glob.glob(os.path.join(base, "*.jsonl")):
            try:
                if os.path.getmtime(f) < cutoff: continue
                turns, opened, sw = [], None, []
                with open(f, encoding="utf-8", errors="ignore") as fh:
                    for line in fh:
                        # a prompt row only matters while a keyword turn is open
                        if "workflow_keyword_request" not in line and "ultra_effort_" not in line and (opened is None or '"promptId"' not in line): continue
                        try: e = json.loads(line)
                        except Exception: continue
                        at = (e.get("attachment") or {}).get("type") if e.get("type") == "attachment" else None
                        if at in ("ultra_effort_enter", "ultra_effort_exit") and not e.get("timestamp"): continue   # no time, no window edge
                        if at == "ultra_effort_enter":
                            if not sw or sw[-1][1] is not None: sw.append([e["timestamp"], None])
                        elif at == "ultra_effort_exit":
                            if sw and sw[-1][1] is None: sw[-1][1] = e["timestamp"]
                        elif at == "workflow_keyword_request":
                            if opened is None:    # a second marker inside the same turn is not a new turn
                                opened = e.get("timestamp") or ""
                                turns.append([opened, None])
                        elif opened is not None and _typed_prompt(e):
                            for t in turns:
                                if t[1] is None: t[1] = e.get("timestamp") or ""
                            opened = None
                if turns: marks[os.path.basename(f)[:-6]] = turns
                if sw: wins[os.path.basename(f)[:-6]] = sw
            except OSError:
                continue
if marks or wins:
    print(f"\n  ultracode turns: {sum(len(v) for v in marks.values())} · ultracode sessions: {len(wins)} (last 14d; rows type=attachment attachment.type=workflow_keyword_request / ultra_effort_enter..ultra_effort_exit)")
def _ultra(g):
    return bool(g["first"]) and any(a <= g["first"] and (b is None or g["first"] < b)
                                    for a, b in marks.get(g.get("sess"), []) + wins.get(g.get("sess"), []))
if fleets:
    n_agents = sum(g["files"] for g in fleets.values())
    print(f"\n  Fleet token footprint — subagent transcripts (last 14d, {len(fleets)} fleet(s), {n_agents} agents; output + cache-read tokens only — not total tokens, not billed cost):")
    def _k(x):
        if x <= 0: return "0"
        k = int(x / 1e3 + 0.5)                       # half-up, and 999,999 rolls to 1M
        return f"{int(x / 1e6 + 0.5)}M" if k >= 1000 else f"{k}k"
    for grp, g in sorted(fleets.items(), key=lambda kv: kv[1]["first"], reverse=True)[:8]:
        cells = " · ".join(f"{_short(m)} {v[0]} (out {_k(v[1])}, cache-read {_k(v[2])})" for m, v in sorted(g["models"].items(), key=lambda kv: -kv[1][0]))
        eff = " ".join(f"{k}×{n}" for k, n in sorted(g["effort"].items()))
        print(f"    {grp[:16]:16} {(g['first'] or '')[5:16].replace('T', ' '):11}  {cells}  · effort {eff}" + ("  [ultracode]" if _ultra(g) else ""))
    tot = Counter()
    for g in fleets.values():
        for m, v in g["models"].items(): tot[_short(m)] += v[0]
    print("    total: " + " · ".join(f"{m} {n}" for m, n in tot.most_common()))
    t_in = t_cw = 0
    for g in fleets.values():
        for v in g["models"].values(): t_in += v[3]; t_cw += v[4]
    print(f"    input + cache-write (per API call, deduped by message.id): input {_k(t_in)} · cache-write {_k(t_cw)}")
    ug = [g for g in fleets.values() if _ultra(g)]
    if ug:
        print(f"    ultracode fleets: {len(ug)} of {len(fleets)} (keyword turn or ultracode session) — {sum(g['files'] for g in ug)} agents")
    strong = sum(v[0] for g in fleets.values() for m, v in g["models"].items() if _cls(m) == "strong")
    low = sum(v[0] for g in fleets.values() for m, v in g["models"].items() if _cls(m) in ("cheap", "balanced"))
    if n_agents >= 5 and strong > low:
        print("    ⚠ strong-class agents outnumber cheap/balanced ones — fan-outs ran at the Lead price; the tier follows the work: "
              "read/browse haiku or scout, per-item verify sonnet, ONE opus judge (the fleet-tier gate denies new ones)")

print()
PY
