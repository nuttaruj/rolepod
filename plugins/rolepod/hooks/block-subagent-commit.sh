#!/bin/bash
# PreToolUse Bash hook — block sub-agents from the calls they cannot recover from.
#
# 1. Version control (original rule). A backend-developer sub-agent ran
#    `git commit` after marking tasks COMPLETED, bypassing the review floor
#    and the Lead's verify step; soft reminders were ignored because the agent
#    saw success signals (tsc=0, imports OK). Blocks git commit / push /
#    reset --hard, gh pr merge / create.
# 2. Cannot-wait (v2.147.0, Claude only). A sub-agent receives no completion
#    notice for a backgrounded call, so a Bash run_in_background - or a long
#    gate left on the 120 s default timeout, which the harness moves to the
#    background - ends in an idle turn nobody wakes. Blocks run_in_background;
#    blocks a gate (make test*, a tests/integration/ script, a cross-family
#    run or collect) with no timeout. An explicit timeout of any size passes.
#    Codex payloads carry neither field, so the rule stays silent there.
# 3. Write rule (bash-writes-are-edits, 2026-09-18). A file written through
#    Bash (`cat > f <<EOF`, `sed -i`, `tee`, `cp`, ...) was invisible to the
#    edit ledger and to a sub-agent's write-scope class check — both key on
#    the CLI's Edit/Write/MultiEdit tools only. Runs for the LEAD too (not
#    just sub-agents): every detected write path gets an edit-ledger row
#    (same shape gate-reminder.sh writes for a real Edit); a sub-agent's path
#    additionally goes through subagent-write-scope.sh via a synthesized
#    input, and a deny there is returned with `shell write: <path> — `
#    prepended to its reason, unchanged otherwise. Precedence: commit deny >
#    wait deny > write deny — rules 1/2 already denying means the command
#    never runs, so nothing was actually written and no ledger row is added.
#
# Mechanism: Claude Code PreToolUse input carries `agent_id` + `agent_type`
# ONLY when the call originates from a sub-agent; the Lead has neither. One
# python pass tokenises the command once and answers rules 1 and 2 (only for
# a sub-agent — a Lead is never subject to them) plus a cheap pre-check for
# rule 3 (for BOTH): every segment (split on && || ; | and newlines; heredoc
# bodies dropped first) is read past the wrapper-ish tokens (a prefix word,
# its flags and numeric values, VAR=x) and a shell's -c string is recursed
# into. The gate rule reads the head only (a false positive costs one
# resend); the version-control rule tries every token (a wrapped commit must
# still be caught) and skips only a pure-output head (echo / printf / :).
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

# Fast path (v2.150.1): a Lead call (no agent_id) whose command carries no
# write-shaped token can trip no rule — skip the python spawn, which cost
# every Lead Bash call ~20 ms once the write rule made the program long.
# Checked on the raw JSON, so a marker anywhere in the payload (cwd, the
# description field) forces the full pass — fail-safe. The second
# alternative is the six-character JSON escape of ">" (backslash u003e) some
# harnesses emit; keep it. A word must stand alone ("git add" is not dd). A
# missed case costs one ledger row (fail-open); every sub-agent call and
# every token-carrying command still takes the full pass.
FAST_RX='(>|\\u003e|(^|[^[:alnum:]_-])(tee|sed|perl|cp|mv|rm|install|unlink|truncate|dd)([^[:alnum:]_-]|$))'
if [[ "$INPUT" != *'"agent_id"'* ]] && ! [[ "$INPUT" =~ $FAST_RX ]]; then exit 0; fi

RP_LIB="$(cd "$(dirname "$0")/lib" && pwd)"

