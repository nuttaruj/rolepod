#!/bin/bash
# cursor-host-guard — (1) the Claude hook manifest self-disables under Cursor;
# (2) the Cursor-native gate-reminder delivers on the events Cursor honours.
#
# Cursor auto-imports every Claude Code plugin from
# ~/.claude/plugins/installed_plugins.json and runs its hooks/hooks.json with
# the Claude event names mapped (PreToolUse → preToolUse, ...). On a machine
# that also carries the Cursor-native rolepod plugin that ran two hook sets
# per tool call. Cursor sets CURSOR_PROJECT_DIR for hook processes only
# (workbench + extension host + agent CLI, verified 2026-09-16), so every
# command in adapters/claude/hooks.json is:
#
#   [ -z "$CURSOR_PROJECT_DIR" ] && exec bash "${CLAUDE_PLUGIN_ROOT}/hooks/<x>.sh"; cat >/dev/null
#
# Not Cursor → exec the script (stdin untouched, exit code passes through).
# Cursor → swallow stdin, exit 0, no output — the Cursor-native rule + hooks
# own that host. The guard is a shell builtin: zero extra processes on Claude.
set -u
cd "$(dirname "$0")/../.."
ROOT="$PWD"
fail=0
pass() { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1"; fail=$((fail + 1)); }

SRC=adapters/claude/hooks.json
RENDERED=plugins/rolepod/hooks/hooks.json

# 1. Shape: every command carries the guard, one script each, 22 registrations
#    over 16 distinct scripts (the lean-surface pins).
if python3 -I - "$SRC" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1]))
rx = re.compile(r'^\[ -z "\$CURSOR_PROJECT_DIR" \] && exec bash "\$\{CLAUDE_PLUGIN_ROOT\}/hooks/([a-z-]+\.sh)"( --[a-z]+)?; cat >/dev/null$')
cmds = []
def walk(n):
    if isinstance(n, dict):
        for k, v in n.items():
            if k == "command" and isinstance(v, str): cmds.append(v)
            else: walk(v)
    elif isinstance(n, list):
        for x in n: walk(x)
walk(d)
bad = [c for c in cmds if not rx.match(c)]
assert not bad, "unguarded command(s): " + "; ".join(bad)
scripts = {rx.match(c).group(1) for c in cmds}
assert len(cmds) == 22 and len(scripts) == 16, (len(cmds), len(scripts))
PY
then pass "every Claude hook command carries the CURSOR_PROJECT_DIR guard (22 registrations / 16 scripts)"
else bad "a Claude hook command lacks the guard or the counts moved"; fi

# 2. Rendered plugin copy is byte-identical to the adapter source.
if cmp -s "$SRC" "$RENDERED"; then pass "plugins/rolepod/hooks/hooks.json matches adapters/claude/hooks.json"
else bad "rendered hooks.json drifted from the adapter source — run make render"; fi

cmd_of() {  # $1 = script basename → the registered command string
  python3 -I - "$SRC" "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); want = sys.argv[2]
def walk(n):
    if isinstance(n, dict):
        for k, v in n.items():
            if k == "command" and isinstance(v, str) and want in v: print(v); raise SystemExit
            walk(v)
    elif isinstance(n, list):
        for x in n: walk(x)
walk(d)
PY
}
LOADER_CMD="$(cmd_of always-on-loader.sh)"
GATE_CMD="$(cmd_of precommit-gate.sh)"
SESSION_IN='{"hook_event_name":"SessionStart","cwd":"/tmp","session_id":"guard-test"}'
COMMIT_IN='{"tool_name":"Bash","tool_input":{"command":"git commit -m x"},"cwd":"/tmp","session_id":"guard-test"}'
export CLAUDE_PLUGIN_ROOT="$ROOT/plugins/rolepod"

# 3. Under Cursor (CURSOR_PROJECT_DIR set): exit 0, no output, stdin drained —
#    through both shells a host may pick.
for sh in sh bash; do
  out=$(printf '%s' "$SESSION_IN" | CURSOR_PROJECT_DIR=/tmp/ws "$sh" -c "$LOADER_CMD" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$out" ]; then pass "$sh: always-on-loader is silent under Cursor (rc 0, no output)"
  else bad "$sh: always-on-loader ran under Cursor (rc $rc, ${#out} bytes)"; fi
  out=$(printf '%s' "$COMMIT_IN" | CURSOR_PROJECT_DIR=/tmp/ws "$sh" -c "$GATE_CMD" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$out" ]; then pass "$sh: precommit-gate never denies under Cursor"
  else bad "$sh: precommit-gate fired under Cursor (rc $rc): ${out:0:120}"; fi
done

# 4. Not Cursor: the script runs with stdin intact — the loader still emits
#    the always-on payload, and the script's exit status passes through exec.
out=$(printf '%s' "$SESSION_IN" | env -u CURSOR_PROJECT_DIR sh -c "$LOADER_CMD" 2>/dev/null); rc=$?
case "$out" in
  *'"additionalContext"'*'always-on judgment'*) [ "$rc" -eq 0 ] && pass "no Cursor env: always-on-loader emits the payload (rc 0)" || bad "no Cursor env: loader rc $rc";;
  *) bad "no Cursor env: always-on-loader emitted nothing (${#out} bytes) — exec path broken";;
