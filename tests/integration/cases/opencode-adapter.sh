#!/bin/bash
# opencode-adapter — structural fixture for the opencode adapter.
# Locks the verified opencode facts (opencode.ai docs, checked 2026-10-03):
#   - skills are native SKILL.md; frontmatter documents only name+description
#     and opencode ignores unknown keys, so the one shared skill tree ships as is
#   - agents/<name>.md — the FILENAME is the agent id (no name: field);
#     frontmatter = description + mode: subagent
#   - AGENTS.md is the global rules file and carries the always-on core
#   - plugin before-tool hooks classify child ship operations by session lookup
# Also exercises a full temp-target install + uninstall round-trip.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() { if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi; }

# Render the target.
bash build/render.sh --target=opencode >/dev/null 2>&1 || { echo "  ✗ render --target=opencode failed"; exit 1; }
P="build/rendered/opencode"

# Rendered structure.
check "opencode.json valid JSON"        "python3 -m json.tool $P/opencode.json >/dev/null"
check "plugin shim rendered"            "[ -f $P/plugin/rolepod.js ]"

# Agent frontmatter: no name: field (filename = id), mode: subagent present.
check "agent has mode: subagent"        "grep -q '^mode: subagent$' $P/agents/rolepod-scout.md"
check "agent has no name: field"        "! grep -q '^name:' $P/agents/rolepod-scout.md"
check "agent carries the agent protocol" "grep -q '^## Agent protocol' $P/agents/rolepod-scout.md"

# One shared skill tree ships as is; core frontmatter carries only name, description, disable-model-invocation (no tier / phase).
check "skill keeps name+description"    "grep -q '^name: write-spec$' $P/skills/write-spec/SKILL.md"
check "skill drops tier field"          "! grep -q '^tier:' $P/skills/write-spec/SKILL.md"
check "skill drops phase field"         "! grep -q '^phase:' $P/skills/write-spec/SKILL.md"
check "skill keeps disable-model-invocation (one tree; opencode ignores unknown keys)" "grep -q '^disable-model-invocation' $P/skills/deepen-codebase/SKILL.md"
check "using-rolepod workflow helper has its canonical adjacent config reader" "[ -f $P/skills/using-rolepod/scripts/rolepod_config.py ]"

# AGENTS.md carries the always-on core fragments.
check "AGENTS.md rendered"              "[ -f $P/AGENTS.md ]"
check "rendered scout agent is mechanically read-only" "grep -q 'bash: deny' $REPO_DIR/build/rendered/opencode/agents/rolepod-scout.md"
check "rendered Bash agents leave workflow ship rules to the mode-aware plugin" "[ -f $REPO_DIR/build/rendered/opencode/agents/rolepod-builder.md ] && ! grep -q '\"git commit\\*\": deny' $REPO_DIR/build/rendered/opencode/agents/rolepod-builder.md"

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
# hard deny. The evidence-based (risk edit / test) gate is Claude-only now
# (spec Desired 10, 2026-09-25). The commit hook now runs the SHARED
# hooks/precommit-gate.sh itself (ROLEPOD_LEAD_CLI=opencode, hook-layer-lean
# fix round, 2026-09-25, B-spec MAJOR) instead of a JS private-docs copy —
# every fixture below stages / writes a real file under a real git repo and
# asserts against the shared script's own deny.
if command -v node >/dev/null 2>&1; then
  OC_FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-ocgate.XXXXXX")"
  mkdir -p "$OC_FIX/.rolepod"; printf '{"workflow":{"mode":"full"}}\n' > "$OC_FIX/.rolepod/config.json"
  git -C "$OC_FIX" init -q
  # An initial commit (not an unborn branch): the compound-add case below
  # needs `git diff HEAD` to succeed — an unborn branch falls back to
  # --cached (precommit-gate.sh:569), which an UNTRACKED file never reaches.
  git -C "$OC_FIX" commit -q -m init --allow-empty
  OC_HOME="$OC_FIX/fake-home"; mkdir -p "$OC_HOME"
  DRIVER="$OC_FIX/drive.mjs"
  cat > "$DRIVER" <<DRIVEREOF
