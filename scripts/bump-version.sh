#!/bin/bash
# rolepod version bump — one command instead of hand-editing 11 manifests.
#
# Seds the version field in the 7 SOURCE manifests, then re-renders so the
# 4 committed derived copies (plugins/rolepod/, plugins/rolepod-codex/,
# plugins/rolepod-cursor/, .cursor-plugin/marketplace.json) regenerate.
# Gemini + Antigravity track the release on a 0.x lockstep line
# (2.38.0 ↔ 0.38.0 — see docs/release-checklist.md §6).
#
# Usage: scripts/bump-version.sh 2.38.0   (or: make version-bump VERSION=2.38.0)
# Consistency across all 11 committed carriers is pinned by
# tests/static/lean-surface.sh — run `make test-static` after.
set -euo pipefail

V="${1:?usage: bump-version.sh <2.x.y>}"
case "$V" in
  2.*.*) ;;
  *) echo "expected a 2.x.y version, got: $V" >&2; exit 1 ;;
esac
V0="0.${V#2.}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

setver() {  # $1 = file, $2 = version — rewrite every "version" leaf field
  python3 - "$1" "$2" <<'PY'
import re, sys
path, ver = sys.argv[1], sys.argv[2]
text = open(path).read()
out = re.sub(r'("version"\s*:\s*")[0-9]+\.[0-9]+\.[0-9]+(")',
             lambda m: m.group(1) + ver + m.group(2), text)
if out == text:
    sys.exit(f"{path}: no version field rewritten")
open(path, "w").write(out)
PY
  echo "  ✓ $1 → $2"
}

setver adapters/claude/.claude-plugin/plugin.json            "$V"
setver adapters/codex/plugins/rolepod/.codex-plugin/plugin.json "$V"
setver adapters/cursor/.cursor-plugin/plugin.json            "$V"
setver adapters/cursor/.cursor-plugin/marketplace.json       "$V"
setver adapters/opencode/opencode.json                       "$V"
setver adapters/gemini/gemini-extension.json                 "$V0"
setver adapters/antigravity/plugin.json                      "$V0"

echo "  → re-rendering derived copies"
bash build/render.sh --target=all >/dev/null
echo "  ✓ bumped to $V (gemini/antigravity $V0) — verify: make test-static"
