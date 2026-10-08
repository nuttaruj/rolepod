#!/bin/bash
# Static test — hooks/subagent-write-scope.sh (v2.111.0, classes v2.112.0).
#
# generic (general-purpose / default / claude) → no product write; test-only
# (rolepod-qa / rolepod-reviewer) → test paths + markdown; read-only
# (rolepod-scout) → markdown. The Lead, rolepod-builder, unknown and retired
# names, OS temp, scratch / evidence paths and paths outside the repo root
# (git toplevel of the payload cwd) pass. One case per rule.
# Wired into `make test-static`.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"
HOOK="hooks/subagent-write-scope.sh"
fail=0
FX=""
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP" "$FX"' EXIT
# run in a scratch cwd with no .git so the evidence row never lands in the repo;
# no git root there means no out-of-root skip (C2), so the denies below hold
WORK="$TMP/work"; mkdir -p "$WORK"
# These ownership assertions pin Full's enforcement. Mode behavior is covered
# by the integration hooks; an absent profile now correctly defaults Standard.
PROFILE_HOME="$TMP/home"; mkdir -p "$PROFILE_HOME/.rolepod"
printf '{"workflow":{"mode":"full"}}\n' > "$PROFILE_HOME/.rolepod/config.json"
export ROLEPOD_SESSION_MODE=full ROLEPOD_SESSION_SOURCE=global ROLEPOD_SESSION_CLI=claude

# run <json> <expect: deny|allow> <label> [env]
run() {
  local got
  got=$(cd "$WORK" && printf '%s' "$1" | env HOME="$PROFILE_HOME" ${4:-} bash "$REPO_DIR/$HOOK" 2>/dev/null || true)
  local verdict="allow"
  printf '%s' "$got" | grep -q '"permissionDecision": "deny"' && verdict="deny"
  if [ "$verdict" = "$2" ]; then
    echo "  ✓ $3"
  else
    echo "  ✗ $3 — expected $2, got $verdict"; fail=$((fail+1))
  fi
}

P='/home/x/proj/src/booking.ts'
echo "── subagent-write-scope ──"

run '{"tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  allow "Lead (no agent_id) edits freely"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  deny "general-purpose Edit on a product path is denied"

run '{"agent_id":"a1","agent_type":"default","tool_name":"Write","tool_input":{"file_path":"'"$P"'"}}' \
  deny "default agent Write on a product path is denied"
run '{"agent_id":"a1","agent_type":"workflow-subagent","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  deny "bare Workflow agent() Edit on a product path is denied"
run '{"agent_id":"a1","agent_type":"workflow-subagent","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/notes/plan.md"}}' \
  deny "bare Workflow agent() may not write even markdown in the product tree"
WF_MSG=$(cd "$WORK" && printf '%s' '{"agent_id":"a1","agent_type":"workflow-subagent","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' | HOME="$PROFILE_HOME" bash "$REPO_DIR/$HOOK" 2>/dev/null || true)
if printf '%s' "$WF_MSG" | grep -qF 'put BLOCKED and this path in your StructuredOutput answer (or final text); a repro script goes to $TMPDIR or the scratchpad.' \
   && ! printf '%s' "$WF_MSG" | grep -qF 'return BLOCKED naming this path' \
   && [ "$(python3 -c 'import sys,json; print(len(json.loads(sys.stdin.read())["hookSpecificOutput"]["permissionDecisionReason"]))' <<<"$WF_MSG")" -le 600 ]; then
  echo "  ✓ workflow-subagent message carries C3, no old wording, ≤600 chars"
else
  echo "  ✗ workflow-subagent message: C3 missing, old wording present, or >600 chars"; fail=$((fail+1))
fi

run '{"agent_id":"a1","agent_type":"rolepod:backend-developer","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  allow "a rolepod role writes"

