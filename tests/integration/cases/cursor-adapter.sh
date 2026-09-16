#!/bin/bash
# cursor-adapter — structural + behavioural fixture for the Cursor plugin hooks.
# Locks the Cursor hook contract MEASURED LIVE on agent CLI 2026.09.10 / IDE 3.20
# (2026-09-16):
#   - hook cwd = plugin root; ./scripts/x.sh resolves; matcher = regex on tool_name
#     (preToolUse/postToolUse) or on the literal command (beforeShellExecution)
#   - only sessionStart / postToolUse carry additional_context to the model;
#     agent_message reaches the model only on deny; afterShellExecution carries
#     command + output but NO exit code and NO context field
#   - shell commands never raise postToolUse (before/afterShellExecution instead)
#   - stdin carries conversation_id + session_id + workspace_roots (no cwd);
#     Read's tool_output is {"file_path","content_length"} (bytes the model got)
# Consequences locked here: sweep-nudge counts Read via content_length and delivers
# on the next postToolUse; fix-loop-breaker + push-ref-check are NOT ported
# (no exit code / no pre-shell channel); session locks are cursor-<conversation_id>
# and released on stop.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() { if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi; }

P="plugins/rolepod-cursor"
S="$REPO_DIR/$P/scripts"
HJ="$P/hooks/hooks.json"

# Structure.
check "rendered cursor plugin present"     "[ -f $P/.cursor-plugin/plugin.json ] && [ -f $HJ ]"
check "5 core scripts present + shared/sweep-nudge.sh is the Claude script, byte-identical" \
  "for f in project-context-loader gate-reminder precommit-gate sweep-nudge stop-unlock; do [ -f $P/scripts/\$f.sh ] || exit 1; done && cmp -s hooks/sweep-nudge.sh $P/scripts/shared/sweep-nudge.sh"
check "hooks.json: 9 registrations over 5 distinct scripts, every command ./scripts/<x>.sh" \
  "python3 -I -c \"
import json,re
h=json.load(open('$HJ'))['hooks']; cmds=[(ev,r['command'],r.get('matcher','')) for ev,regs in h.items() for r in regs]
assert len(cmds)==9, cmds
assert len({c for _,c,_ in cmds})==5, cmds
assert all(re.fullmatch(r'\\./scripts/[a-z-]+\\.sh', c) for _,c,_ in cmds), cmds
assert set(h)=={'sessionStart','beforeSubmitPrompt','preToolUse','postToolUse','afterShellExecution','beforeShellExecution','stop'}, set(h)\""
check "sweep-nudge sits on beforeSubmitPrompt / preToolUse(edit) / postToolUse(read tools) / afterShellExecution" \
  "python3 -I -c \"
import json
h=json.load(open('$HJ'))['hooks']
def has(ev,m): return any(r['command'].endswith('sweep-nudge.sh') and r.get('matcher','')==m for r in h[ev])
assert has('beforeSubmitPrompt','') and has('preToolUse','Write|Edit|MultiEdit') and has('postToolUse','Read|Grep|Glob|WebFetch|WebSearch') and has('afterShellExecution','')\""
check "stop-unlock sits on stop" "python3 -I -c \"import json;h=json.load(open('$HJ'))['hooks'];assert [r['command'] for r in h['stop']]==['./scripts/stop-unlock.sh']\""
check "precommit-gate matcher fires on ANY git command (git -c k=v commit / add && commit shapes), the gate decides" \
  "python3 -I -c \"
import json,re
m=[r['matcher'] for r in json.load(open('$HJ'))['hooks']['beforeShellExecution'] if r['command'].endswith('precommit-gate.sh')][0]
rx=re.compile(m)
for c in ['git commit -m x','git -c user.email=p@p commit -m x','git add -A && git -c a=b commit -m x','cd x; git status']: assert rx.search(c), c
assert not rx.search('gitk') and not rx.search('echo digit'), m\""
check "no fix-loop-breaker / push-ref-check wrapper on Cursor (no exit code, no pre-shell channel)" \
  "[ ! -f $P/scripts/fix-loop-breaker.sh ] && [ ! -f $P/scripts/push-ref-check.sh ]"

