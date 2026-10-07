#!/bin/bash
# Claude PreToolUse(Workflow) — dispatch-time tier floor for fleets, scoped
# to the two shapes that measurably cost money or block a run:
#
#   bare-fanout: a fan-out agent() call with NO tier at all (no model:, no
#     variable agentType, no agentType naming a role that renders a pin —
#     TIER_PINNED_AGENTS; a platform agentType like
#     general-purpose/Explore renders no pin) under a strong-class or
#     unknown Lead — every item in the fan-out inherits the Lead's price.
#     DENY, never yields.
#   strong-fanout: a fan-out agent() call that passes a strong model (model:
#     opus-class) — the top price × N. On any Lead. No type is strong by name.
#     DENY, never yields; ONE strong call outside the fan-out (the judge) is fine.
#   bare-writer: an agent() call on a writing stage (implement/build/fix/
#     integrate/migrate/refactor/patch/scaffold/write) with no agentType:
#     — its edits are blocked at the first Write, minutes into the run.
#     DENY on any Lead, never yields.
#
# A script with both fan-out shapes under a costly Lead gets ONE deny (verdict
# bare-fanout+strong-fanout) naming both stage lists.
#
# Every other verdict this hook used to carry (the per-stage tier spread
# checks, the judgment-floor checks, the fan-out vs single-call pin checks,
# the loop valve, the low-Lead nudge, the escape-hatch comment, and the
# Agent-tool strong-role floor rewrite / downgrade nudge) is removed
# (hook-layer-lean-2026-09-25, Desired 8) — the router skill (using-rolepod)
# carries the tier-per-stage rule; this hook only stops the two shapes a
# skill reminder cannot catch after the fact.
#
# Every mode denies and logs phase: dispatch-gate (rolepod_gate_action
# bare-fanout / strong-fanout / bare-writer). A plan fleet — every agent() bare
# and each call's prompt naming docs/rolepod/plans/ — is exempt from
# bare-fanout and bare-writer.
set -uo pipefail
_rcfg="${BASH_SOURCE[0]%/*}"; [ "$_rcfg" != "${BASH_SOURCE[0]}" ] || _rcfg=.
INPUT=$(cat 2>/dev/null || true)
 . "$_rcfg/lib/session-mode.sh"
rolepod_session_profile_load "$INPUT" "${ROLEPOD_SESSION_CLI:-unknown}"
[ -n "$INPUT" ] || exit 0
case "$INPUT" in *Workflow*) ;; *) exit 0 ;; esac

