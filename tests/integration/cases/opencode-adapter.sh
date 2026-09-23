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
check "exactly 13 skills (Core 10 + 2 commands + 1 on-demand)" "[ \"\$(ls $P/skills | wc -l | tr -d ' ')\" = 13 ]"
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
  # v2.157.0: dual export — opencode 2.x needs a `default` definition
  # (`PluginModule.LoadError` otherwise); opencode 1.x still wants the
  # named export.
  check "rolepod.js exports both entry points (default.id=rolepod + setup fn, named RolepodPlugin fn)" \
    "node -e \"import('file://$REPO_DIR/adapters/opencode/plugin/rolepod.js').then(m=>{if(m.default?.id!=='rolepod'||typeof m.default?.setup!=='function'||typeof m.RolepodPlugin!=='function')process.exit(1)})\""
  check "no process.cwd() fallback inside the v2 setup() (directory must come from ctx.location)" \
    "! awk '/^export default/{f=1} f' $REPO_DIR/adapters/opencode/plugin/rolepod.js | grep -q 'process.cwd()'"
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
  ocg() { rm -rf "$OC_FIX/.rolepod"; (cd "$OC_FIX" && ROLEPOD_OC_SHARED="$REPO_DIR/build/rendered/opencode/plugin/rolepod-shared" node "$DRIVER" "$1" "$2" "$3" 2>/dev/null); }
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
// v2.135.0: task → dispatch-proof line; session.idle → route line via the SDK client (faked here).
await after('task', { subagent_type: 'qa-tester', description: 'review', prompt: 'review it' }, '<task_result>ok</task_result>')
const fs = await import('node:fs')
const log = process.cwd() + '/.rolepod/evidence/phase-log.jsonl'
res.dispatchProof = fs.existsSync(log) && fs.readFileSync(log, 'utf8').includes('"phase":"dispatch-proof","cli":"opencode","agent_type":"qa-tester"')
const fakeClient = { session: { messages: async () => ({ data: [
  { info: { role: 'user' }, parts: [{ type: 'text', text: 'fix the login bug' }] },
  { info: { role: 'assistant' }, parts: [{ type: 'text', text: 'Route: R2 (one file + test) → implement-plan · one handler' }] },
] }) } }
const plugin2 = await RolepodPlugin({ directory: process.cwd(), client: fakeClient })
await plugin2.event({ event: { type: 'session.created', properties: { info: { id: 'ses-route-test' } } } })
await plugin2['chat.message']({ sessionID: 'ses-route-test' }, { message: {}, parts: [{ type: 'text', text: 'fix the login bug' }] })
await plugin2.event({ event: { type: 'session.created', properties: { info: { id: 'ses-child-task' } } } })   // a task subagent's session must not shadow the Lead's
await plugin2.event({ event: { type: 'session.idle', properties: { sessionID: 'ses-child-task' } } })
await plugin2.event({ event: { type: 'session.idle', properties: { sessionID: 'ses-route-test' } } })
res.routeLine = fs.readFileSync(log, 'utf8').includes('"phase":"route","tier":"R2","skill":"implement-plan"')
await plugin2.event({ event: { type: 'session.idle', properties: { sessionID: 'ses-route-test' } } })
res.routeOnce = (fs.readFileSync(log, 'utf8').match(/"phase":"route"/g) || []).length === 1
console.log(JSON.stringify(res))
DRIVEREOF
  CORES=$(cd "$OC_FIX" && ROLEPOD_OC_SHARED="$REPO_DIR/build/rendered/opencode/plugin/rolepod-shared" node "$DRIVER2" 2>/dev/null); rm -f "${TMPDIR:-/tmp}"/rolepod-sweep-oc-cores-test-*.json "${TMPDIR:-/tmp}"/rolepod-loopbreak-oc-cores-test-*.json
  ocv() { printf '%s' "$CORES" | python3 -I -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('$1') is $2 else 1)"; }
  check "oc-cores: first 70 KB read → no nudge; second (136 KB) → '⟂ sweep' appended to the tool result; third → silent" "ocv sweep1 False && ocv sweep2 True && ocv sweep3 False"
  check "oc-cores: chat.message resets, an edit suppresses the sweep for the turn" "ocv sweepAfterEdit False"
  check "oc-cores: same bash command failing 3× (metadata.exit) → LOOP BREAKER on the third result only" "ocv loop2 False && ocv loop3 True"
  check "oc-cores: a passing run resets the loop counter; plain output untouched" "ocv loopReset False && ocv plainUntouched True"
  check "oc-cores: task → dispatch-proof phase-log line (cli opencode, agent_type qa-tester)" "ocv dispatchProof True"
  check "oc-cores: session.idle → the turn's route line via the SDK messages (once per prompt)" "ocv routeLine True && ocv routeOnce True"
  check "oc-cores: missing shared dir → tool results untouched (fail open)" "[ \"\$(cd $OC_FIX && rm -rf .rolepod && ROLEPOD_OC_SHARED=/nonexistent node $DRIVER2 2>/dev/null | python3 -I -c 'import json,sys; d=json.load(sys.stdin); print(all(v is False for k,v in d.items() if k not in (\"plainUntouched\",\"dispatchProof\")) and d[\"plainUntouched\"] and d[\"dispatchProof\"])')\" = True ]"
  rm -rf "$OC_FIX"

  # ── Behavioral: opencode 2.x default export (v2.157.0) ────────────────
  # A fake ctx that mirrors the v2 contract measured against opencode
  # 2.0.12 (docs/rolepod/handoffs/opencode-v2-migration-2026-09-22.md):
  # tool.list/tool.hook/session.hook record their registrations and can
  # invoke them directly; event.subscribe is an async generator fed from
  # a push queue (mirrors ctx.event.subscribe's global stream); HOME is
  # overridden so the session lock lands under a fake home, never the
  # real one.
  OC_FIX2="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-ocv2.XXXXXX")"
  FAKEHOME2="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-ocv2home.XXXXXX")"
  git -C "$OC_FIX2" init -q
  DRIVERV2="$OC_FIX2/v2.mjs"
  cat > "$DRIVERV2" <<'DRIVEREOF'
