#!/bin/bash
# mode-gate-matrix — policy table of rolepod_gate_action (14 gates x 3 modes).
# ROLEPOD_CASE=<regex> selects sections; no match -> exit 1.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fail=0
RAN_SECTIONS=0
TOTAL_SECTIONS=0
export HOME; HOME=$(mktemp -d); trap 'rm -rf "$HOME"' EXIT
unset ROLEPOD_SESSION_MODE ROLEPOD_SESSION_SOURCE BASH_ENV 2>/dev/null || true

section() {
  TOTAL_SECTIONS=$((TOTAL_SECTIONS+1))
  if [ -n "${ROLEPOD_CASE:-}" ] && ! [[ "$1" =~ $ROLEPOD_CASE ]]; then return 1; fi
  RAN_SECTIONS=$((RAN_SECTIONS+1)); echo "── $1"; return 0
}

# run_hook <hook> <mode> <payload>: profile on disk + session_id in payload (no env shim).
run_hook() {
  local hook=$1 mode=$2 payload=$3 sid="${RUN_SID:-mx-$$-$RANDOM}" d
  d="$HOME/.rolepod/session-profiles/claude"; mkdir -p "$d"
  printf '%s\nproject\n' "$mode" > "$d/$sid.mode"
  payload=${payload/\{/\{\"session_id\":\"$sid\",}
  # A section that sourced session-mode.sh exported ROLEPOD_SESSION_* into
  # this shell; the hook must resolve its mode from the profile file alone.
  printf '%s' "$payload" | env -u ROLEPOD_SESSION_MODE -u ROLEPOD_SESSION_SOURCE -u ROLEPOD_SESSION_ID -u ROLEPOD_SESSION_CLI \
    CLAUDE_PLUGIN_ROOT="$REPO_DIR" bash "$REPO_DIR/hooks/$hook" 2>&1 || true
}

if section "table"; then
  # shellcheck source=/dev/null
  . "$REPO_DIR/hooks/lib/session-mode.sh"
  table="private-docs deny deny deny
risk-no-test warn warn deny
code-no-test silent silent deny
subagent-ship deny deny deny
cannot-wait deny deny deny
scope-generic warn deny deny
scope-bare-workflow warn deny deny
scope-test-role warn deny deny
scope-readonly-role warn deny deny
collision deny deny deny
bare-fanout deny deny deny
strong-fanout deny deny deny
bare-writer deny deny deny"
  n=0
  while read -r gate l s f; do
    i=0
    for mode in lite standard full; do
      i=$((i+1)); exp=$(echo "$l $s $f" | cut -d' ' -f$i)
      got=$(ROLEPOD_SESSION_MODE=$mode rolepod_gate_action "$gate")
      n=$((n+1))
      [ "$got" = "$exp" ] || { echo "  ✗ $gate/$mode: want $exp got $got"; fail=$((fail+1)); }
    done
  done <<< "$table"
  [ "$n" -eq 39 ] || { echo "  ✗ expected 39 cells, ran $n"; fail=$((fail+1)); }
  [ "$(ROLEPOD_SESSION_MODE=full rolepod_gate_action no-such-gate)" = silent ] || { echo "  ✗ unknown gate"; fail=$((fail+1)); }
  [ "$(ROLEPOD_SESSION_MODE=bogus rolepod_gate_action risk-no-test)" = warn ] || { echo "  ✗ unknown mode -> lite"; fail=$((fail+1)); }
  [ "$(unset ROLEPOD_SESSION_MODE; rolepod_gate_action risk-no-test)" = warn ] || { echo "  ✗ unset mode -> lite"; fail=$((fail+1)); }
  rolepod_session_profile_apply lite project
  [ "$ROLEPOD_SESSION_MODE" = lite ] && [ "$ROLEPOD_SESSION_SOURCE" = project ] || { echo "  ✗ lite profile apply did not set mode/source"; fail=$((fail+1)); }
  [ "$fail" -eq 0 ] && echo "  ✓ table: $n cells + unknown + lite profile"
fi

# verdict <hook output> -> deny | warn | note | silent (what the hook told the CLI)
verdict() {
  case "$1" in
    *'"permissionDecision": "deny"'*) echo deny ;;
    *'"additionalContext": "WARNING:'*) echo warn ;;
    *additionalContext*) echo note ;;
    *) echo silent ;;
  esac
}
expect() { # <label> <want> <got>
  if [ "$2" = "$3" ]; then return 0; fi
  echo "  ✗ $1: want $2 got $3"; fail=$((fail+1))
}
# C4 shape of a warning: WARNING: … Fix: … Exception: …, <=600 chars, no BLOCKED / retry / switch name.
c4() { # <label> <hook output>
  local m
  m=$(printf '%s' "$2" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"].split("\n",1)[0])' 2>/dev/null || true)
  case "$m" in "WARNING:"*) ;; *) echo "  ✗ $1: warning does not start WARNING:"; fail=$((fail+1)); return ;; esac
  [[ "$m" == *"Fix:"* && "$m" == *"Exception:"* ]] || { echo "  ✗ $1: warning lacks Fix:/Exception:"; fail=$((fail+1)); }
  [ "${#m}" -le 600 ] || { echo "  ✗ $1: warning is ${#m} chars (>600)"; fail=$((fail+1)); }
  case "$m" in *BLOCKED*|*retry*|*ROLEPOD_ALLOW_*) echo "  ✗ $1: warning names BLOCKED/retry/a switch"; fail=$((fail+1)) ;; esac
}
mk_repo() { # <dir> <file> <lines>: a repo with one staged file of N code lines
  mkdir -p "$1/$(dirname "$2")"
  ( cd "$1" && git init -q . && git config user.email t@t && git config user.name t \
    && seq "$3" | sed 's/^/x = /' > "$2" && git add -A )
}
commit_in() { # <repo> <mode> [transcript]: run the commit gate for `git commit` inside <repo>
  local tp=${3:-}
  local payload
  if [ -n "$tp" ]; then payload=$(printf '{"tool_name":"Bash","transcript_path":"%s","tool_input":{"command":"git commit -m x"}}' "$tp")
  else payload='{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}'; fi
  ( cd "$1" && run_hook precommit-gate.sh "$2" "$payload" )
}

