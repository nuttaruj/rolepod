#!/bin/bash
# agent-turn-cap — no rolepod role carries a `maxTurns` cap, and an empty
# reviewer return is doctrine-named as a failed reviewer (v2.119.0).
#
# Measured 2026-09-11, 14 days, every project on one machine (105 reviewer
# dispatches): 12 stopped at exactly the cap with no report — the read was
# paid for, the write thrown away, then a resume paid again — while no
# uncapped run was ever observed past 71 turns. A cap defends against a
# runaway nobody has measured and causes a loss measured at 11%. The harness
# has no default cap (a subagent runs to its natural end and auto-compacts),
# and a Workflow lens that hits a cap returns "" with no error, which the
# Lead first read as "no findings". The brief states the budget; the role
# file states none. Scout included: a wide sweep is allowed to be long.
#
# Both carriers are checked — the source frontmatter and the rendered plugin
# copy — so a stale render cannot ship a cap either.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
fail=0
echo "agent-turn-cap:"

# The render step is an allowlist (build/merge-agent.py CLAUDE_KEY_ORDER), so a
# re-added key would vanish from the rendered copy — the source grep is the
# catch; the rendered grep guards a hand-edited plugin file. Count the
# carriers first so a broken glob cannot read as a pass.
SRC=$(ls adapters/claude/agent-frontmatter/*.yml 2>/dev/null | wc -l | tr -d ' ')
RND=$(ls plugins/rolepod/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$SRC" -lt 15 ] || [ "$RND" -lt 15 ]; then
  echo "  ✗ expected ≥ 15 role files per carrier, found source=$SRC rendered=$RND"
  fail=$((fail+1))
fi
HITS=$(grep -ln '^maxTurns:' adapters/claude/agent-frontmatter/*.yml plugins/rolepod/agents/*.md 2>/dev/null || true)
if [ -z "$HITS" ]; then
  echo "  ✓ no role carries maxTurns (source frontmatter + rendered plugin)"
else
  echo "  ✗ maxTurns present — the brief carries the budget, the role file carries none:"
  printf '%s\n' "$HITS" | sed 's/^/      /'
  fail=$((fail+1))
fi

RULE='An empty or partial return is a failed reviewer, never a clean pass'
for f in core/skills/review-code/SKILL.md \
         plugins/rolepod/skills/review-code/SKILL.md \
         plugins/rolepod-codex/skills/review-code/SKILL.md \
         plugins/rolepod-cursor/skills/review-code/SKILL.md; do
  if grep -q "$RULE" "$f"; then
    echo "  ✓ $f names an empty reviewer return a failed reviewer"
  else
    echo "  ✗ $f lost the empty-return rule (a \"\" lens or a one-line partial must not read as a pass)"
    fail=$((fail+1))
  fi
done

[ "$fail" -eq 0 ] || exit 1
