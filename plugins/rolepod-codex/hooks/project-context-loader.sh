#!/bin/bash
# SessionStart — inject git activity for current repo. Silent if not in git.
#
# Scope: repo name, branch, dirty count, recent commits, hot files.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
CWD=$(echo "$INPUT" | python3 -I -c "import sys,json;print(json.load(sys.stdin).get('cwd','') or '')" 2>/dev/null || echo "$PWD")
cd "$CWD" 2>/dev/null || exit 0

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
NAME=$(basename "$REPO")
BRANCH=$(git -C "$REPO" branch --show-current 2>/dev/null || echo "?")
DIRTY=$(git -C "$REPO" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
COMMITS=$(git -C "$REPO" log --oneline -5 2>/dev/null || echo "")
HOT=$(git -C "$REPO" log --since="7 days ago" --name-only --pretty=format: 2>/dev/null \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -5 \
  | awk '{printf "  %s (%dx)\n", $2, $1}' || echo "")

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
    open_n = 0; done_n = 0; nxt = None; head = ""
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
        m = re.match(r"^### ((Task ?|T)\d+.*)", line)
        if m:
            head = m.group(1).strip()
        if re.match(r"^\s*-\s*\[\s\]", line):
            open_n += 1
            if nxt is None:
                nxt = head
        elif re.match(r"^\s*-\s*\[[xX]\]", line):
            done_n += 1
    if open_n == 0 or done_n == 0:
        continue
    out.append("**Open plan:** `%s` — %d done / %d open · next: %s" % (os.path.relpath(p, repo), done_n, open_n, (nxt or "first unchecked step")[:80]))
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
# unprompted). No pool file and a second CLI installed → ONE silent context
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
if [ -f "$_xf" ] && [ ! -f "$HOME/.rolepod/cross-family" ] && [ ! -f "$REPO/.rolepod/cross-family" ]; then
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