# Behaviour: sweep-nudge through the translator (state lives in \$TMPDIR/rolepod-sweep-<sid>.json).
SID="cursor-adapter-test-$$"
cleanup() { rm -f "${TMPDIR:-/tmp}"/rolepod-sweep-"$SID"*.json; rm -rf "${R:-}" "${LOCK_DIR:-}"; }
trap cleanup EXIT
cur() { printf '{"hook_event_name":"%s","conversation_id":"%s","session_id":"%s","workspace_roots":["/tmp"]%s}' "$1" "$2" "$2" "${3:-}"; }
read_out() { printf ',"tool_name":"Read","tool_input":{"file_path":"/tmp/f"},"tool_output":"{\\"file_path\\":\\"/tmp/f\\",\\"content_length\\":%d}"' "$1"; }

out=$(cur beforeSubmitPrompt "$SID" ',"prompt":"hello"' | bash "$S/sweep-nudge.sh" 2>/dev/null); rc=$?
check "beforeSubmitPrompt → {continue: true} (prompt never blocked), state reset" "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -qx '{\"continue\": true}'"
out=$(cur postToolUse "$SID" "$(read_out 70000)" | bash "$S/sweep-nudge.sh" 2>/dev/null); rc=$?
check "postToolUse Read 70 KB → below the 120 KB line: NO output" "[ $rc -eq 0 ] && [ -z \"$out\" ]"
out=$(cur postToolUse "$SID" "$(read_out 70000)" | bash "$S/sweep-nudge.sh" 2>/dev/null); rc=$?
check "second Read (140 KB total) → ONE {additional_context} carrying the sweep nudge (KB counted from content_length)" \
  "[ $rc -eq 0 ] && printf '%s' \"\$out\" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); m=d[\"additional_context\"]; assert m.startswith(\"⟂ sweep: ~136 KB\") and \"2 calls\" in m, m'"
out=$(cur postToolUse "$SID" "$(read_out 70000)" | bash "$S/sweep-nudge.sh" 2>/dev/null); rc=$?
check "third Read → silent (fires once per turn)" "[ $rc -eq 0 ] && [ -z \"$out\" ]"

SID2="${SID}-edit"
cur beforeSubmitPrompt "$SID2" ',"prompt":"x"' | bash "$S/sweep-nudge.sh" >/dev/null 2>&1
out=$(cur preToolUse "$SID2" ',"tool_name":"Write","tool_input":{"file_path":"/tmp/f","content":""}' | bash "$S/sweep-nudge.sh" 2>/dev/null); rc=$?
check "preToolUse Write → edit flag, NO output" "[ $rc -eq 0 ] && [ -z \"$out\" ]"
out=$(cur postToolUse "$SID2" "$(read_out 200000)" | bash "$S/sweep-nudge.sh" 2>/dev/null); rc=$?
check "reads after an edit never nudge (build turn)" "[ $rc -eq 0 ] && [ -z \"$out\" ]"

SID3="${SID}-shell"
cur beforeSubmitPrompt "$SID3" ',"prompt":"x"' | bash "$S/sweep-nudge.sh" >/dev/null 2>&1
BIG=$(python3 -c 'print("y"*130000)')
out=$(cur afterShellExecution "$SID3" ",\"command\":\"cat big.log\",\"output\":\"$BIG\"" | bash "$S/sweep-nudge.sh" 2>/dev/null); rc=$?
check "afterShellExecution 130 KB → counted but silent (no context channel there)" "[ $rc -eq 0 ] && [ -z \"$out\" ]"
out=$(cur postToolUse "$SID3" "$(read_out 10)" | bash "$S/sweep-nudge.sh" 2>/dev/null); rc=$?
check "…and the next Read delivers the nudge (the shell fire was un-fired, not lost)" \
  "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'additional_context'"
out=$(printf 'not json' | bash "$S/sweep-nudge.sh" 2>/dev/null); rc=$?
check "unparsable stdin → silent, rc 0" "[ $rc -eq 0 ] && [ -z \"$out\" ]"