esac
FAKE_CMD='[ -z "$CURSOR_PROJECT_DIR" ] && exec bash -c "exit 7"; cat >/dev/null'
env -u CURSOR_PROJECT_DIR sh -c "$FAKE_CMD" </dev/null >/dev/null 2>&1; rc=$?
[ "$rc" -eq 7 ] && pass "no Cursor env: the script's exit status passes through (7)" || bad "no Cursor env: exit status lost (got $rc, want 7)"

# ── Cursor-native gate-reminder delivery (v2.130.2) ──────────────────────
# Cursor feeds agent_message to the model only on deny and has no
# additional_context on preToolUse, so the script is registered twice:
# preToolUse = deny path only, postToolUse = soft reminders as additional_context.
CUR_HOOKS=adapters/cursor/hooks/hooks.json
CUR_GATE=adapters/cursor/scripts/gate-reminder.sh
if python3 -I - "$CUR_HOOKS" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["hooks"]
for ev in ("preToolUse", "postToolUse"):
    regs = [h for h in d[ev] if h["command"] == "./scripts/gate-reminder.sh"]
    assert len(regs) == 1 and regs[0].get("matcher") == "Write|Edit|MultiEdit", ev
PY
then pass "cursor hooks.json registers gate-reminder on preToolUse AND postToolUse (matcher Write|Edit|MultiEdit)"
else bad "cursor hooks.json gate-reminder registrations wrong"; fi
if cmp -s adapters/cursor/scripts/gate-reminder.sh plugins/rolepod-cursor/scripts/gate-reminder.sh && cmp -s "$CUR_HOOKS" plugins/rolepod-cursor/hooks/hooks.json; then
  pass "rendered Cursor plugin carries the same gate-reminder + hooks.json"
else bad "plugins/rolepod-cursor drifted from adapters/cursor — run make render"; fi

CUR_TMP="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-cursor-gate.XXXXXX")"
mkdir -p "$CUR_TMP/src/auth" "$CUR_TMP/.cursor-plugin"; printf '{}' > "$CUR_TMP/.cursor-plugin/plugin.json"; printf 'x' > "$CUR_TMP/src/auth/login.ts"; printf 'y' > "$CUR_TMP/src/util.ts"
cur_in() { printf '{"hook_event_name":"%s","tool_name":"Write","tool_input":{"file_path":"%s","content":""},"workspace_roots":["%s"],"session_id":"g"}' "$1" "$2" "$CUR_TMP"; }
# preToolUse: always silent (v2.134.1 — the write-time deny was measured to push the model
# into writing the file through the shell, which skips every edit hook).
out=$(cur_in preToolUse "$CUR_TMP/.cursor-plugin/marketplace.json" | env -u ROLEPOD_GATES_SOFT -u ROLEPOD_GATES_PASSED bash "$CUR_GATE" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass "preToolUse: schema-bound new file is silent (soft reminder no longer wasted on allow)" || bad "preToolUse schema-bound: rc $rc out=${out:0:80}"
out=$(cur_in preToolUse "$CUR_TMP/src/auth/new-token.ts" | env -u ROLEPOD_GATES_SOFT -u ROLEPOD_GATES_PASSED bash "$CUR_GATE" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass "preToolUse: high-risk NEW file is silent too — no write-time deny (the commit gate is the stop)" || bad "preToolUse high-risk new file: rc $rc out=${out:0:100}"
out=$(cur_in preToolUse "$CUR_TMP/src/auth/login.ts" | env -u ROLEPOD_GATES_SOFT -u ROLEPOD_GATES_PASSED bash "$CUR_GATE" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass "preToolUse: existing high-risk file passes silently" || bad "preToolUse existing high-risk: rc $rc out=${out:0:80}"
# postToolUse: schema-bound / high-risk → additional_context; plain path → silent
out=$(cur_in postToolUse "$CUR_TMP/.cursor-plugin/plugin.json" | bash "$CUR_GATE" 2>/dev/null); rc=$?
printf '%s' "$out" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); m=d["additional_context"]; assert m.startswith("SCHEMA-BOUND file written: plugin.json") and len(m)<=600' 2>/dev/null && [ "$rc" -eq 0 ] \
  && pass "postToolUse: schema-bound file → additional_context reminder (≤600 chars)" || bad "postToolUse schema-bound: rc $rc out=${out:0:100}"
out=$(cur_in postToolUse "$CUR_TMP/src/auth/login.ts" | bash "$CUR_GATE" 2>/dev/null); rc=$?
printf '%s' "$out" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); m=d["additional_context"]; assert m.startswith("HIGH-RISK path edited: login.ts") and "qa-tester" in m and len(m)<=600' 2>/dev/null && [ "$rc" -eq 0 ] \
  && pass "postToolUse: high-risk path → additional_context reminder" || bad "postToolUse high-risk: rc $rc out=${out:0:100}"
out=$(cur_in postToolUse "$CUR_TMP/src/util.ts" | bash "$CUR_GATE" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass "postToolUse: plain path stays silent" || bad "postToolUse plain: rc $rc out=${out:0:80}"
out=$(printf '{"hook_event_name":"postToolUse","tool_name":"Read","tool_input":{"file_path":"%s"}}' "$CUR_TMP/src/auth/login.ts" | bash "$CUR_GATE" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass "non-edit tool never answers" || bad "Read tool produced output: ${out:0:80}"
rm -rf "$CUR_TMP"

echo
if [ "$fail" -eq 0 ]; then echo "cursor-host-guard: pass"; exit 0
else echo "cursor-host-guard: FAIL ($fail)"; exit 1; fi
