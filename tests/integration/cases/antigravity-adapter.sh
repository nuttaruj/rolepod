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

# Adapter source files present.
check "adapter plugin.json exists"   "[ -f adapters/antigravity/plugin.json ]"
check "adapter AGENTS.md.tmpl exists" "[ -f adapters/antigravity/AGENTS.md.tmpl ]"
check "adapter hooks.json exists"     "[ -f adapters/antigravity/hooks/hooks.json ]"

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
check "hooks/ = 4 agy-native scripts + the shared gate pair (6 files)" \
  "[ \"\$(ls $P/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')\" = 6 ] && [ -f $P/hooks/pre-tool.sh ] && [ -f $P/hooks/precommit-gate.sh ] && [ -f $P/hooks/test-diff-lint.sh ]"
check "shared gate is byte-identical to hooks/precommit-gate.sh" "cmp -s hooks/precommit-gate.sh $P/hooks/precommit-gate.sh && cmp -s hooks/test-diff-lint.sh $P/hooks/test-diff-lint.sh"
check "no gemini context emitters left (agy has no context channel)" "[ ! -f $P/hooks/before-tool.sh ] && [ ! -f $P/hooks/after-tool.sh ] && [ ! -f $P/hooks/claim-verify-nudge.sh ]"
check "exactly 13 skills (Core 10 + 2 commands + 1 on-demand)" "[ \"\$(ls $P/skills | wc -l | tr -d ' ')\" = 13 ]"
check "15 agents present"                   "[ \"\$(ls $P/agents/*.md | wc -l | tr -d ' ')\" = 15 ]"

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
assert len(cmds)==4, cmds\""
check "PreToolUse covers run_command (gate) + the edit tools (ledger) in one registration" \
  "python3 -I -c \"import json;g=json.load(open('$P/hooks.json'))['rolepod']['PreToolUse'];assert [x['matcher'] for x in g]==['run_command|write_to_file|replace|edit|edit_file|multi_replace_file_content'],g\""
check "hooks/ ships edit-ledger.py + route_check.py byte-identical" "cmp -s hooks/edit-ledger.py $P/hooks/edit-ledger.py && cmp -s hooks/lib/route_check.py $P/hooks/route_check.py"

# Behaviour against agy-shaped stdin (the rendered scripts, a throwaway repo).
R="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-agy-adapter.XXXXXX")"
trap 'rm -rf "$R" "${LOCK_DIR:-}"' EXIT
git -C "$R" init -q; git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
# The lock dir is keyed on git's toplevel (a realpath — /private/var on macOS), not the mktemp spelling.
LOCK_HASH="$(git -C "$R" rev-parse --show-toplevel | tr -d '\n' | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)"
LOCK_DIR="$HOME/.rolepod/session-locks/$LOCK_HASH"
SID="agy-adapter-test-$$"
agy_in() { printf '{"conversationId":"%s","modelName":"gemini-test-model","workspacePaths":["%s"],"transcriptPath":"/nonexistent","artifactDirectoryPath":"/nonexistent"%s}' "$SID" "$R" "${1:-}"; }
tool_in() { agy_in ",\"toolCall\":{\"name\":\"$1\",\"args\":$2}"; }

out=$(agy_in | bash "$H/session-start.sh" 2>/dev/null); rc=$?
check "session-start: silent, writes parent-active + agy-<conversationId> lock" \
  "[ $rc -eq 0 ] && [ -z \"$out\" ] && [ -f '$R/.rolepod/parent-active' ] && [ -f '$LOCK_DIR/agy-$SID.lock' ]"
out=$(agy_in | bash "$H/model-log.sh" 2>/dev/null); rc=$?
check "model-log: silent, appends a dispatch-proof line with the hook-reported model" \
  "[ $rc -eq 0 ] && [ -z \"$out\" ] && grep -q '\"model\": \"gemini-test-model\"' '$R/.rolepod/evidence/phase-log.jsonl'"
out=$(agy_in | bash "$H/model-log.sh" 2>/dev/null)
check "model-log: same model again → no second line" "[ \"\$(grep -c dispatch-proof '$R/.rolepod/evidence/phase-log.jsonl')\" = 1 ]"

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

# Edit ledger (v2.134.0): an agy edit tool call is recorded, silently; the gate then
# reads it — a risky edit with no test edit hard-blocks the next commit.
out=$(tool_in write_to_file "{\"TargetFile\":\"$R/src/auth/login.py\",\"CodeContent\":\"x\"}" | bash "$H/pre-tool.sh" 2>/dev/null); rc=$?
check "pre-tool: write_to_file → silent + ledger row (kind risk, cli antigravity)" \
  "[ $rc -eq 0 ] && [ -z \"$out\" ] && grep -q '\"path\": \"src/auth/login.py\", \"kind\": \"risk\", \"agent\": \"\"' '$R/.rolepod/evidence/edits.jsonl' && grep -q '\"cli\": \"antigravity\"' '$R/.rolepod/evidence/edits.jsonl'"
mkdir -p "$R/src"; printf 'x = 1\n' > "$R/src/util.py"; git -C "$R" add -A
tool_in run_command "{\"CommandLine\":\"git commit -m x\",\"Cwd\":\"$R\"}" | bash "$H/pre-tool.sh" > "$R/../deny3.json" 2>/dev/null; rc=$?
check "pre-tool: git commit after a ledgered risk edit with 0 tests → deny (the HARD path that needed a transcript before)" \
  "[ $rc -eq 0 ] && python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d[\"decision\"]==\"deny\" and \"1 high-risk edits\" in d[\"reason\"], d' '$R/../deny3.json'"
rm -f "$R/../deny3.json"; git -C "$R" reset -q

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
check "AGENTS.md carries Risky actions core"   "grep -q '^## Risky actions' build/rendered/antigravity/AGENTS.md"
check "AGENTS.md carries Communication core"    "grep -q '^## Communication' build/rendered/antigravity/AGENTS.md"

# cross-family: agy is only useful with the repo as its workspace.
check "cross-family passes --add-dir to agy" "grep -q -- '--add-dir \"\$ROOT\"' scripts/cross-family.sh"

# Gemini sunset note present (bundled with this work).
check "gemini GEMINI.md.tmpl has the 2026-06-18 sunset note" \
  "grep -q '2026-06-18' adapters/gemini/GEMINI.md.tmpl"
check "install.sh wires --target=antigravity" \
  "grep -q 'antigravity_selected' install.sh"

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
