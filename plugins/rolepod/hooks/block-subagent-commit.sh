#!/bin/bash
# PreToolUse Bash / Agent / SendMessage hook — block sub-agents from the calls
# they cannot recover from.
#
# 1. Version control (original rule). A backend-developer sub-agent ran
#    `git commit` after marking tasks COMPLETED, bypassing the review floor
#    and the Lead's verify step; soft reminders were ignored because the agent
#    saw success signals (tsc=0, imports OK). Blocks git commit / push /
#    reset --hard, gh pr merge / create.
#    C9a: rule 1 runs on Codex too - a child's PreToolUse carries `agent_id`
#    (live probe 2026-09-30, Codex 0.159), so a sub-agent's `git commit` /
#    `git push` is denied there.
# 2. Cannot-wait (v2.147.0, Claude only). A sub-agent receives no completion
#    notice for a backgrounded call, so a Bash run_in_background - or a long
#    gate left on the 120 s default timeout, which the harness moves to the
#    background - ends in an idle turn nobody wakes. Blocks run_in_background;
#    blocks a gate (make test*, a tests/integration/ script, a cross-family
#    run or collect) with no timeout. An explicit timeout of any size passes.
#    The Codex hooks.json entry passes `--cli codex`: that half is skipped
#    there (a Codex Bash payload has no timeout field to satisfy it).
#    Extended to Agent/SendMessage (incident 2026-09-28): an R4 task owner
#    dispatched 4 reviewers with run_in_background unset - the platform
#    default is background - ended its turn "waiting for their
#    notifications", and idled 6.6 h (a named / resumed child reports to the
#    Lead; nothing wakes the sub-agent). Live probe 2026-09-29 (Claude Code 2.1.284): the Agent
#    tool has NO run_in_background parameter (every dispatch is async) and a
#    child's end DOES wake a sub-agent that ended its turn (parent ended
#    03:07:57, child done 03:08:13, the notification reached the parent, the
#    Lead got nothing) - so an unset flag is allowed. Blocks a sub-agent's
#    Agent dispatch only on an explicit run_in_background: true / "true" /
#    "True" (older builds, where that flag exists). Blocks a sub-agent's
#    SendMessage only when `to` is a raw agentId (regex ^a[0-9a-f-]{8,}$ - how an owner addresses the
#    finished, unnamed reviewer it just spawned; all 3 Kyni incidents used
#    one) - that message resumes the child in the background the same way,
#    and its reply goes to the Lead. A named target (main, team-lead, a
#    teammate's own name) always passes - narrowed from "anyone but main"
#    (round-1 fix, 2026-09-29): that shape denied a resumed reviewer's
#    legitimate reply to its parent owner by name. In-process teammates
#    carry agent_id too, same as an Agent-tool sub-agent (live probe
#    2026-09-29: a teammate's `git commit --dry-run` was denied).
#    Round 2 (live probe 2026-09-29): run_in_background: false does not save
#    an Agent call that always runs in the background regardless - a `name`
#    (the platform spawns it as a background teammate: "Spawned successfully
#    ... will receive instructions via mailbox"), subagent_type "fork", or
#    isolation "remote" (both documented as always-background). Denied
#    before the run_in_background check even when it is explicitly false.
#    All three checks decide from tool_input alone (run_in_background / to /
#    name / subagent_type / isolation) - none carries a shell command, so
#    none imports the tokenizer below.
# Mechanism: Claude Code PreToolUse input carries `agent_id` + `agent_type`
# ONLY when the call originates from a sub-agent; the Lead has neither. Codex
# PreToolUse carries agent_id too (live probe 2026-09-30, Codex 0.159); the
# Codex hooks.json entry passes --cli codex (commit ban only). One
# python pass tokenises the command once and answers rules 1 and 2 (only for
# a sub-agent — a Lead is never subject to them): every segment (split on &&
# || ; | and newlines; heredoc bodies dropped first) is read past the
# wrapper-ish tokens (a prefix word, its flags and numeric values, VAR=x) and
# a shell's -c string is recursed into. The gate rule reads the head only (a
# false positive costs one resend); the version-control rule tries every
# token (a wrapped commit must still be caught) and skips only a pure-output
# head (echo / printf / :).
#
# Accepted residuals (owner decision, 2026-09-24, final cut before release):
# deliberate evasion is out of scope by design — this hook catches mistakes
# in the normal flow, not a deliberately crafted bypass. Not handled: ANSI-C
# $'…' escapes, a bare & after an output command, quote- or backslash-split
# names. A sub-agent can no longer spawn a named child at all (the `name`
# deny above closes that resume path at spawn time); the SendMessage raw-id
# regex still stays narrow on purpose, since a named target reaching it
# (main, team-lead, a parent owner, a Lead-spawned teammate) is a legit send.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
_rcfg="${BASH_SOURCE[0]%/*}"; [ "$_rcfg" != "${BASH_SOURCE[0]}" ] || _rcfg=.
. "$_rcfg/lib/session-mode.sh"
rolepod_session_profile_load "$INPUT" "${ROLEPOD_SESSION_CLI:-unknown}"
_mode=$ROLEPOD_SESSION_MODE
[ "$_mode" = lite ] && exit 0
_cwd=$(printf '%s' "$INPUT" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("cwd") or "")' 2>/dev/null || true)
export ROLEPOD_PROJECT_ROOT="${_cwd:-$PWD}"

