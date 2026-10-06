#!/bin/bash
# SessionStart — inject git activity for current repo. Silent if not in git.
#
# Scope: repo name, branch, dirty count, recent commits, hot files.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
_rcfg="${BASH_SOURCE[0]%/*}"; [ "$_rcfg" != "${BASH_SOURCE[0]}" ] || _rcfg=.
. "$_rcfg/lib/session-mode.sh"
rolepod_session_profile_load "$INPUT" "${ROLEPOD_SESSION_CLI:-unknown}"
CWD=$(printf '%s' "$INPUT" | python3 -I -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd') or (d.get('workspace_roots') or [''])[0] or (d.get('workspacePaths') or [''])[0])" 2>/dev/null || echo "$PWD")
[ -n "$CWD" ] || CWD="$PWD"
export ROLEPOD_PROJECT_ROOT="$CWD"
cd "$CWD" 2>/dev/null || exit 0

# Machine config (written once): a plugin-manager update never runs install.sh,
# so the first session start writes ~/.rolepod/config.json when it is absent.
# The bash test comes first, so a normal start spawns nothing; silent, fail-open.

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
NAME=$(basename "$REPO")
BRANCH=$(git -C "$REPO" branch --show-current 2>/dev/null || echo "?")
DIRTY=$(git -C "$REPO" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
COMMITS=$(git -C "$REPO" log -5 --pretty=format:'%h %<(92,trunc)%s' 2>/dev/null | sed 's/[[:space:]]*$//' || echo "")
HOT=$(git -C "$REPO" log --since="7 days ago" --name-only --pretty=format: 2>/dev/null \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -5 \
  | awk '{printf "  %s (%dx)\n", $2, $1}' || echo "")
# A manifest / lockfile on top is release churn, not a work area: drop the block.
printf '%s\n' "$HOT" | head -1 | grep -Eq '(^|[[:space:]/])(plugin|marketplace|package|opencode|composer)\.json \(|(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?|Cargo\.(toml|lock)|go\.(mod|sum)|poetry\.lock|uv\.lock|Gemfile\.lock|composer\.lock|CHANGELOG\.md|VERSION) \(' && HOT=""

[ -z "$COMMITS" ] && exit 0

CTX="**$NAME** @ \`$BRANCH\` ($DIRTY uncommitted)\n\n**Recent:**\n\`\`\`\n$COMMITS\n\`\`\`"
[ -n "$HOT" ] && CTX="$CTX\n\n**Hot (7d):**\n$HOT"

# Session-start state pointers (v2.102.0): the newest plan with unchecked
# steps, the last phase-log line — "read the progress file first" made
# automatic for continuation sessions (measured: 21 compactions in one
# project lineage and the plan was never re-read).
STATE=$(ROLEPOD_PCL_REPO="$REPO" python3 -I - <<'PY' 2>/dev/null || true
import glob, json, os, re
repo = os.environ["ROLEPOD_PCL_REPO"]; out = []
plans = sorted(glob.glob(os.path.join(repo, "docs", "rolepod", "plans", "*.md")), key=os.path.getmtime, reverse=True)
for p in plans:
    try:
        text = open(p, encoding="utf-8", errors="ignore").read()
    except Exception:
        continue
    # Fence rule (2026-09-28-plan-fence contract): a fenced line (opening
    # delimiter through the closing one) is literal — it never counts as an
    # open/done box or a task heading, however many the line's text spells.
    # Per task (same rule as ticket.sh plan_task_rows): done = at least one
    # box and none open; a `## ` heading closes the task block. Running ids
    # come from the plan's `## Status` rows.
    tasks = []; cur = None; running = []; insec = False
    fence_ch = None; fence_len = 0
    for line in text.splitlines():
        if fence_ch is None:
            fm = re.match(r"^ {0,3}(\x60{3,}|~{3,})", line)
            if fm:
                fence_ch = fm.group(1)[0]; fence_len = len(fm.group(1))
                continue
        else:
            if re.match(r"^ {0,3}" + re.escape(fence_ch) + "{" + str(fence_len) + ",}[ \t]*$", line):
                fence_ch = None; fence_len = 0
            continue
        m = re.match(r"^### (?:Task ?|T)(\d+)", line)
        if m:
            cur = [m.group(1), 0, 0]; tasks.append(cur); insec = False
            continue
        if line.startswith("## "):
            cur = None
            insec = bool(re.match(r"^## Status\s*$", line))
            continue
        if insec:
            sm = re.match(r"^- Task (\d+) — .*: running \([^)]*\)\s*$", line)
            if sm:
                running.append(sm.group(1))
            continue
        if cur is None:
            continue
        if re.match(r"^\s*-\s*\[\s\]", line):
            cur[1] += 1; cur[2] += 1
        elif re.match(r"^\s*-\s*\[[xX]\]", line):
            cur[2] += 1
    done_ids = [t[0] for t in tasks if t[2] > 0 and t[1] == 0]
    run_ids = [i for i in dict.fromkeys(running) if i not in done_ids]
    if not tasks or len(done_ids) == len(tasks) or (not done_ids and not run_ids):
        continue
    nxt = [t[0] for t in tasks if t[0] not in done_ids and t[0] not in run_ids]
    line = "**Open plan:** `%s` — Task %d/%d done" % (os.path.relpath(p, repo), len(done_ids), len(tasks))
    if run_ids:
        line += " · running: " + ", ".join(run_ids)
    if nxt:
        line += " · next: " + nxt[0]
    out.append(line)
    break
log = os.path.join(repo, ".rolepod", "evidence", "phase-log.jsonl")
if os.path.isfile(log):
    try:
        with open(log, "rb") as f:
            f.seek(max(0, os.path.getsize(log) - 4096)); last = [l for l in f.read().decode("utf-8", "ignore").splitlines() if l.strip()][-1]
        d = json.loads(last)
        out.append("**Last phase:** %s %s %s" % (d.get("phase", ""), str(d.get("ts", ""))[:16], d.get("verdict") or d.get("tier") or d.get("action") or ""))
    except Exception:
        pass
print("\\n".join(out))
PY
)
[ -n "$STATE" ] && CTX="$CTX\n\n$STATE"

# Cross-family pool nudge (v2.142.0: no opt-in question — rolepod never asks
# unprompted). Pool not on (the shared reader says so) and a second CLI installed → ONE silent context
# line says how to set it up when the user asks. Runner locator (v2.179.0:
# inside the cross-family skill): a plugin tree's own skills/, else the
# source repo's core/skills/ copy — canonicalized so --candidates below
# runs a real, quotable path.
xfam_runner() {
  local d
  for d in "$(dirname "${BASH_SOURCE[0]}")/../skills/cross-family/scripts" \
           "$(dirname "${BASH_SOURCE[0]}")/../core/skills/cross-family/scripts"; do
    [ -f "$d/cross-family.sh" ] && { (cd "$d" && printf '%s/cross-family.sh' "$(pwd)"); return 0; }
  done
  return 0
}
_xf="$(xfam_runner)"
_xr="$(dirname "${BASH_SOURCE[0]}")/lib/rolepod_config.py"   # the one reader; missing = no nudge (never a guess)
_xp=""   # the reader's `configured=` line: only "no" (no pool key at all) earns the one setup line; a pool that is on or deliberately off stays silent
[ -f "$_xf" ] && [ -f "$_xr" ] && { _xp=$(python3 -I "$_xr" pool 2>/dev/null | grep '^configured=' || true); }
if [ -f "$_xf" ] && [ "$_xp" = "configured=no" ]; then
  _lead="${ROLEPOD_LEAD_CLI:-}"
  if [ -z "$_lead" ] && [ -n "${CLAUDE_PROJECT_DIR:-}${CLAUDE_PLUGIN_ROOT:-}" ]; then _lead=claude; fi
  _cand=""
  if [ -n "$_lead" ]; then
    _cand=$( { bash "$_xf" --candidates --lead "$_lead" 2>/dev/null || true; } | tr '\n' ' ' | sed 's/ *$//' || true)
  fi
  [ -n "$_cand" ] && CTX="$CTX\n\ncross-family pool: not set (opt-in, never asked for you). When the user asks to set it up: the cross-family skill's setup steps (installed: $_cand)."
fi

# Env-pass the context so a crafted commit message / branch name cannot escape
# the Python string literal (RCE). CTX is built with literal `\n`; convert to
# real newlines here since the old inline literal relied on Python to do it.
ROLEPOD_HOOK_CTX="${CTX//\\n/$'\n'}" python3 -I -c "
import json, os
print(json.dumps({'hookSpecificOutput':{'hookEventName':'SessionStart','additionalContext':os.environ.get('ROLEPOD_HOOK_CTX','')}}))
" 2>/dev/null || echo '{}'
