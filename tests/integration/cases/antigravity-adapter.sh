#!/bin/bash
# antigravity-adapter — structural + behavioural fixture for the agy adapter.
# Locks the agy plugin hook contract MEASURED LIVE on agy 1.2.3 (2026-09-16):
#   - plugin hooks.json lives at the PLUGIN ROOT (not hooks/hooks.json)
#   - hook events sit under ONE name key: {"rolepod": {PreInvocation, PreToolUse,
#     Stop}} — the flat top-level form (v2.6 → v2.130) never parsed on agy ≥1.1
#     ("cannot unmarshal array into Go struct field .PreInvocation") and no
#     rolepod hook ever fired there
#   - commands are RELATIVE to the hooks.json directory (`hooks/x.sh`);
#     ${extensionPath} is passed through literally
#   - stdin is camelCase (toolCall.name/args, workspacePaths, conversationId);
#     a PreToolUse result is {decision, reason} or NOTHING — `{}` denies, any
#     other field is a hook error that also blocks the tool
#   - AGENTS.md is the agy context file and carries the always-on core fragments
# If `agy` is on PATH, also runs the deterministic `agy plugin validate`.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() { if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi; }

# Render the target.
bash build/render.sh --target=antigravity >/dev/null 2>&1 || { echo "  ✗ render --target=antigravity failed"; exit 1; }
P="build/rendered/antigravity/plugin"
H="$REPO_DIR/$P/hooks"

# Plugin structure.
check "rendered plugin.json present"        "[ -f $P/plugin.json ]"
check "plugin.json is valid JSON"           "python3 -m json.tool $P/plugin.json >/dev/null"
check "plugin name is rolepod"              "python3 -c \"import json;assert json.load(open('$P/plugin.json'))['name']=='rolepod'\""
check "hooks.json at PLUGIN ROOT"           "[ -f $P/hooks.json ]"
check "no stray hooks/hooks.json subpath"   "[ ! -f $P/hooks/hooks.json ]"

# hooks.json schema: ONE name key wrapping agy-native events; relative commands.
check "hooks.json valid JSON"               "python3 -m json.tool $P/hooks.json >/dev/null"
check "hooks.json = {\"rolepod\": {PreInvocation, PreToolUse, Stop}} (named wrapper, no flat events)" \
  "python3 -I -c \"import json;d=json.load(open('$P/hooks.json'));assert set(d)=={'rolepod'},set(d);assert set(d['rolepod'])=={'PreInvocation','PreToolUse','Stop'},set(d['rolepod'])\""
check "every command is hooks/<script>.sh (relative, no \${extensionPath})" \
  "python3 -I -c \"
import json,re
d=json.load(open('$P/hooks.json'))['rolepod']; cmds=[]
def walk(n):
    if isinstance(n,dict):
        for k,v in n.items():
            if k=='command': cmds.append(v)
            else: walk(v)
    elif isinstance(n,list):
        for x in n: walk(x)
walk(d)
assert cmds and all(re.fullmatch(r'hooks/[a-z-]+\\.sh', c) for c in cmds), cmds
assert len(cmds)==3, cmds\""
check "PreToolUse covers run_command (the shared commit gate) only — no edit-tool matcher" \
  "python3 -I -c \"import json;g=json.load(open('$P/hooks.json'))['rolepod']['PreToolUse'];assert [x['matcher'] for x in g]==['run_command'],g\""

# Agents: agy has no preload field and no tools grant (PRELOAD_MODE none) — the
# role's Skill Mapping loads its skill at run time.
check "4 agy agent types carry no skill grant: keys exactly {name, description, model}, no inlined preload" \
  "python3 -I -c \"
from pathlib import Path
agents = sorted(Path('$P/agents').glob('*.md'))
assert [a.stem for a in agents] == ['rolepod-builder', 'rolepod-qa', 'rolepod-reviewer', 'rolepod-scout'], [a.stem for a in agents]
for a in agents:
    text = a.read_text()
    fm = text[4:].split('\n---\n', 1)[0]
    keys = {l.split(':', 1)[0] for l in fm.splitlines() if l and not l.startswith(' ')}
    assert keys == {'name', 'description', 'model'}, (a.name, keys)
    assert '<preloaded_skill' not in text and '\n## Skill Mapping\n' in text, a.name
