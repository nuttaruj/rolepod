#!/bin/bash
# Claude PreToolUse(Workflow|Agent) — soft tier-per-stage nudge at dispatch time.
#
# The tier rule ("sweep = cheap, build = balanced, verify/judge = strong —
# never inherit the Lead's model across the whole fleet without a stated
# reason") lives in the using-rolepod router skill, which is NOT loaded at
# the moment a Workflow script is authored or an Agent call fires. Observed
# failure: a 10-agent research fleet ran entirely on the Lead's model because
# nothing surfaced the rule at authoring time. This hook re-injects it at
# exactly that moment.
#
# Soft by construction: additionalContext only, never blocks — fleet-wide
# inherit WITH a stated reason (e.g. ultracode) is a legitimate choice.
# Class labels only, no model names (rename-proof rule).
#
#   Workflow, has agent() fan-out, zero model:/effort: overrides → nudge
#   Workflow with any per-stage override                         → silent
#   Agent, sweep-type (scout/Explore/general-purpose), no model  → nudge
#   anything else                                                → silent
#
# Opt-out for a session: ROLEPOD_NUDGE_OFF=1
set -uo pipefail

[ "${ROLEPOD_NUDGE_OFF:-0}" = "1" ] && exit 0

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

# One parse pass → "workflow <fanout 0|1> <override-count>" or "agent <type> <model|->".
PARSED=$(printf '%s' "$INPUT" | python3 -c '
import json, re, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tool = d.get("tool_name") or ""
ti = d.get("tool_input") or {}
if tool == "Workflow":
    script = ti.get("script") or ""
    if not script and ti.get("scriptPath"):
        try:
            with open(ti["scriptPath"]) as f:
                script = f.read()
        except OSError:
            script = ""
    fanout = 1 if "agent(" in script else 0
    overrides = len(re.findall("[,{\\s](model|effort)\\s*:", script))
    print("workflow %d %d" % (fanout, overrides))
elif tool in ("Agent", "Task"):
    atype = (ti.get("subagent_type") or "general-purpose").split()[0]
    model = (ti.get("model") or "-").split()[0]
    print("agent %s %s" % (atype, model))
' 2>/dev/null || true)
[ -n "$PARSED" ] || exit 0

set -- $PARSED
KIND="${1:-}"

MSG=""
if [ "$KIND" = "workflow" ] && [ "${2:-0}" = "1" ] && [ "${3:-0}" = "0" ]; then
  MSG="⚖ rolepod tier-check: this Workflow script sets NO per-agent model/effort — every agent() inherits the Lead's model across the whole fleet. Tier per stage: sweep/read = cheap class, build = balanced, verify/judge = strong. Fleet-wide inherit needs a stated reason. (off: ROLEPOD_NUDGE_OFF=1)"
elif [ "$KIND" = "agent" ] && [ "${3:-}" = "-" ] && printf '%s' "${2:-}" | grep -qiE "(scout|explore|general-purpose)"; then
  MSG="⚖ rolepod tier-check: sweep-type agent (${2}) dispatched with no model override — it inherits the Lead's model. Sweep/read work fits the cheap class; keep inherit only with a stated reason. (off: ROLEPOD_NUDGE_OFF=1)"
fi

[ -n "$MSG" ] || exit 0

ROLEPOD_HOOK_MSG="$MSG" python3 -c '
import json, os
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": os.environ.get("ROLEPOD_HOOK_MSG", "")}}))
' 2>/dev/null || echo "{}"
exit 0
