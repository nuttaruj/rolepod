#!/bin/bash
# skill-tree-parity — the repo-root skills/ is the one rendered skill tree; every
# bundle's skills path is a byte-identical copy. Run `make render` first.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

fail=0
check() { if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi; }

TREES="plugins/rolepod/skills plugins/rolepod-codex/skills plugins/rolepod-cursor/skills build/rendered/antigravity/plugin/skills build/rendered/opencode/skills"

check "skills/ is a real directory (not a link)" "[ -d skills ] && [ ! -L skills ]"
for t in $TREES; do
  check "$t matches skills/ byte for byte" "[ -d '$t' ] && diff -r skills '$t' >/dev/null"
done
check "skills/ carries both fanout-claude.md and fanout-codex.md" \
  "[ -f skills/using-rolepod/references/fanout-claude.md ] && [ -f skills/using-rolepod/references/fanout-codex.md ]"
check "skills/ has no unresolved {{INCLUDE: directive" "! grep -rqF '{{INCLUDE:' skills/"

[ "$fail" -eq 0 ] || { echo "  ✗ skill-tree-parity: $fail failed"; exit 1; }
echo "  ✓ skill-tree-parity: every bundle equals skills/"
