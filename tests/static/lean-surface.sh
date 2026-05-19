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
# Core 10 target: Tier 0 = 1 router (using-rolepod), Tier 1 = 9 core
# workflow skills (write-spec / write-plan / implement-plan / debug-issue
# / check-work / review-code / finish-work / simplify-code / manage-context).
# Default Lead surface = Tier 0 + Tier 1 = 10 skills.
LEAN_TIER0=$(awk '/^### Tier 0/{f=1;next} /^### Tier/{f=0} f && /^\| `/{c++} END{print c+0}' core/fragments/skill-index-lean.md)
LEAN_TIER1=$(awk '/^### Tier 1/{f=1;next} /^### Tier/{f=0} f && /^\| `/{c++} END{print c+0}' core/fragments/skill-index-lean.md)
check "lean skill-index Tier 0 = 1 (actual: $LEAN_TIER0)"    "[ $LEAN_TIER0 -eq 1 ]"
check "lean skill-index Tier 1 = 9 (actual: $LEAN_TIER1)"    "[ $LEAN_TIER1 -eq 9 ]"
LEAN_SURFACE=$((LEAN_TIER0 + LEAN_TIER1))
check "default Lead surface ≤ 10 (actual: $LEAN_SURFACE)"    "[ $LEAN_SURFACE -le 10 ]"

