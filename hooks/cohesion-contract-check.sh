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
#   - 2nd+ Agent spawn within last 10 tool uses AND no cohesion-contract
#     artifact in session (Write/Edit of contract.md / SPEC.md / cohesion.md /
#     specs/* / contracts/* / <feature>-cohesion-YYYY-MM-DD.md /
#     <feature>-contract[-…].md, OR a Bash command whose target is one of
#     those names — a redirect / cp / mv / install / tee, not a mere
#     mention) → HARD block
#
# Bypass:
#   ROLEPOD_GATES_SOFT=1   — soft warn instead of block
#   ROLEPOD_NO_CONTRACT=1  — explicit acknowledgment that this Agent spawn
#                            doesn't need a contract (e.g. read-only Explore,
#                            single-domain task, fix for hook-found issue)
set -euo pipefail

# Bypass accountability: a used bypass is recorded to .rolepod/evidence/bypass.log
# (reason via ROLEPOD_BYPASS_REASON), never blocked. Fail-open on any error.
rolepod_log_bypass() {
  _rlb_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  [ -n "$_rlb_root" ] || return 0
  mkdir -p "$_rlb_root/.rolepod/evidence" 2>/dev/null || return 0
  _rlb_reason="${ROLEPOD_BYPASS_REASON:-unreasoned}"
  _rlb_reason="${_rlb_reason//\"/ }"
  printf '{"ts":"%s","hook":"%s","var":"%s","reason":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$_rlb_reason" \
    >> "$_rlb_root/.rolepod/evidence/bypass.log" 2>/dev/null || true
}

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL=$(echo "$INPUT" | python3 -I -c "import sys,json;print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

# Match only the Agent / Task tool. (Both names are valid across CC versions.)
case "$TOOL" in
  Agent|Task) ;;
  *) exit 0 ;;
esac

# Bypass paths: explicit env override OR sub-agent self-delegation.
if [ "${ROLEPOD_NO_CONTRACT:-0}" = "1" ]; then rolepod_log_bypass "cohesion-contract-check" "ROLEPOD_NO_CONTRACT"; exit 0; fi

SOFT_MODE=0
[ "${ROLEPOD_GATES_SOFT:-0}" = "1" ] && { SOFT_MODE=1; rolepod_log_bypass "cohesion-contract-check" "ROLEPOD_GATES_SOFT"; }

