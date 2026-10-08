#!/bin/bash
# cursor-adapter — structural + behavioural fixture for the Cursor plugin hooks.
# Locks the Cursor hook contract MEASURED LIVE on agent CLI 2026.09.10 / IDE 3.20
# (2026-09-16):
#   - hook cwd = plugin root; ./scripts/x.sh resolves; matcher = regex on tool_name
#     (preToolUse/postToolUse) or on the literal command (beforeShellExecution)
#   - sessionStart / postToolUse carry additional_context; beforeShellExecution
#     can return agent_message for both deny and advisory allow results;
#     afterShellExecution carries command + output but NO exit code/context
#   - shell commands never raise postToolUse (before/afterShellExecution instead)
#   - stdin carries conversation_id + session_id + workspace_roots (no cwd);
#     Read's tool_output is {"file_path","content_length"} (bytes the model got)
# Consequences locked here: fix-loop-breaker + push-ref-check are NOT ported
# (no exit code); session locks are cursor-<conversation_id> and released on stop.
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
check "3 core scripts present" \
  "for f in project-context-loader precommit-gate stop-unlock; do [ -f $P/scripts/\$f.sh ] || exit 1; done"
check "no gate-reminder / dispatch-log scripts left (spec Desired 10, 2026-09-25)" \
  "[ ! -f $P/scripts/gate-reminder.sh ] && [ ! -f $P/scripts/dispatch-log.sh ]"
check "deepen-codebase keeps disable-model-invocation" \
  "grep -q '^disable-model-invocation: true$' $P/skills/deepen-codebase/SKILL.md"
check "write-spec drops when_to_use" \
  "! grep -q '^when_to_use:' $P/skills/write-spec/SKILL.md"
check "every Cursor skill frontmatter key is within {name, description, disable-model-invocation}, and only deepen-codebase and rolepod-stats carry disable-model-invocation" \
  "python3 -I -c \"
import re, sys
from pathlib import Path
allowed = {'name', 'description', 'disable-model-invocation'}
bad = []
dmi_owners = []
for skill in sorted(Path('$P/skills').glob('*/SKILL.md')):
    text = skill.read_text()
    assert text.startswith('---\n'), skill
    end = text.find('\n---\n', 4)
    fm = text[4:end]
    keys = set()
    for line in fm.split(chr(10)):
        m = re.match(r'^([A-Za-z][A-Za-z0-9_-]*):\s', line)
        if m:
            keys.add(m.group(1))
    if not keys <= allowed:
        bad.append((skill, keys - allowed))
    if 'disable-model-invocation' in keys:
        dmi_owners.append(skill.parent.name)
assert not bad, bad
assert dmi_owners == ['deepen-codebase', 'rolepod-stats'], dmi_owners
\""
check "4 Cursor agent types carry no skill grant (Skill Mapping loads at run time): keys within {name, description, readonly}, no inlined preload, readonly only on rolepod-scout (the one type with no write tool)" \
  "python3 -I -c \"
from pathlib import Path
agents = sorted(Path('$P/agents').glob('*.md'))
assert [a.stem for a in agents] == ['rolepod-builder', 'rolepod-qa', 'rolepod-reviewer', 'rolepod-scout'], [a.stem for a in agents]
ro = []
for a in agents:
    text = a.read_text()
    fm = text[4:].split('\n---\n', 1)[0]
    keys = {l.split(':', 1)[0] for l in fm.splitlines() if l and not l.startswith(' ')}
    assert keys <= {'name', 'description', 'readonly'}, (a.name, keys)
    assert '<preloaded_skill' not in text and '\n## Skill Mapping\n' in text, a.name
    if 'readonly' in keys: ro.append(a.stem)
assert ro == ['rolepod-scout'], ro
\""
check "hooks.json: 3 registrations over 3 distinct scripts, every command ./scripts/<x>.sh" \
  "python3 -I -c \"
