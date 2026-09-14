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
default_subagent_model
default_subagent_reasoning_effort
gpt-5.6-luna
gpt-5.6-terra
gpt-5.6-sol
gpt-5.6-lunacodex
EOF
SNAP="$tmp/codex.snapshot"

out=$(bash "$SCRIPT" --check --cli codex --from-strings "$tmp/codex-a.txt" --version 0.1.0 --snapshot "$SNAP" 2>&1); rc=$?
check "no snapshot yet → CANNOT-OBSERVE, exit 2" 2 "$rc" "$out" "CANNOT-OBSERVE codex"

out=$(bash "$SCRIPT" --update --cli codex --from-strings "$tmp/codex-a.txt" --version 0.1.0 --snapshot "$SNAP" 2>&1); rc=$?
check "--update writes the snapshot, exit 0" 0 "$rc" "$out" "UPDATED codex 0.1.0"
grep -q '^effort_levels: high low max medium minimal ultra xhigh$' "$SNAP" \
  && echo "  ✓ effort enum recorded sorted" || { echo "  ✗ effort enum line wrong: $(grep effort "$SNAP")"; fail=$((fail+1)); }
grep -q '^model_ids: gpt-5.6-luna gpt-5.6-sol gpt-5.6-terra$' "$SNAP" \
  && echo "  ✓ glued literal (gpt-5.6-lunacodex) dropped from model ids" || { echo "  ✗ model ids: $(grep model_ids "$SNAP")"; fail=$((fail+1)); }

out=$(bash "$SCRIPT" --check --cli codex --from-strings "$tmp/codex-a.txt" --version 0.2.0 --snapshot "$SNAP" 2>&1); rc=$?
check "same facts, newer version → OK, exit 0 (version is informational)" 0 "$rc" "$out" "OK codex 0.2.0: 6 fact sets unchanged \(snapshot taken at 0.1.0\)"

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
