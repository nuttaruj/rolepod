#!/bin/bash
# Regression test — the agent-type name sets stay in step with core/agents/.
# The types are the file stems of core/agents/*.md. Every other list that
# names them is read as TEXT (never imported or executed) and compared:
#   hooks/lib/session_state.py          TIER_PINNED_AGENTS == types
#   core/skills/rolepod-stats/scripts/stats.sh   TYPES == types, LEGACY_TYPE values in types
#   hooks/subagent-write-scope.sh       TEST_ONLY, READ_ONLY (+ session_state WRITER_ROLE_AGENTS)
#                                       pairwise disjoint, union == types
#   install.sh                          OLD_ROLE_NAMES shares no name with types
# TYPE_SETS_ROOT overrides the repo root so a mutation can run on a copy.
#
# Wired into `make test-static`.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ROOT="${TYPE_SETS_ROOT:-$REPO_DIR}"
fail=0

echo "── type-name-sets ──"

out=$(ROOT="$ROOT" python3 - <<'PYEOF'
import ast, os, pathlib, re

root = pathlib.Path(os.environ["ROOT"])

def read(rel):
    return (root / rel).read_text()

def literal(rel, name, opener, closer):
    """ast.literal_eval of the literal assigned to `name` (first match)."""
    text = read(rel)
    m = re.search(r"^%s\s*=\s*(?=\%s)" % (re.escape(name), opener), text, re.M)
    if not m:
        raise ValueError("%s: no assignment of %s" % (rel, name))
    start = m.end()
    depth = 0
    for i in range(start, len(text)):
        if text[i] == opener:
            depth += 1
        elif text[i] == closer:
            depth -= 1
            if depth == 0:
                return ast.literal_eval(text[start:i + 1])
    raise ValueError("%s: unterminated %s" % (rel, name))

def check(label, rel, fn):
    try:
        msg = fn()
    except Exception as e:  # unreadable list is a failure, never a crash
        msg = "cannot read: %s" % e
    if msg:
        print("FAIL  %s — %s: %s" % (rel, label, msg))
    else:
        print("OK    %s — %s" % (rel, label))

types = {p.stem for p in (root / "core/agents").glob("*.md")}
print("INFO  types = %s" % sorted(types))

def eqtypes(s):
    s = set(s)
    if s == types:
        return ""
    return "differs from core/agents (missing %s, extra %s)" % (sorted(types - s), sorted(s - types))

SS = "hooks/lib/session_state.py"
ST = "core/skills/rolepod-stats/scripts/stats.sh"
WS = "hooks/subagent-write-scope.sh"

check("TIER_PINNED_AGENTS == types", SS, lambda: eqtypes(literal(SS, "TIER_PINNED_AGENTS", "{", "}")))
check("TYPES == types", ST, lambda: eqtypes(literal(ST, "TYPES", "{", "}")))

def legacy():
    bad = sorted(set(literal(ST, "LEGACY_TYPE", "{", "}").values()) - types)
    return "LEGACY_TYPE values not in types: %s" % bad if bad else ""
check("LEGACY_TYPE values in types", ST, legacy)

def disjoint():
    sets = {
        "TEST_ONLY": set(literal(WS, "TEST_ONLY", "(", ")")),
        "READ_ONLY": set(literal(WS, "READ_ONLY", "(", ")")),
        "WRITER_ROLE_AGENTS": set(literal(SS, "WRITER_ROLE_AGENTS", "{", "}")),
    }
    names = sorted(sets)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            both = sets[a] & sets[b]
            if both:
                return "%s and %s overlap on %s" % (a, b, sorted(both))
    return eqtypes(set().union(*sets.values()))
check("TEST_ONLY / READ_ONLY / WRITER_ROLE_AGENTS disjoint, union == types", WS, disjoint)

def retired():
    m = re.search(r'^OLD_ROLE_NAMES="([^"]*)"', read("install.sh"), re.M)
    if not m:
        raise ValueError("no OLD_ROLE_NAMES assignment")
    both = sorted(set(m.group(1).split()) & types)
    return "retired names overlap current types: %s" % both if both else ""
check("OLD_ROLE_NAMES shares no name with types", "install.sh", retired)
PYEOF
)

while IFS= read -r line; do
  case "$line" in
    OK*)   echo "  ✓ ${line#OK    }" ;;
    FAIL*) echo "  ✗ ${line#FAIL  }"; fail=$((fail+1)) ;;
    INFO*) echo "  · ${line#INFO  }" ;;
  esac
done <<< "$out"
if [ -z "$out" ]; then echo "  ✗ the check printed nothing"; fail=$((fail+1)); fi

echo ""
if [ $fail -eq 0 ]; then
  echo "type-name-sets: pass"
  exit 0
fi
echo "type-name-sets: $fail failure(s)"
exit 1