import json,re
h=json.load(open('$HJ'))['hooks']; cmds=[(ev,r['command'],r.get('matcher','')) for ev,regs in h.items() for r in regs]
assert len(cmds)==3, cmds
assert len({c for _,c,_ in cmds})==3, cmds
assert all(re.fullmatch(r'\\./scripts/[a-z-]+\\.sh', c) for _,c,_ in cmds), cmds
assert set(h)=={'sessionStart','beforeShellExecution','stop'}, set(h)\""
check "Claude-imported hooks all self-disable when Cursor sets CURSOR_PROJECT_DIR" \
  "python3 -I -c 'import json; d=json.load(open(\"adapters/claude/hooks.json\")); hooks=[h for regs in d[\"hooks\"].values() for group in regs for h in group.get(\"hooks\",[])]; assert hooks and all(\"CURSOR_PROJECT_DIR\" in h.get(\"command\",\"\") for h in hooks)'"
check "stop-unlock sits on stop" "python3 -I -c \"import json;h=json.load(open('$HJ'))['hooks'];assert [r['command'] for r in h['stop']]==['./scripts/stop-unlock.sh']\""
PYSCRIPT=$(mktemp "${TMPDIR:-/tmp}/rolepod-cursor-matcher.XXXXXX")
cat > "$PYSCRIPT" <<PYEOF
import json, re
m = [r['matcher'] for r in json.load(open('$HJ'))['hooks']['beforeShellExecution'] if r['command'].endswith('precommit-gate.sh')][0]
rx = re.compile(m)
positive = [
    'git commit -m x',
    'git -c user.email=p@p commit -m x',
    'git add -A && git -c a=b commit -m x',
    'cd x; git status',
    "bash -lc 'git commit -m x'",
    'sh -c "git commit"',
    '/usr/bin/git commit -m x',
    '(git commit -m x)',
    '\$(git commit)',
    '"git" commit',
    "'git' commit",
]
for c in positive:
    assert rx.search(c), c
assert not rx.search('gitk'), m
assert not rx.search('echo digit'), m
assert not rx.search('my-git x'), m
print('OK')
PYEOF
set +e
MATCHER_OUT=$(python3 -I "$PYSCRIPT" 2>&1); MATCHER_RC=$?
set -e
rm -f "$PYSCRIPT"
check "precommit-gate matcher fires on ANY git command, including quoted wrappers and absolute paths (v2.180.4)" \
  "[ $MATCHER_RC -eq 0 ] && [ \"\$MATCHER_OUT\" = OK ]"

cleanup() { rm -rf "${R:-}" "${LOCK_DIR:-}" "${TEST_HOME:-}" "${NONGIT:-}" "${EMPTYGIT:-}"; }
trap cleanup EXIT

# Behaviour: session lock by conversation_id, released on stop.
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-cursor-home.XXXXXX")"
export HOME="$TEST_HOME"
R="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-cursor-adapter.XXXXXX")"
git -C "$R" init -q; git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
mkdir -p "$R/.rolepod"
printf '{"workflow":{"mode":"full"}}\n' > "$R/.rolepod/config.json"
LOCK_HASH="$(git -C "$R" rev-parse --show-toplevel | tr -d '\n' | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)"
LOCK_DIR="$HOME/.rolepod/session-locks/$LOCK_HASH"
CONV="conv-cursor-$$"
out=$(printf '{"hook_event_name":"sessionStart","conversation_id":"%s","session_id":"%s","workspace_roots":["%s"]}' "$CONV" "$CONV" "$R" | bash "$S/project-context-loader.sh" 2>/dev/null); rc=$?
check "sessionStart: profile env + visible frozen-profile context and cursor lock" \
  "[ $rc -eq 0 ] && printf '%s' \"\$out\" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"env\"][\"ROLEPOD_SESSION_MODE\"]==\"full\" and d[\"env\"][\"ROLEPOD_SESSION_CLI\"]==\"cursor\" and \"Active Rolepod workflow profile: full (source: project)\" in d[\"additional_context\"]' && [ -f '$LOCK_DIR/cursor-$CONV.lock' ] && [ -f '$R/.rolepod/parent-active' ]"
check "sessionStart lock: line 1 = cursor, line 2 = a numeric CLI pid" \
  "[ \"\$(sed -n 1p '$LOCK_DIR/cursor-$CONV.lock')\" = cursor ] && sed -n 2p '$LOCK_DIR/cursor-$CONV.lock' | grep -qE '^[0-9]+\$'"