# Fast path: only a sub-agent call (agent_id present) can trip rules 1/2 —
# a Lead is never subject to either, so a Lead Bash call skips the python
# spawn entirely. Checked on the raw JSON so nothing about the command
# itself needs parsing to decide this.
if [[ "$INPUT" != *'"agent_id"'* ]]; then exit 0; fi

RP_LIB="$(cd "$(dirname "$0")/lib" && pwd)"

# --cli codex (Codex hooks.json): only rule 1 runs; the cannot-wait rules are
# Claude-harness rules. No arg = Claude behavior.
RP_CLI=""
if [ "${1:-}" = "--cli" ]; then RP_CLI="${2:-}"; fi

# The payload travels by env: the program itself is python's stdin (heredoc).
VERDICT=$(RP_INPUT="$INPUT" RP_LIB="$RP_LIB" RP_CLI="$RP_CLI" python3 -I - <<'PY' 2>/dev/null || printf '\n\n\n'
import sys, json, os, re
try:
    d = json.loads(os.environ.get('RP_INPUT') or '{}')
except Exception:
    d = {}
agent_id = d.get('agent_id') or ''
atype = d.get('agent_type') or ''
ti = d.get('tool_input') or {}
cmd = ti.get('command') or ''

blocked = ''
wait = ''

tool_name = d.get('tool_name') or ''

if agent_id and tool_name == 'Agent':
    # Cannot-wait, Agent form: no shell command to walk, so no tokenizer.
    # A named / fork / remote-isolation dispatch always runs in the
    # background (round 2, live probe 2026-09-29) - checked before
    # run_in_background, since an explicit false does not save it.
    name = str(ti.get('name') or '').strip()
    subagent_type = str(ti.get('subagent_type') or '').strip()
    isolation = str(ti.get('isolation') or '').strip()
    if name or subagent_type == 'fork' or isolation == 'remote':
        wait = 'agent-always-bg'
    elif ti.get('run_in_background') in (True, 'true', 'True'):
        # An unset flag is fine: Claude Code 2.1.284 has no such parameter
        # and a child's end wakes the dispatching sub-agent (the desktop app
        # sends it to the Lead, which relays it).
        wait = 'agent-bg'

elif agent_id and tool_name == 'SendMessage':
    # Cannot-wait, SendMessage form: deny only a raw agentId - the shape an
    # owner uses to message the finished, unnamed reviewer it just spawned
    # (all 3 Kyni incidents used one). A named target (main, team-lead, a
    # teammate's own name - a resumed reviewer's legitimate reply path) is
    # never denied (round-1 fix, 2026-09-29: "anyone but main" caught that
    # legitimate reply too). Newlines are replaced with spaces, not stripped,
    # to keep the `to` value on one line for the 3-line verdict protocol.
    to_clean = str(ti.get('to') or '').replace('\r', ' ').replace('\n', ' ').strip()
    if re.match(r'^a[0-9a-f-]{8,}$', to_clean):
        wait = 'sendmessage:' + to_clean

elif agent_id:
    # Tokenizer (toks_of / PREFIX / WRAPPER_VALUE / DURATION / SHELLS / ASSIGN /
    # OUTPUT_ONLY / HEREDOC / segments / head) lives in session_state.py — the
    # only copy; a second hand-written copy would drift. Imported only for a
    # sub-agent's Bash call — a Lead's Bash call never reaches here (fast path
    # above), and an Agent/SendMessage call is handled above with no import.
    sys.path.insert(0, os.environ.get('RP_LIB', ''))
    from session_state import toks_of, SHELLS, OUTPUT_ONLY, segments, head  # noqa: F401

    GIT_VALUE_OPTS = {'-C', '--git-dir', '--work-tree', '--namespace', '--exec-path'}
    RUNNER = {'cross-family.sh'}

    def walk(text, rule, every, depth=0):
        # rule(t, base) -> label or ''. every=False: t starts at the segment head
        # (a gate false positive costs one resend, so head-only is right there).
        # every=True: every token position is tried (a wrapped commit - timeout,
        # xargs, watch - must still be caught); only a pure-output head is skipped.
        # F8b/S8 (v2.166.x): a flag CLUSTER containing 'c' (-c, -lc, -ec, -xc)
        # recurses like an exact '-c'; a $SHELL / ${SHELL} head is expanded
        # from the environment first; 'eval' recurses into its joined
        # remaining args. depth-4 cap's VALUE is unchanged; its RETURN on hit
        # is now fail-closed (round-1 external review) — adding 'eval'
        # recursion here means a 5-deep eval chain ('eval eval eval eval
        # eval git commit') would otherwise fall through the empty '' this
        # cap used to return with nothing else in the segment to check,
        # silently clearing the sub-agent's only hard deny.
        if depth > 4:
            return 'nested shell/eval too deep'
        for seg in segments(text):
            t = head(toks_of(seg))
            if not t:
                continue
            ht = t[0]
            if ht in ('$SHELL', '${SHELL}'):
                ht = os.environ.get('SHELL', '')
            base = os.path.basename(ht)
            if base == 'eval' and len(t) > 1:
                r = walk(' '.join(t[1:]), rule, every, depth + 1)
                if r:
                    return r
                continue
            if base in SHELLS:
                cflag = None
                for k in range(1, len(t)):
                    if t[k].startswith('-') and not t[k].startswith('--') and 'c' in t[k][1:]:
                        cflag = k
                        break
                if cflag is not None and cflag + 1 < len(t):
                    r = walk(t[cflag + 1], rule, every, depth + 1)
                    if r:
                        return r
                if len(t) > 1 and not t[1].startswith('-'):
                    t = t[1:]; base = os.path.basename(t[0])
            if every:
                if base in OUTPUT_ONLY:
                    continue
                for i in range(len(t)):
                    r = rule(t[i:], os.path.basename(t[i]))
                    if r:
                        return r
            else:
                r = rule(t, base)
                if r:
                    return r
        return ''

    def git_rule(t, base):
        if base == 'git':
            j = 1
            while j < len(t) and t[j].startswith('-'):
                if t[j] in GIT_VALUE_OPTS or (t[j] == '-c' and j + 1 < len(t) and '=' in t[j + 1]):
                    j += 2
                else:
                    j += 1
            if j < len(t):
                sub, rest = t[j], t[j:]
                if sub == 'commit':
                    return 'git commit'
                if sub == 'push':
                    return 'git push --force' if ('--force' in rest or '-f' in rest) else 'git push'
                if sub == 'reset' and '--hard' in rest:
                    return 'git reset --hard'
        elif base == 'gh' and len(t) > 2 and t[1] == 'pr' and t[2] in ('merge', 'create'):
            return 'gh pr ' + t[2]
        return ''

    def gate_rule(t, base):
        if base == 'make':
            for a in t[1:]:
                if not a.startswith('-') and a.startswith('test'):
                    return 'make ' + a
        if 'tests/integration/' in t[0] and t[0].endswith('.sh'):
            return t[0]
        if base in RUNNER and ('--collect' in t or ('--kind' in t and '--detach' not in t)):
            return base
        return ''

    blocked = walk(cmd, git_rule, True)
    if not blocked and tool_name == 'Bash':
        if ti.get('run_in_background') in (True, 'true', 'True'):
            wait = 'run_in_background'
        else:
            try:
                to = float(ti.get('timeout') or 0)
            except (TypeError, ValueError):
                to = 0
            if to <= 0:
                wait = walk(cmd, gate_rule, False)

if os.environ.get('RP_CLI') == 'codex':
    wait = ''   # cannot-wait rules are Claude-only; the commit ban above stays
print(atype); print(blocked); print(wait)
PY
)

