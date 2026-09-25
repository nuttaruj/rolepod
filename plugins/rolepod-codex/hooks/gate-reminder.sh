#!/bin/bash
# PreToolUse(Edit|Write|MultiEdit) — HARD-block edits that violate
# discipline rules + soft-warn on high-risk path edits. Normal code edits
# are silent here (the per-edit Q1-Q4 reminder was cut for cost).
#
# Default tiering:
#   Trivial path (docs/configs/lockfiles)             → silent
#   Normal code edit                                  → silent
#   Review in flight: live detached cross-family    → one advisory line, never a deny —
#     job + edit to a file its diff touches (v2.93.0)   the job reads the tree live; an
#                                                       early edit voids its verdict
#   High-risk path, a strong reviewer   → silent — the commit gate would pass.
#     has already finished
#   High-risk path, 0 strong reviewers  → ONE line, only now: fact (high-risk
#     since the last commit               edit, 0 strong reviewers) → Fix
#                                          (security-engineer + a finished
#                                          strong universal-reviewer, or the
#                                          external when the pool is on) →
#                                          Exception (user-set bypass only).
#     Never a deny (v2.47.0): edit-time HARD blocks were the measured reason
#     users set ROLEPOD_GATES_SOFT for good (CourtBook: 33 high-risk edits in
#     one day, 116 unreasoned bypasses) — which then silenced the commit gate
#     too. One hard checkpoint, at commit (precommit-gate.sh); this hook
#     informs.
#
# Bypass envs (user-set only):
#   ROLEPOD_GATES_SOFT=1   — silence the would-block line entirely
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

