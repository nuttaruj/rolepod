#!/bin/bash
# rolepod-config.sh — source this, then call `rolepod_cfg_load` once per hook.
# Sets ROLEPOD_CFG_GATES (off|soft|hard) and ROLEPOD_CFG_NUDGE (on|off) from
# $HOME/.rolepod/config.json with ONE python spawn. The reader's warnings are
# dropped here (a hook's stderr can reach a model); doctor shows them.
# Defaults on any failure: soft / on. Never fails.

_ROLEPOD_CFG_DIR="${BASH_SOURCE[0]%/*}"
[ "$_ROLEPOD_CFG_DIR" != "${BASH_SOURCE[0]}" ] || _ROLEPOD_CFG_DIR=.

rolepod_cfg_load() {
  local out line
  ROLEPOD_CFG_GATES=soft
  ROLEPOD_CFG_NUDGE=on
  out=$(python3 -I "$_ROLEPOD_CFG_DIR/rolepod_config.py" shell 2>/dev/null) || return 0   # the reader's warnings name the file and key: a hook never shows them (doctor and the runner do)
  while IFS= read -r line; do
    case "$line" in
      gates=off|gates=soft|gates=hard) ROLEPOD_CFG_GATES=${line#gates=} ;;
      nudge=on|nudge=off) ROLEPOD_CFG_NUDGE=${line#nudge=} ;;
    esac
  done <<EOF
$out
EOF
  return 0
}
