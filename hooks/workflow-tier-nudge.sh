#!/bin/bash
# Claude PreToolUse(Workflow) — dispatch-time tier floor for fleets, scoped
# to the two shapes that measurably cost money or block a run:
#
#   bare-fanout: a fan-out agent() call with NO tier at all (no model:,
#     no agentType:) under a strong-class or unknown Lead — every item in
#     the fan-out inherits the Lead's price. DENY, never yields.
#   bare-writer: an agent() call on a writing stage (implement/build/fix/
#     integrate/migrate/refactor/patch/scaffold/write) with no agentType:
#     — its edits are blocked at the first Write, minutes into the run.
#     DENY on any Lead, never yields.
#
# Every other verdict this hook used to carry (the per-stage tier spread
# checks, the judgment-floor checks, the fan-out vs single-call pin checks,
# the loop valve, the low-Lead nudge, the escape-hatch comment, and the
# Agent-tool strong-role floor rewrite / downgrade nudge) is removed
# (hook-layer-lean-2026-09-25, Desired 8) — the router skill (using-rolepod)
# carries the tier-per-stage rule; this hook only stops the two shapes a
# skill reminder cannot catch after the fact.
#
# Deny rows still log phase: dispatch-gate (read by make stats).
# ROLEPOD_GATES_SOFT=1 (user-set) degrades a deny to a nudge, logged to
# bypass.log. ROLEPOD_NUDGE_OFF=1 silences the hook entirely.
set -uo pipefail
[ "${ROLEPOD_NUDGE_OFF:-0}" = "1" ] && exit 0
INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

SESSION_STATE="$(dirname "$0")/lib/session_state.py"
[ -f "$SESSION_STATE" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

printf '%s' "$INPUT" | ROLEPOD_SESSION_STATE="$SESSION_STATE" python3 -I -c '
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

def ctx(msg):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                              "additionalContext": msg}}, ensure_ascii=False))
    sys.exit(0)

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
bare_writer = []    # stage of every agent() call with no agentType on a writing stage
call_pos = [m.start() for m in re.finditer(r"\bagent\(", code)]

def stage_of(pos, win):
    pk = re.search(r"[,{\s]phase\s*:\s*[\x27\"]", win)
    if pk:
        pv = re.match(r"[\x27\"]([^\x27\"]+)[\x27\"]", script[pos + pk.end() - 1:pos + pk.end() + 79])
        return pv.group(1) if pv else ""
    prev = re.findall(r"phase\(\s*[\x27\"]([^\x27\"]+)", script[:pos])
    return prev[-1] if prev else ""

for i, pos in enumerate(call_pos):
    end = call_pos[i + 1] if i + 1 < len(call_pos) else len(code)
    win = code[pos:end]
    pinned = bool(re.search(r"[,{\s]model\s*:", win)) or bool(re.search(r"[,{\s]agentType\s*:", win))
    stage = stage_of(pos, win)
    fanout = bool(re.search(r"label\s*:\s*`[^`]*\$\{", script[pos:end])) or _in_fanout(code, pos)
    if not re.search(r"[,{\s]agentType\s*:", win) and WRITE_RX.search(stage or ""):
        bare_writer.append(stage)
    if fanout and not pinned:
        bare_fanout.append(stage or "(no phase)")

soft = os.environ.get("ROLEPOD_GATES_SOFT", "0") == "1"
costly = cls == "strong" or (bool(lead) and cls == "unknown")
why = ("strong class" if cls == "strong" else "unknown family, priced as strong")

verdict = ""
reason_txt = ""
if costly and bare_fanout:
    verdict = "bare-fanout"
    reason_txt = (
        "⛔ fleet-tier: bare fan-out call(s) — stage(s) %s — inherit the Lead %s (%s) × N. "
        "Fix: pin the fan-out — a stage that WRITES → agentType:\x27rolepod:<role>\x27 (the role pins "
        "its tier); read/browse/sweep → model:\x27haiku\x27 or agentType:\x27rolepod:scout\x27; per-item "
        "verify → model:\x27sonnet\x27, effort:\x27high\x27; ONE strong slot on the single review call. "
        "Exception: none — pin the fan-out; ROLEPOD_GATES_SOFT=1 (user-set) warns."
        % (", ".join(sorted(set(bare_fanout)))[:120], lead or "unknown model", why))
elif bare_writer:
    verdict = "bare-writer"
    reason_txt = (
        "⛔ write-scope: bare agent() on writing stage(s) %s — a call that edits product files needs "
        "agentType:\x27rolepod:<role>\x27 (backend-developer / frontend-developer / devops-sre; E2E tests → "
        "qa-tester). model: alone pins the tier, not the write permission — its edits are blocked at the "
        "first Write. Fix: add agentType to every call that edits files; read-only calls may stay bare. "
        "Exception: a stage that only reads → name it so (Research / Verify); ROLEPOD_GATES_SOFT=1 "
        "(user-set) warns." % ", ".join(sorted(set(bare_writer)))[:120])

if verdict:
    if soft:
        _log_bypass("workflow-tier-nudge", "ROLEPOD_GATES_SOFT")
        ctx(reason_txt)
    else:
        _log_gate(ti, script, lead, cls, n_calls, verdict,
                   sorted(set(bare_fanout)) if verdict == "bare-fanout" else sorted(set(bare_writer)))
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason_txt}}, ensure_ascii=False))
        sys.exit(0)
sys.exit(0)
' 2>/dev/null || true
exit 0