if section "precommit"; then
  W=$(mktemp -d)
  mk_repo "$W/docs" docs/rolepod/plan.md 3
  mk_repo "$W/risk" src/auth/login.py 15
  mk_repo "$W/norm" src/util.py 15
  mk_repo "$W/rnt" src/util.py 15
  printf '%s\n' '{"type":"tool_use","name":"Edit","input":{"file_path":"src/auth/login.py"}}' > "$W/edits.jsonl"
  printf '%s\n' '{"type":"tool_use","name":"Edit","input":{"file_path":"tests/test_login.py"}}' > "$W/testedit.jsonl"
  for mode in lite standard full; do
    exp_priv=deny
    case "$mode" in full) exp_r4=deny ;; *) exp_r4=warn ;; esac
    case "$mode" in full) exp_rnt=deny; exp_cnt=deny ;; *) exp_rnt=warn; exp_cnt=silent ;; esac
    out=$(commit_in "$W/docs" "$mode"); expect "private-docs/$mode" "$exp_priv" "$(verdict "$out")"
    out=$(commit_in "$W/risk" "$mode"); expect "high-risk-staged-no-test/$mode" "$exp_r4" "$(verdict "$out")"
    [ "$exp_r4" = warn ] && c4 "high-risk-staged-no-test/$mode" "$out"
    out=$(commit_in "$W/risk" "$mode" "$W/testedit.jsonl"); expect "high-risk-staged-with-test/$mode" silent "$(verdict "$out")"
    out=$(commit_in "$W/rnt" "$mode" "$W/edits.jsonl"); expect "risk-no-test/$mode" "$exp_rnt" "$(verdict "$out")"
    [ "$exp_rnt" = warn ] && c4 "risk-no-test/$mode" "$out"
    out=$(commit_in "$W/norm" "$mode"); expect "code-no-test/$mode" "$exp_cnt" "$(verdict "$out")"
  done
  # Group B: the test-diff-lint note speaks in every mode, after no gate verdict.
  mk_repo "$W/lint" tests/a.test.js 1
  ( cd "$W/lint" && printf 'it.only("x", () => {});\n' >> tests/a.test.js && git add -A )
  for mode in lite standard full; do
    out=$(commit_in "$W/lint" "$mode")
    case "$out" in *test-diff-lint*) ;; *) echo "  ✗ test-diff-lint/$mode: no lint note"; fail=$((fail+1)) ;; esac
  done
  # Tree rewrite while a detached review runs: the advisory speaks in every mode.
  mk_repo "$W/rw" src/util.py 3
  ( cd "$W/rw" && git commit -q -m init && mkdir -p .rolepod/evidence/external/jobs/j1 )
  bash -c 'exec -a cross-family-fake sleep 20' & JOB=$!
  echo "$JOB" > "$W/rw/.rolepod/evidence/external/jobs/j1/pid"; date +%s > "$W/rw/.rolepod/evidence/external/jobs/j1/started"
  for mode in lite standard full; do
    out=$(cd "$W/rw" && run_hook precommit-gate.sh "$mode" '{"tool_name":"Bash","tool_input":{"command":"git stash"}}')
    case "$out" in *"REVIEW IN FLIGHT"*) ;; *) echo "  ✗ tree-rewrite/$mode: no advisory (${out:0:80})"; fail=$((fail+1)) ;; esac
  done
  kill "$JOB" 2>/dev/null || true; wait "$JOB" 2>/dev/null || true
  rm -rf "$W"
  [ "$fail" -eq 0 ] && echo "  ✓ precommit: 4 gates x 3 modes + C4 + group B"
