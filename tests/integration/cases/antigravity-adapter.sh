#!/bin/bash
# antigravity-adapter — structural + live-validate fixture for the agy adapter.
# Locks the hard-won agy 1.0.13 plugin schema facts (verified 2026-06-30):
#   - plugin hooks.json lives at the PLUGIN ROOT (not hooks/hooks.json)
#   - hook events are TOP-LEVEL (no {"rolepod":{...}} wrapper; no _comment key —
#     agy counts every top-level key as a hook)
#   - agy uses Claude-style events (PreInvocation/PreToolUse/PostToolUse)
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

# Plugin structure.
check "rendered plugin.json present"        "[ -f $P/plugin.json ]"
check "plugin.json is valid JSON"           "python3 -m json.tool $P/plugin.json >/dev/null"
check "plugin name is rolepod"              "python3 -c \"import json;assert json.load(open('$P/plugin.json'))['name']=='rolepod'\""
check "hooks.json at PLUGIN ROOT"           "[ -f $P/hooks.json ]"
check "no stray hooks/hooks.json subpath"   "[ ! -f $P/hooks/hooks.json ]"
check "hook scripts under hooks/ (4)"       "[ \"\$(ls $P/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')\" = 4 ]"
check "exactly 11 skills (Core 10 + rolepod-full alias)" "[ \"\$(ls $P/skills | wc -l | tr -d ' ')\" = 11 ]"
check "16 agents present"                   "[ \"\$(ls $P/agents/*.md | wc -l | tr -d ' ')\" = 16 ]"

# hooks.json schema: agy-native events, top-level, no wrapper, no _comment.
check "hooks.json valid JSON"               "python3 -m json.tool $P/hooks.json >/dev/null"
check "hooks.json events are top-level (no plugin-name wrapper, no _comment)" \
  "python3 -c \"import json;k=set(json.load(open('$P/hooks.json')));assert k=={'PreInvocation','PreToolUse','PostToolUse'}, k\""

# AGENTS.md is the agy context file with the always-on core fragments.
check "AGENTS.md rendered"                  "[ -f build/rendered/antigravity/AGENTS.md ]"
check "AGENTS.md carries Risky actions core"   "grep -q '^## Risky actions' build/rendered/antigravity/AGENTS.md"
check "AGENTS.md carries Communication core"    "grep -q '^## Communication' build/rendered/antigravity/AGENTS.md"

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
