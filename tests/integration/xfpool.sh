# Sourced by the cross-family cases: state a pool in the machine setting
# ($HOME/.rolepod/config.json) from the short legacy text.
#   setpool '<text>'       the machine pool (remembered as the base)
#   setpool_over '<text>'  a temporary pool for one check (the base comes back with restorepool)
#   restorepool            the base again (or no setting when there was none)
#   droppool               no pool setting at all
XFPOOL_PY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/xfpool.py"
XF_BASE=""
_xf_write() { mkdir -p "$HOME/.rolepod"; printf "$1" | python3 -I "$XFPOOL_PY" > "$HOME/.rolepod/config.json"; }
setpool() { XF_BASE="$1"; _xf_write "$1"; }
setpool_over() { _xf_write "$1"; }
restorepool() { if [ -n "$XF_BASE" ]; then _xf_write "$XF_BASE"; else rm -f "$HOME/.rolepod/config.json"; fi; }
droppool() { XF_BASE=""; rm -f "$HOME/.rolepod/config.json"; }
