#!/bin/bash
# parent-active-marker — combined mode is cross-CLI (v2.14.1): every CLI's
# session-start surface writes <git-root>/.rolepod/parent-active so child
# plugins (uiproof / wplab / dblab) pick with-rolepod mode. Locks the write
# in every adapter + proves the root loader's write functionally.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1"; fail=1
  fi
}

# Static: every session surface carries the marker write.
check "claude lifecycle writes marker"  "grep -q 'parent-active' hooks/session-lifecycle.sh"
check "root loader writes marker (codex parity)" "grep -q 'parent-active' hooks/project-context-loader.sh"
check "codex mirror carries it byte-exact" "cmp -s hooks/project-context-loader.sh adapters/codex/plugins/rolepod/hooks/project-context-loader.sh"
check "gemini session-start writes marker" "grep -q 'parent-active' adapters/gemini/hooks/session-start.sh"
check "cursor loader writes marker"     "grep -q 'parent-active' adapters/cursor/scripts/project-context-loader.sh"
check "opencode plugin writes marker"   "grep -q 'parent-active' adapters/opencode/plugin/rolepod.js"
check "protocol doc lists all six CLIs" "grep -q '| opencode | ✓' docs/EXTENSION-PROTOCOL.md"

# Functional: root loader creates the marker in a fresh repo (non-Claude path).
FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-marker.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
git -C "$FIX" init -q
git -C "$FIX" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
( cd "$FIX" && unset CLAUDE_PROJECT_DIR && printf '{}' \
  | HOME="$FIX/home" ROLEPOD_ALLOW_SHARED_WORKTREE=1 \
    bash "$REPO_DIR/hooks/project-context-loader.sh" >/dev/null 2>&1 ) || true
check "loader creates .rolepod/parent-active" "[ -f '$FIX/.rolepod/parent-active' ]"
check "marker carries protocol version v1"    "grep -qx 'v1' '$FIX/.rolepod/parent-active'"

exit $fail