# One read pass (3 fixed fields via the shell's own `read`, no forked
# process) instead of separate `sed -n` spawns.
# `|| true` on each read: $(...) strips ALL trailing newlines, so when the
# last field is empty, the read after it hits true EOF — a real `read`
# failure, not just an empty value — which would otherwise abort the script
# under `set -e`.
{
  IFS= read -r AGENT_TYPE || true
  IFS= read -r BLOCKED || true
  IFS= read -r WAIT || true
} <<EOF
$VERDICT
EOF

[ -z "$BLOCKED" ] && [ -z "$WAIT" ] && exit 0

# Deny via PreToolUse JSON; Claude Code surfaces the reason to the agent.
# Fields are env-passed so a quote in agent_type / command cannot break the emitter.
RP_AGENT_TYPE="$AGENT_TYPE" RP_BLOCKED="$BLOCKED" RP_WAIT="$WAIT" RP_MODE="$_mode" python3 -I -c "
import json, os
a = os.environ.get('RP_AGENT_TYPE', ''); b = os.environ.get('RP_BLOCKED', ''); w = os.environ.get('RP_WAIT', '')
if b:
    reason = (
      'BLOCKED: sub-agent %r attempted %r. Sub-agents never commit, push, or '
      'merge - the Lead does, after review. Return COMPLETED with the file list '
      'and verification evidence; the Lead commits.'
    ) % (a, b)
