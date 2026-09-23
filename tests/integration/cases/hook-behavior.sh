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

# The real repo's edit ledger must not grow while this file runs: fixture paths
# (src/auth/login.py ...) once landed there and read as high-risk edits at the
# next commit gate (2026-09-19: a release commit was denied on 6 leaked rows).
REAL_LEDGER="$REPO_DIR/.rolepod/evidence/edits.jsonl"
ledger_rows() { [ -f "$REAL_LEDGER" ] && wc -l < "$REAL_LEDGER" | tr -d ' ' || echo 0; }
LEDGER_ROWS_BEFORE=$(ledger_rows)
# A hook called below without its own (cd ...) inherits this cwd: a fixture git
# repo, so its ledger rows land there and the write-scope rule still evaluates.
# NOT mktemp -d: subagent-write-scope.sh allows every write under the OS temp
# roots, which would turn the write-shaped allow cases vacuous.
SANDBOX_CWD="$(dirname "$REPO_DIR")/rp-hb-sandbox.$$"
rm -rf "$SANDBOX_CWD"; mkdir -p "$SANDBOX_CWD"
trap 'rm -rf "$SANDBOX_CWD"' EXIT
( cd "$SANDBOX_CWD" && git init -q . && git config user.email t@t && git config user.name t \
  && git commit -q --allow-empty -m base )
cd "$SANDBOX_CWD"

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

TOTAL_SECTIONS=0
RAN_SECTIONS=0
section() { # $1 = banner title; prints the banner itself (one copy of the
  # title, never a separate `echo` call site the arg can drift from) and
  # gates the block on ROLEPOD_CASE (regex substring match against the title)
  echo "── $1 ──"
  TOTAL_SECTIONS=$((TOTAL_SECTIONS+1))
  if [ -n "${ROLEPOD_CASE:-}" ] && ! [[ "$1" =~ $ROLEPOD_CASE ]]; then
    return 1
  fi
  RAN_SECTIONS=$((RAN_SECTIONS+1))
  return 0
}

payload_subagent() { # $1 = command
  printf '{"agent_id":"a1","agent_type":"backend-developer","tool_name":"Bash","tool_input":{"command":%s}}' \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
}

# ── block-subagent-commit: deny destructive git, allow the rest ────────
if section "block-subagent-commit: deny destructive git, allow the rest"; then
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

out=$(payload_subagent 'timeout 300 git commit -m x' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent wrapped commit (timeout N git commit) → deny" deny "$out"
out=$(payload_subagent 'find . -name "*.md" | xargs git commit -m x' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent xargs git commit → deny" deny "$out"
out=$(payload_subagent 'echo please git commit later' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent echo mentioning git commit → allow (pure-output head)" allow "$out"
out=$(payload_subagent 'cat > note.md <<EOF
run make test-static && git commit -m x
EOF
ls' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent heredoc body with a chained commit example → allow (body dropped)" allow "$out"
out=$(payload_subagent "bash <<'EOF'
git commit -m x
EOF" | bash "$HOOKS/block-subagent-commit.sh")
check "subagent heredoc feeding bash with a commit in the body → deny (a shell owns it)" deny "$out"
out=$(payload_subagent 'sh <<EOF
cd x
git push origin main
EOF' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent heredoc feeding sh with a push in the body → deny" deny "$out"
out=$(payload_subagent 'bash <<EOF
make test-static
EOF' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent heredoc feeding bash with a gate, no timeout → deny" deny "$out"
out=$(payload_subagent 'cat <<EOF | bash
git commit -m x
EOF' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent heredoc piped into bash with a commit → deny" deny "$out"
out=$(payload_subagent 'cat <<EOF | xargs -0 bash -c
git commit -m x
EOF' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent heredoc piped through xargs into bash → deny (any shell on the line owns it)" deny "$out"
SL_TMP=$(mktemp -d); mkdir -p "$SL_TMP/repo" && git -C "$SL_TMP/repo" init -q && mkdir -p "$SL_TMP/.rolepod/session-locks/deadbeefdeadbeef" "$SL_TMP/.rolepod/session-locks/cafebabecafebabe"
OLD=$(python3 -I -c 'import time; print(time.strftime("%Y%m%d%H%M", time.localtime(time.time() - 3600)))')   # one hour ago, derived, never a literal date
touch -t "$OLD" "$SL_TMP/.rolepod/session-locks/deadbeefdeadbeef/auto-1.lock" "$SL_TMP/.rolepod/session-locks/deadbeefdeadbeef/auto-1.files"
touch "$SL_TMP/.rolepod/session-locks/cafebabecafebabe/fresh.lock"; touch -t "$OLD" "$SL_TMP/.rolepod/session-locks/cafebabecafebabe/fresh.files"
printf '{"session_id":"sl1","cwd":"%s"}' "$SL_TMP/repo" | (cd "$SL_TMP/repo" && HOME="$SL_TMP" bash "$HOOKS/session-lifecycle.sh") >/dev/null 2>&1 || true
# an orphan registry the sweep cannot delete must not end SessionStart before its own lock is written
mkdir -p "$SL_TMP/.rolepod/session-locks/0000000000000000" && touch "$SL_TMP/.rolepod/session-locks/0000000000000000/orphan.files" && chmod 555 "$SL_TMP/.rolepod/session-locks/0000000000000000"
SL_RC=0; printf '{"session_id":"sl2","cwd":"%s"}' "$SL_TMP/repo" | (cd "$SL_TMP/repo" && HOME="$SL_TMP" bash "$HOOKS/session-lifecycle.sh") >/dev/null 2>&1 || SL_RC=$?
_h=$(printf '%s' "$(cd "$SL_TMP/repo" && git rev-parse --show-toplevel)" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
[ "$SL_RC" -eq 0 ] && [ -f "$SL_TMP/.rolepod/session-locks/$_h/sl2.lock" ] \
  && echo "  ✓ session-lifecycle survives an undeletable orphan registry and still writes its own lock" \
  || { echo "  ✗ session-lifecycle fail-closed on an undeletable orphan (rc=$SL_RC, lock=$(ls "$SL_TMP/.rolepod/session-locks/$_h" 2>/dev/null | tr '\n' ' '))"; fail=$((fail+1)); }
chmod 755 "$SL_TMP/.rolepod/session-locks/0000000000000000"
[ ! -d "$SL_TMP/.rolepod/session-locks/deadbeefdeadbeef" ] && [ -f "$SL_TMP/.rolepod/session-locks/cafebabecafebabe/fresh.lock" ] && [ -f "$SL_TMP/.rolepod/session-locks/cafebabecafebabe/fresh.files" ] \
  && echo "  ✓ session-lifecycle sweeps a stale lock dir (lock + registry) and keeps a fresh lock with its old registry" \
  || { echo "  ✗ session-lifecycle sweep: stale=$(ls "$SL_TMP/.rolepod/session-locks/deadbeefdeadbeef" 2>&1 | head -1) fresh=$(ls "$SL_TMP/.rolepod/session-locks/cafebabecafebabe" 2>&1 | head -1)"; fail=$((fail+1)); }
rm -rf "$SL_TMP"

# Lead (no agent_id) is never blocked
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | bash "$HOOKS/block-subagent-commit.sh")
check "Lead git commit → allow (hook targets subagents only)" allow "$out"

fi
# ── block-subagent-commit: a sub-agent cannot wait on a backgrounded call ──
if section "block-subagent-commit: a sub-agent cannot wait on a backgrounded call"; then
bsc_ti() { printf '{"agent_id":"a1","agent_type":"devops-sre","tool_name":"%s","tool_input":%s}' "$1" "$2" | bash "$HOOKS/block-subagent-commit.sh"; }
out=$(bsc_ti Bash '{"command":"make test-static","run_in_background":true}')
check "subagent Bash run_in_background → deny (no completion notice reaches a sub-agent)" deny "$out"
out=$(bsc_ti Bash '{"command":"make test-static"}')
check "subagent make test-* with no timeout → deny (120 s default backgrounds it)" deny "$out"
out=$(bsc_ti Bash '{"command":"make test-static","timeout":600000}')
check "subagent make test-* with an explicit timeout → allow" allow "$out"
out=$(bsc_ti Bash '{"command":"make test-static","timeout":120000}')
check "subagent explicit short timeout → allow (a stated choice)" allow "$out"
out=$(bsc_ti Bash '{"command":"cd /tmp/wt && bash tests/integration/cases/cross-family-runner.sh && make test-static"}')
check "subagent compound integration case + gate, no timeout → deny" deny "$out"
out=$(bsc_ti Bash '{"command":"rolepod-cross-family --collect j1"}')
check "subagent cross-family --collect with no timeout → deny" deny "$out"
out=$(bsc_ti Bash '{"command":"rolepod-cross-family --kind review --brief b.md --detach"}')
check "subagent cross-family --detach → allow (returns at once)" allow "$out"
out=$(bsc_ti Bash '{"command":"grep -rn \"make test\" docs/ && bash tests/unit/fast.sh"}')
check "subagent command merely mentioning a gate → allow" allow "$out"
out=$(bsc_ti Bash '{"command":"npm test -- --watch=false"}')
check "subagent plain project test runner without timeout → allow (only make test-* / integration / cross-family are gates)" allow "$out"
out=$(bsc_ti Bash '{"command":"bash -c \"make test-static\""}')
check "subagent bash -c wrapping a gate → deny (recursed)" deny "$out"
out=$(bsc_ti Bash '{"command":"sh -c \"rolepod-cross-family --collect j1\""}')
check "subagent sh -c wrapping cross-family --collect → deny" deny "$out"
out=$(bsc_ti Bash '{"command":"make -j4 test-static"}')
check "subagent make with a flag before the test target → deny" deny "$out"
out=$(bsc_ti Bash '{"command":"command rolepod-cross-family --collect j1"}')
check "subagent command/exec/nohup prefix → deny" deny "$out"
out=$(bsc_ti Bash '{"command":"bash scripts/quick.sh"}')
check "subagent bash <script> that is not a gate → allow" allow "$out"
out=$(bsc_ti Bash '{"command":"make -C dir test-static"}')
check "subagent make -C dir <target> → deny (value token before the target)" deny "$out"
out=$(bsc_ti Bash '{"command":"env -i nice -n 10 make test-static"}')
check "subagent wrapper flags + numeric value before make → deny" deny "$out"
out=$(bsc_ti Bash '{"command":"echo make test-static > note.txt"}')
check "subagent echo of a gate name → allow (head is echo)" allow "$out"
for m in --rounds --pool --pool-names --candidates --probe --setup --jobs --kill; do
  out=$(bsc_ti Bash "{\"command\":\"rolepod-cross-family $m\"}")
  check "subagent cross-family $m (instant read) → allow" allow "$out"
done
out=$(bsc_ti Bash '{"command":"rolepod-cross-family --kind review --brief b.md"}')
check "subagent cross-family --kind without --detach, no timeout → deny" deny "$out"
out=$(bsc_ti Bash '{"command":"make test-static","timeout":0}')
check "subagent timeout: 0 counts as absent → deny" deny "$out"
out=$(bsc_ti Bash '{"command":"make test-static && git commit -m x"}')
check "subagent gate chained with a commit → the commit deny wins" deny "$out"
echo "$out" | grep -q "never commit" && echo "  ✓ …and the reason is the version-control one" || { echo "  ✗ gate+commit reason is not the commit one"; fail=$((fail+1)); }
out=$(payload_subagent 'cat > note.md <<EOF
the git commit step is the Lead
EOF' | bash "$HOOKS/block-subagent-commit.sh")
check "subagent heredoc mentioning git commit mid-line → allow (head is cat)" allow "$out"
for c in 'sudo -n git commit -m x' 'sudo -k git commit -m x' 'sudo -S git commit -m x' 'sudo -s bash -c "git commit -m x"' 'nice -n 10 git commit -m x' 'timeout -k 5 -s KILL 300 git push'; do
  out=$(payload_subagent "$c" | bash "$HOOKS/block-subagent-commit.sh")
  check "subagent wrapper boolean/value flags before a commit: $c → deny" deny "$out"
done
out=$(bsc_ti Bash '{"command":"sudo -n make test-static"}')
check "subagent sudo -n (boolean) make test → deny (no token swallowed)" deny "$out"
out=$(bsc_ti Bash '{"command":"timeout -k 5 300 make test-static"}')
check "subagent timeout -k <dur> <dur> make test → deny" deny "$out"
out=$(bsc_ti Bash '{"command":"sudo -u deploy make test-static"}')
check "subagent sudo -u <user> make test → deny (value-taking wrapper flag skipped)" deny "$out"
out=$(bsc_ti Bash '{"command":"timeout 5m make test-integration"}')
check "subagent timeout 5m make test → deny (duration skipped)" deny "$out"
out=$(bsc_ti shell '{"command":"make test-static"}')
check "Codex tool name (no timeout field exists) → allow" allow "$out"
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"make test-static","run_in_background":true}}' | bash "$HOOKS/block-subagent-commit.sh")
check "Lead run_in_background → allow (the Lead is notified)" allow "$out"
grep -q 'timeout: 600000' <<<"$(bsc_ti Bash '{"command":"make test-static"}')" \
  && echo "  ✓ deny reason names the fix (timeout: 600000)" \
  || { echo "  ✗ deny reason lacks the timeout fix"; fail=$((fail+1)); }

fi
# ── block-subagent-commit: write rule — a Bash write is an edit (bash-writes-are-edits Task 2) ──
if section "block-subagent-commit: write rule — a Bash write is an edit (bash-writes-are-edits Task 2)"; then
# NOT mktemp -d: subagent-write-scope.sh treats /tmp, /private/tmp and (on
# macOS) /var/folders/... as OS scratch and always allows a write there — a
# fixture repo living under the system temp root would silently pass every
# deny case below. A sibling of REPO_DIR sits outside all of those.
BW_TMP="$(dirname "$REPO_DIR")/rp-bw-selftest.$$"
rm -rf "$BW_TMP"; mkdir -p "$BW_TMP"
( cd "$BW_TMP" && git init -q . && git config user.email t@t && git config user.name t \
  && mkdir -p src tests && git commit -q --allow-empty -m base )
BW_LEDGER="$BW_TMP/.rolepod/evidence/edits.jsonl"
bw_sub() { # $1 = agent_type, $2 = command
  printf '{"agent_id":"a1","agent_type":"%s","cwd":"%s","tool_name":"Bash","tool_input":{"command":%s}}' \
    "$1" "$BW_TMP" "$(printf '%s' "$2" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$BW_TMP" && bash "$HOOKS/block-subagent-commit.sh")
}
bw_lead() { # $1 = command
  printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":%s}}' \
    "$BW_TMP" "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$BW_TMP" && bash "$HOOKS/block-subagent-commit.sh")
}

rm -f "$BW_LEDGER"
out=$(bw_sub 'rolepod:universal-reviewer' 'cat > src/x.ts <<EOF
x
EOF')
check "read-only sub-agent Bash heredoc write to src/x.ts → deny" deny "$out"
echo "$out" | grep -q 'shell write:' \
  && echo "  ✓ deny reason carries the shell write: prefix" \
  || { echo "  ✗ deny reason missing the shell write: prefix"; fail=$((fail+1)); }
[ -f "$BW_LEDGER" ] \
  && { echo "  ✗ a denied shell write still added a ledger row"; fail=$((fail+1)); } \
  || echo "  ✓ a denied shell write adds no ledger row"

rm -f "$BW_LEDGER"
out=$(bw_sub 'rolepod:qa-tester' 'cat > tests/x.test.ts <<EOF
x
EOF')
check "test-only sub-agent Bash heredoc write to tests/x.test.ts → allow" allow "$out"

rm -f "$BW_LEDGER"
out=$(bw_sub 'general-purpose' 'sed -i "s/a/b/" src/y.py')
check "generic sub-agent Bash sed -i on src/y.py → deny" deny "$out"
echo "$out" | grep -q 'shell write:' \
  && echo "  ✓ generic sub-agent sed -i deny reason carries the shell write: prefix" \
  || { echo "  ✗ generic sub-agent sed -i deny reason missing the shell write: prefix"; fail=$((fail+1)); }

rm -f "$BW_LEDGER"
out=$(bw_lead 'printf x > src/z.py')
check "Lead Bash write to src/z.py → allow" allow "$out"
[ -f "$BW_LEDGER" ] && grep -q '"path": *"src/z.py"' "$BW_LEDGER" \
  && echo "  ✓ Lead Bash write lands a ledger row for src/z.py" \
  || { echo "  ✗ Lead Bash write did not add a ledger row for src/z.py"; fail=$((fail+1)); }

rm -f "$BW_LEDGER"
out=$(bw_sub 'backend-developer' 'printf x > src/z.py && git commit -m x')
check "sub-agent Bash write chained with git commit → the commit deny wins" deny "$out"
echo "$out" | grep -q "never commit" \
  && echo "  ✓ …and the reason is the version-control one, not the write one" \
  || { echo "  ✗ write+commit reason is not the commit one"; fail=$((fail+1)); }
[ -f "$BW_LEDGER" ] \
  && { echo "  ✗ a command whose commit was denied still added a ledger row"; fail=$((fail+1)); } \
  || echo "  ✓ a denied write+commit command adds no ledger row"

rm -f "$BW_LEDGER"
out=$(bw_lead 'ls -la')
check "Lead Bash non-write (ls -la) → allow" allow "$out"
[ ! -f "$BW_LEDGER" ] \
  && echo "  ✓ Lead non-write Bash call adds no ledger row" \
  || { echo "  ✗ Lead non-write Bash call unexpectedly added a ledger row"; fail=$((fail+1)); }

# fast path (v2.150.1): a Lead command with no write-shaped token never spawns python;
# a redirect, a bare write verb, or any sub-agent call still takes the full pass.
REAL_PY=$(command -v python3); mkdir -p "$BW_TMP/shim"
printf '#!/bin/bash\n: > "%s/python-ran"\nexec "%s" "$@"\n' "$BW_TMP" "$REAL_PY" > "$BW_TMP/shim/python3"; chmod +x "$BW_TMP/shim/python3"
rm -f "$BW_TMP/python-ran"
printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"git add . && make test"}}' "$BW_TMP" \
  | PATH="$BW_TMP/shim:$PATH" bash "$HOOKS/block-subagent-commit.sh" >/dev/null 2>&1 || true   # hand-built JSON: bw_lead itself calls python3
[ ! -f "$BW_TMP/python-ran" ] \
  && echo "  ✓ fast path: Lead 'git add . && make test' never spawns python" \
  || { echo "  ✗ fast path: python spawned on a no-write Lead command"; fail=$((fail+1)); }
rm -f "$BW_TMP/python-ran"
printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"printf x > src/z.py"}}' "$BW_TMP" \
  | PATH="$BW_TMP/shim:$PATH" bash "$HOOKS/block-subagent-commit.sh" >/dev/null 2>&1 || true
[ -f "$BW_TMP/python-ran" ] \
  && echo "  ✓ fast path: a redirect still takes the full pass" \
  || { echo "  ✗ fast path skipped a redirect"; fail=$((fail+1)); }
rm -f "$BW_TMP/python-ran"
printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"npm rm lodash"}}' "$BW_TMP" \
  | PATH="$BW_TMP/shim:$PATH" bash "$HOOKS/block-subagent-commit.sh" >/dev/null 2>&1 || true
[ -f "$BW_TMP/python-ran" ] \
  && echo "  ✓ fast path: a bare write verb (rm) still takes the full pass" \
  || { echo "  ✗ fast path skipped a bare write verb"; fail=$((fail+1)); }
rm -f "$BW_TMP/python-ran"
printf '{"agent_id":"a1","agent_type":"backend-developer","cwd":"%s","tool_name":"Bash","tool_input":{"command":"git log --oneline"}}' "$BW_TMP" \
  | PATH="$BW_TMP/shim:$PATH" bash "$HOOKS/block-subagent-commit.sh" >/dev/null 2>&1 || true
[ -f "$BW_TMP/python-ran" ] \
  && echo "  ✓ fast path: a sub-agent call always takes the full pass" \
  || { echo "  ✗ fast path skipped a sub-agent call"; fail=$((fail+1)); }
rm -f "$BW_TMP/python-ran"

# Cost (R4): the Lead's no-write allow path and a sub-agent's allow path stay
# cheap — informational timing (machine-dependent; never fails the suite).
# The hook itself is timed directly here (plain printf, no python json.dumps
# escaping step in the measured region — bw_lead/bw_sub above build that
# payload through an extra python interpreter start, which would double-count
# against the hook's own cost). Two commands with no shell metacharacters, so
# a hand-built JSON literal is safe.
LEAD_IN=$(printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"ls -la"}}' "$BW_TMP")
SUB_IN=$(printf '{"agent_id":"a1","agent_type":"backend-developer","cwd":"%s","tool_name":"Bash","tool_input":{"command":"git log --oneline"}}' "$BW_TMP")
T0=$(python3 -I -c 'import time; print(time.time())')
printf '%s' "$LEAD_IN" | bash "$HOOKS/block-subagent-commit.sh" >/dev/null
T1=$(python3 -I -c 'import time; print(time.time())')
LEAD_MS=$(python3 -I -c "print(int(($T1-$T0)*1000))")
echo "  · Lead no-write Bash allow path: ${LEAD_MS} ms (task budget ≤ 40 ms, informational)"
T0=$(python3 -I -c 'import time; print(time.time())')
printf '%s' "$SUB_IN" | bash "$HOOKS/block-subagent-commit.sh" >/dev/null
T1=$(python3 -I -c 'import time; print(time.time())')
SUB_MS=$(python3 -I -c "print(int(($T1-$T0)*1000))")
echo "  · sub-agent Bash allow path: ${SUB_MS} ms (task budget ≤ 60 ms, informational)"

rm -rf "$BW_TMP"

fi
# ── gate-reminder: Claude AND Codex tool names must both fire ──────────
if section "gate-reminder: Claude AND Codex tool names must both fire"; then
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

# v2.47.0: gate-reminder never denies — edit-time HARD blocks were the
# measured reason a user set ROLEPOD_GATES_SOFT for good (which silenced the
# commit gate too). It NAMES what the commit gate will require instead.
out=$(gr '{"tool_name":"Edit","tool_input":{"file_path":"src/auth/login.py"}}')
echo "$out" | grep -q '"deny"' \
  && { echo "  ✗ gate-reminder still denies an edit (v2.47.0: warn-only, one hard checkpoint at commit)"; fail=$((fail+1)); } \
  || echo "  ✓ gate-reminder high-risk edit with 0 evidence → NOT a deny"
echo "$out" | grep -q 'COMMIT WILL BLOCK' \
  && echo "  ✓ gate-reminder names the coming commit-gate requirement" \
  || { echo "  ✗ gate-reminder missing would-block wording"; fail=$((fail+1)); }
out=$(ROLEPOD_GATES_SOFT=1 ROLEPOD_BYPASS_REASON=rolepod-selftest gr '{"tool_name":"Edit","tool_input":{"file_path":"src/auth/login.py"}}')
echo "$out" | grep -q 'COMMIT WILL BLOCK' \
  && { echo "  ✗ gate-reminder SOFT should silence the would-block wording"; fail=$((fail+1)); } \
  || echo "  ✓ gate-reminder SOFT silences the would-block wording (banner stays)"

fi
# ── precommit-gate: high-risk staged diff blocks; claim-bypass ignored ──
TMP=$(mktemp -d)
# Unconditional: pct() ("a test-ONLY diff...") and pcd() ("the pool reviews
# CODE only") both reuse this same scratch dir path and manage its contents
# themselves (rm -rf + mkdir -p per call) — filtering ROLEPOD_CASE to pcd()'s
# section alone used to leave $TMPT empty, turning "$TMPT/.rolepod" into the
# absolute path "/.rolepod" (read-only fs, hard mkdir failure).
TMPT=$(mktemp -d)
trap 'rm -rf "$TMP" "$SANDBOX_CWD" ${TMPT:+"$TMPT"}' EXIT
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
if section "precommit-gate: high-risk staged diff blocks; claim-bypass ignored"; then

out=$(pc 'git commit -m "add billing"')
check "precommit high-risk staged diff → deny" deny "$out"

out=$(pc 'git -C . commit -m "add billing"')
check "precommit git -C . commit (flag-separated) → deny" deny "$out"

out=$(pc 'git commit -m "add billing [gates: pass]"')
check "precommit [gates: pass] with ZERO session evidence → still deny" deny "$out"
echo "$out" | grep -q 'IGNORED' \
  && echo "  ✓ precommit deny reason states the marker was ignored" \
  || { echo "  ✗ precommit deny reason missing marker-ignored note"; fail=$((fail+1)); }
fi

# ── precommit-gate: add+commit / commit -a one-liners are gated on the working tree (v2.134.1) ──
if section "precommit-gate: add+commit / commit -a one-liners are gated on the working tree (v2.134.1)"; then
# At hook time nothing is staged yet; the old index-only read let every CLI's Lead
# ship `git add -A && git commit` past the gate (measured live 2026-09-16).
TMP2=$(mktemp -d)   # own repo: the shared $TMP fixture must keep its staged diff for the cases below
( cd "$TMP2" && git init -q . && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m base
  mkdir -p src/auth && printf 'def check(u):\n    return u.role == "admin"\n' > src/auth/login.py )
pc2() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$TMP2" && bash "$HOOKS/precommit-gate.sh") || true; }
out=$(pc2 'git add -A && git commit -m "add login"')
check "precommit 'git add -A && git commit' with an unstaged high-risk file → deny" deny "$out"
out=$(pc2 'git commit -am "add login"')
check "precommit 'git commit -am' → deny" deny "$out"
out=$(pc2 'git -C . add src && git commit -m "add login"')
check "precommit 'git -C . add src && git commit' (value option before add) → deny" deny "$out"
out=$(pc2 'git commit -m "fix: add thing"')
check "precommit plain commit with nothing staged (message says add) → silent" allow "$out"
rm -rf "$TMP2"

fi
# ── precommit-gate: a test-ONLY diff on a risk-named path is not R4 code (v2.85.2) ──
if section "precommit-gate: a test-ONLY diff on a risk-named path is not R4 code (v2.85.2)"; then
# Filename convention only — bare directory segments would downgrade
# api/specs/auth.yaml and tests/fixtures/seed_auth_users.py (cases c, d).
# ($TMPT itself is the unconditional fixture above; pct() only manages its contents.)
pct() { # $1 = space-separated files to stage (15 logic lines each), fresh repo per call
  rm -rf "$TMPT"; mkdir -p "$TMPT"
  ( cd "$TMPT" && git init -q . && git config user.email t@t && git config user.name t
    for f in $1; do mkdir -p "$(dirname "$f")"; seq 15 | sed 's/^/x = /' > "$f"; done
    git add -A )
  printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' \
    | (cd "$TMPT" && bash "$HOOKS/precommit-gate.sh") || true
}
check "precommit test-only tests/auth/login.spec.ts → allow (SOFT)" allow "$(pct tests/auth/login.spec.ts)"
check "precommit test-only spec/models/payment_spec.rb → allow (SOFT)" allow "$(pct spec/models/payment_spec.rb)"
check "precommit api/specs/auth.yaml (specs segment, not a test name) → deny" deny "$(pct api/specs/auth.yaml)"
check "precommit tests/fixtures/seed_auth_users.py (fixture, not a test name) → deny" deny "$(pct tests/fixtures/seed_auth_users.py)"
check "precommit spec/services/payment_processor.rb (spec dir, not a test name) → deny" deny "$(pct spec/services/payment_processor.rb)"
# Path with a space: numstat does not quote spaces, so a whitespace-split awk
# read `src/my` and the risk regex never saw the `auth` segment (fail-open before v2.85.3).
rm -rf "$TMPT"; mkdir -p "$TMPT/src/my app/auth"
( cd "$TMPT" && git init -q . && git config user.email t@t && git config user.name t \
  && seq 15 | sed 's/^/x = /' > "src/my app/auth/login.ts" && git add -A )
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | (cd "$TMPT" && bash "$HOOKS/precommit-gate.sh") || true)
check "precommit 'src/my app/auth/login.ts' (space in path, auth segment) → deny" deny "$out"
check "precommit mixed test + src/auth/login.ts → deny" deny "$(pct 'tests/auth/login.spec.ts src/auth/login.ts')"

fi
# ── precommit-gate: emoji advisory removed v2.164.0 — emoji in product code no longer speaks ──
if section "precommit-gate: emoji advisory removed v2.164.0 — emoji in product code no longer speaks"; then
rm -rf "$TMPT"; mkdir -p "$TMPT/src/ui"
( cd "$TMPT" && git init -q . && git config user.email t@t && git config user.name t
  seq 14 | sed 's/^/x = /' > src/ui/button.py
  printf 'label = "\xf0\x9f\x9a\x80 Launch"\n' >> src/ui/button.py
  git add -A )
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | (cd "$TMPT" && bash "$HOOKS/precommit-gate.sh") || true)
check "precommit emoji in product code → allow (no emoji rule left)" allow "$out"
echo "$out" | grep -q 'emoji in product code' \
  && { echo "  ✗ precommit still prints an emoji line (should be removed)"; fail=$((fail+1)); } \
  || echo "  ✓ a commit with an emoji in product code prints no emoji line"

