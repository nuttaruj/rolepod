#!/bin/bash
# spec-lint — proves the write-spec placeholder lint actually works.
# Backs the SKILL.md "Full Rolepod enhancement" claim that a saved spec is
# checked for placeholder leaks before Gate 2 / handoff. The lint is the
# deterministic backstop to write-spec's prose self-review: it catches
# leftover template hints (<...>) and TODO/TBD markers a model might miss.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

# The deterministic placeholder lint. MUST stay in sync with the regex
# documented in core/skills/write-spec/SKILL.md (steps 6 + 7).
LINT_RX='<[^>]+>|TODO|TBD'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1. The shipped template is full of <...> hints — the lint must flag it
#    (proves the lint detects the canonical unfilled state).
check "lint flags the unfilled template (<...> hints present)" \
  "grep -niE \"\$LINT_RX\" core/skills/write-spec/templates/spec-template.md >/dev/null"

# 2. A spec that left a template hint in a success criterion — must catch.
cat > "$TMP/dirty.md" <<'EOF'
# Foo Export Spec
## Goal
Let a user download the filtered list as a CSV file.
## Success criteria
- <criterion 1>
## High-risk surfaces
None — read-only export.
## Open questions
None.
EOF
check "lint catches a planted placeholder (<criterion 1>)" \
  "grep -niE \"\$LINT_RX\" \"$TMP/dirty.md\" >/dev/null"

# 3. A spec with a stray TODO — must catch.
cat > "$TMP/todo.md" <<'EOF'
# Foo Export Spec
## Goal
Let a user download the filtered list as a CSV file.
## Constraints
TODO: confirm the timeout budget.
EOF
check "lint catches a stray TODO marker" \
  "grep -niE \"\$LINT_RX\" \"$TMP/todo.md\" >/dev/null"

# 4. A clean filled spec — the lint must PASS (no match).
cat > "$TMP/clean.md" <<'EOF'
# Foo Export Spec
## Goal
Let a user download the currently filtered orders list as a CSV file.
## Success criteria
- The CSV row set equals the filtered table row set.
- A filter range with zero orders downloads a header-only CSV.
## High-risk surfaces
None — read-only export of data already visible on screen.
## Open questions
None.
EOF
check "lint passes a clean filled spec (no false positive)" \
  "! grep -niE \"\$LINT_RX\" \"$TMP/clean.md\" >/dev/null"

# 5. SKILL.md must document the lint so author + this test stay in sync.
check "write-spec SKILL.md documents the spec-lint" \
  "grep -qi 'spec-lint' core/skills/write-spec/SKILL.md"
check "write-spec SKILL.md ships the lint regex" \
  "grep -qF '<[^>]+>|TODO|TBD' core/skills/write-spec/SKILL.md"

if [ $fail -eq 0 ]; then echo "spec-lint: pass"; exit 0; fi
echo "spec-lint: $fail failure(s)"
exit 1