\""

# Behaviour against agy-shaped stdin (the rendered scripts, a throwaway repo).
R="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-agy-adapter.XXXXXX")"
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-agy-home.XXXXXX")"
export HOME="$TEST_HOME"
trap 'rm -rf "$R" "${LOCK_DIR:-}" "$TEST_HOME"' EXIT
git -C "$R" init -q; git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
mkdir -p "$R/.rolepod"
printf '{"workflow":{"mode":"full"}}\n' > "$R/.rolepod/config.json"
# The lock dir is keyed on git's toplevel (a realpath — /private/var on macOS), not the mktemp spelling.
LOCK_HASH="$(git -C "$R" rev-parse --show-toplevel | tr -d '\n' | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)"
LOCK_DIR="$HOME/.rolepod/session-locks/$LOCK_HASH"
SID="agy-adapter-test-$$"
agy_in() { printf '{"conversationId":"%s","modelName":"gemini-test-model","workspacePaths":["%s"],"transcriptPath":"/nonexistent","artifactDirectoryPath":"/nonexistent"%s}' "$SID" "$R" "${1:-}"; }
tool_in() { agy_in ",\"toolCall\":{\"name\":\"$1\",\"args\":$2}"; }

out=$(agy_in | bash "$H/session-start.sh" 2>/dev/null); rc=$?
check "session-start: silent, writes parent-active + agy-<conversationId> lock" \
  "[ $rc -eq 0 ] && [ -z \"$out\" ] && [ -f '$R/.rolepod/parent-active' ] && [ -f '$LOCK_DIR/agy-$SID.lock' ]"
check "session-start lock: line 1 = antigravity, line 2 = a numeric CLI pid" \
  "[ \"\$(sed -n 1p '$LOCK_DIR/agy-$SID.lock')\" = antigravity ] && sed -n 2p '$LOCK_DIR/agy-$SID.lock' | grep -qE '^[0-9]+\$'"

out=$(tool_in run_command "{\"CommandLine\":\"git status --short\",\"Cwd\":\"$R\"}" | bash "$H/pre-tool.sh" 2>/dev/null); rc=$?
check "pre-tool: plain shell command → NO output (silence = allow; '{}' would deny)" "[ $rc -eq 0 ] && [ -z \"$out\" ]"
out=$(tool_in view_file '{"AbsolutePath":"/x"}' | bash "$H/pre-tool.sh" 2>/dev/null); rc=$?
check "pre-tool: non-shell tool → NO output" "[ $rc -eq 0 ] && [ -z \"$out\" ]"
out=$(printf 'not json' | bash "$H/pre-tool.sh" 2>/dev/null); rc=$?
check "pre-tool: unparsable stdin → NO output, rc 0" "[ $rc -eq 0 ] && [ -z \"$out\" ]"
out=$(printf '' | bash "$H/pre-tool.sh" 2>/dev/null); rc=$?
check "pre-tool: empty stdin → NO output, rc 0" "[ $rc -eq 0 ] && [ -z \"$out\" ]"

mkdir -p "$R/docs/rolepod"; printf 'private plan\n' > "$R/docs/rolepod/plan.md"; git -C "$R" add -A
tool_in run_command "{\"CommandLine\":\"git commit -m x\",\"Cwd\":\"$R\"}" | bash "$H/pre-tool.sh" > "$R/../deny1.json" 2>/dev/null; rc=$?
check "pre-tool: git commit the shared gate denies (private docs staged) → {decision: deny, reason} and nothing else" \
  "[ $rc -eq 0 ] && python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert set(d)=={\"decision\",\"reason\"}, d; assert d[\"decision\"]==\"deny\" and \"docs/rolepod\" in d[\"reason\"]' '$R/../deny1.json'"