out=$(pc 'git status')
check "precommit non-commit command → allow" allow "$out"

fi
# ── v2.39.0 single-parse regression guards ──────────────────────────────
if section "v2.39.0 single-parse regression guards"; then
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

fi
# ── worktree-guard: reuse-ladder nudge removed v2.164.0, touched-files registry stays ──
if section "worktree-guard: reuse-ladder nudge removed v2.164.0, touched-files registry stays"; then
WG_TMP=$(mktemp -d); ( cd "$WG_TMP" && git init -q . && mkdir -p src && printf '{}\n' > package.json )
wg() { printf '{"session_id":"wg1","cwd":"%s","tool_name":"%s","tool_input":{"file_path":"%s"}}' "$WG_TMP" "$1" "$WG_TMP/$2" | (cd "$WG_TMP" && HOME="$WG_TMP" bash "$HOOKS/worktree-guard.sh") || true; }
out=$(wg Write src/b.ts)
[ -z "$out" ] && echo "  ✓ a new code file prints no reuse-ladder line" || { echo "  ✗ new file still nudges: ${out:0:100}"; fail=$((fail+1)); }
out=$(wg Edit package.json)
[ -z "$out" ] && echo "  ✓ a dependency-manifest edit prints no reuse-ladder line" || { echo "  ✗ manifest edit still nudges: ${out:0:100}"; fail=$((fail+1)); }
rm -rf "$WG_TMP"

fi
# ── precommit: evidence auto-pass — split by risk (v2.46.0) ─────────────
# A HIGH-RISK diff clears ONLY on a strong-class adversarial reviewer
# dispatch (security-engineer / universal-reviewer). Test edits and qa-tester
# are the balanced test floor, not the review — the CourtBook evidence:
# 672 green tests + strong impl still shipped 4 money bugs that only the
# adversarial pass caught. HOME points at $TMP so the log lands in sandbox.
# $TMP/.rolepod itself is unconditional too: "running detached job named in
# the hold" and "money / auth vs other high-risk" both write straight into
# it (printf > "$TMP/.rolepod/cross-family", no mkdir of their own) — a
# ROLEPOD_CASE filter to either alone used to hit "No such file or
# directory" and abort the run under set -e before "satellite-first
# ENFORCED" (the section that used to create this dir) ever ran. Same for
# the "evidence" subdir: both sections' first statement also redirects
# straight into "$TMP/.rolepod/evidence/phase-log.jsonl".
mkdir -p "$TMP/.rolepod/evidence"
TRANSCRIPT="$TMP/transcript.jsonl"
# Unconditional: "satellite-first ENFORCED", "running detached job named in
# the hold" and "the pool reviews CODE only" all reuse this default
# security-engineer dispatch content without writing it themselves — a
# ROLEPOD_CASE filter to one of those alone used to leave $TRANSCRIPT
# missing, which flips an expected allow into a satellite-first deny (no
# reviewer recognized) instead of failing the check for the right reason.
printf '%s\n' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' \
  > "$TRANSCRIPT"
pce() { # $1 = command; hook input carries transcript_path
  printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":%s}}' \
    "$(printf '%s' "$TRANSCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$TMP" && HOME="$TMP" bash "$HOOKS/precommit-gate.sh") || true
}
if section "precommit: evidence auto-pass — split by risk (v2.46.0)"; then

