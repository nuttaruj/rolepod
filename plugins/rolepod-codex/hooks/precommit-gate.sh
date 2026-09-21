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

# Detached cross-family job still running for this repo (v2.79.0): prints
# "<job-id> (running N min)" for a live one, else nothing. Liveness = pid
# alive AND still a cross-family process (a reused pid is a dead job).
# Shared by the commit hold and the tree-rewrite warning below;
# gate-reminder.sh carries the same walk (keep in parity).
xfam_running_job() {
  _xr_jobs="$(git rev-parse --show-toplevel 2>/dev/null)/.rolepod/evidence/external/jobs"
  [ -d "$_xr_jobs" ] || return 0
  _xr_out=""
  for _jd in "$_xr_jobs"/*/; do
    [ -d "$_jd" ] || continue; [ -f "$_jd/status" ] && continue
    _jp=$(cat "$_jd/pid" 2>/dev/null); case "$_jp" in ''|*[!0-9]*) continue ;; esac
    kill -0 "$_jp" 2>/dev/null || continue
    ps -o command= -p "$_jp" 2>/dev/null | grep -q 'cross-family' || continue
    _js=$(cat "$_jd/started" 2>/dev/null || echo 0); _jm=$(( ($(date +%s) - _js) / 60 ))
    _xr_out="$(basename "$_jd") (running ${_jm} min)"
  done
  printf '%s' "$_xr_out"
}

# Reviewer-dispatch count from phase-log.jsonl rows of one phase value
# (v2.144.0) — shared by two callers below: the non-Claude Lead path
# (dispatch-proof rows from Cursor Task / opencode task, v2.134/2.135) and
# the Claude nested-Agent backstop (below). Same base classification both
# times: qa-tester never counts (E2E verification, not the review floor —
# v2.148.4); security-engineer / universal-reviewer / code-reviewer are
# STRONG; a scout or writer-role row never counts (name in neither set).
#
# Claude nested-Agent case, precisely (round-1 review corrected the first
# cut of this comment, which overclaimed): session_state.count_all already
# discovers ONE level of nesting — a runner subagent's own Agent-tool call
# to a reviewer is a tool_use recorded in the RUNNER's own transcript file,
# and that file sits directly under the Lead's <session>/subagents/, which
# agent_transcripts() walks. Measured gap instead: agent_transcripts() caps
# at the 60 NEWEST subagent-transcript files in the window
# (session_state.py AGENT_TRANSCRIPT_CAP) — a session running a large fleet
# (many tickets, many named dispatches) since the last commit can push a
# real reviewer dispatch out of that cap, and the transcript scan silently
# reads 0. phase-log.jsonl is append-only with no such cap, so it backstops
# exactly that drop (plus any dispatch shape whose transcript never lands
# under the walked tree). MAX with the transcript scan, never summed.
#
# Hardening added after the same review: $4 REQUIRED provenance value
# ("" = no requirement, preserving the non-Claude path's existing,
# unchanged behavior) raises a bare `printf >> phase-log.jsonl` forgery to
# parity with the real writer's own field — not authentication, a
# determined agent can still add the key, but it closes the casual path
# the shipped test used to demonstrate. $5 "1" additionally requires a
# STRONG row's model to NOT be low-class (mirrors session_state.count_all's
# own LOW_CLASSES refusal — a named sonnet/haiku downgrade of a strong
# reviewer must not count as the adversarial pass); "" skips the check,
# preserving the non-Claude path's pre-existing, documented leniency
# (those rows are hook-reported with unverified provenance and the agent
# TOMLs pin the strong model anyway). $6 session_state.py path for the
# model-class lookup (only read when $5 is "1"). Fails CLOSED, not open:
# when $5 is "1" but the import fails (session_state.py present but
# broken — the call site already gates on the file existing), no row
# counts as strong rather than falling back to a permissive default.
#
# Accepted, NOT fixed here (out of this file's owned scope — flagged to
# the caller): phase-log.jsonl is repo-scoped, not session-scoped, same as
# every other phase-log-based evidence in this file (XREV, external-fail,
# the pre-existing dispatch-proof path) — a second Claude session sharing
# this worktree gets the same repo-wide credit. Narrowing this needs a
# session_id field on the "dispatch" row, written by dispatch-auto-log.sh
# (not owned by this change).
#
# $1 phase value, $2 since-epoch (unix seconds; "" = no window), $3 path.
# stdout: "<reviewers> <strong>".
phase_log_reviewer_count() {
  _pr_phase="$1"; _pr_since="$2"; _pr_path="$3"; _pr_prov="${4:-}"; _pr_strict="${5:-}"; _pr_ss="${6:-}"
  [ -f "$_pr_path" ] || { printf '0 0\n'; return; }
  python3 -I -c '
import json, os, sys, datetime
phase, since, path, prov, strict, ss_path = (sys.argv + [""] * 6)[1:7]
cut = None
if since:
    try:
        cut = datetime.datetime.fromtimestamp(int(since), datetime.timezone.utc)
    except Exception:
        cut = None
REVIEWERS = {"security-engineer", "universal-reviewer", "code-reviewer"}   # qa-tester = E2E verification, never the review floor (v2.148.4)
STRONG = {"security-engineer", "universal-reviewer", "code-reviewer"}
model_class = lambda m: "unknown"
LOW_CLASSES = set()
ss_ok = False
if strict == "1" and ss_path:
    try:
        sys.path.insert(0, os.path.dirname(ss_path))
        import session_state as ss
        model_class = ss.model_class
        LOW_CLASSES = ss.LOW_CLASSES
        ss_ok = True
    except Exception:
        pass
r = s = 0
try:
    with open(path) as f:
        for line in f:
            try:
                d = json.loads(line)
                if not isinstance(d, dict):
                    continue
                if d.get("phase") != phase:
                    continue
                if prov and d.get("provenance") != prov:
                    continue
                if cut is not None:
                    ts = datetime.datetime.fromisoformat((d.get("ts") or "").replace("Z", "+00:00"))
                    if ts.tzinfo is None or ts < cut:
                        continue
                at = d.get("agent_type")
                name = (at.strip() if isinstance(at, str) else "").rsplit(":", 1)[-1]
                if name.startswith("rolepod-"):
                    name = name[len("rolepod-"):]
                if name in REVIEWERS:
                    r += 1
                if name in STRONG and (strict != "1" or (ss_ok and model_class(d.get("model")) not in LOW_CLASSES)):
                    s += 1
            except Exception:
                continue
except OSError:
    pass
print(r, s)
' "$_pr_phase" "$_pr_since" "$_pr_path" "$_pr_prov" "$_pr_strict" "$_pr_ss" 2>/dev/null || echo "0 0"
}

INPUT=$(cat 2>/dev/null || echo '{}')

# ONE python3 pass for tool_name + commit token-walk + command (was 3
# spawns — ~30ms on EVERY Bash call, the hottest PreToolUse matcher).
# Field order matters: tool + is_commit first via read -r; command LAST,
# slurped with $(cat) so multi-line commit messages survive intact and an
# empty trailing field cannot EOF-fail the read under set -e. The walk
# matches flag-separated forms (`git -C . commit`, `git -c k=v commit`).
PARSED=$(printf '%s' "$INPUT" | python3 -I -c "
import json, os, shlex, sys
tool = ''
cmd = ''
hit = 0
mut = ''
# Tree-rewriting subcommands (v2.93.0): warned about while a detached
# cross-family review is running. stash list/show and a mixed/soft reset
# touch nothing the reviewer reads.
MUT = {'stash', 'reset', 'checkout', 'switch', 'restore', 'rebase', 'merge', 'cherry-pick', 'clean', 'pull'}
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
            if j < len(toks) and toks[j] in MUT and not mut:
                sub = toks[j]
                nxt = toks[j + 1] if j + 1 < len(toks) else ''
                if sub == 'stash' and nxt in ('list', 'show'):
                    pass
                elif sub == 'reset' and not any(t in ('--hard', '--merge', '--keep') for t in toks[j:]):
                    pass
                else:
                    mut = sub
except Exception:
    pass
print(tool)
print(mut)
print(hit)
print(cmd)
" 2>/dev/null) || exit 0
{ read -r TOOL; read -r MUTATES; read -r IS_COMMIT; CMD=$(cat); } <<EOF
$PARSED
EOF

# Belt-and-suspenders: hooks.json registers matcher "Bash" only.
[ "$TOOL" = "Bash" ] || exit 0
if [ "$IS_COMMIT" != "1" ]; then
  # Tree rewrite while a review is in flight (v2.93.0): stash / reset --hard /
  # checkout / … empties or moves the tree a running cross-family job reads
  # live → its verdict is an artifact and the job re-runs. Advisory only.
  [ -n "$MUTATES" ] || exit 0
  [ "${ROLEPOD_GATES_SOFT:-0}" = "1" ] && exit 0
  _mj="$(xfam_running_job)"; [ -n "$_mj" ] || exit 0
  ROLEPOD_HOOK_MSG="⏸ REVIEW IN FLIGHT: cross-family job $_mj reads this tree live — \`git $MUTATES\` rewrites it, so that verdict becomes an artifact and the job re-runs. Fix: \`rolepod-cross-family --collect ${_mj%% *}\` first, then \`git $MUTATES\`. Exception: a red-proof revert goes in a throwaway git worktree, not a stash here; a dead job → --collect says so and this line stops." python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || echo '{}'
  exit 0
fi

if [ "${ROLEPOD_GATES_SOFT:-0}" = "1" ]; then
  rolepod_log_bypass "precommit-gate" "ROLEPOD_GATES_SOFT"
  exit 0
fi

# `git add … && git commit` or `git commit -a` in ONE command (v2.134.1): at hook
# time nothing is staged yet, so the index is empty and the gate used to exit 0
# — measured live on every CLI. In that shape the gate reads the working tree
# (tracked changes vs HEAD + untracked files) instead of the index.
GIT_DIFF_BASE=$(ROLEPOD_GATE_CMD="$CMD" python3 -I -c '
import os, shlex
cmd = os.environ.get("ROLEPOD_GATE_CMD", "")
try:
    toks = shlex.split(cmd)
except ValueError:
    toks = cmd.split()
VALUE_OPTS = {"-C", "--git-dir", "--work-tree", "--namespace", "--exec-path", "-c"}
base = "--cached"
i = 0
while i < len(toks):
    if os.path.basename(toks[i]) != "git":
        i += 1; continue
    j = i + 1
    while j < len(toks) and toks[j].startswith("-"):
        j += 2 if toks[j] in VALUE_OPTS else 1
    if j >= len(toks):
        break
    sub = toks[j]
    if sub == "add":
        base = "HEAD"; break
    if sub == "commit":
        k = j + 1
        while k < len(toks) and toks[k].startswith("-"):
            f = toks[k]
            if f in ("-a", "--all") or (f.startswith("-") and not f.startswith("--") and "a" in f[1:]):
                base = "HEAD"
            if f in ("-m", "-F", "-C", "-c", "--author", "--date", "-t"):
                k += 1
            k += 1
        break
    i = j + 1
print(base)
' 2>/dev/null || echo "--cached")
[ "$GIT_DIFF_BASE" = "HEAD" ] || GIT_DIFF_BASE="--cached"

# Compute diff stats — skip gate if trivial
DIFF_STAT=$(git diff $GIT_DIFF_BASE --numstat 2>/dev/null || echo "")
if [ "$GIT_DIFF_BASE" = "HEAD" ]; then
  UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | awk -F'\t' '{print "1\t0\t" $0}' || true)
  [ -n "$UNTRACKED" ] && DIFF_STAT="$(printf '%s\n%s' "$DIFF_STAT" "$UNTRACKED" | sed '/^$/d')"
fi
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
PRIVATE_DOCS=$( { git diff $GIT_DIFF_BASE --name-only 2>/dev/null | grep -E '^docs/rolepod/' || true; } | head -5 | tr '\n' ' ' | sed 's/ *$//')
if [ -n "$PRIVATE_DOCS" ] && [ ! -f "$_pd_root/.rolepod/docs-tracked" ]; then
  ROLEPOD_HOOK_MSG="precommit-gate BLOCKED — private working docs staged: $PRIVATE_DOCS. docs/rolepod/ is never committed. Fix: git restore --staged docs/rolepod; make sure .gitignore lists docs/rolepod/. Repo tracks them on purpose → create .rolepod/docs-tracked, commit again." python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || echo '{}'
  exit 0
fi
# Emoji in the product (v2.110.0): a pictograph on a shipped surface — UI
# copy, templates, source strings, CLI output — is an icon nobody asked for.
# ADVISORY, never a block: the line rides on whichever message this gate
# ends with (auto-pass note, HARD reason, SOFT warn, or the R1 early exit).
# Only ADDED lines of non-prose, non-test staged files count, and comment
# lines are skipped: docs, commit messages and code comments may carry
# emoji; the product may not. Detection = Unicode Emoji_Presentation: every
# char in U+1F000–U+1FAFF, the BMP chars that default to colour emoji
# (✅ ❌ ⚡ ⛔ ⭐ …), and any char forced to emoji by U+FE0F (⚠️ ✔️). Plain
# text marks (✓ ✗ ⚠ → ·) never match. A product that wants emoji creates
# <git-root>/.rolepod/allow-emoji — explicit, reviewable, user-set — and
# the line goes silent.
EMOJI_WARN=""
if [ ! -f "$_pd_root/.rolepod/allow-emoji" ] && command -v python3 >/dev/null 2>&1; then
  EMOJI_HIT=$(git diff $GIT_DIFF_BASE -U0 2>/dev/null | python3 -I -c '
import re, sys
rx = re.compile("[\U0001F000-\U0001FAFF\u231A\u231B\u23E9-\u23EC\u23F0\u23F3\u25FD\u25FE\u2614\u2615\u2648-\u2653\u267F\u2693\u26A1\u26AA\u26AB\u26BD\u26BE\u26C4\u26C5\u26CE\u26D4\u26EA\u26F2\u26F3\u26F5\u26FA\u26FD\u2705\u270A\u270B\u2728\u274C\u274E\u2753-\u2755\u2757\u2795-\u2797\u27B0\u27BF\u2B1B\u2B1C\u2B50\u2B55]|.\uFE0F")
skip_path = re.compile(r"\.(md|mdx|mdc|txt|rst|adoc)(\.tmpl)?$|(^|/)(test|tests|spec|specs|__tests__|fixtures)(/|\.|_)|_test\.|\.test\.|_spec\.|\.spec\.")
comment = re.compile(r"^\s*(#|//|/\*|\*|--|;|<!--)")
path = None; n = 0; hits = []
for raw in sys.stdin.buffer:
    line = raw.decode("utf-8", "replace").rstrip("\n")
    if line.startswith("+++ "):
        path = line[4:].rstrip(" \t"); path = path[2:] if path.startswith("b/") else path
        continue
    if line.startswith("@@"):
        m = re.search(r"\+(\d+)", line); n = int(m.group(1)) - 1 if m else 0
        continue
    if not line.startswith("+") or line.startswith("+++"):
        continue
    n += 1
    body = line[1:]
    if path is None or skip_path.search(path) or comment.match(body):
        continue
    m = rx.search(body)
    if m:
        hits.append("%s:%d %s" % (path, n, m.group(0).strip()))
if hits:
    more = " (+%d more)" % (len(hits) - 1) if len(hits) > 1 else ""
    print(hits[0] + more)
' 2>/dev/null || true)
  [ -n "$EMOJI_HIT" ] && EMOJI_WARN="emoji in product code: $EMOJI_HIT — a pictograph on a shipped surface is an icon nobody asked for. Fix: text, an icon component, or an SVG (docs, code comments, commit messages are not checked). Exception: the user wants emoji in this product → create .rolepod/allow-emoji."
fi
LINES_CHANGED=$(echo "$DIFF_STAT" | awk '{a+=$1; b+=$2} END {print a+b}')
LINES_CHANGED=${LINES_CHANGED:-0}

# High-risk path detection — anchored to path segments (avoids matching e.g.
# `session_state.py` for the hooks helper, where "session" is part of the
# identifier not a security surface).
# Test-NAMED files are not the risk (v2.85.2): a test-only commit under
# tests/auth/ or spec/models/payment_spec.rb is the QA-automation deliverable,
# and gate-reminder.sh (IS_TEST) + session_state.py (TEST_FILE) already exempt
# the same file at edit time. Filename convention ONLY — never bare directory
# segments (tests/ spec/ e2e/ fixtures/): those would downgrade
# api/specs/auth.yaml and tests/fixtures/seed_auth_users.py. A mixed diff
# (test + production file) still matches on the production path. The
# Paths come from numstat, tab-separated: split on TAB (a path with a space
# is one field, never truncated at the space — v2.85.3).
# content-based money check below CANNOT see these files either (it excludes
# test paths itself), so money primitives inside a test-named file are an
# ACCEPTED blind spot: rspec/jest-only load, and the mixed diff still blocks.
HIGH_RISK=$(echo "$DIFF_STAT" | awk -F'\t' '{print $3}' | grep -vE '\.(test|spec)\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|kt|swift|cs|php)$|(^|/)(test_[^/]*|[^/]*_test|[^/]*_spec)\.(py|go|rs|rb|php)$|(^|/)[^/]*Tests?\.(java|kt|cs|swift|php|scala)$' | grep -vE '\.(md|mdx|mdc|txt|rst|adoc)(\.tmpl)?$|(^|/)(README|LICENSE|CHANGELOG)$' | risk_filter '(^|/|_)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices|deletion|deletions|erasure|gdpr|security)(/|\.|_|$)' | head -1 || true)

# Content-based high-risk (v2.46.0) — money-movement primitives in ADDED
# lines of non-test staged files. Catches refund/payout logic living in a
# generically named file (closure-service.ts, date-utils.ts) the path regex
# cannot see — the shape of 2 of the 4 escaped CourtBook money bugs.
if [ -z "$HIGH_RISK" ]; then
  # Prose is excluded INSIDE awk, on the header path only (never on the
  # added line's text — `b.refund.md + b.total` in a .py must still count):
  # a doc that mentions a refund policy is not money logic (v2.86.0 — all
  # 14 recorded content hits were executable files, 0 were docs). git
  # appends a trailing tab to `+++ b/<path>` when the name has a space —
  # stripped before the suffix test. The candidate paths then go through
  # risk_filter so a `-` line in .rolepod/risk-paths excludes them exactly
  # like the path regex.
  CONTENT_RISK=$(git diff $GIT_DIFF_BASE -U0 2>/dev/null \
    | awk '/^\+\+\+ /{f=substr($0,5); sub(/[ \t]+$/,"",f)} /^\+[^+]/{if (f !~ /\.(md|mdx|mdc|txt|rst|adoc)(\.tmpl)?$/) print f "\t" $0}' \
    | grep -vE '(^|/)(test|tests|spec|specs|__tests__|fixtures)(/|\.|_)|_test\.|\.test\.|_spec\.|\.spec\.' \
    | grep -iE '(refund|payout|chargeback|settlement)' \
    | awk -F'\t' '{print $1}' | sed -E 's#^[abciow]/##' | risk_filter '.' | head -1 || true)
  [ -n "$CONTENT_RISK" ] && HIGH_RISK="staged content: money-movement term (refund/payout/chargeback/settlement)"
fi

# Logic-bearing line count — non-comment, non-blank lines of NON-PROSE files
# (v2.153.0). Prose is excluded on the header path, like CONTENT_RISK above:
# a mixed diff used to count every .md line as logic (a docs task + one
# script read "280 logic"). Headers are read only between `diff --git` and
# the first `@@`, so a removed SQL comment (`--- x`) is never taken for one;
# a deleted file (`+++ /dev/null`) keeps its `---` path; git quotes a path
# with non-ASCII bytes (`+++ "b/\340…md"`), so the closing quote is dropped
# before the suffix test.
LOGIC_LINES=$(git diff $GIT_DIFF_BASE -U0 2>/dev/null \
  | awk '/^diff --git /{hdr=1; next}
         hdr && /^--- /{g=substr($0,5); sub(/[ \t]+$/,"",g); sub(/"$/,"",g); next}
         hdr && /^\+\+\+ /{f=substr($0,5); sub(/[ \t]+$/,"",f); sub(/"$/,"",f); if (f=="/dev/null") f=g; next}
         /^@@/{hdr=0; next}
         !hdr && /^[+-]/{ if (f !~ /\.(md|mdx|mdc|txt|rst|adoc)(\.tmpl)?$/ && f !~ /(^|\/)(README|LICENSE|CHANGELOG)$/) print }' \
  | grep -vE '^[+-][[:space:]]*$' | grep -vE '^[+-][[:space:]]*(#|//|/\*|\*/?|--|;)' || true)
