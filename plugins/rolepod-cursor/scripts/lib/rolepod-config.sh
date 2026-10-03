#!/bin/bash
# rolepod-config.sh — shell-only adapter for the captured session profile.
# Runtime hooks never launch Python or reread config to select their mode.

_ROLEPOD_CFG_DIR="${BASH_SOURCE[0]%/*}"
[ "$_ROLEPOD_CFG_DIR" != "${BASH_SOURCE[0]}" ] || _ROLEPOD_CFG_DIR=.

rolepod_cfg_load() {
  . "$_ROLEPOD_CFG_DIR/session-mode.sh"
  rolepod_session_profile_load "${INPUT:-}" "${ROLEPOD_SESSION_CLI:-unknown}"
}