import { createHash } from "node:crypto"
import * as fs from "node:fs"
import * as path from "node:path"
import { execSync } from "node:child_process"
const REPO_DIR = process.env.ROLEPOD_REPO_DIR
const mod = await import("file://" + REPO_DIR + "/adapters/opencode/plugin/rolepod.js")
const plugin = mod.default
const DIR = process.cwd()
function makeStream() {
  const queue = []
  let waiter = null
  let capturedSignal = null
  return {
    push(ev) { if (waiter) { const w = waiter; waiter = null; w({ value: ev, done: false }) } else queue.push(ev) },
    get signal() { return capturedSignal },
    subscribe({ signal }) {
      capturedSignal = signal
      const iterator = {
        async next() {
          if (queue.length) return { value: queue.shift(), done: false }
          if (signal.aborted) return { value: undefined, done: true }
          return new Promise((resolve) => {
            waiter = resolve
            signal.addEventListener("abort", () => { waiter = null; resolve({ value: undefined, done: true }) }, { once: true })
          })
        },
      }
      return { [Symbol.asyncIterator]: () => iterator }
    },
  }
}
const hooks = { tool: {}, session: {} }
const stream = makeStream()
const ctx = {
  location: { directory: DIR },
  tool: { hook: async (name, cb) => { (hooks.tool[name] ??= []).push(cb) } },
  session: { hook: async (name, cb) => { (hooks.session[name] ??= []).push(cb) } },
  event: { subscribe: (opts) => stream.subscribe(opts) },
}
async function before(tool, input, sessionID = "s") {
  for (const cb of hooks.tool["execute.before"] || []) await cb({ tool, input, sessionID, agent: "build", messageID: "m", id: "c" })
}
async function after(tool, input, result, sessionID = "s") {
  const e = { tool, input, sessionID, agent: "build", messageID: "m", id: "c", status: "completed", result }
  for (const cb of hooks.tool["execute.after"] || []) await cb(e)
  return e.result
}
async function prompt(sessionID, text) {
  for (const cb of hooks.session["prompt"] || []) await cb({ sessionID, messageID: "m", prompt: { text, files: [] }, delivery: "steer" })
}
async function context(sessionID, messages) {
  const e = { sessionID, model: "m", system: [{ type: "text", text: "sys" }], messages, agent: "build", tools: {} }
  for (const cb of hooks.session["context"] || []) await cb(e)
  return e
}
function tick() { return new Promise((r) => setTimeout(r, 5)) }
function wipeLedger() { fs.rmSync(path.join(DIR, ".rolepod"), { recursive: true, force: true }) }
function lockDir() {
  const worktree = execSync("git rev-parse --show-toplevel", { cwd: DIR }).toString().trim()
  const hash = createHash("sha256").update(worktree).digest("hex").slice(0, 16)
  return path.join(process.env.HOME, ".rolepod", "session-locks", hash)
}
function phaseLog() {
  try { return fs.readFileSync(path.join(DIR, ".rolepod", "evidence", "phase-log.jsonl"), "utf8") } catch { return "" }
}
const res = {}
const cleanup = await plugin.setup(ctx)
res.setupReturnsCleanup = typeof cleanup === "function"
// (2) gate
wipeLedger()
await after("edit", { path: "auth/login.py" }, { content: "ok" })
try { await before("shell", { command: "git commit -m x" }); res.gateRisk = "ALLOW" } catch (e) { res.gateRisk = String(e?.message || "").includes("rolepod precommit gate") ? "DENY" : "BADMSG" }
wipeLedger()
await after("edit", { path: "auth/login.py" }, { content: "ok" })
try { await before("shell", { command: "git -C /repo commit -m x" }); res.gateFlagC = "ALLOW" } catch (e) { res.gateFlagC = String(e?.message || "").includes("rolepod precommit gate") ? "DENY" : "BADMSG" }
wipeLedger()
await after("edit", { path: "auth/login.py" }, { content: "ok" })
try { await before("shell", { command: "git log --oneline" }); res.gateLog = "ALLOW" } catch { res.gateLog = "DENY" }
wipeLedger()
await after("edit", { path: "docs/notes.md" }, { content: "ok" })
try { await before("shell", { command: "git commit -m x" }); res.gateNormalPath = "ALLOW" } catch { res.gateNormalPath = "DENY" }
wipeLedger()
await after("edit", { path: "auth/login.py" }, { content: "ok" })
await after("edit", { path: "tests/test_x.py" }, { content: "ok" })
try { await before("shell", { command: "git commit -m x" }); res.gateWithTest = "ALLOW" } catch { res.gateWithTest = "DENY" }
wipeLedger()
await after("edit", { path: "auth/login.py" }, { content: "ok" })
process.env.ROLEPOD_GATES_SOFT = "1"
try { await before("shell", { command: "git commit -m x" }); res.gateSoft = "ALLOW" } catch { res.gateSoft = "DENY" }
delete process.env.ROLEPOD_GATES_SOFT
res.bypassLogged = fs.existsSync(path.join(DIR, ".rolepod", "evidence", "bypass.log")) &&
  fs.readFileSync(path.join(DIR, ".rolepod", "evidence", "bypass.log"), "utf8").includes("opencode-precommit-gate")
