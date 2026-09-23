#!/bin/bash
# bench-hooks — smoke: the advisory bench runs end to end on a small
# synthetic transcript, prints one row per registered Claude hook payload
# and the per-event sums, exits 0 whatever the numbers say (it is never a
# gate), and --json emits parseable rows.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fail=0
echo "── bench-hooks ──"
out=$(RUNS=1 SIZE_MB=1 bash "$REPO_DIR/scripts/bench-hooks.sh" 2>&1); rc=$?
[ "$rc" -eq 0 ] && echo "  ✓ exits 0 (advisory)" || { echo "  ✗ exit $rc"; fail=$((fail+1)); }
rows=$(printf '%s\n' "$out" | grep -cE '^(PreToolUse|PostToolUse|UserPromptSubmit) ')
[ "$rows" -ge 10 ] && echo "  ✓ one row per hook payload ($rows rows)" || { echo "  ✗ only $rows rows"; fail=$((fail+1)); }
printf '%s\n' "$out" | grep -q 'per tool call' && echo "  ✓ per-event sums printed" || { echo "  ✗ no per-event sums"; fail=$((fail+1)); }
printf '%s\n' "$out" | grep -q ' missing' && { echo "  ✗ a benched hook is missing from hooks/: $(printf '%s\n' "$out" | grep ' missing')"; fail=$((fail+1)); } || echo "  ✓ every benched hook exists"
j=$(RUNS=1 SIZE_MB=1 bash "$REPO_DIR/scripts/bench-hooks.sh" --json 2>/dev/null)
printf '%s' "$j" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["runs"]==1 and len(d["rows"])>=10 and "PreToolUse Edit" in d["per_event_ms"]' 2>/dev/null \
  && echo "  ✓ --json rows parse" || { echo "  ✗ --json output not parseable"; fail=$((fail+1)); }
if [ "$fail" -eq 0 ]; then echo "bench-hooks: pass"; exit 0; fi
echo "bench-hooks: $fail failure(s)"; exit 1