out=$(pce 'git commit -m "add billing"')
check "precommit high-risk + security-engineer dispatch → auto-pass" allow "$out"
echo "$out" | grep -q 'auto-passed' \
  && echo "  ✓ auto-pass surfaces an additionalContext note" \
  || { echo "  ✗ auto-pass note missing from hook output"; fail=$((fail+1)); }
fi

# ── precommit: satellite-first ENFORCED (v2.76.0) ───────────────────────
# With a usable cross-family pool, an internal strong reviewer clears a
# high-risk diff only after the pool was tried: an anchored external pass,
# or an external-fail line since the last commit. Stub `codex` on PATH =
# usable pool; CLAUDE_PLUGIN_ROOT = Lead is claude.
XF_BIN="$TMP/xfbin"; mkdir -p "$XF_BIN"; printf '#!/bin/bash\nexit 1\n' > "$XF_BIN/codex"; chmod +x "$XF_BIN/codex"
pcx() { # $1 = command, $2 = extra env assignments (string) — Lead = claude, stub codex on PATH
  printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":%s}}' \
    "$(printf '%s' "$TRANSCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$TMP" && env HOME="$TMP" PATH="$XF_BIN:/usr/bin:/bin" CLAUDE_PLUGIN_ROOT="$TMP" ${2:-} bash "$HOOKS/precommit-gate.sh") || true
}
if section "precommit: satellite-first ENFORCED (v2.76.0)"; then
printf '%s\n' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' \
  > "$TRANSCRIPT"
rm -f "$TMP/.rolepod/evidence/phase-log.jsonl" "$TMP/.rolepod/cross-family"
out=$(pcx 'git commit -m "add billing"')
check "precommit high-risk + internal strong reviewer, cross-family NOT enabled (opt-in default) → allow (never forced)" allow "$out"
mkdir -p "$TMP/.rolepod"; printf 'codex\n' > "$TMP/.rolepod/cross-family"
out=$(pcx 'git commit -m "add billing"')
check "precommit high-risk + internal strong reviewer + ENABLED usable pool + nothing tried → deny (satellite-first)" deny "$out"
echo "$out" | grep -q 'SATELLITE-FIRST' && echo "$out" | grep -q 'rolepod-cross-family' \
  && echo "  ✓ deny reason names the runner + the usable pool" \
  || { echo "  ✗ satellite-first deny reason missing runner instruction"; fail=$((fail+1)); }
mkdir -p "$TMP/.rolepod/evidence"
printf '{"ts":"%s","phase":"external-fail","kind":"review","cli":"codex","family":"openai","lead":"claude","reason":"exit 1"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TMP/.rolepod/evidence/phase-log.jsonl"
out=$(pcx 'git commit -m "add billing"')
check "…+ external-fail line since last commit (runner tried, pool failed) → internal strong reviewer clears" allow "$out"
: > "$TMP/.rolepod/evidence/phase-log.jsonl"
mkdir -p "$TMP/.rolepod/evidence/external"; head -c 700 /dev/zero | tr '\0' 'x' > "$TMP/.rolepod/evidence/external/t-codex.txt"
printf '{"ts":"%s","phase":"review","reviewer":"external","kind":"review","cli":"codex","family":"openai","model":"default","raw":"external/t-codex.txt","lead":"claude","secs":9}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TMP/.rolepod/evidence/phase-log.jsonl"
: > "$TRANSCRIPT"
out=$(pcx 'git commit -m "add billing"')
check "money/auth fixture + enabled pool + external anchor ONLY, no internal reviewer → allow (external alone clears — v2.145.0)" allow "$out"
echo "$out" | grep -q '1 reviewer dispatches / 1 strong' \
  && echo "  ✓ allow is credited to the external anchor alone (1 strong, 0 internal)" \
  || { echo "  ✗ external-alone allow did not credit exactly 1 strong reviewer"; fail=$((fail+1)); }
printf '%s\n' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' \
  > "$TRANSCRIPT"
out=$(pcx 'git commit -m "add billing"')
check "money/auth fixture + external anchor + internal strong reviewer → allow (both present)" allow "$out"
: > "$TMP/.rolepod/evidence/phase-log.jsonl"
printf '%s\n' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' \
  > "$TRANSCRIPT"
out=$(pcx 'git commit -m "add billing"')
check "money/auth fixture + enabled pool + internal strong ONLY, nothing tried → deny (satellite-first unchanged)" deny "$out"
: > "$TRANSCRIPT"
: > "$TMP/.rolepod/evidence/phase-log.jsonl"
printf '%s\n' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' \
  > "$TRANSCRIPT"
printf 'none\n' > "$TMP/.rolepod/cross-family"
out=$(pcx 'git commit -m "add billing"')
check "pool disabled (.rolepod/cross-family = none) + internal strong reviewer → allow (no tightening without a pool)" allow "$out"
printf 'codex\n' > "$TMP/.rolepod/cross-family"
out=$(printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":"git commit -m x"}}' \
    "$(printf '%s' "$TRANSCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$TMP" && env -u CLAUDE_PLUGIN_ROOT -u ROLEPOD_LEAD_CLI HOME="$TMP" PATH="$XF_BIN:/usr/bin:/bin" bash "$HOOKS/precommit-gate.sh") || true)
check "Lead CLI unknown (no ROLEPOD_LEAD_CLI / CLAUDE_PLUGIN_ROOT) → cannot exclude a family → old behavior, allow" allow "$out"
fi

# ── running detached job named in the hold (v2.79.0) ────────────────────
if section "running detached job named in the hold (v2.79.0)"; then
printf 'codex\n' > "$TMP/.rolepod/cross-family"
: > "$TMP/.rolepod/evidence/phase-log.jsonl"
printf '%s\n' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' \
  > "$TRANSCRIPT"
JOBD="$TMP/.rolepod/evidence/external/jobs/t-review-1"; mkdir -p "$JOBD"
bash -c 'sleep 20; :' cross-family-fake-job & JPID=$!; echo "$JPID" > "$JOBD/pid"; date +%s > "$JOBD/started"   # argv carries cross-family so the pid-reuse check accepts it
out=$(pcx 'git commit -m "add billing"')
check "high-risk + internal strong + pool usable + a detached review job RUNNING → deny names the job (wait / --collect), not 'run the runner'" deny "$out"
echo "$out" | grep -q 'ALREADY RUNNING: t-review-1' && ! echo "$out" | grep -q -- '--detach (or scripts' \
  && echo "  ✓ hold reason points at the running job" \
  || { echo "  ✗ hold reason did not name the running job"; fail=$((fail+1)); }
kill "$JPID" 2>/dev/null; wait "$JPID" 2>/dev/null || true; rm -rf "$JOBD"
rm -f "$TMP/.rolepod/cross-family"

fi
# ── the pool reviews CODE only; docs are written, not reviewed (v2.143.0) ──
# Fresh repo per call, enabled pool (stub codex), Lead = claude. $1 = "path=kind …"
# (kind: logic | comment | prose, 15 lines each); $2 = transcript path.
EMPTY_T="$TMP/empty-transcript.jsonl"; : > "$EMPTY_T"
pcd() {
  rm -rf "$TMPT"; mkdir -p "$TMPT/.rolepod"
  ( cd "$TMPT" && git init -q . && git config user.email t@t && git config user.name t
    if [ -n "${PCD_GENATTR:-}" ]; then mkdir -p .git/info; printf '%s linguist-generated\n' "$PCD_GENATTR" > .git/info/attributes; fi   # outside the diff
    for spec in $1; do f="${spec%%=*}"; kind="${spec##*=}"; mkdir -p "$(dirname "$f")"
      case "$kind" in logic) seq 15 | sed 's/^/x = /' > "$f" ;; comment) seq 15 | sed 's/^/# note /' > "$f" ;; prose) seq 15 | sed 's/^/Line /' > "$f" ;; version) seq 15 | sed 's/.*/"version": "1.2.3",/' > "$f" ;; esac
    done
    git add -A; printf 'codex\n' > .rolepod/cross-family )   # pool file written AFTER staging — never part of the diff
  printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":"git commit -m x"}}' \
    "$(printf '%s' "$2" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$TMPT" && env HOME="$TMPT" PATH="$XF_BIN:/usr/bin:/bin" CLAUDE_PLUGIN_ROOT="$TMPT" bash "$HOOKS/precommit-gate.sh") || true
}
if section "the pool reviews CODE only; docs are written, not reviewed (v2.143.0)"; then
out=$(pcd docs/auth.md=prose "$EMPTY_T")
check "docs-only diff on a risk-named prose path, NO reviewer, pool enabled → allow (docs are written, not reviewed)" allow "$out"
[ -z "$out" ] && echo "  ✓ docs-only diff passes silently (no nudge)" || { echo "  ✗ docs-only diff produced hook output: ${out:0:120}"; fail=$((fail+1)); }
out=$(pcd auth/billing.py=comment "$TRANSCRIPT")
check "comment-only diff on a risky path + internal strong reviewer + pool usable → allow (the pool reviews code only)" allow "$out"
out=$(pcd auth/billing.py=logic "$TRANSCRIPT")
check "logic diff on a risky path + internal strong reviewer + pool usable, nothing tried → deny (control: satellite-first still holds for code)" deny "$out"
out=$(pcd billing/plan.json=version "$TRANSCRIPT")
check "version-field lines on a risky path + internal strong reviewer + pool usable → deny (the HARD count keeps them; only the SOFT ask drops them)" deny "$out"
out=$(PCD_GENATTR='billing/**' pcd billing/gen.py=logic "$TRANSCRIPT")
check "linguist-generated logic on a risky path + internal strong reviewer + pool usable → deny (generated files leave the SOFT ask only)" deny "$out"
out=$(pcd 'README=prose docs/guide.md=prose' "$EMPTY_T")
check "extension-less README + docs → allow silently (prose)" allow "$out"
fi

# ── qa-tester is never the per-diff review floor (v2.148.4) ──
if section "qa-tester is never the per-diff review floor (v2.148.4)"; then
T_QA="$TMP/t_qa.jsonl"; printf '%s\n' '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:qa-tester","prompt":"run the E2E flow"}}' > "$T_QA"
T_UR="$TMP/t_ur.jsonl"; printf '%s\n' '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:universal-reviewer","prompt":"review the diff"}}' > "$T_UR"
export ROLEPOD_GATES_HARD=1
out=$(pcd 'src/util.py=logic' "$T_QA")
check "HARD gate: logic diff, no tests, qa-tester ALONE → deny (E2E is not the review floor)" deny "$out"
out=$(pcd 'src/util.py=logic' "$T_UR")
check "HARD gate: logic diff, no tests, universal-reviewer → allow (the per-diff floor)" allow "$out"
unset ROLEPOD_GATES_HARD
out=$(pcd 'src/util.py=logic' "$T_QA")
echo "$out" | grep -q 'reviewers since last commit: 0' \
  && echo "  ✓ SOFT line counts a qa-tester dispatch as 0 reviewers" \
  || { echo "  ✗ SOFT line counted qa-tester as a reviewer: ${out:0:160}"; fail=$((fail+1)); }
out=$(pcd 'adapters/codex/AGENTS.md.tmpl=prose' "$EMPTY_T")
check "prose template (.md.tmpl) only → allow silently (prose)" allow "$out"
[ -z "$out" ] && echo "  ✓ .md.tmpl diff passes silently" || { echo "  ✗ .md.tmpl diff produced hook output: ${out:0:120}"; fail=$((fail+1)); }
out=$(pcd 'docs/rolepod/plan.md=prose docs/auth.md=prose' "$EMPTY_T")
check "docs-only diff that also stages docs/rolepod/ → deny (private-docs gate runs before the prose exit)" deny "$out"
out=$(pcd 'docs/auth.md=prose src/util.py=logic' "$EMPTY_T")
echo "$out" | grep -q 'HIGH-RISK path' \
  && { echo "  ✗ a prose file made a mixed diff high-risk (docs/auth.md is never a risk path)"; fail=$((fail+1)); } \
  || echo "  ✓ prose file in a mixed diff is not a risk path"
rm -rf "$TMPT"

fi
# ── money / auth vs other high-risk (v2.78.0) ──────────────────────────
if section "money / auth vs other high-risk (v2.78.0)"; then
printf 'codex\n' > "$TMP/.rolepod/cross-family"
printf '{"ts":"%s","phase":"external-fail","kind":"review","cli":"codex","family":"openai","lead":"claude","reason":"exit 1"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TMP/.rolepod/evidence/phase-log.jsonl"
printf '%s\n' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' \
  > "$TRANSCRIPT"
out=$(pcx 'git commit -m "add billing"')
check "money/auth + external FAILED (logged) + internal strong → allow (internal alone clears after a failed pool)" allow "$out"
TMPM=$(mktemp -d); ( cd "$TMPM" && git init -q . && git config user.email t@t && git config user.name t \
  && mkdir -p db/migrations && printf 'ALTER TABLE users ADD COLUMN x int;\n' > db/migrations/001_x.sql && git add db/migrations/001_x.sql )
mkdir -p "$TMPM/.rolepod/evidence/external"; printf 'codex\n' > "$TMPM/.rolepod/cross-family"
head -c 700 /dev/zero | tr '\0' 'x' > "$TMPM/.rolepod/evidence/external/t-codex.txt"
printf '{"ts":"%s","phase":"review","reviewer":"external","kind":"review","cli":"codex","family":"openai","model":"default","raw":"external/t-codex.txt","lead":"claude","secs":9}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TMPM/.rolepod/evidence/phase-log.jsonl"
: > "$TRANSCRIPT"
out=$(printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":"git commit -m x"}}' \
    "$(printf '%s' "$TRANSCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$TMPM" && env HOME="$TMP" PATH="$XF_BIN:/usr/bin:/bin" CLAUDE_PLUGIN_ROOT="$TMP" bash "$HOOKS/precommit-gate.sh") || true)
check "migration path (other high-risk) + external anchor ONLY → allow (external is the pass)" allow "$out"
rm -rf "$TMPM"
rm -f "$TMP/.rolepod/evidence/phase-log.jsonl" "$TMP/.rolepod/cross-family"

fi
# ── hook message state: R4 floor wording, C1 (lean-workflow-dedupe 2026-09-19) ──
if section "hook message state: R4 floor wording, C1 (lean-workflow-dedupe 2026-09-19)"; then
# A Lead must never read "mandatory universal-reviewer + security-engineer" in
# one sentence and "clears on ONE of" in the next — the deny states the R4
# floor once, then the gate's actual (unchanged) mechanical bar.
out=$(pc 'git commit -m "add billing"')
check "HARD-gate deny on a high-risk diff, no reviewer → still deny" deny "$out"
echo "$out" | grep -q 'R4 floor: security-engineer + ONE general strong pass' \
  && echo "  ✓ deny reason states the R4 floor (security-engineer + ONE general strong pass)" \
  || { echo "  ✗ deny reason missing the R4 floor wording"; fail=$((fail+1)); }
echo "$out" | grep -q 'mandatory universal-reviewer' \
  && { echo "  ✗ deny reason still names the superseded 'mandatory universal-reviewer' wording"; fail=$((fail+1)); } \
  || echo "  ✓ deny reason drops the old 'mandatory universal-reviewer' wording"
echo "$out" | grep -q 'The gate opens when one of them has FINISHED' \
  && echo "  ✓ deny reason states the gate opens when one of them has FINISHED (not 'clears on ONE of')" \
  || { echo "  ✗ deny reason missing 'the gate opens when one of them has FINISHED' wording"; fail=$((fail+1)); }

# gate-reminder AUTO-CAREFUL banner: a usable pool names the external in
# place of universal-reviewer + security-engineer — never the money/auth
# "alone clears" carve-out (C1: money/auth follow the same rule).
mkdir -p "$TMP/.rolepod"; printf 'codex\n' > "$TMP/.rolepod/cross-family"
grx() { # $1 = json body — gate-reminder with a usable cross-family pool stub (codex on PATH, Lead=claude)
  printf '%s' "$1" | (cd "$TMP" && env HOME="$TMP" PATH="$XF_BIN:/usr/bin:/bin" CLAUDE_PLUGIN_ROOT="$TMP" bash "$HOOKS/gate-reminder.sh")
}
out=$(grx '{"tool_name":"Edit","tool_input":{"file_path":"src/auth/login.py"}}')
echo "$out" | grep -q 'in place of universal-reviewer' \
  && echo "  ✓ AUTO-CAREFUL reminder with a usable pool: the external runs in place of universal-reviewer" \
  || { echo "  ✗ AUTO-CAREFUL reminder with a usable pool missing the 'in place of universal-reviewer' wording"; fail=$((fail+1)); }