# ONE python3 pass for tool_name + file path (was 2 spawns — ~16ms on
# every edit). tool first via read -r; path LAST, slurped with $(cat) so
# an empty trailing field cannot EOF-fail the read under set -e.
# file_path (Claude tools) → notebook_path → path → apply_patch body markers
# (Codex patches carry "*** Add/Update/Delete File: <path>" lines, no field).
PARSED=$(printf '%s' "$INPUT" | python3 -I -c "
import json, re, sys
tool = ''
p = ''
try:
    d = json.load(sys.stdin)
    tool = d.get('tool_name', '') or ''
    ti = d.get('tool_input', {}) or {}
    p = ti.get('file_path', '') or ti.get('notebook_path', '') or ti.get('path', '') or ''
    if not p:
        body = ti.get('input', '') or ti.get('patch', '') or ''
        m = re.search(r'\*\*\* (?:Add|Update|Delete) File: (.+)', body)
        p = m.group(1).strip() if m else ''
except Exception:
    pass
print(tool)
print(p)
" 2>/dev/null) || exit 0
{ read -r TOOL; FILE=$(cat); } <<EOF
$PARSED
EOF

# Claude edit tools + Codex's apply_patch (the Codex adapter registers this
# same script on matcher "apply_patch" — without it here the hook is inert
# on Codex: disjoint tool-name sets).
echo "$TOOL" | grep -qE '^(Edit|Write|MultiEdit|NotebookEdit|apply_patch)$' || exit 0

# Repo-relative normalization (breaker round 2, item 1): every classification
# check below (COMMIT_TEST_EXEMPT / PROSE_EXEMPT / risk_filter) reads
# FILE_REL, not the raw FILE — a CLI's own absolute spelling must resolve
# against the repo root the same realpath-aware way as the commit gate, or a
# root-anchored `.rolepod/risk-paths` line (`^design_tokens/`) and an
# ancestor directory named `auth` OUTSIDE the repo disagree with it.
FILE_REL="$FILE"
_gr2_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_gr2_root" ] && [ -n "$FILE" ]; then
  _gr2_rel="$FILE"
  if [ "${_gr2_rel#/}" != "$_gr2_rel" ]; then   # a NEW file in a not-yet-existing directory: resolve the nearest existing ancestor, re-append the rest
    _gr2_walk=$(dirname "$_gr2_rel"); _gr2_tail=$(basename "$_gr2_rel")
    while [ ! -d "$_gr2_walk" ] && [ "$_gr2_walk" != "/" ] && [ "$_gr2_walk" != "." ]; do _gr2_tail="$(basename "$_gr2_walk")/$_gr2_tail"; _gr2_walk=$(dirname "$_gr2_walk"); done
    _gr2_dir=$(cd "$_gr2_walk" 2>/dev/null && pwd -P || true)
    [ -n "$_gr2_dir" ] && _gr2_rel="$_gr2_dir/$_gr2_tail"
  fi
  _gr2_rootp=$(cd "$_gr2_root" 2>/dev/null && pwd -P || printf '%s' "$_gr2_root")
  case "$_gr2_rel" in "$_gr2_rootp"/*) FILE_REL="${_gr2_rel#"$_gr2_rootp"/}" ;; "$_gr2_root"/*) FILE_REL="${_gr2_rel#"$_gr2_root"/}" ;; esac
fi

# Test files are exempt: writing the RED test on a high-risk path is the very
# action the hard block demands, so flagging it would deadlock. Mirrors
# session_state.py's TEST_FILE filename alternatives — byte-equivalent to the
# commit gate's own test-name filter (precommit-gate.sh HIGH_RISK= line), so
# a filename the gate exempts is never flagged risk here either (F4).
COMMIT_TEST_EXEMPT=0
if [[ "$FILE_REL" =~ \.(test|spec)\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|kt|swift|cs|php)$ ]] \
   || [[ "$FILE_REL" =~ (^|/)(test_[^/]*|[^/]*_test|[^/]*_spec)\.(py|go|rs|rb|php)$ ]] \
   || [[ "$FILE_REL" =~ (^|/)[^/]*Tests?\.(java|kt|cs|swift|php|scala)$ ]]; then
  COMMIT_TEST_EXEMPT=1
fi

# The HIGH-RISK banner below keys off COMMIT_TEST_EXEMPT only — a bare test
# DIRECTORY (tests/fixtures/seed_auth_users.py) is NOT filename-exempt, so it
# still shows the banner: the commit gate calls a risk-term file under a test
# directory high-risk by design (v2.85.2), and the banner must predict that
# deny, not hide it (F5 / Desired 4). Strong-reviewer evidence comes from
# session_state.py below, not from a variable here.

# A prose file is never a risk path at commit either (precommit-gate.sh's
# HIGH_RISK= line strips these by extension before risk_filter runs) — the
# banner must agree, so `.cursor/rules/auth.mdc` never shows HIGH-RISK.
PROSE_EXEMPT=0
if [[ "$FILE_REL" =~ \.(md|mdx|mdc|txt|rst|adoc)(\.tmpl)?$ ]] \
   || [[ "$FILE_REL" =~ (^|/)(README|LICENSE|CHANGELOG)$ ]]; then
  PROSE_EXEMPT=1
fi

# High-risk path flag — match on path segments only, not substrings.
HIGH_RISK=""
# Canonical high-risk regex — byte-for-byte the same segment/anchor set as
# precommit-gate.sh's HIGH_RISK= line and session_state.py's HIGH_RISK_PATH, so a file cannot
# pass at edit time and then block at commit time.
_RISK_HIT=$(printf '%s\n' "$FILE_REL" | risk_filter '(^|/|_)(auth|authn|authz|authentication|authorization|billing|payment|payments|migration|migrations|credit|credits|permission|permissions|secret|secrets|crypto|cryptography|token|tokens|oauth|jwt|sso|saml|webhook|webhooks|stripe|paypal|charge|charges|invoice|invoices|deletion|deletions|erasure|gdpr|security)(/|\.|_|$)' | head -1 || true)
MONEY_RISK=""
if [ "$COMMIT_TEST_EXEMPT" -eq 0 ] && [ "$PROSE_EXEMPT" -eq 0 ] && [ -n "$_RISK_HIT" ]; then
  HIGH_RISK="HIGH-RISK path → R4 floor: security-engineer + ONE general strong pass before commit. "
  # money / auth subset — retained unused: C1 (2026-09-19) gives money / auth
  # the same R4 floor as every high-risk path; the whole computation is a
  # separate, out-of-scope cut.
  MONEY_RISK=$(printf '%s\n' "$FILE_REL" | grep -iE '(^|/|_)(auth|authn|authz|authentication|authorization|billing|payment|payments|credit|credits|secret|secrets|crypto|cryptography|oauth|jwt|sso|saml|stripe|paypal|charge|charges|invoice|invoices|deletion|deletions|erasure|gdpr)(/|\.|_|$)' | head -1 || true)
fi

# Review in flight (v2.93.0): a detached cross-family job is still running
# on this repo and reads the live tree for context. An edit to a file its
# attached diff touches turns that verdict into an artifact and re-runs the
# job — one advisory line, never a deny (v2.47.0). Files under review =
# `+++ b/<path>` of every --attach in the job's args (written with %q, so
# eval is the decoder); attachments gone (tmp cleaned) → the current WIP
# (git diff HEAD) stands in. Liveness walk = precommit-gate.sh's
# xfam_running_job (keep in parity).
XFAM_INFLIGHT=""
_gr_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_gr_root" ] && [ -d "$_gr_root/.rolepod/evidence/external/jobs" ] && [ "${ROLEPOD_GATES_SOFT:-0}" != "1" ]; then
  # Repo-relative target. Both sides go through pwd -P: git resolves symlinks
  # (/private/var vs /var on macOS) while the tool passes the path as typed,
  # and a mismatched prefix would silently skip the match.
  _gr_rel="$FILE"
  if [ "${_gr_rel#/}" != "$_gr_rel" ]; then   # a NEW file in a not-yet-existing directory: resolve the nearest existing ancestor, re-append the rest
    _gr_walk=$(dirname "$_gr_rel"); _gr_tail=$(basename "$_gr_rel")
    while [ ! -d "$_gr_walk" ] && [ "$_gr_walk" != "/" ] && [ "$_gr_walk" != "." ]; do _gr_tail="$(basename "$_gr_walk")/$_gr_tail"; _gr_walk=$(dirname "$_gr_walk"); done
    _gr_dir=$(cd "$_gr_walk" 2>/dev/null && pwd -P || true)
    [ -n "$_gr_dir" ] && _gr_rel="$_gr_dir/$_gr_tail"
  fi
  _gr_rootp=$(cd "$_gr_root" 2>/dev/null && pwd -P || printf '%s' "$_gr_root")
  case "$_gr_rel" in "$_gr_rootp"/*) _gr_rel="${_gr_rel#"$_gr_rootp"/}" ;; "$_gr_root"/*) _gr_rel="${_gr_rel#"$_gr_root"/}" ;; esac
  for _jd in "$_gr_root"/.rolepod/evidence/external/jobs/*/; do
    [ -d "$_jd" ] || continue; [ -f "$_jd/status" ] && continue
    _jp=$(cat "$_jd/pid" 2>/dev/null); case "$_jp" in ''|*[!0-9]*) continue ;; esac
    kill -0 "$_jp" 2>/dev/null || continue
    ps -o command= -p "$_jp" 2>/dev/null | grep -q 'cross-family' || continue
    _jid=$(basename "$_jd"); _jk=$(printf '%s' "$_jid" | sed -n 's/^[^-]*-\([a-z]*\)-.*/\1/p'); _jk=${_jk:-review}
    if [ "$_jk" = "implement" ] && [ -f "$_jd/allow" ]; then   # an implement job: every edit OUTSIDE the ticket's Files allowed is reverted when it returns — warn on those, stay silent inside the scope
      _in=0; while IFS= read -r _ae; do [ -n "$_ae" ] || continue; case "$_ae" in */) case "$_gr_rel" in "${_ae%/}"/*) _in=1 ;; esac ;; *) [ "$_gr_rel" = "$_ae" ] && _in=1 ;; esac; done < "$_jd/allow"
      [ "$_in" -eq 1 ] && continue
      _js=$(cat "$_jd/started" 2>/dev/null || echo 0); _jm=$(( ($(date +%s) - _js) / 60 ))
      XFAM_INFLIGHT="⏸ EXTERNAL IMPLEMENT IN FLIGHT: cross-family job $_jid (running ${_jm} min) is EDITING this tree — an edit outside the ticket's Files allowed made now (this one included) is reverted when the job returns (a copy is kept under the job's .reverted/). Fix: park the edit until \`rolepod-cross-family --collect $_jid\` returns, or work in another worktree. "
      break
    fi
    _under=$( ( eval "set -- $(cat "$_jd/args" 2>/dev/null)" 2>/dev/null; while [ $# -gt 0 ]; do if [ "$1" = "--attach" ] && [ -f "${2:-}" ]; then grep -E '^\+\+\+ b/' "$2" 2>/dev/null | sed -E 's#^\+\+\+ b/##; s/[[:space:]]+$//'; shift; fi; shift; done ) 2>/dev/null || true )
    [ -n "$_under" ] || _under=$(git -C "$_gr_root" diff HEAD --name-only 2>/dev/null || true)
    if printf '%s\n' "$_under" | grep -qxF -- "$_gr_rel"; then
      _js=$(cat "$_jd/started" 2>/dev/null || echo 0); _jm=$(( ($(date +%s) - _js) / 60 ))
      XFAM_INFLIGHT="⏸ REVIEW IN FLIGHT: cross-family job $_jid (running ${_jm} min) reads '$_gr_rel' live — this edit turns its verdict into an artifact and re-runs the job. Fix: park the edit until \`rolepod-cross-family --collect $_jid\` returns; work outside the diff meanwhile. Exception: a dead job → --collect says so and this line stops. "
      break
    fi
  done
fi

# Silent pass when nothing is risky. Normal code / docs / config edits
# never see a reminder from this hook — the Q1-Q4 doctrine lives in
# CLAUDE.md / AGENTS.md and using-rolepod skill, read once per session.
if [ -z "$HIGH_RISK" ]; then
  [ -n "$XFAM_INFLIGHT" ] || exit 0
  ROLEPOD_HOOK_MSG="$XFAM_INFLIGHT" python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || echo '{}'
  exit 0
fi

# Session-state inspection — the same tally the commit gate reads (spec
# Desired 2, 2026-09-25): one session_state.py call computes the window at
# the EDITED FILE's directory and returns strong reviewers since the last
# commit — transcript scan + hook-auto phase-log "dispatch" backstop.
# This canonical script ships only where hooks/lib/session_state.py ships
# alongside it (Claude, Codex — build/render.sh:320-333, 426-434); Cursor's
# own gate-reminder is a separate hand-written adapter script under
# adapters/cursor/scripts/.
SESSION_STATE="$(dirname "$0")/lib/session_state.py"
STRONG_REVIEWERS=0
# Walk up to the nearest EXISTING ancestor (LOW-8, round-1 review): a Write
# into a not-yet-created directory, or a relative Codex apply_patch path
# when the hook cwd is not the repo root, made `git -C "$FILE_DIR"` fail —
# the window then read as "no commits" (whole history), not "since the
# last commit", and the reminder stayed silent while the gate denied. Same
# walk as the FILE_REL block above.
FILE_DIR="$(dirname "$FILE")"
while [ ! -d "$FILE_DIR" ] && [ "$FILE_DIR" != "/" ] && [ "$FILE_DIR" != "." ]; do
  FILE_DIR="$(dirname "$FILE_DIR")"
done
[ -d "$FILE_DIR" ] || FILE_DIR="."
if [ -f "$SESSION_STATE" ] && command -v python3 >/dev/null 2>&1; then
  GR_EV=$(printf '%s' "$INPUT" | python3 "$SESSION_STATE" gate-evidence "$FILE_DIR" 2>/dev/null || true)
  [ -n "$GR_EV" ] && read -r _ _ _ STRONG_REVIEWERS _ <<< "$GR_EV"
fi
STRONG_REVIEWERS=${STRONG_REVIEWERS:-0}

SOFT_MODE=0
[ "${ROLEPOD_GATES_SOFT:-0}" = "1" ] && { SOFT_MODE=1; rolepod_log_bypass "gate-reminder" "ROLEPOD_GATES_SOFT"; }

# ONE line, only when the commit would block now (spec Desired 2, 2026-09-25):
# fact (high-risk edit, strong reviewers since the last commit = 0) → Fix →
# Exception. No always-on careful-mode banner, no per-CLI reviewer-list
# builder, no test-first nudge — the gate's own deny (at commit) is the one hard
# checkpoint; this is a cheap, silent-unless-blocking prediction of it.
WOULD_BLOCK=""
if [ -n "$HIGH_RISK" ] && [ "$SOFT_MODE" -eq 0 ] && [ "$STRONG_REVIEWERS" -eq 0 ]; then
  WOULD_BLOCK="COMMIT WILL BLOCK — HIGH-RISK edit, strong reviewers since the last commit = 0. Fix: the writer loop's rolepod:security-engineer + a FINISHED strong rolepod:universal-reviewer dispatch before commit (the external cross-family pass counts when the pool is on). Exception: user-set bypass only (ROLEPOD_GATES_SOFT). "
fi

# Emit reminder ONLY when high-risk AND would-block — no generic Q1-Q4 nag,
# no output at all once a strong reviewer has already finished (spec
# Success criterion 2, 2026-09-25).
[ -z "${XFAM_INFLIGHT}${WOULD_BLOCK}" ] && exit 0

# Env-passed (see deny path) so apostrophes in the banner cannot break it.
ROLEPOD_HOOK_MSG="${XFAM_INFLIGHT}${WOULD_BLOCK}" python3 -I -c "
import json, os
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')
  }
}))
" 2>/dev/null || echo '{}'

exit 0