import { RolepodPlugin } from 'file://$REPO_DIR/adapters/opencode/plugin/rolepod.js'
const [,, command, childMode, lookupRole, repeatMode] = process.argv
let toastMessage = ''
let lookupCount = 0
const client = {
  tui: { showToast: ({body}) => { toastMessage = body.message } },
  session: lookupRole === 'missing' ? {} : { get: async ({path}) => { lookupCount++; if (lookupRole === 'error') throw new Error('lookup failed'); return {data: {id: lookupRole === 'wrongid' ? 'different-session' : path.id, parentID: lookupRole === 'child' ? 'parent' : undefined}} } },
}
const plugin = await RolepodPlugin({ directory: process.cwd(), client })
if (repeatMode === 'lite-registration') { console.log('CALLBACKS=' + Object.keys(plugin).length); process.exit(0) }
if (childMode === 'child') await plugin.event({ event: { type: 'session.created', properties: { info: { id: 'child-session', parentID: 'lead-session' } } } })
if (childMode === 'lead') await plugin.event({ event: { type: 'session.created', properties: { info: { id: 'lead-session' } } } })
if (childMode === 'partial') await plugin.event({ event: { type: 'session.created', properties: { sessionID: 'child-session' } } })
let verdict = 'ALLOW'
try {
  if (repeatMode === 'flip') {
    const fs = await import('node:fs')
    fs.writeFileSync(process.cwd() + '/.rolepod/config.json', '{"workflow":{"mode":"full"}}\n')
  }
  const input = { tool: 'bash', sessionID: childMode === 'lead' ? 'lead-session' : (childMode ? 'child-session' : (lookupRole ? 'lookup-session' : undefined)) }
  await plugin['tool.execute.before'](input, { args: { command } })
  if (repeatMode === 'repeat') await plugin['tool.execute.before'](input, { args: { command } })
} catch (e) { verdict = String(e?.message || '').includes('precommit-gate BLOCKED') || String(e?.message || '').includes('child sessions cannot') || String(e?.message || '').includes('cannot verify session identity') ? 'DENY' : 'DENY-BADMSG:' + String(e?.message || '').slice(0, 60) }
console.log(verdict + (toastMessage.startsWith('WARNING:') ? ':WARNING' : '') + (lookupRole ? ':LOOKUPS=' + lookupCount : ''))
DRIVEREOF
  # $1 = repo-relative path to stage (private-docs deny fixture), or "-" for
  # none; $2 = the shell command under test.
  ocg() {
    ( cd "$OC_FIX" && git reset -q >/dev/null 2>&1; rm -rf docs
      if [ -n "$1" ] && [ "$1" != "-" ]; then mkdir -p "$(dirname "$1")"; echo x > "$1"; git add "$1" >/dev/null 2>&1; fi
      HOME="$OC_HOME" ROLEPOD_OC_SHARED="$REPO_DIR/build/rendered/opencode/plugin/rolepod-shared" node "$DRIVER" "$2" lead 2>/dev/null )
  }
  check "oc-gate: staged private doc + git commit → deny"    "[ \"\$(ocg docs/rolepod/plan.md 'git commit -m x')\" = DENY ]"
  check "oc-gate: flag-separated git -C commit → deny"       "[ \"\$(ocg docs/rolepod/plan.md 'git -C /repo commit -m x')\" = DENY ]"
  check "oc-gate: git -c k=v commit → deny"                  "[ \"\$(ocg docs/rolepod/plan.md 'git -c user.email=x@y commit -m x')\" = DENY ]"
  check "oc-gate: /usr/bin/git commit → deny"                "[ \"\$(ocg docs/rolepod/plan.md '/usr/bin/git commit -m x')\" = DENY ]"
  check "oc-gate: git log → allow"                           "[ \"\$(ocg docs/rolepod/plan.md 'git log --oneline')\" = ALLOW ]"
  check "oc-gate: no staged private doc + git commit → allow" "[ \"\$(ocg - 'git commit -m x')\" = ALLOW ]"
  check "oc-gate: staged high-risk path, zero evidence, no private doc → allow (Claude-only gate)" \
    "[ \"\$(ocg src/auth/login.py 'git commit -m x')\" = ALLOW ]"
  # Compound `git add -A && git commit` in ONE command (hook-layer-lean fix
  # round, 2026-09-25, B-spec MAJOR): nothing is staged at hook time, so the
  # old JS check (git diff --cached only) missed it — the shared gate reads
  # the working tree instead once it sees an `add` before `commit`. $1 stays
  # UNTRACKED (never `git add`ed) to prove this, unlike ocg() above.
  ocg_untracked() {
    ( cd "$OC_FIX" && git reset -q >/dev/null 2>&1; rm -rf docs
      mkdir -p "$(dirname "$1")"; echo x > "$1"
      HOME="$OC_HOME" ROLEPOD_OC_SHARED="$REPO_DIR/build/rendered/opencode/plugin/rolepod-shared" node "$DRIVER" "$2" lead 2>/dev/null )
  }
  occhild() {
    printf '{"workflow":{"mode":"%s"}}\n' "$1" > "$OC_FIX/.rolepod/config.json"
    ( cd "$OC_FIX" && HOME="$OC_HOME" ROLEPOD_OC_SHARED="$REPO_DIR/build/rendered/opencode/plugin/rolepod-shared" node "$DRIVER" "$2" child 2>/dev/null )
  }
  check "oc-child Full: commit is denied in child session" "[ \"$(occhild full 'git commit -m x')\" = DENY ]"
  check "oc-child Full: push is denied in child session" "[ \"$(occhild full 'git push origin main')\" = DENY ]"
  check "oc-child Full: PR create is denied in child session" "[ \"$(occhild full 'gh pr create --title x')\" = DENY ]"
  check "oc-child Standard: push is denied (subagent-ship table row)" "[ \"$(occhild standard 'git push origin main')\" = DENY ]"
  ocprobe() {
    printf '{"workflow":{"mode":"%s"}}\n' "$1" > "$OC_FIX/.rolepod/config.json"
    ( cd "$OC_FIX" && HOME="$OC_HOME" ROLEPOD_OC_SHARED="$REPO_DIR/build/rendered/opencode/plugin/rolepod-shared" node "$DRIVER" "$2" unseeded "$3" "${4:-}" 2>/dev/null )
  }
  check "oc-child Lite: plugin registers the same 4 callbacks as Standard" "[ \"$(ocprobe lite 'git push origin main' child lite-registration)\" = CALLBACKS=4 ]"
  check "oc-v1 Full first call: looked-up child commit denied" "[ \"$(ocprobe full 'git commit -m x' child)\" = DENY:LOOKUPS=1 ]"
  check "oc-v1 Full first call: looked-up Lead push allowed" "[ \"$(ocprobe full 'git push origin main' lead)\" = ALLOW:LOOKUPS=1 ]"
  check "oc-v1 Full: failed lookup denies pending ship" "[ \"$(ocprobe full 'gh pr create --title x' error)\" = DENY:LOOKUPS=1 ]"
  printf '{"workflow":{"mode":"full"}}\n' > "$OC_FIX/.rolepod/config.json"
  ocpartial=$(cd "$OC_FIX" && HOME="$OC_HOME" ROLEPOD_OC_SHARED="$REPO_DIR/build/rendered/opencode/plugin/rolepod-shared" node "$DRIVER" 'git push origin main' partial error 2>/dev/null)
  check "oc-v1 Full: partial session.created does not confirm Lead" "[ \"$ocpartial\" = DENY:LOOKUPS=1 ]"
  check "oc-v1 Full: unavailable lookup denies unverified ship" "[ \"$(ocprobe full 'git push origin main' missing)\" = DENY:LOOKUPS=0 ]"
  check "oc-v1 Full: mismatched session lookup denies unverified ship" "[ \"$(ocprobe full 'git push origin main' wrongid)\" = DENY:LOOKUPS=1 ]"
  check "oc-v1 Full: confirmed child role is cached across calls" "[ \"$(ocprobe full 'git push origin main' child repeat)\" = DENY:LOOKUPS=1 ]"
  check "oc-v1 Standard: child lookup denies" "[ \"$(ocprobe standard 'git push origin main' child)\" = DENY:LOOKUPS=1 ]"
  check "oc-v1 Standard: unavailable lookup warns and allows" "[ \"$(ocprobe standard 'git push origin main' missing)\" = ALLOW:WARNING:LOOKUPS=0 ]"
  check "oc-v1 Lite: child push is denied (subagent-ship table row)" "[ \"$(ocprobe lite 'git push origin main' child)\" = DENY:LOOKUPS=1 ]"
  check "oc-v1 Lite: child commit is denied" "[ \"$(occhild lite 'git commit -m x')\" = DENY ]"
  check "oc-v1 Lite: unavailable lookup warns and allows" "[ \"$(ocprobe lite 'git push origin main' missing)\" = ALLOW:WARNING:LOOKUPS=0 ]"
    check "oc-v1 Standard startup profile stays fixed after config changes" "[ \"$(ocprobe standard 'git push origin main' missing flip)\" = ALLOW:WARNING:LOOKUPS=0 ]"
  check "oc-v1 Full: child hard reset is denied" "[ \"$(occhild full 'git reset --hard HEAD')\" = DENY ]"
  check "oc-v1 Full: reordered hard reset options are denied" "[ \"$(occhild full 'git reset -q --hard HEAD')\" = DENY ]"
  check "oc-v1 Standard: child hard reset is denied" "[ \"$(occhild standard 'git reset --hard HEAD')\" = DENY ]"
  check "oc-v1 Lite: child hard reset is denied" "[ \"$(occhild lite 'git reset --hard HEAD')\" = DENY ]"
  DRIVERV2="$OC_FIX/drive-v2.mjs"
  cat > "$DRIVERV2" <<DRIVERV2EOF
