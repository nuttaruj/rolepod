#!/bin/bash
# Claude PreToolUse(Workflow|Agent) — tier-per-stage at dispatch time:
# a soft nudge for fleets, a mechanical floor for the strong review roles, and
# ONE deny where money measurably leaks (fleet-tier gate, v2.48.0).
#
# The tier rule ("sweep = cheap, build = balanced, verify/judge = strong —
# never inherit the Lead's model across the whole fleet without a stated
# reason") lives in the using-rolepod router skill, which is NOT loaded at
# the moment a Workflow script is authored or an Agent call fires. Observed
# failure: a 10-agent research fleet ran entirely on the Lead's model because
# nothing surfaced the rule at authoring time. This hook re-injects it at
# exactly that moment — now Lead-aware (v2.47.0): the message says what to
# do given the class the Lead is actually running (read from the transcript).
#
# Strong-role floor (v2.47.0, the one non-soft branch): security-engineer and
# universal-reviewer render `model: inherit` on Claude (merge-agent.py — a
# fixed pin would DOWNGRADE a fable-class Lead). On a known-low Lead
# (haiku/sonnet class) that inherit silently runs the adversarial pass at
# the Lead's class — measured: 0 explicit strong overrides across a whole
# project. This hook writes the strong alias into the Agent call itself
# (`updatedInput`, which the platform applies only with
# permissionDecision "allow" — the Agent tool asks no permission of its own,
# so nothing is bypassed). Unknown Lead class → untouched (never a downgrade
# of a model stronger than the alias). Explicit `model:` on the call is the
# Lead's stated choice → never rewritten, only named. system-architect gets
# the nudge, not the rewrite (cohesion-contract-check may deny a parallel
# architect spawn; hook-decision precedence is undocumented).
#
#   Workflow fan-out under a STRONG (or unknown non-empty) Lead, no
#     `// tier-reason:` (or legacy `fleet-inherit:`) comment → DENY when:
#       · zero `model:`/`agentType:` (whole fleet at the Lead's price)  v2.48.0
#       · ≥2 stages (phase()/meta titles/label prefixes) all pinned to
#         the ONE balanced tier — "sonnet pasted everywhere"            v2.50.0
#       · a judgment-shaped stage (verify/judge/review/refute/rank/…)
#         with no strong / role-pin / dynamic tier anywhere — ONLY when
#         the fleet is high-risk-shaped (money/auth/security/migration
#         words in the script); routine work judges at balanced   v2.50.0/v2.51.1
#     Loop valve: the same fleet name denied twice in 30 min → the third
#     submission passes with a nudge (logged action "yield") — bounded cost.
#   Workflow with a per-stage spread (or a stated reason)      → silent
#   Workflow, no `model:`/`agentType:`, low Lead               → nudge (Lead-aware)
#     (`effort:` alone is not a tier choice — nudged, not silenced)
#   Agent strong role, no model, Lead known-low                → allow + updatedInput model=opus
#   Agent strong role, explicit low model                      → nudge (named downgrade)
#   Agent system-architect, no model, Lead known-low           → nudge (pass model:'opus')
#   Agent sweep-type (Explore/general-purpose), no model        → nudge
#     (rolepod:scout is frontmatter-pinned cheap → silent)
#   Agent = the Lead's 3rd sequential dispatch round-trip this turn
#                                                              → coordinator-loop nudge (once)
#   anything else                                              → silent
#
# Fleet-tier gate (v2.48.0): the ONE deny in this hook, scoped to where money
# actually leaks. Ultracode / workflow-heavy users run opus- or fable-class
# Leads, and a Workflow script that sets no per-agent model runs the WHOLE
# fleet at the Lead's price — measured on one project: 6 fleets in one day,
# 5,196 agent turns at opus/fable, ≈ $180 over the sonnet price for the opus
# share alone, with the soft nudge fired and ignored every time. Under a
# low-class Lead the fleet is already cheap → nudge only. Any per-stage
# `model:` or `agentType:` (rolepod writers are pinned balanced) → silent.
# Intentional fleet-wide inherit → write `// fleet-inherit: <reason>` in the
# script and it passes (the reason is the accountability). Bypass envs are
# user-set only: ROLEPOD_GATES_SOFT=1 degrades the deny to the nudge (logged
# to bypass.log), ROLEPOD_NUDGE_OFF=1 silences everything in this hook.
set -uo pipefail
[ "${ROLEPOD_NUDGE_OFF:-0}" = "1" ] && exit 0
INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