echo "$out" | grep -q 'rolepod:security-engineer' \
  && echo "  ✓ AUTO-CAREFUL reminder with a usable pool names rolepod:security-engineer" \
  || { echo "  ✗ AUTO-CAREFUL reminder with a usable pool missing rolepod:security-engineer"; fail=$((fail+1)); }
echo "$out" | grep -q 'alone clears' \
  && { echo "  ✗ AUTO-CAREFUL reminder still carries the 'alone clears' money/auth sentence"; fail=$((fail+1)); } \
  || echo "  ✓ AUTO-CAREFUL reminder drops the 'alone clears' money/auth sentence"
rm -f "$TMP/.rolepod/cross-family"

fi
# ── private working docs never commit (v2.80.0) ─────────────────────────
if section "private working docs never commit (v2.80.0)"; then
TMPD=$(mktemp -d); ( cd "$TMPD" && git init -q . && git config user.email t@t && git config user.name t \
  && mkdir -p docs/rolepod/specs src && printf 'secret spec\n' > docs/rolepod/specs/x.md && printf 'x=1\n' > src/a.py && git add -A )
pcd() { printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | (cd "$TMPD" && HOME="$TMP" bash "$HOOKS/precommit-gate.sh") || true; }
out=$(pcd)
check "staged docs/rolepod/specs/x.md → deny (private working docs never commit)" deny "$out"
echo "$out" | grep -q 'docs-tracked' && echo "$out" | grep -q 'docs/rolepod/specs/x.md' \
  && echo "  ✓ deny reason names the file and the opt-in marker" \
  || { echo "  ✗ private-docs deny reason incomplete"; fail=$((fail+1)); }
mkdir -p "$TMPD/.rolepod" && : > "$TMPD/.rolepod/docs-tracked"
out=$(pcd)
echo "$out" | grep -q 'private working docs' \
  && { echo "  ✗ .rolepod/docs-tracked did not lift the private-docs deny"; fail=$((fail+1)); } \
  || echo "  ✓ .rolepod/docs-tracked lets a repo track its working docs"
rm -rf "$TMPD"

fi
# ── precommit-gate follows the commit's directory: cd / -C (2026-09-21 delta) ──
if section "precommit-gate follows the commit's directory: cd / -C (2026-09-21 delta)"; then
# `cd <dir> && git commit` or `git -C <dir> commit` used to be judged against
# the SESSION checkout (hook cwd) — a clean session checkout meant an empty
# diff and a silent exit 0, so the worktree commit was never gated. Every
# case here starts the hook with cwd = a clean MAIN checkout; the staged
# diff lives only in a linked worktree.
GD_MAIN=$(mktemp -d)
( cd "$GD_MAIN" && git init -q . && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m base )
gd_wt() { # $1 = suffix — fresh linked worktree at $GD_MAIN-wt-$1, prints its path
  local d="${GD_MAIN}-wt-$1"
  git -C "$GD_MAIN" worktree add -q -b "gd-$1" "$d" >/dev/null 2>&1
  printf '%s' "$d"
}
gd() { # $1 = command (hook cwd = $GD_MAIN), $2 = optional transcript path
  # HOME=$GD_MAIN sandboxes an auto-pass's ~/.rolepod/gate-bypass.log write —
  # test 5 below auto-passes and must not touch the real machine's home dir.
  if [ -n "${2:-}" ]; then
    printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":%s}}' \
      "$(printf '%s' "$2" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
      "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
      | (cd "$GD_MAIN" && HOME="$GD_MAIN" bash "$HOOKS/precommit-gate.sh") || true
  else
    printf '{"tool_name":"Bash","tool_input":{"command":%s}}' \
      "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
      | (cd "$GD_MAIN" && HOME="$GD_MAIN" bash "$HOOKS/precommit-gate.sh") || true
  fi
}

# (1)/(2) worktree stages high-risk logic; main's own index stays empty.
GD_WT1=$(gd_wt 1)
( cd "$GD_WT1" && mkdir -p src/auth && seq 15 | sed 's/^/x = /' > src/auth/login.py && git add -A )
out=$(gd "cd $GD_WT1 && git commit -m x")
check "worktree high-risk diff via 'cd <wt> && git commit' from main → deny (was silent — main's own index is empty)" deny "$out"
out=$(gd "git -C $GD_WT1 commit -m x")
check "worktree high-risk diff via 'git -C <wt> commit' from main → deny" deny "$out"

# (3) worktree stages plain (non-risk) logic → SOFT line carries the WORKTREE's own counts.
GD_WT3=$(gd_wt 3)
( cd "$GD_WT3" && mkdir -p src && seq 15 | sed 's/^/const x = /' > src/util.ts && git add -A )
out=$(gd "cd $GD_WT3 && git commit -m x")
check "worktree plain logic diff → allow (SOFT, not the session checkout's empty index)" allow "$out"
echo "$out" | grep -q '1 files / 15 lines / 15 logic' \
  && echo "  ✓ SOFT line carries the WORKTREE's own counts (1 files / 15 lines / 15 logic)" \
  || { echo "  ✗ SOFT line missing the worktree's counts: ${out:0:200}"; fail=$((fail+1)); }

# (4) worktree stages a private working doc → deny naming it, read off the worktree not main.
GD_WT4=$(gd_wt 4)
( cd "$GD_WT4" && mkdir -p docs/rolepod/plans && printf 'secret plan\n' > docs/rolepod/plans/x.md && git add -A )
out=$(gd "cd $GD_WT4 && git commit -m x")
check "worktree stages docs/rolepod/plans/x.md → deny (private docs, read off the worktree)" deny "$out"
echo "$out" | grep -q 'docs/rolepod/plans/x.md' \
  && echo "  ✓ deny names the worktree's staged private doc" \
  || { echo "  ✗ private-docs deny missing the worktree's file: ${out:0:200}"; fail=$((fail+1)); }

# (5) evidence window in a linked worktree (R4): a fast-forward from main is
# not a commit and must not slide the window past a reviewer dispatched
# before it. Differential proof: main's post-worktree commit is dated FAR in
# the future (2099) — if the window were still anchored to "gitd log -1"
# (today's non-worktree rule) the 2050-dated dispatch below would read as
# stale against it; anchored to the worktree's own creation reflog instead
# (real "now", years before 2050), it counts.
GD_WT5=$(gd_wt 5)
GD_T5="$GD_MAIN-t5.jsonl"
printf '%s\n' \
  '{"type":"assistant","timestamp":"2050-01-01T00:00:00.000Z","message":{"model":"claude-opus-5","content":[{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:universal-reviewer","prompt":"review"}}]}}' \
  > "$GD_T5"
( cd "$GD_MAIN" && printf 'y\n' > extra.txt && git add -A \
  && GIT_COMMITTER_DATE="2099-01-01T00:00:00" git commit -q --date="2099-01-01T00:00:00" -m "main gains a future-dated commit" )
( cd "$GD_WT5" && git merge -q --ff-only main )
( cd "$GD_WT5" && mkdir -p src && seq 15 | sed 's/^/const x = /' > src/util2.ts && git add -A )
out=$(gd "cd $GD_WT5 && git commit -m x" "$GD_T5")
check "reviewer dispatched before a worktree ff-only merge + a plain logic diff → allow (SOFT)" allow "$out"
echo "$out" | grep -q 'reviewers since last commit: 1' \
  && echo "  ✓ SOFT line: the pre-merge reviewer still counts (window anchored to the worktree's creation, not gitd's last commit)" \
  || { echo "  ✗ SOFT line lost the pre-merge reviewer: ${out:0:200}"; fail=$((fail+1)); }
( cd "$GD_WT5" && mkdir -p src/auth && seq 15 | sed 's/^/x = /' > src/auth/pay.py && git add -A )
out=$(gd "cd $GD_WT5 && git commit -m x" "$GD_T5")
check "same reviewer + a HIGH-RISK diff staged after the ff-only merge → auto-pass" allow "$out"
echo "$out" | grep -q 'auto-passed' \
  && echo "  ✓ high-risk variant auto-passes on the pre-merge reviewer" \
  || { echo "  ✗ high-risk variant did not auto-pass: ${out:0:200}"; fail=$((fail+1)); }
# Catches a degenerate epoch (e.g. a %gd format change reading "1" out of
# "HEAD@{1}" instead of a real unix stamp): that would still pass the digit
# guard and anchor the window at 1970 — maximally lenient, so the assertions
# above would stay green for the wrong reason. A real-looking anchor year
# rules that out without pinning a literal date.
echo "$out" | grep -q "since last commit $(date +%Y)-" \
  && echo "  ✓ auto-pass note anchors the window to the real current year, not a degenerate 1970 (or other in-range) epoch" \
  || { echo "  ✗ auto-pass note missing the real anchor year: ${out:0:200}"; fail=$((fail+1)); }

# (6) unresolvable directory → today's behavior: fail open to the hook cwd,
# silent rc 0, no `set -u` crash on an unset var or a missing path.
GD_MAIN6=$(mktemp -d)
( cd "$GD_MAIN6" && git init -q . && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m base )
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"cd /nonexistent && git commit -m x"}}' | (cd "$GD_MAIN6" && HOME="$GD_MAIN6" bash "$HOOKS/precommit-gate.sh") || true)
[ -z "$out" ] && echo "  ✓ cd /nonexistent (missing dir) + clean main → silent (fail-open to the hook cwd)" \
  || { echo "  ✗ cd /nonexistent should fail open silently: ${out:0:120}"; fail=$((fail+1)); }
rc=0
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"cd \"$NOPE\" && git commit -m x"}}' | (cd "$GD_MAIN6" && HOME="$GD_MAIN6" bash "$HOOKS/precommit-gate.sh")) || rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] \
  && echo "  ✓ cd \"\$NOPE\" (unset var) + clean main → silent rc 0, no set -u crash" \
  || { echo "  ✗ cd \"\$NOPE\" case: rc=$rc out=${out:0:120}"; fail=$((fail+1)); }

# (7) F2 regression: hook cwd is not inside ANY git repo, but the resolved
# `cd` directory is a real worktree with a high-risk staged diff (reusing
# GD_WT1 from case 1/2). `_pd_root`'s `git rev-parse --show-toplevel` fails
# here (hook cwd, rc 128) — without `|| true` on it and its fallback, that
# kills the whole script under `set -e` before R3's own fallback ever runs.
GD_NONREPO=$(mktemp -d)
out=$(printf '{"tool_name":"Bash","tool_input":{"command":%s}}' \
  "$(printf '%s' "cd $GD_WT1 && git commit -m x" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
  | (cd "$GD_NONREPO" && HOME="$GD_NONREPO" bash "$HOOKS/precommit-gate.sh") || true)
check "hook cwd is not a git repo + 'cd <worktree> && git commit' on a high-risk diff → deny (no set -e crash)" deny "$out"

# (8) F1 regression: an UNQUOTED '#' in the worktree path must not truncate
# the token walk (shlex.shlex's default commenters='#') and read as hit=0 —
# a bare `# ...` reads as a shell comment in word state too, so this would
# otherwise silently skip the gate exactly like the pre-fix bug case 1 covers.
GD_WTHASH="${GD_MAIN}-wt#3"
git -C "$GD_MAIN" worktree add -q -b gd-hash "$GD_WTHASH" >/dev/null 2>&1
( cd "$GD_WTHASH" && mkdir -p src/auth && seq 15 | sed 's/^/x = /' > src/auth/login2.py && git add -A )
out=$(gd "cd $GD_WTHASH && git commit -m x")
check "worktree path with an unquoted '#' + high-risk diff → deny (not silently truncated)" deny "$out"

# (9) SOFT: a rolepod-ticket worktree (basename *-wt-*-tN*) leaves out the
# "0 reviewers on a logic diff" sentence — the Lead's ONE combined review
# already covers it (spec lean-loop-2026-09-23 Task 2, implement-plan §6);
# the rest of the SOFT line (counts, the Gates sentence) still prints.
GD_WT9="${GD_MAIN}-wt-sample-feature-t9-build-widget"
git -C "$GD_MAIN" worktree add -q -b gd-9 "$GD_WT9" >/dev/null 2>&1
( cd "$GD_WT9" && mkdir -p src && seq 15 | sed 's/^/const x = /' > src/util9.ts && git add -A )
out=$(gd "cd $GD_WT9 && git commit -m x")
check "*-wt-*-t9-* worktree, plain logic diff, 0 reviewers → allow (SOFT)" allow "$out"
echo "$out" | grep -qF '0 reviewers on a logic diff' \
  && { echo "  ✗ ticket worktree SOFT line still carries the 0-reviewers sentence"; fail=$((fail+1)); } \
  || echo "  ✓ ticket worktree (*-wt-*-t9-*) SOFT line leaves out the 0-reviewers sentence"
echo "$out" | grep -qF 'Gates S1-S5' \
  && echo "  ✓ ticket worktree SOFT line still carries the rest of the message" \
  || { echo "  ✗ ticket worktree SOFT line dropped too much: ${out:0:200}"; fail=$((fail+1)); }
echo "$out" | grep -qF '15 logic' \
  && echo "  ✓ ticket worktree SOFT line still carries the diff counts" \
  || { echo "  ✗ ticket worktree SOFT line missing diff counts: ${out:0:200}"; fail=$((fail+1)); }

rm -rf "$GD_MAIN" "$GD_MAIN"-wt-* "$GD_MAIN"-t5.jsonl "$GD_MAIN6" "$GD_NONREPO" "$GD_WTHASH"

fi
# ── project-context-loader: cross-family is never asked unprompted (v2.142.0) ──
if section "project-context-loader: cross-family is never asked unprompted (v2.142.0)"; then
XF_HOME="$TMP/xfhome"; rm -rf "$XF_HOME"; mkdir -p "$XF_HOME"
XF_REPO="$TMP/xfrepo"; mkdir -p "$XF_REPO"; git -C "$XF_REPO" init -q; git -C "$XF_REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init  # loader needs ≥1 commit
pcl() { printf '{"cwd":%s}' "$(printf '%s' "$XF_REPO" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
  | (cd "$XF_REPO" && env HOME="$XF_HOME" PATH="$XF_BIN:/usr/bin:/bin" CLAUDE_PLUGIN_ROOT="$TMP" bash "$HOOKS/project-context-loader.sh") || true; }
out=$(pcl)
echo "$out" | grep -q 'ASK THE USER' \
  && { echo "  ✗ loader still asks the cross-family question"; fail=$((fail+1)); } \
  || echo "  ✓ loader never asks the cross-family question"
echo "$out" | grep -q 'cross-family pool: not set' && echo "$out" | grep -q 'rolepod-cross-family --setup' \
  && echo "  ✓ no pool file + a second CLI → one silent line naming --setup" \
  || { echo "  ✗ silent setup line missing"; fail=$((fail+1)); }
[ -f "$XF_HOME/.rolepod/cross-family.asked" ] \
  && { echo "  ✗ loader still writes the asked-marker"; fail=$((fail+1)); } \
  || echo "  ✓ no asked-marker written"
mkdir -p "$XF_HOME/.rolepod"; printf 'none\n' > "$XF_HOME/.rolepod/cross-family"
out=$(pcl)
echo "$out" | grep -q 'cross-family pool: not set' \
  && { echo "  ✗ loader mentions setup although a config exists"; fail=$((fail+1)); } \
  || echo "  ✓ an existing config (none) silences the setup line"

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

fi
# ── precommit: content-based high-risk (v2.46.0) ────────────────────────
if section "precommit: content-based high-risk (v2.46.0)"; then
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