import plugin from 'file://$REPO_DIR/adapters/opencode/plugin/rolepod.js'
const [,, command, lookupRole, repeatMode] = process.argv
let lookups = 0
let before, context
const sessionHooks = new Map(), toolHooks = new Map()
const sessionApi = { hook: async (name, fn) => sessionHooks.set(name, fn) }
if (lookupRole !== 'missing') sessionApi.get = async ({sessionID}) => { lookups++; if (lookupRole === 'error') throw new Error('lookup failed'); return {id: lookupRole === 'wrongid' ? 'different-session' : sessionID, ...(lookupRole === 'child' ? {parentID:'parent'} : {})} }
const ctx = {
  location: { directory: process.cwd() },
  session: sessionApi,
  tool: { hook: async (name, fn) => { if (name === 'execute.before') before = fn; toolHooks.set(name, fn) } },
  event: { subscribe: () => ({ async *[Symbol.asyncIterator]() {} }) },
}
await plugin.setup(ctx)
if (repeatMode === 'lite-registration') { console.log('HOOKS=' + (sessionHooks.size + toolHooks.size)); process.exit(0) }
await sessionHooks.get('prompt')({sessionID:'lookup-session'})
let verdict = 'ALLOW'
try {
  if (repeatMode === 'flip') {
    const fs = await import('node:fs')
    fs.writeFileSync(process.cwd() + '/.rolepod/config.json', '{"workflow":{"mode":"full"}}\n')
  }
  const event = {tool:'shell', sessionID:'lookup-session', input:{command}}
  await before(event)
  if (repeatMode === 'repeat') await before(event)
} catch (e) { verdict = String(e?.message || '').includes('child sessions cannot') || String(e?.message || '').includes('cannot verify session identity') ? 'DENY' : 'DENY-BADMSG:' + String(e?.message || '').slice(0,60) }
const system = []
await sessionHooks.get('context')({sessionID:'lookup-session',system})
console.log(verdict + (system.some(p=>String(p.text||'').includes('WARNING:')) ? ':WARNING' : '') + ':LOOKUPS=' + lookups)
DRIVERV2EOF
  ocv2probe() {
    printf '{"workflow":{"mode":"%s"}}\n' "$1" > "$OC_FIX/.rolepod/config.json"
    mkdir -p "$OC_FIX/fake-home"
    ( cd "$OC_FIX" && HOME="$OC_FIX/fake-home" ROLEPOD_OC_SHARED="$REPO_DIR/build/rendered/opencode/plugin/rolepod-shared" node "$DRIVERV2" "$2" "$3" "${4:-}" 2>/dev/null )
  }
  check "oc-v2 Full first call: looked-up child is denied" "[ \"$(ocv2probe full 'git commit -m x' child)\" = DENY:LOOKUPS=1 ]"
  check "oc-v2 Full first call: looked-up Lead push is allowed" "[ \"$(ocv2probe full 'git push origin main' lead)\" = ALLOW:LOOKUPS=1 ]"
  check "oc-v2 Full: failed lookup denies pending ship" "[ \"$(ocv2probe full 'gh pr merge 1' error)\" = DENY:LOOKUPS=1 ]"
  check "oc-v2 Full: unavailable lookup denies unverified ship" "[ \"$(ocv2probe full 'git push origin main' missing)\" = DENY:LOOKUPS=0 ]"
  check "oc-v2 Full: mismatched session lookup denies unverified ship" "[ \"$(ocv2probe full 'git push origin main' wrongid)\" = DENY:LOOKUPS=1 ]"
  check "oc-v2 Full: cached child identity avoids second lookup" "[ \"$(ocv2probe full 'git push origin main' child repeat)\" = DENY:LOOKUPS=1 ]"
  check "oc-v2 Standard: child push is denied" "[ \"$(ocv2probe standard 'git push origin main' child)\" = DENY:LOOKUPS=1 ]"
  check "oc-v2 Standard: unverified-identity warning reaches the context hook" "[ \"$(ocv2probe standard 'git push origin main' missing)\" = ALLOW:WARNING:LOOKUPS=0 ]"
  check "oc-v2 Standard: unavailable lookup warns and allows" "[ \"$(ocv2probe standard 'git push origin main' missing)\" = ALLOW:WARNING:LOOKUPS=0 ]"
  check "oc-v2 Lite: child push is denied (subagent-ship table row)" "[ \"$(ocv2probe lite 'git push origin main' child)\" = DENY:LOOKUPS=1 ]"
  check "oc-v2 Lite: unavailable lookup warns and allows" "[ \"$(ocv2probe lite 'git push origin main' missing)\" = ALLOW:WARNING:LOOKUPS=0 ]"
  check "oc-v2 Lite registers the same 4 hooks as Standard" "[ \"$(ocv2probe lite 'git push origin main' child lite-registration)\" = HOOKS=4 ]"
  check "oc-v2 Standard startup profile stays fixed after config changes" "[ \"$(ocv2probe standard 'git push origin main' missing flip)\" = ALLOW:WARNING:LOOKUPS=0 ]"
  check "oc-v2 Full: child hard reset is denied" "[ \"$(ocv2probe full 'git reset --hard HEAD' child)\" = DENY:LOOKUPS=1 ]"
  check "oc-v2 Standard: child hard reset is denied" "[ \"$(ocv2probe standard 'git reset --hard HEAD' child)\" = DENY:LOOKUPS=1 ]"
  check "oc-v2 Lite: child hard reset is denied" "[ \"$(ocv2probe lite 'git reset --hard HEAD' child)\" = DENY:LOOKUPS=1 ]"
  printf '{"workflow":{"mode":"full"}}\n' > "$OC_FIX/.rolepod/config.json"
  check "oc-gate: compound git add -A && git commit, private doc UNTRACKED (not staged) → deny" \
    "[ \"\$(ocg_untracked docs/rolepod/new.md 'git add -A && git commit -m x')\" = DENY ]"
  # F8b/S8 (v2.166.x): shell-wrapped commits reach the same isGitCommit walk.
  printf '{"workflow":{"mode":"lite"}}\n' > "$OC_FIX/.rolepod/config.json"
  check "oc-gate Lite: staged private doc + git commit → deny (private-docs table row)" "[ \"\$(ocg docs/rolepod/plan.md 'git commit -m x')\" = DENY ]"
  printf '{"workflow":{"mode":"full"}}\n' > "$OC_FIX/.rolepod/config.json"
  check "oc-gate: bash -c wrapped commit → deny"            "[ \"\$(ocg docs/rolepod/plan.md 'bash -c \"git commit -m x\"')\" = DENY ]"
  check "oc-gate: bash -lc flag-cluster wrapped commit → deny" "[ \"\$(ocg docs/rolepod/plan.md 'bash -lc \"git commit -m x\"')\" = DENY ]"
  check "oc-gate: \$SHELL -c wrapped commit → deny"          "[ \"\$(ocg docs/rolepod/plan.md '\$SHELL -c \"git commit -m x\"')\" = DENY ]"
  check "oc-gate: eval wrapped commit → deny"                "[ \"\$(ocg docs/rolepod/plan.md 'eval \"git commit -m x\"')\" = DENY ]"
  check "oc-gate: nested bash -c wrapped commit → deny"      "[ \"\$(ocg docs/rolepod/plan.md 'bash -c \"bash -c '\\''git commit -m x'\\''\"')\" = DENY ]"
  check "oc-gate: echo git commit (no real commit) → allow" "[ \"\$(ocg docs/rolepod/plan.md 'bash -c \"echo git commit\"')\" = ALLOW ]"
  # round-1 review (v2.166.x): qsplit never emitted ';' as its own token, so
  # 'true; git commit' or a real newline before a commit hid it behind the
  # OUTPUT_ONLY drop; the shell-flag scan stopped at the first non-flag
  # token, missing -c behind '-o pipefail' or '--noprofile'.
  check "oc-gate: bare ; before a real commit → deny"        "[ \"\$(ocg docs/rolepod/plan.md 'true; git commit -m x')\" = DENY ]"
  check "oc-gate: echo x; git commit (semicolon) → deny"     "[ \"\$(ocg docs/rolepod/plan.md 'echo x; git commit -m x')\" = DENY ]"
  check "oc-gate: timeout N bash -c wrapped commit → deny"   "[ \"\$(ocg docs/rolepod/plan.md 'timeout 30 bash -c \"git commit -m x\"')\" = DENY ]"
  check "oc-gate: bash -o pipefail -c wrapped commit → deny" "[ \"\$(ocg docs/rolepod/plan.md 'bash -o pipefail -c \"git commit -m x\"')\" = DENY ]"
  check "oc-gate: bash --noprofile -c wrapped commit → deny" "[ \"\$(ocg docs/rolepod/plan.md 'bash --noprofile -c \"git commit -m x\"')\" = DENY ]"
  check "oc-gate: 5-deep eval chain (past depth-4) → deny (fail-closed)" "[ \"\$(ocg docs/rolepod/plan.md 'eval eval eval eval eval \"git commit -m x\"')\" = DENY ]"
  # round-2 external + security-engineer review (v2.166.x): the round-1 fix
  # (qsplit + a hand-rolled TEXT-level operator split) was itself wrong on
  # an escaped quote, a bare '&', and command substitution — a real
  # shell-grade tokenizer (uwTokenize) replaced it.
  check "oc-gate: escaped dquote then a real commit → deny"  "[ \"\$(ocg docs/rolepod/plan.md 'echo \\\"; git commit -m x')\" = DENY ]"
  check "oc-gate: bare & (not &&) before a real commit → deny" "[ \"\$(ocg docs/rolepod/plan.md 'echo x & git commit -m x')\" = DENY ]"
  check "oc-gate: bash -c \"true\" & git commit → deny"       "[ \"\$(ocg docs/rolepod/plan.md 'bash -c \"true\" & git commit -m x')\" = DENY ]"
  check "oc-gate: command substitution inside echo → deny"    "[ \"\$(ocg docs/rolepod/plan.md 'echo \$(git commit -m x)')\" = DENY ]"
  check "oc-gate: quoted ; inside a string then a real ; and commit → deny" "[ \"\$(ocg docs/rolepod/plan.md 'echo \"Done; committing\"; git commit -m x')\" = DENY ]"
  # round-3 external review (v2.166.x): absolute-path wrapper, a bare '&'
  # with no spaces, and bash's \$'...' ANSI-C quoting each evaded round 2.
  check "oc-gate: absolute-path env wrapper before bash -c → deny"  "[ \"\$(ocg docs/rolepod/plan.md '/usr/bin/env bash -c \"git commit -m x\"')\" = DENY ]"
  check "oc-gate: bare & with NO surrounding spaces → deny"         "[ \"\$(ocg docs/rolepod/plan.md 'echo x&git commit -m x')\" = DENY ]"
  check "oc-gate: bash -c with a \\\$'...' ANSI-C quoted string → deny" "[ \"\$(ocg docs/rolepod/plan.md \"bash -c \\\$'git commit -m x'\")\" = DENY ]"
  # ── Behavioral: shared cores behind the translator (v2.133.0) ─────────
  # fix-loop-breaker is the Claude script in hooks/, run via ROLEPOD_OC_SHARED;
  # the nudge must land INSIDE output.output (the string the model reads) —
  # once per turn — and never break a tool call.
  DRIVER2="$OC_FIX/cores.mjs"
  cat > "$DRIVER2" <<DRIVEREOF