SESSION_STATE="$(dirname "$0")/lib/session_state.py"
[ -f "$SESSION_STATE" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

printf '%s' "$INPUT" | ROLEPOD_SESSION_STATE="$SESSION_STATE" python3 -c '
import json, os, re, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
sys.path.insert(0, os.path.dirname(os.environ["ROLEPOD_SESSION_STATE"]))
try:
    import session_state as ss
except Exception:
    sys.exit(0)

tool = d.get("tool_name") or ""
ti = d.get("tool_input") or {}
lead = ss.lead_model(d.get("transcript_path") or "")
cls = ss.model_class(lead)
lead_txt = "%s (%s class)" % (lead or "unknown model", cls)
OFF = " (off: ROLEPOD_NUDGE_OFF=1)"

def emit(out):
    print(json.dumps(out, ensure_ascii=False))
    sys.exit(0)

def ctx(msg):
    emit({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                 "additionalContext": msg}})

def _git_root():
    try:
        import subprocess
        return subprocess.check_output(["git", "rev-parse", "--show-toplevel"],
                                       text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def _log_bypass(hook, var):
    # Same line shape as rolepod_log_bypass() in the bash hooks — a used
    # bypass is recorded, never blocked; fail-open on any error.
    root = _git_root()
    if not root:
        return
    try:
        import datetime
        os.makedirs(os.path.join(root, ".rolepod", "evidence"), exist_ok=True)
        reason = (os.environ.get("ROLEPOD_BYPASS_REASON") or "unreasoned").replace(chr(34), " ")
        with open(os.path.join(root, ".rolepod", "evidence", "bypass.log"), "a") as f:
            f.write("{\"ts\":\"%s\",\"hook\":\"%s\",\"var\":\"%s\",\"reason\":\"%s\"}\n" % (
                datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                hook, var, reason))
    except Exception:
        pass

def _fleet_key(ti, script):
    # Named fleet → its name (a re-submitted, still-wrong script counts as the
    # same fleet); nameless → a hash of the script text (only an unchanged
    # re-submission counts — nothing else can be told apart).
    m = re.search(r"name:\s*[\x27\"]([^\x27\"]+)", script)
    if m:
        return m.group(1)
    if ti.get("name"):
        return ti["name"]
    import hashlib
    return "sha:" + hashlib.sha1(script.encode("utf-8", "ignore")).hexdigest()[:12]

def _recent_denies(ti, script, minutes=30):
    # Loop valve: how many times THIS fleet (by name) was denied in the last
    # `minutes`. Two strikes → the third submission passes with a nudge, so a
    # Lead that cannot satisfy the gate never spins (bounded cost: 2 turns).
    root = _git_root()
    if not root:
        return 0
    try:
        import datetime
        name = _fleet_key(ti, script)
        cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=minutes)
        n = 0
        with open(os.path.join(root, ".rolepod", "evidence", "phase-log.jsonl")) as f:
            for line in f:
                if "dispatch-gate" not in line or name not in line:
                    continue
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                if d.get("phase") != "dispatch-gate" or d.get("name") != name or d.get("action") != "deny":
                    continue
                try:
                    ts = datetime.datetime.fromisoformat(d.get("ts", ""))
                except Exception:
                    continue
                if ts >= cutoff:
                    n += 1
        return n
    except Exception:
        return 0

def _log_gate(ti, script, lead, cls, n_calls, verdict="no-tier", tiers=None, stages=None, action="deny"):
    # A denied fleet never reaches PostToolUse (dispatch-auto-log), so the
    # gate records itself: phase "dispatch-gate" — read by make stats.
    root = _git_root()
    if not root:
        return
    try:
        import datetime
        os.makedirs(os.path.join(root, ".rolepod", "evidence"), exist_ok=True)
        line = {"ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
                "phase": "dispatch-gate", "cli": "claude", "tool": "Workflow",
                "provenance": "hook-gate", "action": action,
                "name": _fleet_key(ti, script),
                "agent_calls": n_calls, "lead_model": lead or "unknown", "lead_class": cls,
                "reason": verdict, "tiers": tiers or [], "stages": stages or []}
        with open(os.path.join(root, ".rolepod", "evidence", "phase-log.jsonl"), "a") as f:
            f.write(json.dumps(line, ensure_ascii=False) + "\n")
    except Exception:
        pass