# ── Public non-shim skills ≤ 11 (Core 10 + optional check-security) ────
# Public non-shim = filesystem skills without `tier: 3` frontmatter.
PUBLIC_NONSHIM=$(grep -L "^tier: 3" core/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
check "public non-shim skills ≤ 11 (actual: $PUBLIC_NONSHIM)" "[ $PUBLIC_NONSHIM -le 11 ]"

# ── Skill catalog drift — filesystem must match rendered fragment ──────
# Catches the "render.sh skips utility skills" failure mode that bit us
# pre-PR-doc-catalog-drift (advisor-escalation, new-project-onboarding,
# reviewer-flow, session-hygiene, triage-deep all silently missing).
FS_SKILLS=$(find core/skills -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
RENDERED_SKILLS=$(awk '/^\| `/{c++} END{print c+0}' core/fragments/skill-index.md)
check "skill catalog: filesystem=$FS_SKILLS rendered=$RENDERED_SKILLS (must match)" "[ $FS_SKILLS -eq $RENDERED_SKILLS ]"

# ── Stale doc count keywords — guard against drift in prose ────────────
# After every skill add/remove, the count appears in ~6 places (README,
# CHEATSHEET, docs/cli-support.md, docs/skill-inventory-audit.md, plugin
# manifest, AGENTS.md). The filesystem-vs-rendered check above only
# catches the catalog fragment. Block known-stale numbers from slipping
# back into prose.
# Patterns catch the count appearing in many shapes:
#   bare: "42 skills" "43 skills" "34 native"
#   parenthesized: "Skills (42)"
#   sum form: "18 + 42"
#   bold form: "**43**" "**42**" when right after "skills" or "Total"
#   compound: "all 34 rolepod skills" / "Total skills on disk: **43**"
#   comment form: trailing "# 34" / "# 42" (cli verify commands)
#   hook drift: "3 hooks" / "3 auto-trigger hooks" / "3 scripts"
#   hook-truth drift: broad cross-CLI claims that hide per-CLI coverage
# Two groups: word-boundary patterns + non-word-end patterns. The second
# group covers forms ending in `)` or `*` where trailing `\b` is dead
# (qa-tester PR #10 caught this).
STALE_WB='\b(42 bundled|42 skills|43 skills|43-skill|34 native|3 auto-trigger hooks|same 3 scripts|same 3 files|18 \+ 42|18 \+ 43|all 34 rolepod|all 43 rolepod|Total 4[23]|three rolepod entries|3 codex hooks|3 gemini hooks|3 root hooks|9 root hook scripts|own 3 scripts|3 \*\.sh)\b'
STALE_NONWORD='Skills \(4[23]\)|Total skills on disk: \*\*4[23]\*\*|Hooks \(3\)|, 3 hooks\)'
STALE_COMMENT='(^|[^0-9])(#|`) ?4[23]\b'
STALE_HOOK_TRUTH='Context hooks \(cross-CLI\)|Codex / Gemini fire the context hooks|full hook coverage|Before tool run.*CLI handles native compact|SessionStart \+ 2x PostToolUse|10 bash hooks that auto-register|portable across Claude and Codex'
STALE_PATTERNS="${STALE_WB}|${STALE_NONWORD}|${STALE_COMMENT}|${STALE_HOOK_TRUTH}"
STALE_HITS=$(grep -rEn "$STALE_PATTERNS" \
  --include='*.md' --include='*.json' --include='*.tmpl' \
  README.md CHEATSHEET.md docs/ .claude-plugin/ adapters/ 2>/dev/null \
  | grep -v 'build/rendered/' || true)
if [ -z "$STALE_HITS" ]; then
  echo "  ✓ no stale doc count keywords (42/43-skill, 34 native, 3 hooks, etc.)"
else
  echo "  ✗ stale doc count keywords found:"
  printf '%s\n' "$STALE_HITS" | sed 's/^/      /'
  fail=$((fail+1))
fi

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

# ── Core 10 portability invariants ────────────────────────────────────
# Each of the 9 core workflow skills must include both an agent-available
# path and a no-agent fallback path so a copy-only install still works.
# These checks back the spec's Acceptance Criteria #6-#10 + Risks #11.
CORE_SKILLS=(write-spec write-plan implement-plan debug-issue check-work review-code finish-work simplify-code manage-context)
FALLBACK_RX='(If no matching agent is available|If \`[a-z-]+\` is not available|no-agent fallback|standalone fallback|Execute (as Lead|the checklist directly as Lead))'
for s in "${CORE_SKILLS[@]}"; do
  f="core/skills/$s/SKILL.md"
  if [ ! -f "$f" ]; then
    echo "  ✗ core skill missing on disk: $s"; fail=$((fail+1)); continue
  fi
  if grep -Eq "$FALLBACK_RX" "$f"; then
    echo "  ✓ core skill has no-agent fallback section: $s"
  else
    echo "  ✗ core skill missing no-agent fallback section: $s"; fail=$((fail+1))
  fi
done

# Core skills must not contain hard-dependency language. Forbidden:
# "Always delegate to <agent>", "Requires <skill>", "Load <other> before"
# (with skill-name pattern), "must use agent".
HARD_DEP_RX='(Always delegate to|Requires Rolepod (agents|hooks)|must use (a |an |the )?agent|Only works inside full Rolepod)'
for s in "${CORE_SKILLS[@]}"; do
  f="core/skills/$s/SKILL.md"
  [ -f "$f" ] || continue
  if grep -Eq "$HARD_DEP_RX" "$f"; then
    echo "  ✗ core skill contains hard-dependency language: $s"
    grep -En "$HARD_DEP_RX" "$f" | sed 's/^/      /' || true
    fail=$((fail+1))
  fi
done
echo "  ✓ no core skill contains hard-dependency language"

# Every core skill must include the "Full Rolepod enhancement" note.
for s in "${CORE_SKILLS[@]}"; do
  f="core/skills/$s/SKILL.md"
  [ -f "$f" ] || continue
  if ! grep -q "^## Full Rolepod enhancement" "$f"; then
    echo "  ✗ core skill missing 'Full Rolepod enhancement' section: $s"; fail=$((fail+1))
  fi
done
echo "  ✓ every core skill has Full Rolepod enhancement note"

# write-spec must include an approval gate + self-review (Acceptance #7-#9).
if grep -Eiq "(approval|approve)" core/skills/write-spec/SKILL.md && \
   grep -Eiq "self.review" core/skills/write-spec/SKILL.md; then
  echo "  ✓ write-spec contains approval gate + self-review"
else
  echo "  ✗ write-spec missing approval gate or self-review"; fail=$((fail+1))
fi

# Every shim (tier 3) must include both `redirect_to` and a fallback
# section so a copy-only shim does not dead-end.
SHIM_FILES=$(grep -l "^tier: 3" core/skills/*/SKILL.md 2>/dev/null)
for f in $SHIM_FILES; do
  name=$(basename "$(dirname "$f")")
  if ! grep -q "^redirect_to: " "$f"; then
    echo "  ✗ shim missing redirect_to: $name"; fail=$((fail+1)); continue
  fi
  if ! grep -Eq "^## If \`[a-z-]+\` is not available" "$f"; then
    echo "  ✗ shim missing fallback section: $name"; fail=$((fail+1))
  fi
done
echo "  ✓ every shim has redirect_to + fallback section"

# Every redirect_to target must point at an existing public skill.
BAD_TARGETS=""
for f in $SHIM_FILES; do
  target=$(awk '/^redirect_to:/{gsub(/^redirect_to:[[:space:]]*/, ""); print; exit}' "$f")
  if [ -z "$target" ] || [ ! -f "core/skills/$target/SKILL.md" ]; then
    BAD_TARGETS="$BAD_TARGETS $(basename "$(dirname "$f")")→$target"
  fi
done
if [ -z "$BAD_TARGETS" ]; then
  echo "  ✓ every shim redirect_to points at an existing skill"
else
  echo "  ✗ shim redirect_to targets missing:$BAD_TARGETS"; fail=$((fail+1))
fi

# `redirect_to_agent` field must NOT appear anywhere (spec verdict #2).
if grep -lr "^redirect_to_agent:" core/skills/ 2>/dev/null | grep -q .; then
  echo "  ✗ forbidden `redirect_to_agent` field appears in source:"
  grep -lr "^redirect_to_agent:" core/skills/ | sed 's/^/      /'
  fail=$((fail+1))
else
  echo "  ✓ no redirect_to_agent field in source"
fi

# Core skill fallback sections must stay concise (line guard). A
# fallback that grows past ~25 lines is on its way to becoming a domain
# manual — push detail into agent / docs instead.
for s in "${CORE_SKILLS[@]}"; do
  f="core/skills/$s/SKILL.md"
  [ -f "$f" ] || continue
  fallback_lines=$(awk '/^## If no matching agent is available/{f=1;next} /^## /{if(f){exit}} f{c++} END{print c+0}' "$f")
  if [ "$fallback_lines" -gt 25 ]; then
    echo "  ✗ core skill fallback section > 25 lines ($fallback_lines): $s"; fail=$((fail+1))
  fi
done
echo "  ✓ core skill fallback sections concise (≤ 25 lines)"

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
