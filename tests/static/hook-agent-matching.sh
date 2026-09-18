#!/bin/bash
# Regression test — hooks must count plugin-namespaced reviewer agents.
#
# Bug: session_state.count_reviewers_dispatched matched bare agent names
# only. A plugin-installed reviewer is dispatched as 'rolepod:qa-tester';
# it counted as 0, so precommit-gate false-blocked a commit even after
# qa-tester + security-engineer had actually reviewed and APPROVED.
#
# Wired into `make test-static`.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"

SS="hooks/lib/session_state.py"
fail=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# run <transcript-jsonl> <query> <expected> <label>
run() {
  printf '%s\n' "$1" > "$tmp"
  local got
  got=$(printf '{"transcript_path":"%s"}' "$tmp" | python3 "$SS" "$2" 2>/dev/null || echo ERR)
  if [ "$got" = "$3" ]; then
    echo "  ✓ $4 (got $got)"
  else
    echo "  ✗ $4 — expected $3, got $got"
    fail=$((fail+1))
  fi
}

echo "── hook-agent-matching ──"

# The bug: a plugin-namespaced reviewer must count.
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:universal-reviewer"}}' \
  count-reviewers-dispatched 1 "rolepod:universal-reviewer counts as a reviewer"

# qa-tester is E2E verification, never the per-diff review floor (v2.148.4).
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:qa-tester","prompt":"review-mode ONLY. Do NOT edit any file."}}' \
  count-reviewers-dispatched 0 "rolepod:qa-tester never counts, even in review-mode"

# The 'Task' tool name must count too (CLI-version variance).
run '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:security-engineer"}}' \
  count-reviewers-dispatched 1 "Task tool + rolepod:security-engineer counts"

# A brief that declares write-mode is a writer, not a reviewer (v2.113.0).
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:security-engineer","prompt":"## Mode\nwrite-mode: add a failing authz test for TC3"}}' \
  count-reviewers-dispatched 0 "write-mode security-engineer is not a review"
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:universal-reviewer","prompt":"review-mode ONLY. Do NOT edit any file."}}' \
  count-reviewers-dispatched 1 "review-mode universal-reviewer counts"
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:universal-reviewer","prompt":"Read the diff and judge correctness"}}' \
  count-reviewers-dispatched 1 "a brief with no mode word still counts (fail-open)"
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:security-engineer","prompt":"review-mode ONLY - do NOT edit, you are not in write-mode"}}' \
  count-reviewers-dispatched 1 "review-mode that merely mentions write-mode still counts"

# A bare (un-namespaced) name must still count — no regression.
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"universal-reviewer"}}' \
  count-reviewers-dispatched 1 "bare universal-reviewer still counts"
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"qa-tester"}}' \
  count-reviewers-dispatched 0 "bare qa-tester does not count"

# A non-reviewer agent must NOT count.
run '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:backend-developer"}}' \
  count-reviewers-dispatched 0 "rolepod:backend-developer is not a reviewer"

# Workflow-run reviewers (agent() agentType calls) must count — a workflow
# that already reviewed must not force a duplicate Agent-tool dispatch.
run '{"type":"tool_use","name":"Workflow","input":{"script":"const r = await agent(prompt, {agentType: '\''rolepod:universal-reviewer'\''})"}}' \
  count-reviewers-dispatched 1 "Workflow agentType universal-reviewer counts"

run '{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''rolepod:backend-developer'\''})"}}' \
  count-reviewers-dispatched 0 "Workflow agentType backend-developer does not count"

# count-all strong split: inherit → strong; explicit low model → reviewer only.
run '{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''security-engineer'\''})"}}' \
  count-all "0 0 1 1" "Workflow reviewer (no model = frontmatter opus) counts as strong in count-all"

run '{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''security-engineer'\'', model: '\''haiku'\''})"}}' \
  count-all "0 0 1 0" "Workflow reviewer pinned haiku is not strong"

# v2.104.0 — a Workflow agentType strong reviewer with no explicit model runs its
# frontmatter pin (opus): strong under ANY Lead. From v2.74.0 to v2.103 it rendered
# inherit and counted only under a strong Lead (CourtBook technician review fleet
# had cleared the commit gate with a sonnet security-engineer). Explicit opus counts anywhere.
wf_tu='{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''rolepod:security-engineer'\''})"}}'
wf_tu_opus='{"type":"tool_use","name":"Workflow","input":{"script":"await agent(p, {agentType: '\''rolepod:security-engineer'\'', model: '\''opus'\''})"}}'
lead_sonnet='{"type":"assistant","message":{"model":"claude-sonnet-5","content":[]}}'
lead_opus='{"type":"assistant","message":{"model":"claude-opus-5","content":[]}}'
run "$lead_sonnet"$'\n'"$wf_tu"      count-all "0 0 1 1" "v2.104: Workflow reviewer (frontmatter opus) under a sonnet Lead IS strong"
run "$lead_opus"$'\n'"$wf_tu"        count-all "0 0 1 1" "v2.104: Workflow reviewer (frontmatter opus) under an opus Lead is strong"
run "$lead_sonnet"$'\n'"$wf_tu_opus" count-all "0 0 1 1" "v2.74: Workflow reviewer pinned opus under a sonnet Lead is strong"