import { RolepodPlugin } from 'file://$REPO_DIR/adapters/opencode/plugin/rolepod.js'
const sid = 'oc-cores-test-' + process.pid
const plugin = await RolepodPlugin({ directory: process.cwd(), client: null })
if (Object.keys(plugin).length === 0) {
  console.log(JSON.stringify({ loop1: false, loop2: false, loop3: false, loop4: false, loopReset: false, plainUntouched: true, routeLine: false, routeOnce: false }))
  process.exit(0)
}
const after = (tool, args, output, metadata) => { const o = { title: tool, output, metadata: metadata || {} }; return plugin['tool.execute.after']({ tool, sessionID: sid, callID: 'c', args }, o).then(() => o.output) }
const res = {}
await plugin['chat.message']({ sessionID: sid }, { message: {}, parts: [{ type: 'text', text: 'go' }] })
let l1 = await after('bash', { command: 'npm test' }, 'FAIL', { exit: 1 })
let l2 = await after('bash', { command: 'npm test' }, 'FAIL', { exit: 1 })
let l3 = await after('bash', { command: 'npm test' }, 'FAIL', { exit: 1 })
let l4 = await after('bash', { command: 'npm test' }, 'FAIL', { exit: 1 })
res.loop1 = l1.includes('LOOP BREAKER'); res.loop2 = l2.includes('LOOP BREAKER')
res.loop3 = l3.includes('LOOP BREAKER'); res.loop4 = l4.includes('LOOP BREAKER')
let l5 = await after('bash', { command: 'npm test' }, 'PASS', { exit: 0 })
res.loopReset = l5.includes('LOOP BREAKER')
let plain = await after('bash', { command: 'echo hi' }, 'hi', { exit: 0 })
res.plainUntouched = plain === 'hi'
// v2.176.0: task/subagent dispatch writes no phase-log line any more (spec Desired 10, 2026-09-25).
const fs = await import('node:fs')
const log = process.cwd() + '/.rolepod/evidence/phase-log.jsonl'
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
res.routeLine = fs.existsSync(log) && fs.readFileSync(log, 'utf8').includes('"phase":"route","tier":"R2","skill":"implement-plan"')
await plugin2.event({ event: { type: 'session.idle', properties: { sessionID: 'ses-route-test' } } })
res.routeOnce = fs.existsSync(log) && (fs.readFileSync(log, 'utf8').match(/"phase":"route"/g) || []).length === 1
console.log(JSON.stringify(res))
DRIVEREOF
  CORES=$(cd "$OC_FIX" && HOME="$OC_HOME" ROLEPOD_OC_SHARED="$REPO_DIR/build/rendered/opencode/plugin/rolepod-shared" node "$DRIVER2" 2>/dev/null); rm -f "${TMPDIR:-/tmp}"/rolepod-loopbreak-oc-cores-test-*.json
  ocv() { printf '%s' "$CORES" | python3 -I -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('$1') is $2 else 1)"; }
  check "oc-cores: metadata.exit failures 1–4 show advisory after failure 2; pass resets" "ocv loop1 False && ocv loop2 True && ocv loop3 True && ocv loop4 True && ocv loopReset False"
  check "oc-cores: a passing run resets the loop counter; plain output untouched" "ocv loopReset False && ocv plainUntouched True"
  check "oc-cores: session.idle → the turn's route line via the SDK messages (once per prompt)" "ocv routeLine True && ocv routeOnce True"
  check "oc-cores: missing shared dir → tool results untouched (fail open)" "[ \"\$(cd $OC_FIX && rm -rf .rolepod && HOME=$OC_HOME ROLEPOD_OC_SHARED=/nonexistent node $DRIVER2 2>/dev/null | python3 -I -c 'import json,sys; d=json.load(sys.stdin); print(all(v is False for k,v in d.items() if k != \"plainUntouched\") and d[\"plainUntouched\"])')\" = True ]"
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
  mkdir -p "$OC_FIX2/.rolepod"; printf '{"workflow":{"mode":"full"}}\n' > "$OC_FIX2/.rolepod/config.json"
  FAKEHOME2="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-ocv2home.XXXXXX")"
  git -C "$OC_FIX2" init -q
  # See OC_FIX above — the compound-add case needs a real HEAD.
  git -C "$OC_FIX2" commit -q -m init --allow-empty
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
  session: {
    hook: async (name, cb) => { (hooks.session[name] ??= []).push(cb) },
    get: async ({sessionID}) => ({id: sessionID, ...(sessionID === 'child-sess' ? {parentID: 'lead-sess'} : {})}),
  },
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
function resetGit() { try { execSync("git reset -q", { cwd: DIR }) } catch {}; fs.rmSync(path.join(DIR, "docs"), { recursive: true, force: true }) }
function stagePrivateDoc(p) {
  const full = path.join(DIR, p)
  fs.mkdirSync(path.dirname(full), { recursive: true })
  fs.writeFileSync(full, "x")
  execSync("git add " + JSON.stringify(p), { cwd: DIR })
}
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
// (2) gate — runs the SHARED hooks/precommit-gate.sh (ROLEPOD_LEAD_CLI=
// opencode); Claude-only evidence gating is retired (spec Desired 10,
// 2026-09-25) so it denies on a real private-docs path only, exiting right
// after — these fixtures stage/write real files under a real git repo.
resetGit()
stagePrivateDoc("docs/rolepod/plan.md")
try { await before("shell", { command: "git commit -m x" }); res.gateRisk = "ALLOW" } catch (e) { res.gateRisk = String(e?.message || "").includes("precommit-gate BLOCKED") ? "DENY" : "BADMSG" }
resetGit()
stagePrivateDoc("docs/rolepod/plan.md")
try { await before("shell", { command: "git -C /repo commit -m x" }); res.gateFlagC = "ALLOW" } catch (e) { res.gateFlagC = String(e?.message || "").includes("precommit-gate BLOCKED") ? "DENY" : "BADMSG" }
resetGit()
// Compound `git add -A && git commit` — the doc stays UNTRACKED (never
// `git add`ed), unlike stagePrivateDoc() above (hook-layer-lean fix round,
// 2026-09-25, B-spec MAJOR).
fs.mkdirSync(path.join(DIR, "docs", "rolepod"), { recursive: true })
fs.writeFileSync(path.join(DIR, "docs", "rolepod", "new.md"), "x")
try { await before("shell", { command: "git add -A && git commit -m x" }); res.gateCompoundAdd = "ALLOW" } catch (e) { res.gateCompoundAdd = String(e?.message || "").includes("precommit-gate BLOCKED") ? "DENY" : "BADMSG" }
resetGit()
stagePrivateDoc("docs/rolepod/plan.md")
try { await before("shell", { command: "git log --oneline" }); res.gateLog = "ALLOW" } catch { res.gateLog = "DENY" }
resetGit()
try { await before("shell", { command: "git commit -m x" }); res.gateNormalPath = "ALLOW" } catch { res.gateNormalPath = "DENY" }
resetGit()
stagePrivateDoc("src/auth/login.py")
try { await before("shell", { command: "git commit -m x" }); res.gateHighRiskNoDoc = "ALLOW" } catch { res.gateHighRiskNoDoc = "DENY" }
resetGit()
// (4) loop breaker
const sidLoop = "loop-sess"
let l1 = await after("shell", { command: "npm test" }, { content: "FAIL", metadata: { exit: 1 } }, sidLoop)
let l2 = await after("shell", { command: "npm test" }, { content: "FAIL", metadata: { exit: 1 } }, sidLoop)
let l3 = await after("shell", { command: "npm test" }, { content: "FAIL", metadata: { exit: 1 } }, sidLoop)
res.loop2 = String(l2.content).includes("LOOP BREAKER")
res.loop3 = String(l3.content).includes("LOOP BREAKER")
let l4 = await after("shell", { command: "npm test" }, { content: "FAIL", metadata: { exit: 1 } }, sidLoop)
res.loop1 = String(l1.content).includes("LOOP BREAKER")
res.loop2 = String(l2.content).includes("LOOP BREAKER")
res.loop3 = String(l3.content).includes("LOOP BREAKER")
res.loop4 = String(l4.content).includes("LOOP BREAKER")
let l5 = await after("shell", { command: "npm test" }, { content: "PASS", metadata: { exit: 0 } }, sidLoop)
res.loopReset = String(l5.content).includes("LOOP BREAKER")
let plain = await after("shell", { command: "echo hi" }, { content: "hi", metadata: { exit: 0 } }, sidLoop)
res.plainUntouched = plain.content === "hi"
// (6) lock + sibling
const sidA = "ses-A"
await prompt(sidA, "hello")
await tick()
const ld = lockDir()
res.lockAExists = fs.existsSync(path.join(ld, `${sidA}.lock`))
res.parentActiveExists = fs.existsSync(path.join(DIR, ".rolepod", "parent-active"))
res.lockPidLine = fs.readFileSync(path.join(ld, `${sidA}.lock`), "utf8") === `opencode\n${process.pid}`
const lockCountAfterFirst = fs.readdirSync(ld).filter((f) => f.endsWith(".lock")).length
await prompt(sidA, "hello again")
const lockCountAfterSecond = fs.readdirSync(ld).filter((f) => f.endsWith(".lock")).length
res.stillOneLock = lockCountAfterSecond === lockCountAfterFirst
fs.mkdirSync(ld, { recursive: true })
fs.writeFileSync(path.join(ld, "sibling-x.lock"), "opencode\n4242")
const sidB = "ses-B"
await prompt(sidB, "hi")
let cx1 = await context(sidB, [{ id: "m1", role: "user", content: [{ type: "text", text: "hi" }] }])
res.siblingPushedOnce = cx1.system.filter((p) => String(p.text || "").includes("sibling session")).length === 1
res.siblingNamesOpencode = cx1.system.some((p) => String(p.text || "").includes("opencode ×2"))
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
try { await before("shell", { command: "git push origin main" }, "child-sess"); res.childShipFull = "ALLOW" }
catch (e) { res.childShipFull = String(e?.message || "").includes("child sessions cannot") ? "DENY" : "BADMSG" }
fs.writeFileSync(path.join(DIR, ".rolepod", "config.json"), JSON.stringify({ workflow: { mode: "standard" } }))
try { await before("shell", { command: "gh pr create --title x" }, "child-sess"); res.childShipStandard = false }
catch (e) { res.childShipStandard = String(e?.message || "").includes("child sessions cannot") }
fs.writeFileSync(path.join(DIR, ".rolepod", "config.json"), JSON.stringify({ workflow: { mode: "lite" } }))
try { await before("shell", { command: "git push origin main" }, "child-sess"); res.childShipLite = "ALLOW" }
catch { res.childShipLite = "DENY" }
fs.writeFileSync(path.join(DIR, ".rolepod", "config.json"), JSON.stringify({ workflow: { mode: "full" } }))
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
  check "oc-v2 gate: staged private doc + shell 'git commit' → deny" "ocv2 gateRisk '\"DENY\"'"
  check "oc-v2 gate: flag-separated git -C commit → deny" "ocv2 gateFlagC '\"DENY\"'"
  check "oc-v2 gate: compound git add -A && git commit, private doc UNTRACKED → deny" "ocv2 gateCompoundAdd '\"DENY\"'"
  check "oc-v2 gate: git log → allow" "ocv2 gateLog '\"ALLOW\"'"
  check "oc-v2 gate: normal path commit → allow" "ocv2 gateNormalPath '\"ALLOW\"'"
  check "oc-v2 gate: staged high-risk path, zero evidence, no private doc → allow (Claude-only gate)" "ocv2 gateHighRiskNoDoc '\"ALLOW\"'"
  check "oc-v2 loop breaker: metadata.exit failures 1–4 show advisory after failure 2; pass resets" "ocv2 loop1 False && ocv2 loop2 True && ocv2 loop3 True && ocv2 loop4 True && ocv2 loopReset False"
  check "oc-v2 loop breaker: a passing run resets the counter; plain output untouched" "ocv2 loopReset False && ocv2 plainUntouched True"
  check "oc-v2: first prompt for a session → session lock + parent-active marker; a second prompt keeps one lock" "ocv2 lockAExists True && ocv2 parentActiveExists True && ocv2 stillOneLock True"
  check "oc-v2: a pre-placed sibling lock → ONE 'sibling session' text part on the next context call, none on the following one" "ocv2 siblingPushedOnce True && ocv2 siblingNotPushedTwice True"
  check "oc-v2: the sibling message carries the lock's CLI name (opencode ×2: own + a two-line sibling)" "ocv2 siblingNamesOpencode True"
  check "oc-v2: the plugin's own lock is 'opencode' + newline + the opencode process pid" "ocv2 lockPidLine True"
  check "oc-v2: session.compaction.ended → the re-anchor text pushed once on the next context call, not the one after" "ocv2 reanchorPushedOnce True && ocv2 reanchorNotPushedTwice True"
  check "oc-v2: a compaction event for a session the event stream never announced still re-anchors (the prompt hook already seeded it)" "ocv2 reanchorUnseenSession True"
  check "oc-v2: a context call's trailing messages record the route line once; a second context call in the same turn adds no more" "ocv2 routeOnce1 True && ocv2 routeOnce2 True"
  check "oc-v2: a session.created for another directory or with parentID set never locks or routes" "ocv2 childNoLock True && ocv2 childNoRoute True && ocv2 otherDirNoReanchor True"
  check "oc-v2 child ship: Full stays active after config changes to Standard and Lite" "ocv2 childShipFull '\"DENY\"' && ocv2 childShipStandard True && ocv2 childShipLite '\"DENY\"'"
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
try { await before("shell", { command: "git commit -m x" }); res.gateAllows = true } catch { res.gateAllows = false }
let l = await after("shell", { command: "npm test" }, { content: "FAIL", metadata: { exit: 1 } })
res.loopUntouched = !String(l.content).includes("LOOP BREAKER")
let plain = await after("shell", { command: "echo hi" }, { content: "hi", metadata: { exit: 0 } })
res.plainUntouched = plain.content === "hi"
console.log(JSON.stringify(res))
DRIVEREOF
  OC_FIX2B="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-ocv2fo.XXXXXX")"
  git -C "$OC_FIX2B" init -q
  V2FO=$(cd "$OC_FIX2B" && ROLEPOD_REPO_DIR="$REPO_DIR" ROLEPOD_OC_SHARED=/nonexistent node "$DRIVERV2FO" 2>/dev/null)
  ocv2fo() { printf '%s' "$V2FO" | python3 -I -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('$1') == $2 else 1)"; }
  # v2 fail-open: the gate no longer depends on ROLEPOD_OC_SHARED at all
  # (it reads a real `git diff --cached`, spec Desired 10, 2026-09-25) — a
  # broken SHARED path only affects the loop breaker, which fails open too.
  check "oc-v2: missing shared dir → gate still evaluates (no doc staged → allow); loop untouched; plain output untouched" \
    "ocv2fo gateAllows True && ocv2fo loopUntouched True && ocv2fo plainUntouched True"
  rm -rf "$OC_FIX2" "$FAKEHOME2" "$OC_FIX2B"
