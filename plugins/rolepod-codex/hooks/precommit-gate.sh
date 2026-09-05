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
#                                  → session evidence (≥1 test edit or ≥1
#                                    reviewer dispatch) → AUTO-PASS + log +
#                                    additionalContext note. No evidence →
#                                    HARD block (permissionDecision: deny).
#
# Env overrides:
#   ROLEPOD_GATES_HARD=1   — escalate normal code from SOFT warn to HARD block
#                            (recovers pre-change behavior across the board).
#   ROLEPOD_GATES_SOFT=1   — suppress ALL warnings entirely (silent).
#   ROLEPOD_GATES_PASSED=1 / [gates: pass] — legacy bypass markers. Never
#                            required: evidence auto-passes without them, and
#                            without evidence they were always ignored. The
#                            env-prefix form is also a command shape the
#                            platform's own permission layer reads as gate
#                            circumvention — nothing should prescribe it.
set -euo pipefail

# Per-repo risk-path override: <git-root>/.rolepod/risk-paths — one ERE per
# line; bare/+ lines ADD high-risk patterns, - lines EXCLUDE paths from the
# built-in match, # comments. Absent file = built-ins only (fail-open).
# stdin: candidate paths (one per line); $1: built-in ERE → stdout: hits.
risk_filter() {
  _rf_cfg="$(git rev-parse --show-toplevel 2>/dev/null)/.rolepod/risk-paths"
  _rf_add=""; _rf_excl=""
  if [ -f "$_rf_cfg" ]; then
    _rf_add=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e '/^-/d' -e 's/^+//' "$_rf_cfg" 2>/dev/null | paste -sd'|' - 2>/dev/null || true)
    _rf_excl=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$_rf_cfg" 2>/dev/null | grep '^-' 2>/dev/null | sed 's/^-//' | paste -sd'|' - 2>/dev/null || true)
  fi
  _rf_in=$(cat)
  _rf_hits=$(printf '%s\n' "$_rf_in" | grep -iE "$1" 2>/dev/null || true)
  if [ -n "$_rf_add" ]; then
    _rf_hits="$_rf_hits
$(printf '%s\n' "$_rf_in" | grep -iE "$_rf_add" 2>/dev/null || true)"
  fi
  _rf_hits=$(printf '%s\n' "$_rf_hits" | sed '/^$/d' | sort -u)
  if [ -n "$_rf_excl" ]; then
    _rf_hits=$(printf '%s\n' "$_rf_hits" | grep -ivE "$_rf_excl" 2>/dev/null || true)
  fi
  printf '%s\n' "$_rf_hits" | sed '/^$/d'
}

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