if [ -z "$LOGIC_LINES" ]; then
  LOGIC_COUNT=0
else
  LOGIC_COUNT=$(printf '%s\n' "$LOGIC_LINES" | wc -l | tr -d ' ')
fi
# SOFT-only count: a line that is ONLY a version field — "version": "1.2.3" /
# version = "1.2.3-rc.1" / version: v1.2.3 — is a release bump, not logic:
# every release commit asked for a reviewer. The suffix is semver-shaped and
# the line must end there, so `version: 1.2.3;run()` still counts. LOGIC_COUNT
# above keeps those lines: the HARD side (auto-skip, cross-family hold on a
# risky path) reads the wider count and does not move.
VERSION_LINE_RE='^[+-][[:space:]]*"?version"?[[:space:]]*[:=][[:space:]]*"?v?[0-9]+(\.[0-9]+)+([-+][0-9A-Za-z.+-]*)?"?,?[[:space:]]*$'
REVIEW_LOGIC=$(printf '%s\n' "$LOGIC_LINES" | grep -vE "$VERSION_LINE_RE" | grep -c . || true)
REVIEW_LOGIC=${REVIEW_LOGIC:-0}

# Docs are written, not reviewed (v2.143.0): every staged path is prose
# (.md/.mdx/.mdc/.txt/.rst/.adoc, their .tmpl templates, or an extension-less README/LICENSE/CHANGELOG)
# → allow silently, whatever the size. The private-docs deny and the emoji
# advisory (docs exempt) already ran. A prose file is never a risk path
# either (filtered before risk_filter above) — so a `+pattern` in
# .rolepod/risk-paths cannot re-flag a prose file; accepted limitation.
PROSE_N=$(printf '%s\n' "$DIFF_STAT" | awk -F'\t' 'NF>=3 && $3 ~ /\.(md|mdx|mdc|txt|rst|adoc)(\.tmpl)?$|(^|\/)(README|LICENSE|CHANGELOG)$/' | wc -l | tr -d ' ')
NONPROSE_N=$(printf '%s\n' "$DIFF_STAT" | awk -F'\t' 'NF>=3 && $3 !~ /\.(md|mdx|mdc|txt|rst|adoc)(\.tmpl)?$|(^|\/)(README|LICENSE|CHANGELOG)$/' | wc -l | tr -d ' ')
if [ "${PROSE_N:-0}" -gt 0 ] && [ "${NONPROSE_N:-1}" -eq 0 ]; then
  exit 0