elif w == 'run_in_background':
    reason = (
      'BLOCKED: sub-agent %r set run_in_background. A sub-agent receives no completion '
      'notice, so waiting for one never ends the task. Fix: run the command in the '
      'foreground with timeout: 600000 (10 min), write its output to a file and read the '
      'tail. Exception: none - background runs belong to the Lead.'
    ) % a
elif w == 'agent-bg':
    reason = (
      'BLOCKED: sub-agent %r set run_in_background: true on an agent dispatch. Where '
      'that flag exists, the child\'s report can go to the Lead and nothing wakes you. '
      'Fix: resend without run_in_background. Exception: none.'
    ) % a
elif w == 'agent-always-bg':
    reason = (
      'BLOCKED: sub-agent %r dispatched an agent that always runs in the background '
      '(a name, a fork, or isolation: remote), even with run_in_background: false. Its '
      'report goes to the Lead and nothing wakes you once your turn ends. Fix: resend '
      'unnamed, with no fork or remote isolation. '
      'Exception: none.'
    ) % a
elif w.startswith('sendmessage:'):
    to = w[len('sendmessage:'):][:60]
    reason = (
      'BLOCKED: sub-agent %r messaged agent %r by its raw id - a finished child you '
      'spawned. The message resumes it in the background; its reply goes to the Lead and '
      'nothing wakes you. Fix: a round-2 re-check is a fresh Agent dispatch of that role '
      'its report and the fix delta in the brief. '
      'Exception: a named teammate or the Lead (main / team-lead) passes.'
    ) % (a, to)
else:
    reason = (
      'BLOCKED: sub-agent %r ran a gate (%s) with no timeout. A gate that outruns the '
      '120 s default is moved to the background and no completion notice reaches a '
      'sub-agent. Fix: resend with timeout: 600000 (10 min) on the Bash call. Exception: '
      'a gate you know finishes under 2 min - state it with timeout: 120000.'
    ) % (a, w)
hook = {'hookEventName': 'PreToolUse'}
if os.environ.get('RP_MODE') == 'standard':
    hook['additionalContext'] = 'WARNING: ' + reason + ' Standard mode allows the operation; full mode enforces this workflow guard.'
else:
    hook.update(permissionDecision='deny', permissionDecisionReason=reason)
print(json.dumps({'hookSpecificOutput': hook}))
" 2>/dev/null

exit 0
