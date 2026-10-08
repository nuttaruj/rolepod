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
if [ "$SRC" -ne 4 ] || [ "$RND" -ne 4 ]; then
  echo "  ✗ expected exactly 4 type files per carrier, found source=$SRC rendered=$RND"
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

# No role carries `memory:` (owner decision 2026-10-05): a sub-agent starts from a
# fresh context and the Lead keeps project memory; `memory:` also injected ~13k
# chars of boilerplate into every dispatch. Source and rendered copy, like maxTurns.
MEM=$(/usr/bin/grep -l '^memory:' adapters/claude/agent-frontmatter/*.yml plugins/rolepod/agents/*.md 2>/dev/null | tr '\n' ' ')
if [ -z "$MEM" ]; then echo "  ✓ no role carries memory:"; else echo "  ✗ memory: on $MEM"; fail=$((fail+1)); fi

# 4-type roster: reviewer and qa list Write on Claude and render WRITABLE on Cursor
# and opencode (no write-scope hook there, spec s2b); scout is read-only everywhere.
for t in rolepod-reviewer rolepod-qa; do
  if /usr/bin/grep -qx '  - Write' plugins/rolepod/agents/$t.md \
    && ! /usr/bin/grep -qx 'readonly: true' plugins/rolepod-cursor/agents/$t.md \
    && ! /usr/bin/grep -qx '  write: deny' build/rendered/opencode/agents/$t.md; then
    echo "  ✓ $t: Write on Claude, writable on Cursor and opencode"
  else
    echo "  ✗ $t: Write missing on Claude, or rendered read-only on Cursor/opencode"
    fail=$((fail+1))
  fi
done
if ! /usr/bin/grep -qx '  - Write' plugins/rolepod/agents/rolepod-scout.md \
  && /usr/bin/grep -qx 'readonly: true' plugins/rolepod-cursor/agents/rolepod-scout.md \
  && /usr/bin/grep -qx '  write: deny' build/rendered/opencode/agents/rolepod-scout.md; then
  echo "  ✓ rolepod-scout: no Write on Claude, read-only on Cursor and opencode"
else
  echo "  ✗ rolepod-scout: Write granted on Claude, or not read-only on Cursor/opencode"
  fail=$((fail+1))
fi

[ "$fail" -eq 0 ] || exit 1