# stop → route record from a Cursor-format transcript (v2.135.0).
TR="$R/../cursor-transcript.jsonl"
printf '{"role":"user","message":{"content":[{"type":"text","text":"<timestamp>Wednesday, Sep 16, 2026, 2:17 PM (UTC+7)</timestamp>\\n<user_query>\\nfix the login bug\\n</user_query>"}]}}\n{"role":"assistant","message":{"content":[{"type":"text","text":"Route: R2 (one file + test) → implement-plan · one handler\\n\\n[REDACTED]"}]}}\n' > "$TR"
out=$(printf '{"hook_event_name":"stop","conversation_id":"%s","session_id":"%s","workspace_roots":["%s"],"transcript_path":"%s"}' "$CONV" "$CONV" "$R" "$TR" | bash "$S/stop-unlock.sh" 2>/dev/null); rc=$?
check "stop: silent, lock released, and the turn's route line recorded from the Cursor transcript" \
  "[ $rc -eq 0 ] && [ -z \"$out\" ] && [ ! -f '$LOCK_DIR/cursor-$CONV.lock' ] && grep -q '\"phase\":\"route\",\"tier\":\"R2\",\"skill\":\"implement-plan\"' '$R/.rolepod/evidence/phase-log.jsonl'"
rm -f "$TR"

