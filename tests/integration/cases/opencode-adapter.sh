#!/bin/bash
# opencode-adapter — structural fixture for the opencode adapter.
# Locks the verified opencode facts (opencode.ai/docs, 2026-07-28):
#   - skills are native SKILL.md; frontmatter documents only name+description
#     (rolepod's tier/phase/when_to_use are stripped at render)
#   - agents/<name>.md — the FILENAME is the agent id (no name: field);
#     frontmatter = description + mode: subagent
#   - AGENTS.md is the global rules file and carries the always-on core
#   - plugins/rolepod.js is a plain ESM module (fail-open session hygiene)
# Also exercises a full temp-target install + uninstall round-trip.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() { if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi; }

# Adapter source files present.
check "adapter opencode.json exists"    "[ -f adapters/opencode/opencode.json ]"
check "adapter AGENTS.md.tmpl exists"   "[ -f adapters/opencode/AGENTS.md.tmpl ]"
check "adapter plugin rolepod.js exists" "[ -f adapters/opencode/plugin/rolepod.js ]"

# Render the target.
bash build/render.sh --target=opencode >/dev/null 2>&1 || { echo "  ✗ render --target=opencode failed"; exit 1; }
P="build/rendered/opencode"

# Rendered structure.
check "opencode.json valid JSON"        "python3 -m json.tool $P/opencode.json >/dev/null"
check "exactly 11 skills (Core 10 + rolepod-full alias)" "[ \"\$(ls $P/skills | wc -l | tr -d ' ')\" = 11 ]"
check "15 agents present"               "[ \"\$(ls $P/agents/*.md | wc -l | tr -d ' ')\" = 15 ]"
check "plugin shim rendered"            "[ -f $P/plugin/rolepod.js ]"

# Agent frontmatter: no name: field (filename = id), mode: subagent present.
check "agent has mode: subagent"        "grep -q '^mode: subagent$' $P/agents/scout.md"
check "agent has no name: field"        "! grep -q '^name:' $P/agents/scout.md"
check "agent carries the agent protocol" "grep -q '^## Agent protocol' $P/agents/scout.md"

# Skill frontmatter stripped to name + description only.
check "skill keeps name+description"    "grep -q '^name: write-spec$' $P/skills/write-spec/SKILL.md"
check "skill drops tier field"          "! grep -q '^tier:' $P/skills/write-spec/SKILL.md"
check "skill drops phase field"         "! grep -q '^phase:' $P/skills/write-spec/SKILL.md"

# AGENTS.md carries the always-on core fragments.
check "AGENTS.md rendered"              "[ -f $P/AGENTS.md ]"
check "AGENTS.md carries Risky actions core" "grep -q '^## Risky actions' $P/AGENTS.md"
check "AGENTS.md states the enforcement tier (hooks-live partial: precommit deny + permission blocks)" "grep -q 'hooks-live (partial)' $P/AGENTS.md"
check "AGENTS.md keeps the doctrine-only remainder honest (cohesion/worktree)" "grep -q 'doctrine-only' $P/AGENTS.md"
check "rendered scout agent is mechanically read-only" "grep -q 'bash: deny' $REPO_DIR/build/rendered/opencode/agents/scout.md"
check "rendered Bash agents carry the commit ban" "grep -q '\"git commit\\*\": deny' $REPO_DIR/build/rendered/opencode/agents/backend-developer.md"

# Plugin shim is valid ESM (node syntax check) when node is available.
if command -v node >/dev/null 2>&1; then
  check "rolepod.js passes node --check" "node --check $P/plugin/rolepod.js 2>/dev/null"
else
  echo "  ~ node not on PATH — skipping JS syntax check"
fi

# ── Behavioral: precommit gate deny/allow paths ─────────────────────────
# v2.42.0 regression guard: the old COMMIT_RE adjacency regex let
# `git -C /repo commit` / `git -c k=v commit` walk past the adapter's only
# hard deny, and RISK_RE carried 19/32 canonical terms (authentication,
# authorization, authn, authz, cryptography were unreachable).
if command -v node >/dev/null 2>&1; then
  OC_FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-ocgate.XXXXXX")"
  git -C "$OC_FIX" init -q
  DRIVER="$OC_FIX/drive.mjs"
  cat > "$DRIVER" <<DRIVEREOF
import { RolepodPlugin } from 'file://$REPO_DIR/adapters/opencode/plugin/rolepod.js'
const [,, editPath, testPath, command] = process.argv
const plugin = await RolepodPlugin({ directory: process.cwd(), client: null })
if (editPath && editPath !== '-')
  await plugin['tool.execute.after']({ tool: 'edit' }, { args: { filePath: editPath } })
if (testPath && testPath !== '-')
  await plugin['tool.execute.after']({ tool: 'edit' }, { args: { filePath: testPath } })
