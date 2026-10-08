#!/bin/bash
# workflow-mode — the public shell entry point: a captured session profile wins,
# then the workflow.mode resolver (project layer, git root, installed layout).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
WORKFLOW="$ROOT/core/skills/using-rolepod/scripts/workflow-mode.sh"
fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

check() { # name expected-out expected-warn(0|1)
  local n=0; [ -n "$ERR" ] && n=$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')
  if [ "$OUT" = "$2" ] && [ "$n" = "$3" ]; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1 (out='$OUT' want='$2'; stderr lines=$n want=$3)"
    fail=$((fail+1))
  fi
}

# cwd in a subdirectory of a git repo: the project layer is the git root's file.
g=$(mktemp -d "$TMP/g.XXXXXX"); mkdir -p "$g/home" "$g/repo/.rolepod" "$g/repo/sub"
git -C "$g/repo" init -q
printf '{"workflow":{"mode":"full"}}' > "$g/repo/.rolepod/config.json"
OUT=$(cd "$g/repo/sub" && HOME="$g/home" bash "$WORKFLOW" --source 2>/dev/null) || true; ERR=
check "git subdir reads the git root file" "full (project)" 0

# The session profile found by the native session id wins over config, in the
# repo layout and in an installed layout (readers bundled beside the scripts).
pf=$(mktemp -d "$TMP/pf.XXXXXX"); mkdir -p "$pf/home/.rolepod/session-profiles/claude" "$pf/home/.rolepod/session-profiles/codex" "$pf/proj/.rolepod"
printf 'full\nglobal\n' > "$pf/home/.rolepod/session-profiles/claude/sess-R1.mode"
printf 'lite\nproject\n' > "$pf/home/.rolepod/session-profiles/codex/thr-R2.mode"
printf '{"workflow":{"mode":"standard"}}' > "$pf/proj/.rolepod/config.json"
inst="$pf/inst"
for s in using-rolepod; do
  mkdir -p "$inst/plugins/rolepod/skills/$s/scripts"
  cp "$ROOT/core/skills/$s/scripts/"*.sh "$ROOT/hooks/lib/session-mode.sh" "$ROOT/hooks/lib/rolepod_config.py" "$inst/plugins/rolepod/skills/$s/scripts/"
done
penv() { ( cd "$pf/proj" && env -u ROLEPOD_SESSION_MODE -u ROLEPOD_SESSION_SOURCE -u ROLEPOD_SESSION_CLI -u CODEX_THREAD_ID -u CLAUDE_CODE_SESSION_ID HOME="$pf/home" "$@" 2>/dev/null ) || true; }
ERR=
OUT=$(penv CLAUDE_CODE_SESSION_ID=sess-R1 bash "$WORKFLOW" --source);  check "workflow-mode: CLAUDE_CODE_SESSION_ID profile wins over config" "full (global)" 0
OUT=$(penv CODEX_THREAD_ID=thr-R2 bash "$WORKFLOW" --source);          check "workflow-mode: CODEX_THREAD_ID profile wins over config" "lite (project)" 0
OUT=$(penv CLAUDE_CODE_SESSION_ID=sess-none bash "$WORKFLOW" --source); check "workflow-mode: no profile -> config" "standard (project)" 0
OUT=$(penv CLAUDE_CODE_SESSION_ID=sess-R1 bash "$inst/plugins/rolepod/skills/using-rolepod/scripts/workflow-mode.sh" --source)
check "workflow-mode installed layout: profile wins" "full (global)" 0

if [ "$fail" -eq 0 ]; then
  echo "  ✓ pass"
  exit 0
else
  echo "  ✗ fail ($fail)"
  exit 1
fi