# v2.86.0: the content check skips prose and honours `-` lines in .rolepod/risk-paths.
TMP4=$(mktemp -d)
pcr() { # $1 = file, $2 = content, $3 = optional risk-paths body; fresh repo each call
  rm -rf "$TMP4"; mkdir -p "$TMP4/$(dirname "$1")"
  ( cd "$TMP4" && git init -q . && git config user.email t@t && git config user.name t \
    && printf '%b' "$2" > "$1" && git add "$1" \
    && { [ -z "${3:-}" ] || { mkdir -p .rolepod && printf '%b' "$3" > .rolepod/risk-paths; }; } )
  printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":"git commit -m x"}}' \
    "$(printf '%s' "$TRANSCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$TMP4" && HOME="$TMP" bash "$HOOKS/precommit-gate.sh") || true
}
check "precommit refund wording in docs/refunds.md alone → allow (prose is not money logic)" allow \
  "$(pcr docs/refunds.md '# Refund policy\n\nA refund is issued within 14 days.\nPayout timing follows the settlement window.\n')"
check "precommit refund logic in services/closure.py → still deny" deny \
  "$(pcr services/closure.py 'def close(b):\n    return refund_amount(b)\n')"
check "precommit refund logic excluded by a risk-paths - line → allow" allow \
  "$(pcr services/closure.py 'def close(b):\n    return refund_amount(b)\n' '-(^|/)services/closure\\.py$\n')"
check "precommit prose rule must not drop a CODE line containing '.md +' → deny" deny \
  "$(pcr services/closure.py 'def close(b):\n    return b.refund.md + b.total\n')"
check "precommit refund prose in a space-named doc ('d2/refund notes.md') → allow" allow \
  "$(pcr 'd2/refund notes.md' '# Refund notes\n\nPayout after settlement.\n')"
rm -rf "$TMP4"

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

fi
# ── precommit: evidence window = since the last commit (v2.47.0) ────────
if section "precommit: evidence window = since the last commit (v2.47.0)"; then
# A 12-day session must not clear today's high-risk commit with a reviewer
# dispatched ten days ago. git's commit clock is the floor; events without a
# timestamp stay counted (fail-open); subagent transcripts of the session
# (<transcript-dir>/<session>/subagents/**/agent-*.jsonl) count too.
TMP4=$(mktemp -d)
(
  cd "$TMP4"
  git init -q .
  git config user.email t@t && git config user.name t
  printf 'x\n' > README && git add README && git commit -q -m init
  mkdir -p auth
  printf 'def charge(u):\n    return u.balance - 1\n' > auth/billing.py
  git add auth/billing.py
)
T4="$TMP4/sess.jsonl"
pcw() { # $1 = transcript, $2 = extra env prefix (optional)
  printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":"git commit -m x"}}' \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$TMP4" && HOME="$TMP" env $2 bash "$HOOKS/precommit-gate.sh") || true
}
printf '%s\n' \
  '{"type":"assistant","timestamp":"2020-01-01T00:00:00.000Z","message":{"model":"claude-opus-5","content":[{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}]}}' \
  > "$T4"
out=$(pcw "$T4" "")
check "precommit window: strong reviewer BEFORE the last commit → deny (stale evidence)" deny "$out"
echo "$out" | grep -q 'since last commit' \
  && echo "  ✓ deny reason states the evidence window" \
  || { echo "  ✗ deny reason missing the window"; fail=$((fail+1)); }
printf '%s\n' \
  '{"type":"assistant","timestamp":"2099-01-01T00:00:00.000Z","message":{"model":"claude-opus-5","content":[{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}]}}' \
  > "$T4"
out=$(pcw "$T4" "")
check "precommit window: strong reviewer AFTER the last commit → auto-pass" allow "$out"
printf '%s\n' \
  '{"type":"assistant","timestamp":"2099-01-01T00:00:00.000Z","message":{"model":"claude-sonnet-5","content":[{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:universal-reviewer","model":"sonnet","prompt":"review"}}]}}' \
  > "$T4"
out=$(pcw "$T4" "")
check "precommit: universal-reviewer explicitly at sonnet → NOT the strong pass → deny" deny "$out"
# Subagent transcript evidence: main transcript empty, a Workflow agent wrote
# the test — counts for a NON-path HARD block (env-forced normal diff).
(
  cd "$TMP4" && git reset -q && printf 'y = 2\n' > util.py && git add util.py
)
: > "$T4"
mkdir -p "$TMP4/sess/subagents/workflows/wf_1"
printf '%s\n' \
  '{"type":"assistant","timestamp":"2099-01-01T00:00:00.000Z","message":{"model":"claude-sonnet-5","content":[{"type":"tool_use","name":"Write","input":{"file_path":"tests/test_util.py","content":"x"}}]}}' \
  > "$TMP4/sess/subagents/workflows/wf_1/agent-abc.jsonl"
out=$(pcw "$T4" "ROLEPOD_GATES_HARD=1")
check "precommit: test written by a Workflow subagent counts as evidence → auto-pass" allow "$out"
rm -rf "$TMP4"

fi
# ─── fix-loop-breaker: count fails mechanically, reset on pass ────────
if section "fix-loop-breaker: count fails mechanically, reset on pass"; then
# The counter must fire at the 3rd consecutive identical-command failure and
# stay silent after a passing run resets it — the whole point is that the
# model does NOT do the counting.
LB_TMP=$(mktemp -d)
lb() { # $1 = session id, $2 = exit code ("" = success shape, no exit signal)
  local sid="$1" code="$2" resp
  if [ -n "$code" ]; then
    resp="{\"exitCode\":$code,\"stderr\":\"boom\"}"
  else
    resp='{"stdout":"ok"}'
  fi
  printf '{"session_id":"%s","tool_name":"Bash","tool_input":{"command":"pytest tests/test_x.py -v"},"tool_response":%s}' \
    "$sid" "$resp" | TMPDIR="$LB_TMP" bash "$HOOKS/fix-loop-breaker.sh"
}
check_ctx() { # $1 desc, $2 expected (nudge|silent), $3 output
  local desc="$1" expected="$2" out="$3" verdict="silent"
  echo "$out" | grep -q 'LOOP BREAKER' && verdict="nudge"
  if [ "$verdict" = "$expected" ]; then
    echo "  ✓ $desc"
  else
    echo "  ✗ $desc (expected $expected, got $verdict)"
    fail=$((fail+1))
  fi
}

check_ctx "loop-breaker: 1st fail → silent" silent "$(lb s1 1)"
check_ctx "loop-breaker: 2nd fail → silent" silent "$(lb s1 1)"
check_ctx "loop-breaker: 3rd consecutive fail → LOOP BREAKER nudge" nudge "$(lb s1 1)"
check_ctx "loop-breaker: 4th fail keeps nudging" nudge "$(lb s1 1)"
lb s1 "" > /dev/null   # passing run resets the counter
check_ctx "loop-breaker: fail after a pass → silent again (reset)" silent "$(lb s1 1)"
# "Exit code N" text form (no structured exitCode field) must also count
lbtext() {
  printf '{"session_id":"s2","tool_name":"Bash","tool_input":{"command":"make build"},"tool_response":"Exit code 2 boom"}' \
    | TMPDIR="$LB_TMP" bash "$HOOKS/fix-loop-breaker.sh"
}
lbtext > /dev/null; lbtext > /dev/null
check_ctx "loop-breaker: 'Exit code N' text form counts → nudge at 3rd" nudge "$(lbtext)"
check_ctx "loop-breaker: different session id isolated → silent" silent "$(lb s3 1)"
rm -rf "$LB_TMP"

fi
# ── fix-loop-breaker: post-commit worktree reminder removed v2.164.0 ──
if section "fix-loop-breaker: post-commit worktree reminder removed v2.164.0"; then
WT_TMP=$(mktemp -d); WT_HOME="$WT_TMP/home"; mkdir -p "$WT_HOME"
( cd "$WT_TMP" && git init -q r && cd r && git config user.email t@t && git config user.name t \
  && echo a > a && git add a && git commit -qm a \
  && git worktree add -q .worktrees/t1 -b t1 2>/dev/null ) >/dev/null 2>&1
touch -t 202601010000 "$WT_TMP/r/.worktrees/t1/.git"
wtc() { # $1 = command, $2 = cwd
  printf '{"session_id":"w1","tool_name":"Bash","tool_input":{"command":"%s"},"tool_response":{"exit_code":0}}' "$1" \
    | (cd "${2:-$WT_TMP/r}" && HOME="$WT_HOME" TMPDIR="$WT_TMP" bash "$HOOKS/fix-loop-breaker.sh")
}
out=$(wtc 'git commit -m x')
echo "$out" | grep -q 'WORKTREES LEFT' \
  && { echo "  ✗ a commit with a leftover worktree still prints a worktree reminder"; fail=$((fail+1)); } \
  || echo "  ✓ a commit with a leftover worktree prints no worktree reminder (removed v2.164.0)"
rm -rf "$WT_TMP"

fi
# ── sweep-nudge removed v2.164.0 (the always-on core states the scout rule) ──
if section "sweep-nudge removed v2.164.0"; then
[ ! -e "$HOOKS/sweep-nudge.sh" ] \
  && echo "  ✓ hooks/sweep-nudge.sh no longer ships" \
  || { echo "  ✗ hooks/sweep-nudge.sh still present"; fail=$((fail+1)); }

fi
# ── review in flight (v2.93.0): a live detached cross-family job freezes the diff ──
if section "review in flight (v2.93.0): a live detached cross-family job freezes the diff"; then
# gate-reminder warns (never denies) on an edit to a file the job's attached
# diff touches; precommit-gate warns on a tree rewrite (stash / reset --hard /
# checkout); both stay silent for other files, read-only git, or a finished job.
RF_TMP=$(mktemp -d)
( cd "$RF_TMP" && git init -q . && git config user.email t@t && git config user.name t \
  && mkdir -p src && echo 'a' > src/pay.ts && echo 'b' > src/other.ts && git add -A && git commit -qm init )
RF_JOB="$RF_TMP/.rolepod/evidence/external/jobs/20260907T000000Z-review-1"
mkdir -p "$RF_JOB"
printf 'diff --git a/src/pay.ts b/src/pay.ts\n--- a/src/pay.ts\n+++ b/src/pay.ts\n@@ -1 +1 @@\n-a\n+b\n' > "$RF_TMP/diff.patch"
printf -- '--kind review --brief %q --attach %q --lead claude\n' "$RF_TMP/brief.md" "$RF_TMP/diff.patch" > "$RF_JOB/args"
date +%s > "$RF_JOB/started"
bash -c 'exec -a cross-family-fake sleep 120' & RF_PID=$!
echo "$RF_PID" > "$RF_JOB/pid"
rf_edit() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" | (cd "$RF_TMP" && bash "$HOOKS/gate-reminder.sh") || true; }
rf_bash() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | (cd "$RF_TMP" && bash "$HOOKS/precommit-gate.sh") || true; }
out=$(rf_edit "$RF_TMP/src/pay.ts")
if echo "$out" | grep -q 'REVIEW IN FLIGHT' && ! echo "$out" | grep -q '"permissionDecision"'; then
  echo "  ✓ gate-reminder: edit to a file under review while the job runs → advisory line, not a deny"
else echo "  ✗ gate-reminder in-flight edit: ${out:0:160}"; fail=$((fail+1)); fi
out=$(rf_edit "$RF_TMP/src/other.ts")
if echo "$out" | grep -q 'REVIEW IN FLIGHT'; then echo "  ✗ gate-reminder warned on a file outside the attached diff"; fail=$((fail+1))
else echo "  ✓ gate-reminder: file outside the diff → silent"; fi
# an implement job: the trigger is the ticket's allow list, not the diff — inside = silent, outside = EXTERNAL IMPLEMENT warning
RF_IJOB="$RF_TMP/.rolepod/evidence/external/jobs/20260907T000001Z-implement-1"; mkdir -p "$RF_IJOB"
printf 'src/pay.ts\n' > "$RF_IJOB/allow"; date +%s > "$RF_IJOB/started"; echo "$RF_PID" > "$RF_IJOB/pid"; printf -- '--kind implement --brief x --allow src/pay.ts\n' > "$RF_IJOB/args"
out=$(rf_edit "$RF_TMP/src/other.ts")
if echo "$out" | grep -q 'EXTERNAL IMPLEMENT IN FLIGHT' && ! echo "$out" | grep -q '"permissionDecision"'; then
  echo "  ✓ gate-reminder: edit OUTSIDE an implement job's allow list → EXTERNAL IMPLEMENT advisory"
else echo "  ✗ gate-reminder implement outside-allow: ${out:0:160}"; fail=$((fail+1)); fi
out=$(rf_edit "$RF_TMP/src/pay.ts")
if echo "$out" | grep -q 'EXTERNAL IMPLEMENT IN FLIGHT'; then echo "  ✗ gate-reminder warned INSIDE the implement job's allow list"; fail=$((fail+1))
else echo "  ✓ gate-reminder: edit inside the implement job's allow list → silent"; fi
printf 'src/pay.ts\nsrc/new/\n' > "$RF_IJOB/allow"
out=$(rf_edit "$RF_TMP/src/new/deep/file.ts")
if echo "$out" | grep -q 'EXTERNAL IMPLEMENT IN FLIGHT'; then echo "  ✗ gate-reminder warned on a NEW file in a not-yet-existing dir inside the allow list (symlinked tmp root)"; fail=$((fail+1))
else echo "  ✓ gate-reminder: new file in a not-yet-existing directory inside the allow list → silent (path resolved through the nearest existing ancestor)"; fi
out=$(rf_edit "$RF_TMP/src/elsewhere/file.ts")
if echo "$out" | grep -q 'EXTERNAL IMPLEMENT IN FLIGHT'; then echo "  ✓ gate-reminder: new file in a not-yet-existing dir OUTSIDE the allow list → warned"
else echo "  ✗ gate-reminder stayed silent on a new file outside the allow list"; fail=$((fail+1)); fi
rm -rf "$RF_IJOB"
out=$(rf_bash 'git stash')
if echo "$out" | grep -q 'REVIEW IN FLIGHT' && ! echo "$out" | grep -q '"permissionDecision"'; then
  echo "  ✓ precommit-gate: git stash while the job runs → advisory line, not a deny"
else echo "  ✗ precommit-gate in-flight stash: ${out:0:160}"; fail=$((fail+1)); fi
out=$(rf_bash 'git reset --hard HEAD')
if echo "$out" | grep -q 'REVIEW IN FLIGHT'; then echo "  ✓ precommit-gate: git reset --hard while the job runs → advisory line"
else echo "  ✗ precommit-gate in-flight reset --hard silent"; fail=$((fail+1)); fi
for ro in 'git stash list' 'git reset src/pay.ts' 'git status' 'git diff HEAD'; do
  out=$(rf_bash "$ro")
  if echo "$out" | grep -q 'REVIEW IN FLIGHT'; then echo "  ✗ precommit-gate warned on read-only/index-only '$ro'"; fail=$((fail+1))
  else echo "  ✓ precommit-gate: '$ro' → silent"; fi
done
out=$( (export ROLEPOD_GATES_SOFT=1; rf_edit "$RF_TMP/src/pay.ts") )
if echo "$out" | grep -q 'REVIEW IN FLIGHT'; then echo "  ✗ gate-reminder in-flight line ignores ROLEPOD_GATES_SOFT"; fail=$((fail+1))
else echo "  ✓ gate-reminder: ROLEPOD_GATES_SOFT=1 silences the in-flight line"; fi
# attachments gone (tmp cleaned) → the current WIP stands in for the file list
rm -f "$RF_TMP/diff.patch"; echo 'c' > "$RF_TMP/src/other.ts"
out=$(rf_edit "$RF_TMP/src/other.ts")
if echo "$out" | grep -q 'REVIEW IN FLIGHT'; then echo "  ✓ gate-reminder: attachment gone → WIP file (git diff HEAD) still warns"
else echo "  ✗ gate-reminder: attachment-gone fallback missed a WIP file"; fail=$((fail+1)); fi
echo 0 > "$RF_JOB/status"
out=$(rf_edit "$RF_TMP/src/pay.ts"); out2=$(rf_bash 'git stash')
if { echo "$out"; echo "$out2"; } | grep -q 'REVIEW IN FLIGHT'; then echo "  ✗ finished job (status file) still warns"; fail=$((fail+1))
else echo "  ✓ job finished (status written) → both hooks silent"; fi
kill "$RF_PID" 2>/dev/null; wait "$RF_PID" 2>/dev/null || true; rm -rf "$RF_TMP"