if tool == "Workflow":
    script = ti.get("script") or ""
    if not script and ti.get("scriptPath"):
        try:
            with open(ti["scriptPath"]) as f:
                script = f.read()
        except OSError:
            script = ""
    if "agent(" not in script:
        sys.exit(0)
    n_effort = len(re.findall(r"[,{\s]effort\s*:", script))
    n_calls = script.count("agent(")
    models = re.findall(r"[,{\s]model\s*:\s*[\x27\"]([A-Za-z0-9._\-\[\]]+)[\x27\"]", script)
    n_model = len(re.findall(r"[,{\s]model\s*:", script))
    n_atype = len(re.findall(r"[,{\s]agentType\s*:", script))
    tiers = set(ss.model_class(m) for m in models)
    if n_atype:
        tiers.add("role-pin")
    if n_model and not models:
        tiers.add("dynamic")   # model: <expr> — a variable, not a literal; trust it
    # Stages: phase() calls / meta.phases titles, else distinct label prefixes.
    stages = set(re.findall(r"phase\(\s*[\x27\"]([^\x27\"]+)", script))
    stages |= set(re.findall(r"title\s*:\s*[\x27\"]([^\x27\"]+)", script))
    if not stages:
        stages = set(re.findall(r"label\s*:\s*[`\x27\"]([A-Za-z_][A-Za-z0-9_-]*)\s*[:\-]", script))
    JUDGE_RX = re.compile(r"(verif|judg|review|refut|skeptic|rank|scor|adversar|critic|synthes)", re.I)
    judge_stages = sorted(x for x in stages if JUDGE_RX.search(x))
    # High-risk-shaped fleet: the script (name, prompts, paths) names a money /
    # auth / security / migration surface. Only such a fleet needs its judge
    # stage at strong class (R4 adversarial floor); routine work (i18n, UI
    # copy, docs) is R2 — a balanced judge is the policy, not a downgrade.
    RISK_RX = re.compile(r"\b(auth|authn|authz|authentication|authorization|billing|payment|payments|"
                         r"refund|refunds|payout|payouts|chargeback|settlement|credit|credits|invoice|"
                         r"invoices|charge|charges|stripe|paypal|wallet|ledger|migration|migrations|"
                         r"secret|secrets|token|tokens|jwt|oauth|sso|saml|crypto|security|permission|"
                         r"permissions|gdpr|pdpa|deletion|erasure|webhook|webhooks)\b", re.I)
    risky = bool(RISK_RX.search(script)) or bool(RISK_RX.search(str(ti.get("name") or "")))
    m_reason = re.search(r"(?:fleet-inherit|tier-reason)\s*:\s*(\S[^\n]{0,160})", script)
    stated = m_reason.group(1).strip() if m_reason else ""
    eff = (" (%d effort: overrides — effort is depth, not tier)" % n_effort) if n_effort else ""
    soft = os.environ.get("ROLEPOD_GATES_SOFT", "0") == "1"
    costly = cls == "strong" or (bool(lead) and cls == "unknown")
    why = ("strong class" if cls == "strong" else "unknown family — treated as strong-class for cost")
    TAIL = (" Bypass envs are user-set only (ROLEPOD_GATES_SOFT=1 degrades this to a warning); an "
            "intentional exception is stated IN the script: `// tier-reason: <why>`.")

    verdict = ""   # "" = pass; else a deny reason key
    reason_txt = ""
    if costly and not stated:
        if not tiers:
            verdict = "no-tier"
            reason_txt = (
                "⛔ rolepod fleet-tier gate: this Workflow fans out %d agent() call(s) with ZERO "
                "model:/agentType: overrides%s while the Lead is %s (%s) — every agent would run "
                "at the Lead\x27s price (measured: one project burned 5,196 agent turns at "
                "opus/fable in a day this way; a 50-agent fleet ≈ 5M tokens). Re-submit the SAME "
                "script with a tier PER STAGE (not one model pasted on every stage): sweep/read → "
                "model:\x27haiku\x27, build/verify → model:\x27sonnet\x27 (or agentType:\x27rolepod:<role>\x27 "
                "— writers are pinned balanced), judge/refute/rank/review → model:\x27sonnet\x27 for routine "
                "work, opus/inherit only when the fleet touches money/auth/security/migrations."
                % (n_calls, eff, lead or "unknown model", why)) + TAIL
        elif tiers == {"balanced"} and len(stages) >= 2:
            verdict = "single-tier"
            reason_txt = (
                "⛔ rolepod fleet-tier gate: %d stage(s) — %s — all pinned to ONE balanced tier "
                "under a %s Lead (%s). Tier PER STAGE means the tiers DIFFER by the work: "
                "sweep/scan/read → model:\x27haiku\x27, build/verify → model:\x27sonnet\x27, "
                "judge/refute/rank/review/synthesis → model:\x27sonnet\x27 for routine work%s. "
                "Measured: this pattern (sonnet pasted on every stage) is how "
                "the last fleets passed this gate without applying the policy. Re-submit with the "
                "tiers spread; every stage genuinely balanced work? state it: "
                "`// tier-reason: <why>`." % (len(stages), ", ".join(sorted(stages))[:200], why, lead or "unknown model",
                                              (", opus/inherit here because this fleet touches money/auth/security/migrations" if risky else ""))) + TAIL
        elif risky and judge_stages and not (tiers & {"strong", "role-pin", "dynamic"}):
            verdict = "no-strong-judge"
            reason_txt = (
                "⛔ rolepod fleet-tier gate: judgment stage(s) %s run at %s under a %s Lead (%s) — "
                "a strong-class Lead pinning its own judge/verify/rank stage BELOW itself is the "
                "silent downgrade the tier policy forbids on a fleet that touches money/auth/security/"
                "migrations (R4 adversarial floor). Give the judgment stage model:\x27opus\x27 or "
                "leave it inherit; keep sweep haiku / build sonnet. Not a judgment stage, or not "
                "high-risk despite the words? state it: `// tier-reason: <why>`." % (
                    ", ".join(judge_stages)[:160], "+".join(sorted(tiers)), why, lead or "unknown model")) + TAIL
    if verdict:
        if soft:
            _log_bypass("workflow-tier-nudge", "ROLEPOD_GATES_SOFT")
        elif _recent_denies(ti, script) >= 2:
            # Loop valve: third strike passes, loudly, and is logged as yielded.
            _log_gate(ti, script, lead, cls, n_calls, verdict, sorted(tiers), sorted(stages), action="yield")
            ctx("⚖ rolepod fleet-tier gate YIELDED after 2 denies of this fleet in 30 min — "
                "proceeding as submitted (%s). The tier spread is still expected: sweep haiku, "
                "build/verify sonnet, judge/rank/review opus or inherit; or state "
                "`// tier-reason: <why>`. This yield is logged for make stats." % verdict)
        else:
            _log_gate(ti, script, lead, cls, n_calls, verdict, sorted(tiers), sorted(stages))
            emit({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason_txt}})
    if tiers:
        sys.exit(0)   # per-stage choice made (or accepted with a reason) — silent
    if cls in ss.LOW_CLASSES:
        ctx("⚖ rolepod tier-check: this Workflow script sets NO per-agent model%s — every "
            "agent() inherits the Lead: %s. Fine for sweep/build stages. Do NOT rely on an "
            "in-script review/judge stage as the strong pass — dispatch rolepod:universal-reviewer "
            "/ rolepod:security-engineer via the Agent tool before commit (the hook runs them at "
            "strong class; the commit gate requires it on high-risk). In-script judge stages: "
            "sonnet for routine work, model:\x27opus\x27 when the fleet touches money/auth/security.%s" % (eff, lead_txt, OFF))
    else:
        note = (" Stated reason accepted: \x27%s\x27." % stated) if stated else ""
        ctx("⚖ rolepod tier-check: this Workflow script sets NO per-agent model%s — every "
            "agent() inherits the Lead: %s — the WHOLE fleet (%d agent() calls) runs at the "
            "Lead\x27s cost.%s Tier per stage: sweep/read = model:\x27haiku\x27, build = "
            "model:\x27sonnet\x27 (or agentType:\x27rolepod:<role>\x27 — writers are pinned "
            "balanced), verify/judge = sonnet for routine work, strong on money/auth/security.%s" % (eff, lead_txt, n_calls, note, OFF))

