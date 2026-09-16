#!/usr/bin/env bash
# rolepod / Antigravity PreInvocation hook — parent-active marker + session lock.
#
# agy contract (measured on agy 1.2.3, 2026-09-16 — see docs/cli-support.md):
#   stdin  = {"conversationId", "modelName", "workspacePaths": [...],
#             "transcriptPath", "artifactDirectoryPath", ...}  (camelCase; no cwd,
#             no session_id, no GEMINI_/CLAUDE_ env; hook cwd = the plugin dir)
#   stdout = NOTHING on the happy path. agy honours no context field on
#            PreInvocation — an unknown field is a hook error — so this hook
#            only leaves side effects. The always-on core reaches the model
#            through AGENTS.md, never through a hook.
#
# Side effects (both fail-open):
#   <worktree>/.rolepod/parent-active        — child plugins pick with-rolepod mode
#   ~/.rolepod/session-locks/<sha16>/agy-<conversationId>.lock
#                                            — same lock dir as every other CLI, so
#                                              the Claude/Codex worktree-guard sees an
#                                              agy session as a sibling. Released by
#                                              stop-unlock.sh on Stop.
set -uo pipefail

IN=$(cat 2>/dev/null || true)
[ -n "$IN" ] || exit 0

IFS=$'\t' read -r WS SID <<< "$(printf '%s' "$IN" | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ws = (d.get("workspacePaths") or [""])[0] or ""
print(ws + "\t" + (d.get("conversationId") or ""))
' 2>/dev/null || true)"
[ -n "${WS:-}" ] || exit 0          # no --add-dir / no project → nothing to mark

WT=$(git -C "$WS" rev-parse --show-toplevel 2>/dev/null) || exit 0
{ mkdir -p "$WT/.rolepod" 2>/dev/null && printf 'v1\n' > "$WT/.rolepod/parent-active"; } 2>/dev/null || true

[ -n "${SID:-}" ] || exit 0
H=$(printf '%s' "$WT" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
LD="$HOME/.rolepod/session-locks/$H"
mkdir -p "$LD" 2>/dev/null || exit 0
touch "$LD/agy-$SID.lock" 2>/dev/null || true
exit 0
