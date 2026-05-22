#!/bin/bash
# PreToolUse(Agent) — enforce cohesion contract before parallel Agent spawn.
#
# Real-world failure: Lead spawned 2 parallel engineering agents on shared
# API contract without writing a contract.md first. The Core 10 `write-plan`
# skill owns the cohesion-contract step but nothing forces Lead to use
# it. This hook makes the trigger structural.
#
# Logic:
#   - Single Agent spawn → silent pass (no parallel concern)
#   - 2nd+ Agent spawn within last 10 tool uses AND no contract.md / spec.md
#     edit in session → HARD block with reason pointing to the skill
#
# Bypass:
#   ROLEPOD_GATES_SOFT=1   — soft warn instead of block
#   ROLEPOD_NO_CONTRACT=1  — explicit acknowledgment that this Agent spawn
#                            doesn't need a contract (e.g. read-only Explore,
#                            single-domain task, fix for hook-found issue)
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

# Match only the Agent / Task tool. (Both names are valid across CC versions.)
case "$TOOL" in
  Agent|Task) ;;
  *) exit 0 ;;
esac

# Bypass paths: explicit env override OR sub-agent self-delegation.
if [ "${ROLEPOD_NO_CONTRACT:-0}" = "1" ]; then exit 0; fi

SOFT_MODE=0
[ "${ROLEPOD_GATES_SOFT:-0}" = "1" ] && SOFT_MODE=1

# Read-only / strategy agents don't need a contract — they investigate, they
# don't write code. Skip these specific subagent types.
SUBAGENT=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('subagent_type', '') or '')
except Exception:
    print('')
" 2>/dev/null || echo "")

# Strip a plugin namespace prefix (rolepod:qa-tester -> qa-tester) so
# plugin-installed agents match the whitelist exactly like built-in ones.
SUBAGENT_BARE="${SUBAGENT##*:}"

case "$SUBAGENT_BARE" in
  Explore|Plan|general-purpose|universal-reviewer|qa-tester|security-engineer|claude-code-guide|business-analyst|product-manager|customer-success|growth-marketer|tech-writer|ui-ux-designer)
    # These are either read-only / advisory / single-domain — no contract concern.
    exit 0
    ;;
esac

# Session-state inspection.
SESSION_STATE="$(dirname "$0")/lib/session_state.py"
[ -f "$SESSION_STATE" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

RECENT_AGENTS=$(printf '%s' "$INPUT" | python3 "$SESSION_STATE" count-recent-agent-spawns 10 2>/dev/null || echo 0)
RECENT_AGENTS=${RECENT_AGENTS:-0}

# Need 1+ recent Agent spawn to be "parallel". 0 = first spawn ever → silent pass.
[ "$RECENT_AGENTS" -lt 1 ] && exit 0

# Look for a cohesion contract artifact in the session — contract.md /
# cohesion.md / SPEC.md / specs/*.md edited or written this session.
CONTRACT_PRESENT=$(printf '%s' "$INPUT" | python3 -c "
import sys, json, os, re
try:
    d = json.load(sys.stdin)
except Exception:
    print('no'); sys.exit(0)

tp = d.get('transcript_path') or ''
if not tp or not os.path.isfile(tp):
    print('no'); sys.exit(0)

pat = re.compile(r'(^|/)(contract|cohesion|SPEC|spec)\.(md|markdown)$|(^|/)specs/.+\.md$|(^|/)contracts/.+\.md$', re.IGNORECASE)
EDIT_TOOLS = {'Edit', 'Write', 'MultiEdit', 'NotebookEdit'}

try:
    with open(tp, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue
            # Top-level tool_use OR nested in message.content
            blocks = []
            if isinstance(ev, dict) and ev.get('type') == 'tool_use':
                blocks = [ev]
            else:
                msg = ev.get('message') if isinstance(ev, dict) else None
                if isinstance(msg, dict):
                    c = msg.get('content')
                    if isinstance(c, list):
                        blocks = [b for b in c if isinstance(b, dict) and b.get('type') == 'tool_use']
            for b in blocks:
                if b.get('name') not in EDIT_TOOLS:
                    continue
                inp = b.get('input') or {}
                path = inp.get('file_path') or inp.get('notebook_path') or ''
                if pat.search(path):
                    print('yes')
                    sys.exit(0)
except Exception:
    pass
print('no')
" 2>/dev/null || echo "no")

[ "$CONTRACT_PRESENT" = "yes" ] && exit 0

# No contract + parallel Agent spawn detected → block (or warn in soft mode).
REASON="cohesion-contract gate: about to spawn parallel Agent ('$SUBAGENT') with $RECENT_AGENTS recent Agent spawn(s) in session and NO contract artifact written. "
REASON+="The Core 10 \`write-plan\` skill requires a cohesion contract BEFORE multi-agent fan-out — write contract.md (or SPEC.md / cohesion.md / specs/<name>.md / contracts/<name>.md) defining: shared interfaces, RED tests, integration points, who owns each path. Then re-spawn. "
REASON+="Single-domain / read-only spawn? Pass ROLEPOD_NO_CONTRACT=1 in env to bypass."

if [ "$SOFT_MODE" -eq 1 ]; then
  # Soft mode: emit additionalContext, don't block.
  python3 -c "
import json
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': '⚠️  $REASON'}}))
" 2>/dev/null || true
  exit 0
fi

# Hard block: deny JSON.
python3 -c "
import json
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'permissionDecision': 'deny',
    'permissionDecisionReason': '''$REASON'''
  }
}))
" 2>/dev/null || echo '{}'

exit 0
