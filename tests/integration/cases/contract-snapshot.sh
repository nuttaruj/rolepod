#!/bin/bash
# contract-snapshot — the CLI contract gate's four verdicts, proven on
# fixture strings dumps so the case never depends on which CLIs this
# machine has installed: OK, DRIFT (added and removed members named),
# CANNOT-OBSERVE (no snapshot / no strings file — never exit 0), usage.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$REPO_DIR/scripts/contract-snapshot.sh"
fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

check() { # $1 desc, $2 expected rc, $3 actual rc, $4 output, $5 grep-must-match
  if [ "$3" -eq "$2" ] && printf '%s\n' "$4" | grep -qE "$5"; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1 (expected rc=$2 matching /$5/, got rc=$3: $(printf '%s' "$4" | head -c 200))"
    fail=$((fail+1))
  fi
}

echo "── contract-snapshot ──"
# A fake codex strings dump carrying a known contract.
cat > "$tmp/codex-a.txt" <<'EOF'
SessionStart
UserPromptSubmit
PreToolUse
PostToolUse
Stop
SubagentStart
spawn_agent
wait_agent
close_agent
task_name
agent_type
fork_turns
minimal
low
medium
high
xhigh
max
ultra
persistent
none
default_subagent_model
default_subagent_reasoning_effort
xmax_depthjob_max_runtime_secondsy
tool_namespace
hide_spawn_agent_metadata
Proactive multi-agent delegation
ExplicitRequestOnly
EOF
SNAP="$tmp/codex.snapshot"

out=$(bash "$SCRIPT" --check --cli codex --from-strings "$tmp/codex-a.txt" --version 0.1.0 --snapshot "$SNAP" 2>&1); rc=$?
check "no snapshot yet → CANNOT-OBSERVE, exit 2" 2 "$rc" "$out" "CANNOT-OBSERVE codex"

out=$(bash "$SCRIPT" --update --cli codex --from-strings "$tmp/codex-a.txt" --version 0.1.0 --snapshot "$SNAP" 2>&1); rc=$?
check "--update writes the snapshot, exit 0" 0 "$rc" "$out" "UPDATED codex 0.1.0"
grep -q '^effort_levels: high low max medium minimal none persistent ultra xhigh$' "$SNAP" \
  && echo "  ✓ effort enum recorded sorted (persistent + none)" || { echo "  ✗ effort enum line wrong: $(grep effort "$SNAP")"; fail=$((fail+1)); }
grep -q '^multi_agent_v2_keys: hide_spawn_agent_metadata tool_namespace$' "$SNAP" \
  && echo "  ✓ multi_agent_v2_keys rendered" || { echo "  ✗ multi_agent_v2_keys line wrong: $(grep multi_agent "$SNAP")"; fail=$((fail+1)); }
grep -qE '^agents_keys: .*job_max_runtime_seconds.*max_depth|^agents_keys: .*max_depth.*job_max_runtime_seconds' "$SNAP" \
  && echo "  ✓ agents_keys carries max_depth + job_max_runtime_seconds from one glued string (contains())" || { echo "  ✗ agents_keys line wrong: $(grep agents_keys "$SNAP")"; fail=$((fail+1)); }

grep -q '^delegation_text: ExplicitRequestOnly proactive_delegation$' "$SNAP" \
  && echo "  ✓ delegation_text anchors recorded (Proactive text + ExplicitRequestOnly)" || { echo "  ✗ delegation_text line wrong: $(grep delegation "$SNAP")"; fail=$((fail+1)); }

out=$(bash "$SCRIPT" --check --cli codex --from-strings "$tmp/codex-a.txt" --version 0.2.0 --snapshot "$SNAP" 2>&1); rc=$?
check "same facts, newer version → OK, exit 0 (version is informational)" 0 "$rc" "$out" "OK codex 0.2.0: 7 fact sets unchanged \(snapshot taken at 0.1.0\)"

# ROLEPOD_CODEX_BIN swaps the binary: version and header come from the stub, not PATH.
printf '#!/bin/sh\n[ "$1" = "--version" ] && echo "codex-cli 9.9.9"\nexit 0\n' > "$tmp/stub-codex"
head -c 6000000 /dev/zero | tr '\0' 'x' >> "$tmp/stub-codex"; chmod +x "$tmp/stub-codex"
out=$(ROLEPOD_CODEX_BIN="$tmp/stub-codex" bash "$SCRIPT" --print --cli codex 2>&1); rc=$?
check "ROLEPOD_CODEX_BIN stub → --print header names 9.9.9 and the stub path" 0 "$rc" "$out" "codex -- taken at 9\.9\.9 .*$tmp/stub-codex"

# Drift: a hook event appears, an effort level disappears.
sed -e '/^ultra$/d' "$tmp/codex-a.txt" > "$tmp/codex-b.txt"; echo "SubagentStop" >> "$tmp/codex-b.txt"
out=$(bash "$SCRIPT" --check --cli codex --from-strings "$tmp/codex-b.txt" --version 0.2.0 --snapshot "$SNAP" 2>&1); rc=$?
check "an event added + an effort removed → DRIFT, exit 1, both named" 1 "$rc" "$out" "DRIFT codex 0.2.0 .*effort_levels: \+- -ultra.*hook_events: \+SubagentStop -- "

out=$(bash "$SCRIPT" --check --cli codex --from-strings "$tmp/missing.txt" --version 0.2.0 --snapshot "$SNAP" 2>&1); rc=$?
check "unreadable strings file → CANNOT-OBSERVE, exit 2" 2 "$rc" "$out" "CANNOT-OBSERVE codex: strings file not readable"

out=$(bash "$SCRIPT" --frobnicate 2>&1); rc=$?
check "bad flag → usage, exit 3" 3 "$rc" "$out" "usage:"

# The committed snapshots parse and carry the fact sets the hooks depend on.
for cli in claude codex; do
  f="$REPO_DIR/tests/contract/$cli.snapshot"
  [ -f "$f" ] && grep -q '^hook_events: .*PreToolUse' "$f" \
    && echo "  ✓ committed $cli snapshot present with hook_events" \
    || { echo "  ✗ committed $cli snapshot missing or without PreToolUse"; fail=$((fail+1)); }
done

if [ "$fail" -eq 0 ]; then echo "contract-snapshot: pass"; exit 0; fi
echo "contract-snapshot: $fail failure(s)"; exit 1
