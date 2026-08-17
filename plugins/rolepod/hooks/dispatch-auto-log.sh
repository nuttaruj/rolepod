#!/bin/bash
# Claude PostToolUse(Workflow|Agent) — auto-append the dispatch intent line.
#
# The dispatch-log rule ("Log EVERY dispatch — ad-hoc fan-outs included",
# using-rolepod tier paragraph) relied on the Lead remembering to append the
# line at dispatch time; the model that wrote the rule forgot it on the very
# next fleet it launched. Automation over doctrine: this hook writes the line
# itself, so /rolepod-stats always has intent data even when the Lead forgets.
#
# Records the raw facts: explicit `model:` override vs inherit (a Workflow
# script counts as "mixed" only when it sets model: — `effort:` alone is
# depth, not tier, and is counted separately). v2.47.0 adds the Lead's model
# + FAMILY class as read from the transcript (family word only — haiku /
# sonnet / opus… — never a version, so renames within a family change
# nothing; an unknown family logs as "unknown"), and mirrors the strong-role
# floor applied by workflow-tier-nudge.sh (security-engineer /
# universal-reviewer, no model, known-low Lead → ran at the strong alias) so
# stats never shows "inherit" for a dispatch the hook actually lifted.
# Runtime companion: the "dispatch-proof" transcript/hook layer.
#
# Fail-open everywhere: no git root, no JSON, missing fields → exit 0.

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
EV_DIR="$GIT_ROOT/.rolepod/evidence"
mkdir -p "$EV_DIR" 2>/dev/null || exit 0

SESSION_STATE="$(dirname "$0")/lib/session_state.py"
printf '%s' "$INPUT" | ROLEPOD_SESSION_STATE="$SESSION_STATE" python3 -c '
import json, os, re, sys, datetime
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tool = d.get("tool_name") or ""
if tool not in ("Workflow", "Agent", "Task"):
    sys.exit(0)
ti = d.get("tool_input") or {}
lead = ""
cls = "unknown"
try:
    sys.path.insert(0, os.path.dirname(os.environ.get("ROLEPOD_SESSION_STATE", "")))
    import session_state as ss
    lead = ss.lead_model(d.get("transcript_path") or "")
    cls = ss.model_class(lead)
except Exception:
    ss = None
line = {
    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "phase": "dispatch",
    "cli": "claude",
    "tool": "Agent" if tool == "Task" else tool,
    "provenance": "hook-auto",
    "lead_model": lead or "unknown",
    "lead_class": cls,
}
if tool == "Workflow":
    script = ti.get("script") or ""
    if not script and ti.get("scriptPath"):
        try:
            with open(ti["scriptPath"]) as f:
                script = f.read()
        except OSError:
            script = ""
    m = re.search("name:\\s*[\x27\"]([^\x27\"]+)", script)
    line["name"] = m.group(1) if m else (ti.get("name") or "?")
    n_model = len(re.findall("[,{\\s]model\\s*:", script))
    n_effort = len(re.findall("[,{\\s]effort\\s*:", script))
    line["model_overrides"] = n_model
    line["effort_overrides"] = n_effort
    line["model"] = "mixed" if n_model else "inherit"
    line["override"] = "per-stage" if n_model else "none"
else:
    atype = ti.get("subagent_type") or "general-purpose"
    line["agent_type"] = atype
    model = ti.get("model") or ""
    line["model"] = model or "inherit"
    line["override"] = model or "none"
    if (ss is not None and not model
            and ss._bare_agent_name(atype) in ss.STRONG_ROLE_AGENTS
            and cls in ss.LOW_CLASSES):
        # Mirror of the tier-floor branch in workflow-tier-nudge.sh.
        line["model"] = ss.STRONG_ALIAS
        line["override"] = "auto-upgrade"
print(json.dumps(line, ensure_ascii=False))
' >> "$EV_DIR/phase-log.jsonl" 2>/dev/null || true

exit 0