fi

if section "push-ref"; then
  W=$(mktemp -d)
  ( cd "$W" && git init -q --bare remote.git && git clone -q remote.git work 2>/dev/null && cd work \
    && git config user.email t@t && git config user.name t \
    && git commit -q --allow-empty -m c0 && git push -q origin HEAD 2>/dev/null \
    && git commit -q --allow-empty -m c1 && git commit -q --allow-empty -m c2 )
  for mode in lite standard full; do
    out=$(cd "$W/work" && run_hook push-ref-check.sh "$mode" '{"tool_name":"Bash","tool_input":{"command":"git push"}}')
    case "$out" in *"publishes 2 commits"*) ;; *) echo "  ✗ push-ref/$mode: no note (${out:0:80})"; fail=$((fail+1)) ;; esac
    [ "$(verdict "$out")" = deny ] && { echo "  ✗ push-ref/$mode denied"; fail=$((fail+1)); }
  done
  rm -rf "$W"
  [ "$fail" -eq 0 ] && echo "  ✓ push-ref: note speaks in every mode, never denies"
fi

sub_payload() { # <agent_type> <tool> <tool_input json>
  printf '{"agent_id":"a1","agent_type":"%s","tool_name":"%s","tool_input":%s}' "$1" "$2" "$3"
}

