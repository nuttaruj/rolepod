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

# ── precommit-gate: high-risk staged diff blocks; claim-bypass ignored ──
TMP=$(mktemp -d)
TMPT=""
trap 'rm -rf "$TMP" ${TMPT:+"$TMPT"}' EXIT
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

# ── precommit-gate: a test-ONLY diff on a risk-named path is not R4 code (v2.85.2) ──
# Filename convention only — bare directory segments would downgrade
# api/specs/auth.yaml and tests/fixtures/seed_auth_users.py (cases c, d).
TMPT=$(mktemp -d)
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

# ── reuse-ladder nudge at first touch / new file / manifest (v2.109.0) ──
WG_TMP=$(mktemp -d); ( cd "$WG_TMP" && git init -q . && mkdir -p src docs && printf 'x\n' > src/a.ts && printf '{}\n' > package.json && printf '# r\n' > docs/r.md )
wg() { printf '{"session_id":"wg1","cwd":"%s","tool_name":"%s","tool_input":{"file_path":"%s"}}' "$WG_TMP" "$1" "$WG_TMP/$2" | (cd "$WG_TMP" && HOME="$WG_TMP" bash "$HOOKS/worktree-guard.sh") || true; }
out=$(wg Edit src/a.ts)
echo "$out" | grep -q 'first touch of a.ts' && echo "  ✓ reuse nudge: first edit of a code file this session → one ladder line" || { echo "  ✗ reuse nudge first touch: ${out:0:100}"; fail=$((fail+1)); }
out=$(wg Edit src/a.ts)
[ -z "$out" ] && echo "  ✓ reuse nudge: second edit of the same file → silent" || { echo "  ✗ reuse nudge repeated: ${out:0:80}"; fail=$((fail+1)); }
out=$(wg Write src/b.ts)
echo "$out" | grep -q 'new file b.ts' && echo "  ✓ reuse nudge: Write of a file that does not exist → new-file wording" || { echo "  ✗ reuse nudge new file: ${out:0:100}"; fail=$((fail+1)); }
out=$(wg Edit package.json); out2=$(wg Edit package.json)
echo "$out" | grep -q 'dependency manifest package.json' && echo "$out2" | grep -q 'dependency manifest' && echo "  ✓ reuse nudge: dependency manifest → last-rung wording on every edit" || { echo "  ✗ reuse nudge manifest: ${out:0:80} / ${out2:0:40}"; fail=$((fail+1)); }
out=$(wg Edit docs/r.md)
[ -z "$out" ] && echo "  ✓ reuse nudge: docs path → silent" || { echo "  ✗ reuse nudge on docs: ${out:0:80}"; fail=$((fail+1)); }
out=$( (export ROLEPOD_NUDGE_OFF=1; wg Edit src/c.ts) )
[ -z "$out" ] && echo "  ✓ reuse nudge: ROLEPOD_NUDGE_OFF=1 → silent" || { echo "  ✗ reuse nudge ignores NUDGE_OFF: ${out:0:80}"; fail=$((fail+1)); }
printf 'y\n' > "$WG_TMP/src/d.ts"; out=$(wg Write src/d.ts)
echo "$out" | grep -q 'first touch of d.ts' && ! echo "$out" | grep -q 'new file' && echo "  ✓ reuse nudge: Write to an EXISTING file → first-touch wording, not new-file" || { echo "  ✗ reuse nudge Write existing: ${out:0:100}"; fail=$((fail+1)); }
out=$(wg MultiEdit src/e.ts)
echo "$out" | grep -q 'first touch of e.ts' && echo "  ✓ reuse nudge: MultiEdit payload → fires like Edit" || { echo "  ✗ reuse nudge MultiEdit: ${out:0:100}"; fail=$((fail+1)); }
printf '{}\n' > "$WG_TMP/package-lock.json"; out=$(wg Edit package-lock.json)
[ -z "$out" ] && echo "  ✓ reuse nudge: package-lock.json is a lockfile, not a manifest → silent" || { echo "  ✗ reuse nudge lockfile: ${out:0:80}"; fail=$((fail+1)); }
rm -rf "$WG_TMP"

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
check "money/auth fixture + enabled pool + external anchor ONLY, no internal reviewer → deny (this surface needs BOTH — v2.78.0)" deny "$out"
echo "$out" | grep -q 'needs BOTH' \
  && echo "  ✓ deny reason says the money/auth surface needs both passes" \
  || { echo "  ✗ money/auth deny reason missing BOTH wording"; fail=$((fail+1)); }
