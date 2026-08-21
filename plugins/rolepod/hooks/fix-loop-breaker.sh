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
# run resets it. At >= 3 consecutive fails, inject additionalContext telling
# the Lead to apply debug-issue Iron Rule #5 (stop fixing, hypothesis ledger,
# ONE cross-model advisor opinion or escalate). Advisory only — never blocks.
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

printf '%s' "$INPUT" | python3 -c '
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

resp = d.get("tool_response")
text = resp if isinstance(resp, str) else json.dumps(resp or {})

# Exit-code extraction: structured field when the CLI provides one, else the
# "Exit code N" line a failing Bash result carries. No signal at all → treat
# as success (fail-open: never count what cannot be proven a failure).
code = None
if isinstance(resp, dict):
    if resp.get("interrupted") is True:
        sys.exit(0)  # user cancel, not a failure
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
if not sid:
    sys.exit(0)
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

if n < 3:
    sys.exit(0)

msg = (
    "LOOP BREAKER: this exact command has now failed %d consecutive times "
    "with no passing run in between. STOP editing-and-retrying — a blind "
    "next attempt is not allowed. Apply debug-issue Iron Rule #5: (1) stop "
    "fixing, (2) write the hypothesis ledger — what you believed, what each "
    "attempt changed, why each failed, (3) get ONE cross-model advisor "
    "opinion (`codex exec` / `claude -p` / `gemini -m pro -p`) or escalate "
    "to the user with the ledger. An identical failure twice means the "
    "mental model of the bug is wrong — more of the same fix cannot fix it."
    % n
)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": msg,
}}))
' 2>/dev/null || true
exit 0
