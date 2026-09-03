#!/bin/bash
# rolepod doctor — mechanical self-test of the enforcement layer.
#
# Answers "do the hooks actually fire, and can they actually deny?" with a
# live run instead of a README claim. A governance layer without a self-test
# asks the user to trust a mechanism that has already regressed in the wild
# (vendor hook APIs move); this script is the standing counter-evidence.
#
# What it does:
#   1. Syntax-checks every shipped hook script (bash -n) + session_state.py.
#   2. Fires the SessionStart loader and asserts valid JSON carrying the
#      enforcement-tier banner.
#   3. Proves the deny path on the three blocking hooks with synthetic
#      payloads in throwaway fixtures (never touches real HOME or repo):
#        - block-subagent-commit: subagent `git commit` → deny
#        - precommit-gate: staged high-risk diff, no tests → deny
#        - worktree-guard: second session editing a claimed file → deny
#   4. Reports installed rolepod version + enforcement tier per CLI.
#
# Exit 0 = every check passed. Any failure prints the failing check and
# exits 1. Run via `make doctor`.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0

check() { # <label> <command>
  if eval "$2" >/dev/null 2>&1; then
    printf '  ✓ %s\n' "$1"; PASS=$((PASS+1))
  else
    printf '  ✗ %s\n' "$1"; FAIL=$((FAIL+1))
  fi
}

