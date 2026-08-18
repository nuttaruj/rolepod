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
#   Workflow, agent() fan-out, zero `model:`/`agentType:`, Lead STRONG (or
#     unknown non-empty family) and no `fleet-inherit: <reason>` in the script
#                                                              → DENY (fleet-tier gate, v2.48.0)
#   Workflow, agent() fan-out, zero `model:`/`agentType:`, otherwise
#                                                              → nudge (Lead-aware)
#   Workflow with any per-stage `model:` / `agentType:`        → silent
#     (`effort:` alone is not a tier choice — nudged, not silenced)
#   Agent strong role, no model, Lead known-low                → allow + updatedInput model=opus
#   Agent strong role, explicit low model                      → nudge (named downgrade)
#   Agent system-architect, no model, Lead known-low           → nudge (pass model:'opus')
#   Agent sweep-type (scout/Explore/general-purpose), no model → nudge
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

def _log_gate(ti, script, lead, cls, n_calls):
    # A denied fleet never reaches PostToolUse (dispatch-auto-log), so the
    # gate records itself: phase "dispatch-gate" — read by make stats.
    root = _git_root()
    if not root:
        return
    try:
        import datetime
        os.makedirs(os.path.join(root, ".rolepod", "evidence"), exist_ok=True)
        m = re.search(r"name:\s*[\x27\"]([^\x27\"]+)", script)
        line = {"ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
                "phase": "dispatch-gate", "cli": "claude", "tool": "Workflow",
                "provenance": "hook-gate", "action": "deny",
                "name": m.group(1) if m else (ti.get("name") or "?"),
                "agent_calls": n_calls, "lead_model": lead or "unknown", "lead_class": cls}
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
    n_model = len(re.findall(r"[,{\s]model\s*:", script))
    n_atype = len(re.findall(r"[,{\s]agentType\s*:", script))
    n_effort = len(re.findall(r"[,{\s]effort\s*:", script))
    if n_model or n_atype:
        sys.exit(0)
    n_calls = script.count("agent(")
    m_reason = re.search(r"fleet-inherit\s*:\s*(\S[^\n]{0,160})", script)
    stated = m_reason.group(1).strip() if m_reason else ""
    eff = (" (%d effort: overrides — effort is depth, not tier)" % n_effort) if n_effort else ""
    soft = os.environ.get("ROLEPOD_GATES_SOFT", "0") == "1"
    costly = cls == "strong" or (bool(lead) and cls == "unknown")
    if costly and not stated:
        why = ("strong class" if cls == "strong"
               else "unknown family — treated as strong-class for cost")
        if soft:
            _log_bypass("workflow-tier-nudge", "ROLEPOD_GATES_SOFT")
        else:
            _log_gate(ti, script, lead, cls, n_calls)
            emit({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason":
                    "⛔ rolepod fleet-tier gate: this Workflow fans out %d agent() call(s) with ZERO "
                    "model:/agentType: overrides%s while the Lead is %s (%s) — every agent would run "
                    "at the Lead\x27s price (measured: one project burned 5,196 agent turns at "
                    "opus/fable in a day this way; a 50-agent fleet ≈ 5M tokens). Re-submit the SAME "
                    "script with a tier PER STAGE (not one model pasted on every stage): sweep/read → model:\x27haiku\x27, build/verify → "
                    "model:\x27sonnet\x27 (or agentType:\x27rolepod:<role>\x27 — writers are pinned "
                    "balanced), judge/adversarial → keep inherit or model:\x27opus\x27. Fleet-wide "
                    "inherit intended? Put a comment `// fleet-inherit: <reason>` in the script and it "
                    "passes. Bypass envs are user-set only (ROLEPOD_GATES_SOFT=1 degrades this to a "
                    "warning)." % (n_calls, eff, lead or "unknown model", why)}})
    if cls in ss.LOW_CLASSES:
        ctx("⚖ rolepod tier-check: this Workflow script sets NO per-agent model%s — every "
            "agent() inherits the Lead: %s. Fine for sweep/build stages. Do NOT rely on an "
            "in-script review/judge stage as the strong pass — dispatch rolepod:universal-reviewer "
            "/ rolepod:security-engineer via the Agent tool before commit (the hook runs them at "
            "strong class; the commit gate requires it on high-risk). Or pin judge stages: "
            "model:\x27opus\x27.%s" % (eff, lead_txt, OFF))
    else:
        note = (" Stated reason accepted: \x27%s\x27." % stated) if stated else ""
        ctx("⚖ rolepod tier-check: this Workflow script sets NO per-agent model%s — every "
            "agent() inherits the Lead: %s — the WHOLE fleet (%d agent() calls) runs at the "
            "Lead\x27s cost.%s Tier per stage: sweep/read = model:\x27haiku\x27, build = "
            "model:\x27sonnet\x27 (or agentType:\x27rolepod:<role>\x27 — writers are pinned "
            "balanced), verify/judge = keep strong.%s" % (eff, lead_txt, n_calls, note, OFF))

if tool in ("Agent", "Task"):
    atype_raw = (ti.get("subagent_type") or "general-purpose").split()[0]
    atype = ss._bare_agent_name(atype_raw)
    model = (ti.get("model") or "").split()[0] if ti.get("model") else ""
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
            ctx("⚖ rolepod tier-check: %s dispatched with model=%s — an EXPLICIT downgrade of a "
                "strong review role. The commit gate does not count it as the strong pass on a "
                "high-risk diff. Drop the model field (the hook lifts it) or pass "
                "model:\x27opus\x27.%s" % (atype, model, OFF))
        sys.exit(0)
    if atype == "system-architect" and not model and cls in ss.LOW_CLASSES:
        ctx("⚖ rolepod tier-check: system-architect inherits the Lead: %s — a strong-tier "
            "judgment role. Pass model:\x27opus\x27 (or the strongest you have).%s" % (lead_txt, OFF))
    if not model and re.search(r"(scout|explore|general-purpose)", atype, re.I):
        ctx("⚖ rolepod tier-check: sweep-type agent (%s) dispatched with no model override — it "
            "inherits the Lead: %s. Sweep/read work fits the cheap class (model:\x27haiku\x27); "
            "keep inherit only with a stated reason.%s" % (atype, lead_txt, OFF))
' 2>/dev/null || true
exit 0
