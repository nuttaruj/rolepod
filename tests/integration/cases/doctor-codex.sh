#!/bin/bash
# doctor-codex — scripts/doctor_codex.py prints one line per Codex config risk
# from a throwaway HOME: fixture config.toml / models_cache.json / agents stamp
# / plugin cache + stub `codex` binaries. Fake slugs only; $HOME/.codex is
# checksummed before and after (read-only proof).
set -uo pipefail
PY="$(command -v python3 || true)"
if [ -z "$PY" ] || ! "$PY" -I -c 'import tomllib' 2>/dev/null; then
  echo "SKIP: python < 3.11 (tomllib)"; exit 0
fi
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$REPO_DIR/scripts/doctor_codex.py"
fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1"; fail=$((fail+1)); }
has() { # $1 desc, $2 output, $3 regex
  if printf '%s\n' "$2" | grep -qE -- "$3"; then ok "$1"; else bad "$1 (no /$3/ in: $(printf '%s' "$2" | head -c 400))"; fi
}
hasnt() {
  if printf '%s\n' "$2" | grep -qE -- "$3"; then bad "$1 (unexpected /$3/)"; else ok "$1"; fi
}

stub() { # $1 path, $2 version
  printf '#!/bin/sh\n[ "$1" = "--version" ] && echo "codex-cli %s"\nexit 0\n' "$2" > "$1"; chmod +x "$1"
}
mkstubs() {
  mkdir -p "$tmp/bin"; stub "$tmp/bin/codex" 0.159.2; stub "$tmp/app-codex" 0.159.0
}
catalog() { # $1 client_version
  cat > "$HOME/.codex/models_cache.json" <<EOF
{"client_version": "$1", "models": [
 {"slug": "model-a", "supported_reasoning_levels": [{"effort": "low"}, {"effort": "high"}, {"effort": "ultra"}]},
 {"slug": "model-b", "supported_reasoning_levels": [{"effort": "low"}, {"effort": "high"}]}
]}
EOF
}
fresh() { # new HOME with a clean fixture; sets HOME
  export HOME="$tmp/home-$1"; rm -rf "$HOME"
  mkdir -p "$HOME/.codex/agents" "$HOME/.codex/plugins/cache/rolepod/rolepod/2.5.0"
  printf '2.5.0\n' > "$HOME/.codex/agents/.rolepod-agents-version"
  printf 'model = "model-a"\nmodel_reasoning_effort = "high"\n[agents]\ndefault_subagent_model = "model-b"\ndefault_subagent_reasoning_effort = "high"\n' > "$HOME/.codex/config.toml"
  catalog 0.159.0
}
run() { # RUNPATH / APPBIN override the default engines (stub npm codex first, stub app)
  env HOME="$HOME" PATH="${RUNPATH:-$tmp/bin:$PATH}" ROLEPOD_CODEX_APP_BIN="${APPBIN:-$tmp/app-codex}" "$PY" -I "$SCRIPT" 2>&1
}
cfg() { printf '%s\n' "$1" > "$HOME/.codex/config.toml"; }
sum() { (cd "$HOME/.codex" && find . -type f | sort | xargs shasum | shasum); }

mkstubs
echo "── doctor-codex ──"

fresh clean
before=$(sum)
out=$(run); rc=$?
[ "$rc" -eq 0 ] && ok "clean fixture exits 0" || bad "clean fixture rc=$rc"
hasnt "clean fixture has no warning" "$out" "⚠"
hasnt "never prints a fail mark" "$out" "✗"
has "clean: default_subagent_model shown" "$out" "default_subagent_model = model-b"
[ "$(sum)" = "$before" ] && ok "clean run leaves \$HOME/.codex unchanged" || bad "\$HOME/.codex changed"

fresh d1
cfg 'model = "model-a"
[agents]
default_subagent_model = "model-zzz"
default_subagent_reasoning_effort = "high"'
out=$(run)
has "D1 slug not in catalog" "$out" "⚠.*model-zzz.*not in"

fresh d1b
catalog 0.158.0
cfg 'model = "model-a"
[agents]
default_subagent_model = "model-zzz"'
out=$(run)
has "D1 catalog from another client → unknown" "$out" "- .*catalog from another client.*unknown"
hasnt "D1 mismatch: no slug warning" "$out" "⚠.*model-zzz"

fresh d1c
rm "$HOME/.codex/models_cache.json"
out=$(run)
has "D1 catalog unreadable → unknown" "$out" "- .*catalog.*unknown"

fresh d2
for e in max ultra persistent; do
  cfg "[agents]
default_subagent_model = \"model-b\"
default_subagent_reasoning_effort = \"$e\""
  out=$(run)
  has "D2 subagent effort $e" "$out" "⚠.*default_subagent_reasoning_effort = $e"
done

fresh d3
cfg 'model = "model-b"
model_reasoning_effort = "ultra"'
out=$(run)
has "D3 Lead ultra on a model without ultra" "$out" "⚠.*ultra.*model-b"
sed -i.bak 's/model-b/model-a/' "$HOME/.codex/config.toml"
out=$(run); rc=$?
[ "$rc" -eq 0 ] && ok "D3 negative run exits 0" || bad "D3 negative run rc=$rc"
has "D3 negative run completed (slot cap line printed)" "$out" "slot cap"
hasnt "D3 on ultra-capable model no warn" "$out" "⚠.*Lead"

