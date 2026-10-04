#!/bin/bash
# fix-loop-breaker — PostToolUse(Bash): mechanical counter for fix→fail loops.
#
# Compensates (recorded per decay-cadence practice): Leads below sonnet-class
# instruction-following cannot self-count failed attempts — every retry feels
# like a fresh attempt. Real case 2026-08-21: a Codex terra Lead looped a
# failing fix for many rounds with all hooks enabled; the prose stops
# (AGENTS.md hard-stop line + debug-issue Iron Rule #5) sat in context and
# were ignored. Prose asks the model to count; this hook counts for it and
# injects the STOP text at the exact moment the loop is about to take its
# next lap. Strong Leads (sonnet+) already obey the prose — for them the
# nudge is redundant and rarely fires.
#
# Mechanics: fingerprint = sha1 of the whitespace-normalized command. A
# non-zero exit increments that fingerprint's consecutive-fail count; a clean
# run resets it. At two failures, remind the Lead to consult once after two
# actual failed fixes; later failures carry informed retry guidance, with a
# stop reminder at four actual failed fixes. Command failures are only a proxy.
# Advisory only — never blocks.
#
# Scope limit (stated so a silent gap is not assumed covered): only
# identical-command loops (the rerun-the-repro loop) are counted. A loop that
# mutates its command every round evades the counter — accepted; prose covers
# models strong enough to vary their probes, this net exists for the weak
# ones re-running the same failing command.
#
# Fail-open everywhere: no JSON, no session_id, unwritable state → exit 0.

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0
_rcfg="${BASH_SOURCE[0]%/*}"; [ "$_rcfg" != "${BASH_SOURCE[0]}" ] || _rcfg=.
. "$_rcfg/lib/session-mode.sh"
rolepod_session_profile_load "$INPUT" "${ROLEPOD_SESSION_CLI:-unknown}"
_mode=$ROLEPOD_SESSION_MODE
[ "$_mode" = lite ] && exit 0
_cwd=$(printf '%s' "$INPUT" | python3 -I -c "import json,sys; print(json.load(sys.stdin).get('cwd') or '')" 2>/dev/null || true)
export ROLEPOD_PROJECT_ROOT="${_cwd:-$PWD}"

printf '%s' "$INPUT" | python3 -I -c '
import hashlib, json, os, re, sys, tempfile

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

if (d.get("tool_name") or "") != "Bash":
    sys.exit(0)
cmd = ((d.get("tool_input") or {}).get("command") or "").strip()
if not cmd:
    sys.exit(0)

notes = []

# ── fix→fail loop counter (runs first: its state write must never wait on git) ──
resp = d.get("tool_response")
text = resp if isinstance(resp, str) else json.dumps(resp or {})

# Exit-code extraction: structured field when the CLI provides one, else the
# "Exit code N" line a failing Bash result carries. No signal at all → treat
# as success (fail-open: never count what cannot be proven a failure).
code = None
interrupted = False
if isinstance(resp, dict):
    if resp.get("interrupted") is True:
        interrupted = True  # user cancel, not a failure
    for k in ("exitCode", "exit_code", "returnCode", "code"):
        v = resp.get(k)
        if isinstance(v, int):
            code = v
            break
if code is None:
    m = re.search(r"[Ee]xit code:? (\d+)", text)
    if m:
        code = int(m.group(1))
failed = code is not None and code != 0

sid = re.sub(r"[^A-Za-z0-9_-]", "", str(d.get("session_id") or ""))[:64]
if sid and not interrupted:
    state_path = os.path.join(tempfile.gettempdir(), "rolepod-loopbreak-%s.json" % sid)
    try:
        with open(state_path) as f:
            state = json.load(f)
        if not isinstance(state, dict):
            state = {}
    except Exception:
        state = {}

    fp = hashlib.sha1(" ".join(cmd.split()).encode()).hexdigest()[:16]
    prev = state.get(fp, 0)
    n = (prev if isinstance(prev, int) else 0) + 1 if failed else 0
    state[fp] = n
    if len(state) > 50:
        for k in list(state)[: len(state) - 50]:
            del state[k]
    try:
        with open(state_path, "w") as f:
            json.dump(state, f)
    except Exception:
        pass

    if n >= 4:
        notes.append(
            "LOOP BREAKER: this exact command failed %d times in a row, no pass between; "
            "command failures are only a proxy, not proof of failed fixes. If this is the "
            "fourth failed fix for the same unresolved repro or criterion, STOP and ask "
            "the user with the attempt log. Otherwise check the actual failed-fix ledger: "
            "if two fixes failed and no Second opinion is complete, consult once; never "
            "repeat a completed opinion. Carry usable advice into the next fresh trace; "
            "if no usable advisor is available, stop before another fix."
            % n
        )
    elif n >= 3:
        notes.append(
            "LOOP BREAKER: this exact command failed %d times in a row, no pass between; "
            "command failures are only a proxy, not proof of failed fixes. If two fixes "
            "for this unresolved repro or criterion failed and no Second opinion is "
            "complete, consult once now; never repeat a completed opinion. For attempts "
            "three and four, make a fresh trace and apply usable advice. If no usable "
            "advisor is available, stop before another fix; this command count alone "
            "does not exhaust the fix budget."
            % n
        )
    elif n == 2:
        notes.append(
            "LOOP BREAKER: this exact command failed twice in a row; command failures "
            "are only a proxy, not proof of failed fixes. If two fixes for the same "
            "unresolved repro or criterion failed and no Second opinion is complete, "
            "get ONE now; never repeat a completed opinion. If none is usable, stop "
            "before another fix. A usable opinion leaves attempts three and four "
            "available; trace again and apply its advice before those fixes."
        )

if not notes:
    sys.exit(0)
out = {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "\n\n".join(notes)}}
print(json.dumps(out))
' 2>/dev/null || true
exit 0
