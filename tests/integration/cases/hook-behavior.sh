#!/bin/bash
# hook-behavior — BEHAVIORAL tests for the enforcement hooks.
#
# The rest of the suite asserts words (bash -n + grep-for-string); this case
# pipes synthetic hook-input JSON into the actual scripts and asserts the
# deny/allow DECISION — a comment containing "HARD BLOCK" cannot pass here.
#
# Covers the empirically-proven evasions from the 2026-07 strength audit:
#   - flag-separated git forms (`git -C . commit`, `git -c k=v commit`)
#   - Codex apply_patch tool name (was disjoint from the script's filter)
#   - claim-based bypass ([gates: pass] with zero session evidence)
# Plus the evidence auto-pass (2026-07-21 WalnutZite deadlock): a high-risk
# commit with real session evidence passes with NO marker — prescribing
# `ROLEPOD_GATES_PASSED=1 git commit` collided with the platform's own
# permission layer, which reads that shape as gate circumvention.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HOOKS="$REPO_DIR/hooks"
fail=0

check() { # $1 desc, $2 expected (deny|allow), $3 output
  local desc="$1" expected="$2" out="$3"
  local verdict="allow"
  echo "$out" | grep -q '"permissionDecision": *"deny"' && verdict="deny"
  if [ "$verdict" = "$expected" ]; then
    echo "  ✓ $desc"
  else
    echo "  ✗ $desc (expected $expected, got $verdict)"
    fail=$((fail+1))
  fi
}

payload_subagent() { # $1 = command
  printf '{"agent_id":"a1","agent_type":"backend-developer","tool_name":"Bash","tool_input":{"command":%s}}' \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
}

