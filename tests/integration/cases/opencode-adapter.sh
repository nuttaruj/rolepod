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
check "16 agents present"               "[ \"\$(ls $P/agents/*.md | wc -l | tr -d ' ')\" = 16 ]"
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
} catch { verdict = 'DENY' }
console.log(verdict)
DRIVEREOF
  ocg() { (cd "$OC_FIX" && node "$DRIVER" "$1" "$2" "$3" 2>/dev/null); }
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
  check "oc-gate: ROLEPOD_GATES_SOFT logs bypass, no deny" "[ \"\$(ROLEPOD_GATES_SOFT=1 ocg auth/login.py - 'git commit -m x')\" = ALLOW ] && grep -q opencode-precommit-gate '$OC_FIX/.rolepod/evidence/bypass.log'"
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
  check "installed 16 agents"             "[ \"\$(ls $TMP_OC/agents/*.md | wc -l | tr -d ' ')\" = 16 ]"
  check "installed plugins/rolepod.js"    "[ -f $TMP_OC/plugins/rolepod.js ]"
  check "installed AGENTS.md managed block" "grep -q 'rolepod:start' $TMP_OC/AGENTS.md"
  check "installed version stamp"         "[ -f $TMP_OC/rolepod-version.json ]"
  if ROLEPOD_OPENCODE_TARGET="$TMP_OC" ./install.sh --target=opencode --uninstall --yes >/dev/null 2>&1; then
    check "uninstall removed skills"      "[ ! -d $TMP_OC/skills/using-rolepod ]"
    check "uninstall removed plugin shim" "[ ! -f $TMP_OC/plugins/rolepod.js ]"
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
