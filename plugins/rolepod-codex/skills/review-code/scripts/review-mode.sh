#!/bin/bash
# review-mode — print the review mode, `standard` or `full`.
#
# Usage: scripts/review-mode.sh [--source]
#   stdout: one word. `--source` prints `<mode> (project|global|default)`.
#
# Layers, first one with a `review.mode` key decides:
#   1. <git root of cwd, or cwd when not a git repo>/.rolepod/config.json
#   2. $HOME/.rolepod/config.json
#   3. default `standard`
# A deciding layer whose file is unreadable (broken JSON) or whose value is
# not standard|full counts as `standard` with one warning line on stderr.
# Keys outside `review` and `version` are never read. Always exits 0.

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# read_layer <file> -> prints "absent" | "standard" | "full" | "bad"
read_layer() {
  [ -f "$1" ] || { echo absent; return; }
  python3 -I -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
except Exception:
    print("bad"); sys.exit(0)
r = d.get("review") if isinstance(d, dict) else None
if not isinstance(r, dict) or "mode" not in r:
    print("absent")
elif r["mode"] in ("standard", "full"):
    print(r["mode"])
else:
    print("bad")
' "$1" 2>/dev/null || echo bad
}

mode=standard; src=default
for layer in "project:$root/.rolepod/config.json" "global:$HOME/.rolepod/config.json"; do
  name=${layer%%:*}; file=${layer#*:}
  v=$(read_layer "$file")
  [ "$v" = absent ] && continue
  if [ "$v" = bad ]; then
    echo "review-mode: $file is unreadable or review.mode is not standard|full; using standard" >&2
    v=standard
  fi
  mode=$v; src=$name
  break
done

if [ "${1:-}" = "--source" ]; then
  echo "$mode ($src)"
else
  echo "$mode"
fi
