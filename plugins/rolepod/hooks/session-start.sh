#!/bin/bash
# Combined SessionStart profile capture and shared context/lock entry.
set -uo pipefail

CLI="${ROLEPOD_SESSION_CLI:-unknown}"
REUSE=0
SYNC=""
FORMAT=context
while [ "$#" -gt 0 ]; do
  case "$1" in
    --cli) CLI="${2:-unknown}"; shift 2 ;;
    --reuse) REUSE=1; shift ;;
    --sync) SYNC="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-context}"; shift 2 ;;
    *) shift ;;
  esac
done
case "$CLI" in claude|codex|cursor|antigravity|opencode) ;; *) CLI=unknown ;; esac

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_rcfg="$HOOK_DIR/lib"
. "$_rcfg/session-mode.sh"
INPUT=$(cat 2>/dev/null || echo '{}')
META=$(printf '%s' "$INPUT" | python3 -I -c 'import json,os,sys
try: d=json.load(sys.stdin)
except Exception: d={}
cwd=d.get("cwd") or (d.get("workspace_roots") or [""])[0] or (d.get("workspacePaths") or [""])[0] or os.getcwd()
print(cwd)
print(d.get("source", ""))' 2>/dev/null || printf '%s\n' "$PWD")
{ IFS= read -r CWD || true; IFS= read -r EVENT_SOURCE || true; } <<< "$META"
[ -n "$CWD" ] || CWD="$PWD"
rolepod_session_id_from_input "$INPUT"
SESSION_ID=$ROLEPOD_SESSION_ID
export ROLEPOD_SESSION_CLI="$CLI" ROLEPOD_SESSION_ID
export ROLEPOD_PROJECT_ROOT="$CWD"

if [ "$REUSE" -eq 1 ] || [ "$EVENT_SOURCE" = compact ]; then
  rolepod_session_profile_load "$INPUT" "$CLI"
else
  unset ROLEPOD_SESSION_MODE ROLEPOD_SESSION_SOURCE
  READER="$_rcfg/rolepod_config.py"
  [ -f "$READER" ] || READER="$HOOK_DIR/rolepod_config.py"
  # Create-only global defaults remain a startup exception. It does not parse
  # existing config and is deliberately before the one effective-mode read.
  [ -f "$READER" ] && python3 -I "$READER" init >/dev/null 2>&1 || true
  RESOLVED=$(ROLEPOD_PROJECT_ROOT="$CWD" python3 -I "$READER" mode 2>/dev/null || true)
  MODE=lite SOURCE=default
  while IFS= read -r line; do
    case "$line" in
      mode=lite|mode=standard|mode=full) MODE=${line#mode=} ;;
      source=project|source=global|source=default) SOURCE=${line#source=} ;;
    esac
  done <<< "$RESOLVED"
  rolepod_session_profile_apply "$MODE" "$SOURCE"
  if [ -n "$SESSION_ID" ]; then
    rolepod_session_profile_store "$CLI" "$SESSION_ID" "$MODE" "$SOURCE" || rolepod_session_profile_apply lite uncaptured
  else
    rolepod_session_profile_apply lite uncaptured
  fi
fi

# Native env-channel adapters (Cursor, Antigravity) own their context/lock
# handlers and call this entry only to capture their startup profile.
if [ "$FORMAT" = env ]; then
  ROLEPOD_STARTUP_MODE="$ROLEPOD_SESSION_MODE" ROLEPOD_STARTUP_SOURCE="$ROLEPOD_SESSION_SOURCE" ROLEPOD_STARTUP_CLI="$CLI" python3 -I -c '
import json, os
print(json.dumps({"env": {
  "ROLEPOD_SESSION_MODE": os.environ["ROLEPOD_STARTUP_MODE"],
  "ROLEPOD_SESSION_SOURCE": os.environ["ROLEPOD_STARTUP_SOURCE"],
  "ROLEPOD_SESSION_CLI": os.environ["ROLEPOD_STARTUP_CLI"],
}}))
' 2>/dev/null || echo '{}'
  exit 0
fi

PART_CONTEXT=""
PART_CORE=""
PART_LOCK=""
PART_SYNC=""
if [ "$ROLEPOD_SESSION_MODE" != lite ]; then
  if [ "$CLI" = claude ] && [ -f "$HOOK_DIR/always-on-loader.sh" ]; then
    PART_CORE=$(printf '%s' "$INPUT" | ROLEPOD_SESSION_CLI="$CLI" ROLEPOD_SESSION_ID="$SESSION_ID" ROLEPOD_SESSION_MODE="$ROLEPOD_SESSION_MODE" ROLEPOD_SESSION_SOURCE="$ROLEPOD_SESSION_SOURCE" bash "$HOOK_DIR/always-on-loader.sh" 2>/dev/null || true)
  fi
  PART_CONTEXT=$(printf '%s' "$INPUT" | ROLEPOD_SESSION_CLI="$CLI" ROLEPOD_SESSION_ID="$SESSION_ID" ROLEPOD_SESSION_MODE="$ROLEPOD_SESSION_MODE" ROLEPOD_SESSION_SOURCE="$ROLEPOD_SESSION_SOURCE" bash "$HOOK_DIR/project-context-loader.sh" 2>/dev/null || true)
  PART_LOCK=$(printf '%s' "$INPUT" | ROLEPOD_SESSION_CLI="$CLI" ROLEPOD_SESSION_ID="$SESSION_ID" ROLEPOD_SESSION_MODE="$ROLEPOD_SESSION_MODE" ROLEPOD_SESSION_SOURCE="$ROLEPOD_SESSION_SOURCE" bash "$HOOK_DIR/session-lifecycle.sh" --lock --cli "$CLI" 2>/dev/null || true)
fi
if [ "$CLI" = claude ] && [ "$ROLEPOD_SESSION_MODE" = lite ] && [ -f "$HOOK_DIR/always-on-loader.sh" ]; then
  PART_CORE=$(printf '%s' "$INPUT" | ROLEPOD_SESSION_CLI="$CLI" ROLEPOD_SESSION_ID="$SESSION_ID" ROLEPOD_SESSION_MODE="$ROLEPOD_SESSION_MODE" ROLEPOD_SESSION_SOURCE="$ROLEPOD_SESSION_SOURCE" bash "$HOOK_DIR/always-on-loader.sh" 2>/dev/null || true)
fi
if [ "$CLI" = codex ]; then
  if [ -z "$SYNC" ]; then
    [ -f "$HOOK_DIR/agent-sync.sh" ] && SYNC="$HOOK_DIR/agent-sync.sh"
    [ -n "$SYNC" ] || SYNC="$(cd "$HOOK_DIR/../../adapters/codex/plugins/rolepod/hooks" 2>/dev/null && pwd)/agent-sync.sh"
  fi
  if [ -f "$SYNC" ]; then
    PART_SYNC=$(printf '%s' "$INPUT" | bash "$SYNC" 2>/dev/null || true)
  fi
fi

# SessionStart exposes one output object; combine supported advisory context
# from the sequential shared handlers. Codex agent-sync remains a bootstrap
# exception and may still produce context in Lite.
ROLEPOD_STARTUP_MODE="$ROLEPOD_SESSION_MODE" ROLEPOD_STARTUP_SOURCE="$ROLEPOD_SESSION_SOURCE" ROLEPOD_STARTUP_CORE="$PART_CORE" ROLEPOD_STARTUP_CONTEXT="$PART_CONTEXT" ROLEPOD_STARTUP_LOCK="$PART_LOCK" ROLEPOD_STARTUP_SYNC="$PART_SYNC" python3 -I -c '
import json, os
parts = ["Active Rolepod workflow profile: %s (source: %s). This profile is fixed for this session; restart or open a new session to apply configuration changes." % (os.environ.get("ROLEPOD_STARTUP_MODE", "lite"), os.environ.get("ROLEPOD_STARTUP_SOURCE", "uncaptured"))]
for key in ("ROLEPOD_STARTUP_CORE", "ROLEPOD_STARTUP_CONTEXT", "ROLEPOD_STARTUP_LOCK", "ROLEPOD_STARTUP_SYNC"):
    value = os.environ.get(key, "").strip()
    if not value:
        continue
    try:
        obj = json.loads(value)
        msg = (obj.get("hookSpecificOutput") or {}).get("additionalContext", "")
        if msg:
            parts.append(msg)
    except Exception:
        parts.append(value)
if parts:
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "\n\n".join(parts)}}))
' 2>/dev/null || true
