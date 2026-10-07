#!/bin/bash
# PreToolUse(Edit|Write|MultiEdit) — the review-in-flight advisory only. Every
# other edit, high-risk paths included, is silent here.
#
# Default tiering:
#   Trivial path (docs/configs/lockfiles)             → silent
#   Normal code edit                                  → silent
#   Review in flight: live detached cross-family    → one advisory line, never a deny —
#     job + edit to a file its diff touches (v2.93.0)   the job reads the tree live; an
#                                                       early edit voids its verdict
#   High-risk path → silent: the R4 review is the track-end review. Never a deny
#     (v2.47.0): edit-time HARD blocks were the measured reason users turn the
#     gates off for good.
#
# Every mode runs the hook.
set -euo pipefail
unset XF_RUNNER

# Cross-family runner (v2.179.0: inside the cross-family skill) — resolved
# on FIRST USE only (this hook fires on every Edit/Write/MultiEdit call): a
# plugin tree's own skills/, else the source repo's core/skills/ copy.
# Prints the canonicalized path so every message that quotes it is real and
# runnable. "" when neither resolves — no home-dir launcher-payload
# fallback (no launcher is installed any more).
xfam_runner() {
  local d
  for d in "$(dirname "${BASH_SOURCE[0]}")/../skills/cross-family/scripts" \
           "$(dirname "${BASH_SOURCE[0]}")/../core/skills/cross-family/scripts"; do
    [ -f "$d/cross-family.sh" ] && { (cd "$d" && printf '%s/cross-family.sh' "$(pwd)"); return 0; }
  done
  return 0
}

# Bypass accountability: a used bypass is recorded to .rolepod/evidence/bypass.log
# (reason via ROLEPOD_BYPASS_REASON), never blocked. Fail-open on any error.
rolepod_log_bypass() {
  _rlb_log=""
  _rlb_root="$(git rev-parse --show-toplevel 2>/dev/null)" || _rlb_root=""
  if [ -n "$_rlb_root" ] && mkdir -p "$_rlb_root/.rolepod/evidence" 2>/dev/null; then
    _rlb_log="$_rlb_root/.rolepod/evidence/bypass.log"
  elif [ -n "${HOME:-}" ] && mkdir -p "$HOME/.rolepod" 2>/dev/null; then
    _rlb_log="$HOME/.rolepod/gate-bypass.log"   # no repo root: never unlogged (parity with precommit-gate.sh)
  else
    return 0
  fi
  _rlb_reason="${ROLEPOD_BYPASS_REASON:-unreasoned}"
  _rlb_reason="${_rlb_reason//\"/ }"
  printf '{"ts":"%s","hook":"%s","var":"%s","reason":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$_rlb_reason" \
    >> "$_rlb_log" 2>/dev/null || true
}

# workflow.mode is resolved from the event workspace's root; the environment
# config fallback is handled by the shared resolver.
_rcfg="${BASH_SOURCE[0]%/*}"; [ "$_rcfg" != "${BASH_SOURCE[0]}" ] || _rcfg=.
INPUT=$(cat 2>/dev/null || echo '{}')
 . "$_rcfg/lib/session-mode.sh"
rolepod_session_profile_load "$INPUT" "${ROLEPOD_SESSION_CLI:-unknown}"