else
  echo "  ~ node not on PATH — skipping opencode gate behavior checks"
fi

# Full install + uninstall round-trip against a temp target — runs the real
# install.sh --target=opencode selection, so a static wiring grep is redundant.
TMP_OC="$(mktemp -d)"
trap 'rm -rf "$TMP_OC"' EXIT
# A retired role file left by an older install must be pruned (the 4-agent count and the absence check below).
# install.sh prunes only a retired-name file that carries the "## Skill Mapping" line (a user's own agent stays).
mkdir -p "$TMP_OC/agents" && printf 'stale\n## Skill Mapping\n' > "$TMP_OC/agents/data-scientist.md"
if ROLEPOD_OPENCODE_TARGET="$TMP_OC" ./install.sh --target=opencode --force --yes >/dev/null 2>&1; then
  check "installed skills/using-rolepod"  "[ -f $TMP_OC/skills/using-rolepod/SKILL.md ]"
  check "installed using-rolepod helper reader" "[ -f $TMP_OC/skills/using-rolepod/scripts/rolepod_config.py ]"
  check "installed 4 agents"              "[ \"\$(ls $TMP_OC/agents/*.md | wc -l | tr -d ' ')\" = 4 ]"
  check "install pruned the retired data-scientist.md" "[ ! -e $TMP_OC/agents/data-scientist.md ]"
  check "installed plugins/rolepod.js"    "[ -f $TMP_OC/plugins/rolepod.js ]"
  check "installed plugins/rolepod-shared/ = the hook core, byte-identical" "cmp -s hooks/fix-loop-breaker.sh $TMP_OC/plugins/rolepod-shared/fix-loop-breaker.sh"
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