run '{"agent_id":"a1","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  allow "sub-agent with no agent_type passes (fail-open)"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/scratchpad/notes.md"}}' \
  allow "general-purpose may write scratchpad"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/.rolepod/evidence/r.md"}}' \
  allow "general-purpose may write evidence"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Write","tool_input":{"file_path":"/private/tmp/claude-501/x/probe.ts"}}' \
  allow "general-purpose may write under the OS temp root"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/tmp/fixture.json"}}' \
  deny "a repo-internal tmp/ directory is product, not scratch"

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"NotebookEdit","tool_input":{"notebook_path":"/home/x/proj/analysis.ipynb"}}' \
  deny "NotebookEdit on a product notebook is denied"

# test-only class — rolepod-qa / rolepod-reviewer
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/src/booking.test.ts"}}' \
  allow "rolepod-qa writes a *.test.* file"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/tests/fixtures/seed.json"}}' \
  allow "rolepod-qa writes under tests/"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/vitest.config.ts"}}' \
  allow "rolepod-qa edits test config"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/docs/test-plan.md"}}' \
  allow "rolepod-qa writes markdown"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/worker/payments/accountChargeGate.ts"}}' \
  deny "rolepod-qa Edit on production code is denied"
run '{"agent_id":"a1","agent_type":"rolepod-qa","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/testimonials.ts"}}' \
  deny "a 'test' substring inside a source name is not a test path"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-reviewer","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/tests/authz.spec.ts"}}' \
  allow "rolepod-reviewer writes a spec that proves a finding"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/src/specs/openapi.yaml"}}' \
  deny "specs/ is a contract dir, not a test dir"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/spec/models/user_spec.rb"}}' \
  allow "RSpec spec/ tree is a test path"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/experiments/ab_test.py"}}' \
  deny "Python *_test.py is product (no discovery guarantee)"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/src/test_ab.py"}}' \
  allow "Python test_*.py is a test file"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/src/__snapshots__/Card.test.tsx.snap"}}' \
  allow "snapshot under __snapshots__ is a test artifact"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/src/Card.test.tsx.snap"}}' \
  allow "*.test.tsx.snap beside the test is a test artifact"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/src/checkout.cy.ts"}}' \
  allow "Cypress *.cy.ts is a test file"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-qa","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/src/types.test-d.ts"}}' \
  allow "tsd *.test-d.ts is a test file"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-reviewer","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/worker/routes/invite.ts"}}' \
  deny "rolepod-reviewer Edit on an auth route is denied"

# reviewer markdown, the new type classes (A1-A7) and the old names
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-reviewer","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/review-notes.md"}}' \
  allow "rolepod-reviewer writes markdown"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-reviewer","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  deny "rolepod-reviewer Edit on product code is denied"
run '{"agent_id":"a1","agent_type":"otherplugin:rolepod-reviewer","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  deny "another namespace's rolepod-reviewer is still restricted"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-reviewer","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/tests/x.test.ts"}}' \
  allow "A2: rolepod-reviewer writes a test path"
run '{"agent_id":"a1","agent_type":"rolepod-reviewer","tool_name":"Write","tool_input":{"file_path":"/tmp/repro/x.py"}}' \
  allow "A2: rolepod-reviewer writes a free path (/tmp)"
run '{"agent_id":"a1","agent_type":"rolepod-reviewer","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/.rolepod/evidence/review/t-spec.md"}}' \
  allow "A2: rolepod-reviewer writes its lens report under .rolepod/"
run '{"agent_id":"a1","agent_type":"rolepod-reviewer","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/x.py"}}' \
  deny "A1: rolepod-reviewer (bare name) Edit on src/x.py is denied"
run '{"agent_id":"a1","agent_type":"rolepod-reviewer","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/src/x.py"}}' \
  deny "A1: rolepod-reviewer Write on src/x.py is denied"
run '{"agent_id":"a1","agent_type":"rolepod-qa","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/x.py"}}' \
  deny "A3: rolepod-qa on a product file is denied"
run '{"agent_id":"a1","agent_type":"rolepod-qa","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/tests/test_x.py"}}' \
  allow "A3: rolepod-qa on a test path is allowed"
