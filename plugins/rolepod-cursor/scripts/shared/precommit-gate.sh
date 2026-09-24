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
#
# Accepted residuals (owner decision, 2026-09-24, final cut before release):
# deliberate evasion is out of scope by design — this gate catches mistakes
# in the normal flow, not a deliberately crafted bypass. Not handled: ANSI-C
# $'…' escapes, a bare & after an output command, quote- or backslash-split
# names.
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
                if d.get("write_mode"):
                    # F1/F2: a write-mode dispatch (dispatch-auto-log.sh) is a
                    # writer, not a reviewer — count_all already excludes it
                    # from the transcript scan; the phase-log backstop must
                    # not re-admit it. A forged write_mode field can only
                    # LOWER a count, never raise one.
                    continue
                if cut is not None:
                    ts = datetime.datetime.fromisoformat((d.get("ts") or "").replace("Z", "+00:00"))
                    if ts.tzinfo is None or ts < cut:
                        continue
                at = d.get("agent_type")
                name = (at.strip() if isinstance(at, str) else "").rsplit(":", 1)[-1]
                if name.startswith("rolepod-"):
                    name = name[len("rolepod-"):]
                # Both flags resolved before either counter moves (round-2
                # review MINOR-1): model_class() raising on a malformed
                # `model` must not leave `r` incremented with `s` never
                # reached.
                is_reviewer = name in REVIEWERS
                is_strong = name in STRONG and (strict != "1" or (ss_ok and model_class(d.get("model")) not in LOW_CLASSES))
                if is_reviewer:
                    r += 1
                if is_strong:
                    s += 1
            except Exception:
                continue
except OSError:
    pass
print(r, s)
' "$_pr_phase" "$_pr_since" "$_pr_path" "$_pr_prov" "$_pr_strict" "$_pr_ss" 2>/dev/null || echo "0 0"
}

INPUT=$(cat 2>/dev/null || echo '{}')