# ONE python3 pass for tool_name + file path (was 2 spawns — ~16ms on
# every edit). tool first via read -r; path LAST, slurped with $(cat) so
# an empty trailing field cannot EOF-fail the read under set -e.
# file_path (Claude tools) → notebook_path → path → apply_patch body markers
# (Codex patches carry "*** Add/Update/Delete File: <path>" lines, no field).
PARSED=$(printf '%s' "$INPUT" | python3 -I -c "
import json, re, sys
tool = ''
aid = ''
p = ''
try:
    d = json.load(sys.stdin)
    tool = d.get('tool_name', '') or ''
    aid = str(d.get('agent_id', '') or '').replace('\\n', ' ')
    ti = d.get('tool_input', {}) or {}
    p = ti.get('file_path', '') or ti.get('notebook_path', '') or ti.get('path', '') or ''
    if not p:
        body = ti.get('input', '') or ti.get('patch', '') or ''
        m = re.search(r'\*\*\* (?:Add|Update|Delete) File: (.+)', body)
        p = m.group(1).strip() if m else ''
except Exception:
    pass
print(tool)
print(aid)
print(p)
" 2>/dev/null) || exit 0
{ read -r TOOL; read -r AGENT_ID; FILE=$(cat); } <<EOF
$PARSED
EOF

# Claude edit tools + Codex's apply_patch (the Codex adapter registers this
# same script on matcher "apply_patch" — without it here the hook is inert
# on Codex: disjoint tool-name sets).
echo "$TOOL" | grep -qE '^(Edit|Write|MultiEdit|NotebookEdit|apply_patch)$' || exit 0

# Repo-relative normalization (breaker round 2, item 1): the in-flight check below reads
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

# Review in flight (v2.93.0): a detached cross-family job is still running
# on this repo and reads the live tree for context. An edit to a file its
# attached diff touches turns that verdict into an artifact and re-runs the
# job — one advisory line, never a deny (v2.47.0). Files under review =
# `+++ b/<path>` of every --attach in the job's args (written with %q, so
# eval is the decoder); attachments gone (tmp cleaned) → the current WIP
# (git diff HEAD) stands in. Liveness walk = precommit-gate.sh's
# xfam_running_job, dual-root (D6, keep in parity): a job started as `cd
# <worktree> && cross-family.sh … --detach` writes its job dir under the
# WORKTREE's own evidence, which can differ from the hook's own process cwd
# when the edited FILE itself lives in that worktree.
XF_INFLIGHT=""
gr_inflight_scan() {
  # Nearest EXISTING ancestor of FILE's directory (a NEW file in a
  # not-yet-created directory resolves through it) — the second root
  # candidate below.
  _gr2_walk="$(dirname "$FILE")"
  while [ ! -d "$_gr2_walk" ] && [ "$_gr2_walk" != "/" ] && [ "$_gr2_walk" != "." ]; do _gr2_walk="$(dirname "$_gr2_walk")"; done
  _gr_seen=""
  for _gr_root in "$(git rev-parse --show-toplevel 2>/dev/null || true)" "$(git -C "$_gr2_walk" rev-parse --show-toplevel 2>/dev/null || true)"; do
    [ -n "$_gr_root" ] || continue
    case " $_gr_seen " in *" $_gr_root "*) continue ;; esac
    _gr_seen="$_gr_seen $_gr_root"
    [ -d "$_gr_root/.rolepod/evidence/external/jobs" ] || continue
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
      _jid=$(basename "$_jd")
      _under=$( ( eval "set -- $(cat "$_jd/args" 2>/dev/null)" 2>/dev/null; while [ $# -gt 0 ]; do if [ "$1" = "--attach" ] && [ -f "${2:-}" ]; then grep -E '^\+\+\+ b/' "$2" 2>/dev/null | sed -E 's#^\+\+\+ b/##; s/[[:space:]]+$//'; shift; fi; shift; done ) 2>/dev/null || true )
      [ -n "$_under" ] || _under=$(git -C "$_gr_root" diff HEAD --name-only 2>/dev/null || true)
      if printf '%s\n' "$_under" | grep -qxF -- "$_gr_rel"; then
        _js=$(cat "$_jd/started" 2>/dev/null || echo 0); _jm=$(( ($(date +%s) - _js) / 60 ))
        XF_RUNNER="${XF_RUNNER-$(xfam_runner)}"
        XF_INFLIGHT="⏸ REVIEW IN FLIGHT: cross-family job $_jid (running ${_jm} min) reads '$_gr_rel' live — this edit turns its verdict into an artifact and re-runs the job. Fix: park the edit until \`bash '$XF_RUNNER' --collect $_jid\` returns; work outside the diff meanwhile. Exception: a dead job → --collect says so and this line stops. "
        break
      fi
    done
    [ -n "$XF_INFLIGHT" ] && break
  done
  return 0
}
gr_inflight_scan

# The selected workflow.mode is authoritative. In-flight advisories remain
# visible in every mode.

# Only the in-flight advisory speaks: the R4 review is the track-end review,
# so a high-risk edit gets no commit-block or lens-report line.
[ -n "$XF_INFLIGHT" ] || exit 0
# Env-passed so an apostrophe in the message cannot break the JSON emitter.
ROLEPOD_HOOK_MSG="$XF_INFLIGHT" python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'additionalContext': os.environ.get('ROLEPOD_HOOK_MSG', '')}}))
" 2>/dev/null || echo '{}'
exit 0