if section "subagent"; then
  # subagent-ship and cannot-wait deny in every mode; no warn form exists.
  for mode in lite standard full; do
    out=$(run_hook block-subagent-commit.sh "$mode" "$(sub_payload backend-developer Bash '{"command":"git commit -m x"}')")
    expect "subagent-ship/$mode" deny "$(verdict "$out")"
    out=$(run_hook block-subagent-commit.sh "$mode" "$(sub_payload backend-developer Bash '{"command":"sleep 1","run_in_background":true}')")
    expect "cannot-wait/bash-bg/$mode" deny "$(verdict "$out")"
    out=$(run_hook block-subagent-commit.sh "$mode" "$(sub_payload backend-developer Bash '{"command":"make test-static"}')")
    expect "cannot-wait/gate-no-timeout/$mode" deny "$(verdict "$out")"
    out=$(run_hook block-subagent-commit.sh "$mode" "$(sub_payload backend-developer Agent '{"name":"r1","prompt":"x"}')")
    expect "cannot-wait/named-agent/$mode" deny "$(verdict "$out")"
    out=$(run_hook block-subagent-commit.sh "$mode" "$(sub_payload backend-developer SendMessage '{"to":"a1234567890abcdef","message":"x"}')")
    expect "cannot-wait/raw-id/$mode" deny "$(verdict "$out")"
    out=$(run_hook block-subagent-commit.sh "$mode" '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}')
    expect "lead-commit-passes/$mode" silent "$(verdict "$out")"
  done
  [ "$fail" -eq 0 ] && echo "  ✓ subagent: subagent-ship + 5 cannot-wait forms deny in every mode"
fi

if section "scope"; then
  W=$(mktemp -d)
  for mode in lite standard full; do
    case "$mode" in lite) exp=warn ;; *) exp=deny ;; esac
    for at in general-purpose workflow-subagent rolepod-qa rolepod-reviewer; do
      out=$(cd "$W" && run_hook subagent-write-scope.sh "$mode" "$(sub_payload "$at" Write '{"file_path":"/repo/src/app.py"}')")
      expect "scope/$at/$mode" "$exp" "$(verdict "$out")"
      [ "$exp" = warn ] && c4 "scope/$at/$mode" "$out"
      case "$out" in *ROLEPOD_ALLOW_*) echo "  ✗ scope/$at/$mode: message names a switch"; fail=$((fail+1)) ;; esac
    done
    out=$(cd "$W" && run_hook subagent-write-scope.sh "$mode" "$(sub_payload backend-developer Write '{"file_path":"/repo/src/app.py"}')")
    expect "scope/owning-role/$mode" silent "$(verdict "$out")"
    out=$(cd "$W" && run_hook subagent-write-scope.sh "$mode" '{"tool_name":"Write","tool_input":{"file_path":"/repo/src/app.py"}}')
    expect "scope/lead/$mode" silent "$(verdict "$out")"
  done
  rm -rf "$W"
  [ "$fail" -eq 0 ] && echo "  ✓ scope: 4 classes x 3 modes (lite warn + C4, standard/full deny)"
fi

if section "collision"; then
  W=$(mktemp -d); mk_repo "$W/r" src/a.py 3
  WT=$(cd "$W/r" && pwd -P)
  H=$(printf '%s' "$WT" | { shasum -a 256 2>/dev/null || sha256sum; } | awk '{print $1}' | head -c 16)
  mkdir -p "$HOME/.rolepod/session-locks/$H"
  printf 'claude\n1' > "$HOME/.rolepod/session-locks/$H/sib.lock"
  printf '%s\n' "$WT/src/a.py" > "$HOME/.rolepod/session-locks/$H/sib.files"
  for mode in lite standard full; do
    out=$(cd "$WT" && run_hook worktree-guard.sh "$mode" "{\"cwd\":\"$WT\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$WT/src/a.py\"}}")
    expect "collision/$mode" deny "$(verdict "$out")"
    out=$(cd "$WT" && run_hook worktree-guard.sh "$mode" "{\"cwd\":\"$WT\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$WT/src/other-$mode.py\"}}")
    expect "disjoint/$mode" silent "$(verdict "$out")"
  done
  rm -rf "$W" "$HOME/.rolepod/session-locks"
  [ "$fail" -eq 0 ] && echo "  ✓ collision: a sibling-owned file denies in every mode; a disjoint file passes"
fi