printf '%s\n' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' \
  > "$TRANSCRIPT"
out=$(pcx 'git commit -m "add billing"')
check "money/auth fixture + external anchor + internal strong reviewer → allow (both present)" allow "$out"
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

# ── running detached job named in the hold (v2.79.0) ────────────────────
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

# ── money / auth vs other high-risk (v2.78.0) ──────────────────────────
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

# ── private working docs never commit (v2.80.0) ─────────────────────────
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

# ── project-context-loader: opt-in question asked ONCE per machine ──────
XF_HOME="$TMP/xfhome"; rm -rf "$XF_HOME"; mkdir -p "$XF_HOME"
XF_REPO="$TMP/xfrepo"; mkdir -p "$XF_REPO"; git -C "$XF_REPO" init -q; git -C "$XF_REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init  # loader needs ≥1 commit
pcl() { printf '{"cwd":%s}' "$(printf '%s' "$XF_REPO" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
  | (cd "$XF_REPO" && env HOME="$XF_HOME" PATH="$XF_BIN:/usr/bin:/bin" CLAUDE_PLUGIN_ROOT="$TMP" bash "$HOOKS/project-context-loader.sh") || true; }
out=$(pcl)
echo "$out" | grep -q 'Cross-family reviewers are OFF (opt-in)' && echo "$out" | grep -q 'codex(openai)' && echo "$out" | grep -q 'ASK THE USER ONCE' \
  && echo "  ✓ loader asks the opt-in question with the installed candidates when no config exists" \
  || { echo "  ✗ loader did not ask the cross-family opt-in question"; fail=$((fail+1)); }
[ -f "$XF_HOME/.rolepod/cross-family.asked" ] \
  && echo "  ✓ loader drops the asked-marker" \
  || { echo "  ✗ asked-marker missing"; fail=$((fail+1)); }
out=$(pcl)
echo "$out" | grep -q 'ASK THE USER ONCE' \
  && { echo "  ✗ loader asked again in a later session (marker ignored)"; fail=$((fail+1)); } \
  || echo "  ✓ loader does not ask twice"
rm -f "$XF_HOME/.rolepod/cross-family.asked"; printf 'none\n' > "$XF_HOME/.rolepod/cross-family"
out=$(pcl)
echo "$out" | grep -q 'ASK THE USER ONCE' \
  && { echo "  ✗ loader asked although the user already answered (none)"; fail=$((fail+1)); } \
  || echo "  ✓ an answered config (none) silences the question"

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

# ── precommit: evidence window = since the last commit (v2.47.0) ────────
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

# ─── fix-loop-breaker: count fails mechanically, reset on pass ────────
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

# ── review in flight (v2.93.0): a live detached cross-family job freezes the diff ──
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

# ── precommit SOFT line names the reviewer count (v2.95.0) ────────────────
SF_TMP=$(mktemp -d)
sf() { # $1 file, $2 content-generator command
  rm -rf "$SF_TMP"; mkdir -p "$SF_TMP/$(dirname "$1")"
  ( cd "$SF_TMP" && git init -q . && git config user.email t@t && git config user.name t && eval "$2" > "$1" && git add -A )
  printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | (cd "$SF_TMP" && bash "$HOOKS/precommit-gate.sh") || true
}
out=$(sf src/util.ts "seq 15 | sed 's/^/const x = /'")
if echo "$out" | grep -q 'reviewers since last commit: 0' && echo "$out" | grep -q 'rolepod:qa-tester' && ! echo "$out" | grep -q '"permissionDecision"'; then
  echo "  ✓ precommit SOFT: logic diff, 0 reviewers → names the count + the qa-tester floor, still allow"