# Per-CLI breakdown (review round 2, MAJOR — same lock-name rule as
# session-lifecycle.sh and the opencode plugin): a pre-placed opencode lock
# names itself in the concurrent-session line, not just a bare count.
mkdir -p "$LOCK_DIR"; printf 'opencode\n4242' > "$LOCK_DIR/oc-sibling.lock"
CONV2="conv-cursor-b-$$"
out2=$(printf '{"hook_event_name":"sessionStart","conversation_id":"%s","session_id":"%s","workspace_roots":["%s"]}' "$CONV2" "$CONV2" "$R" | bash "$S/project-context-loader.sh" 2>/dev/null)
ctx2=$(printf '%s' "$out2" | python3 -c 'import json,sys
try: print(json.load(sys.stdin)["additional_context"])
except Exception: print("")')
check "sessionStart concurrent-session line breaks down by CLI (opencode ×1)" "printf '%s' \"\$ctx2\" | grep -q 'opencode ×1'"
rm -f "$LOCK_DIR/oc-sibling.lock" "$LOCK_DIR/cursor-$CONV2.lock"

# Behaviour: the shared commit gate behind the translator (v2.134.0); no edit
# ledger and no per-CLI verdict at write time any more (spec Desired 10, 2026-09-25).
mkdir -p "$R/src/auth"; printf 'def check(u):\n    return u.role == "admin"\n' > "$R/src/auth/login.py"
printf 'x = 1\n' > "$R/src/util.py"; git -C "$R" add -A
set +e
printf '{"hook_event_name":"beforeShellExecution","conversation_id":"%s","session_id":"%s","command":"git commit -m x","cwd":"%s","workspace_roots":["%s"]}' "$CONV" "$CONV" "$R" "$R" | bash "$S/precommit-gate.sh" > "$R/../gate.json" 2>/dev/null; rc=$?
set -e
# spec Desired 10 (2026-09-25): the HARD evidence path is Claude-native only
# — ROLEPOD_LEAD_CLI=cursor (the translator's default) skips it entirely, so
# a high-risk diff with 0 evidence now passes on Cursor (private-docs is the
# only deny left on a non-Claude CLI).
check "beforeShellExecution git commit: staged high-risk diff, 0 evidence, ROLEPOD_LEAD_CLI=cursor → the SHARED gate allows (Claude-only evidence path)" \
  "[ $rc -eq 0 ] && [ ! -s '$R/../gate.json' ]"
out=$(printf '{"hook_event_name":"beforeShellExecution","conversation_id":"%s","command":"git status --short","cwd":"%s","workspace_roots":["%s"]}' "$CONV" "$R" "$R" | bash "$S/precommit-gate.sh" 2>/dev/null); rc=$?
check "beforeShellExecution non-commit → silent, rc 0" "[ $rc -eq 0 ] && [ -z \"$out\" ]"

# criterion 6: a staged docs/rolepod/ path still denies on Cursor.
git -C "$R" reset -q; mkdir -p "$R/docs/rolepod"; printf 'plan\n' > "$R/docs/rolepod/plan.md"; git -C "$R" add -A
set +e
printf '{"hook_event_name":"beforeShellExecution","conversation_id":"%s","session_id":"%s","command":"git commit -m x","cwd":"%s","workspace_roots":["%s"]}' "$CONV" "$CONV" "$R" "$R" | bash "$S/precommit-gate.sh" > "$R/../gate2.json" 2>/dev/null; rc=$?
set -e
check "beforeShellExecution git commit: staged docs/rolepod/ path → deny" \
  "[ -s '$R/../gate2.json' ] && python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d[\"permission\"]==\"deny\" and \"docs/rolepod\" in d[\"agent_message\"]' '$R/../gate2.json'"
printf '{"workflow":{"mode":"standard"}}\n' > "$R/.rolepod/config.json"
CONV_STD="conv-cursor-standard-$$"
printf '{"hook_event_name":"sessionStart","conversation_id":"%s","session_id":"%s","workspace_roots":["%s"]}' "$CONV_STD" "$CONV_STD" "$R" | bash "$S/project-context-loader.sh" >/dev/null 2>&1
check "sessionStart stores a frozen Standard profile for the new conversation" "[ \"\$(sed -n '1p' '$HOME/.rolepod/session-profiles/cursor/$CONV_STD.mode' 2>/dev/null)\" = standard ]"
set +e
printf '{"hook_event_name":"beforeShellExecution","conversation_id":"%s","session_id":"%s","command":"git commit -m x","cwd":"%s","workspace_roots":["%s"]}' "$CONV_STD" "$CONV_STD" "$R" "$R" | bash "$S/precommit-gate.sh" > "$R/../gate-standard.json" 2>/dev/null; rc=$?
set -e
check "Standard private-docs commit: deny (private-docs denies in every mode)" \
  "[ $rc -eq 2 ] && python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d[\"permission\"]==\"deny\" and \"docs/rolepod\" in d[\"agent_message\"]' '$R/../gate-standard.json'"
printf '{"workflow":{"mode":"lite"}}\n' > "$R/.rolepod/config.json"
CONV_LITE="conv-cursor-lite-$$"
out=$(printf '{"hook_event_name":"sessionStart","conversation_id":"%s","session_id":"%s","workspace_roots":["%s"]}' "$CONV_LITE" "$CONV_LITE" "$R" | bash "$S/project-context-loader.sh" 2>/dev/null)
check "sessionStart stores a frozen Lite profile for the new conversation" "[ \"\$(sed -n '1p' '$HOME/.rolepod/session-profiles/cursor/$CONV_LITE.mode' 2>/dev/null)\" = lite ]"
check "Lite sessionStart runs the same loader as Standard: profile env/context and a session lock" \
  "printf '%s' \"\$out\" | python3 -c 'import json,sys; d=json.load(sys.stdin); c=d[\"additional_context\"]; assert d[\"env\"][\"ROLEPOD_SESSION_MODE\"]==\"lite\" and d[\"env\"][\"ROLEPOD_SESSION_SOURCE\"]==\"project\" and \"Active Rolepod workflow profile: lite\" in c' && [ -f '$LOCK_DIR/cursor-$CONV_LITE.lock' ]"
set +e
out=$(printf '{"hook_event_name":"beforeShellExecution","conversation_id":"%s","command":"git commit -m x","cwd":"%s","workspace_roots":["%s"]}' "$CONV_LITE" "$R" "$R" | bash "$S/precommit-gate.sh" 2>/dev/null); rc=$?
set -e
check "Lite private-docs commit: deny (R4 floor, every mode)" "[ $rc -eq 2 ] && printf '%s' '$out' | python3 -I -c 'import json,sys; d=json.load(sys.stdin); assert d[\"permission\"]==\"deny\" and \"docs/rolepod\" in d[\"agent_message\"]'"
printf '{"workflow":{"mode":"full"}}\n' > "$R/.rolepod/config.json"
rm -f "$R/../gate2.json"
rm -f "$R/../gate-standard.json"
rm -f "$R/../gate.json"

# v2.180.4: the SAME staged docs/rolepod/ path, but through a quoted shell
# wrapper (bash -lc 'git commit ...') piped directly into the translator —
# this never exercises the hooks.json matcher (that regex is covered by the
# check above); it proves the shared gate still unwraps a `bash -lc` string
# and denies once the command reaches it.
set +e
printf '{"hook_event_name":"beforeShellExecution","conversation_id":"%s","session_id":"%s","command":"bash -lc '\''git commit -m x'\''","cwd":"%s","workspace_roots":["%s"]}' "$CONV" "$CONV" "$R" "$R" | bash "$S/precommit-gate.sh" > "$R/../gate3.json" 2>/dev/null; rc=$?
set -e
check "beforeShellExecution bash -lc 'git commit -m x' (quoted wrapper): staged docs/rolepod/ path → deny" \
  "[ -s '$R/../gate3.json' ] && python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d[\"permission\"]==\"deny\" and \"docs/rolepod\" in d[\"agent_message\"]' '$R/../gate3.json'"
rm -f "$R/../gate3.json"

# Native profile output remains available when Git context cannot be built.
NONGIT="$R/../cursor-nongit-$$"; mkdir -p "$NONGIT"
CONV_NONGIT="conv-cursor-nongit-$$"
out=$(printf '{"hook_event_name":"sessionStart","conversation_id":"%s","workspace_roots":["%s"]}' "$CONV_NONGIT" "$NONGIT" | bash "$S/project-context-loader.sh" 2>/dev/null)
check "non-Git sessionStart returns profile env and visible profile context" \
  "printf '%s' \"\$out\" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"env\"][\"ROLEPOD_SESSION_MODE\"]==\"lite\" and d[\"env\"][\"ROLEPOD_SESSION_SOURCE\"] in (\"global\",\"default\") and (\"Active Rolepod workflow profile: lite (source: \"+d[\"env\"][\"ROLEPOD_SESSION_SOURCE\"]+\")\") in d[\"additional_context\"]'"
EMPTYGIT="$R/../cursor-empty-git-$$"; mkdir -p "$EMPTYGIT"; git -C "$EMPTYGIT" init -q
CONV_EMPTY="conv-cursor-empty-$$"
out=$(printf '{"hook_event_name":"sessionStart","conversation_id":"%s","workspace_roots":["%s"]}' "$CONV_EMPTY" "$EMPTYGIT" | bash "$S/project-context-loader.sh" 2>/dev/null)
EMPTY_HASH="$(git -C "$EMPTYGIT" rev-parse --show-toplevel | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)"
check "empty-Git sessionStart returns profile env/context without git context or a session lock" \
  "printf '%s' \"\$out\" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"env\"][\"ROLEPOD_SESSION_MODE\"]==\"lite\" and \"Active Rolepod workflow profile: lite\" in d[\"additional_context\"] and \"Recent:\" not in d[\"additional_context\"]' && [ ! -f '$HOME/.rolepod/session-locks/$EMPTY_HASH/cursor-$CONV_EMPTY.lock' ]"

LONGR="$R/../cursor-long-$$"; mkdir -p "$LONGR"; git -C "$LONGR" init -q
git -C "$LONGR" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "$(printf 'x%.0s' $(seq 1 200))"
out=$(printf '{"hook_event_name":"sessionStart","conversation_id":"conv-cursor-long-%s","workspace_roots":["%s"]}' "$$" "$LONGR" | bash "$S/project-context-loader.sh" 2>/dev/null)
check "sessionStart: a 200-char commit subject is cut to a Recent line <= 105 chars" \
  "printf '%s' \"\$out\" | python3 -c 'import json,sys; c=json.load(sys.stdin)[\"additional_context\"]; ls=[l for l in c.splitlines() if l.endswith(\"..\")]; assert ls and all(len(l)<=105 for l in ls)'"

if [ $fail -eq 0 ]; then echo "cursor-adapter: pass"; exit 0; fi
echo "cursor-adapter: $fail failure(s)"
exit 1