fi

# Auto-skip path: trivial commit
if [ "$FILES_CHANGED" -eq 1 ] && [ "$LINES_CHANGED" -le 5 ] && [ "$LOGIC_COUNT" -eq 0 ] && [ -z "$HIGH_RISK" ]; then
  [ -n "$EMOJI_WARN" ] && ROLEPOD_HOOK_MSG="precommit-gate: $EMOJI_WARN" python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || true
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
  # Nested reviewer dispatch backstop (v2.144.0): count_all's
  # agent_transcripts() already discovers ONE level of nesting (a runner
  # subagent's own Agent-tool call to a reviewer is a tool_use IN THE
  # RUNNER'S OWN transcript file, which sits directly under the Lead's
  # <session>/subagents/ and gets walked) — but that walk caps at the 60
  # NEWEST subagent-transcript files in the window
  # (session_state.AGENT_TRANSCRIPT_CAP), so a session running a large
  # fleet since the last commit can push a real dispatch out of the cap and
  # read 0. dispatch-auto-log.sh writes a "dispatch" row to the SAME
  # phase-log for every Agent/Task/Workflow call in ANY session — an
  # append-only log with no such cap — so it backstops exactly that drop.
  # MAX with the transcript scan, never summed — the Lead's own direct
  # dispatch is visible to both and must not double-count (case: 1 dispatch,
  # both paths report it → reported count stays 1). Hardened above real
  # session evidence: only "hook-auto"-provenance rows count (raises a bare
  # forged line to parity with the real writer's field), and a STRONG row
  # is dropped to a plain reviewer when its model is a named low-class
  # downgrade (mirrors count_all's own LOW_CLASSES refusal) — see
  # phase_log_reviewer_count's header for the full rationale + the
  # accepted repo-scope (not session-scope) residual.
  NESTED_PHASE_LOG="$(git rev-parse --show-toplevel 2>/dev/null)/.rolepod/evidence/phase-log.jsonl"
  read -r NEST_R NEST_S <<< "$(phase_log_reviewer_count dispatch "$SINCE_EPOCH" "$NESTED_PHASE_LOG" "hook-auto" "1" "$SESSION_STATE")"
  [ "${NEST_R:-0}" -gt "${REVIEWERS:-0}" ] 2>/dev/null && REVIEWERS=$NEST_R
  [ "${NEST_S:-0}" -gt "${STRONG_REVIEWERS:-0}" ] 2>/dev/null && STRONG_REVIEWERS=$NEST_S
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
  read -r REVIEWERS STRONG_REVIEWERS <<< "$(phase_log_reviewer_count dispatch-proof "$SINCE_EPOCH" "$PHASE_LOG")"