if section "fleet"; then
  W=$(mktemp -d); mk_repo "$W/r" src/a.py 1
  printf '{"type":"assistant","timestamp":"2026-08-17T01:00:00.000Z","message":{"model":"claude-opus-5","content":[]}}\n' > "$W/lead-opus.jsonl"
  fleet() { # <mode> <script json string>
    local p
    p=$(python3 -I -c 'import json,sys; print(json.dumps({"cwd":sys.argv[1],"tool_name":"Workflow","transcript_path":sys.argv[2],"tool_input":{"script":sys.argv[3]}}))' "$W/r" "$W/lead-opus.jsonl" "$2")
    ( cd "$W/r" && run_hook workflow-tier-nudge.sh "$1" "$p" )
  }
  BARE='phase("Browse"); await parallel(B.map((b) => () => agent(b.prompt, {label: `browse:${b.key}`})))'
  PLAN='phase("Run"); await parallel(T.map((t) => () => agent(`Execute docs/rolepod/plans/p.md task ${t}`, {label: `task:${t}`})))'
  PLANMODEL='phase("Run"); await parallel(T.map((t) => () => agent(`Execute docs/rolepod/plans/p.md task ${t}`, {model: "sonnet", label: `task:${t}`}))); await parallel(U.map((u) => () => agent(`Execute docs/rolepod/plans/p.md other ${u}`, {label: `o:${u}`})))'
  PLANWRITE='phase("Implement"); await agent("Execute docs/rolepod/plans/p.md task 1", {label: "t1"})'
  STRONG='phase("Verify"); await parallel(F.map((f) => () => agent(`v ${f}`, {model: "opus", label: `v:${f}`})))'
  WRITER='phase("Implement"); await agent("do it", {label: "impl"})'
  for mode in lite standard full; do
    expect "bare-fanout/$mode" deny "$(verdict "$(fleet "$mode" "$BARE")")"
    expect "strong-fanout/$mode" deny "$(verdict "$(fleet "$mode" "$STRONG")")"
    expect "bare-writer/$mode" deny "$(verdict "$(fleet "$mode" "$WRITER")")"
    expect "plan-fleet/$mode" silent "$(verdict "$(fleet "$mode" "$PLAN")")"
    expect "plan-fleet-writer/$mode" silent "$(verdict "$(fleet "$mode" "$PLANWRITE")")"
    expect "plan-fleet-with-model/$mode" deny "$(verdict "$(fleet "$mode" "$PLANMODEL")")"
  done
  rm -rf "$W"
  [ "$fail" -eq 0 ] && echo "  ✓ fleet: 3 deny gates x 3 modes; plan fleet exempt; a model: call voids the exemption"
fi

