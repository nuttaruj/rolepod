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

# ── Core 10 only — no executable legacy shims ─────────────────────────
FS_SKILLS=$(find core/skills -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
TIER3_SKILLS=$( { grep -Rsl "^tier: 3" core/skills/*/SKILL.md 2>/dev/null || true; } | wc -l | tr -d ' ')
REDIRECT_FIELDS=$( { grep -Rsl "^redirect_to:" core/skills/*/SKILL.md 2>/dev/null || true; } | wc -l | tr -d ' ')
check "filesystem skill dirs = Core 10 only (actual: $FS_SKILLS)" "[ $FS_SKILLS -eq 10 ]"
check "no tier: 3 skill files remain (actual: $TIER3_SKILLS)" "[ $TIER3_SKILLS -eq 0 ]"
check "no redirect_to shim fields remain (actual: $REDIRECT_FIELDS)" "[ $REDIRECT_FIELDS -eq 0 ]"

# ── Skill catalog drift — filesystem must match rendered fragment ──────
# Catches the "render.sh skips utility skills" failure mode that bit us
# pre-PR-doc-catalog-drift (advisor-escalation, new-project-onboarding,
# reviewer-flow, session-hygiene, triage-deep all silently missing).
RENDERED_SKILLS=$(awk '/^\| `/{c++} END{print c+0}' core/fragments/skill-index.md)
check "skill catalog: filesystem=$FS_SKILLS rendered=$RENDERED_SKILLS (must match)" "[ $FS_SKILLS -eq $RENDERED_SKILLS ]"

# ── Stale doc count keywords — guard against drift in prose ────────────
# After every skill add/remove, the count appears in ~6 places (README,
# CHEATSHEET, docs/cli-support.md, docs/skill-inventory-audit.md, plugin
# manifest, AGENTS.md). The filesystem-vs-rendered check above only
# catches the catalog fragment. Block known-stale numbers from slipping
# back into prose.
# Patterns catch the count appearing in many shapes:
#   bare: "42 skills" "43 skills" "53 skills" "34 native"
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
STALE_WB='\b(42 bundled|42 skills|43 skills|53 skills|43-skill|53-skill|53 skill files|34 native|3 auto-trigger hooks|same 3 scripts|same 3 files|18 \+ 42|18 \+ 43|18 \+ 53|all 34 rolepod|all 43 rolepod|Total 4[23]|Total 53|three rolepod entries|3 codex hooks|3 gemini hooks|3 root hooks|9 root hook scripts|own 3 scripts|3 \*\.sh)\b'
STALE_NONWORD='Skills \(4[23]\)|Skills \(53\)|Total skills on disk: \*\*(4[23]|53)\*\*|Hooks \(3\)|, 3 hooks\)'
STALE_COMMENT='(^|[^0-9])(#|`) ?4[23]\b'
STALE_HOOK_TRUTH='Context hooks \(cross-CLI\)|Codex / Gemini fire the context hooks|full hook coverage|Before tool run.*CLI handles native compact|SessionStart \+ 2x PostToolUse|10 bash hooks that auto-register|portable across Claude and Codex'
STALE_PATTERNS="${STALE_WB}|${STALE_NONWORD}|${STALE_COMMENT}|${STALE_HOOK_TRUTH}"
STALE_HITS=$(grep -rEn "$STALE_PATTERNS" \
  --include='*.md' --include='*.json' --include='*.tmpl' \
  README.md CHEATSHEET.md docs/ .claude-plugin/ adapters/ 2>/dev/null \
  | grep -v 'build/rendered/' || true)
if [ -z "$STALE_HITS" ]; then
  echo "  ✓ no stale doc count keywords (42/43/53-skill, 34 native, 3 hooks, etc.)"
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

# Tier 0 router must point at canonical Core 10 skills, not legacy names.
# This catches the subtle failure mode where the
# visible surface is lean but the first-loaded router still sends Lead
# through legacy skill names.
ROUTER="core/skills/using-rolepod/SKILL.md"
for s in "${CORE_SKILLS[@]}"; do
  if grep -q "\`$s\`" "$ROUTER"; then
    echo "  ✓ using-rolepod router references canonical core skill: $s"
  else
    echo "  ✗ using-rolepod router missing canonical core skill: $s"; fail=$((fail+1))
  fi
done
LEGACY_ROUTER_RX='(spec-driven-development|planning-and-task-breakdown|systematic-debugging|team-routing|parallel-contract-orchestration|subagent-task-execution|post-change-verify|code-review-and-quality|pre-merge-gate|finishing-a-development-branch|code-simplification|frontend-ui-engineering|api-and-interface-design|security-and-hardening|documentation-and-adrs|test-driven-development|reviewer-flow|webapp-testing)'
if grep -En "$LEGACY_ROUTER_RX" "$ROUTER" >/tmp/rolepod-router-legacy-hits.txt 2>/dev/null; then
  echo "  ✗ using-rolepod active router still references legacy shim names:"
  sed 's/^/      /' /tmp/rolepod-router-legacy-hits.txt
  fail=$((fail+1))
else
  echo "  ✓ using-rolepod router uses Core 10 names only"
fi
rm -f /tmp/rolepod-router-legacy-hits.txt

# Active docs and generated lean fragments must name Core 10 routing.
# Legacy names are allowed in docs/skills.md and audit docs, but not in
# the install/readme surfaces that teach users what to invoke.
ACTIVE_DOCS=(README.md CHEATSHEET.md CLAUDE.md AGENTS.md GEMINI.md adapters/claude/CLAUDE.md.tmpl adapters/codex/AGENTS.md.tmpl adapters/gemini/GEMINI.md.tmpl build/rendered/claude/CLAUDE.md build/rendered/codex/AGENTS.md build/rendered/gemini/GEMINI.md docs/agents.md docs/cli-support.md core/fragments/team-trigger.md core/fragments/agent-roster-lean.md core/fragments/model-tier-policy.md)
ACTIVE_LEGACY_RX='(team-routing|parallel-contract-orchestration|pre-merge-gate|post-change-verify|code-review-and-quality|spec-driven-development|planning-and-task-breakdown|systematic-debugging|finishing-a-development-branch|reviewer-flow)'
ACTIVE_LEGACY_HITS=""
for f in "${ACTIVE_DOCS[@]}"; do
  [ -f "$f" ] || continue
  hits=$(grep -En "$ACTIVE_LEGACY_RX" "$f" 2>/dev/null || true)
  [ -z "$hits" ] || ACTIVE_LEGACY_HITS="${ACTIVE_LEGACY_HITS}${hits}
"
done
if [ -z "$ACTIVE_LEGACY_HITS" ]; then
  echo "  ✓ active docs route through Core 10 names only"
else
  echo "  ✗ active docs still route through legacy shim names:"
  printf '%s' "$ACTIVE_LEGACY_HITS" | sed 's/^/      /'
  fail=$((fail+1))
fi

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

# Deleted legacy skill dirs must not creep back in. The migration map lives in
# docs/legacy-skill-map.md; executable routing must stay Core 10 only.
LEGACY_SKILLS=(
  advisor-escalation anti-spaghetti api-and-interface-design browser-testing-with-devtools
  ci-cd-and-automation claude-api code-review-and-quality code-simplification
  context-engineering conversion-copywriting debugging-and-error-recovery doc-coauthoring
  documentation-and-adrs doubt-driven-development finishing-a-development-branch
  frontend-ui-engineering interaction-design interface-design internal-comms
  new-project-onboarding parallel-contract-orchestration performance-optimization
  planning-and-task-breakdown post-change-verify pre-merge-gate reviewer-flow
  root-cause-tracing security-and-hardening seo session-hygiene shipping-and-launch
  source-driven-development spec-driven-development subagent-task-execution
  systematic-debugging team-routing test-driven-development triage-deep
  user-facing-content using-worktrees web-design-guidelines webapp-testing zoom-out
)
LEGACY_FOUND=""
for s in "${LEGACY_SKILLS[@]}"; do
  [ ! -d "core/skills/$s" ] || LEGACY_FOUND="${LEGACY_FOUND}${s}\n"
done
if [ -z "$LEGACY_FOUND" ]; then
  echo "  ✓ deleted legacy skill directories stay absent"
else
  echo "  ✗ deleted legacy skill directories reappeared:"
  printf "%b" "$LEGACY_FOUND" | sed 's/^/      /'
  fail=$((fail+1))
fi

# `redirect_to_agent` field must NOT appear anywhere (spec verdict #2).
if grep -lr "^redirect_to_agent:" core/skills/ 2>/dev/null | grep -q .; then
  echo "  ✗ forbidden `redirect_to_agent` field appears in source:"
  grep -lr "^redirect_to_agent:" core/skills/ | sed 's/^/      /'
  fail=$((fail+1))
else
  echo "  ✓ no redirect_to_agent field in source"
fi

# Core skills that name a next skill in their "Next phase" section must
# also include either an unavailable-next-skill fallback OR a terminal
# handoff (return to using-rolepod / surface to user / route back to a
# Core 10 skill family). Spec line 813 — keeps the phase skill usable
# when copied alone without the next phase skill.
NEXT_FALLBACK_RX='If .*(is not available|are not available)|If neither|If not[, ]|otherwise|outline below|return to (using-rolepod|the phase|`)|surface (the blocker|to the user)|ask the user'
NEXT_FAIL=0
for s in "${CORE_SKILLS[@]}"; do
  f="core/skills/$s/SKILL.md"
  [ -f "$f" ] || continue
  if grep -q "^## Next phase" "$f"; then
    if awk '/^## Next phase/{f=1;next} /^## /{if(f){exit}} f' "$f" | grep -Eq "$NEXT_FALLBACK_RX"; then
      :  # fallback / terminal handoff present
    else
      echo "  ✗ core skill names a next phase without a fallback or terminal handoff: $s"
      fail=$((fail+1))
      NEXT_FAIL=$((NEXT_FAIL+1))
    fi
  fi
done
[ "$NEXT_FAIL" -eq 0 ] && echo "  ✓ every core skill with a next-phase pointer has a fallback or terminal handoff"

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

# ── Agent standalone invariants (PR 2) ────────────────────────────────
# Every agent file must:
#   (a) preload only Core 10 skills (no legacy names in `skills:` frontmatter)
#   (b) carry a standalone output contract (either ## Output contract or ## Final authority)
#   (c) carry a labeled "## When to use" + "## Hand-off" + "## Escalation back to Core 10" section
CORE_10_SKILLS=(using-rolepod write-spec write-plan implement-plan debug-issue check-work review-code finish-work simplify-code manage-context)
AGENT_LEGACY_PRELOADS=""
AGENT_MISSING_OUTPUT=""
AGENT_MISSING_SECTIONS=""
for a in core/agents/*.md; do
  name=$(basename "$a" .md)
  # (a) skills: preload must be subset of Core 10
  preloads=$(awk '/^skills:/{f=1;next} /^[a-z]/{f=0} f && /^  - /{sub(/^  - /, ""); print}' "$a")
  for skill in $preloads; do
    is_core_10=0
    for c in "${CORE_10_SKILLS[@]}"; do
      [ "$skill" = "$c" ] && { is_core_10=1; break; }
    done
    if [ $is_core_10 -eq 0 ]; then
      AGENT_LEGACY_PRELOADS="${AGENT_LEGACY_PRELOADS}${name}: ${skill}\n"
    fi
  done
  # (b) output contract
  if ! grep -Eq "^## (Output contract|Final authority)" "$a"; then
    AGENT_MISSING_OUTPUT="${AGENT_MISSING_OUTPUT}${name}\n"
  fi
  # (c) labeled sections
  for sec in "## When to use" "## Hand-off" "## Escalation back to Core 10"; do
    if ! grep -Fq "$sec" "$a"; then
      AGENT_MISSING_SECTIONS="${AGENT_MISSING_SECTIONS}${name}: ${sec}\n"
    fi
  done
done
if [ -z "$AGENT_LEGACY_PRELOADS" ]; then
  echo "  ✓ all agents preload only Core 10 skills"
else
  echo "  ✗ agents preload legacy shim skills:"
  printf "%b" "$AGENT_LEGACY_PRELOADS" | sed 's/^/      /'
  fail=$((fail+1))
fi

# Claude adapter frontmatter is what rendered Claude agents actually use.
# Keep it in the same contract as core/agents; ui-ux-pro-max is the only
# optional external add-on preload allowed.
ADAPTER_BAD_PRELOADS=""
for a in adapters/claude/agent-frontmatter/*.yml; do
  name=$(basename "$a" .yml)
  preloads=$(awk '/^skills:/{f=1;next} /^[a-zA-Z]/{f=0} f && /^  - /{sub(/^  - /, ""); print}' "$a")
  for skill in $preloads; do
    allowed=0
    for c in "${CORE_10_SKILLS[@]}" ui-ux-pro-max; do
      [ "$skill" = "$c" ] && { allowed=1; break; }
    done
    if [ $allowed -eq 0 ]; then
      ADAPTER_BAD_PRELOADS="${ADAPTER_BAD_PRELOADS}${name}: ${skill}\n"
    fi
  done
done
if [ -z "$ADAPTER_BAD_PRELOADS" ]; then
  echo "  ✓ Claude adapter frontmatter preloads only Core 10 (+ ui-ux-pro-max)"
else
  echo "  ✗ Claude adapter frontmatter preloads deleted legacy skills:"
  printf "%b" "$ADAPTER_BAD_PRELOADS" | sed 's/^/      /'
  fail=$((fail+1))
fi
if [ -z "$AGENT_MISSING_OUTPUT" ]; then
  echo "  ✓ all agents have a standalone output contract"
else
  echo "  ✗ agents missing output contract (## Output contract or ## Final authority):"
  printf "%b" "$AGENT_MISSING_OUTPUT" | sed 's/^/      /'
  fail=$((fail+1))
fi
if [ -z "$AGENT_MISSING_SECTIONS" ]; then
  echo "  ✓ every agent has When-to-use + Hand-off + Escalation sections"
else
  echo "  ✗ agents missing required sections:"
  printf "%b" "$AGENT_MISSING_SECTIONS" | sed 's/^/      /'
  fail=$((fail+1))
fi

# ── Root vs Codex adapter hook parity ─────────────────────────────────
# Canonical = root `hooks/*.sh`. Codex adapter mirrors a subset (events
# Codex supports: SessionStart, PreToolUse Bash / apply_patch, PostToolUse
# Bash / apply_patch). Drift means a fix landed in root but Codex still
# runs the old script — caught the gate-reminder drift in PR 5.
SHARED_HOOKS=(gate-reminder.sh post-ship-detect.sh precommit-gate.sh project-context-loader.sh verify-reminder.sh)
HOOK_DRIFT=""
for h in "${SHARED_HOOKS[@]}"; do
  root="hooks/$h"
  codex="adapters/codex/plugins/rolepod/hooks/$h"
  if [ ! -f "$root" ] || [ ! -f "$codex" ]; then
    HOOK_DRIFT="${HOOK_DRIFT}${h}: missing on one side\n"
    continue
  fi
  if ! diff -q "$root" "$codex" >/dev/null 2>&1; then
    HOOK_DRIFT="${HOOK_DRIFT}${h}: root vs Codex adapter diverged\n"
  fi
done
if [ -z "$HOOK_DRIFT" ]; then
  echo "  ✓ root vs Codex adapter hook parity (5 shared hooks identical)"
else
  echo "  ✗ root vs Codex adapter hook drift:"
  printf "%b" "$HOOK_DRIFT" | sed 's/^/      /'
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
