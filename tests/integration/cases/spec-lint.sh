#!/bin/bash
# spec-lint — proves the write-spec placeholder lint actually works.
# Backs write-spec §6-§7: a saved spec is checked for placeholder leaks
# before Gate 2 / handoff. The lint is the
# deterministic backstop to write-spec's prose self-review: it catches an
# unfilled [[FILL: ...]] marker and TODO/TBD markers a model might miss — and
# must NOT false-positive on ordinary angle brackets (<h1>, List<T>).
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

# The deterministic placeholder lint. MUST stay in sync with the regex
# documented in core/skills/write-spec/SKILL.md (steps 6 + 7).
LINT_RX='\[\[FILL:|TODO|TBD'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1. The shipped template is full of [[FILL: ...]] markers — the lint must
#    flag it (proves the lint detects the canonical unfilled state).
check "lint flags the unfilled template ([[FILL: ...]] markers present)" \
  "grep -niE \"\$LINT_RX\" core/skills/write-spec/templates/spec-template.md >/dev/null"

# 2. A spec that left a template hint in a success criterion — must catch.
cat > "$TMP/dirty.md" <<'EOF'
# Foo Export Spec
## Goal
Let a user download the filtered list as a CSV file.
## Success criteria
- [[FILL: criterion 1]]
## High-risk surfaces
None — read-only export.
## Open questions
None.
EOF
check "lint catches a planted placeholder ([[FILL: criterion 1]])" \
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

# 4a. Anchor headings (v2.91.0). A repeat-feature spec seeds Current
#     behavior from the prior spec's `## Desired behavior` and carries
#     Non-goals forward by reference — a numbered or renamed heading cannot
#     be found, so the seed silently falls back to a blank slate (real case:
#     a saved spec with `## 1. Goal … ## 8. Open items`, zero anchors).
#     The loop below is the one documented in SKILL.md step 7.
anchor_missing() { # $1 = spec → prints "missing ## X" per absent anchor
  for h in 'Non-goals' 'Current behavior' 'Desired behavior' 'Success criteria'; do
    grep -q "^## $h" "$1" || echo "missing ## $h"
  done
}
check "template carries the four anchor headings" \
  "[ -z \"\$(anchor_missing core/skills/write-spec/templates/spec-template.md)\" ]"
python3 - "$TMP" <<'PYX' > "$TMP/goods.txt"
import re, sys
tmp = sys.argv[1]
s = open('core/skills/write-spec/examples/spec-examples.md').read()
for i, b in enumerate(re.findall(r'### Good\s*\n```text\n(.*?)\n```', s, re.S), 1):
    open('%s/good%d.md' % (tmp, i), 'w').write(b); print(i)
PYX
for i in $(cat "$TMP/goods.txt"); do
  check "Good example $i carries the four anchor headings" "[ -z \"\$(anchor_missing \"$TMP/good$i.md\")\" ]"
done
cat > "$TMP/numbered.md" <<'EOF'
# Cart Spec
## 1. Goal
One checkout for several items.
## 2. Non-goals (v1)
No saved carts.
## 5. Chosen design
Server-side holds.
## 6. Success criteria
- Both items confirm — proven by: e2e.
EOF
check "anchor check flags a numbered-heading spec (every anchor missing)" \
  "[ \"\$(anchor_missing \"$TMP/numbered.md\" | wc -l | tr -d ' ')\" -eq 4 ]"
check "SKILL.md step 7 documents the anchor loop" \
  "grep -q 'missing ## ' core/skills/write-spec/SKILL.md"
check "SKILL.md §6 lets a repeat-feature spec inherit unchanged sections by reference" \
  "grep -q 'Unchanged — <prior spec>' core/skills/write-spec/SKILL.md"

# 4b. Legitimate angle brackets are NOT placeholders — HTML tags, generic
#     types, a bare URL. The old '<[^>]+>' regex flagged all three (v2.81.0).
cat > "$TMP/brackets.md" <<'EOF'
# Report Header Spec
## Goal
Render the page title inside an <h1>Title</h1> element.
## Success criteria
- The API returns List<Order> sorted by created_at — proven by: curl https://api.example.test/orders?sort=created_at
## High-risk surfaces
None.
## Open questions
None.
EOF
check "lint does not false-positive on <h1>, List<T>, or a URL" \
  "! grep -niE \"\$LINT_RX\" \"$TMP/brackets.md\" >/dev/null"

# 5. SKILL.md must document the lint so author + this test stay in sync.
check "write-spec SKILL.md documents the spec-lint" \
  "grep -qi 'spec-lint' core/skills/write-spec/SKILL.md"
check "write-spec SKILL.md ships the lint regex" \
  "grep -qF '\[\[FILL:|TODO|TBD' core/skills/write-spec/SKILL.md"

if [ $fail -eq 0 ]; then echo "spec-lint: pass"; exit 0; fi
echo "spec-lint: $fail failure(s)"
exit 1
