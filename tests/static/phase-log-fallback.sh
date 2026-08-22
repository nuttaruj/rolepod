#!/bin/bash
# Behavioral test — precommit-gate reviewer fallback on renders without
# hooks/lib/session_state.py (codex + the non-Claude adapters).
#
# Bug (v2.60.0): those renders always read 0 reviewer evidence, so a
# high-risk commit HARD-blocked with no way to clear — the deny said
# "dispatch a reviewer and rerun" but the rerun still counted 0.
# Fix: fall back to the SubagentStop dispatch-proof log
# (.rolepod/evidence/phase-log.jsonl, written by subagent-model-log.sh).
#
# Runs the real hook in a throwaway git repo with a staged high-risk diff;
# lib/ is absent from the copied hook dir, so the fallback path executes.
# Wired into `make test-static`.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

fail=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
mkdir -p "$HOME"
unset ROLEPOD_GATES_SOFT ROLEPOD_GATES_HARD ROLEPOD_GATES_PASSED 2>/dev/null || true

# Throwaway repo with one commit, then a staged high-risk diff with logic.
mkdir -p "$tmp/repo" && cd "$tmp/repo"
git init -q . && git config user.email t@t && git config user.name t
echo base > base.txt && git add base.txt && git commit -qm init
GIT_ROOT=$(git rev-parse --show-toplevel)
mkdir -p auth
printf 'def check(tok):\n    if tok is None:\n        return False\n    return len(tok) > 8\n\n\ndef issue(uid):\n    return f"tk-{uid}"\n' > auth/login.py
git add auth/login.py

# Hook dir WITHOUT lib/ — forces the phase-log fallback branch.
mkdir -p "$tmp/hooks"
cp "$REPO_DIR/hooks/precommit-gate.sh" "$tmp/hooks/"

INPUT='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"add auth check\""}}'
EPOCH=$(git log -1 --format=%ct)
TS_AFTER=$(python3 -c "import datetime,sys;print(datetime.datetime.fromtimestamp(int(sys.argv[1])+1,datetime.timezone.utc).isoformat(timespec='seconds'))" "$EPOCH")
TS_BEFORE=$(python3 -c "import datetime,sys;print(datetime.datetime.fromtimestamp(int(sys.argv[1])-100,datetime.timezone.utc).isoformat(timespec='seconds'))" "$EPOCH")

# run <label> <expect: deny|pass>
run() {
  local out
  out=$(printf '%s' "$INPUT" | bash "$tmp/hooks/precommit-gate.sh" 2>/dev/null)
  local verdict=pass
  echo "$out" | grep -q '"permissionDecision": *"deny"' && verdict=deny
  if [ "$verdict" = "$2" ]; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1 — expected $2, got $verdict"
    fail=$((fail+1))
  fi
}

EV="$GIT_ROOT/.rolepod/evidence"
mkdir -p "$EV"

echo "── phase-log-fallback ──"

# 1. High-risk staged diff, no evidence log → HARD deny.
run "high-risk diff with no dispatch log denies" deny

# 2. Non-reviewer dispatch-proof entry → still denies.
printf '{"ts":"%s","phase":"dispatch-proof","cli":"codex","agent_type":"rolepod-backend-developer","model":"gpt-5.6-terra"}\n' "$TS_AFTER" > "$EV/phase-log.jsonl"
run "non-reviewer dispatch does not clear" deny

# 3. Strong reviewer finished BEFORE the last commit → outside window, denies.
printf '{"ts":"%s","phase":"dispatch-proof","cli":"codex","agent_type":"rolepod-universal-reviewer","model":"gpt-5.6-sol"}\n' "$TS_BEFORE" > "$EV/phase-log.jsonl"
run "reviewer before last commit is outside the window" deny

# 4. Strong reviewer finished after the last commit → auto-pass.
printf '{"ts":"%s","phase":"dispatch-proof","cli":"codex","agent_type":"rolepod-universal-reviewer","model":"gpt-5.6-sol"}\n' "$TS_AFTER" > "$EV/phase-log.jsonl"
run "codex-named (rolepod-) strong reviewer clears the block" pass

# 5. Namespaced form (rolepod:security-engineer) must also clear.
printf '{"ts":"%s","phase":"dispatch-proof","cli":"codex","agent_type":"rolepod:security-engineer","model":""}\n' "$TS_AFTER" > "$EV/phase-log.jsonl"
run "namespaced (rolepod:) strong reviewer clears the block" pass

# 6. qa-tester is review activity but NOT strong → high-risk still denies.
printf '{"ts":"%s","phase":"dispatch-proof","cli":"codex","agent_type":"rolepod-qa-tester","model":"gpt-5.6-terra"}\n' "$TS_AFTER" > "$EV/phase-log.jsonl"
run "qa-tester alone does not clear a high-risk diff" deny

# ── External strong pass (satellite-first, v2.61.0) ──

# 7. Anchored external review (real raw file >= 500B) → auto-pass.
mkdir -p "$EV/external"
head -c 900 /dev/zero | tr '\0' 'x' > "$EV/external/r1-codex.txt"
printf '{"ts":"%s","phase":"review","verdict":"APPROVED","blockers":0,"reviewer":"external","family":"codex","model":"gpt-5.6-sol","raw":"external/r1-codex.txt"}\n' "$TS_AFTER" > "$EV/phase-log.jsonl"
run "anchored external strong review clears the block" pass

# 8. External review line with NO raw file → bare claim, denies.
printf '{"ts":"%s","phase":"review","verdict":"APPROVED","blockers":0,"reviewer":"external","family":"codex","model":"gpt-5.6-sol","raw":"external/missing.txt"}\n' "$TS_AFTER" > "$EV/phase-log.jsonl"
run "external review without the raw artifact is ignored" deny

# 9. Raw file too small (< 500B) → not a real review output, denies.
printf 'APPROVED' > "$EV/external/tiny.txt"
printf '{"ts":"%s","phase":"review","verdict":"APPROVED","blockers":0,"reviewer":"external","family":"codex","model":"gpt-5.6-sol","raw":"external/tiny.txt"}\n' "$TS_AFTER" > "$EV/phase-log.jsonl"
run "trivially small raw artifact is ignored" deny

# 10. Path traversal in raw → ignored, denies.
head -c 900 /dev/zero | tr '\0' 'x' > "$tmp/outside.txt"
printf '{"ts":"%s","phase":"review","verdict":"APPROVED","blockers":0,"reviewer":"external","family":"codex","model":"gpt-5.6-sol","raw":"../../outside.txt"}\n' "$TS_AFTER" > "$EV/phase-log.jsonl"
run "raw path traversal outside evidence dir is ignored" deny

# 11. Anchored external review BEFORE last commit → outside window, denies.
printf '{"ts":"%s","phase":"review","verdict":"APPROVED","blockers":0,"reviewer":"external","family":"codex","model":"gpt-5.6-sol","raw":"external/r1-codex.txt"}\n' "$TS_BEFORE" > "$EV/phase-log.jsonl"
run "anchored external review before last commit is outside the window" deny

echo ""
if [ $fail -eq 0 ]; then
  echo "phase-log-fallback: pass"
  exit 0
fi
echo "phase-log-fallback: $fail failure(s)"
exit 1