let verdict = 'ALLOW'
try {
  await plugin['tool.execute.before']({ tool: 'bash' }, { args: { command } })
} catch (e) { verdict = String(e?.message || '').includes('rolepod precommit gate') ? 'DENY' : 'DENY-BADMSG:' + String(e?.message || '').slice(0, 60) }
console.log(verdict)
DRIVEREOF
  # v2.134.0: the gate counts the edit ledger (<repo>/.rolepod/evidence/edits.jsonl,
  # written by rolepod-shared/edit-ledger.py) — fresh ledger per driver call.
  ocg() { rm -rf "$OC_FIX/.rolepod"; (cd "$OC_FIX" && ROLEPOD_OC_SHARED="$REPO_DIR/hooks" node "$DRIVER" "$1" "$2" "$3" 2>/dev/null); }
  check "oc-gate: risk edit + git commit → deny"           "[ \"\$(ocg auth/login.py - 'git commit -m x')\" = DENY ]"
  check "oc-gate: flag-separated git -C commit → deny"     "[ \"\$(ocg auth/login.py - 'git -C /repo commit -m x')\" = DENY ]"
  check "oc-gate: git -c k=v commit → deny"                "[ \"\$(ocg auth/login.py - 'git -c user.email=x@y commit -m x')\" = DENY ]"
  check "oc-gate: /usr/bin/git commit → deny"              "[ \"\$(ocg auth/login.py - '/usr/bin/git commit -m x')\" = DENY ]"
  for t in authentication authorization authn authz cryptography; do
    check "oc-gate: $t path reaches the gate"              "[ \"\$(ocg src/$t/x.py - 'git commit -m x')\" = DENY ]"
  done
  check "oc-gate: git log → allow"                         "[ \"\$(ocg auth/login.py - 'git log --oneline')\" = ALLOW ]"
  check "oc-gate: normal path commit → allow"              "[ \"\$(ocg docs/notes.md - 'git commit -m x')\" = ALLOW ]"
  check "oc-gate: risk + test evidence → allow"            "[ \"\$(ocg auth/login.py tests/test_x.py 'git commit -m x')\" = ALLOW ]"
  check "oc-gate: the edits landed in the ledger (risk + test rows, cli opencode)" "grep -q '\"path\": \"auth/login.py\", \"kind\": \"risk\"' $OC_FIX/.rolepod/evidence/edits.jsonl && grep -q '\"kind\": \"test\"' $OC_FIX/.rolepod/evidence/edits.jsonl && grep -q '\"cli\": \"opencode\"' $OC_FIX/.rolepod/evidence/edits.jsonl"
  check "oc-gate: ROLEPOD_GATES_SOFT logs bypass, no deny" "[ \"\$(ROLEPOD_GATES_SOFT=1 ocg auth/login.py - 'git commit -m x')\" = ALLOW ] && grep -q opencode-precommit-gate '$OC_FIX/.rolepod/evidence/bypass.log'"
  # ── Behavioral: shared cores behind the translator (v2.133.0) ─────────
  # sweep-nudge / fix-loop-breaker are the Claude scripts in hooks/, run via
  # ROLEPOD_OC_SHARED; the nudge must land INSIDE output.output (the string the
  # model reads) — once per turn — and never break a tool call.
  DRIVER2="$OC_FIX/cores.mjs"
  cat > "$DRIVER2" <<DRIVEREOF
