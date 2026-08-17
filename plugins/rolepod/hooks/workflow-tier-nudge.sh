#!/bin/bash
# Claude PreToolUse(Workflow|Agent) — tier-per-stage at dispatch time:
# a soft nudge for fleets, and ONE mechanical floor for the strong review roles.
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
#   Workflow, agent() fan-out, zero `model:` overrides         → nudge (Lead-aware)
#   Workflow with any per-stage `model:`                       → silent
#     (`effort:` alone is not a tier choice — nudged, not silenced)
#   Agent strong role, no model, Lead known-low                → allow + updatedInput model=opus
#   Agent strong role, explicit low model                      → nudge (named downgrade)
#   Agent system-architect, no model, Lead known-low           → nudge (pass model:'opus')
#   Agent sweep-type (scout/Explore/general-purpose), no model → nudge
#   anything else                                              → silent
#
# Opt-out for a session: ROLEPOD_NUDGE_OFF=1 (silences nudges AND the floor —
# user-set only; the commit gate still requires the strong pass on high-risk).
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
    n_effort = len(re.findall(r"[,{\s]effort\s*:", script))
    if n_model:
        sys.exit(0)
    eff = (" (%d effort: overrides — effort is depth, not tier)" % n_effort) if n_effort else ""
    if cls in ss.LOW_CLASSES:
        ctx("⚖ rolepod tier-check: this Workflow script sets NO per-agent model%s — every "
            "agent() inherits the Lead: %s. Fine for sweep/build stages. Do NOT rely on an "
            "in-script review/judge stage as the strong pass — dispatch rolepod:universal-reviewer "
            "/ rolepod:security-engineer via the Agent tool before commit (the hook runs them at "
            "strong class; the commit gate requires it on high-risk). Or pin judge stages: "
            "model:\x27opus\x27.%s" % (eff, lead_txt, OFF))
    else:
        ctx("⚖ rolepod tier-check: this Workflow script sets NO per-agent model%s — every "
            "agent() inherits the Lead: %s — the WHOLE fleet runs at the Lead\x27s cost. Tier per "
            "stage: sweep/read = model:\x27haiku\x27, build = model:\x27sonnet\x27 (or "
            "agentType:\x27rolepod:<role>\x27 — writers are pinned balanced), verify/judge = "
            "keep strong. Fleet-wide inherit needs a stated reason.%s" % (eff, lead_txt, OFF))

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