else echo "  ✗ precommit SOFT reviewer line: ${out:0:200}"; fail=$((fail+1)); fi
out=$(sf src/label.ts "printf 'export const L = \"Save\";\nexport const M = \"Cancel\";\n'")
if echo "$out" | grep -q 'reviewers since last commit: 0' && ! echo "$out" | grep -q '0 reviewers on a logic diff'; then
  echo "  ✓ precommit SOFT: R1-shaped diff (1 file, ≤5 lines) → count only, no qa-tester ask (string text is R1 in the router)"
else echo "  ✗ precommit SOFT R1-shaped: ${out:0:200}"; fail=$((fail+1)); fi
out=$(sf src/notes.ts "seq 10 | sed 's/^/\/\/ note /'")
if echo "$out" | grep -q 'reviewers since last commit: 0' && ! echo "$out" | grep -q '0 reviewers on a logic diff'; then
  echo "  ✓ precommit SOFT: comment-only diff → count shown, no qa-tester ask (nothing logic-bearing)"
else echo "  ✗ precommit SOFT comment-only: ${out:0:200}"; fail=$((fail+1)); fi
rm -rf "$SF_TMP"

# ── route nudge (v2.98.0): commission + no fresh tier → one line ──────────
RN_TMP=$(mktemp -d); ( cd "$RN_TMP" && git init -q . && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init )
rn() { printf '{"session_id":"rn1","prompt":%s%s}' "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" "${2:+,\"transcript_path\":\"$2\"}" | (cd "$RN_TMP" && HOME="$RN_TMP" bash "$HOOKS/claim-verify-nudge.sh") || true; }
out=$(rn 'fix the login button')
echo "$out" | grep -q 'commission with no tier' && echo "  ✓ route nudge: commission + no route line ever → nudge" || { echo "  ✗ route nudge missing: ${out:0:120}"; fail=$((fail+1)); }
out=$(rn 'why does login fail')
echo "$out" | grep -q 'commission with no tier' && { echo "  ✗ route nudge fired on a claim-shaped question"; fail=$((fail+1)); } || echo "  ✓ route nudge: analysis question → no route line (claim-check owns it)"
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
# ── route record (v2.105.0): the hook writes the route line from the routing text ──
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