fi
# Edit ledger (v2.134.0): CLI-neutral edit evidence written at edit time by every
# CLI's edit hook (hooks/edit-ledger.py). Max with the transcript scan, never summed.
LEDGER="$(dirname "$0")/edit-ledger.py"
if [ -f "$LEDGER" ] && command -v python3 >/dev/null 2>&1; then
  read -r L_TEST L_RISK <<< "$(python3 -I "$LEDGER" count "$SINCE_EPOCH" 2>/dev/null || echo "0 0")"
  [ "${L_TEST:-0}" -gt "${TEST_EDITS:-0}" ] 2>/dev/null && TEST_EDITS=$L_TEST
  [ "${L_RISK:-0}" -gt "${HIGH_RISK_EDITS:-0}" ] 2>/dev/null && HIGH_RISK_EDITS=$L_RISK
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
  XREV=$(python3 -I -c '
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
# internal path untouched. Lead CLI unknown → cannot exclude its own CLI →
# no tightening (fail-open).
XFAM_HELD=""
XFAM_RUNNER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/cross-family.sh"
[ -f "$XFAM_RUNNER" ] || XFAM_RUNNER="$HOME/.rolepod/bin/cross-family.sh"
XFAM_LEAD="${ROLEPOD_LEAD_CLI:-}"
[ -z "$XFAM_LEAD" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && XFAM_LEAD="claude"
XFAM_POOL=""; XFAM_FAILS=0
# Detached runner job still running for this repo (v2.79.0): the hold reason
# must say "wait / --collect", not "run the runner" (it is already running).
XFAM_RUNNING="$(xfam_running_job)"
# Money / auth no longer needs BOTH passes (v2.78.0 hold REMOVED, v2.145.0):
# the pool exists to move strong-class tokens OFF the main plan, so an
# anchored external pass (XREV, already credited to STRONG_REVIEWERS above)
# clears a money/auth diff alone, same as any other high-risk surface.
# Satellite-first below is unchanged: an internal reviewer with NOTHING
# tried against the pool still does not clear.
# The pool reviews CODE only (v2.143.0): a comment / blank-only diff on a
# risky path (LOGIC_COUNT 0) clears with the internal strong reviewer.
# `-z "$XFAM_HELD"` is defensive (no earlier block sets it now) — keeps this
# `if` correct unchanged if a hold is ever added above it again.
if [ -z "$XFAM_HELD" ] && [ -n "$HIGH_RISK" ] && [ "${LOGIC_COUNT:-0}" -gt 0 ] && [ -n "$XFAM_LEAD" ] && [ -f "$XFAM_RUNNER" ] && [ "${XREV:-0}" -eq 0 ] && [ "$STRONG_REVIEWERS" -gt 0 ]; then
  XFAM_POOL=$(bash "$XFAM_RUNNER" --lead "$XFAM_LEAD" --pool-names 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
  XFAM_FAILS=0
  if [ -n "$XFAM_POOL" ] && [ -f "$EV_ROOT/phase-log.jsonl" ]; then
    XFAM_FAILS=$(python3 -I -c '
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
    XFAM_HELD="cross-family pool usable ($XFAM_POOL), no anchored external pass since the last commit — $STRONG_REVIEWERS internal reviewer(s) do NOT clear a high-risk diff while a different CLI is available. "
    if [ -n "$XFAM_RUNNING" ]; then
      XFAM_HELD+="A detached job is ALREADY RUNNING: $XFAM_RUNNING — rolepod-cross-family --collect <job-id>, then retry; do not start another. "
    else
      XFAM_HELD+="Fix: rolepod-cross-family --kind review --brief <brief.md> --attach <diff> --detach (add --lead $XFAM_LEAD outside a hook); --collect <job-id> waits. "
    fi
    XFAM_HELD+="Pool failed or empty (logged) → the internal reviewer counts. "
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
REASON+="Evidence ($SINCE_HUMAN, Lead + subagent transcripts + edit ledger): $TEST_EDITS test edits / $HIGH_RISK_EDITS high-risk edits / $REVIEWERS reviewer dispatches ($STRONG_REVIEWERS strong). "
[ -n "$HIGH_RISK" ] && REASON+="HIGH-RISK path: $HIGH_RISK → R4 floor: security-engineer + ONE general strong pass (the external when the pool is usable, else universal-reviewer). "
if [ "$HIGH_RISK_EDITS" -gt 0 ] && [ "$TEST_EDITS" -eq 0 ]; then
  REASON+="NO TEST EDITS in this session despite touching high-risk code — T-gate violation (T1: bug/feature/migration/auth/billing → test required). "
fi
[ -n "$XFAM_HELD" ] && REASON+="SATELLITE-FIRST: $XFAM_HELD"
[ -z "$XFAM_HELD" ] && [ -n "$XFAM_RUNNING" ] && [ -n "$HIGH_RISK" ] && [ "$STRONG_REVIEWERS" -eq 0 ] && REASON+="A detached cross-family job is still running: $XFAM_RUNNING — rolepod-cross-family --collect <job-id>, then retry. "
if [ -n "$HIGH_RISK" ] && [ "$STRONG_REVIEWERS" -eq 0 ] && [ -z "$XFAM_HELD" ]; then
  REASON+="NO STRONG ADVERSARIAL REVIEWER since the last commit. The gate opens when one of them has FINISHED: (a) a cross-family external strong review, anchored per review-code (raw output under .rolepod/evidence/external/ + the reviewer:external log line) — preferred; (b) a security-engineer or universal-reviewer dispatch (Agent tool or Workflow agentType) that has FINISHED. The hook lifts Agent-tool ones to strong — do not pass a balanced model. Test edits are the test floor, not the review. "
fi
REASON+="Run S1-S5 (simplicity) + T1-T6 (tests) + F1-F5 (finish) — finish-work §1, check-work §6. "
REASON+="Auto-passes once evidence exists SINCE THE LAST COMMIT: high-risk → dispatch security-engineer or universal-reviewer; other blocks → write the failing test or dispatch a reviewer; then rerun the SAME git commit. No bypass marker, no env prefix."

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
#     test edits are the floor, not the review — CourtBook
#     proof: 672 green tests + opus impl still shipped 4 money bugs that
#     only the adversarial pass caught.
#   other HARD blocks (session risk edits w/o tests, env) → original OR
#     (≥1 test edit or ≥1 reviewer dispatch): delegated sessions route
#     test-writing into subagents whose edits land in the child transcript,
#     so a universal-reviewer dispatch is often the only evidence the Lead's
#     own transcript can show (qa-tester counts 0 since v2.148.4). Every
#     auto-pass is logged and surfaced as context.
# Test-tampering lint (warn-only) — grep-able half of the writer's test self-check.
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
  SAFE_CMD=$(ROLEPOD_BYPASS_CMD="$CMD" python3 -I -c "
import os, sys
sys.stdout.reconfigure(errors='replace')
sys.stdout.write(' '.join(os.environ.get('ROLEPOD_BYPASS_CMD', '').split())[:200])
" 2>/dev/null) || SAFE_CMD=""
  printf '%s auto-pass on evidence (tests=%s reviewers=%s strong=%s risk=%s): %s\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" "$TEST_EDITS" "$REVIEWERS" "$STRONG_REVIEWERS" "${HIGH_RISK:-none}" "$SAFE_CMD" \
    >> "$HOME/.rolepod/gate-bypass.log" 2>/dev/null || true
  NOTE="precommit-gate auto-passed on session evidence: $TEST_EDITS test edits / $REVIEWERS reviewer dispatches / $STRONG_REVIEWERS strong"
  [ -n "$HIGH_RISK" ] && NOTE+=" (HIGH-RISK path: $HIGH_RISK)"
  NOTE+=" ($SINCE_HUMAN). Evidence is per-window — confirm S1-S5 (simplicity) / T1-T6 (tests) / F1-F5 (finish) — finish-work §1, check-work §6 — cover THIS change."
  [ -n "$LINT_WARN" ] && NOTE+=" | $LINT_WARN"
  [ -n "$EMOJI_WARN" ] && NOTE+=" | $EMOJI_WARN"
  ROLEPOD_HOOK_MSG="$NOTE" python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || true
  exit 0
fi

if [ "$HARD_BLOCK" -eq 1 ]; then
  # Env-passed — quotes in the reason must not break the JSON emitter.
  [ -n "$LINT_WARN" ] && REASON+=" | $LINT_WARN"
  [ -n "$EMOJI_WARN" ] && REASON+=" | $EMOJI_WARN"
  ROLEPOD_HOOK_MSG="$REASON" python3 -I -c "
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
WARN="precommit-gate SOFT: $FILES_CHANGED files / $LINES_CHANGED lines / $REVIEW_LOGIC logic, no high-risk path; reviewers since last commit: $REVIEWERS. "
# A logic diff nobody but its author read (v2.95.0): the R2 floor is one
# read-only universal-reviewer pass (v2.148.0) — named here, still advisory. An R1-shaped
# diff (1 file, ≤5 lines) gets the count only: a user-facing string edit
# counts as logic here but as zero in the router (v2.96.0), and the
# hook cannot tell a label from a branch — the doctrine can.
# The R1 shape is judged on the CODE part (v2.153.0): docs riding along with
# a 2-line label edit do not make it a reviewable diff, and neither do the
# comment lines around one real line.
if [ "$REVIEW_LOGIC" -gt 0 ] && [ "$REVIEWERS" -eq 0 ] && { [ "${NONPROSE_N:-0}" -gt 1 ] || [ "$REVIEW_LOGIC" -gt 5 ]; }; then WARN+="0 reviewers on a logic diff = the author reviewed it. Fix: dispatch rolepod:universal-reviewer (read-only, two axes) on the diff, then commit (review-code §1; R2 = one file + test). Exception: the task owner already had it reviewed, or the diff is config / generated copies / message text → commit. "; fi
WARN+="Gates S1-S5 (simplicity) / T1-T6 (tests) / F1-F5 (finish) — finish-work §1, check-work §6 — are advisory here; ROLEPOD_GATES_HARD=1 enforces."
[ -n "$LINT_WARN" ] && WARN+=" | $LINT_WARN"
[ -n "$EMOJI_WARN" ] && WARN+=" | $EMOJI_WARN"

ROLEPOD_HOOK_MSG="$WARN" python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || true

exit 0