if section "nudge"; then
  W=$(mktemp -d); mk_repo "$W/r" src/a.py 3
  ( cd "$W/r" && git commit -q -m init )
  LOCKH=$(cd "$W/r" && printf '%s' "$(pwd -P)" | { shasum -a 256 2>/dev/null || sha256sum; } | awk '{print $1}' | head -c 16)
  for mode in lite standard full; do
    # route nudge: a commission with no tier
    out=$(cd "$W/r" && run_hook claim-verify-nudge.sh "$mode" '{"prompt":"fix the login button"}')
    case "$out" in *"commission with no tier"*) ;; *) echo "  ✗ route-nudge/$mode: ${out:0:80}"; fail=$((fail+1)) ;; esac
    # loop breaker: the 2nd identical failing command draws the note
    export RUN_SID="lb-$mode-$$"
    fl='{"tool_name":"Bash","tool_input":{"command":"pytest t.py"},"tool_response":{"exitCode":1,"stderr":"boom"}}'
    ( cd "$W/r" && run_hook fix-loop-breaker.sh "$mode" "$fl" ) >/dev/null
    out=$(cd "$W/r" && run_hook fix-loop-breaker.sh "$mode" "$fl")
    case "$out" in *"LOOP BREAKER"*) ;; *) echo "  ✗ loop-breaker/$mode: ${out:0:80}"; fail=$((fail+1)) ;; esac
    unset RUN_SID
    # subagent-core text
    out=$(run_hook subagent-core.sh "$mode" '{"hook_event_name":"SubagentStart","agent_id":"a1","agent_type":"general-purpose"}')
    case "$out" in *"rolepod sub-agent core"*) ;; *) echo "  ✗ subagent-core/$mode: ${out:0:80}"; fail=$((fail+1)) ;; esac
    # sibling warning at SessionStart
    mkdir -p "$HOME/.rolepod/session-locks/$LOCKH"
    printf 'claude\n1' > "$HOME/.rolepod/session-locks/$LOCKH/sib.lock"
    out=$(cd "$W/r" && run_hook session-lifecycle.sh "$mode" "{\"cwd\":\"$W/r\"}" 2>&1)
    case "$out" in *ibling*|*"another"*|*"session"*) ;; *) echo "  ✗ sibling-warning/$mode: ${out:0:80}"; fail=$((fail+1)) ;; esac
    rm -rf "$HOME/.rolepod/session-locks"
    # project context
    out=$(cd "$W/r" && run_hook project-context-loader.sh "$mode" "{\"cwd\":\"$W/r\"}")
    case "$out" in *"Recent:"*) ;; *) echo "  ✗ project-context/$mode: ${out:0:80}"; fail=$((fail+1)) ;; esac
    # gate-reminder: a high-risk edit is silent in every mode (the R4 review is the track-end review)
    mkdir -p "$W/r/src/auth"; : > "$W/r/src/auth/login.py"
    out=$(cd "$W/r" && run_hook gate-reminder.sh "$mode" "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$W/r/src/auth/login.py\"}}")
    [ -z "$out" ] || { echo "  ✗ gate-reminder/$mode not silent: ${out:0:80}"; fail=$((fail+1)); }
  done
  rm -rf "$W"
  [ "$fail" -eq 0 ] && echo "  ✓ nudge: route, loop breaker, subagent-core, sibling, context speak in every mode; gate-reminder is silent on a high-risk edit"
fi

if section "session-start"; then
  W=$(mktemp -d); mk_repo "$W/r" src/a.py 3
  cp -R "$REPO_DIR/hooks" "$W/hooks"
  [ -f "$W/hooks/always-on-core.md" ] || cp "$REPO_DIR/plugins/rolepod/hooks/always-on-core.md" "$W/hooks/always-on-core.md"
  # The loader cuts a commit subject to one line and drops manifest churn, so the
  # project context is padded with five long hot-file paths (~620 chars) to pass the 9500 cap.
  seg=$(head -c 200 /dev/zero | tr '\0' 'p')
  for i in 1 2 3 4 5; do mkdir -p "$W/r/src/$seg$i/$seg/$seg"; : > "$W/r/src/$seg$i/$seg/$seg/f.py"; done
  ( cd "$W/r" && git add -A && git commit -q -m "$(head -c 3000 /dev/zero | tr '\0' 'x')" )
  CORE_LAST=$(grep -v '^[[:space:]]*$' "$W/hooks/always-on-core.md" | tail -n 1)
  for mode in lite standard; do
    mkdir -p "$HOME/.rolepod/session-profiles/claude"
    old="$HOME/.rolepod/session-profiles/claude/old-$mode.mode"; new="$HOME/.rolepod/session-profiles/claude/new-$mode.mode"
    printf 'lite\nproject\n' > "$old"; printf 'lite\nproject\n' > "$new"
    touch -t "$(date -v-20d +%Y%m%d%H%M 2>/dev/null || date -d '20 days ago' +%Y%m%d%H%M)" "$old"
    mkdir -p "$W/r/.rolepod"; printf '{"workflow":{"mode":"%s"}}\n' "$mode" > "$W/r/.rolepod/config.json"
    out=$(printf '{"cwd":"%s","session_id":"ss-%s","source":"startup"}' "$W/r" "$mode" | ROLEPOD_PROJECT_ROOT="$W/r" bash "$W/hooks/session-start.sh" --cli claude 2>/dev/null)
    ctx=$(printf '%s' "$out" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"],end="")')
    n=$(printf '%s' "$out" | python3 -I -c 'import json,sys; print(len(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]))')
    [ "$n" -le 9500 ] && [ "$n" -gt 1000 ] || { echo "  ✗ session-start/$mode: additionalContext $n chars"; fail=$((fail+1)); }
    case "$ctx" in *"# rolepod — always-on judgment"*) ;; *) echo "  ✗ session-start/$mode: core heading missing"; fail=$((fail+1)) ;; esac
    case "$ctx" in *"$CORE_LAST"*) ;; *) echo "  ✗ session-start/$mode: last core line missing"; fail=$((fail+1)) ;; esac
    [ ! -e "$old" ] || { echo "  ✗ session-start/$mode: 20-day-old profile not pruned"; fail=$((fail+1)); }
    [ -e "$new" ] || { echo "  ✗ session-start/$mode: fresh profile pruned"; fail=$((fail+1)); }
    [ -n "$(find "$HOME/.rolepod/session-locks" -type f -name "ss-$mode*" 2>/dev/null | head -n 1)" ] || { echo "  ✗ session-start/$mode: no session lock written"; fail=$((fail+1)); }
  done
  case "$ctx" in *"truncated to 9500"*) ;; *) echo "  ✗ session-start: no truncation note"; fail=$((fail+1)) ;; esac
  rm -rf "$W"
  [ "$fail" -eq 0 ] && echo "  ✓ session-start: context capped at 9500 with core first; 14-day-old profiles pruned"