# ONE python3 pass for tool_name + commit token-walk + command (was 3
# spawns — ~30ms on EVERY Bash call, the hottest PreToolUse matcher).
# Field order matters: tool + is_commit first via read -r; command LAST,
# slurped with $(cat) so multi-line commit messages survive intact and an
# empty trailing field cannot EOF-fail the read under set -e. The walk
# matches flag-separated forms (`git -C . commit`, `git -c k=v commit`).
PARSED=$(printf '%s' "$INPUT" | python3 -c "
import json, os, shlex, sys
tool = ''
cmd = ''
hit = 0
try:
    d = json.load(sys.stdin)
    tool = d.get('tool_name', '') or ''
    cmd = (d.get('tool_input', {}) or {}).get('command', '') or ''
    try:
        toks = shlex.split(cmd)
    except ValueError:
        toks = cmd.split()
    VALUE_OPTS = {'-C', '--git-dir', '--work-tree', '--namespace', '--exec-path'}
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
except Exception:
    pass
print(tool)
print(hit)
print(cmd)
" 2>/dev/null) || exit 0
{ read -r TOOL; read -r IS_COMMIT; CMD=$(cat); } <<EOF
$PARSED
EOF

# Belt-and-suspenders: hooks.json registers matcher "Bash" only.
[ "$TOOL" = "Bash" ] || exit 0
[ "$IS_COMMIT" = "1" ] || exit 0

if [ "${ROLEPOD_GATES_SOFT:-0}" = "1" ]; then
  rolepod_log_bypass "precommit-gate" "ROLEPOD_GATES_SOFT"
  exit 0
fi

# Compute diff stats — skip gate if trivial
DIFF_STAT=$(git diff --cached --numstat 2>/dev/null || echo "")
if [ -z "$DIFF_STAT" ]; then
  # No staged changes — let git's own error fire
  exit 0
fi

FILES_CHANGED=$(echo "$DIFF_STAT" | wc -l | tr -d ' ')

# Private working docs (v2.80.0): everything rolepod writes under
# docs/rolepod/ — specs, plans, cohesion contracts, maps, hand-offs — is
# confidential by default and never enters a commit. `git add -A` sweeps it
# in silently; this is the mechanical stop. A repo that WANTS them tracked
# creates <git-root>/.rolepod/docs-tracked (an explicit, reviewable choice).
_pd_root="$(git rev-parse --show-toplevel 2>/dev/null)"
PRIVATE_DOCS=$( { git diff --cached --name-only 2>/dev/null | grep -E '^docs/rolepod/' || true; } | head -5 | tr '\n' ' ' | sed 's/ *$//')
if [ -n "$PRIVATE_DOCS" ] && [ ! -f "$_pd_root/.rolepod/docs-tracked" ]; then
  ROLEPOD_HOOK_MSG="precommit-gate BLOCKED — private working docs are staged: $PRIVATE_DOCS. docs/rolepod/ (specs / plans / cohesion contracts / maps / hand-offs) is confidential by default and never committed. Unstage them (git restore --staged docs/rolepod) and make sure .gitignore lists docs/rolepod/ (the skills add it on first save). If this repository deliberately tracks them, create .rolepod/docs-tracked and commit again." python3 -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || echo '{}'
  exit 0
fi
LINES_CHANGED=$(echo "$DIFF_STAT" | awk '{a+=$1; b+=$2} END {print a+b}')
LINES_CHANGED=${LINES_CHANGED:-0}

# High-risk path detection
# High-risk path detection — anchored to path segments (avoids matching e.g.
# `session_state.py` for the hooks helper, where "session" is part of the
# identifier not a security surface).
HIGH_RISK=$(echo "$DIFF_STAT" | awk '{print $3}' | risk_filter '(^|/|_)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices|deletion|deletions|erasure|gdpr|security)(/|\.|_|$)' | head -1 || true)

# Content-based high-risk (v2.46.0) — money-movement primitives in ADDED
# lines of non-test staged files. Catches refund/payout logic living in a
# generically named file (closure-service.ts, date-utils.ts) the path regex
# cannot see — the shape of 2 of the 4 escaped CourtBook money bugs.
if [ -z "$HIGH_RISK" ]; then
  CONTENT_RISK=$(git diff --cached -U0 2>/dev/null \
    | awk '/^\+\+\+ /{f=$2} /^\+[^+]/{print f "\t" $0}' \
    | grep -vE '(^|/)(test|tests|spec|specs|__tests__|fixtures)(/|\.|_)|_test\.|\.test\.|_spec\.|\.spec\.' \
    | grep -m1 -iE '(refund|payout|chargeback|settlement)' || true)
  [ -n "$CONTENT_RISK" ] && HIGH_RISK="staged content: money-movement term (refund/payout/chargeback/settlement)"
fi
# Money / auth subset of high-risk (v2.78.0): billing · payments · credits ·
# auth · crypto · secrets · data deletion — plus the content-based money hit.
# A missed bug here costs real money or a breach, so when a cross-family pool
# is enabled these need BOTH passes: the external (decorrelated) AND the
# internal strong reviewer (project-context depth). migration / permission /
# token / webhook / security-named paths stay external-is-the-pass.
MONEY_RISK=""
if [ -n "$HIGH_RISK" ]; then
  MONEY_RISK=$(echo "$DIFF_STAT" | awk '{print $3}' | grep -iE '(^|/|_)(auth|authn|authz|authentication|authorization|billing|payment|payments|credit|credits|secret|secrets|crypto|cryptography|oauth|jwt|sso|saml|stripe|paypal|charge|charges|invoice|invoices|deletion|deletions|erasure|gdpr)(/|\.|_|$)' | head -1 || true)
  case "$HIGH_RISK" in "staged content: money-movement"*) MONEY_RISK="$HIGH_RISK" ;; esac