// leave a risk + test row on disk for the bash-side ledger-content check
wipeLedger()
await after("edit", { path: "auth/login.py" }, { content: "ok" })
await after("edit", { path: "tests/test_x.py" }, { content: "ok" })
// (3) sweep
const sidSweep = "sweep-sess"
await prompt(sidSweep, "go")
let r1 = await after("read", { path: "/tmp/a" }, { content: "x".repeat(70000) }, sidSweep)
let r2 = await after("read", { path: "/tmp/b" }, { content: "y".repeat(70000) }, sidSweep)
let r3 = await after("grep", { pattern: "q" }, { content: "z".repeat(1000) }, sidSweep)
res.sweep1 = String(r1.content).includes("⟂ sweep")
res.sweep2 = String(r2.content).includes("⟂ sweep: ~136 KB")
res.sweep3 = String(r3.content).includes("⟂ sweep")
await prompt(sidSweep, "again")
await after("write", { path: "/tmp/c", content: "x" }, { content: "ok" }, sidSweep)
let r4 = await after("read", { path: "/tmp/a" }, { content: "x".repeat(200000) }, sidSweep)
res.sweepAfterEdit = String(r4.content).includes("⟂ sweep")
// (4) loop breaker
const sidLoop = "loop-sess"
let l1 = await after("shell", { command: "npm test" }, { content: "FAIL", metadata: { exit: 1 } }, sidLoop)
let l2 = await after("shell", { command: "npm test" }, { content: "FAIL", metadata: { exit: 1 } }, sidLoop)
let l3 = await after("shell", { command: "npm test" }, { content: "FAIL", metadata: { exit: 1 } }, sidLoop)
res.loop2 = String(l2.content).includes("LOOP BREAKER")
res.loop3 = String(l3.content).includes("LOOP BREAKER")
let l4 = await after("shell", { command: "npm test" }, { content: "PASS", metadata: { exit: 0 } }, sidLoop)
res.loopReset = String(l4.content).includes("LOOP BREAKER")
let plain = await after("shell", { command: "echo hi" }, { content: "hi", metadata: { exit: 0 } }, sidLoop)
res.plainUntouched = plain.content === "hi"
// (5) subagent dispatch proof
await after("subagent", { agent: "qa-tester", description: "review", prompt: "review it" }, { content: "ok" })
res.dispatchProof = phaseLog().includes('"phase":"dispatch-proof","cli":"opencode","agent_type":"qa-tester"')
// (6) lock + sibling
const sidA = "ses-A"
await prompt(sidA, "hello")
await tick()
const ld = lockDir()
res.lockAExists = fs.existsSync(path.join(ld, `${sidA}.lock`))
res.parentActiveExists = fs.existsSync(path.join(DIR, ".rolepod", "parent-active"))
const lockCountAfterFirst = fs.readdirSync(ld).filter((f) => f.endsWith(".lock")).length
await prompt(sidA, "hello again")
const lockCountAfterSecond = fs.readdirSync(ld).filter((f) => f.endsWith(".lock")).length
res.stillOneLock = lockCountAfterSecond === lockCountAfterFirst
fs.mkdirSync(ld, { recursive: true })
fs.writeFileSync(path.join(ld, "sibling-x.lock"), "")
const sidB = "ses-B"
await prompt(sidB, "hi")
let cx1 = await context(sidB, [{ id: "m1", role: "user", content: [{ type: "text", text: "hi" }] }])
res.siblingPushedOnce = cx1.system.filter((p) => String(p.text || "").includes("sibling session")).length === 1
let cx2 = await context(sidB, [{ id: "m1", role: "user", content: [{ type: "text", text: "hi" }] }])
res.siblingNotPushedTwice = cx2.system.filter((p) => String(p.text || "").includes("sibling session")).length === 0
// (7) reanchor
stream.push({ type: "session.created", data: { location: { directory: DIR }, sessionID: sidA } })
await tick()
stream.push({ type: "session.compaction.ended", data: { sessionID: sidA } })
await tick()
let cx3 = await context(sidA, [{ id: "m1", role: "user", content: [{ type: "text", text: "hi" }] }])
res.reanchorPushedOnce = cx3.system.filter((p) => String(p.text || "").includes("post-compact re-anchor")).length === 1
let cx4 = await context(sidA, [{ id: "m1", role: "user", content: [{ type: "text", text: "hi" }] }])
res.reanchorNotPushedTwice = cx4.system.filter((p) => String(p.text || "").includes("post-compact re-anchor")).length === 0
// (7b) reanchor for a session the event stream never announced with
// session.created (e.g. it predates a service restart) — its own prompt
// hook call (instance-scoped, unlike the global event stream) already
// seeded `sessions` for it, so the later compaction event still arms.
const sidUnseen = "ses-unseen"
await prompt(sidUnseen, "hi")
stream.push({ type: "session.compaction.ended", data: { sessionID: sidUnseen } })
await tick()
let cx5 = await context(sidUnseen, [{ id: "m1", role: "user", content: [{ type: "text", text: "hi" }] }])
res.reanchorUnseenSession = cx5.system.filter((p) => String(p.text || "").includes("post-compact re-anchor")).length === 1
// (8) route
const sidRoute = "ses-route"
await prompt(sidRoute, "fix the login bug")
const routeMessages = [
  { id: "u1", role: "user", content: [{ type: "text", text: "fix the login bug" }] },
  { id: "a1", role: "assistant", content: [{ type: "text", text: "Route: R2 (one file + test) → implement-plan · one handler" }] },
  { id: "u2", role: "user", content: [{ type: "text", text: "next" }] },
]
await context(sidRoute, routeMessages)
res.routeOnce1 = (phaseLog().match(/"phase":"route"/g) || []).length === 1
await context(sidRoute, routeMessages)
res.routeOnce2 = (phaseLog().match(/"phase":"route"/g) || []).length === 1
// (9) cross-directory + child sessions
stream.push({ type: "session.created", data: { location: { directory: "/somewhere/else" }, sessionID: "other-dir-sess" } })
await tick()
stream.push({ type: "session.created", data: { location: { directory: DIR }, sessionID: "lead-sess" } })
await tick()
stream.push({ type: "session.created", data: { sessionID: "child-sess", parentID: "lead-sess" } })
await tick()
const lockCountBefore = fs.readdirSync(ld).filter((f) => f.endsWith(".lock")).length
await prompt("child-sess", "do the subtask")
const lockCountAfter = fs.readdirSync(ld).filter((f) => f.endsWith(".lock")).length
res.childNoLock = lockCountAfter === lockCountBefore
const routeCountBefore = (phaseLog().match(/"phase":"route"/g) || []).length
await context("child-sess", routeMessages)
const routeCountAfter = (phaseLog().match(/"phase":"route"/g) || []).length
res.childNoRoute = routeCountAfter === routeCountBefore
stream.push({ type: "session.compaction.ended", data: { sessionID: "other-dir-sess" } })
await tick()
let cxOther = await context("other-dir-sess", [{ id: "m1", role: "user", content: [{ type: "text", text: "hi" }] }])
res.otherDirNoReanchor = cxOther.system.filter((p) => String(p.text || "").includes("post-compact re-anchor")).length === 0
// (10) cleanup aborts the subscribe signal
res.signalAbortedBefore = stream.signal.aborted
await cleanup()
res.signalAbortedAfter = stream.signal.aborted
console.log(JSON.stringify(res))
DRIVEREOF
  V2RES=$(cd "$OC_FIX2" && HOME="$FAKEHOME2" ROLEPOD_REPO_DIR="$REPO_DIR" ROLEPOD_OC_SHARED="$REPO_DIR/build/rendered/opencode/plugin/rolepod-shared" node "$DRIVERV2" 2>/dev/null)
  ocv2() { printf '%s' "$V2RES" | python3 -I -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('$1') == $2 else 1)"; }
  check "oc-v2 gate: risk edit + shell 'git commit' → deny" "ocv2 gateRisk '\"DENY\"'"
  check "oc-v2 gate: flag-separated git -C commit → deny" "ocv2 gateFlagC '\"DENY\"'"
  check "oc-v2 gate: git log → allow" "ocv2 gateLog '\"ALLOW\"'"
  check "oc-v2 gate: normal path commit → allow" "ocv2 gateNormalPath '\"ALLOW\"'"
  check "oc-v2 gate: risk + test evidence → allow" "ocv2 gateWithTest '\"ALLOW\"'"
  check "oc-v2 gate: ROLEPOD_GATES_SOFT logs bypass, no deny" "ocv2 gateSoft '\"ALLOW\"' && ocv2 bypassLogged True"
  check "oc-v2: the edits landed in the ledger (risk + test rows, cli opencode)" "grep -q '\"path\": \"auth/login.py\", \"kind\": \"risk\"' $OC_FIX2/.rolepod/evidence/edits.jsonl && grep -q '\"kind\": \"test\"' $OC_FIX2/.rolepod/evidence/edits.jsonl && grep -q '\"cli\": \"opencode\"' $OC_FIX2/.rolepod/evidence/edits.jsonl"
  check "oc-v2 sweep: first 70 KB read → no nudge; second (136 KB) → '⟂ sweep' text part; third → silent" "ocv2 sweep1 False && ocv2 sweep2 True && ocv2 sweep3 False"
  check "oc-v2 sweep: a new prompt resets, an edit suppresses the sweep for the turn" "ocv2 sweepAfterEdit False"
  check "oc-v2 loop breaker: same shell command failing 3× (metadata.exit) → LOOP BREAKER on the third result only" "ocv2 loop2 False && ocv2 loop3 True"
  check "oc-v2 loop breaker: a passing run resets the counter; plain output untouched" "ocv2 loopReset False && ocv2 plainUntouched True"
  check "oc-v2: subagent tool → dispatch-proof phase-log line (cli opencode, agent_type qa-tester)" "ocv2 dispatchProof True"
  check "oc-v2: first prompt for a session → session lock + parent-active marker; a second prompt keeps one lock" "ocv2 lockAExists True && ocv2 parentActiveExists True && ocv2 stillOneLock True"
  check "oc-v2: a pre-placed sibling lock → ONE 'sibling session' text part on the next context call, none on the following one" "ocv2 siblingPushedOnce True && ocv2 siblingNotPushedTwice True"
  check "oc-v2: session.compaction.ended → the re-anchor text pushed once on the next context call, not the one after" "ocv2 reanchorPushedOnce True && ocv2 reanchorNotPushedTwice True"
  check "oc-v2: a compaction event for a session the event stream never announced still re-anchors (the prompt hook already seeded it)" "ocv2 reanchorUnseenSession True"
  check "oc-v2: a context call's trailing messages record the route line once; a second context call in the same turn adds no more" "ocv2 routeOnce1 True && ocv2 routeOnce2 True"
  check "oc-v2: a session.created for another directory or with parentID set never locks or routes" "ocv2 childNoLock True && ocv2 childNoRoute True && ocv2 otherDirNoReanchor True"
  check "oc-v2: setup() returns a cleanup that aborts the event.subscribe signal" "ocv2 setupReturnsCleanup True && ocv2 signalAbortedBefore False && ocv2 signalAbortedAfter True"

  DRIVERV2FO="$OC_FIX2/v2-failopen.mjs"
  cat > "$DRIVERV2FO" <<'DRIVEREOF'