import { RolepodPlugin } from 'file://$REPO_DIR/adapters/opencode/plugin/rolepod.js'
const sid = 'oc-cores-test-' + process.pid
const plugin = await RolepodPlugin({ directory: process.cwd(), client: null })
const after = (tool, args, output, metadata) => { const o = { title: tool, output, metadata: metadata || {} }; return plugin['tool.execute.after']({ tool, sessionID: sid, callID: 'c', args }, o).then(() => o.output) }
const res = {}
await plugin['chat.message']({ sessionID: sid }, { message: {}, parts: [{ type: 'text', text: 'go' }] })
let o1 = await after('read', { filePath: '/tmp/a' }, 'x'.repeat(70000))
let o2 = await after('read', { filePath: '/tmp/b' }, 'y'.repeat(70000))
let o3 = await after('grep', { pattern: 'q' }, 'z'.repeat(1000))
res.sweep1 = o1.includes('⟂ sweep'); res.sweep2 = o2.includes('⟂ sweep: ~136 KB'); res.sweep3 = o3.includes('⟂ sweep')
await plugin['chat.message']({ sessionID: sid }, { message: {}, parts: [{ type: 'text', text: 'again' }] })
await after('write', { filePath: '/tmp/c' }, 'ok')
let o4 = await after('read', { filePath: '/tmp/a' }, 'x'.repeat(200000))
res.sweepAfterEdit = o4.includes('⟂ sweep')
let l1 = await after('bash', { command: 'npm test' }, 'FAIL', { exit: 1 })
let l2 = await after('bash', { command: 'npm test' }, 'FAIL', { exit: 1 })
let l3 = await after('bash', { command: 'npm test' }, 'FAIL', { exit: 1 })
res.loop2 = l2.includes('LOOP BREAKER'); res.loop3 = l3.includes('LOOP BREAKER')
let l4 = await after('bash', { command: 'npm test' }, 'PASS', { exit: 0 })
res.loopReset = l4.includes('LOOP BREAKER')
let plain = await after('bash', { command: 'echo hi' }, 'hi', { exit: 0 })
res.plainUntouched = plain === 'hi'
console.log(JSON.stringify(res))
DRIVEREOF
  CORES=$(cd "$OC_FIX" && ROLEPOD_OC_SHARED="$REPO_DIR/hooks" node "$DRIVER2" 2>/dev/null); rm -f "${TMPDIR:-/tmp}"/rolepod-sweep-oc-cores-test-*.json "${TMPDIR:-/tmp}"/rolepod-loopbreak-oc-cores-test-*.json
  ocv() { printf '%s' "$CORES" | python3 -I -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('$1') is $2 else 1)"; }
  check "oc-cores: first 70 KB read → no nudge; second (136 KB) → '⟂ sweep' appended to the tool result; third → silent" "ocv sweep1 False && ocv sweep2 True && ocv sweep3 False"
  check "oc-cores: chat.message resets, an edit suppresses the sweep for the turn" "ocv sweepAfterEdit False"
  check "oc-cores: same bash command failing 3× (metadata.exit) → LOOP BREAKER on the third result only" "ocv loop2 False && ocv loop3 True"
  check "oc-cores: a passing run resets the loop counter; plain output untouched" "ocv loopReset False && ocv plainUntouched True"
  check "oc-cores: missing shared dir → tool results untouched (fail open)" "[ \"\$(cd $OC_FIX && ROLEPOD_OC_SHARED=/nonexistent node $DRIVER2 2>/dev/null | python3 -I -c 'import json,sys; d=json.load(sys.stdin); print(all(v is False for k,v in d.items() if k!=\"plainUntouched\") and d[\"plainUntouched\"])')\" = True ]"
  rm -rf "$OC_FIX"
else
  echo "  ~ node not on PATH — skipping opencode gate behavior checks"
fi

check "install.sh wires --target=opencode" "grep -q 'opencode_selected' install.sh"

# Full install + uninstall round-trip against a temp target.
TMP_OC="$(mktemp -d)"
trap 'rm -rf "$TMP_OC"' EXIT
if ROLEPOD_OPENCODE_TARGET="$TMP_OC" ./install.sh --target=opencode --force --yes >/dev/null 2>&1; then
  check "installed skills/using-rolepod"  "[ -f $TMP_OC/skills/using-rolepod/SKILL.md ]"
  check "installed 15 agents"             "[ \"\$(ls $TMP_OC/agents/*.md | wc -l | tr -d ' ')\" = 15 ]"
  check "installed plugins/rolepod.js"    "[ -f $TMP_OC/plugins/rolepod.js ]"
  check "installed plugins/rolepod-shared/ = the two hook cores, byte-identical" "cmp -s hooks/sweep-nudge.sh $TMP_OC/plugins/rolepod-shared/sweep-nudge.sh && cmp -s hooks/fix-loop-breaker.sh $TMP_OC/plugins/rolepod-shared/fix-loop-breaker.sh"
  check "installed AGENTS.md managed block" "grep -q 'rolepod:start' $TMP_OC/AGENTS.md"
  check "installed version stamp"         "[ -f $TMP_OC/rolepod-version.json ]"
  if ROLEPOD_OPENCODE_TARGET="$TMP_OC" ./install.sh --target=opencode --uninstall --yes >/dev/null 2>&1; then
    check "uninstall removed skills"      "[ ! -d $TMP_OC/skills/using-rolepod ]"
    check "uninstall removed plugin shim" "[ ! -f $TMP_OC/plugins/rolepod.js ]"
    check "uninstall removed plugins/rolepod-shared/" "[ ! -d $TMP_OC/plugins/rolepod-shared ]"
    check "uninstall stripped managed block" "! grep -q 'rolepod:start' $TMP_OC/AGENTS.md 2>/dev/null || [ ! -f $TMP_OC/AGENTS.md ]"
  else
    echo "  ✗ uninstall --target=opencode failed"; fail=$((fail+1))
  fi
else
  echo "  ✗ install --target=opencode (temp target) failed"; fail=$((fail+1))
fi

if [ $fail -eq 0 ]; then echo "opencode-adapter: pass"; exit 0; fi
echo "opencode-adapter: $fail failure(s)"
exit 1