# Behaviour: session lock by conversation_id, released on stop.
R="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-cursor-adapter.XXXXXX")"
git -C "$R" init -q; git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
LOCK_HASH="$(git -C "$R" rev-parse --show-toplevel | tr -d '\n' | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)"
LOCK_DIR="$HOME/.rolepod/session-locks/$LOCK_HASH"
CONV="conv-cursor-$$"
out=$(printf '{"hook_event_name":"sessionStart","conversation_id":"%s","session_id":"%s","workspace_roots":["%s"]}' "$CONV" "$CONV" "$R" | bash "$S/project-context-loader.sh" 2>/dev/null); rc=$?
check "sessionStart: answers additional_context and registers cursor-<conversation_id>.lock" \
  "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q additional_context && [ -f '$LOCK_DIR/cursor-$CONV.lock' ] && [ -f '$R/.rolepod/parent-active' ]"
out=$(printf '{"hook_event_name":"stop","conversation_id":"%s","session_id":"%s","workspace_roots":["%s"]}' "$CONV" "$CONV" "$R" | bash "$S/stop-unlock.sh" 2>/dev/null); rc=$?
check "stop: silent, lock released" "[ $rc -eq 0 ] && [ -z \"$out\" ] && [ ! -f '$LOCK_DIR/cursor-$CONV.lock' ]"

# Behaviour: edit ledger + the shared commit gate behind the translator (v2.134.0).
check "scripts/shared carries the gate pair + edit-ledger.py, byte-identical" \
  "cmp -s hooks/precommit-gate.sh $P/scripts/shared/precommit-gate.sh && cmp -s hooks/test-diff-lint.sh $P/scripts/shared/test-diff-lint.sh && cmp -s hooks/edit-ledger.py $P/scripts/shared/edit-ledger.py"
mkdir -p "$R/src/auth"; printf 'def check(u):\n    return u.role == "admin"\n' > "$R/src/auth/login.py"
out=$(printf '{"hook_event_name":"postToolUse","conversation_id":"%s","session_id":"%s","workspace_roots":["%s"],"tool_name":"Write","tool_input":{"file_path":"%s/src/auth/login.py","content":""},"tool_output":"{}"}' "$CONV" "$CONV" "$R" "$R" | bash "$S/gate-reminder.sh" 2>/dev/null); rc=$?
check "postToolUse Write on a high-risk path → ledger row (kind risk, cli cursor) + the HIGH-RISK reminder" \
  "[ $rc -eq 0 ] && grep -q '\"path\": \"src/auth/login.py\", \"kind\": \"risk\"' '$R/.rolepod/evidence/edits.jsonl' && printf '%s' \"\$out\" | grep -q 'HIGH-RISK path edited'"
printf 'x = 1\n' > "$R/src/util.py"; git -C "$R" add -A
set +e
printf '{"hook_event_name":"beforeShellExecution","conversation_id":"%s","session_id":"%s","command":"git commit -m x","cwd":"%s","workspace_roots":["%s"]}' "$CONV" "$CONV" "$R" "$R" | bash "$S/precommit-gate.sh" > "$R/../gate.json" 2>/dev/null; rc=$?
set -e
check "beforeShellExecution git commit: staged diff + ledger risk edit + 0 tests → the SHARED gate denies (permission deny, exit 2, reason names the evidence)" \
  "[ $rc -eq 2 ] && python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d[\"permission\"]==\"deny\" and d[\"agent_message\"]==d[\"user_message\"] and \"precommit-gate BLOCKED\" in d[\"agent_message\"] and \"1 high-risk edits\" in d[\"agent_message\"], d' '$R/../gate.json'"
out=$(printf '{"hook_event_name":"beforeShellExecution","conversation_id":"%s","command":"git status --short","cwd":"%s","workspace_roots":["%s"]}' "$CONV" "$R" "$R" | bash "$S/precommit-gate.sh" 2>/dev/null); rc=$?
check "beforeShellExecution non-commit → silent, rc 0" "[ $rc -eq 0 ] && [ -z \"$out\" ]"
rm -f "$R/../gate.json"

if [ $fail -eq 0 ]; then echo "cursor-adapter: pass"; exit 0; fi
echo "cursor-adapter: $fail failure(s)"
exit 1