echo "── doctor: syntax ──"
for f in "$REPO_DIR"/hooks/*.sh "$REPO_DIR"/adapters/gemini/hooks/*.sh \
         "$REPO_DIR"/adapters/codex/plugins/rolepod/hooks/*.sh \
         "$REPO_DIR"/adapters/cursor/scripts/*.sh; do
  [ -f "$f" ] || continue
  check "bash -n $(basename "$(dirname "$f")")/$(basename "$f")" "bash -n '$f'"
done
check "session_state.py imports" "python3 -c \"import sys; sys.path.insert(0,'$REPO_DIR/hooks/lib'); import session_state\""

echo "── doctor: loader emits enforcement banner ──"
# The loader reads the RENDERED core (hooks/always-on-core.md) sitting next to
# it — that file exists in the committed plugin tree, not next to the source
# template, so fire the rendered copy.
LOADER_OUT=$(printf '{}' | bash "$REPO_DIR/plugins/rolepod/hooks/always-on-loader.sh" 2>/dev/null || echo '')
check "loader output is valid JSON" "printf '%s' \"\$LOADER_OUT\" | python3 -m json.tool"
check "loader carries additionalContext" "printf '%s' \"\$LOADER_OUT\" | grep -q additionalContext"
check "loader payload within 5120B docs-safe budget" "[ \"\$(printf '%s' \"\$LOADER_OUT\" | wc -c | tr -d ' ')\" -le 5120 ]"

echo "── doctor: deny paths (synthetic fixtures) ──"
FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-doctor.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

# 3a. block-subagent-commit: a subagent running git commit must be denied.
OUT=$(printf '{"agent_id":"a1","agent_type":"backend-developer","tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' \
      | bash "$REPO_DIR/hooks/block-subagent-commit.sh" 2>/dev/null || true)
check "block-subagent-commit denies subagent git commit" "printf '%s' \"\$OUT\" | grep -q '\"deny\"'"
OUT=$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' \
      | bash "$REPO_DIR/hooks/block-subagent-commit.sh" 2>/dev/null || true)
check "block-subagent-commit allows Lead git commit" "[ -z \"\$OUT\" ]"

# 3b. precommit-gate: staged high-risk diff + zero test evidence → deny.
GITFIX="$FIX/repo"
mkdir -p "$GITFIX/src/auth"
git -C "$GITFIX" init -q 2>/dev/null
git -C "$GITFIX" -c user.email=d@d -c user.name=doctor commit -q --allow-empty -m init 2>/dev/null
printf 'def check(u):\n    return u.role == "admin"\n' > "$GITFIX/src/auth/login.py"
git -C "$GITFIX" add -A 2>/dev/null
OUT=$(cd "$GITFIX" && printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' \
      | bash "$REPO_DIR/hooks/precommit-gate.sh" 2>/dev/null || true)
check "precommit-gate denies high-risk diff w/o tests" "printf '%s' \"\$OUT\" | grep -q '\"deny\"'"
OUT=$(cd "$GITFIX" && printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' \
      | ROLEPOD_GATES_SOFT=1 ROLEPOD_BYPASS_REASON=doctor bash "$REPO_DIR/hooks/precommit-gate.sh" 2>/dev/null || true)
check "precommit-gate GATES_SOFT bypass is silent" "[ -z \"\$OUT\" ]"
check "precommit-gate bypass was logged" "grep -q '\"var\":\"ROLEPOD_GATES_SOFT\"' '$GITFIX/.rolepod/evidence/bypass.log'"

# 3c. worktree-guard: session B edits a file session A claimed → deny.
# HOME is faked so the real ~/.rolepod is never touched.
WG_PAYLOAD_A="{\"session_id\":\"sess-A\",\"cwd\":\"$GITFIX\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$GITFIX/src/auth/login.py\"}}"
WG_PAYLOAD_B="{\"session_id\":\"sess-B\",\"cwd\":\"$GITFIX\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$GITFIX/src/auth/login.py\"}}"
printf '%s' "$WG_PAYLOAD_A" | HOME="$FIX/home" bash "$REPO_DIR/hooks/worktree-guard.sh" >/dev/null 2>&1 || true
OUT=$(printf '%s' "$WG_PAYLOAD_B" | HOME="$FIX/home" bash "$REPO_DIR/hooks/worktree-guard.sh" 2>/dev/null || true)
check "worktree-guard denies cross-session same-file edit" "printf '%s' \"\$OUT\" | grep -q '\"deny\"'"
OUT=$(printf '%s' "$WG_PAYLOAD_B" | HOME="$FIX/home" ROLEPOD_ALLOW_SHARED_WORKTREE=1 ROLEPOD_BYPASS_REASON=doctor \
      bash "$REPO_DIR/hooks/worktree-guard.sh" 2>/dev/null || true)
check "worktree-guard shared-worktree bypass is silent" "[ -z \"\$OUT\" ]"

echo "── doctor: tier mapping — installed files match intent ──"
# Install-half of "no silent model fallback": the agent files on disk must
# map tier→model exactly as TIER_MODELS intends. Runtime-half (what model a
# dispatch actually runs) is not exposed by these CLIs — the dispatch-log in
# phase-log.jsonl is the audit for that (see make stats).
if python3 - "$REPO_DIR" <<'PY'
import glob, os, re, sys
repo = sys.argv[1]
TIER = {
    "claude": {"cheap": "haiku", "balanced": "sonnet", "strong": "inherit"},
    "codex": {"cheap": "gpt-5.6-luna", "balanced": "gpt-5.6-terra", "strong": "gpt-5.6-sol"},
    "gemini": {"cheap": "gemini-3-flash-preview", "balanced": "gemini-3-pro-preview", "strong": "gemini-3-pro-preview"},
}
def overlay_tiers(cli):
    out = {}
    for p in glob.glob(f"{repo}/adapters/{cli}/agent-frontmatter/*.yml"):
        m = re.search(r"^tier:\s*(\w+)", open(p).read(), re.M)
        if m:
            out[os.path.basename(p)[:-4]] = m.group(1)
    return out
home = os.environ["HOME"]
fails = 0
def check_cli(label, cli, agent_dir, fname, rx):
    global fails
    if not agent_dir or not os.path.isdir(agent_dir):
        print(f"  - {label}: target absent — skipped")
        return
    bad = []
    exp = overlay_tiers(cli)
    for name, tier in sorted(exp.items()):
        want = TIER[cli][tier]
        path = os.path.join(agent_dir, fname.format(name=name))
        if not os.path.isfile(path):
            bad.append(f"{name}: file missing")
            continue
        m = re.search(rx, open(path).read(), re.M)
        got = m.group(1).strip() if m else "(no model field)"
        if got != want:
            bad.append(f"{name}: {got} != {want}")
    if bad:
        print(f"  ✗ {label}: " + "; ".join(bad[:4]))
        fails += 1
    else:
        print(f"  ✓ {label}: {len(exp)} agents map tier→model as intended")
claude_agents = None
base = f"{home}/.claude/plugins/cache/rolepod/rolepod"
if os.path.isdir(base):
    def vkey(v):
        try:
            return [int(x) for x in v.split(".")]
        except ValueError:
            return [0]
    vs = sorted((d for d in os.listdir(base) if os.path.isdir(f"{base}/{d}")), key=vkey)
    if vs:
        claude_agents = f"{base}/{vs[-1]}/agents"
check_cli("claude installed agents", "claude", claude_agents, "{name}.md", r"^model:\s*(.+)$")
check_cli("codex installed agents", "codex", f"{home}/.codex/agents", "rolepod-{name}.toml", r'^model\s*=\s*"([^"]+)"')
check_cli("gemini installed agents", "gemini", f"{home}/.gemini/extensions/rolepod/agents", "{name}.md", r"^model:\s*(.+)$")
print("  - cursor / opencode / antigravity: no model field by design — doctrine ceiling (model-tier-policy)")
print("  - pinned ids rot with CLI updates — re-verify after upgrading: codex gpt-5.6-{luna,terra,sol}, gemini gemini-3-{flash,pro}-preview")
# Codex fan-out defaults (v2.74.0; xhigh ceiling v2.75.0) — `ultra` = deepest effort + proactive
# delegation (the agent spawns its own children; the count is the model's
# call per task, never prescribed). An UN-pinned child resolves
# explicit spawn → agents.default_subagent_* → the parent (official
# precedence); role files pin, so these two keys decide what the fan-out
# costs. The Codex analogue of the Claude fleet-tier gate — config, since
# SubagentStart fires post-spawn and cannot deny.
cfg = f"{home}/.codex/config.toml"
if os.path.isfile(cfg):
    txt = open(cfg).read()
    m = re.search(r'^\s*default_subagent_model\s*=\s*"([^"]+)"', txt, re.M)
    if not m:
        print("  ⚠ codex [agents].default_subagent_model unset — un-pinned spawns (Ultra delegation included) inherit the parent; set gpt-5.6-terra so the fan-out lands balanced (the strong slot = one named reviewer role)")
    elif "sol" in m.group(1):
        print(f"  ⚠ codex [agents].default_subagent_model = {m.group(1)} (strong) — every un-pinned child runs at strong price; the tier policy wants the balanced id here")
    else:
        print(f"  ✓ codex [agents].default_subagent_model = {m.group(1)}")
    over = [os.path.basename(p) for p in sorted(glob.glob(f"{home}/.codex/agents/rolepod-*.toml"))
            if re.search(r'^model_reasoning_effort\s*=\s*"(ultra|max)"', open(p).read(), re.M)]
    if over:
        # Advisory, not a fail: the tier-mapping check above is the hard
        # install-drift gate; a stale pre-2.75 install must not redden the
        # whole doctor (make test-integration runs it against the real HOME).
        print(f"  ⚠ codex role(s) pinned model_reasoning_effort above the xhigh ceiling (ultra = a fan-out, strong × N per dispatch; max = beyond doctrine): {', '.join(over)} — the SessionStart agent-sync hook fixes this on the next Codex launch after `codex plugin marketplace upgrade rolepod`; v2.75.0 pins xhigh")
sys.exit(1 if fails else 0)
PY
then
  printf '  ✓ tier mapping check clean\n'; PASS=$((PASS+1))
else
  printf '  ✗ tier mapping mismatch — installed files diverge from TIER_MODELS intent\n'; FAIL=$((FAIL+1))
fi

echo "── doctor: installed versions + enforcement tier ──"
report() { printf '  %-12s %-10s %s\n' "$1" "$2" "$3"; }
CLAUDE_V=$(ls "$HOME/.claude/plugins/cache/rolepod/rolepod/" 2>/dev/null | sort -V | tail -1)
report "claude"      "${CLAUDE_V:-absent}"  "hooks-live (full — deny gates mechanical)"
CODEX_V=$(ls "$HOME/.codex/plugins/cache/rolepod/rolepod/" 2>/dev/null | sort -V | tail -1)
report "codex"       "${CODEX_V:-absent}"   "hooks-live (expanded — precommit + subagent-commit deny; sibling locks)"
GEMINI_V=$(python3 -c "import json;print(json.load(open('$HOME/.gemini/extensions/rolepod/gemini-extension.json'))['version'])" 2>/dev/null)
report "gemini"      "${GEMINI_V:-absent}"  "hooks-live (advisory — reminders only, no deny)"
CURSOR_V=$(python3 -c "import json;print(json.load(open('$HOME/.cursor/plugins/local/rolepod/.cursor-plugin/plugin.json'))['version'])" 2>/dev/null)
report "cursor"      "${CURSOR_V:-absent}"  "unverified — treat gates as skill-enforced"
OC_V=$(python3 -c "import json;print(json.load(open('$HOME/.config/opencode/rolepod-version.json'))['version'])" 2>/dev/null)
report "opencode"    "${OC_V:-absent}"      "hooks-live (partial — plugin precommit deny + agent permission blocks; rest doctrine-only, no hook API)"
AGY_V=$(command -v agy >/dev/null 2>&1 && agy plugin list 2>/dev/null | grep -q '"name": "rolepod"' && echo installed)
report "antigravity" "${AGY_V:-absent}"     "unverified — treat gates as skill-enforced"

echo ""
echo "doctor: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