# ── block-subagent-commit: deny destructive git, allow the rest ────────
out=$(payload_subagent 'git commit -m "x"' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent git commit → deny" deny "$out"

out=$(payload_subagent 'git -C . commit -m "x"' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent git -C . commit (flag-separated) → deny" deny "$out"

out=$(payload_subagent 'git -c user.email=x@y commit -m "x"' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent git -c k=v commit (flag-separated) → deny" deny "$out"

out=$(payload_subagent 'cd /tmp && git push origin main' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent compound git push → deny" deny "$out"

out=$(payload_subagent 'gh pr merge 42' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent gh pr merge → deny" deny "$out"

out=$(payload_subagent 'git log --oneline' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent git log → allow" allow "$out"

out=$(payload_subagent 'grep -r "git commit docs" .' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent command merely MENTIONING git commit → allow" allow "$out"

# Lead (no agent_id) is never blocked
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | bash "$HOOKS/block-subagent-commit.sh")
check "Lead git commit → allow (hook targets subagents only)" allow "$out"

# ── gate-reminder: Claude AND Codex tool names must both fire ──────────
gr() { printf '%s' "$1" | bash "$HOOKS/gate-reminder.sh"; }

out=$(gr '{"tool_name":"Edit","tool_input":{"file_path":"src/auth/login.py"}}')
echo "$out" | grep -q 'HIGH-RISK' \
  && echo "  ✓ gate-reminder Edit on auth path → high-risk banner" \
  || { echo "  ✗ gate-reminder Edit on auth path emitted nothing"; fail=$((fail+1)); }

out=$(gr '{"tool_name":"apply_patch","tool_input":{"input":"*** Begin Patch\n*** Update File: src/auth/login.py\n@@\n+x = 1\n*** End Patch"}}')
echo "$out" | grep -q 'HIGH-RISK' \
  && echo "  ✓ gate-reminder apply_patch (Codex) on auth path → high-risk banner" \
  || { echo "  ✗ gate-reminder apply_patch on auth path emitted nothing (Codex hook inert)"; fail=$((fail+1)); }

out=$(gr '{"tool_name":"Edit","tool_input":{"file_path":"docs/notes.md"}}')
[ -z "$out" ] \
  && echo "  ✓ gate-reminder normal-path edit → silent" \
  || { echo "  ✗ gate-reminder normal-path edit not silent"; fail=$((fail+1)); }

# v2.44.0: data-deletion/GDPR tokens joined the canon — doctrine listed the
# category for months while the regex silently ignored it.
out=$(gr '{"tool_name":"Edit","tool_input":{"file_path":"src/account_deletion.py"}}')
echo "$out" | grep -q 'HIGH-RISK' \
  && echo "  ✓ gate-reminder deletion-path edit → high-risk banner" \
  || { echo "  ✗ gate-reminder deletion path missed (canon narrowed?)"; fail=$((fail+1)); }

# Lead-exclusion: the banner must never recommend the session's own CLI.
out=$(ROLEPOD_LEAD_CLI=codex gr '{"tool_name":"apply_patch","tool_input":{"input":"*** Update File: src/auth/a.py"}}')
echo "$out" | grep -q 'codex exec' \
  && { echo "  ✗ gate-reminder recommends codex exec to a Codex Lead (self-review)"; fail=$((fail+1)); } \
  || echo "  ✓ gate-reminder excludes the Lead's own CLI from the reviewer list"

# ── precommit-gate: high-risk staged diff blocks; claim-bypass ignored ──
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
(
  cd "$TMP"
  git init -q .
  git config user.email t@t && git config user.name t
  mkdir -p auth
  printf 'def charge(u):\n    return u.balance - 1\n' > auth/billing.py
  git add auth/billing.py
)
pc() { # $1 = command json-escaped inline
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$TMP" && bash "$HOOKS/precommit-gate.sh") || true
}

out=$(pc 'git commit -m "add billing"')
check "precommit high-risk staged diff → deny" deny "$out"

out=$(pc 'git -C . commit -m "add billing"')
check "precommit git -C . commit (flag-separated) → deny" deny "$out"

out=$(pc 'git commit -m "add billing [gates: pass]"')
check "precommit [gates: pass] with ZERO session evidence → still deny" deny "$out"
echo "$out" | grep -q 'IGNORED' \
  && echo "  ✓ precommit deny reason states the marker was ignored" \
  || { echo "  ✗ precommit deny reason missing marker-ignored note"; fail=$((fail+1)); }

out=$(pc 'git status')
check "precommit non-commit command → allow" allow "$out"

# ── v2.39.0 single-parse regression guards ──────────────────────────────
# (a) Multi-line heredoc commit message: the command must survive the
#     $(cat) slurp INTACT — deny still fires and a bypass marker on a
#     LATER line is still detected (a read -r would truncate at line 1).
ML_CMD=$(printf 'git commit -m "$(cat <<MSGEOF\nadd billing\n\n[gates: pass]\nMSGEOF\n)"')
out=$(pc "$ML_CMD")
check "precommit multi-line heredoc commit → still deny" deny "$out"
echo "$out" | grep -q 'IGNORED' \
  && echo "  ✓ marker on line 3 of a heredoc command still detected (CMD not truncated)" \
  || { echo "  ✗ multi-line command truncated — marker on line 3 missed"; fail=$((fail+1)); }

# (b) Malformed stdin must fail-open: silent, exit 0 (the set -e +
#     read-at-EOF class that bit worktree-guard).
rc=0
out=$(printf 'not json' | (cd "$TMP" && bash "$HOOKS/precommit-gate.sh")) || rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] \
  && echo "  ✓ precommit malformed stdin → silent exit 0" \
  || { echo "  ✗ precommit malformed stdin: rc=$rc out=${out:0:60}"; fail=$((fail+1)); }
rc=0
out=$(printf '{"tool_name":"Write","tool_input":{}}' | bash "$HOOKS/worktree-guard.sh") || rc=$?
[ "$rc" -eq 0 ] \
  && echo "  ✓ worktree-guard pathless payload → exit 0 (was rc=1)" \
  || { echo "  ✗ worktree-guard pathless payload: rc=$rc"; fail=$((fail+1)); }

# ── precommit: evidence auto-pass — split by risk (v2.46.0) ─────────────
# A HIGH-RISK diff clears ONLY on a strong-class adversarial reviewer
# dispatch (security-engineer / universal-reviewer). Test edits and qa-tester
# are the balanced test floor, not the review — the CourtBook evidence:
# 672 green tests + strong impl still shipped 4 money bugs that only the
# adversarial pass caught. HOME points at $TMP so the log lands in sandbox.
TRANSCRIPT="$TMP/transcript.jsonl"
pce() { # $1 = command; hook input carries transcript_path
  printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":%s}}' \
    "$(printf '%s' "$TRANSCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$TMP" && HOME="$TMP" bash "$HOOKS/precommit-gate.sh") || true
}

printf '%s\n' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' \
  > "$TRANSCRIPT"
out=$(pce 'git commit -m "add billing"')
check "precommit high-risk + security-engineer dispatch → auto-pass" allow "$out"
echo "$out" | grep -q 'auto-passed' \
  && echo "  ✓ auto-pass surfaces an additionalContext note" \
  || { echo "  ✗ auto-pass note missing from hook output"; fail=$((fail+1)); }

printf '%s\n' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:qa-tester","prompt":"review"}}' \
  > "$TRANSCRIPT"
out=$(pce 'git commit -m "add billing"')
check "precommit high-risk + qa-tester ALONE → still deny (test floor ≠ review)" deny "$out"
echo "$out" | grep -q 'STRONG ADVERSARIAL REVIEWER' \
  && echo "  ✓ deny reason names the missing strong reviewer" \
  || { echo "  ✗ deny reason missing strong-reviewer instruction"; fail=$((fail+1)); }

printf '%s\n' \
  '{"type":"tool_use","name":"Edit","input":{"file_path":"tests/test_billing.py"}}' \
  > "$TRANSCRIPT"
out=$(pce 'git commit -m "add billing"')
check "precommit high-risk + test-edit alone → still deny (OR split by risk)" deny "$out"

# OR path stays alive for NON-path HARD blocks (env-forced): test edit clears.
TMP2=$(mktemp -d)
(
  cd "$TMP2"
  git init -q .
  git config user.email t@t && git config user.name t
  printf 'x = 1\n' > util.py
  git add util.py
)
out=$(printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":"git commit -m x"}}' \
  "$(printf '%s' "$TRANSCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
  | (cd "$TMP2" && HOME="$TMP" ROLEPOD_GATES_HARD=1 bash "$HOOKS/precommit-gate.sh") || true)
check "precommit env-forced block on normal diff + test edit → auto-pass (OR preserved)" allow "$out"
rm -rf "$TMP2"

# ── precommit: content-based high-risk (v2.46.0) ────────────────────────
# Money-movement term in an added line of a generically named file must
# classify HIGH-RISK even though no path segment matches the risk regex.
TMP3=$(mktemp -d)
(
  cd "$TMP3"
  git init -q .
  git config user.email t@t && git config user.name t
  mkdir -p services tests
  printf 'def close(b):\n    return refund_amount(b)\n' > services/closure.py
  git add services/closure.py
)
: > "$TRANSCRIPT"
out=$(printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":"git commit -m x"}}' \
  "$(printf '%s' "$TRANSCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
  | (cd "$TMP3" && HOME="$TMP" bash "$HOOKS/precommit-gate.sh") || true)
check "precommit refund logic in generically named file → deny (content risk)" deny "$out"

(
  cd "$TMP3"
  git reset -q
  printf 'def test_close():\n    assert refund_amount(1) == 0\n' > tests/test_closure.py
  git add tests/test_closure.py
)
out=$(printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":"git commit -m x"}}' \
  "$(printf '%s' "$TRANSCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
  | (cd "$TMP3" && HOME="$TMP" bash "$HOOKS/precommit-gate.sh") || true)
check "precommit same term inside a test file → allow (test paths excluded)" allow "$out"
rm -rf "$TMP3"

# ─── result ───
if [ "$fail" -eq 0 ]; then
  echo "  ✓ pass"
  exit 0
else
  echo "  ✗ fail ($fail behavioral assertions failed)"
  exit 1
fi
