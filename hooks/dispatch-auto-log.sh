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
# v2.64.0 — workflow-round counter (fix-loop-breaker's sibling): the Bash
# loop breaker counts identical failing commands, but a fix-fleet loop
# repeats a WORKFLOW, not a command — real case 2026-08-24: six rounds of
# the same fix workflow (defect count 16→5→3→6, not converging) with every
# hook enabled and no nudge fired; the user had to suggest the cross-family
# consult by hand, and it caught a plan flaw in one call. So: count
# same-name Workflow dispatches per session; at the 3rd and every round
# after, inject additionalContext telling the Lead to consult ONE
# clean-room cross-family CLI before the next round. Advisory only — never
# blocks. Scope limit (stated so a silent gap is not assumed covered): a
# loop that renames its workflow every round evades the counter — accepted;
# the hard-stops prose covers models strong enough to vary their scripts.
#
# Fail-open everywhere: no git root, no JSON, missing fields → exit 0.

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
EV_DIR="$GIT_ROOT/.rolepod/evidence"
mkdir -p "$EV_DIR" 2>/dev/null || exit 0

SESSION_STATE="$(dirname "$0")/lib/session_state.py"
printf '%s' "$INPUT" | ROLEPOD_SESSION_STATE="$SESSION_STATE" ROLEPOD_EV_DIR="$EV_DIR" python3 -c '
import json, os, re, sys, datetime, tempfile
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
    # inside a prompt literal logged a phantom override (see the same strip
    # in workflow-tier-nudge.sh; keep the two in lockstep).
    _STR_RX = re.compile(r"`(?:\\.|[^`\\])*`|\x27(?:\\.|[^\x27\\])*\x27|\"(?:\\.|[^\"\\])*\"", re.S)
    code = _STR_RX.sub(lambda mm: mm.group(0)[0] + mm.group(0)[-1], script)
    n_model = len(re.findall("[,{\\s]model\\s*:", code))
    n_effort = len(re.findall("[,{\\s]effort\\s*:", code))
    line["model_overrides"] = n_model
    line["effort_overrides"] = n_effort
    line["model"] = "mixed" if n_model else "inherit"
    line["override"] = "per-stage" if n_model else "none"
    # Which tiers the script actually names (v2.48.1) — so stats can tell a
    # real per-stage spread from "one model pasted on every stage".
    models = sorted(set(re.findall("model\\s*:\\s*[\x27\"]([A-Za-z0-9._\\-\\[\\]]+)[\x27\"]", script)))
    atypes = sorted(set(re.findall("agentType\\s*:\\s*[\x27\"]([^\x27\"]+)[\x27\"]", script)))
    line["models"] = models
    line["agent_types"] = atypes
    mix = sorted(set((ss.model_class(m) if ss is not None else "?") for m in models))
    if atypes:
        mix.append("role-pin")
    line["tier_mix"] = mix
else:
    atype = ti.get("subagent_type") or "general-purpose"
    line["agent_type"] = atype
    model = ti.get("model") or ""
    line["model"] = model or "inherit"
    line["override"] = model or "none"
    if (ss is not None and ss._bare_agent_name(atype) in ss.STRONG_ROLE_AGENTS
            and cls in ss.LOW_CLASSES):
        # Strong-role floor outcome. PostToolUse tool_input carries the
        # PreToolUse updatedInput (live-verified 2026-08-17: lifted call
        # logs model=opus here and the subagent transcript shows opus), so
        # what we see IS what ran: strong-class model → applied; anything
        # else → missed (first assistant turn of a fresh session — no prior
        # turn to read the Lead from — ROLEPOD_NUDGE_OFF, or an explicit
        # low model). Observable in `make stats`, never inferred.
        line["floor"] = "applied" if ss.model_class(model) == "strong" else "missed"

# The log line goes to the file directly (stdout is reserved for the hook
# JSON below). Same shape as before — consumers (stats, precommit-gate
# fallback, integration fixtures) parse this line.
try:
    with open(os.path.join(os.environ.get("ROLEPOD_EV_DIR") or ".", "phase-log.jsonl"), "a") as f:
        f.write(json.dumps(line, ensure_ascii=False) + "\n")
except Exception:
    pass

# ── workflow-round counter (v2.64.0) ── same-name Workflow dispatched a 3rd
# time this session = the fix-loop signature at fleet scale. Nudge, never block.
if tool != "Workflow":
    sys.exit(0)
name = line.get("name") or "?"
if name == "?":
    sys.exit(0)  # unnamed script — cannot count without false positives
sid = re.sub(r"[^A-Za-z0-9_-]", "", str(d.get("session_id") or ""))[:64]
if not sid:
    sys.exit(0)
state_path = os.path.join(tempfile.gettempdir(), "rolepod-wfrounds-%s.json" % sid)
try:
    with open(state_path) as f:
        state = json.load(f)
    if not isinstance(state, dict):
        state = {}
except Exception:
    state = {}
prev = state.get(name, 0)
n = (prev if isinstance(prev, int) else 0) + 1
state[name] = n
if len(state) > 50:
    for k in list(state)[: len(state) - 50]:
        del state[k]
try:
    with open(state_path, "w") as f:
        json.dump(state, f)
except Exception:
    pass

if n < 3:
    sys.exit(0)

msg = (
    "WORKFLOW ROUNDS: workflow \x27%s\x27 has now been dispatched %d times "
    "this session — the fix-loop signature at fleet scale. Before launching "
    "another round, check convergence: is the defect/failure count strictly "
    "falling round over round? If not, STOP iterating and get ONE clean-room "
    "cross-family opinion FIRST (`rolepod-cross-family --kind consult --brief "
    "<ledger.md>` — first usable different-family CLI, read-only, default "
    "model, ROLEPOD_BRAIN_SILENT=1 clean room, anchored): hand it a short "
    "ledger — what each "
    "round changed, why it failed — and decide rebuild-vs-iterate with both "
    "views before spending another fleet. A loop that plugs holes one round "
    "at a time usually has the wrong mental model of the defect; an outside "
    "family catches that in one call. If a consult already happened this "
    "loop, note its verdict and continue. Advisory only — nothing is blocked."
    % (name, n)
)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": msg,
}}))
' 2>/dev/null || true

exit 0