# ONE python3 pass for tool_name + commit token-walk + resolved directory +
# command (was 3 spawns — ~30ms on EVERY Bash call, the hottest PreToolUse
# matcher). Field order matters: tool/mut/hit/dir first via read -r; command
# LAST, slurped with $(cat) so multi-line commit messages survive intact and
# an empty trailing field cannot EOF-fail the read under set -e — command
# substitution strips ALL trailing blank lines, so when dir AND cmd are both
# empty (malformed input, no "command" key) the dir read lands exactly on
# that stripped boundary; `|| true` on it is the same fail-open the cmd read
# gets for free from $(cat) (v2.153.0). The walk matches flag-separated
# forms (`git -C . commit`, `git -c k=v commit`).
PARSED=$(printf '%s' "$INPUT" | python3 -I -c "
import json, os, re, shlex, sys
tool = ''
cmd = ''
hit = 0
mut = ''
resolved_dir = ''
# Tree-rewriting subcommands (v2.93.0): warned about while a detached
# cross-family review is running. stash list/show and a mixed/soft reset
# touch nothing the reviewer reads.
MUT = {'stash', 'reset', 'checkout', 'switch', 'restore', 'rebase', 'merge', 'cherry-pick', 'clean', 'pull'}
try:
    d = json.load(sys.stdin)
    tool = d.get('tool_name', '') or ''
    cmd = (d.get('tool_input', {}) or {}).get('command', '') or ''
    VALUE_OPTS = {'-C', '--git-dir', '--work-tree', '--namespace', '--exec-path'}
    GLOB = set('*?[')
    OPCHARS = set('();<>|&\n')
    # Shell-wrapped commit unwind (F8b/S8, v2.166.x): the wrapper tables are
    # hooks/lib/session_state.py's PREFIX / WRAPPER_VALUE / SHELLS / DURATION,
    # copied inline — the gate runs lib-less on Cursor and Antigravity (no
    # lib/ in those bundles). Tokenize the WHOLE command with real shlex
    # first (posix quote/escape rules — correct by construction, never
    # hand-rolled: a round-1 fix that hand-rolled a quote-aware text
    # scanner was itself wrong on an escaped quote, a comment apostrophe, a
    # bare '&', and command substitution — round-2 external + security review)
    # — '\n' is added to punctuation_chars so a literal newline is its OWN
    # token instead of silently eaten as whitespace (round-1 review; shlex
    # otherwise folds a newline into nothing, hiding 'echo x<newline>git
    # commit'). Segment boundaries are then any token made ENTIRELY of
    # OPCHARS characters (';', '&&', '&', '|', '\n', ...). Unbalanced
    # quoting anywhere (top level or inside a recursed -c / eval string) ->
    # that segment's raw tokens are kept UNTOUCHED (no drop, no recursion) —
    # ambiguous input never disappears, it just isn't optimized away, so the
    # existing 'git'+'commit' token walk below still sees it. Per clean
    # segment: skip env assigns and a known wrapper's own flags/duration,
    # then a shell head (SHELLS, or \$SHELL / \${SHELL} expanded from the
    # environment) with a flag cluster containing 'c' (-c, -lc, -ec, -xc) —
    # found by scanning every remaining token, never stopping at the first
    # non-flag one, so a value-taking option before -c ('bash -o pipefail
    # -c ...') or a long option ('--noprofile') cannot hide it — recurses
    # into its string; 'eval' recurses into its joined remaining args.
    # depth > 4 -> a forced commit hit (fail-closed) — segments already
    # unwound before the cap was hit are kept, so a preceding 'cd' still
    # resolves. Residuals accepted, not handled (v2.166.x, 3 review rounds):
    # xargs / find -exec / parallel, a script FILE that runs git commit, a
    # git alias (incl. \`git -c alias.x=commit x\`), a wrapper long option
    # this table does not name (\`exec -a\`, \`sudo --user\`, \`env -S\`,
    # \`timeout --signal\`), and any shell-grammar shape neither this table
    # nor real shlex covers (process substitution, brace/subshell grouping,
    # \`{ ...; }\`, \`if...then\`). Full shell-grammar parity is open-ended by
    # nature — this is the accepted line, matching the Pragmatic approach's
    # own scope.
    PREFIX = {'time', 'env', 'nice', 'sudo', 'rtk', 'proxy', 'caffeinate', 'command', 'exec', 'nohup', 'timeout'}
    WRAPPER_VALUE = {'sudo': {'-u', '-g', '-C', '-p', '-h', '-r', '-t', '-U', '-D'}, 'nice': {'-n'},
                      'env': {'-u', '-C', '-S'}, 'timeout': {'-k', '-s'}, 'nohup': set(), 'caffeinate': {'-t', '-w'}}
    DURATION = re.compile(r'^[0-9]+(\.[0-9]+)?[smhd]?\$')
    ASSIGN = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*=')
    SHELLS = {'bash', 'sh', 'zsh', 'dash', 'ksh'}
    OUTPUT_ONLY = {'echo', 'printf', ':'}
    def _uw_head(t):
        # basename, not t[0] itself — '/usr/bin/env bash -c ...' must skip
        # 'env' the wrapper the same as a bare 'env' (round-3 external
        # review: an absolute-path wrapper evaded every PREFIX check).
        w = ''
        while t:
            if os.path.basename(t[0]) in PREFIX:
                w = os.path.basename(t[0]); t = t[1:]
            elif t[0].startswith('-'):
                t = t[2:] if (t[0] in WRAPPER_VALUE.get(w, set()) and len(t) > 1) else t[1:]
            elif DURATION.match(t[0]) or ASSIGN.match(t[0]):
                t = t[1:]
            else:
                break
        return t
    def _uw_tok(s):
        # Fallback ONLY (top-level unbalanced quoting) — never used to feed
        # the unwrap itself, so its looser semantics never gate a drop.
        try:
            _l = shlex.shlex(s, posix=True, punctuation_chars=True)
            _l.whitespace_split = True
            _l.commenters = ''
            return list(_l)
        except Exception:
            try:
                return shlex.split(s)
            except ValueError:
                return s.split()
    def _uw_tokenize_full(s):
        # ANSI-C / locale quoting (bash dollar-single-quote / dollar-double-
        # quote strings) — shlex has no concept of it, reading the leading
        # \$ as an ordinary character that glues onto the quote instead of
        # opening it, which hid 'git commit' inside such a string entirely
        # (round-3 external review). Swap the dollar-quote prefix for a
        # plain quote before tokenizing — enough for OUR purpose (seeing
        # the words inside), even though it is not a faithful backslash-
        # escape reinterpretation.
        s = s.replace(chr(36) + chr(39), chr(39)).replace(chr(36) + chr(34), chr(34))
        _l = shlex.shlex(s, posix=True, punctuation_chars='();<>|&\n')
        _l.whitespace = _l.whitespace.replace('\n', '')
        _l.whitespace_split = True
        _l.commenters = ''
        return list(_l)  # raises ValueError on unbalanced quoting
    def _uw_process(toks_in, depth):
        if depth > 4:
            return toks_in, True
        out = []
        forced = False
        i = 0
        n2 = len(toks_in)
        while i < n2:
            j = i
            while j < n2 and not (toks_in[j] and all(c in OPCHARS for c in toks_in[j])):
                j += 1
            seg = toks_in[i:j]
            t = _uw_head(seg)
            handled = False
            if t:
                ht = t[0]
                if ht in ('\$SHELL', '\${SHELL}'):
                    ht = os.environ.get('SHELL', '')
                hbase = os.path.basename(ht)
                if hbase in OUTPUT_ONLY:
                    # a pure-output head (echo/printf/:) never invokes what
                    # follows it — drop only THIS clean segment (matches
                    # block-subagent-commit.sh's every=True OUTPUT_ONLY
                    # skip).
                    handled = True
                elif hbase in SHELLS:
                    cflag = None
                    for p in range(1, len(t)):
                        if t[p].startswith('-') and not t[p].startswith('--') and 'c' in t[p][1:]:
                            cflag = p
                            break
                    if cflag is not None and cflag + 1 < len(t):
                        try:
                            inner_toks = _uw_tokenize_full(t[cflag + 1])
                        except ValueError:
                            pass
                        else:
                            r_toks, f2 = _uw_process(inner_toks, depth + 1)
                            out.extend(r_toks)
                            handled = True
                            if f2:
                                forced = True
                elif hbase == 'eval' and len(t) > 1:
                    try:
                        inner_toks = _uw_tokenize_full(' '.join(t[1:]))
                    except ValueError:
                        pass
                    else:
                        r_toks, f2 = _uw_process(inner_toks, depth + 1)
                        out.extend(r_toks)
                        handled = True
                        if f2:
                            forced = True
            if not handled:
                out.extend(seg)
            if forced:
                return out, True
            if j < n2:
                out.append(toks_in[j])
            i = j + 1
        return out, False
    try:
        _uw_top = _uw_tokenize_full(cmd)
        toks, _uw_forced = _uw_process(_uw_top, 0)
    except ValueError:
        # Unbalanced quoting at the TOP level: unwrap is unsafe — fall back
        # to the plain tokenizer, unfiltered (more visible tokens, never
        # fewer; the existing 'git'+'commit' walk below still runs on it).
        toks = _uw_tok(cmd)
        _uw_forced = False
    def _giveup(a):
        # A var, a command substitution, a flag ('cd -' = previous dir) or a
        # glob — none resolvable from the command text alone (R2:
        # unresolvable never produces a new deny, it falls open to the hook
        # cwd). chr(96) avoids a literal backtick inside this quoted block.
        if not a or a[0] in '\$-' or chr(96) in a or any(c in a for c in GLOB):
            return True
        return all(c in OPCHARS for c in a)
    def _join(cur, a):
        if a.startswith('/'):
            return a
        if a.startswith('~'):
            return os.path.expanduser(a)
        return os.path.join(cur, a) if cur else a
    cur_dir = None
    dir_failed = False
    k = 0
    n = len(toks)
    while k < n:
        t = toks[k]
        if t == 'cd':
            # A bare 'cd' (home dir) or one immediately followed by an
            # operator ('cd && …') has no operand token to consume — leave
            # the operator for the next iteration instead of swallowing it
            # as a fake directory argument.
            nxt = toks[k + 1] if k + 1 < n else ''
            if nxt and not all(c in OPCHARS for c in nxt):
                if not dir_failed:
                    if _giveup(nxt):
                        dir_failed = True
                    else:
                        cur_dir = _join(cur_dir, nxt)
                k += 2
            else:
                k += 1
            continue
        if os.path.basename(t) == 'git':
            j = k + 1
            c_dir = None
            while j < n and toks[j].startswith('-'):
                if toks[j] == '-C' and j + 1 < n:
                    c_dir = toks[j + 1]
                    j += 2
                elif toks[j] in VALUE_OPTS:
                    j += 2
                elif toks[j] == '-c' and j + 1 < n and '=' in toks[j + 1]:
                    j += 2
                else:
                    j += 1
            if j < n and toks[j] == 'commit':
                hit = 1
                # -C on the HIT invocation applies last, relative to every
                # cd segment already walked (R1).
                if c_dir is not None and not dir_failed:
                    if _giveup(c_dir):
                        dir_failed = True
                    else:
                        cur_dir = _join(cur_dir, c_dir)
                break
            if j < n and toks[j] in MUT and not mut:
                sub = toks[j]
                nxt = toks[j + 1] if j + 1 < n else ''
                if sub == 'stash' and nxt in ('list', 'show'):
                    pass
                elif sub == 'reset' and not any(x in ('--hard', '--merge', '--keep') for x in toks[j:]):
                    pass
                else:
                    mut = sub
            k = j + 1
            continue
        k += 1
    if _uw_forced:
        hit = 1
    if not dir_failed and cur_dir:
        resolved_dir = cur_dir
except Exception:
    pass
print(tool)
print(mut)
print(hit)
print(resolved_dir)
print(cmd)
" 2>/dev/null) || exit 0
{ read -r TOOL; read -r MUTATES; read -r IS_COMMIT; read -r RESOLVED_DIR || true; CMD=$(cat); } <<EOF
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
import os, re, shlex
cmd = os.environ.get("ROLEPOD_GATE_CMD", "")
# Same shell-wrapped unwind as the commit-hit walk above (F8b/S8): tables
# copied from hooks/lib/session_state.py (PREFIX / WRAPPER_VALUE / SHELLS),
# so `bash -c "git add x && git commit -m y"` reads the working tree here
# too, not just the plain form.
PREFIX = {"time", "env", "nice", "sudo", "rtk", "proxy", "caffeinate", "command", "exec", "nohup", "timeout"}
WRAPPER_VALUE = {"sudo": {"-u", "-g", "-C", "-p", "-h", "-r", "-t", "-U", "-D"}, "nice": {"-n"},
                 "env": {"-u", "-C", "-S"}, "timeout": {"-k", "-s"}, "nohup": set(), "caffeinate": {"-t", "-w"}}
DURATION = re.compile(r"^[0-9]+(\.[0-9]+)?[smhd]?$")
ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
OUTPUT_ONLY = {"echo", "printf", ":"}
OPCHARS = set("();<>|&\n")
# Tokenize with real shlex first (round-2 review: a hand-rolled quote
# scanner was itself wrong on an escaped quote, a comment apostrophe, a
# bare ampersand, and command substitution; newline is a punctuation char
# so a literal newline is its own boundary token instead of vanishing as
# whitespace (round-1). This block is bash SINGLE-quoted: no quote marks
# in this comment, no escape mechanism exists for them here.
def _tok(s):
    try:
        lx = shlex.shlex(s, posix=True, punctuation_chars=True)
        lx.whitespace_split = True
        lx.commenters = ""
        return list(lx)
    except Exception:
        try:
            return shlex.split(s)
        except ValueError:
            return s.split()
def _uw_head(t):
    # basename, not t[0] itself (round-3 external review: an absolute-path
    # wrapper such as /usr/bin/env bash -c ..., evaded every PREFIX check).
    w = ""
    while t:
        if os.path.basename(t[0]) in PREFIX:
            w = os.path.basename(t[0]); t = t[1:]
        elif t[0].startswith("-"):
            t = t[2:] if (t[0] in WRAPPER_VALUE.get(w, set()) and len(t) > 1) else t[1:]
        elif DURATION.match(t[0]) or ASSIGN.match(t[0]):
            t = t[1:]
        else:
            break
    return t
def _uw_tokenize_full(s):
    # ANSI-C / locale quoting (bash dollar-single-quote / dollar-double-quote
    # strings) — shlex has no concept of it; swap the dollar-quote prefix
    # for a plain quote before tokenizing, enough for OUR purpose (seeing
    # the words inside), even though it is not a faithful backslash-escape
    # reinterpretation (round-3 external review).
    s = s.replace("$" + chr(39), chr(39)).replace("$\"", "\"")
    lx = shlex.shlex(s, posix=True, punctuation_chars="();<>|&\n")
    lx.whitespace = lx.whitespace.replace("\n", "")
    lx.whitespace_split = True
    lx.commenters = ""
    return list(lx)  # raises ValueError on unbalanced quoting
def _uw_process(toks_in, depth):
    if depth > 4:
        return toks_in, True
    out = []
    forced = False
    i = 0
    n2 = len(toks_in)
    while i < n2:
        j = i
        while j < n2 and not (toks_in[j] and all(c in OPCHARS for c in toks_in[j])):
            j += 1
        seg = toks_in[i:j]
        t = _uw_head(seg)
        handled = False
        if t:
            ht = t[0]
            if ht in ("$SHELL", "${SHELL}"):
                ht = os.environ.get("SHELL", "")
            hbase = os.path.basename(ht)
            if hbase in OUTPUT_ONLY:
                handled = True
            elif hbase in SHELLS:
                cflag = None
                for p in range(1, len(t)):
                    if t[p].startswith("-") and not t[p].startswith("--") and "c" in t[p][1:]:
                        cflag = p
                        break
                if cflag is not None and cflag + 1 < len(t):
                    try:
                        inner_toks = _uw_tokenize_full(t[cflag + 1])
                    except ValueError:
                        pass
                    else:
                        r_toks, f2 = _uw_process(inner_toks, depth + 1)
                        out.extend(r_toks)
                        handled = True
                        if f2:
                            forced = True
            elif hbase == "eval" and len(t) > 1:
                try:
                    inner_toks = _uw_tokenize_full(" ".join(t[1:]))
                except ValueError:
                    pass
                else:
                    r_toks, f2 = _uw_process(inner_toks, depth + 1)
                    out.extend(r_toks)
                    handled = True
                    if f2:
                        forced = True
        if not handled:
            out.extend(seg)
        if forced:
            return out, True
        if j < n2:
            out.append(toks_in[j])
        i = j + 1
    return out, False
try:
    _uw_top = _uw_tokenize_full(cmd)
    toks, _uw_forced = _uw_process(_uw_top, 0)
except ValueError:
    toks = _tok(cmd)
    _uw_forced = False
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
if _uw_forced:
    # Fail-closed past the unwrap depth cap: read the working tree, the more
    # inclusive base, rather than trust whatever partial "--cached" default
    # survived an unresolved deep nesting (round-1 external review).
    base = "HEAD"
print(base)
' 2>/dev/null || echo "--cached")
[ "$GIT_DIFF_BASE" = "HEAD" ] || GIT_DIFF_BASE="--cached"

# Directory the commit runs in (v2.153.0, R1/R2): RESOLVED_DIR came out of
# the python pass above. Accepted only when it is a real directory AND a
# git work tree — a parse gap, a missing path, or a non-repo directory all
# keep DIFF_DIR at "." (the hook's own cwd, exactly today's behavior; no new
# deny can come from a parse problem). gitd() is every diff-reading call
# from here down; `.rolepod/` config, phase-log, edit-ledger and
# cross-family evidence stay pinned to the hook cwd (R3) — see _pd_root.
DIFF_DIR="."
if [ -n "$RESOLVED_DIR" ] && [ -d "$RESOLVED_DIR" ] \
   && [ "$(git -C "$RESOLVED_DIR" rev-parse --is-inside-work-tree 2>/dev/null || true)" = "true" ]; then
  DIFF_DIR="$RESOLVED_DIR"
fi
gitd() { git -C "$DIFF_DIR" "$@"; }

# A forced fail-closed HEAD (past the shell-unwrap depth cap, above) is
# unsafe in a repo with NO commits yet: `git diff HEAD` errors on an unborn
# branch, the error is swallowed, DIFF_STAT comes back empty, and the hook
# exits before ever reading the staged file (round-3 external review) —
# `--cached` diffs the index against an empty tree and works with zero
# commits, so it is the correct fallback here (not a loosening: HEAD was
# only ever chosen to be MORE inclusive than --cached, never required).
if [ "$GIT_DIFF_BASE" = "HEAD" ] && ! gitd rev-parse HEAD >/dev/null 2>&1; then
  GIT_DIFF_BASE="--cached"
fi

# Compute diff stats — skip gate if trivial
DIFF_STAT=$(gitd diff $GIT_DIFF_BASE --numstat 2>/dev/null || echo "")
if [ "$GIT_DIFF_BASE" = "HEAD" ]; then
  UNTRACKED=$(gitd ls-files --others --exclude-standard 2>/dev/null | awk -F'\t' '{print "1\t0\t" $0}' || true)
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
# _pd_root is the config/evidence root for the REST of this file (R3): pinned
# to the hook's own cwd — every writer hook (edit-ledger, phase-log,
# bypass.log, session locks) put its state there — and only when the hook
# cwd is not itself a git work tree does it fall back to the resolved diff
# directory's toplevel.
_pd_root="$(git rev-parse --show-toplevel 2>/dev/null)" || true
[ -n "$_pd_root" ] || _pd_root="$(gitd rev-parse --show-toplevel 2>/dev/null)" || true
PRIVATE_DOCS=$( { gitd diff $GIT_DIFF_BASE --name-only 2>/dev/null | grep -E '^docs/rolepod/' || true; } | head -5 | tr '\n' ' ' | sed 's/ *$//')
if [ -n "$PRIVATE_DOCS" ] && [ ! -f "$_pd_root/.rolepod/docs-tracked" ]; then
  ROLEPOD_HOOK_MSG="precommit-gate BLOCKED — private working docs staged: $PRIVATE_DOCS. docs/rolepod/ is never committed. Fix: git restore --staged docs/rolepod; make sure .gitignore lists docs/rolepod/. Repo tracks them on purpose → create .rolepod/docs-tracked, commit again." python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || echo '{}'
  exit 0
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
  CONTENT_RISK=$(gitd diff $GIT_DIFF_BASE -U0 2>/dev/null \
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
LOGIC_LINES=$(gitd diff $GIT_DIFF_BASE -U0 2>/dev/null \
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
# SOFT-only, continued (v2.153.2): a generated file is not what a reviewer
# reads. Two mechanical sources, no guessing from names beyond lockfiles:
# a path git itself marks `linguist-generated` (.gitattributes /
# .git/info/attributes — the platform convention for rendered copies, dist,
# codegen, snapshots) and the standard lockfiles. Replayed over 80 commits
# of this repo: docs-only source changes asked for a reviewer because their
# rendered .toml copies counted as logic; a dependency add counts its whole
# lockfile. A path git quotes, or a commit run from a subdirectory, simply
# fails to match and keeps counting — the miss costs one extra ask, never a
# skipped one. LOGIC_COUNT above still holds every line: HARD does not move.
LOCK_RE='(^|/)(package-lock\.json|npm-shrinkwrap\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb?|Cargo\.lock|poetry\.lock|uv\.lock|Pipfile\.lock|composer\.lock|Gemfile\.lock|go\.sum|flake\.lock|mix\.lock|pubspec\.lock|Podfile\.lock|packages\.lock\.json)$'
GEN_PATHS=$(printf '%s\n' "$DIFF_STAT" | awk -F'\t' 'NF>=3{print $3}' | gitd check-attr --stdin linguist-generated 2>/dev/null | sed -nE 's/: linguist-generated: (set|true)$//p' || true)
REVIEW_LOGIC=$(gitd diff $GIT_DIFF_BASE -U0 2>/dev/null \
  | RP_GEN="$GEN_PATHS" RP_LOCK="$LOCK_RE" awk 'BEGIN{n=split(ENVIRON["RP_GEN"],a,"\n"); for(i=1;i<=n;i++) if (a[i]!="") gen[a[i]]=1; lock=ENVIRON["RP_LOCK"]}
         /^diff --git /{hdr=1; next}
         hdr && /^--- /{g=substr($0,5); sub(/[ \t]+$/,"",g); sub(/"$/,"",g); next}
         hdr && /^\+\+\+ /{f=substr($0,5); sub(/[ \t]+$/,"",f); sub(/"$/,"",f); if (f=="/dev/null") f=g; p=f; sub(/^"?[ab]\//,"",p); next}
         /^@@/{hdr=0; next}
         !hdr && /^[+-]/{ if (f !~ /\.(md|mdx|mdc|txt|rst|adoc)(\.tmpl)?$/ && f !~ /(^|\/)(README|LICENSE|CHANGELOG)$/ && !(p in gen) && p !~ lock) print }' \
  | grep -vE '^[+-][[:space:]]*$' | grep -vE '^[+-][[:space:]]*(#|//|/\*|\*/?|--|;)' | grep -vE "$VERSION_LINE_RE" | grep -c . || true)
REVIEW_LOGIC=${REVIEW_LOGIC:-0}
REVIEW_FILES=$(printf '%s\n' "$DIFF_STAT" | RP_GEN="$GEN_PATHS" RP_LOCK="$LOCK_RE" awk -F'\t' 'BEGIN{n=split(ENVIRON["RP_GEN"],a,"\n"); for(i=1;i<=n;i++) if (a[i]!="") gen[a[i]]=1; lock=ENVIRON["RP_LOCK"]}
         NF>=3 && $3 !~ /\.(md|mdx|mdc|txt|rst|adoc)(\.tmpl)?$/ && $3 !~ /(^|\/)(README|LICENSE|CHANGELOG)$/ && !($3 in gen) && $3 !~ lock {c++} END{print c+0}' || true)
REVIEW_FILES=${REVIEW_FILES:-0}

# Docs are written, not reviewed (v2.143.0): every staged path is prose
# (.md/.mdx/.mdc/.txt/.rst/.adoc, their .tmpl templates, or an extension-less README/LICENSE/CHANGELOG)
# → allow silently, whatever the size. The private-docs deny already ran.
# A prose file is never a risk path either (filtered before risk_filter
# above) — so a `+pattern` in .rolepod/risk-paths cannot re-flag a prose
# file; accepted limitation.
PROSE_N=$(printf '%s\n' "$DIFF_STAT" | awk -F'\t' 'NF>=3 && $3 ~ /\.(md|mdx|mdc|txt|rst|adoc)(\.tmpl)?$|(^|\/)(README|LICENSE|CHANGELOG)$/' | wc -l | tr -d ' ')
NONPROSE_N=$(printf '%s\n' "$DIFF_STAT" | awk -F'\t' 'NF>=3 && $3 !~ /\.(md|mdx|mdc|txt|rst|adoc)(\.tmpl)?$|(^|\/)(README|LICENSE|CHANGELOG)$/' | wc -l | tr -d ' ')
if [ "${PROSE_N:-0}" -gt 0 ] && [ "${NONPROSE_N:-1}" -eq 0 ]; then
  exit 0
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
SINCE_EPOCH=$(gitd log -1 --format=%ct 2>/dev/null || true)
SINCE_HUMAN=$(gitd log -1 --format=%cd --date=format:'%Y-%m-%d %H:%M' 2>/dev/null || true)
# Linked worktree (v2.153.0, R4): "since the last commit" follows the
# WORKTREE's own HEAD reflog, not its last commit — a `git merge --ff-only
# main` in the worktree shares main's commit clock but is not itself a
# commit, and must not slide the window past a reviewer dispatched before
# it. Newest reflog line whose subject starts with "commit" wins; none → the
# oldest line (the worktree's creation). Outside a linked worktree
# (git-dir == git-common-dir), unchanged.
# Resolved to an absolute, symlink-resolved path before comparing (MEDIUM-3,
# round-1 review): from a SUBDIRECTORY of the main worktree, git prints an
# absolute --git-dir but a RELATIVE --git-common-dir (e.g. "../.git") — the
# raw strings then always differ and every plain-repo subdir call wrongly
# took the linked-worktree reflog branch. `cd` each raw answer from DIFF_DIR
# (git prints it relative to the cwd it ran in) then `pwd -P`, so a relative
# or already-absolute answer resolves the same way.
GIT_DIR_RAW=$(gitd rev-parse --git-dir 2>/dev/null || true)
GIT_CDIR_RAW=$(gitd rev-parse --git-common-dir 2>/dev/null || true)
GIT_DIR_D=""; GIT_CDIR_D=""
[ -n "$GIT_DIR_RAW" ] && GIT_DIR_D=$(cd "$DIFF_DIR" 2>/dev/null && cd "$GIT_DIR_RAW" 2>/dev/null && pwd -P || true)
[ -n "$GIT_CDIR_RAW" ] && GIT_CDIR_D=$(cd "$DIFF_DIR" 2>/dev/null && cd "$GIT_CDIR_RAW" 2>/dev/null && pwd -P || true)
if [ -n "$GIT_DIR_D" ] && [ -n "$GIT_CDIR_D" ] && [ "$GIT_DIR_D" != "$GIT_CDIR_D" ]; then
  RLOG=$(gitd reflog show --date=unix --format='%gd %gs' HEAD 2>/dev/null || true)
  if [ -n "$RLOG" ]; then
    RL_PICK=$(printf '%s\n' "$RLOG" | grep -E '^HEAD@\{[0-9]+\} commit' | head -1 || true)
    [ -n "$RL_PICK" ] || RL_PICK=$(printf '%s\n' "$RLOG" | tail -1)
    WT_EPOCH=$(printf '%s' "$RL_PICK" | sed -E 's/^HEAD@\{([0-9]+)\}.*/\1/')
    case "$WT_EPOCH" in ''|*[!0-9]*) WT_EPOCH="" ;; esac
    if [ -n "$WT_EPOCH" ]; then
      SINCE_EPOCH="$WT_EPOCH"
      SINCE_HUMAN=$(python3 -I -c '
import datetime, sys
print(datetime.datetime.fromtimestamp(int(sys.argv[1])).strftime("%Y-%m-%d %H:%M"))
' "$WT_EPOCH" 2>/dev/null || true)
    fi
  fi
fi
[ -n "$SINCE_HUMAN" ] && SINCE_HUMAN="since last commit $SINCE_HUMAN" || SINCE_HUMAN="whole session (no commit yet)"
GATE_EV_DONE=0
if [ -f "$SESSION_STATE" ] && command -v python3 >/dev/null 2>&1; then
  # One session_state.py call computes the window at DIFF_DIR itself (same
  # algorithm as SINCE_EPOCH above, kept in bash for SINCE_HUMAN and the
  # lib-less branch below — S11 pins the two windows equal) and returns all
  # five numbers in one pass: test edits, high-risk edits, reviewers, strong
  # reviewers (internal + anchored external) and the anchored external count
  # alone. It folds in the transcript scan, the hook-auto phase-log backstop
  # (v2.144.0, see below), every CLI's "dispatch-proof" rows (Codex ships
  # lib/ and used to take this same branch while ignoring its own proof
  # rows — reproduced 2026-09-24) and the edit ledger — MAX per source,
  # never summed (spec Desired 2).
  GATE_EV=$(printf '%s' "$INPUT" | python3 "$SESSION_STATE" gate-evidence "$DIFF_DIR" 2>/dev/null || true)
  if [ -n "$GATE_EV" ]; then
    read -r TEST_EDITS HIGH_RISK_EDITS REVIEWERS STRONG_REVIEWERS XREV <<< "$GATE_EV"
    GATE_EV_DONE=1
  fi
elif command -v python3 >/dev/null 2>&1; then
  # Renders without lib/session_state.py (Cursor / Antigravity — no lib/,
  # build/render.sh:668-672): their transcripts are not Claude-JSONL, so
  # reviewer evidence comes from the SubagentStop dispatch-proof log written
  # by the adapter's own dispatch hook. Only reviewer counts exist on this
  # path — test/high-risk edit evidence needs transcript parsing, and the
  # HARD paths that consume those counts cannot fire when both sides read
  # as 0. Strong class is decided by agent_type alone: the logged model is
  # hook-reported with unverified provenance (may be the parent's), and the
  # agent TOMLs pin strong reviewers to the strong model anyway. `provenance:
  # hook-stdin` IS required (HIGH-1, round-1 review): every real writer sets
  # it (Codex subagent-model-log.sh, Cursor dispatch-log.sh, Antigravity
  # model-log.sh, opencode rolepod.js) — none of these bundles has a hook
  # that could ever write a dispatch-proof row WITHOUT it, so requiring the
  # field closes the hand-written-line forgery at no cost to a real one.
  PHASE_LOG="$_pd_root/.rolepod/evidence/phase-log.jsonl"
  read -r REVIEWERS STRONG_REVIEWERS <<< "$(phase_log_reviewer_count dispatch-proof "$SINCE_EPOCH" "$PHASE_LOG" "hook-stdin")"
fi
TEST_EDITS=${TEST_EDITS:-0}
HIGH_RISK_EDITS=${HIGH_RISK_EDITS:-0}
REVIEWERS=${REVIEWERS:-0}
STRONG_REVIEWERS=${STRONG_REVIEWERS:-0}
if [ "$GATE_EV_DONE" -ne 1 ]; then
  # Edit ledger (v2.134.0): CLI-neutral edit evidence written at edit time by
  # every CLI's edit hook (hooks/edit-ledger.py) — the lib-less path only;
  # the python tally above already folds this in for the lib path.
  LEDGER="$(dirname "$0")/edit-ledger.py"
  if [ -f "$LEDGER" ] && command -v python3 >/dev/null 2>&1; then
    read -r L_TEST L_RISK <<< "$(python3 -I "$LEDGER" count "$SINCE_EPOCH" 2>/dev/null || echo "0 0")"
    [ "${L_TEST:-0}" -gt "${TEST_EDITS:-0}" ] 2>/dev/null && TEST_EDITS=$L_TEST
    [ "${L_RISK:-0}" -gt "${HIGH_RISK_EDITS:-0}" ] 2>/dev/null && HIGH_RISK_EDITS=$L_RISK
  fi
fi
TEST_EDITS=${TEST_EDITS:-0}
HIGH_RISK_EDITS=${HIGH_RISK_EDITS:-0}

# External strong pass (satellite-first, v2.61.0) — cross-family reviews are
# plain Bash `codex exec` / `gemini -p` / `claude -p` calls, invisible to
# transcript parsing on EVERY CLI. review-code's evidence anchor appends a
# phase-log "review" line with reviewer:"external" pointing at the saved raw
# output; count it as a strong reviewer only when that file really exists
# inside .rolepod/evidence/ and is >= 500 bytes — a bare claim without the
# artifact is ignored (claim-based evidence is what this gate exists to stop).
# The python tally above already computed XREV for the lib path — this
# bash-python block is the lib-less path's own copy (kept, per Desired 2).
EV_ROOT="$_pd_root/.rolepod/evidence"
XREV=${XREV:-0}
if [ "$GATE_EV_DONE" -ne 1 ] && [ -f "$EV_ROOT/phase-log.jsonl" ] && command -v python3 >/dev/null 2>&1; then
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
            if not isinstance(raw, str) or not raw or raw.startswith("/") or ".." in raw:
                continue
            # P1 (Lead close-out, round 2 residual): raw must sit under
            # evidence/external/ — the python twin (_anchored_external_count
            # in session_state.py) carries the full rationale.
            if not raw.startswith("external/"):
                continue
            candidate = os.path.join(ev, raw)
            ext_root = os.path.realpath(os.path.join(ev, "external"))
            real = os.path.realpath(candidate)
            if real != ext_root and not real.startswith(ext_root + os.sep):
                continue
            try:
                if os.path.getsize(candidate) >= 500:
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

# The plan is the readable record of each step; the gate writes to it, never
# reads from it (spec Desired 10, 2026-09-24). One "phase":"gate" row per
# judged commit, HEAD BEFORE the commit so `rolepod-ticket log --sha <sha>`
# can match it as `<sha>^` after the commit lands. Fail-open: any error here
# never changes HARD_BLOCK / AUTO_PASS — it only ever runs right before an
# `exit 0` this file already reaches.
append_gate_row() {
  local decision="$1" head_sha
  head_sha=$(gitd rev-parse HEAD 2>/dev/null || echo "")
  mkdir -p "$EV_ROOT" 2>/dev/null || return 0
  ROLEPOD_GATE_DECISION="$decision" ROLEPOD_GATE_TESTS="$TEST_EDITS" \
  ROLEPOD_GATE_RISK="$HIGH_RISK_EDITS" ROLEPOD_GATE_REVIEWERS="$REVIEWERS" \
  ROLEPOD_GATE_STRONG="$STRONG_REVIEWERS" ROLEPOD_GATE_EXTERNAL="${XREV:-0}" \
  ROLEPOD_GATE_HEAD="$head_sha" ROLEPOD_EV_DIR="$EV_ROOT" python3 -I -c '
import json, os, datetime
def _int(name):
    try:
        return int(os.environ.get(name) or 0)
    except Exception:
        return 0
line = {
    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "phase": "gate",
    "decision": os.environ.get("ROLEPOD_GATE_DECISION") or "",
    "tests": _int("ROLEPOD_GATE_TESTS"),
    "risk": _int("ROLEPOD_GATE_RISK"),
    "reviewers": _int("ROLEPOD_GATE_REVIEWERS"),
    "strong": _int("ROLEPOD_GATE_STRONG"),
    "external": _int("ROLEPOD_GATE_EXTERNAL"),
    "head": os.environ.get("ROLEPOD_GATE_HEAD") or "",
}
try:
    with open(os.path.join(os.environ.get("ROLEPOD_EV_DIR") or ".", "phase-log.jsonl"), "a") as f:
        f.write(json.dumps(line, ensure_ascii=False) + "\n")
except Exception:
    pass
' 2>/dev/null || true
}

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
REASON+="Run S1-S5 (simplicity) + T1-T6 (tests) + F1-F5 (finish) — finish-work Pre-merge gates, check-work Failure modes. "
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
# Runs in a subshell cd-ed to DIFF_DIR (v2.153.0): the script reads
# `git diff --cached` off its own cwd, so it must see the resolved commit
# directory, not the hook's.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT_WARN=""
if [ -f "$SCRIPT_DIR/test-diff-lint.sh" ]; then
  LINT_WARN=$( (cd "$DIFF_DIR" 2>/dev/null && bash "$SCRIPT_DIR/test-diff-lint.sh") 2>/dev/null || true)
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
  NOTE+=" ($SINCE_HUMAN). Evidence is per-window — confirm S1-S5 (simplicity) / T1-T6 (tests) / F1-F5 (finish) — finish-work Pre-merge gates, check-work Failure modes — cover THIS change."
  [ -n "$LINT_WARN" ] && NOTE+=" | $LINT_WARN"
  ROLEPOD_HOOK_MSG="$NOTE" python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || true
  append_gate_row "pass"
  exit 0
fi

if [ "$HARD_BLOCK" -eq 1 ]; then
  # Env-passed — quotes in the reason must not break the JSON emitter.
  [ -n "$LINT_WARN" ] && REASON+=" | $LINT_WARN"
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
  append_gate_row "deny"
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
# A rolepod-ticket worktree (basename `*-wt-*-tN*`, the shape `ticket.sh
# start` always creates) already gets the Lead's ONE combined review before
# release (spec lean-loop-2026-09-23 Task 2, implement-plan Review) — the
# "0 reviewers on a logic diff" sentence would double-count it there.
WT_TOPLEVEL_BASE=$(basename "$(gitd rev-parse --show-toplevel 2>/dev/null || echo "$DIFF_DIR")")
case "$WT_TOPLEVEL_BASE" in
  *-wt-*-t[0-9]*) IN_TICKET_WT=1 ;;
  *) IN_TICKET_WT=0 ;;
esac
if [ "$REVIEW_LOGIC" -gt 0 ] && [ "$REVIEWERS" -eq 0 ] && [ "$IN_TICKET_WT" -eq 0 ] && { [ "${REVIEW_FILES:-0}" -gt 1 ] || [ "$REVIEW_LOGIC" -gt 5 ]; }; then WARN+="0 reviewers on a logic diff = the author reviewed it. Fix: dispatch rolepod:universal-reviewer (read-only, two axes) on the diff, then commit (review-code Pick reviewers; R2 = one file + test). Exception: the task owner already had it reviewed, or the diff is config / generated copies / message text → commit. "; fi
WARN+="Gates S1-S5 (simplicity) / T1-T6 (tests) / F1-F5 (finish) — finish-work Pre-merge gates, check-work Failure modes — are advisory here; ROLEPOD_GATES_HARD=1 enforces."
[ -n "$LINT_WARN" ] && WARN+=" | $LINT_WARN"

ROLEPOD_HOOK_MSG="$WARN" python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || true
append_gate_row "soft"

exit 0