import * as fs from "node:fs"
import * as path from "node:path"
const REPO_DIR = process.env.ROLEPOD_REPO_DIR
const mod = await import("file://" + REPO_DIR + "/adapters/opencode/plugin/rolepod.js")
const plugin = mod.default
const DIR = process.cwd()
const hooks = { tool: {}, session: {} }
const ctx = {
  location: { directory: DIR },
  tool: { hook: async (name, cb) => { (hooks.tool[name] ??= []).push(cb) } },
  session: { hook: async (name, cb) => { (hooks.session[name] ??= []).push(cb) } },
  event: { subscribe: () => ({ [Symbol.asyncIterator]: () => ({ next: async () => ({ value: undefined, done: true }) }) }) },
}
async function before(tool, input) {
  for (const cb of hooks.tool["execute.before"] || []) await cb({ tool, input, sessionID: "s", agent: "build", messageID: "m", id: "c" })
}
async function after(tool, input, result) {
  const e = { tool, input, sessionID: "s", agent: "build", messageID: "m", id: "c", status: "completed", result }
  for (const cb of hooks.tool["execute.after"] || []) await cb(e)
  return e.result
}
await plugin.setup(ctx)
const res = {}
await after("edit", { path: "auth/login.py" }, { content: "ok" })
try { await before("shell", { command: "git commit -m x" }); res.gateAllows = true } catch { res.gateAllows = false }
let r1 = await after("read", { path: "/tmp/a" }, { content: "x".repeat(70000) })
let r2 = await after("read", { path: "/tmp/b" }, { content: "y".repeat(70000) })
res.sweepUntouched = !String(r1.content).includes("⟂") && !String(r2.content).includes("⟂")
let l = await after("shell", { command: "npm test" }, { content: "FAIL", metadata: { exit: 1 } })
res.loopUntouched = !String(l.content).includes("LOOP BREAKER")
let plain = await after("shell", { command: "echo hi" }, { content: "hi", metadata: { exit: 0 } })
res.plainUntouched = plain.content === "hi"
await after("subagent", { agent: "qa-tester" }, { content: "ok" })
res.dispatchProof = (() => { try { return fs.readFileSync(path.join(DIR, ".rolepod", "evidence", "phase-log.jsonl"), "utf8").includes('"phase":"dispatch-proof"') } catch { return false } })()
console.log(JSON.stringify(res))
DRIVEREOF
  OC_FIX2B="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-ocv2fo.XXXXXX")"
  git -C "$OC_FIX2B" init -q
  V2FO=$(cd "$OC_FIX2B" && ROLEPOD_REPO_DIR="$REPO_DIR" ROLEPOD_OC_SHARED=/nonexistent node "$DRIVERV2FO" 2>/dev/null)
  ocv2fo() { printf '%s' "$V2FO" | python3 -I -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('$1') == $2 else 1)"; }
  # v2 fail-open: the ledger lives behind ROLEPOD_OC_SHARED too, so a
  # broken SHARED path makes the count read as 0/0 — the gate falls open
  # (allow) on the same "unknown/unreachable evidence -> never block" rule
  # the v1 fail-open case asserts; sweep/loop stay silent; the dispatch-proof
  # write is plain fs and never touches SHARED.
  check "oc-v2: missing shared dir → ledger unreachable so the gate allows; sweep/loop untouched; dispatch-proof still recorded; plain output untouched" \
    "ocv2fo gateAllows True && ocv2fo sweepUntouched True && ocv2fo loopUntouched True && ocv2fo plainUntouched True && ocv2fo dispatchProof True"
  rm -rf "$OC_FIX2" "$FAKEHOME2" "$OC_FIX2B"
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
