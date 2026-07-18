#!/bin/bash
# PreToolUse(Bash) — path-aware gate on `git commit`.
#
# Default behavior (path-aware tiering — reduces overforce for day-to-day work):
#   Trivial diff (≤5 lines, 1 file, 0 logic lines, no risky path)
#                                  → silent auto-pass
#   Normal code (logic but no high-risk path)
#                                  → SOFT warn (additionalContext, exit 0)
#                                    Lead sees S1-S5 / T1-T6 / F1-F5 reminder.
#                                    Commit proceeds.
#   High-risk path matched (auth/billing/payment/migration/credit/permission/
#                            secret/crypto/token)
#                                  → HARD block (exit 2 + permissionDecision: deny)
#                                    Lead must run gates, bypass explicitly.
#
# Env overrides:
#   ROLEPOD_GATES_HARD=1   — escalate normal code from SOFT warn to HARD block
#                            (recovers pre-change behavior across the board).
#   ROLEPOD_GATES_SOFT=1   — suppress ALL warnings entirely (silent).
#   ROLEPOD_GATES_PASSED=1 — inline bypass for one commit
#                            (e.g. `ROLEPOD_GATES_PASSED=1 git commit ...`).
#   [gates: pass]          — bypass marker inside commit message body.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
[ "$TOOL" = "Bash" ] || exit 0