SESSION_STATE="$(dirname "$0")/lib/session_state.py"
[ -f "$SESSION_STATE" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

printf '%s' "$INPUT" | ROLEPOD_SESSION_STATE="$SESSION_STATE" RP_ACT_BF="$(rolepod_gate_action bare-fanout)" RP_ACT_SF="$(rolepod_gate_action strong-fanout)" RP_ACT_BW="$(rolepod_gate_action bare-writer)" python3 -I -c '
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
if tool != "Workflow":
    sys.exit(0)
ti = d.get("tool_input") or {}
lead = ss.lead_model(d.get("transcript_path") or "")
cls = ss.model_class(lead)

def _git_root():
    try:
        import subprocess
        return subprocess.check_output(["git", "rev-parse", "--show-toplevel"],
                                       text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def _log_bypass(hook, var):
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
    m = re.search(r"name:\s*[\x27\"]([^\x27\"]+)", script)
    if m:
        return m.group(1)
    if ti.get("name"):
        return ti["name"]
    import hashlib
    return "sha:" + hashlib.sha1(script.encode("utf-8", "ignore")).hexdigest()[:12]

def _log_gate(ti, script, lead, cls, n_calls, verdict, stages=None):
    root = _git_root()
    if not root:
        return
    try:
        import datetime
        os.makedirs(os.path.join(root, ".rolepod", "evidence"), exist_ok=True)
        line = {"ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
                "phase": "dispatch-gate", "cli": "claude", "tool": "Workflow",
                "provenance": "hook-gate", "action": "deny",
                "name": _fleet_key(ti, script),
                "agent_calls": n_calls, "lead_model": lead or "unknown", "lead_class": cls,
                "reason": verdict, "stages": stages or []}
        with open(os.path.join(root, ".rolepod", "evidence", "phase-log.jsonl"), "a") as f:
            f.write(json.dumps(line, ensure_ascii=False) + "\n")
    except Exception:
        pass

script = ti.get("script") or ""
if not script and ti.get("scriptPath"):
    try:
        with open(ti["scriptPath"]) as f:
            script = f.read()
    except OSError:
        script = ""
if "agent(" not in script:
    sys.exit(0)
# Key counts run on the script with STRING CONTENTS stripped: agent() opts
# are code, prompts are string literals (v2.88.0 stripper, shared with the
# other hooks that read a script).
code = ss.strip_strings(script)
n_calls = script.count("agent(")

def _in_fanout(code, pos):
    # Inside an UNCLOSED .map( / .flatMap( / .forEach( / pipeline( / Array.from(
    # call, or an unclosed for/while body, at the point of the agent() call.
    dp = db = 0
    i = pos - 1
    while i >= 0:
        ch = code[i]
        if ch == ")":
            dp += 1
        elif ch == "(":
            if dp == 0:
                if re.search(r"(\.map|\.flatMap|\.forEach|\bpipeline|Array\.from)\s*$", code[max(0, i - 40):i]):
                    return True
            else:
                dp -= 1
        elif ch == "}":
            db += 1
        elif ch == "{":
            if db == 0:
                if re.search(r"\b(for|while)\s*\([^{}]*\)\s*$", code[max(0, i - 200):i]):
                    return True
            else:
                db -= 1
        i -= 1
    return False

WRITE_RX = re.compile(r"(implement|build|fix|integrat|migrat|refactor|patch|scaffold|write)", re.I)
bare_fanout = []    # stage of every fan-out agent() call with no pin at all
strong_fanout = []  # stage of every fan-out agent() call that passes a strong model:
bare_writer = []    # stage of every agent() call with no agentType on a writing stage
call_pos = [m.start() for m in re.finditer(r"\bagent\(", code)]
plan_fleet = bool(call_pos)  # every agent() bare (no model:, no agentType) and tied to docs/rolepod/plans/

def literal_of(key, pos, win):
    # The quoted literal after `key:` in the call window, or None when the key
    # is absent or its value is not a quoted string (a variable).
    m = re.search(r"[,{\s]" + key + r"\s*:\s*[\x27\"]", win)
    if not m:
        return None
    v = re.match(r"[\x27\"]([^\x27\"]+)[\x27\"]", script[pos + m.end() - 1:pos + m.end() + 79])
    return v.group(1) if v else None

def stage_of(pos, win):
    if re.search(r"[,{\s]phase\s*:\s*[\x27\"]", win):
        return literal_of("phase", pos, win) or ""
    prev = re.findall(r"phase\(\s*[\x27\"]([^\x27\"]+)", script[:pos])
    return prev[-1] if prev else ""

def agenttype_of(pos, win):
    # (has_key, literal_value|None) — literal_value is None when the key is
    # present but its value is not a quoted string (a variable: cannot
    # resolve statically, so trusted, same as before v2.88.0).
    if not re.search(r"[,{\s]agentType\s*:", win):
        return False, None
    return True, literal_of("agentType", pos, win)

for i, pos in enumerate(call_pos):
    end = call_pos[i + 1] if i + 1 < len(call_pos) else len(code)
    win = code[pos:end]
    # A Workflow call is tiered by model:, a variable agentType/model (not
    # statically resolvable — trusted), or a literal agentType that RENDERS a
    # tier pin (cheap/balanced roles, strong roles). A platform agentType
    # (general-purpose, Explore, claude, Plan) or another plugin agent
    # renders no pin and silently inherits the Lead price — same rule
    # dispatch-auto-log.sh uses (v2.88.0), restored here (B-spec/B-standards
    # fix round, 2026-09-25): a bare agentType general-purpose fan-out under
    # a strong-class or unknown Lead must still deny.
    model_pinned = bool(re.search(r"[,{\s]model\s*:", win))
    at_has, at_lit = agenttype_of(pos, win)
    if at_has and at_lit is not None:
        at_pinned = ss._bare_agent_name(at_lit) in ss.TIER_PINNED_AGENTS
    else:
        at_pinned = at_has
    pinned = model_pinned or at_pinned
    if model_pinned or at_has or "docs/rolepod/plans/" not in script[pos:end]:
        plan_fleet = False
    stage = stage_of(pos, win)
    fanout = bool(re.search(r"label\s*:\s*`[^`]*\$\{", script[pos:end])) or _in_fanout(code, pos)
    if not re.search(r"[,{\s]agentType\s*:", win) and WRITE_RX.search(stage or ""):
        bare_writer.append(stage)
    if fanout and not pinned:
        bare_fanout.append(stage or "(no phase)")
    if fanout:
        mv = literal_of("model", pos, win)
        strong_model = bool(mv) and ss.model_class(mv) == "strong"
        if strong_model:
            strong_fanout.append(stage or "(no phase)")

if plan_fleet:
    # A plan fleet (every call bare, each prompt names docs/rolepod/plans/) is
    # the plan runner: exempt from bare-fanout and bare-writer (the first product
    # Write of a bare agent is still refused by subagent-write-scope).
    bare_fanout = []
    bare_writer = []
costly = cls == "strong" or (bool(lead) and cls == "unknown")
why = ("strong class" if cls == "strong" else "unknown family, priced as strong")
lead_s = (lead or "unknown model")[:20]

verdict = ""
reason_txt = ""
stages = []
if costly and bare_fanout and strong_fanout:
    verdict = "bare-fanout+strong-fanout"
    stages = bare_fanout + strong_fanout
    # stage lists capped at 60 each + lead name capped at 20 keep the text <= 600 by construction
    reason_txt = (
        "⛔ fleet-tier: bare fan-out stage(s) %s inherit the Lead %s (%s) × N, and stage(s) %s pin a "
        "strong model × N. "
        "Fix: pin every fan-out non-strong — a stage that WRITES → "
        "agentType:\x27rolepod:rolepod-builder\x27; read-only sweep (no Bash/MCP) → \x27rolepod:rolepod-scout\x27, else "
        "model:\x27haiku\x27; per-item verify → model:\x27sonnet\x27, effort:\x27high\x27; ONE strong slot on the "
        "single review call. "
        "Exception: none — pin the fan-out."
        % (", ".join(sorted(set(bare_fanout)))[:60], lead_s, why,
           ", ".join(sorted(set(strong_fanout)))[:60]))
elif costly and bare_fanout:
    verdict = "bare-fanout"
    stages = bare_fanout
    reason_txt = (
        "⛔ fleet-tier: bare fan-out call(s) — stage(s) %s — inherit the Lead %s (%s) × N. "
        "Fix: pin the fan-out — a stage that WRITES → "
        "agentType:\x27rolepod:rolepod-builder\x27; read-only sweep (no Bash/MCP) → "
        "\x27rolepod:rolepod-scout\x27 (~15k vs ~71k context), else model:\x27haiku\x27; per-item "
        "verify → model:\x27sonnet\x27, effort:\x27high\x27; ONE strong slot on the single review call. "
        "Exception: none — pin the fan-out."
        % (", ".join(sorted(set(bare_fanout)))[:120], lead_s, why))
elif strong_fanout:
    verdict = "strong-fanout"
    stages = strong_fanout
    reason_txt = (
        "⛔ fleet-tier: strong model pinned on fan-out stage(s) %s — the top price × N. "
        "Fix: a fan-out runs a non-strong rolepod type (agentType:\x27rolepod:rolepod-builder\x27 etc., which pins its "
        "tier and trims fixed context) or model:\x27haiku\x27 / model:\x27sonnet\x27; keep ONE strong call outside the fan-out "
        "for the judge."
        % ", ".join(sorted(set(strong_fanout)))[:120])
elif bare_writer:
    verdict = "bare-writer"
    stages = bare_writer
    reason_txt = (
        "⛔ write-scope: bare agent() on writing stage(s) %s — a call that edits product files needs "
        "agentType:\x27rolepod:rolepod-builder\x27 (E2E tests → "
        "rolepod-qa). model: alone pins the tier, not the write permission — its edits are blocked at the "
        "first Write. Fix: add agentType to every call that edits files; read-only calls may stay bare. "
        "Exception: a stage that only reads → name it so (Research / Verify)." %", ".join(sorted(set(bare_writer)))[:120])

ACT = {"bare-fanout": os.environ.get("RP_ACT_BF"), "strong-fanout": os.environ.get("RP_ACT_SF"),
       "bare-writer": os.environ.get("RP_ACT_BW")}
# The verdict labels are the gate ids; a combined verdict denies when any of
# its gates denies. The table has no warn form for these three gates.
if verdict and any(ACT.get(v) == "deny" for v in verdict.split("+")):
    _log_gate(ti, script, lead, cls, n_calls, verdict, sorted(set(stages)))
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason_txt}}, ensure_ascii=False))
    sys.exit(0)
sys.exit(0)
' 2>/dev/null || true
exit 0