# The payload travels by env: the program itself is python's stdin (heredoc).
VERDICT=$(RP_INPUT="$INPUT" RP_LIB="$RP_LIB" python3 -I - <<'PY' 2>/dev/null || printf '\n\n\n\n\n'
import sys, json, os, re
try:
    d = json.loads(os.environ.get('RP_INPUT') or '{}')
except Exception:
    d = {}
agent_id = d.get('agent_id') or ''
atype = d.get('agent_type') or ''
ti = d.get('tool_input') or {}
cmd = ti.get('command') or ''
cwd = d.get('cwd') or ''

blocked = ''
wait = ''

if agent_id:
    # Tokenizer (toks_of / PREFIX / WRAPPER_VALUE / DURATION / SHELLS / ASSIGN /
    # OUTPUT_ONLY / HEREDOC / segments / head) lives in session_state.py — the
    # only copy (bash-writes-are-edits spec, 2026-09-18); bash_write_paths()
    # there needs to walk a command the same way these rules do, and a second
    # hand-written copy would drift. Imported only for a sub-agent call — a
    # Lead's Bash call never pays for rules 1/2's git/gate walk; the write
    # rule below is the one check that still runs for a Lead, and it is
    # gated by a cheap regex first so the common no-write case stays free too.
    sys.path.insert(0, os.environ.get('RP_LIB', ''))
    from session_state import toks_of, SHELLS, OUTPUT_ONLY, segments, head  # noqa: F401

    GIT_VALUE_OPTS = {'-C', '--git-dir', '--work-tree', '--namespace', '--exec-path'}
    RUNNER = {'rolepod-cross-family', 'cross-family.sh'}

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
    if not blocked and d.get('tool_name') == 'Bash':
        if ti.get('run_in_background') in (True, 'true', 'True'):
            wait = 'run_in_background'
        else:
            try:
                to = float(ti.get('timeout') or 0)
            except (TypeError, ValueError):
                to = 0
            if to <= 0:
                wait = walk(cmd, gate_rule, False)

write_paths = []
# Write rule pre-check: most Bash calls (ls, git log, grep, npm test) carry
# none of these markers, so the common allow path never imports
# session_state or shells out to `git rev-parse` for the write detector. A
# false positive here (e.g. `2>&1`, a `>` inside prose) just costs one extra
# bash_write_paths() call — it re-parses precisely and returns [] — never a
# false ledger row or a false deny.
if not blocked and not wait and cmd and re.search(
        r'>|\btee\b|\bsed\b|\bperl\b|\bcp\b|\bmv\b|\binstall\b|\btruncate\b|\bdd\b|\brm\b|\bunlink\b', cmd):
    if os.environ.get('RP_LIB', '') not in sys.path:
        sys.path.insert(0, os.environ.get('RP_LIB', ''))
    from session_state import bash_write_paths
    write_paths = bash_write_paths(cmd, cwd or None)

print(atype); print(blocked); print(wait); print(agent_id); print(cwd)
for p in write_paths:
    print(p)
PY
)

# One read pass (5 fixed fields via the shell's own `read`, no forked
# process; the trailing multi-line field slurped with $(cat), same pattern
# gate-reminder.sh uses) instead of six `sed -n` spawns — each spawn measured
# ~2-3 ms on the allow path, the one every plain `ls` still pays for.
# `|| true` on each fixed read: $(...) strips ALL trailing newlines, so when
# cwd (or an earlier field) is the last non-empty line, the reads after it
# hit true EOF — a real `read` failure, not just an empty value — which
# would otherwise abort the script under `set -e`.
{
  IFS= read -r AGENT_TYPE || true
  IFS= read -r BLOCKED || true
  IFS= read -r WAIT || true
  IFS= read -r AGENT_ID || true
  IFS= read -r CWD || true
  WRITE_PATHS=$(cat)
} <<EOF
$VERDICT
EOF

