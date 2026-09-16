#!/usr/bin/env bash
# rolepod / Antigravity Stop hook — release this session's worktree lock.
#
# Mirrors session-start.sh exactly: lock id agy-<conversationId> under
# sha256(worktree)[:16], worktree from workspacePaths[0]. A miss removes
# nothing and the 30-min stale prune in the other CLIs' guards still covers
# it — strictly fail-open. Prints nothing: agy's Stop result accepts no
# field we would want to send (measured 2026-09-16).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IN=$(cat 2>/dev/null || true)
[ -n "$IN" ] || exit 0

IFS=$'\t' read -r WS SID TP <<< "$(printf '%s' "$IN" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ws = (d.get("workspacePaths") or [""])[0] or ""
print(ws + "\t" + (d.get("conversationId") or "") + "\t" + (d.get("transcriptPath") or ""))
' 2>/dev/null || true)"
[ -n "${WS:-}" ] && [ -n "${SID:-}" ] || exit 0

WT=$(git -C "$WS" rev-parse --show-toplevel 2>/dev/null) || exit 0
# Route record (v2.135.0): agy's transcript_full.jsonl → the tier the Lead stated this
# turn lands in the phase-log (hooks/route_check.py reads the agy line shape).
if [ -n "${TP:-}" ] && [ -f "$HERE/route_check.py" ]; then
  ( cd "$WT" && printf '{"transcript_path":%s}' "$(printf '%s' "$TP" | python3 -I -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" | python3 -I "$HERE/route_check.py" --record ) >/dev/null 2>&1 || true
fi
H=$(printf '%s' "$WT" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
LD="$HOME/.rolepod/session-locks/$H"
rm -f "$LD/agy-$SID.lock" "$LD/agy-$SID.files" 2>/dev/null || true
exit 0
