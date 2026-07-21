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

# ── precommit: evidence auto-pass — no marker, no env prefix needed ─────
# HOME is pointed at $TMP so the auto-pass log lands in the sandbox.
TRANSCRIPT="$TMP/transcript.jsonl"
pce() { # $1 = command; hook input carries transcript_path
  printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":%s}}' \
    "$(printf '%s' "$TRANSCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$TMP" && HOME="$TMP" bash "$HOOKS/precommit-gate.sh") || true
}

printf '%s\n' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:qa-tester","prompt":"review"}}' \
  > "$TRANSCRIPT"
out=$(pce 'git commit -m "add billing"')
check "precommit high-risk + reviewer-dispatch evidence → auto-pass" allow "$out"
echo "$out" | grep -q 'auto-passed' \
  && echo "  ✓ auto-pass surfaces an additionalContext note" \
  || { echo "  ✗ auto-pass note missing from hook output"; fail=$((fail+1)); }

printf '%s\n' \
  '{"type":"tool_use","name":"Edit","input":{"file_path":"tests/test_billing.py"}}' \
  > "$TRANSCRIPT"
out=$(pce 'git commit -m "add billing"')
check "precommit high-risk + test-edit evidence alone → auto-pass (OR, not AND)" allow "$out"

# ─── result ───
if [ "$fail" -eq 0 ]; then
  echo "  ✓ pass"
  exit 0
else
  echo "  ✗ fail ($fail behavioral assertions failed)"
  exit 1
fi