fi

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
# v2.47.0: evidence is WINDOWED to "since the last commit" (git's own clock —
# unaffected by denied attempts, hook-less commits, or a 12-day session) and
# includes the session's subagent transcripts (Workflow / Agent fleets write
# the tests in delegated sessions). See session_state.count_all.
SESSION_STATE="$(dirname "$0")/lib/session_state.py"
TEST_EDITS=0
HIGH_RISK_EDITS=0
REVIEWERS=0
STRONG_REVIEWERS=0
SINCE_EPOCH=$(git log -1 --format=%ct 2>/dev/null || true)
SINCE_HUMAN=$(git log -1 --format=%cd --date=format:'%Y-%m-%d %H:%M' 2>/dev/null || true)
[ -n "$SINCE_HUMAN" ] && SINCE_HUMAN="since last commit $SINCE_HUMAN" || SINCE_HUMAN="whole session (no commit yet)"
if [ -f "$SESSION_STATE" ] && command -v python3 >/dev/null 2>&1; then
  # ONE transcript scan for all four counts (see gate-reminder.sh).
  COUNTS=$(printf '%s' "$INPUT" | python3 "$SESSION_STATE" count-all "$SINCE_EPOCH" 2>/dev/null || echo "0 0 0 0")
  read -r TEST_EDITS HIGH_RISK_EDITS REVIEWERS STRONG_REVIEWERS <<< "$COUNTS"