fi
# ── precommit SOFT line names the reviewer count (v2.95.0) ────────────────
if section "precommit SOFT line names the reviewer count (v2.95.0)"; then
SF_TMP=$(mktemp -d)
sf() { # $1 file, $2 content-generator command
  rm -rf "$SF_TMP"; mkdir -p "$SF_TMP/$(dirname "$1")"
  ( cd "$SF_TMP" && git init -q . && git config user.email t@t && git config user.name t && eval "$2" > "$1" && git add -A )
  printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | (cd "$SF_TMP" && bash "$HOOKS/precommit-gate.sh") || true
}
out=$(sf src/util.ts "seq 15 | sed 's/^/const x = /'")
if echo "$out" | grep -q 'reviewers since last commit: 0' && echo "$out" | grep -q 'rolepod:universal-reviewer' && ! echo "$out" | grep -q '"permissionDecision"'; then
  echo "  ✓ precommit SOFT: logic diff, 0 reviewers → names the count + the read-only reviewer, still allow"
else echo "  ✗ precommit SOFT reviewer line: ${out:0:200}"; fail=$((fail+1)); fi
out=$(sf src/label.ts "printf 'export const L = \"Save\";\nexport const M = \"Cancel\";\n'")
if echo "$out" | grep -q 'reviewers since last commit: 0' && ! echo "$out" | grep -q '0 reviewers on a logic diff'; then
  echo "  ✓ precommit SOFT: R1-shaped diff (1 file, ≤5 lines) → count only, no reviewer ask (string text is R1 in the router)"
else echo "  ✗ precommit SOFT R1-shaped: ${out:0:200}"; fail=$((fail+1)); fi
out=$(sf src/notes.ts "seq 10 | sed 's/^/\/\/ note /'")
if echo "$out" | grep -q 'reviewers since last commit: 0' && ! echo "$out" | grep -q '0 reviewers on a logic diff'; then
  echo "  ✓ precommit SOFT: comment-only diff → count shown, no reviewer ask (nothing logic-bearing)"
else echo "  ✗ precommit SOFT comment-only: ${out:0:200}"; fail=$((fail+1)); fi
# v2.153.0 — the count is about code: prose lines of a mixed diff and pure
# version-field lines are not logic, and the ask names its exception.
sf_run() { printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | (cd "$SF_TMP" && bash "$HOOKS/precommit-gate.sh") || true; }
sfm() { # $1 = code lines in ONE code file, beside 30 prose lines
  rm -rf "$SF_TMP"; mkdir -p "$SF_TMP/docs" "$SF_TMP/src"
  ( cd "$SF_TMP" && git init -q . && git config user.email t@t && git config user.name t && seq 30 | sed 's/^/Line /' > docs/guide.md && seq "$1" | sed 's/^/const x = /' > src/util.ts && git add -A )
  sf_run
}
out=$(sfm 2)
if echo "$out" | grep -q '/ 2 logic' && ! echo "$out" | grep -q '0 reviewers on a logic diff'; then
  echo "  ✓ precommit SOFT: docs + a 2-line code file → 2 logic (prose never counts), no reviewer ask"
else echo "  ✗ precommit SOFT mixed docs + small code: ${out:0:200}"; fail=$((fail+1)); fi
out=$(sfm 15)
if echo "$out" | grep -q '/ 15 logic' && echo "$out" | grep -q '0 reviewers on a logic diff' && echo "$out" | grep -q 'Exception: '; then
  echo "  ✓ precommit SOFT: docs + a 15-line code file → 15 logic, reviewer ask carries its Exception"
else echo "  ✗ precommit SOFT mixed docs + code: ${out:0:260}"; fail=$((fail+1)); fi
sfv() { # three manifests, only the version field moves
  rm -rf "$SF_TMP"; mkdir -p "$SF_TMP"
  ( cd "$SF_TMP" && git init -q . && git config user.email t@t && git config user.name t \
    && printf '{\n  "name": "x",\n  "version": "1.2.3"\n}\n' > package.json && cp package.json plugin.json \
    && printf '[package]\nname = "x"\nversion = "1.2.3"\n' > Cargo.toml && git add -A && git commit -q -m base \
    && for f in package.json plugin.json Cargo.toml; do sed 's/1\.2\.3/1.2.4/' "$f" > "$f.n" && mv "$f.n" "$f"; done && git add -A )
  sf_run
}
out=$(sfv)
if echo "$out" | grep -q '3 files / 6 lines / 0 logic' && ! echo "$out" | grep -q '0 reviewers on a logic diff'; then
  echo "  ✓ precommit SOFT: version bump across 3 manifests → 0 logic, no reviewer ask"
else echo "  ✗ precommit SOFT version bump: ${out:0:200}"; fail=$((fail+1)); fi
# A line that only LOOKS like a version field is still logic (6 lines → ask).
out=$(sf src/ver.ts "printf 'const version = compute()\nversion: 1.2.3;run()\nversion: 1.2.3,foo:bar\nif (version > 2) go()\nversion = next(1.2.3)\nexport default version\n'")
if echo "$out" | grep -q '/ 6 logic' && echo "$out" | grep -q '0 reviewers on a logic diff'; then
  echo "  ✓ precommit SOFT: code that merely mentions a version (or trails junk after one) still counts as logic"
else echo "  ✗ precommit SOFT version look-alikes: ${out:0:200}"; fail=$((fail+1)); fi
out=$(sf src/rel.toml "printf 'version = \"1.2.3-rc.1+build.5\"\nversion: v2.0.0\n'")
if echo "$out" | grep -q '/ 0 logic'; then
  echo "  ✓ precommit SOFT: pre-release / build suffix and a v prefix are still a version field"
else echo "  ✗ precommit SOFT semver suffix: ${out:0:200}"; fail=$((fail+1)); fi
sfq() { # a prose file git must QUOTE in the diff header (non-ASCII name) + a deleted prose file + a removed SQL comment
  rm -rf "$SF_TMP"; mkdir -p "$SF_TMP/docs" "$SF_TMP/db"
  ( cd "$SF_TMP" && git init -q . && git config user.email t@t && git config user.name t \
    && seq 12 | sed 's/^/Old /' > docs/old.md && printf -- '-- drop me\nSELECT 1;\n' > db/q.sql && git add -A && git commit -q -m base \
    && seq 20 | sed 's/^/Line /' > "docs/$(printf '\303\251')tude.md" && git rm -q docs/old.md && printf 'SELECT 1;\n' > db/q.sql && git add -A )
  sf_run
}
# v2.153.2 — generated files are not what a reviewer reads: a path marked
# linguist-generated (git attributes) and the standard lockfiles leave the SOFT count.
sfg() { # $1 = 1 → gen/** is marked linguist-generated in .git/info/attributes (outside the diff)
  rm -rf "$SF_TMP"; mkdir -p "$SF_TMP/docs" "$SF_TMP/gen"
  ( cd "$SF_TMP" && git init -q . && git config user.email t@t && git config user.name t && mkdir -p .git/info \
    && { [ "$1" != 1 ] || printf 'gen/** linguist-generated\n' > .git/info/attributes; } \
    && seq 12 | sed 's/^/Line /' > docs/guide.md && seq 15 | sed 's/^/prompt = /' > gen/a.toml && cp gen/a.toml gen/b.toml && git add -A )
  sf_run
}
out=$(sfg 0)
if echo "$out" | grep -q '/ 30 logic' && echo "$out" | grep -q '0 reviewers on a logic diff'; then
  echo "  ✓ precommit SOFT: docs + two unmarked copies → 30 logic, reviewer ask (control)"
else echo "  ✗ precommit SOFT unmarked copies (control): ${out:0:200}"; fail=$((fail+1)); fi
out=$(sfg 1)
if echo "$out" | grep -q '/ 0 logic' && ! echo "$out" | grep -q '0 reviewers on a logic diff'; then
  echo "  ✓ precommit SOFT: docs + two linguist-generated copies → 0 logic, no reviewer ask"
else echo "  ✗ precommit SOFT linguist-generated copies: ${out:0:200}"; fail=$((fail+1)); fi
out=$(rm -rf "$SF_TMP"; mkdir -p "$SF_TMP"; cd "$SF_TMP" && git init -q . && git config user.email t@t && git config user.name t \
  && printf '{\n  "dependencies": {\n    "left-pad": "^1.3.0"\n  }\n}\n' > package.json && seq 40 | sed 's/^/    "resolved": /' > package-lock.json && git add -A && sf_run)
if echo "$out" | grep -q '2 files / 45 lines / 5 logic' && ! echo "$out" | grep -q '0 reviewers on a logic diff'; then
  echo "  ✓ precommit SOFT: a dependency add → the lockfile is not logic, the manifest edit is R1-shaped, no reviewer ask"
else echo "  ✗ precommit SOFT lockfile: ${out:0:200}"; fail=$((fail+1)); fi
out=$(sfq)
if echo "$out" | grep -q '3 files / 33 lines / 0 logic'; then
  echo "  ✓ precommit SOFT: quoted-path prose, a deleted prose file and a removed SQL comment → 0 logic"
else echo "  ✗ precommit SOFT quoted / deleted prose: ${out:0:200}"; fail=$((fail+1)); fi
rm -rf "$SF_TMP"

fi
# Unconditional: "route record" below reuses $RN_TMP, rn() and the
# .rolepod/evidence dir without building any of them itself — filtering
# ROLEPOD_CASE to that section alone used to leave $RN_TMP unbound (set -u
# abort, masked to exit 0 by the EXIT trap on bash 3.2 — the run silently
# stopped mid-file) and, once that was fixed, "$RN_TMP/.rolepod/evidence"
# missing (redirect into a non-existent dir, abort under set -e).
RN_TMP=$(mktemp -d); mkdir -p "$RN_TMP/.rolepod/evidence"; ( cd "$RN_TMP" && git init -q . && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init )
rn() { printf '{"session_id":"rn1","prompt":%s%s}' "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" "${2:+,\"transcript_path\":\"$2\"}" | (cd "$RN_TMP" && HOME="$RN_TMP" bash "$HOOKS/claim-verify-nudge.sh") || true; }
# ── route nudge (v2.98.0): commission + no fresh tier → one line ──────────
if section "route nudge (v2.98.0): commission + no fresh tier → one line"; then
out=$(rn 'fix the login button')
echo "$out" | grep -q 'commission with no tier' && echo "  ✓ route nudge: commission + no route line ever → nudge" || { echo "  ✗ route nudge missing: ${out:0:120}"; fail=$((fail+1)); }
out=$(rn 'why does login fail')
echo "$out" | grep -q 'commission with no tier' && { echo "  ✗ route nudge fired on a question with no commission verb"; fail=$((fail+1)); } || echo "  ✓ route nudge: analysis question → no route line (no commission verb)"
# v2.163.0 regression guard: a question that ALSO contains a bare commission
# verb (why does .. fail / how do .. remove / status of) used to be excluded
# by the removed read-first-nudge classifier before route_check even ran;
# that gate now lives internally in session_state._QUESTION_SHAPE_RX so
# route nudge's own behavior stays unchanged after that nudge was cut.
out=$(rn 'why does the build fail')
echo "$out" | grep -q 'commission with no tier' && { echo "  ✗ route nudge fired on a question containing a commission verb (build)"; fail=$((fail+1)); } || echo "  ✓ route nudge: question + commission verb (why does .. fail) → still silent"
out=$(rn 'how do we remove the dead code')
echo "$out" | grep -q 'commission with no tier' && { echo "  ✗ route nudge fired on a question containing a commission verb (remove)"; fail=$((fail+1)); } || echo "  ✓ route nudge: question + commission verb (how do .. remove) → still silent"
out=$(rn 'status of the deploy')
echo "$out" | grep -q 'commission with no tier' && { echo "  ✗ route nudge fired on a question containing a commission verb (deploy)"; fail=$((fail+1)); } || echo "  ✓ route nudge: question + commission verb (status of .. deploy) → still silent"
out=$(rn "$(python3 -c 'print("\u0e17\u0e33\u0e44\u0e21\u0e1b\u0e38\u0e48\u0e21 login \u0e1e\u0e31\u0e07\u0e2b\u0e25\u0e2d")')")
echo "$out" | grep -q 'commission with no tier' && { echo "  ✗ route nudge fired on a Thai question"; fail=$((fail+1)); } || echo "  ✓ route nudge: Thai question → silent"
out=$(rn "$(python3 -c 'print("\u0e42\u0e2d\u0e40\u0e04")')")
[ -z "$out" ] && echo "  ✓ route nudge: bare ack → silent" || { echo "  ✗ route nudge on a bare ack: ${out:0:80}"; fail=$((fail+1)); }
mkdir -p "$RN_TMP/.rolepod/evidence"; printf '{"ts":"%s","phase":"route","tier":"R2","skill":"implement-plan"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$RN_TMP/.rolepod/evidence/phase-log.jsonl"
out=$(rn "$(python3 -c 'print("\u0e41\u0e01\u0e49\u0e1b\u0e38\u0e48\u0e21 login \u0e43\u0e2b\u0e49\u0e2b\u0e19\u0e48\u0e2d\u0e22")')")
echo "$out" | grep -q 'commission with no tier' && { echo "  ✗ route nudge fired with a fresh route line"; fail=$((fail+1)); } || echo "  ✓ route nudge: fresh route line (no transcript, <30 min) → silent"
printf '{"ts":"2026-01-01T00:00:00Z","phase":"route","tier":"R2","skill":"implement-plan"}\n' > "$RN_TMP/.rolepod/evidence/phase-log.jsonl"
out=$(rn 'add a logout button')
echo "$out" | grep -q 'commission with no tier' && echo "  ✓ route nudge: stale route line (no transcript, >30 min) → nudge" || { echo "  ✗ route nudge missing on a stale route"; fail=$((fail+1)); }
T1=$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=90)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
TR=$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=60)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
printf '{"type":"user","timestamp":"%s","message":{"content":"earlier request"}}\n' "$T1" > "$RN_TMP/t.jsonl"
printf '{"ts":"%s","phase":"route","tier":"R3","skill":"write-spec"}\n' "$TR" > "$RN_TMP/.rolepod/evidence/phase-log.jsonl"
out=$(rn 'continue with the plan' "$RN_TMP/t.jsonl")
echo "$out" | grep -q 'commission with no tier' && { echo "  ✗ route nudge fired though the previous request was routed"; fail=$((fail+1)); } || echo "  ✓ route nudge: route line newer than the previous prompt → silent (age alone does not matter)"
printf '{"ts":"2026-01-01T00:00:00Z","phase":"route","tier":"R3","skill":"write-spec"}\n' > "$RN_TMP/.rolepod/evidence/phase-log.jsonl"
out=$(rn 'continue with the plan' "$RN_TMP/t.jsonl")
echo "$out" | grep -q 'commission with no tier' && echo "  ✓ route nudge: route older than the previous prompt → nudge" || { echo "  ✗ route nudge missing when the route predates the last prompt"; fail=$((fail+1)); }
out=$( (export ROLEPOD_NUDGE_OFF=1; rn 'fix the login button') )
[ -z "$out" ] && echo "  ✓ route nudge: ROLEPOD_NUDGE_OFF=1 → silent" || { echo "  ✗ route nudge ignores ROLEPOD_NUDGE_OFF"; fail=$((fail+1)); }
fi
# ── route record (v2.105.0): the hook writes the route line from the routing text ──
if section "route record (v2.105.0): the hook writes the route line from the routing text"; then
RLOG="$RN_TMP/.rolepod/evidence/phase-log.jsonl"; : > "$RLOG"
TU=$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=10)).strftime("%Y-%m-%dT%H:%M:%S.000Z"))')
TA=$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=9)).strftime("%Y-%m-%dT%H:%M:%S.000Z"))')
mk_transcript() { python3 - "$1" "$TU" "$TA" "$2" <<'PY'
import json, sys
p, tu, ta, txt = sys.argv[1:5]
rows = [{"type":"user","timestamp":tu,"message":{"role":"user","content":[{"type":"text","text":"fix the login button"}]}},
        {"type":"assistant","timestamp":ta,"message":{"role":"assistant","content":[{"type":"thinking","thinking":"x"},{"type":"text","text":txt}]}}]
open(p, "w").write("".join(json.dumps(r) + "\n" for r in rows))
PY
}
mk_transcript "$RN_TMP/t2.jsonl" "$(printf '\xe2\x86\x92 implement-plan \xc2\xb7 R2 \xc2\xb7 one handler, own test\n- [ ] baseline: npm test')"
out=$(rn 'add a logout button' "$RN_TMP/t2.jsonl")
if [ "$(grep -c '"phase":"route"' "$RLOG")" -eq 1 ] && grep -q '"tier":"R2","skill":"implement-plan","provenance":"hook-auto"' "$RLOG" && ! echo "$out" | grep -q 'commission with no tier'; then echo "  ✓ route record: R2 one-liner in the previous turn → one hook-auto route line, no nudge"; else echo "  ✗ route record R2: out=${out:0:80} log=$(cat "$RLOG")"; fail=$((fail+1)); fi
out=$(rn 'add a logout button' "$RN_TMP/t2.jsonl")
[ "$(grep -c '"phase":"route"' "$RLOG")" -eq 1 ] && echo "  ✓ route record: a second prompt on the same turn → no duplicate" || { echo "  ✗ route record duplicated: $(cat "$RLOG")"; fail=$((fail+1)); }
: > "$RLOG"
mk_transcript "$RN_TMP/t3.jsonl" 'Uploads go to the Cloudflare R2 bucket. The router tiers R0-R4; R3/R4 need a spec first.'
out=$(rn 'add a logout button' "$RN_TMP/t3.jsonl")
if [ ! -s "$RLOG" ] && echo "$out" | grep -q 'commission with no tier'; then echo "  ✓ route record: prose R2 + quoted R0-R4 / R3/R4 ranges → nothing recorded, nudge fires"; else echo "  ✗ route record false positive: log=$(cat "$RLOG") out=${out:0:60}"; fail=$((fail+1)); fi
: > "$RLOG"
mk_transcript "$RN_TMP/t4.jsonl" "$(printf 'Routing: Build \xe2\x86\x92 implement-plan\nTier: R3\nReason: three files\nNext step: plan')"
out=$(rn 'add a logout button' "$RN_TMP/t4.jsonl")
grep -q '"tier":"R3","skill":"implement-plan","provenance":"hook-auto"' "$RLOG" && echo "  ✓ route record: routing block (Tier: R3 + Routing: → skill) → R3 / implement-plan" || { echo "  ✗ route record block: $(cat "$RLOG")"; fail=$((fail+1)); }
: > "$RLOG"
mk_transcript "$RN_TMP/t5.jsonl" 'The router doc says to quote `Tier: R3` in the block when routing at that level.'
out=$(rn 'add a logout button' "$RN_TMP/t5.jsonl")
[ ! -s "$RLOG" ] && echo "  ✓ route record: Tier: quoted mid-sentence → nothing (only a line-start field or the marks count)" || { echo "  ✗ route record mid-sentence quote: $(cat "$RLOG")"; fail=$((fail+1)); }
: > "$RLOG"
mk_transcript "$RN_TMP/t6.jsonl" "$(printf '| D1 | 52 tables (APAC) \xc2\xb7 R2 \xc2\xb7 cron every 5 min |')"
out=$(rn 'add a logout button' "$RN_TMP/t6.jsonl")
[ ! -s "$RLOG" ] && echo "  ✓ route record: marked R2 mid-line (a table row, not a line-start arrow) → nothing" || { echo "  ✗ route record table row: $(cat "$RLOG")"; fail=$((fail+1)); }
: > "$RLOG"
python3 - "$RN_TMP/t7.jsonl" "$TA" <<'PY'
import json, sys
p, ta = sys.argv[1:3]
rows = [{"type":"user","message":{"role":"user","content":[{"type":"text","text":"fix the login button"}]}},
        {"type":"assistant","timestamp":ta,"message":{"role":"assistant","content":[{"type":"text","text":"\u2192 implement-plan \u00b7 R2 \u00b7 one handler"}]}}]