run '{"agent_id":"a1","agent_type":"rolepod-scout","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/x.py"}}' \
  deny "A4: rolepod-scout on a product file is denied"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-scout","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/tests/x.test.ts"}}' \
  deny "A4: rolepod-scout may not write even a test file"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-scout","tool_name":"Write","tool_input":{"file_path":"/home/x/proj/notes.md"}}' \
  allow "A4: rolepod-scout writes a .md file"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-builder","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/x.py"}}' \
  allow "A5: rolepod-builder writes product code (owner)"
run '{"agent_id":"a1","agent_type":"rolepod-builder","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/x.py"}}' \
  allow "A5: rolepod-builder (bare name) writes product code"
run '{"agent_id":"a1","agent_type":"otherplugin:rolepod-reviewer","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/x.py"}}' \
  deny "A6: otherplugin:rolepod-reviewer is test-only (class keys on the bare name)"
run '{"agent_id":"a1","agent_type":"rolepod:rolepod-reviewer","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/x.py"}}' \
  deny "A6: rolepod:rolepod-reviewer is test-only"

# retired role names get no class (no alias in the hook): they pass like any unknown type
for old in universal-reviewer adversarial-reviewer qa-tester security-engineer scout backend-developer; do
  run '{"agent_id":"a1","agent_type":"rolepod:'"$old"'","tool_name":"Edit","tool_input":{"file_path":"/home/x/proj/src/x.py"}}' \
    allow "old name '$old' has no class → passes"
done

run '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  allow "ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE=1 bypasses" "ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE=1"

# deny reason names the fix + exception, stays under the lean cap
REASON=$(cd "$WORK" && printf '%s' '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  | HOME="$PROFILE_HOME" bash "$REPO_DIR/$HOOK" 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecisionReason"])')
if printf '%s' "$REASON" | grep -q "re-dispatches the write to a rolepod type" && printf '%s' "$REASON" | grep -q "Exception:" && ! printf '%s' "$REASON" | grep -q "ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE" && [ "${#REASON}" -le 600 ]; then
  echo "  ✓ deny reason = fact → Fix → Exception, ${#REASON} chars"
else
  echo "  ✗ deny reason shape/length (${#REASON} chars)"; fail=$((fail+1))
fi
# bypass inside a git repo lands one row in bypass.log
REPO="$TMP/repo"; mkdir -p "$REPO"; (cd "$REPO" && git init -q)
(cd "$REPO" && printf '%s' '{"agent_id":"a1","agent_type":"general-purpose","tool_name":"Edit","tool_input":{"file_path":"'"$P"'"}}' \
  | HOME="$PROFILE_HOME" ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE=1 ROLEPOD_BYPASS_REASON=test bash "$REPO_DIR/$HOOK" >/dev/null 2>&1 || true)
if grep -q '"hook":"subagent-write-scope","var":"ROLEPOD_ALLOW_OUT_OF_SCOPE_WRITE"' "$REPO/.rolepod/evidence/bypass.log" 2>/dev/null; then
  echo "  ✓ bypass is logged to bypass.log"
else
  echo "  ✗ bypass row missing from bypass.log"; fail=$((fail+1))
fi

# a deny with no .git and no .rolepod/evidence writes no evidence row
if [ ! -e "$WORK/.rolepod" ]; then
  echo "  ✓ no evidence dir created outside a repo"
else
  echo "  ✗ evidence dir created outside a repo"; fail=$((fail+1))
fi

