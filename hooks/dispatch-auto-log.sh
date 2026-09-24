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
# nothing; an unknown family logs as "unknown"), and records the OUTCOME of
# the strong-role floor (workflow-tier-nudge.sh) — PostToolUse tool_input
# already carries the lifted model, so `floor: applied|missed` is read, not
# inferred.
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
printf '%s' "$INPUT" | ROLEPOD_SESSION_STATE="$SESSION_STATE" ROLEPOD_EV_DIR="$EV_DIR" python3 -I -c '
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
    # Count keys on the STRING-STRIPPED script — prose containing "model:"
    # inside a prompt literal logged a phantom override. v2.88.0: the strip and
    # the literal reader are ss helpers, so this file and the gate can no longer
    # drift (they used different fillers and read different offsets).
    code = ss.strip_strings(script) if ss is not None else script
    n_model = len(re.findall("[,{\\s]model\\s*:", code))
    n_effort = len(re.findall("[,{\\s]effort\\s*:", code))
    line["model_overrides"] = n_model
    line["effort_overrides"] = n_effort
    line["model"] = "mixed" if n_model else "inherit"
    line["override"] = "per-stage" if n_model else "none"
    # Which tiers the script actually names (v2.48.1) — so stats can tell a
    # real per-stage spread from "one model pasted on every stage".
    if ss is not None:   # values written as CODE only - a prompt naming a model
        models = sorted(set(ss.script_option_values(script, "model", code)))
        atypes = sorted(set(ss.script_option_values(script, "agentType", code)))
    else:
        models, atypes = [], []
    line["models"] = models
    line["agent_types"] = atypes
    mix = sorted(set((ss.model_class(m) if ss is not None else "?") for m in models))
    # role-pin only when the agentType RENDERS a pin (cheap/balanced roles,
    # and strong roles since v2.104.0 — they render opus). Without
    # this a bare fleet carrying one agentType general-purpose logged as
    # tiered (v2.88.0 - same rule as the gate).
    names = set(ss._bare_agent_name(a) for a in atypes) if ss is not None else set()
    if ss is not None and (names & (ss.TIER_PINNED_AGENTS | ss.STRONG_ROLE_AGENTS)):
        mix.append("role-pin")
    line["tier_mix"] = mix
else:
    atype = ti.get("subagent_type") or "general-purpose"
    line["agent_type"] = atype
    line["name"] = ti.get("name") or "?"
    model = ti.get("model") or ""
    is_strong_role = ss is not None and ss._bare_agent_name(atype) in ss.STRONG_ROLE_AGENTS
    # A model-less strong role runs its frontmatter pin (opus, v2.104.0).
    line["model"] = model or ("opus" if is_strong_role else "inherit")
    line["override"] = model or "none"
    if is_strong_role:
        # Strong-role floor outcome. PostToolUse tool_input carries the
        # PreToolUse updatedInput (live-verified 2026-08-17: lifted call
        # logs model=opus here and the subagent transcript shows opus), so
        # what we see IS what ran: strong-class model → applied (hook lift);
        # no model → frontmatter (the opus pin, hook silent or not needed);
        # an explicit low model → missed. Observable in `make stats`.
        line["floor"] = ("applied" if ss.model_class(model) == "strong"
                         else ("frontmatter" if not model else "missed"))
    # F1/F2: a brief that declares write-mode authors tests, not a review —
    # the phase-log backstop (precommit-gate.sh phase_log_reviewer_count)
    # must skip this row the same way count_all already does for the
    # transcript scan, or a test-writing reviewer clears the strong-review
    # gate through the backstop alone.
    if ss is not None and ss.is_write_mode_brief(ti.get("prompt")):
        line["write_mode"] = True

# The log line goes to the file directly. Same shape as before — consumers (stats, precommit-gate
# fallback, integration fixtures) parse this line.
try:
    with open(os.path.join(os.environ.get("ROLEPOD_EV_DIR") or ".", "phase-log.jsonl"), "a") as f:
        f.write(json.dumps(line, ensure_ascii=False) + "\n")
except Exception:
    pass

' 2>/dev/null || true

exit 0