open(p, "w").write("".join(json.dumps(r) + "\n" for r in rows))
PY
out=$(rn 'add a logout button' "$RN_TMP/t7.jsonl")
grep -q '"tier":"R2"' "$RLOG" && echo "  ✓ route record: user prompt with no timestamp → still the turn boundary, R2 recorded" || { echo "  ✗ route record missing-timestamp boundary: $(cat "$RLOG")"; fail=$((fail+1)); }
: > "$RLOG"
mk_transcript "$RN_TMP/t8.jsonl" "$(printf '**Route: R2 \xe2\x80\x94 same task** (docs only, no code)')"
out=$(rn 'add a logout button' "$RN_TMP/t8.jsonl")
grep -q '"tier":"R2","skill":"","provenance":"hook-auto"' "$RLOG" && echo "  ✓ route record: the measured real form **Route: R2 — reason** → R2 recorded" || { echo "  ✗ route record field form: $(cat "$RLOG")"; fail=$((fail+1)); }
: > "$RLOG"
mk_transcript "$RN_TMP/t9.jsonl" "$(printf 'The block looks like this:\n```\nTier: R3\nRouting: Build \xe2\x86\x92 implement-plan\n```\nfill it in.')"
out=$(rn 'add a logout button' "$RN_TMP/t9.jsonl")
[ ! -s "$RLOG" ] && echo "  ✓ route record: a routing block quoted inside a code fence → nothing" || { echo "  ✗ route record fenced quote: $(cat "$RLOG")"; fail=$((fail+1)); }
: > "$RLOG"
mk_transcript "$RN_TMP/t10.jsonl" "$(printf 'Route: R2 \xe2\x86\x92 <skill> \xc2\xb7 <reason>')"
out=$(rn 'add a logout button' "$RN_TMP/t10.jsonl")
[ ! -s "$RLOG" ] && echo "  ✓ route record: the template with <skill> / <reason> placeholders → nothing" || { echo "  ✗ route record placeholder: $(cat "$RLOG")"; fail=$((fail+1)); }
: > "$RLOG"
mk_transcript "$RN_TMP/t11.jsonl" "$(printf 'Route: R2 (one file + test) \xe2\x86\x92 implement-plan \xc2\xb7 one handler')"
out=$(rn 'add a logout button' "$RN_TMP/t11.jsonl")
grep -q '"tier":"R2","skill":"implement-plan","provenance":"hook-auto"' "$RLOG" && echo "  ✓ route record: the glossed form Route: R2 (one file + test) → skill · reason → R2 / implement-plan" || { echo "  ✗ route record glossed form: $(cat "$RLOG")"; fail=$((fail+1)); }
: > "$RLOG"
mk_transcript "$RN_TMP/t12.jsonl" 'Fill the block:
Tier: R3 (multi-file) | R4 (high-risk)
Routing: <phase> -> <skill>'
out=$(rn 'add a logout button' "$RN_TMP/t12.jsonl")
[ ! -s "$RLOG" ] && echo "  ✓ route record: the glossed block template Tier: R3 (multi-file) | R4 (high-risk) echoed verbatim → nothing" || { echo "  ✗ route record glossed template: $(cat "$RLOG")"; fail=$((fail+1)); }
: > "$RLOG"
printf '{"session_id":"rn1","transcript_path":"%s","cwd":"%s"}' "$RN_TMP/t2.jsonl" "$RN_TMP" | (cd "$RN_TMP" && HOME="$RN_TMP" bash "$HOOKS/session-lifecycle.sh" --unlock) >/dev/null 2>&1 || true
grep -q '"tier":"R2"' "$RLOG" && echo "  ✓ route record: Stop hook (session-lifecycle --unlock) records the finished turn" || { echo "  ✗ route record at Stop: $(cat "$RLOG" 2>/dev/null)"; fail=$((fail+1)); }
rm -rf "$RN_TMP"

fi
# RH + its helpers are an unconditional fixture (not gated behind this
# section): "acceptance 2" further below reuses $RH/rh_agent/rh_log, and
# "producer→reader→gate chain" reuses rh_ts — with set -euo a gated
# definition left them unbound/undefined when only one of those later
# sections was selected, aborting the run instead of failing a check.
RH=$(mktemp -d); mkdir -p "$RH/.rolepod/evidence"
rh_ts() { python3 -c "import datetime,sys;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$1"; }
rh_log() { printf '{"ts": "%s", "phase": "dispatch", "cli": "claude", "tool": "Agent", "agent_type": "%s"}\n' "$(rh_ts "$1")" "$2" >> "$RH/.rolepod/evidence/phase-log.jsonl"; }
rh_agent() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":"%s","prompt":"review the diff"},"session_id":"rh1","transcript_path":"/nonexistent"}' "$1" | (cd "$RH" && HOME="$RH" bash "$HOOKS/workflow-tier-nudge.sh") || true; }
rh_prompt() { printf '{"session_id":"rh1","prompt":%s}' "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" | (cd "$RH" && HOME="$RH" bash "$HOOKS/claim-verify-nudge.sh") || true; }
# $RH must be a git repo unconditionally too: cross-family.sh's `git status
# --porcelain` on a non-repo exits non-zero with EMPTY stdout (no exception),
# which review_rounds() reads as `clean` and zeroes every round — "acceptance
# 2" below would silently pass a clean-tree short-circuit instead of
# actually counting, whether or not this section ran first.
( cd "$RH" && git init -q . && git config user.email t@t && git config user.name t && printf 'a\n' > f.txt && git add f.txt && GIT_COMMITTER_DATE="$(rh_ts 90)" git commit -q -m init --date="$(rh_ts 90)" && printf 'b\n' > f.txt )
# ── review-rounds policy on internal reviewer dispatch + breaker reminder (v2.99.0) ──
if section "review-rounds policy on internal reviewer dispatch + breaker reminder (v2.99.0)"; then
: > "$RH/.rolepod/evidence/phase-log.jsonl"; rh_log 40 rolepod:security-engineer; rh_log 25 rolepod:security-engineer
out=$(rh_agent rolepod:security-engineer)
if echo "$out" | grep -q 'review-rounds' && ! echo "$out" | grep -q '"permissionDecision": *"deny"'; then echo "  ✓ tier-nudge: reviewer dispatch at round 3 → breaker notice, not a deny"; else echo "  ✗ tier-nudge round 3: ${out:0:160}"; fail=$((fail+1)); fi
out=$(rh_agent rolepod:backend-developer)
if echo "$out" | grep -q 'review-rounds'; then echo "  ✗ tier-nudge: non-reviewer dispatch got the round note"; fail=$((fail+1)); else echo "  ✓ tier-nudge: non-reviewer dispatch → no round note"; fi
# v2.154.0 — rounds per reviewer: security-engineer's own key, not a mix with
# qa-tester (a different reviewer no longer inflates this one's round).
: > "$RH/.rolepod/evidence/phase-log.jsonl"; rh_log 40 rolepod:security-engineer; rh_log 25 rolepod:security-engineer; rh_log 13 rolepod:security-engineer
out=$(rh_agent rolepod:security-engineer)
check "tier-nudge: round 4 with no breaker ledger → deny" deny "$out"
out=$(rh_prompt 'I hit my usage limit while you were working, but it has reset now. Please continue from where you left off.')
if echo "$out" | grep -q 'review-rounds: 3 rounds'; then echo "  ✓ claim-verify: 3 rounds + no ledger → asks for the ledger before anything else"; else echo "  ✗ claim-verify rounds reminder: ${out:0:160}"; fail=$((fail+1)); fi
mkdir -p "$RH/docs/rolepod/handoffs"; printf '# y\n\n## Rounds\n- r1\n\n## Class\n- one predicate\n\n## Decision\n- a\n' > "$RH/docs/rolepod/handoffs/y-breaker-2026-09-08.md"
out=$(rh_agent rolepod:security-engineer)
check "tier-nudge: round 4 with a class ledger → allow" allow "$out"
out=$(rh_prompt 'Please continue from where you left off.')
if echo "$out" | grep -q 'breaker open'; then echo "  ✓ claim-verify: breaker ledger open → auto-resume prompt gets the stop reminder"; else echo "  ✗ claim-verify breaker-open reminder: ${out:0:160}"; fail=$((fail+1)); fi
rh_log 7 rolepod:security-engineer
out=$(rh_agent rolepod:security-engineer)
check "tier-nudge: round 5 even with the ledger → deny (terminal)" deny "$out"
out=$( (export ROLEPOD_GATES_SOFT=1; rh_agent rolepod:security-engineer) )
check "tier-nudge: ROLEPOD_GATES_SOFT=1 lifts the round deny" allow "$out"

fi
# v2.154.0 — rounds per reviewer: acceptance 2 (a churning reviewer never
# blocks a different one) and acceptance 7 (the terminal names the reopen)
if section "v2.154.0 — rounds per reviewer: acceptance 2/7"; then
: > "$RH/.rolepod/evidence/phase-log.jsonl"
rh_log 55 rolepod:security-engineer; rh_log 44 rolepod:security-engineer; rh_log 33 rolepod:security-engineer; rh_log 22 rolepod:security-engineer; rh_log 11 rolepod:security-engineer
out=$(rh_agent rolepod:security-engineer)
check "acceptance 2: the SAME reviewer's 6th dispatch on one uncommitted tree → deny (terminal)" deny "$out"
if echo "$out" | grep -q "next typed prompt re-opens the window"; then echo "  ✓ acceptance 7: the terminal deny names the next typed prompt as the way out"; else echo "  ✗ acceptance 7: terminal text missing the reopen sentence: ${out:0:200}"; fail=$((fail+1)); fi
out=$(rh_agent rolepod:qa-tester)
check "acceptance 2: a DIFFERENT reviewer's first dispatch on the same tree → allow (its own round is 1)" allow "$out"
# dispatch-auto-log.sh's Agent/Task branch writes line["name"] (v2.156.0:
# `ti.get("name") or "?"`, matching workflow-tier-nudge.sh's own dname read
# with no description fallback), so a real Agent dispatch leaves a "name" a
# later --role named lookup can find. The fixture below still proves the
# reader (review_rounds()'s "named" bucket) in isolation; the block further
# down chains the REAL producer into the REAL reader end to end.
rh_log_named() { printf '{"ts": "%s", "phase": "dispatch", "cli": "claude", "tool": "Agent", "name": "%s"}\n' "$(rh_ts "$1")" "$2" >> "$RH/.rolepod/evidence/phase-log.jsonl"; }
rh_named() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","name":"%s","prompt":"look at the diff"},"session_id":"rh1","transcript_path":"/nonexistent"}' "$1" | (cd "$RH" && HOME="$RH" bash "$HOOKS/workflow-tier-nudge.sh") || true; }
: > "$RH/.rolepod/evidence/phase-log.jsonl"
rh_log_named 55 review-pass-a; rh_log_named 44 review-pass-b; rh_log_named 33 review-pass-c; rh_log_named 22 review-pass-d; rh_log_named 11 review-pass-e
out=$(rh_named "review-pass-f")
check "R1 'named': 5 review-shaped dispatch NAMES with no role match, then a 6th → deny (its own key, independent of the role table)" deny "$out"
rm -rf "$RH"

fi
# ── producer→reader→gate chain end to end (v2.156.0): dispatch-auto-log.sh
if section "producer→reader→gate chain end to end (v2.156.0): dispatch-auto-log.sh"; then
# (the REAL producer) writes a role-less Agent dispatch's name to the
# phase-log. Two separate assertions cover the chain: `rounds=1` below
# proves producer→reader (cross-family.sh --rounds --role named counts the
# real write); the deny further down proves reader→gate (workflow-tier-
# nudge.sh denies once the round-breaker budget is spent) — no fixture
# standing in for either half. ─────────────────────────────────────────
DAL_TMP=$(mktemp -d); ( cd "$DAL_TMP" && git init -q . && git config user.email t@t && git config user.name t && printf 'a\n' > f.txt && git add f.txt && GIT_COMMITTER_DATE="$(rh_ts 90)" git commit -q -m init --date="$(rh_ts 90)" && printf 'b\n' > f.txt )
mkdir -p "$DAL_TMP/.rolepod/evidence"
dal_dispatch() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","name":"%s","prompt":"look at the diff"},"session_id":"dal1","transcript_path":"/nonexistent"}' "$1" | (cd "$DAL_TMP" && HOME="$DAL_TMP" bash "$HOOKS/dispatch-auto-log.sh" >/dev/null 2>&1 || true); }
dal_gate() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","name":"%s","prompt":"look at the diff"},"session_id":"dal1","transcript_path":"/nonexistent"}' "$1" | (cd "$DAL_TMP" && HOME="$DAL_TMP" bash "$HOOKS/workflow-tier-nudge.sh") || true; }
dal_dispatch "review-x"
out=$(cd "$DAL_TMP" && bash "$REPO_DIR/scripts/cross-family.sh" --rounds --role named)
if echo "$out" | grep -q "rounds=1 current=1"; then echo "  ✓ dispatch-auto-log→review_rounds: one real named dispatch reads back as round 1"; else echo "  ✗ dispatch-auto-log→review_rounds: expected rounds=1 current=1, got: $out"; fail=$((fail+1)); fi
dal_log_named() { printf '{"ts": "%s", "phase": "dispatch", "cli": "claude", "tool": "Agent", "name": "%s"}\n' "$(rh_ts "$1")" "$2" >> "$DAL_TMP/.rolepod/evidence/phase-log.jsonl"; }
dal_log_named 55 review-pass-a; dal_log_named 44 review-pass-b; dal_log_named 33 review-pass-c; dal_log_named 22 review-pass-d
out=$(dal_gate "review-pass-f")
check "producer→reader→gate: 4 backdated named rounds + 1 REAL producer-logged dispatch → the live gate denies the 6th" deny "$out"
rm -rf "$DAL_TMP"