elif command -v python3 >/dev/null 2>&1; then
  # Renders without lib/session_state.py (codex + the non-Claude adapters):
  # their transcripts are not Claude-JSONL, so reviewer evidence comes from
  # the SubagentStop dispatch-proof log written by subagent-model-log.sh.
  # Only reviewer counts exist on this path — test/high-risk edit evidence
  # needs transcript parsing, and the HARD paths that consume those counts
  # cannot fire when both sides read as 0. Strong class is decided by
  # agent_type alone: the logged model is hook-reported with unverified
  # provenance (may be the parent's), and the agent TOMLs pin strong
  # reviewers to the strong model anyway.
  PHASE_LOG="$(git rev-parse --show-toplevel 2>/dev/null)/.rolepod/evidence/phase-log.jsonl"
  if [ -f "$PHASE_LOG" ]; then
    RCOUNTS=$(python3 -c '
import json, sys, datetime
since, path = sys.argv[1], sys.argv[2]
cut = None
if since:
    try:
        cut = datetime.datetime.fromtimestamp(int(since), datetime.timezone.utc)
    except Exception:
        cut = None
REVIEWERS = {"qa-tester", "security-engineer", "universal-reviewer", "code-reviewer"}
STRONG = {"security-engineer", "universal-reviewer", "code-reviewer"}
r = s = 0
try:
    with open(path) as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            if d.get("phase") != "dispatch-proof":
                continue
            if cut is not None:
                try:
                    if datetime.datetime.fromisoformat(d.get("ts", "")) < cut:
                        continue
                except Exception:
                    continue
            name = (d.get("agent_type") or "").strip().rsplit(":", 1)[-1]
            if name.startswith("rolepod-"):
                name = name[len("rolepod-"):]
            if name in REVIEWERS:
                r += 1
            if name in STRONG:
                s += 1
except OSError:
    pass
print(r, s)
' "$SINCE_EPOCH" "$PHASE_LOG" 2>/dev/null || echo "0 0")
    read -r REVIEWERS STRONG_REVIEWERS <<< "$RCOUNTS"
  fi
fi
TEST_EDITS=${TEST_EDITS:-0}
HIGH_RISK_EDITS=${HIGH_RISK_EDITS:-0}
REVIEWERS=${REVIEWERS:-0}
STRONG_REVIEWERS=${STRONG_REVIEWERS:-0}

# External strong pass (satellite-first, v2.61.0) — cross-family reviews are
# plain Bash `codex exec` / `gemini -p` / `claude -p` calls, invisible to
# transcript parsing on EVERY CLI. review-code's evidence anchor appends a
# phase-log "review" line with reviewer:"external" pointing at the saved raw
# output; count it as a strong reviewer only when that file really exists
# inside .rolepod/evidence/ and is >= 500 bytes — a bare claim without the
# artifact is ignored (claim-based evidence is what this gate exists to stop).
EV_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)/.rolepod/evidence"
if [ -f "$EV_ROOT/phase-log.jsonl" ] && command -v python3 >/dev/null 2>&1; then
  XREV=$(python3 -c '
import json, os, sys, datetime
since, ev = sys.argv[1], sys.argv[2]
cut = None
if since:
    try:
        cut = datetime.datetime.fromtimestamp(int(since), datetime.timezone.utc)
    except Exception:
        cut = None
n = 0
try:
    with open(os.path.join(ev, "phase-log.jsonl")) as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            if d.get("phase") != "review" or d.get("reviewer") != "external":
                continue
            if cut is not None:
                try:
                    ts = datetime.datetime.fromisoformat(
                        (d.get("ts") or "").replace("Z", "+00:00"))
                    if ts.tzinfo is None:
                        ts = ts.replace(tzinfo=datetime.timezone.utc)
                    if ts < cut:
                        continue
                except Exception:
                    continue
            raw = d.get("raw") or ""
            if not raw or raw.startswith("/") or ".." in raw:
                continue
            try:
                if os.path.getsize(os.path.join(ev, raw)) >= 500:
                    n += 1
            except OSError:
                continue
except OSError:
    pass
print(n)
' "$SINCE_EPOCH" "$EV_ROOT" 2>/dev/null || echo 0)
  if [ "${XREV:-0}" -gt 0 ] 2>/dev/null; then
    REVIEWERS=$((REVIEWERS + XREV))
    STRONG_REVIEWERS=$((STRONG_REVIEWERS + XREV))
  fi
fi

# Satellite-first, ENFORCED (v2.76.0). Measured before this: 210 dispatches,
# 0 anchored cross-family passes — the internal strong reviewer was one
# Agent call away and counted the same, so it always won. Now, on a
# high-risk diff, an internal strong reviewer clears the gate only when the
# cross-family pool was actually tried: an anchored external pass (XREV), OR
# an `external-fail` phase-log line since the last commit (the runner tried
# every usable member and they failed / the pool is empty). Machines with no
# usable cross-family CLI (runner --pool-names prints nothing) keep the
# internal path untouched. Lead CLI unknown → cannot exclude its family →
# no tightening (fail-open).
XFAM_HELD=""
INTERNAL_STRONG=$(( STRONG_REVIEWERS - ${XREV:-0} ))
XFAM_RUNNER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/cross-family.sh"
[ -f "$XFAM_RUNNER" ] || XFAM_RUNNER="$HOME/.rolepod/bin/cross-family.sh"
XFAM_LEAD="${ROLEPOD_LEAD_CLI:-}"
[ -z "$XFAM_LEAD" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && XFAM_LEAD="claude"
XFAM_POOL=""; XFAM_FAILS=0
# Detached runner job still running for this repo (v2.79.0): the hold reason
# must say "wait / --collect", not "run the runner" (it is already running).
XFAM_RUNNING=""
if [ -d "$EV_ROOT/external/jobs" ]; then
  for _jd in "$EV_ROOT"/external/jobs/*/; do
    [ -d "$_jd" ] || continue; [ -f "$_jd/status" ] && continue
    _jp=$(cat "$_jd/pid" 2>/dev/null); case "$_jp" in ''|*[!0-9]*) continue ;; esac
    kill -0 "$_jp" 2>/dev/null || continue
    ps -o command= -p "$_jp" 2>/dev/null | grep -q 'cross-family' || continue   # pid reused by something else = dead job
    _js=$(cat "$_jd/started" 2>/dev/null || echo 0); _jm=$(( ($(date +%s) - _js) / 60 ))
    XFAM_RUNNING="$(basename "$_jd") (running ${_jm} min)"
  done
fi
# Money / auth + enabled pool + external anchored but NO internal strong →
# hold: this surface needs BOTH passes (v2.78.0). External failed (logged) →
# internal alone clears, as everywhere else.
if [ -n "$MONEY_RISK" ] && [ -n "$XFAM_LEAD" ] && [ -f "$XFAM_RUNNER" ] && [ "${XREV:-0}" -gt 0 ] && [ "$INTERNAL_STRONG" -eq 0 ]; then
  XFAM_POOL=$(bash "$XFAM_RUNNER" --lead "$XFAM_LEAD" --pool-names 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
  if [ -n "$XFAM_POOL" ]; then
    XFAM_HELD="money / auth surface ($MONEY_RISK): the cross-family pass is anchored but no INTERNAL strong reviewer ran since the last commit — this surface needs BOTH: dispatch rolepod:security-engineer (or rolepod:universal-reviewer) via the Agent tool on the same frozen diff (project-context depth; the external gave decorrelation). Migration / permission / token paths need only the external. "
    STRONG_REVIEWERS=0
  fi
fi
if [ -z "$XFAM_HELD" ] && [ -n "$HIGH_RISK" ] && [ -n "$XFAM_LEAD" ] && [ -f "$XFAM_RUNNER" ] && [ "${XREV:-0}" -eq 0 ] && [ "$STRONG_REVIEWERS" -gt 0 ]; then
  XFAM_POOL=$(bash "$XFAM_RUNNER" --lead "$XFAM_LEAD" --pool-names 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
  XFAM_FAILS=0
  if [ -n "$XFAM_POOL" ] && [ -f "$EV_ROOT/phase-log.jsonl" ]; then
    XFAM_FAILS=$(python3 -c '
import json, sys, datetime
since, path = sys.argv[1], sys.argv[2]
cut = None
if since:
    try:
        cut = datetime.datetime.fromtimestamp(int(since), datetime.timezone.utc)
    except Exception:
        cut = None
n = 0
try:
    for line in open(path):
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("phase") != "external-fail":
            continue
        if cut is not None:
            try:
                ts = datetime.datetime.fromisoformat((d.get("ts") or "").replace("Z", "+00:00"))
                if ts.tzinfo is None:
                    ts = ts.replace(tzinfo=datetime.timezone.utc)
                if ts < cut:
                    continue
            except Exception:
                continue
        n += 1
except OSError:
    pass
print(n)
' "$SINCE_EPOCH" "$EV_ROOT/phase-log.jsonl" 2>/dev/null || echo 0)
  fi
  if [ -n "$XFAM_POOL" ] && [ "${XFAM_FAILS:-0}" -eq 0 ] 2>/dev/null; then
    XFAM_HELD="cross-family pool is usable ($XFAM_POOL) but no anchored external pass and no recorded external failure since the last commit — the $STRONG_REVIEWERS internal strong reviewer dispatch(es) do NOT clear a high-risk diff while a different model family is available. ${XFAM_RUNNING:+A detached external job is ALREADY RUNNING: $XFAM_RUNNING — wait for it (rolepod-cross-family --collect <job-id>) then retry the commit; do not start another. }${XFAM_RUNNING:-Run: rolepod-cross-family --kind review --brief <brief.md> --attach <diff> --detach (or scripts/cross-family.sh in the plugin tree; add --lead $XFAM_LEAD outside a hook); it anchors the pass itself — --collect <job-id> waits for the receipt.} Every member failing (exit 3) or an empty pool (exit 4) is logged and then the internal reviewer counts.${MONEY_RISK:+ Money / auth surface: keep the internal strong reviewer too — this surface needs BOTH passes.} "
    STRONG_REVIEWERS=0
  fi
fi

# Legacy bypass markers are detected only so the deny reason can explain they
# no longer do anything on their own: evidence auto-passes without a marker
# (below), and without evidence a marker was always ignored — a blocked model
# must not self-release by echoing it in its very next tool call
# ("claim-based bypass").
BYPASS_REQUESTED=0
echo "$CMD" | grep -qE 'ROLEPOD_GATES_PASSED=1' && BYPASS_REQUESTED=1
echo "$CMD" | grep -qE '\[gates:[[:space:]]*pass\]' && BYPASS_REQUESTED=1
BYPASS_IGNORED=""
if [ "$BYPASS_REQUESTED" -eq 1 ] && [ "$TEST_EDITS" -eq 0 ] && [ "$REVIEWERS" -eq 0 ]; then
  BYPASS_IGNORED="Bypass marker present but IGNORED — session shows 0 test edits and 0 reviewer dispatches; markers are never honored without gate evidence. "
fi

# Build deny reason
REASON="precommit-gate BLOCKED. ${BYPASS_IGNORED}"
REASON+="Diff: $FILES_CHANGED files / $LINES_CHANGED lines / $LOGIC_COUNT logic lines. "
REASON+="Evidence ($SINCE_HUMAN, Lead + subagent transcripts): $TEST_EDITS test edits / $HIGH_RISK_EDITS high-risk edits / $REVIEWERS reviewer dispatches ($STRONG_REVIEWERS strong). "
[ -n "$HIGH_RISK" ] && REASON+="HIGH-RISK path: $HIGH_RISK → mandatory qa-tester + security-engineer review. "
if [ "$HIGH_RISK_EDITS" -gt 0 ] && [ "$TEST_EDITS" -eq 0 ]; then
  REASON+="NO TEST EDITS in this session despite touching high-risk code — T-gate violation (T1: bug/feature/migration/auth/billing → test required). "
fi
[ -n "$XFAM_HELD" ] && REASON+="SATELLITE-FIRST: $XFAM_HELD"
[ -z "$XFAM_HELD" ] && [ -n "$XFAM_RUNNING" ] && [ -n "$HIGH_RISK" ] && [ "$STRONG_REVIEWERS" -eq 0 ] && REASON+="A detached cross-family job is still running: $XFAM_RUNNING — rolepod-cross-family --collect <job-id>, then retry. "
if [ -n "$HIGH_RISK" ] && [ "$STRONG_REVIEWERS" -eq 0 ] && [ -z "$XFAM_HELD" ]; then
  REASON+="NO STRONG ADVERSARIAL REVIEWER since the last commit — a high-risk diff clears ONLY on: a cross-family external strong review ANCHORED per review-code (raw output saved under .rolepod/evidence/external/ + the reviewer:external phase-log line — satellite-first, preferred); a security-engineer or universal-reviewer dispatch (Agent tool, a Workflow agent() call with that agentType, or on CLIs without transcript parsing a FINISHED reviewer subagent recorded by the SubagentStop dispatch log — wait for the reviewer to complete before retrying; the dispatch hook lifts Agent-tool ones to strong class whatever the Lead runs — do not pass a balanced model on them). Test edits and qa-tester are the test floor, not the review (a green suite has already shipped money bugs). "
fi
REASON+="Run gates explicitly: S1-S5 (simplicity) + T1-T6 (tests) + F1-F5 (failure-mode) — checklists: finish-work §1, check-work §6. "
REASON+="This commit auto-passes once evidence exists SINCE THE LAST COMMIT — HIGH-RISK diff: dispatch security-engineer or universal-reviewer; other blocks: write the failing test or dispatch a reviewer — then rerun the SAME git commit. No bypass marker, no env prefix."

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

# Evidence auto-pass — a would-block commit passes directly when the session
# already shows gate evidence. The marker round-trip this replaces added no
# security: a blocked model could echo the marker in its very next call, so
# the evidence check was always the real guard — and prescribing
# `ROLEPOD_GATES_PASSED=1 git commit` deadlocked against the platform's own
# permission layer, which reads that command shape as gate circumvention.
# Evidence is split by risk (v2.46.0):
#   HIGH-RISK diff  → only a STRONG-class adversarial reviewer dispatch
#     (security-engineer / universal-reviewer) clears it. Test edits and
#     qa-tester are the balanced test floor, not the review — CourtBook
#     proof: 672 green tests + opus impl still shipped 4 money bugs that
#     only the adversarial pass caught.
#   other HARD blocks (session risk edits w/o tests, env) → original OR
#     (≥1 test edit or ≥1 reviewer dispatch): delegated sessions route
#     test-writing into subagents whose edits land in the child transcript,
#     so a qa-tester dispatch is often the only evidence the Lead's own
#     transcript can show. Every auto-pass is logged and surfaced as context.
# Test-tampering lint (warn-only) — grep-able half of qa-tester's REJECT list.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT_WARN=""
if [ -f "$SCRIPT_DIR/test-diff-lint.sh" ]; then
  LINT_WARN=$(bash "$SCRIPT_DIR/test-diff-lint.sh" 2>/dev/null || true)
fi

AUTO_PASS=0
if [ "$HARD_BLOCK" -eq 1 ]; then
  if [ -n "$HIGH_RISK" ]; then
    [ "$STRONG_REVIEWERS" -gt 0 ] && AUTO_PASS=1
  elif [ "$TEST_EDITS" -gt 0 ] || [ "$REVIEWERS" -gt 0 ]; then
    AUTO_PASS=1
  fi
fi
if [ "$AUTO_PASS" -eq 1 ]; then
  mkdir -p "$HOME/.rolepod" 2>/dev/null || true
  # %.200s truncates by BYTES in bash printf. A commit message with any
  # multi-byte character got cut mid-codepoint and left invalid UTF-8 in the
  # machine-global log, which then crashed every reader of it. Slice in
  # python (characters) and flatten newlines so one commit can never corrupt
  # the log or break its one-entry-per-line shape.
  SAFE_CMD=$(ROLEPOD_BYPASS_CMD="$CMD" python3 -c "
import os, sys
sys.stdout.reconfigure(errors='replace')
sys.stdout.write(' '.join(os.environ.get('ROLEPOD_BYPASS_CMD', '').split())[:200])
" 2>/dev/null) || SAFE_CMD=""
  printf '%s auto-pass on evidence (tests=%s reviewers=%s strong=%s risk=%s): %s\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" "$TEST_EDITS" "$REVIEWERS" "$STRONG_REVIEWERS" "${HIGH_RISK:-none}" "$SAFE_CMD" \
    >> "$HOME/.rolepod/gate-bypass.log" 2>/dev/null || true
  NOTE="precommit-gate auto-passed on session evidence: $TEST_EDITS test edits / $REVIEWERS reviewer dispatches / $STRONG_REVIEWERS strong"
  [ -n "$HIGH_RISK" ] && NOTE+=" (HIGH-RISK path: $HIGH_RISK)"
  NOTE+=" ($SINCE_HUMAN). Evidence is per-window, not per-line — confirm S1-S5 / T1-T6 (finish-work §1) / F1-F5 (check-work §6) cover THIS change."
  [ -n "$LINT_WARN" ] && NOTE+=" | $LINT_WARN"
  ROLEPOD_HOOK_MSG="$NOTE" python3 -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || true
  exit 0
fi

if [ "$HARD_BLOCK" -eq 1 ]; then
  # Env-passed — quotes in the reason must not break the JSON emitter.
  [ -n "$LINT_WARN" ] && REASON+=" | $LINT_WARN"
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
WARN+="Recommend running S1-S5 (simplicity) + T1-T6 (tests) + F1-F5 (failure-mode) before commit — checklists: finish-work §1, check-work §6. "
WARN+="Set ROLEPOD_GATES_HARD=1 to enforce blocking on normal diffs."
[ -n "$LINT_WARN" ] && WARN+=" | $LINT_WARN"

ROLEPOD_HOOK_MSG="$WARN" python3 -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || true

exit 0