fresh d4
cfg 'model = "model-a"
model_reasoning_effort = "ultra"'
out=$(run)
has "D4 slot cap default" "$out" "- .*Lead ultra.*slot cap.*default"
cfg 'model = "model-a"
model_reasoning_effort = "ultra"
[features.multi_agent_v2]
max_concurrent_threads_per_session = 7'
out=$(run)
has "D4 slot cap from v2 key" "$out" "- .*Lead ultra.*slot cap.*7"
cfg 'model = "model-a"
model_reasoning_effort = "ultra"
[agents]
max_threads = 5'
out=$(run)
has "D4 slot cap from agents.max_threads" "$out" "- .*Lead ultra.*slot cap.*5"

fresh d5
printf '2.4.0\n' > "$HOME/.codex/agents/.rolepod-agents-version"
out=$(run)
has "D5 stale stamp" "$out" "⚠.*2\.4\.0.*2\.5\.0.*next Codex session"

fresh d7
cfg 'model = "model-a"
[features]
plugin_hooks = true
multi_agent_mode = true
enable_fanout = true'
out=$(run)
has "D7 removed keys named" "$out" "- .*plugin_hooks.*multi_agent_mode.*enable_fanout"
cfg 'model = "model-a"
[mcp_servers.x.env]
plugin_hooks = "not a codex key"'
out=$(run)
hasnt "D7 same key name under an unrelated table is not reported" "$out" "removed"
cfg 'model = "model-a"
[[mcp_servers]]
plugin_hooks = "in an array of tables"
[agents]
default_subagent_model = "model-b"'
out=$(run); rc=$?
[ "$rc" -eq 0 ] && ok "array of tables: exits 0" || bad "array of tables rc=$rc"
hasnt "D7 array of tables outside Codex tables not reported" "$out" "removed"

fresh d8
out=$(run)
has "D8 engines with versions" "$out" "- .*0\.159\.2.*0\.159\.0"
hasnt "D8 same major.minor: no upgrade hint" "$out" "upgrade"
stub "$tmp/app-codex" 0.160.1
out=$(run)
has "D8 differing major.minor recommends upgrade" "$out" "- .*upgrade"
stub "$tmp/app-codex" 0.159.0

fresh persistent
cfg 'model = "model-a"
model_reasoning_effort = "persistent"'
out=$(run)
has "persistent Lead info" "$out" "- .*persistent.*follow-up.*explicit-only"

fresh role
printf 'model_reasoning_effort = "ultra"\n' > "$HOME/.codex/agents/rolepod-x.toml"
out=$(run)
has "role effort above xhigh" "$out" "⚠.*rolepod-x\.toml"

fresh bad
printf 'this is [ not toml' > "$HOME/.codex/config.toml"
out=$(run); rc=$?
[ "$rc" -eq 0 ] && ok "unparseable config exits 0" || bad "unparseable config rc=$rc"
has "unparseable config → one unknown line" "$out" "- .*unknown"

fresh secret
cfg 'model = "model-a"
[mcp_servers.x]
api_key = "sk-FAKE-SECRET-123"
[agents]
default_subagent_model = "model-b"'
out=$(run)
hasnt "a secret in an unrelated table is never printed" "$out" "sk-FAKE-SECRET-123"
has "secret fixture still reports the checked key" "$out" "default_subagent_model = model-b"

fresh unset
cfg 'model = "model-a"'
out=$(run)
has "default_subagent_model unset → warning" "$out" "⚠.*default_subagent_model unset"

fresh nonpm
out=$(RUNPATH="/usr/bin:/bin" run)
has "npm codex absent + app present" "$out" "- .*engines: npm CLI absent, ChatGPT\.app 0\.159\.0"
hasnt "npm absent: no upgrade hint" "$out" "upgrade"

fresh noapp
out=$(APPBIN="$tmp/no-such-app" run)
has "app absent" "$out" "- .*engines: npm CLI 0\.159\.2, ChatGPT\.app absent"

fresh nocfg
rm "$HOME/.codex/config.toml"
out=$(run); rc=$?
[ "$rc" -eq 0 ] && ok "no config.toml exits 0" || bad "no config.toml rc=$rc"
has "no config.toml → engines line still printed" "$out" "- .*engines: npm CLI 0\.159\.2, ChatGPT\.app 0\.159\.0"

fresh appmatch
stub "$tmp/bin/codex" 0.160.0
cfg 'model = "model-a"
[agents]
default_subagent_model = "model-zzz"'
out=$(run)
has "catalog trusted when only the app engine matches" "$out" "⚠.*model-zzz.*not in"
hasnt "catalog matching the app engine is not 'another client'" "$out" "another client"
stub "$tmp/bin/codex" 0.159.2

fresh noeng
cfg 'model = "model-a"
[agents]
default_subagent_model = "model-zzz"'
out=$(RUNPATH="/usr/bin:/bin" APPBIN="$tmp/no-such-app" run)
has "no engine found → catalog unknown" "$out" "- .*catalog.*unknown"
hasnt "no engine found: no slug warning" "$out" "⚠.*model-zzz"
has "unverified default_subagent_model has no pass mark" "$out" "- .*default_subagent_model = model-zzz"

if [ "$fail" -eq 0 ]; then echo "doctor-codex: pass"; exit 0; fi
echo "doctor-codex: $fail failure(s)"; exit 1
