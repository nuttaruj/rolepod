#!/bin/bash
# Public shell entry point; captured session profile wins, then workflow.mode resolver.
# Usage: workflow-mode.sh [--source] [--project-root DIR]
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
READER="$HERE/rolepod_config.py"
[ -f "$READER" ] || READER="$ROOT/hooks/lib/rolepod_config.py"

source_flag=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) source_flag=1; shift ;;
    --project-root) [ "$#" -ge 2 ] || exit 2; export ROLEPOD_PROJECT_ROOT=$2; shift 2 ;;
    *) echo "workflow-mode: unknown argument: $1" >&2; exit 2 ;;
  esac
done

mode=${ROLEPOD_SESSION_MODE:-}
source=${ROLEPOD_SESSION_SOURCE:-}
if [[ ! "$mode" =~ ^(lite|standard|full)$ ]]; then
  CLI=${ROLEPOD_SESSION_CLI:-}
  SESSION_MODE="$HERE/session-mode.sh"
  [ -f "$SESSION_MODE" ] || SESSION_MODE="$ROOT/hooks/lib/session-mode.sh"
  . "$SESSION_MODE" 2>/dev/null || true
  if [[ -z "$CLI" && "${CODEX_THREAD_ID:-}" =~ ^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$ ]] \
    && type rolepod_session_profile_path >/dev/null 2>&1; then
    _codex_profile=$(rolepod_session_profile_path codex "$CODEX_THREAD_ID" 2>/dev/null || true)
    [ -f "$_codex_profile" ] && CLI=codex
  fi
  if [ -n "$CLI" ] && type rolepod_session_profile_load >/dev/null 2>&1; then
    rolepod_session_profile_load "${ROLEPOD_HOOK_INPUT:-}" "$CLI"
    mode=$ROLEPOD_SESSION_MODE source=$ROLEPOD_SESSION_SOURCE
  fi
fi
if [[ ! "$mode" =~ ^(lite|standard|full)$ ]]; then
  out=$(python3 -I "$READER" mode || true)
  mode=$(printf '%s\n' "$out" | awk -F= '$1 == "mode" {print $2}')
  source=$(printf '%s\n' "$out" | awk -F= '$1 == "source" {print $2}')
fi
case "$mode" in lite|standard|full) ;; *) mode=standard ;; esac
case "$source" in project|global|default|uncaptured) ;; *) source=default ;; esac
if [ "$source_flag" = 1 ]; then echo "$mode ($source)"; else echo "$mode"; fi