# v2.88.0 — TIER_PINNED_AGENTS must mirror the tier overlays: every role whose
# Claude tier renders a real model pin (cheap -> haiku, balanced -> sonnet) is
# in the set, every `strong` role (renders opus; the hook floors it) is in STRONG_ROLE_AGENTS and
# NOT in it. Drift here silently re-opens the gate hole a general-purpose
# agentType used to punch (v2.88.0).
drift=$(python3 - <<'PYEOF'
import re, pathlib, sys
sys.path.insert(0, "hooks/lib")
import session_state as ss
bad = []
for y in sorted(pathlib.Path("adapters/claude/agent-frontmatter").glob("*.yml")):
    m = re.search(r"^tier:\s*(\S+)", y.read_text(), re.M)
    if not m:
        bad.append("%s: no tier:" % y.name); continue
    tier, name = m.group(1), y.stem
    if tier in ("cheap", "balanced"):
        if name not in ss.TIER_PINNED_AGENTS:
            bad.append("%s (%s) missing from TIER_PINNED_AGENTS" % (name, tier))
    elif tier == "strong":
        if name not in ss.STRONG_ROLE_AGENTS:
            bad.append("%s (strong) missing from STRONG_ROLE_AGENTS" % name)
        if name in ss.TIER_PINNED_AGENTS:
            bad.append("%s (strong, floored via STRONG_ROLE_AGENTS) must NOT be in TIER_PINNED_AGENTS" % name)
    else:
        bad.append("%s: unknown tier %s" % (name, tier))
known = {y.stem for y in pathlib.Path("adapters/claude/agent-frontmatter").glob("*.yml")}
for extra in sorted(ss.TIER_PINNED_AGENTS - known):
    bad.append("%s in TIER_PINNED_AGENTS but has no tier overlay" % extra)
print("; ".join(bad))
PYEOF
)
if [ -z "$drift" ]; then
  echo "  ✓ TIER_PINNED_AGENTS matches the tier overlays (no drift)"
else
  echo "  ✗ tier-set drift — $drift"
  fail=$((fail+1))
fi

# bash-writes-are-edits (spec R1/R6) — bash_write_paths() detector cases.
# One import, one small command each; expected paths are absolute (resolved
# against the repo root this script cd'd into at the top).
bwp=$(python3 - <<'PYEOF'
import os, sys
sys.path.insert(0, "hooks/lib")
import session_state as ss

root = os.getcwd()
p = lambda name: os.path.join(root, name)
cases = [
    ("printf x > out.txt", [p("out.txt")], "redirect target"),
    ("printf x >> out.txt", [p("out.txt")], "append target"),
    ("tee -a out.txt", [p("out.txt")], "tee target"),
    ("sed -i s/a/b/ out.txt", [p("out.txt")], "sed -i target"),
    ("cp a.txt out.txt", [p("out.txt")], "cp destination (last arg)"),
    ("rm out.txt", [p("out.txt")], "rm target"),
    ("cat > out.txt <<EOF\nrm -rf /\nEOF", [p("out.txt")], "heredoc body ignored"),
    ("printf x 2>&1", [], "2>&1 ignored (fd form)"),
    ("printf x > /dev/null", [], "/dev/null ignored"),
    ('bash -c "cat > inner.txt"', [p("inner.txt")], "bash -c inner write parsed"),
    ("printf x > /etc/passwd", [], "path outside the repo dropped"),
    ("cp a.py b.py 2>/dev/null", [p("b.py")], "cp dest not confused by a trailing stderr redirect"),
    ("tee out.txt 2>/dev/null", [p("out.txt")], "tee target not confused by a trailing stderr redirect"),
    ("perl -Ilib -e 'print 1' file.pl", [], "perl -Ilib is not in-place editing"),
    ("bash run.sh > out.txt", [p("out.txt")], "shell running a script FILE (no -c) still reports its own redirect"),
    ("sed -ri s/a/b/ src/app.ts", [p("src/app.ts")], "sed -ri clustered flag"),
    ("sed -Ei s/a/b/ src/app.ts", [p("src/app.ts")], "sed -Ei clustered flag"),
    ("sed -ni s/a/b/ src/app.ts", [p("src/app.ts")], "sed -ni clustered flag"),
    ("sed -i '' s/a/b/ src/y.py", [p("src/y.py")], "BSD sed -i '' empty-suffix arg is not a path, script is not a path"),
    ("tee out.txt <<EOF\nhello\nEOF", [p("out.txt")], "heredoc operand (<<HEREDOC placeholder) is not a second write target"),
]
bad = []
for cmd, expect, label in cases:
    got = ss.bash_write_paths(cmd, root)
    if got != expect:
        bad.append("%s: expected %r got %r" % (label, expect, got))
print("; ".join(bad))
PYEOF
)
if [ -z "$bwp" ]; then
  echo "  ✓ bash_write_paths detector cases (redirect/append/tee/sed-i/cp/rm/heredoc/2>&1//dev/null/bash-c/outside-repo/stderr-redirect/perl-Ilib/script-file/sed-cluster/bsd-sed-i/heredoc-operand)"
else
  echo "  ✗ bash_write_paths — $bwp"
  fail=$((fail+1))
fi

# A Bash-written test file counts as a test edit (R2) — same as an Edit tool
# targeting the file directly.
run '{"type":"tool_use","name":"Bash","input":{"command":"cat > tests/test_x.py <<EOF\nassert True\nEOF"}}' \
  count-test-edits 1 "Bash-written test file counts as a test edit"

echo ""
if [ $fail -eq 0 ]; then
  echo "hook-agent-matching: pass"
  exit 0
fi
echo "hook-agent-matching: $fail failure(s)"
exit 1