fi
# ── auto-resume prompt (v2.100.0): a resume, not a decision; no route nudge ──
if section "auto-resume prompt (v2.100.0): a resume, not a decision; no route nudge"; then
AR_TMP=$(mktemp -d); ( cd "$AR_TMP" && git init -q . && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init )
out=$(printf '{"session_id":"ar1","prompt":"I hit my usage limit while you were working, but it has reset now. Please continue from where you left off."}' | (cd "$AR_TMP" && HOME="$AR_TMP" bash "$HOOKS/claim-verify-nudge.sh") || true)
if echo "$out" | grep -q 'auto-resume' && ! echo "$out" | grep -q 'commission with no tier'; then echo "  ✓ claim-verify: auto-resume prompt → resume line, no route nudge"; else echo "  ✗ claim-verify auto-resume: ${out:0:200}"; fail=$((fail+1)); fi
out=$(printf '{"session_id":"ar1","prompt":"continue with the plan"}' | (cd "$AR_TMP" && HOME="$AR_TMP" bash "$HOOKS/claim-verify-nudge.sh") || true)
if echo "$out" | grep -q 'auto-resume'; then echo "  ✗ claim-verify: a normal continue got the auto-resume line"; fail=$((fail+1)); else echo "  ✓ claim-verify: a user's own 'continue' → no auto-resume line"; fi
rm -rf "$AR_TMP"

fi
# ── last-prompt stamp (v2.128.0): only a prompt the user typed moves the review-rounds window ──
if section "last-prompt stamp (v2.128.0): only a prompt the user typed moves the review-rounds window"; then
ST_TMP=$(mktemp -d); ( cd "$ST_TMP" && git init -q . && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init )
st() { printf '{"session_id":"st1","prompt":%s}' "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" | (cd "$ST_TMP" && HOME="$ST_TMP" bash "$HOOKS/claim-verify-nudge.sh" >/dev/null 2>&1 || true); }
STAMP="$ST_TMP/.rolepod/evidence/last-prompt"
st "fix the login bug"
if [ -f "$STAMP" ] && [ $(( $(date +%s) - $(cat "$STAMP") )) -le 5 ]; then echo "  ✓ claim-verify: a typed prompt stamps .rolepod/evidence/last-prompt (now)"; else echo "  ✗ claim-verify: typed prompt did not stamp last-prompt"; fail=$((fail+1)); fi
printf '1000\n' > "$STAMP"
st "I hit my usage limit while you were working, but it has reset now. Please continue from where you left off."
[ "$(cat "$STAMP")" = "1000" ] && echo "  ✓ claim-verify: auto-resume prompt does NOT move the stamp" || { echo "  ✗ claim-verify: auto-resume moved the stamp"; fail=$((fail+1)); }
st "This session is being continued from a previous conversation that ran out of context. The summary below covers the earlier portion."
[ "$(cat "$STAMP")" = "1000" ] && echo "  ✓ claim-verify: compaction summary does NOT move the stamp" || { echo "  ✗ claim-verify: compaction summary moved the stamp"; fail=$((fail+1)); }
st "<task-notification><task-id>x</task-id></task-notification>"
[ "$(cat "$STAMP")" = "1000" ] && echo "  ✓ claim-verify: a system block does NOT move the stamp" || { echo "  ✗ claim-verify: system block moved the stamp"; fail=$((fail+1)); }
rm -rf "$ST_TMP"

fi
# ── project-context-loader: session-start state pointers (v2.102.0) ────────
if section "project-context-loader: session-start state pointers (v2.102.0)"; then
PC_TMP=$(mktemp -d); ( cd "$PC_TMP" && git init -q . && git config user.email t@t && git config user.name t && printf 'a\n' > f.txt && git add f.txt && git commit -qm init )
mkdir -p "$PC_TMP/docs/rolepod/plans" "$PC_TMP/.rolepod/evidence"
printf '# Plan\n\n### Task 1: seed\n- [x] **Change:** done\n\n### Task 2: wire the gate\n- [ ] **Change:** todo\n- [ ] **Test / evidence:** todo\n' > "$PC_TMP/docs/rolepod/plans/x-2026-09-08.md"
printf '{"ts":"2026-09-08T01:00:00Z","phase":"route","tier":"R3","skill":"write-plan"}\n' > "$PC_TMP/.rolepod/evidence/phase-log.jsonl"
pcl() { printf '{"cwd":"%s","session_id":"pc1"}' "$PC_TMP" | (cd "$PC_TMP" && HOME="$PC_TMP" bash "$HOOKS/project-context-loader.sh") || true; }
out=$(pcl)
if echo "$out" | grep -q 'Open plan:' && echo "$out" | grep -q 'next: Task 2: wire the gate' && echo "$out" | grep -q '1 done / 2 open' && echo "$out" | grep -q 'Last phase' && echo "$out" | grep -q 'route 2026-09-08T01:00'; then
  echo "  ✓ context-loader: open plan + next task + last phase at session start"
else echo "  ✗ context-loader state pointers: ${out:0:300}"; fail=$((fail+1)); fi
mkdir -p "$PC_TMP/docs/rolepod/handoffs"; printf '# b\n\n## Rounds\n- r\n\n## Class\n- c\n\n## Decision\n- d\n' > "$PC_TMP/docs/rolepod/handoffs/x-breaker-2026-09-08.md"
out=$(pcl)
if echo "$out" | grep -q 'Breaker ledger open'; then echo "  ✓ context-loader: open breaker ledger named at session start"; else echo "  ✗ context-loader breaker pointer: ${out:0:200}"; fail=$((fail+1)); fi
rm -rf "$PC_TMP"

fi
# ── precommit: nested reviewer dispatch counts (v2.144.0) ──────────────────
if section "precommit: nested reviewer dispatch counts (v2.144.0)"; then
# session_state.count_all already discovers ONE level of nesting (a runner
# subagent's own Agent-tool call to a reviewer is a tool_use in the
# RUNNER's own transcript, which sits directly under the Lead's
# subagents/ dir and gets walked) — the real gap is that walk's cap at the
# 60 newest subagent-transcript files in the window, which a big fleet can
# exceed. dispatch-auto-log.sh writes a "dispatch" row to the SAME
# phase-log for every Agent/Task/Workflow call in ANY session, uncapped, so
# the commit gate reads it as a backstop too — MAX with the transcript
# scan, never a sum. Hardened: only "hook-auto"-provenance rows count, and
# a STRONG row with a named low-class model (an explicit downgrade) drops
# to a plain reviewer, not a strong one.
NR_TMP=$(mktemp -d)
nr_ts() { python3 -c "import datetime,sys;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$1"; }
( cd "$NR_TMP" && git init -q . && git config user.email t@t && git config user.name t \
  && mkdir -p auth && printf 'def charge(u):\n    return u.balance - 1\n' > auth/billing.py \
  && git add auth/billing.py \
  && GIT_COMMITTER_DATE="$(nr_ts 60)" git commit -q -m init --date="$(nr_ts 60)" \
  && printf 'def charge(u):\n    return u.balance - 2\n' > auth/billing.py && git add auth/billing.py )
mkdir -p "$NR_TMP/.rolepod/evidence"
NR_EMPTY_T="$NR_TMP/empty.jsonl"; : > "$NR_EMPTY_T"
nr_log() { printf '{"ts":"%s","phase":"dispatch","cli":"claude","tool":"Agent","agent_type":"%s","model":"%s","provenance":"hook-auto"}\n' "$(nr_ts "$1")" "$2" "${3:-opus}" > "$NR_TMP/.rolepod/evidence/phase-log.jsonl"; }
nr() { # $1 = transcript path
  printf '{"tool_name":"Bash","transcript_path":%s,"tool_input":{"command":"git commit -m x"}}' \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | (cd "$NR_TMP" && HOME="$NR_TMP" bash "$HOOKS/precommit-gate.sh") || true
}
nr_log 5 rolepod:security-engineer
out=$(nr "$NR_EMPTY_T")
check "precommit: nested phase-log dispatch row for security-engineer, no transcript reviewer → allow" allow "$out"
echo "$out" | grep -q '1 reviewer dispatches / 1 strong' \
  && echo "  ✓ nested dispatch row counted (1 reviewer / 1 strong)" \
  || { echo "  ✗ nested dispatch row not reflected in auto-pass note: ${out:0:200}"; fail=$((fail+1)); }

nr_log 5 rolepod:scout haiku
out=$(nr "$NR_EMPTY_T")
check "precommit: nested phase-log row is a scout, not a reviewer → deny" deny "$out"

nr_log 90 rolepod:security-engineer
out=$(nr "$NR_EMPTY_T")
check "precommit: nested phase-log row timestamped BEFORE the last commit → deny (windowed)" deny "$out"

nr_log 5 rolepod:security-engineer
NR_T2="$NR_TMP/t2.jsonl"
printf '%s\n' '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' > "$NR_T2"
out=$(nr "$NR_T2")
check "precommit: transcript reviewer + phase-log row for the SAME role → allow" allow "$out"
echo "$out" | grep -q '1 reviewer dispatches / 1 strong' \
  && echo "  ✓ max, not sum: 1 transcript reviewer + 1 phase-log row → count stays 1" \
  || { echo "  ✗ transcript + phase-log row double-counted: ${out:0:200}"; fail=$((fail+1)); }

# A named low-model downgrade of a strong reviewer must not clear a
# high-risk commit through the nested-dispatch backstop (round-1 security
# finding: the phase-log path re-admitted exactly the downgrade
# session_state.count_all already refuses).
printf '{"ts":"%s","phase":"dispatch","cli":"claude","tool":"Agent","agent_type":"rolepod:security-engineer","model":"haiku","provenance":"hook-auto","floor":"missed"}\n' "$(nr_ts 5)" > "$NR_TMP/.rolepod/evidence/phase-log.jsonl"
out=$(nr "$NR_EMPTY_T")
check "precommit: nested row is security-engineer but explicit model:haiku (named downgrade) → deny (not strong)" deny "$out"

# A forged row with no provenance field (a bare printf, not the real hook)
# must not count — the shipped test above used exactly this shape before
# the provenance requirement was added.
printf '{"ts":"%s","phase":"dispatch","cli":"claude","tool":"Agent","agent_type":"rolepod:security-engineer","model":"opus"}\n' "$(nr_ts 5)" > "$NR_TMP/.rolepod/evidence/phase-log.jsonl"
out=$(nr "$NR_EMPTY_T")
check "precommit: nested row with NO provenance field (bare forgery) → deny" deny "$out"
rm -rf "$NR_TMP"

fi
# ── cohesion-contract-check removed v2.164.0 (write-plan carries the contract step) ──
if section "cohesion-contract-check removed v2.164.0"; then
[ ! -e "$HOOKS/cohesion-contract-check.sh" ] \
  && echo "  ✓ hooks/cohesion-contract-check.sh no longer ships" \
  || { echo "  ✗ hooks/cohesion-contract-check.sh still present"; fail=$((fail+1)); }
fi

# ─── session-lifecycle: the Codex Stop entry, run as written ───
# 2026-09-22 (found by the rolepod-brain session on codex 0.153 / 0.155): the
# adapter's Stop entry ran session-lifecycle.sh with no mode, so it re-LOCKED at
# Stop and printed a SessionStart-shaped hookSpecificOutput; Codex's Stop schema
# rejects unknown fields → `hook: Stop Failed` every turn, lock never released.
# The entry is executed exactly as the adapter writes it (PLUGIN_ROOT = repo).
if section "session-lifecycle: Codex Stop entry unlocks and prints nothing"; then
SL_HOME="$SANDBOX_CWD/.sl-home"; mkdir -p "$SL_HOME"
SL_PAYLOAD=$(printf '{"session_id":"sl-test-1","cwd":%s,"hook_event_name":"Stop"}' \
  "$(printf '%s' "$SANDBOX_CWD" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')")
printf '%s' "$SL_PAYLOAD" | HOME="$SL_HOME" bash "$HOOKS/session-lifecycle.sh" --lock >/dev/null 2>&1 || true
SL_LOCK=$(find "$SL_HOME/.rolepod/session-locks" -name 'sl-test-1.lock' 2>/dev/null | head -1)
if [ -n "$SL_LOCK" ]; then echo "  ✓ SessionStart (--lock) registered the session lock"; else echo "  ✗ --lock wrote no lock under the test HOME"; fail=$((fail+1)); fi
# A live sibling is what made the lock-mode Stop print (the real Codex symptom).
[ -n "$SL_LOCK" ] && touch "$(dirname "$SL_LOCK")/sl-sibling.lock"
SL_STOP_CMD=$(python3 -c "import json;d=json.load(open('$REPO_DIR/adapters/codex/plugins/rolepod/hooks/hooks.json'));print([h['command'] for g in d['hooks']['Stop'] for h in g['hooks'] if 'session-lifecycle' in h['command']][0])")
out=$(printf '%s' "$SL_PAYLOAD" | HOME="$SL_HOME" PLUGIN_ROOT="$REPO_DIR" bash -c "$SL_STOP_CMD" 2>/dev/null || true)
if [ -z "$out" ]; then echo "  ✓ Codex Stop entry prints nothing (the Stop schema accepts no hookSpecificOutput)"; else echo "  ✗ Codex Stop entry printed: $out"; fail=$((fail+1)); fi
if [ -n "$SL_LOCK" ] && [ ! -e "$SL_LOCK" ]; then echo "  ✓ Codex Stop entry released the session lock"; else echo "  ✗ the session lock survived the Codex Stop entry (ran in lock mode?)"; fail=$((fail+1)); fi
fi

# ─── the real edit ledger stayed untouched ───
if section "the real edit ledger stayed untouched"; then
SANDBOX_LEDGER="$SANDBOX_CWD/.rolepod/evidence/edits.jsonl"
SANDBOX_ROWS=$([ -f "$SANDBOX_LEDGER" ] && wc -l < "$SANDBOX_LEDGER" | tr -d ' ' || echo 0)
if [ "$SANDBOX_ROWS" -gt 0 ]; then
  echo "  ✓ hooks called without a cwd wrote their ledger rows to the fixture repo ($SANDBOX_ROWS) — still evaluated, not skipped"
else
  echo "  ✗ the fixture repo's ledger is empty — hooks called without a cwd no longer evaluate edits"
  fail=$((fail+1))
fi
cd "$REPO_DIR" && rm -rf "$SANDBOX_CWD"
fi
# Unconditional: this guard must run on every invocation, even when
# ROLEPOD_CASE filters out every section including this one's own banner —
# a leaked fixture row into the real repo's ledger must never go unnoticed
# just because a different section was the one being targeted.
LEDGER_ROWS_AFTER=$(ledger_rows)
if [ "$LEDGER_ROWS_AFTER" = "$LEDGER_ROWS_BEFORE" ]; then
  echo "  ✓ no fixture row leaked into the real repo's edit ledger"
else
  echo "  ✗ the real repo's edit ledger grew $LEDGER_ROWS_BEFORE → $LEDGER_ROWS_AFTER rows during this run (a hook ran with the real repo as cwd)"
  fail=$((fail+1))
fi

echo "  · $RAN_SECTIONS of $TOTAL_SECTIONS sections ran"
# ─── result ───
if [ "$fail" -eq 0 ]; then
  echo "  ✓ pass"
  exit 0
else
  echo "  ✗ fail ($fail behavioral assertions failed)"
  exit 1
fi
