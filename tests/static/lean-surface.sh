#!/bin/bash
# lean-surface — anti-drift static guards.
# Locks in the lean-spine invariants. Any future change that re-bloats
# entry docs, leaks specialist tables, or names a competitor breaks here
# and gets caught before commit.
#
# Wired into `make test-static`. Runs after `build/render.sh --target=all`
# so it sees the just-rendered output.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"

fail=0
check() {
  if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi
}

echo "── lean-surface ──"

# ── Rendered entry doc size caps ───────────────────────────────────────
CLAUDE_LINES=$(wc -l < build/rendered/claude/CLAUDE.md)
CODEX_LINES=$(wc -l < build/rendered/codex/AGENTS.md)
GEMINI_LINES=$(wc -l < build/rendered/gemini/GEMINI.md)
check "rendered Claude CLAUDE.md ≤ 150 lines (actual: $CLAUDE_LINES)"  "[ $CLAUDE_LINES -le 150 ]"
check "rendered Codex  AGENTS.md ≤ 280 lines (actual: $CODEX_LINES)"   "[ $CODEX_LINES  -le 280 ]"
check "rendered Gemini GEMINI.md ≤ 280 lines (actual: $GEMINI_LINES)"  "[ $GEMINI_LINES -le 280 ]"

# ── Tier 0 + Tier 1 visible skill count ───────────────────────────────
LEAN_TIER0=$(awk '/^### Tier 0/{f=1;next} /^### Tier/{f=0} f && /^\| `/{c++} END{print c+0}' core/fragments/skill-index-lean.md)
LEAN_TIER1=$(awk '/^### Tier 1/{f=1;next} /^### Tier/{f=0} f && /^\| `/{c++} END{print c+0}' core/fragments/skill-index-lean.md)
check "lean skill-index Tier 0 = 1 (actual: $LEAN_TIER0)"    "[ $LEAN_TIER0 -eq 1 ]"
check "lean skill-index Tier 1 = 11 (actual: $LEAN_TIER1)"   "[ $LEAN_TIER1 -eq 11 ]"

# ── 18-agent full table must NOT appear in rendered entry docs ────────
# Heuristic: a full agent table has the agent-roster header pattern.
# The lean fragment uses a single "**18 specialists**" line instead.
for f in build/rendered/claude/CLAUDE.md build/rendered/codex/AGENTS.md build/rendered/gemini/GEMINI.md; do
  rows=$(grep -c "^| \`[a-z-]*-engineer\`\|^| \`backend-developer\`\|^| \`frontend-developer\`" "$f" 2>/dev/null || true)
  check "no full agent table leaked into $(basename $(dirname $f))/$(basename $f) (rows: $rows)" "[ $rows -le 1 ]"
done

# ── Model tier coverage — all 18 agents must have a model: line ───────
COVERED=$(grep -l "^model: \(haiku\|sonnet\|opus\)" adapters/claude/agent-frontmatter/*.yml | wc -l | tr -d ' ')
TOTAL=$(ls adapters/claude/agent-frontmatter/*.yml | wc -l | tr -d ' ')
check "model tier covers all $TOTAL agents (actual: $COVERED/$TOTAL)" "[ $COVERED -eq $TOTAL ]"

# ── Competitor brand scrub ─────────────────────────────────────────────
# Allowed: nothing. system files, entry docs, rendered output all clean.
BRAND_LEAKS=$(grep -rl -i "superpower" --include="*.md" --include="*.tmpl" --include="*.yml" . 2>/dev/null | grep -v "^./build/rendered/" | grep -v "^./.git/" || true)
if [ -z "$BRAND_LEAKS" ]; then
  echo "  ✓ no competitor brand refs in source"
else
  echo "  ✗ competitor brand leaked in:"
  echo "$BRAND_LEAKS" | sed 's/^/      /'
  fail=$((fail+1))
fi

# ── Render reproducibility under LC_ALL=C ─────────────────────────────
cp core/fragments/skill-index.md /tmp/.lean-surface-snap.md
LC_ALL=C bash build/render.sh --target=all >/dev/null 2>&1
if diff -q /tmp/.lean-surface-snap.md core/fragments/skill-index.md >/dev/null 2>&1; then
  echo "  ✓ skill-index.md render stable under LC_ALL=C"
else
  echo "  ✗ skill-index.md drifts under LC_ALL=C (locale-dependent generator)"
  fail=$((fail+1))
fi
rm -f /tmp/.lean-surface-snap.md

echo ""
if [ $fail -eq 0 ]; then
  echo "lean-surface: pass"
  exit 0
fi
echo "lean-surface: $fail failure(s)"
exit 1