tool_in run_command "{\"CommandLine\":\"git commit -m x\"}" | bash "$H/pre-tool.sh" > "$R/../deny2.json" 2>/dev/null; rc=$?
check "pre-tool: no Cwd arg → falls back to workspacePaths[0] (still denies)" "[ $rc -eq 0 ] && grep -q '\"decision\": \"deny\"' '$R/../deny2.json'"
rm -f "$R/../deny1.json" "$R/../deny2.json"
git -C "$R" reset -q; rm -rf "$R/docs"

# Evidence-based gating is Claude-only now (spec Desired 10, 2026-09-25): a
# write_to_file call is not translated at all — no ledger, no verdict — and a
# high-risk diff with zero test evidence still commits clean on agy.
out=$(tool_in write_to_file "{\"TargetFile\":\"$R/src/auth/login.py\",\"CodeContent\":\"x\"}" | bash "$H/pre-tool.sh" 2>/dev/null); rc=$?
check "pre-tool: write_to_file → NO output (not translated — only run_command is)" "[ $rc -eq 0 ] && [ -z \"$out\" ]"
mkdir -p "$R/src/auth"; printf 'x = 1\n' > "$R/src/auth/login.py"; git -C "$R" add -A
out=$(tool_in run_command "{\"CommandLine\":\"git commit -m x\",\"Cwd\":\"$R\"}" | bash "$H/pre-tool.sh" 2>/dev/null); rc=$?
check "pre-tool: git commit with a staged high-risk path and 0 evidence → passes (Claude-only gate, spec Desired 10)" \
  "[ $rc -eq 0 ] && [ -z \"$out\" ]"
git -C "$R" reset -q; rm -rf "$R/src"

TRA="$R/../agy-transcript.jsonl"
printf '{"step_index":0,"source":"USER_EXPLICIT","type":"USER_INPUT","status":"DONE","created_at":"2026-01-01T00:00:00Z","content":"<USER_REQUEST>\\nrename the config loader\\n</USER_REQUEST>"}\n{"step_index":1,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","created_at":"2026-01-01T00:00:08Z","content":"Route: R1 → implement-plan · rename only"}\n' > "$TRA"
out=$(printf '{"conversationId":"%s","modelName":"m","workspacePaths":["%s"],"transcriptPath":"%s","terminationReason":"NO_TOOL_CALL"}' "$SID" "$R" "$TRA" | bash "$H/stop-unlock.sh" 2>/dev/null); rc=$?
check "stop-unlock: silent, removes exactly this session's lock, records the turn's route from transcript_full.jsonl" \
  "[ $rc -eq 0 ] && [ -z \"$out\" ] && [ ! -f '$LOCK_DIR/agy-$SID.lock' ] && grep -q '\"phase\":\"route\",\"tier\":\"R1\",\"skill\":\"implement-plan\"' '$R/.rolepod/evidence/phase-log.jsonl'"
rm -f "$TRA"
out=$(printf '{"conversationId":"x","workspacePaths":[]}' | bash "$H/session-start.sh" 2>/dev/null); rc=$?
check "session-start without a workspace (no --add-dir) → silent no-op" "[ $rc -eq 0 ] && [ -z \"$out\" ]"

# AGENTS.md is the agy context file with the always-on core fragments.
check "AGENTS.md rendered"                  "[ -f build/rendered/antigravity/AGENTS.md ]"
check "using-rolepod workflow helper bundles the canonical config reader" \
  "[ -f build/rendered/antigravity/plugin/skills/using-rolepod/scripts/rolepod_config.py ]"

# Live deterministic validation when agy is installed; else skip cleanly.
if command -v agy >/dev/null 2>&1; then
  if agy plugin validate "$P" </dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -q '\[ok\]'; then
    echo "  ✓ agy plugin validate → [ok] (agy $(agy --version 2>/dev/null | head -1))"
  else
    echo "  ✗ agy plugin validate did not report [ok]"; fail=$((fail+1))
  fi
else
  echo "  ~ agy not on PATH — skipping live validate"
fi

if [ $fail -eq 0 ]; then echo "antigravity-adapter: pass"; exit 0; fi
echo "antigravity-adapter: $fail failure(s)"
exit 1