if tool in ("Agent", "Task"):
    atype_raw = (ti.get("subagent_type") or "general-purpose").split()[0]
    atype = ss._bare_agent_name(atype_raw)
    model = (ti.get("model") or "").split()[0] if ti.get("model") else ""
    # Coordinator-loop check (v2.51.0, from the CCW "Beat Model" comparison):
    # this dispatch would be the Lead\x27s 3rd sequential Agent round-trip in
    # ONE turn — each round-trip re-reads the whole context at the Lead\x27s
    # price. Fires once (exactly at the 3rd), never on parallel fan-out inside
    # one message, never blocks. Merged into the branch output below when a
    # tier note also applies.
    rounds = ss.dispatch_rounds_this_turn(d.get("transcript_path") or "")
    loop_note = ""
    if rounds == 2:
        ctxk = ss.last_context_tokens(d.get("transcript_path") or "") // 1000
        loop_note = ("🔁 rolepod coordinator-check: this is the Lead\x27s 3rd sequential Agent "
                     "round-trip this turn — every dispatch→wait→dispatch re-reads the whole "
                     "context (%s) at the Lead\x27s price. Dependent multi-step fan-out belongs "
                     "in a Workflow script (pipeline / parallel stages run OUTSIDE the Lead; the "
                     "Lead reads one result). Keep the Agent tool for one-off or truly parallel "
                     "single-message dispatches. " % (("~%dk tokens" % ctxk) if ctxk else "all of it"))
    if atype in ss.STRONG_ROLE_AGENTS:
        if not model and cls in ss.LOW_CLASSES:
            new_input = dict(ti)
            new_input["model"] = ss.STRONG_ALIAS
            emit({
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow",
                    "updatedInput": new_input,
                },
                "systemMessage": "rolepod tier-floor: %s → model=%s (Lead is %s; "
                                 "frontmatter inherit would have run the adversarial pass at "
                                 "the Lead\x27s class)" % (atype, ss.STRONG_ALIAS, lead_txt),
            })
        if model and ss.model_class(model) in ss.LOW_CLASSES:
            ctx(loop_note + "⚖ rolepod tier-check: %s dispatched with model=%s — an EXPLICIT downgrade of a "
                "strong review role. The commit gate does not count it as the strong pass on a "
                "high-risk diff. Drop the model field (the hook lifts it) or pass "
                "model:\x27opus\x27.%s" % (atype, model, OFF))
        if loop_note:
            ctx(loop_note.rstrip() + OFF)
        sys.exit(0)
    if atype == "system-architect" and not model and cls in ss.LOW_CLASSES:
        ctx(loop_note + "⚖ rolepod tier-check: system-architect inherits the Lead: %s — a strong-tier "
            "judgment role. Pass model:\x27opus\x27 (or the strongest you have).%s" % (lead_txt, OFF))
    # rolepod:scout is pinned cheap by its frontmatter (verified on disk) — no nudge.
    # Only the platform sweep agents (Explore / general-purpose) truly inherit.
    if not model and re.search(r"(explore|general-purpose)", atype, re.I):
        ctx(loop_note + "⚖ rolepod tier-check: sweep-type agent (%s) dispatched with no model override — it "
            "inherits the Lead: %s. Sweep/read work fits the cheap class: pass model:\x27haiku\x27, "
            "or use rolepod:scout (pinned cheap). Keep inherit only with a stated reason.%s"
            % (atype, lead_txt, OFF))
    if loop_note:
        ctx(loop_note.rstrip() + OFF)
' 2>/dev/null || true
exit 0