fi

if section "parity"; then
  # shellcheck source=/dev/null
  . "$REPO_DIR/hooks/lib/session-mode.sh"
  # GATE_ACTION in the opencode plugin must match rolepod_gate_action, row by row.
  js=$(node --input-type=module -e "
    const src = (await import('node:fs')).readFileSync('$REPO_DIR/adapters/opencode/plugin/rolepod.js', 'utf8')
    const m = src.match(/const GATE_ACTION = (\{[\s\S]*?\n\})/)
    if (!m) process.exit(2)
    const t = eval('(' + m[1] + ')')
    for (const [id, row] of Object.entries(t)) console.log(id + ' ' + row.join(' '))
  " 2>/dev/null) || { echo "  ✗ parity: GATE_ACTION not found in rolepod.js"; fail=$((fail+1)); js=""; }
  n=0
  while read -r gate l s f; do
    [ -n "$gate" ] || continue
    i=0
    for mode in lite standard full; do
      i=$((i+1)); exp=$(ROLEPOD_SESSION_MODE=$mode rolepod_gate_action "$gate")
      got=$(echo "$l $s $f" | cut -d' ' -f$i); n=$((n+1))
      [ "$got" = "$exp" ] || { echo "  ✗ parity $gate/$mode: js $got bash $exp"; fail=$((fail+1)); }
    done
  done <<< "$js"
  [ "$n" -ge 6 ] || { echo "  ✗ parity: only $n cells compared"; fail=$((fail+1)); }
  [ "$fail" -eq 0 ] && echo "  ✓ parity: opencode GATE_ACTION matches rolepod_gate_action ($n cells)"
fi

echo "  · $RAN_SECTIONS of $TOTAL_SECTIONS sections ran"
if [ -n "${ROLEPOD_CASE:-}" ] && [ "$RAN_SECTIONS" -eq 0 ]; then
  echo "  ✗ ROLEPOD_CASE='$ROLEPOD_CASE' matched no section banner"
  fail=$((fail+1))
fi
if [ "$fail" -eq 0 ]; then echo "  ✓ pass"; exit 0; else echo "  ✗ $fail failure(s)"; exit 1; fi