# ── review-rounds policy on internal reviewer dispatch + breaker reminder (v2.99.0) ──
RH=$(mktemp -d); mkdir -p "$RH/.rolepod/evidence"
rh_ts() { python3 -c "import datetime,sys;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$1"; }
rh_log() { printf '{"ts": "%s", "phase": "dispatch", "cli": "claude", "tool": "Agent", "agent_type": "%s"}\n' "$(rh_ts "$1")" "$2" >> "$RH/.rolepod/evidence/phase-log.jsonl"; }
( cd "$RH" && git init -q . && git config user.email t@t && git config user.name t && printf 'a\n' > f.txt && git add f.txt && GIT_COMMITTER_DATE="$(rh_ts 90)" git commit -q -m init --date="$(rh_ts 90)" && printf 'b\n' > f.txt )
rh_agent() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":"%s","prompt":"review the diff"},"session_id":"rh1","transcript_path":"/nonexistent"}' "$1" | (cd "$RH" && HOME="$RH" bash "$HOOKS/workflow-tier-nudge.sh") || true; }
rh_prompt() { printf '{"session_id":"rh1","prompt":%s}' "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" | (cd "$RH" && HOME="$RH" bash "$HOOKS/claim-verify-nudge.sh") || true; }
: > "$RH/.rolepod/evidence/phase-log.jsonl"; rh_log 40 rolepod:security-engineer; rh_log 20 rolepod:qa-tester; rh_log 1 rolepod:security-engineer
out=$(rh_agent rolepod:security-engineer)
if echo "$out" | grep -q 'review-rounds' && ! echo "$out" | grep -q '"permissionDecision": *"deny"'; then echo "  ✓ tier-nudge: reviewer dispatch at round 3 → breaker notice, not a deny"; else echo "  ✗ tier-nudge round 3: ${out:0:160}"; fail=$((fail+1)); fi
out=$(rh_agent rolepod:backend-developer)
if echo "$out" | grep -q 'review-rounds'; then echo "  ✗ tier-nudge: non-reviewer dispatch got the round note"; fail=$((fail+1)); else echo "  ✓ tier-nudge: non-reviewer dispatch → no round note"; fi
: > "$RH/.rolepod/evidence/phase-log.jsonl"; rh_log 40 rolepod:security-engineer; rh_log 20 rolepod:qa-tester; rh_log 12 rolepod:security-engineer
out=$(rh_agent rolepod:security-engineer)
check "tier-nudge: round 4 with no breaker ledger → deny" deny "$out"
out=$(rh_prompt 'I hit my usage limit while you were working, but it has reset now. Please continue from where you left off.')
if echo "$out" | grep -q 'review-rounds: 3 rounds'; then echo "  ✓ claim-verify: 3 rounds + no ledger → asks for the ledger before anything else"; else echo "  ✗ claim-verify rounds reminder: ${out:0:160}"; fail=$((fail+1)); fi
mkdir -p "$RH/docs/rolepod/handoffs"; printf '# y\n\n## Rounds\n- r1\n\n## Class\n- one predicate\n\n## Decision\n- a\n' > "$RH/docs/rolepod/handoffs/y-breaker-2026-09-08.md"
out=$(rh_agent rolepod:security-engineer)
check "tier-nudge: round 4 with a class ledger → allow" allow "$out"
out=$(rh_prompt 'Please continue from where you left off.')
if echo "$out" | grep -q 'breaker open'; then echo "  ✓ claim-verify: breaker ledger open → auto-resume prompt gets the stop reminder"; else echo "  ✗ claim-verify breaker-open reminder: ${out:0:160}"; fail=$((fail+1)); fi
rh_log 6 rolepod:qa-tester; rh_log 0 rolepod:security-engineer
out=$(rh_agent rolepod:security-engineer)
check "tier-nudge: round 5 even with the ledger → deny (terminal)" deny "$out"
out=$( (export ROLEPOD_GATES_SOFT=1; rh_agent rolepod:security-engineer) )
check "tier-nudge: ROLEPOD_GATES_SOFT=1 lifts the round deny" allow "$out"
rm -rf "$RH"

# ── auto-resume prompt (v2.100.0): a resume, not a decision; no route nudge ──
AR_TMP=$(mktemp -d); ( cd "$AR_TMP" && git init -q . && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init )
out=$(printf '{"session_id":"ar1","prompt":"I hit my usage limit while you were working, but it has reset now. Please continue from where you left off."}' | (cd "$AR_TMP" && HOME="$AR_TMP" bash "$HOOKS/claim-verify-nudge.sh") || true)
if echo "$out" | grep -q 'auto-resume' && ! echo "$out" | grep -q 'commission with no tier'; then echo "  ✓ claim-verify: auto-resume prompt → resume line, no route nudge"; else echo "  ✗ claim-verify auto-resume: ${out:0:200}"; fail=$((fail+1)); fi
out=$(printf '{"session_id":"ar1","prompt":"continue with the plan"}' | (cd "$AR_TMP" && HOME="$AR_TMP" bash "$HOOKS/claim-verify-nudge.sh") || true)
if echo "$out" | grep -q 'auto-resume'; then echo "  ✗ claim-verify: a normal continue got the auto-resume line"; fail=$((fail+1)); else echo "  ✓ claim-verify: a user's own 'continue' → no auto-resume line"; fi
rm -rf "$AR_TMP"

# ── project-context-loader: session-start state pointers (v2.102.0) ────────
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

# ─── result ───
if [ "$fail" -eq 0 ]; then
  echo "  ✓ pass"
  exit 0
else
  echo "  ✗ fail ($fail behavioral assertions failed)"
  exit 1
fi