# Write rule: only when rules 1/2 did not already deny (their deny means the
# command never runs, so nothing was written) and a path was detected. A
# sub-agent's paths are checked against its write-scope class FIRST — a
# denied command never executes, so a path from it must never reach the
# ledger. Only once every path clears (or there is no class to check, i.e.
# the Lead) does the second pass append one ledger row per path.
WRITE_DENY=""
if [ -z "$BLOCKED" ] && [ -z "$WAIT" ] && [ -n "$WRITE_PATHS" ]; then
  HDIR="$(dirname "$0")"
  CLI_TAG="${ROLEPOD_CLI:-claude}"
  LEDGER="$HDIR/edit-ledger.py"
  SCOPE="$HDIR/subagent-write-scope.sh"
  if [ -n "$AGENT_ID" ] && [ -f "$SCOPE" ]; then
    while IFS= read -r WP; do
      [ -z "$WP" ] && continue
      [ -n "$WRITE_DENY" ] && continue
      SCOPE_IN=$(RP_ATYPE="$AGENT_TYPE" RP_CWD="$CWD" RP_PATH="$WP" python3 -I -c "
import json, os
print(json.dumps({'agent_id': 'bash-write-rule', 'agent_type': os.environ.get('RP_ATYPE', ''),
  'cwd': os.environ.get('RP_CWD', ''), 'tool_name': 'Bash',
  'tool_input': {'file_path': os.environ.get('RP_PATH', '')}}))
")
      SCOPE_OUT=$(printf '%s' "$SCOPE_IN" | bash "$SCOPE" 2>/dev/null || true)
      if [ -n "$SCOPE_OUT" ]; then
        # A real deny must never become a silent allow: on any failure to
        # reformat it (an unexpected shape, a JSON error), fall back to the
        # ORIGINAL deny JSON unchanged — worst case the message lacks the
        # 'shell write:' prefix, never an allow that also ledgers the write.
        WRITE_DENY=$(RP_SCOPE="$SCOPE_OUT" RP_PATH="$WP" python3 -I -c "
import json, os
raw = os.environ.get('RP_SCOPE') or ''
try:
    d = json.loads(raw or '{}')
    reason = d['hookSpecificOutput']['permissionDecisionReason']
    p = os.environ.get('RP_PATH', '')
    short = p if len(p) <= 80 else '…' + p[-79:]
    d['hookSpecificOutput']['permissionDecisionReason'] = 'shell write: ' + short + ' — ' + reason
    print(json.dumps(d))
except Exception:
    print(raw)
")
      fi
    done <<< "$WRITE_PATHS"
  fi
  if [ -z "$WRITE_DENY" ] && [ -f "$LEDGER" ]; then
    while IFS= read -r WP; do
      [ -z "$WP" ] && continue
      python3 -I "$LEDGER" append "$CLI_TAG" "$WP" --cwd "$CWD" --agent "$AGENT_TYPE" >/dev/null 2>&1 || true
    done <<< "$WRITE_PATHS"
  fi
fi

[ -z "$BLOCKED" ] && [ -z "$WAIT" ] && [ -z "$WRITE_DENY" ] && exit 0

# WRITE_DENY is only ever set inside the block above, which itself requires
# BLOCKED and WAIT both empty — so reaching here with WRITE_DENY set means
# rules 1/2 are still empty; no need to re-test them.
if [ -n "$WRITE_DENY" ]; then
  printf '%s\n' "$WRITE_DENY"
  exit 0
fi

# Deny via PreToolUse JSON; Claude Code surfaces the reason to the agent.
# Fields are env-passed so a quote in agent_type / command cannot break the emitter.
RP_AGENT_TYPE="$AGENT_TYPE" RP_BLOCKED="$BLOCKED" RP_WAIT="$WAIT" python3 -I -c "
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
else:
    reason = (
      'BLOCKED: sub-agent %r ran a gate (%s) with no timeout. A gate that outruns the '
      '120 s default is moved to the background and no completion notice reaches a '
      'sub-agent. Fix: resend with timeout: 600000 (10 min) on the Bash call. Exception: '
      'a gate you know finishes under 2 min - state it with timeout: 120000.'
    ) % (a, w)
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse',
  'permissionDecision': 'deny', 'permissionDecisionReason': reason}}))
" 2>/dev/null

exit 0
