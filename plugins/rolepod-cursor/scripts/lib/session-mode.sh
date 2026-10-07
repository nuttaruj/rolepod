#!/bin/bash
# Session profile snapshot bridge. Runtime consumers do not invoke Python or
# reread config; only the SessionStart capture entry writes a profile.

rolepod_session_id_from_input() {
  local json=${1:-}
  ROLEPOD_SESSION_ID=""
  if [[ "$json" =~ \"(session_id|sessionId|conversation_id|conversationId)\"[[:space:]]*:[[:space:]]*\"([A-Za-z0-9][A-Za-z0-9_.:-]{0,127})\" ]]; then
    ROLEPOD_SESSION_ID=${BASH_REMATCH[2]}
  fi
}

rolepod_session_cwd_from_input() {
  local json=${1:-}
  ROLEPOD_INPUT_CWD=""
  if [[ "$json" =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"\\]*)\" ]]; then
    ROLEPOD_INPUT_CWD=${BASH_REMATCH[1]}
  fi
}

rolepod_session_profile_path() {
  local cli=${1:-} sid=${2:-}
  [[ "$cli" =~ ^(claude|codex|cursor|antigravity|opencode)$ ]] || return 1
  [[ "$sid" =~ ^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$ ]] || return 1
  printf '%s/.rolepod/session-profiles/%s/%s.mode' "${HOME:-/nonexistent}" "$cli" "$sid"
}

rolepod_session_profile_apply() {
  local mode=${1:-lite} source=${2:-uncaptured}
  case "$mode" in lite|standard|full) ;; *) mode=lite; source=uncaptured ;; esac
  case "$source" in project|global|default|uncaptured) ;; *) source=uncaptured ;; esac
  ROLEPOD_SESSION_MODE=$mode
  ROLEPOD_SESSION_SOURCE=$source
  export ROLEPOD_SESSION_MODE ROLEPOD_SESSION_SOURCE
}

# rolepod_gate_action <gate-id> -> deny|warn|silent for the session mode.
# Unknown mode -> lite; unknown gate -> silent. Pure bash, no python.
rolepod_gate_action() {
  local gate=${1:-} mode=${ROLEPOD_SESSION_MODE:-lite}
  case "$mode" in lite|standard|full) ;; *) mode=lite ;; esac
  case "$gate" in
    private-docs|subagent-ship|cannot-wait|collision|bare-fanout|strong-fanout|bare-writer)
      echo deny ;;
    scope-generic|scope-bare-workflow|scope-test-role|scope-readonly-role)
      case "$mode" in lite) echo warn ;; *) echo deny ;; esac ;;
    risk-no-test)
      case "$mode" in full) echo deny ;; *) echo warn ;; esac ;;
    code-no-test)
      case "$mode" in full) echo deny ;; *) echo silent ;; esac ;;
    *) echo silent ;;
  esac
}

rolepod_session_profile_store() {
  local cli=${1:-} sid=${2:-} mode=${3:-standard} source=${4:-uncaptured} path dir tmp
  path=$(rolepod_session_profile_path "$cli" "$sid") || return 1
  case "$mode" in lite|standard|full) ;; *) return 1 ;; esac
  case "$source" in project|global|default|uncaptured) ;; *) source=uncaptured ;; esac
  dir=${path%/*}
  (umask 077; mkdir -p "$dir" && chmod 700 "${dir%/*}" "$dir") 2>/dev/null || return 1
  tmp="$dir/.${sid}.$$.tmp"
  (umask 077; printf '%s\n%s\n' "$mode" "$source" > "$tmp" && chmod 600 "$tmp" && mv -f "$tmp" "$path") 2>/dev/null || { rm -f "$tmp" 2>/dev/null || true; return 1; }
  return 0
}

# Shell entry points with no CLI named (workflow-mode, plan-lint):
# when a captured profile exists for the native session id of Claude Code or
# Codex, set ROLEPOD_SESSION_CLI / ROLEPOD_SESSION_ID (shell vars, not exported).
rolepod_session_native_profile() {
  local pair path
  for pair in "claude:${CLAUDE_CODE_SESSION_ID:-}" "codex:${CODEX_THREAD_ID:-}"; do
    path=$(rolepod_session_profile_path "${pair%%:*}" "${pair#*:}" 2>/dev/null) || continue
    if [[ -f "$path" ]]; then ROLEPOD_SESSION_CLI=${pair%%:*}; ROLEPOD_SESSION_ID=${pair#*:}; return 0; fi
  done
  return 1
}

rolepod_session_profile_load() {
  local json=${1:-} cli=${2:-${ROLEPOD_SESSION_CLI:-unknown}} sid path mode source native_id=${ROLEPOD_SESSION_ID:-}
  if [[ "$cli" = unknown || -z "$cli" ]]; then
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then cli=claude
    elif [[ "${CODEX_THREAD_ID:-}" =~ ^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$ ]]; then cli=codex
    fi
  fi
  mode=${ROLEPOD_SESSION_MODE:-}
  source=${ROLEPOD_SESSION_SOURCE:-}
  case "$mode" in lite|standard|full)
    rolepod_session_profile_apply "$mode" "${source:-uncaptured}"
    return 0
  esac
  rolepod_session_id_from_input "$json"
  sid=$ROLEPOD_SESSION_ID
  if [[ -z "$sid" && -n "$native_id" && "$native_id" =~ ^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$ ]]; then sid=$native_id; fi
  if [[ -z "$sid" && "$cli" = claude && "${CLAUDE_CODE_SESSION_ID:-}" =~ ^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$ ]]; then sid=$CLAUDE_CODE_SESSION_ID; fi
  if [[ -z "$sid" && "$cli" = codex && "${CODEX_THREAD_ID:-}" =~ ^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$ ]]; then sid=$CODEX_THREAD_ID; fi
  path=$(rolepod_session_profile_path "$cli" "$sid" 2>/dev/null || true)
  if [[ -n "$path" && -f "$path" ]]; then
    {
      IFS= read -r mode || true
      IFS= read -r source || true
    } < "$path"
    rolepod_session_profile_apply "$mode" "$source"
    return 0
  fi
  rolepod_session_profile_apply lite uncaptured
}