CMD=$(echo "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Match git commit — token walk, not adjacency, so flag-separated forms
# (`git -C . commit`, `git -c k=v commit`) are gated too.
IS_COMMIT=$(printf '%s' "$CMD" | python3 -c "
import sys, shlex, os
cmd = sys.stdin.read()
try:
    toks = shlex.split(cmd)
except ValueError:
    toks = cmd.split()
VALUE_OPTS = {'-C', '--git-dir', '--work-tree', '--namespace', '--exec-path'}
hit = 0
for i, t in enumerate(toks):
    if os.path.basename(t) == 'git':
        j = i + 1
        while j < len(toks) and toks[j].startswith('-'):
            if toks[j] in VALUE_OPTS:
                j += 2
            elif toks[j] == '-c' and j + 1 < len(toks) and '=' in toks[j + 1]:
                j += 2
            else:
                j += 1
        if j < len(toks) and toks[j] == 'commit':
            hit = 1
            break
print(hit)
" 2>/dev/null || echo 0)
[ "$IS_COMMIT" = "1" ] || exit 0

if [ "${ROLEPOD_GATES_SOFT:-0}" = "1" ]; then
  exit 0
fi

# Compute diff stats — skip gate if trivial
DIFF_STAT=$(git diff --cached --numstat 2>/dev/null || echo "")
if [ -z "$DIFF_STAT" ]; then
  # No staged changes — let git's own error fire
  exit 0
fi

FILES_CHANGED=$(echo "$DIFF_STAT" | wc -l | tr -d ' ')
LINES_CHANGED=$(echo "$DIFF_STAT" | awk '{a+=$1; b+=$2} END {print a+b}')
LINES_CHANGED=${LINES_CHANGED:-0}

# High-risk path detection
# High-risk path detection — anchored to path segments (avoids matching e.g.
# `session_state.py` for the hooks helper, where "session" is part of the
# identifier not a security surface).
HIGH_RISK=$(echo "$DIFF_STAT" | awk '{print $3}' | grep -iE '(^|/|_)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices)(/|\.|_|$)' | head -1 || true)

# Logic-bearing line count — non-comment, non-blank, non-pure-rename lines
LOGIC_LINES=$(git diff --cached -U0 2>/dev/null | grep -E '^[+-]' | grep -vE '^[+-]{3}' | grep -vE '^[+-][[:space:]]*$' | grep -vE '^[+-][[:space:]]*(#|//|/\*|\*/?|--|;)' || true)
if [ -z "$LOGIC_LINES" ]; then
  LOGIC_COUNT=0
else
  LOGIC_COUNT=$(printf '%s\n' "$LOGIC_LINES" | wc -l | tr -d ' ')
fi

# Auto-skip path: trivial commit
if [ "$FILES_CHANGED" -eq 1 ] && [ "$LINES_CHANGED" -le 5 ] && [ "$LOGIC_COUNT" -eq 0 ] && [ -z "$HIGH_RISK" ]; then
  exit 0
fi

# T-gate addition (Fix 2): inspect session transcript for test edits.
# Logic: high-risk path diff + 0 test edits this session → strengthen block.
#        Normal code diff + 0 test edits → escalate warn wording.
SESSION_STATE="$(dirname "$0")/lib/session_state.py"
TEST_EDITS=0
HIGH_RISK_EDITS=0
REVIEWERS=0
if [ -f "$SESSION_STATE" ] && command -v python3 >/dev/null 2>&1; then
  # ONE transcript scan for all three counts (see gate-reminder.sh).
  COUNTS=$(printf '%s' "$INPUT" | python3 "$SESSION_STATE" count-all 2>/dev/null || echo "0 0 0")
  read -r TEST_EDITS HIGH_RISK_EDITS REVIEWERS <<< "$COUNTS"
fi
TEST_EDITS=${TEST_EDITS:-0}
HIGH_RISK_EDITS=${HIGH_RISK_EDITS:-0}
REVIEWERS=${REVIEWERS:-0}

# Bypass markers are honored ONLY with observable session evidence — a
# blocked model must not be able to self-release by echoing the marker in
# its very next tool call ("claim-based bypass"). Evidence = the session
# transcript shows ≥1 test edit or ≥1 reviewer dispatch. Every honored
# bypass is logged.
BYPASS_REQUESTED=0
echo "$CMD" | grep -qE 'ROLEPOD_GATES_PASSED=1' && BYPASS_REQUESTED=1
echo "$CMD" | grep -qE '\[gates:[[:space:]]*pass\]' && BYPASS_REQUESTED=1
BYPASS_IGNORED=""
if [ "$BYPASS_REQUESTED" -eq 1 ]; then
  if [ "$TEST_EDITS" -gt 0 ] || [ "$REVIEWERS" -gt 0 ]; then
    mkdir -p "$HOME/.rolepod" 2>/dev/null || true
    printf '%s bypass honored (tests=%s reviewers=%s): %.200s\n' \
      "$(date '+%Y-%m-%dT%H:%M:%S')" "$TEST_EDITS" "$REVIEWERS" "$CMD" \
      >> "$HOME/.rolepod/gate-bypass.log" 2>/dev/null || true
    exit 0
  fi
  BYPASS_IGNORED="Bypass marker present but IGNORED — session shows 0 test edits and 0 reviewer dispatches; the marker is honored only with gate evidence. "
fi

# Build deny reason
REASON="precommit-gate BLOCKED. ${BYPASS_IGNORED}"
REASON+="Diff: $FILES_CHANGED files / $LINES_CHANGED lines / $LOGIC_COUNT logic lines. "
REASON+="Session: $TEST_EDITS test edits / $HIGH_RISK_EDITS high-risk edits / $REVIEWERS reviewer dispatches. "
[ -n "$HIGH_RISK" ] && REASON+="HIGH-RISK path: $HIGH_RISK → mandatory qa-tester + security-engineer review. "
if [ "$HIGH_RISK_EDITS" -gt 0 ] && [ "$TEST_EDITS" -eq 0 ]; then
  REASON+="NO TEST EDITS in this session despite touching high-risk code — T-gate violation (T1: bug/feature/migration/auth/billing → test required). "
fi
if [ -n "$HIGH_RISK" ] && [ "$REVIEWERS" -eq 0 ]; then
  REASON+="NO REVIEWER AGENT dispatched (qa-tester / security-engineer / universal-reviewer) — high-risk path requires adversarial review. "
fi
REASON+="Run gates explicitly: S1-S5 (simplicity) + T1-T6 (tests) + F1-F5 (failure-mode). "
REASON+="The fast path is running the gates for real — a bypass marker is honored only when the session already shows test or reviewer evidence."

# Decide: HARD block vs SOFT warn
HARD_BLOCK=0
if [ -n "$HIGH_RISK" ]; then
  HARD_BLOCK=1
elif [ "${ROLEPOD_GATES_HARD:-0}" = "1" ]; then
  HARD_BLOCK=1
# Fix 2: escalate to HARD when high-risk *code edits* happened this session
# but Lead never wrote a test. Catches the "session touched auth + nobody
# wrote a test" pattern even when the FINAL commit diff is small.
elif [ "$HIGH_RISK_EDITS" -gt 0 ] && [ "$TEST_EDITS" -eq 0 ]; then
  HARD_BLOCK=1
fi

if [ "$HARD_BLOCK" -eq 1 ]; then
  # Env-passed — quotes in the reason must not break the JSON emitter.
  ROLEPOD_HOOK_MSG="$REASON" python3 -c "
import json, os
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'permissionDecision': 'deny',
    'permissionDecisionReason': os.environ.get('ROLEPOD_HOOK_MSG', '')
  }
}))
" 2>/dev/null || echo "{}"
  # exit 0 (not 2): Claude Code parses the stdout permissionDecision JSON only on
  # exit 0 — on exit 2 it reads stderr (empty here), so the deny reason is lost.
  # Matches gate-reminder.sh's proven deny path.
  exit 0
fi

# SOFT warn path — emit reminder, exit 0
WARN="precommit-gate SOFT warn. "
WARN+="Diff: $FILES_CHANGED files / $LINES_CHANGED lines / $LOGIC_COUNT logic lines (normal code, no high-risk path). "
WARN+="Recommend running S1-S5 (simplicity) + T1-T6 (tests) + F1-F5 (failure-mode) before commit. "
WARN+="Set ROLEPOD_GATES_HARD=1 to enforce blocking on normal diffs."

ROLEPOD_HOOK_MSG="$WARN" python3 -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || true

exit 0