# C2 — a path outside the git toplevel of the payload cwd is skipped.
# Fixture under the gitignored .worktrees/: mktemp dirs sit under OS temp roots, which pass earlier.
case "$REPO_DIR" in
  /tmp/*|/private/tmp/*|/var/folders/*) echo "  · C2 root cases skipped (repo under an OS temp root)" ;;
  *)
    mkdir -p "$REPO_DIR/.worktrees"
    FX="$(mktemp -d "$REPO_DIR/.worktrees/ws-scope.XXXXXX")"
    git init -q "$FX/main" && mkdir -p "$FX/main/src" "$FX/other" "$FX/main-other"
    git -C "$FX/main" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m i
    git -C "$FX/main" worktree add -q "$FX/wt" -b wt
    ln -s "$FX/main/src" "$FX/lnk"; ln -s "$FX/other" "$FX/main/outlnk"
    mkdir -p "$FX/wt/src"
    j() { printf '{"agent_id":"a1","agent_type":"%s","tool_name":"%s","cwd":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2" "$3" "$4"; }
    MEM='/home/x/.claude/projects/-home-x-proj/memory/note.md'
    run "$(j general-purpose Write "$FX/main" "$MEM")" allow "out-of-root memory path is skipped"
    if [ ! -e "$FX/main/.rolepod" ]; then echo "  ✓ skip writes no evidence row"; else echo "  ✗ skip wrote an evidence row"; fail=$((fail+1)); fi
    run "$(j rolepod:rolepod-reviewer Edit "$FX/main" "$FX/main/src/app.ts")" deny "in-root: rolepod-reviewer Edit still denied (WS4)"
    run "$(j rolepod:rolepod-qa Edit "$FX/main" "$FX/main/src/app.ts")" deny "in-root: rolepod-qa Edit on product code denied"
    run "$(j rolepod:rolepod-reviewer Edit "$FX/wt" "$FX/wt/src/app.ts")" deny "A7: rolepod-reviewer product path in a .worktrees/<task>-repro tree is denied"
    run "$(j rolepod:rolepod-reviewer Write "$FX/wt" "$FX/wt/tests/test_app.py")" allow "A7: rolepod-reviewer test path in that tree is allowed"
    run "$(j general-purpose Edit "$FX/main/src" "$FX/main/src/app.ts")" deny "root resolves from a subdirectory cwd"
    run "$(j general-purpose Edit "$FX/wt" "$FX/main/src/app.ts")" deny "linked worktree: main checkout counts as inside"
    run "$(j general-purpose Edit "$FX/wt" "$FX/wt/src/app.ts")" deny "linked worktree: its own tree counts as inside"
    run "$(j general-purpose Write "$FX/wt" "$FX/other/x.ts")" allow "linked worktree: a path outside both roots is skipped"
    run "$(j general-purpose Write "/nonexistent/dir" "/home/x/proj/src/booking.ts")" deny "unresolvable root: no skip"
    run "$(j general-purpose Edit "$FX/main" "$FX/lnk/app.ts")" deny "symlink outside the root pointing in is inside"
    run "$(j general-purpose Edit "$FX/main" "$FX/main/outlnk/x.ts")" allow "symlink inside the root pointing out is outside"
    run "$(j general-purpose Edit "$FX/main" "$FX/other/../main/src/app.ts")" deny ".. that re-enters the root is inside"
    run "$(j general-purpose Write "$FX/main" "$FX/main/../other/x.ts")" allow ".. that leaves the root is outside"
    run "$(j general-purpose Write "$FX/main" "$FX/main-other/x.ts")" allow "shared-prefix sibling is outside"
    run "$(j general-purpose Edit "$FX/main" "src/app.ts")" deny "relative path joins the payload cwd"
    run "$(j general-purpose Write "$FX/main/.git/HEAD" "$MEM")" deny "cwd that is not a directory: no root, no skip"
    run "$(j general-purpose Write "" "$MEM")" deny "empty cwd falls back to the hook cwd (no repo): no skip"
    FXU="$(printf '%s' "$FX" | tr '[:lower:]' '[:upper:]')"
    if [ "$FXU" != "$FX" ] && [ -d "$FXU/main/src" ]; then
      run "$(j rolepod:rolepod-reviewer Edit "$FX/main" "$FXU/main/src/app.ts")" deny "wrong-case path into the root (case-insensitive volume) is inside"
      run "$(j general-purpose Write "$FX/main" "$FXU/other/x.ts")" allow "wrong-case path outside the root is still skipped"
    else
      echo "  · wrong-case cases skipped (case-sensitive volume)"
    fi
    ;;
esac

[ "$fail" -eq 0 ] && echo "  → subagent-write-scope: all passed" || { echo "  → subagent-write-scope: $fail failed"; exit 1; }