# Read-only / strategy agents don't need a contract — they investigate, they
# don't write code. Skip these specific subagent types.
SUBAGENT=$(printf '%s' "$INPUT" | python3 -I -c "
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
  Explore|Plan|general-purpose|universal-reviewer|qa-tester|security-engineer|claude-code-guide|scout|system-architect)
    # Read-only / research / review roles — a parallel fan-out of these writes no
    # product code, so no cohesion contract is needed — plus the contract's own
    # author: system-architect writes the spec / contract (write-spec §3,
    # write-plan §4), dispatched ONE at a time, so requiring a contract before
    # it is circular (v2.115.0). Primary writers
    # (incl. ui-ux-designer and every *-developer / *-engineer) are
    # deliberately NOT here: fanned out in parallel they can stomp shared files.
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
# cohesion.md / SPEC.md / specs/*.md / contracts/*.md, plus the write-plan
# prescribed names (<feature>-cohesion-YYYY-MM-DD.md / <feature>-contract[-…].md)
# via Edit/Write OR a Bash command that WRITES one (redirect / cp / mv /
# install / tee — a command that only mentions the name, e.g. `cat`/`grep`/
# `rm`, does not count).
CONTRACT_PRESENT=$(printf '%s' "$INPUT" | python3 -I -c "
import sys, json, os, re
try:
    d = json.load(sys.stdin)
except Exception:
    print('no'); sys.exit(0)

tp = d.get('transcript_path') or ''
if not tp or not os.path.isfile(tp):
    print('no'); sys.exit(0)

# Name alternation shared by both branches below. Single backslash
# throughout (bash's double-quote layer leaves \. and \d as-is, so this
# reaches python unchanged) — do NOT double these if this block ever moves
# into a real .py file, \\. there means backslash-then-any-char.
NAME = (
    r'(?:contract|cohesion|SPEC|spec)\.(?:md|markdown)'
    r'|specs/[^\s]+\.md'
    r'|contracts/[^\s]+\.md'
    r'|[^\s/]+-cohesion-\d{4}-\d{2}-\d{2}\.(?:md|markdown)'
    r'|[^\s/]+-contract(?:-[^\s/]+)?\.(?:md|markdown)'
)
# Trailing boundary: rejects near-miss suffixes the alternation's own .md
# would otherwise half-match (spec.mdx, foo-contract.md.bak); the
# alternation itself is what rejects an unrelated name (README.md).
TAIL = r'(?=$|[\s' + chr(39) + r'\"<>|;&#])'
# Destination-only tail for cp/mv/install: the name must be that command's
# LAST argument (the write target), not an earlier one — 'mv contract.md
# /tmp/x' names contract.md as the SOURCE being moved away, not written.
DEST_TAIL = r'(?=\s*$|\s*[;&|])'
# Optional quoting / directory prefix ahead of the name itself.
LEAD = r'(?:[\"\x27])?(?:[^\s]*/)?'

# Edit/Write file_path: a plain filesystem path, so start-of-string or
# after the last '/' is the only shape it takes.
PATH_PAT = re.compile(r'(?:^|/)(?:' + NAME + r')' + TAIL, re.IGNORECASE)

# Bash command text: the name can sit anywhere in the string, so a bare
# 'mention' (cat/grep/rm) must NOT satisfy the gate — only require the
# match to be the target of a write. Two shapes, each with its own tail:
#   - redirect / tee: loose TAIL (a heredoc marker or '2>&1' may follow).
#   - cp/mv/install: DEST_TAIL — must be the LAST argument, and the scan
#     never crosses into a DIFFERENT command via && / ; / | (otherwise
#     'cp a.md b.md && cat contract.md' would falsely clear the gate on an
#     unrelated later mention).
BASH_WRITE_PAT = re.compile(
    r'(?:' +
    r'(?:>>?\s*|\btee\b\s+(?:-a\s+)?)' + LEAD + r'(?:' + NAME + r')' + TAIL +
    r'|' +
    r'\b(?:cp|mv|install)\b[^\n;&|]*?\s' + LEAD + r'(?:' + NAME + r')' + DEST_TAIL +
    r')',
    re.IGNORECASE,
)
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
                name = b.get('name')
                inp = b.get('input') or {}
                if name in EDIT_TOOLS:
                    path = inp.get('file_path') or inp.get('notebook_path') or ''
                    if PATH_PAT.search(path):
                        print('yes')
                        sys.exit(0)
                elif name == 'Bash':
                    cmd = inp.get('command') or ''
                    if BASH_WRITE_PAT.search(cmd):
                        print('yes')
                        sys.exit(0)
except Exception:
    pass
print('no')
" 2>/dev/null || echo "no")

[ "$CONTRACT_PRESENT" = "yes" ] && exit 0

# No contract + parallel Agent spawn detected → block (or warn in soft mode).
REASON="cohesion-contract gate: parallel Agent ('$SUBAGENT') with $RECENT_AGENTS recent spawn(s) and NO cohesion contract. "
REASON+="Fix: write contract.md (or SPEC.md / cohesion.md / specs/<name>.md / contracts/<name>.md / <feature>-cohesion-YYYY-MM-DD.md / <feature>-contract.md) — shared interfaces, RED tests, integration points, who owns each path — then re-spawn. "
REASON+="Read-only / single-domain spawn → ask the USER to set ROLEPOD_NO_CONTRACT=1; env bypass is user-set only."

if [ "$SOFT_MODE" -eq 1 ]; then
  # Soft mode: emit additionalContext, don't block. Env-pass REASON so a crafted
  # subagent_type cannot escape the Python string literal (RCE).
  ROLEPOD_HOOK_MSG="$REASON" python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || true
  exit 0
fi

# Hard block: deny JSON. Env-pass REASON so a crafted subagent_type cannot
# escape the Python string literal (RCE).
ROLEPOD_HOOK_MSG="$REASON" python3 -I -c "
import json, os
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'permissionDecision': 'deny',
    'permissionDecisionReason': os.environ.get('ROLEPOD_HOOK_MSG', '')
  }
}))
" 2>/dev/null || echo '{}'

exit 0
