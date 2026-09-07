#!/bin/bash
# plan-lint — deterministic lint of a filled plan artifact, plus the
# cohesion contract when the plan declares a parallel layout. The
# mechanical arm of write-plan §7 self-review.
#
# Usage: scripts/plan-lint.sh <plan.md> [contract.md]
#   The contract argument is optional — when omitted, the script looks for
#   a backticked *.md path inside the plan's "## Parallel layout" section
#   (resolved against the plan's directory, then the repo root). A plan
#   whose Parallel layout says "Sequential" skips the ownership check.
#
# Checks:
#   1. `## Failure policy` section present (the loop's circuit breaker).
#   2. Every task block carries a `Command:` (loop-runnable). A task heading
#      is `### Task N:` or `### TN —` — both shapes appear in real plans.
#   3. Blocked-by graph (v2.90.0): every task carries `Blocked by:`, every
#      reference resolves to a task in this plan, and the graph has no cycle.
#      The graph IS the plan's order; a Sequential plan whose graph has more
#      than one root gets an advisory naming the parallel candidates.
#      A plan with NO Blocked-by fields at all (pre-v2.90.0) is advised, not
#      failed — order was prose there.
#   4. Parallel plans only: every backticked path under "## Files to touch"
#      appears under EXACTLY one owner in the contract's "## File ownership"
#      — an unowned file is unplannable work; a dual-owned file is a merge
#      conflict on schedule.
#
# Exit 0 = pass. Exit 1 = fail, every violation named on stdout.
set -uo pipefail

PLAN="${1:-}"
CONTRACT="${2:-}"

if [ -z "$PLAN" ] || [ ! -f "$PLAN" ]; then
  echo "usage: plan-lint.sh <plan.md> [contract.md]" >&2
  exit 2
fi

fail=0

# ── 1. Failure policy ────────────────────────────────────────────────────
if grep -q '^## Failure policy' "$PLAN"; then
  echo "  ✓ Failure policy present"
else
  echo "  ✗ missing '## Failure policy' — the build loop has no circuit breaker"
  fail=1
fi

# ── 2. Command per task ──────────────────────────────────────────────────
# Walk each task block on its own — an aggregate count let one task's
# extra Commands cover for a sibling with none, and 0 tasks passed 0 >= 0.
# 'Command:' still counts only inside task blocks (never Failure-policy prose).
# Heading shapes: `### Task 1:` (template) and `### T1 —` (a real CourtBook
# plan, which this lint rejected wholesale before v2.90.0).
TASK_RX='^### (Task ?|T)[0-9]+'
TASKS=$(grep -Ec "$TASK_RX" "$PLAN" || true)
MISSING=$(awk -v rx="$TASK_RX" '
  $0 ~ rx     { if (t != "" && !c) print t; t = $0; c = 0; next }
  /^## /      { if (t != "" && !c) print t; t = ""; next }
  t != "" && /Command:/ { c = 1 }
  END         { if (t != "" && !c) print t }
' "$PLAN")
if [ "${TASKS:-0}" -eq 0 ]; then
  echo "  ✗ no task blocks found (### Task N: / ### TN —) — nothing for the build loop to run"
  fail=1
elif [ -z "$MISSING" ]; then
  echo "  ✓ every task carries a Command ($TASKS/$TASKS)"
else
  while IFS= read -r t; do
    [ -n "$t" ] && echo "  ✗ missing Command: ${t#\#\#\# } — a Command-less task cannot be verified by the loop"
  done <<EOF
$MISSING
EOF
  fail=1
fi

# Parallel layout is read once here — the graph check below needs to know
# whether Sequential was CHOSEN (then extra roots are an advisory, not a
# mistake), and the ownership check needs the contract path.
# Anchored to a line START (optional bullet) — a bare substring grep let
# 'Not sequential — two tracks run concurrently' skip the ownership check.
LAYOUT=$(awk '/^## Parallel layout/{f=1;next} /^## /{f=0} f' "$PLAN")
SEQUENTIAL=0
printf '%s' "$LAYOUT" | grep -qiE '^[[:space:]]*([-*][[:space:]]*)?sequential' && SEQUENTIAL=1

# ── 3. Blocked-by graph ──────────────────────────────────────────────────
# One awk pass: task id from the heading, refs from the `Blocked by:` line
# (integers after the colon; "none" / "—" / "-" = no blockers). Then resolve
# every ref, count fields, and run Kahn's algorithm for a cycle. Output lines
# are prefixed so the shell can route them: E = fail, A = advisory.
GRAPH=$(awk -v rx="$TASK_RX" -v seq="$SEQUENTIAL" '
  function trim(x) { sub(/^[[:space:]]+/, "", x); sub(/[[:space:]]+$/, "", x); return x }
  $0 ~ rx {
    id = $0; sub(/^### (Task ?|T)/, "", id); sub(/[^0-9].*$/, "", id)
    if (id in seen) dup[id] = 1
    cur = id; n++; order[n] = id; seen[id] = 1; next
  }
  /^## / { cur = "" ; next }
  cur != "" && /Blocked by:/ && !(cur in has) {
    has[cur] = 1; v = $0; sub(/^.*Blocked by:[[:space:]]*/, "", v); v = trim(v)
    gsub(/\*/, "", v)
    if (v ~ /^([Nn]one|—|-|–)/) next
    # strip a trailing aside so "none (T3 could gate…)" never grows an edge
    sub(/[(—].*$/, "", v)
    m = v
    while (match(m, /[0-9]+/)) {
      r = substr(m, RSTART, RLENGTH); m = substr(m, RSTART + RLENGTH)
      if (!(cur SUBSEP r in edge)) { edge[cur, r] = 1; refs[cur] = refs[cur] " " r }
    }
    next
  }
  END {
    if (n == 0) exit 0
    for (d in dup) print "E duplicate task id " d " — two blocks carry the same number; Blocked by cannot name either"
    withf = 0; for (k = 1; k <= n; k++) if (order[k] in has) withf++
    if (withf == 0) { print "A no Blocked by fields — order is prose only; add one per task"; exit 0 }
    for (k = 1; k <= n; k++) if (!(order[k] in has)) print "E Task " order[k] " has no Blocked by (other tasks do) — state its blockers or none"
    # Resolve refs only now — a blocker may be declared later in the file.
    # An unresolved or self ref is reported and dropped from the graph, so
    # it cannot masquerade as a cycle below.
    for (k = 1; k <= n; k++) {
      t = order[k]; split(refs[t], rs, " ")
      for (j in rs) { r = rs[j]; if (r == "") continue
        if (!(r in seen)) { print "E Task " t " is blocked by Task " r " — no such task in this plan"; edge[t, r] = 0 }
        else if (r == t)  { print "E Task " t " blocks itself"; edge[t, r] = 0 }
        else indeg[t]++
      }
    }
    # Kahn: indeg = number of RESOLVED blockers; peel roots
    done = 0; roots = ""
    for (k = 1; k <= n; k++) { t = order[k]; if (indeg[t] + 0 == 0) { q[++qt] = t; roots = roots (roots == "" ? "" : ", ") t } }
    while (qh < qt) { t = q[++qh]; done++
      for (k = 1; k <= n; k++) { u = order[k]; if ((u, t) in edge) { edge[u, t] = 0; indeg[u]--; if (indeg[u] == 0) q[++qt] = u } } }
    if (done < n) { c = ""; for (k = 1; k <= n; k++) if (indeg[order[k]] > 0) c = c (c == "" ? "" : ", ") order[k]
      if (c != "") print "E Blocked-by cycle among Tasks " c " — nothing can start" }
    else if (seq && qt > 0 && index(roots, ",")) print "A parallel candidates: Tasks " roots " have no blockers — Sequential chosen, fine if the layout line says why"
  }
' "$PLAN")
GRAPH_E=$(printf '%s\n' "$GRAPH" | grep '^E ' || true)
GRAPH_A=$(printf '%s\n' "$GRAPH" | grep '^A ' || true)
if [ -n "$GRAPH_E" ]; then
  printf '%s\n' "$GRAPH_E" | sed 's/^E /  ✗ /'
  fail=1
elif [ "${TASKS:-0}" -gt 0 ] && [ -z "$GRAPH_A" ]; then
  echo "  ✓ Blocked-by graph resolves, no cycle ($TASKS tasks)"
elif [ -n "$GRAPH_A" ] && ! printf '%s' "$GRAPH_A" | grep -q 'no Blocked by fields'; then
  echo "  ✓ Blocked-by graph resolves, no cycle ($TASKS tasks)"
fi
[ -n "$GRAPH_A" ] && printf '%s\n' "$GRAPH_A" | sed 's/^A /  · /'

# ── 4. Parallel ownership completeness ───────────────────────────────────
if [ "$SEQUENTIAL" -eq 1 ]; then
  echo "  ✓ sequential layout — ownership check not applicable"
  echo "plan-lint: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
  exit "$fail"
fi

# Resolve the contract file.
if [ -z "$CONTRACT" ]; then
  REL=$(printf '%s' "$LAYOUT" | grep -oE '`[^`]+\.md`' | head -1 | tr -d '`')
  if [ -n "$REL" ]; then
    PLAN_DIR="$(cd "$(dirname "$PLAN")" && pwd)"
    ROOT="$(git -C "$PLAN_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$PLAN_DIR")"
    for cand in "$PLAN_DIR/$REL" "$ROOT/$REL" "$REL"; do
      [ -f "$cand" ] && CONTRACT="$cand" && break
    done
  fi
fi

if [ -z "$CONTRACT" ] || [ ! -f "$CONTRACT" ]; then
  if [ -n "$LAYOUT" ]; then
    echo "  ✗ parallel layout declared but no cohesion contract found — Iron Rule 2: no parallel agents without a contract"
    fail=1
  else
    echo "  ✗ no '## Parallel layout' section — declare 'Sequential — single owner.' or the contract path"
    fail=1
  fi
  echo "plan-lint: FAIL"
  exit 1
fi

OWNERSHIP=$(awk '/^## File ownership/{f=1;next} /^## /{f=0} f' "$CONTRACT")
if [ -z "$OWNERSHIP" ]; then
  echo "  ✗ contract has no '## File ownership' section"
  echo "plan-lint: FAIL"
  exit 1
fi

# Every backticked path in the plan's Files-to-touch must appear under
# exactly one owner line.
FILES=$(awk '/^## Files to touch/{f=1;next} /^## /{f=0} f' "$PLAN" \
        | grep -oE '`[^`]+`' | tr -d '`' | sort -u)
if [ -z "$FILES" ]; then
  echo "  ✗ parallel plan has no backticked paths under '## Files to touch'"
  fail=1
fi

OWN_OK=1
while IFS= read -r f; do
  [ -n "$f" ] || continue
  # Count OWNER LINES that mention the exact backticked path.
  N=$(printf '%s\n' "$OWNERSHIP" | grep -cF "\`$f\`" || true)
  if [ "${N:-0}" -eq 0 ]; then
    echo "  ✗ unowned file: \`$f\` — in Files-to-touch but under no owner in the contract"
    OWN_OK=0; fail=1
  elif [ "${N:-0}" -gt 1 ]; then
    echo "  ✗ dual-owned file: \`$f\` — appears under $N owner lines; a path belongs to exactly one owner"
    OWN_OK=0; fail=1
  fi
done <<EOF
$FILES
EOF
[ "$OWN_OK" -eq 1 ] && [ -n "$FILES" ] && echo "  ✓ every touched file has exactly one owner"

echo "plan-lint: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
exit "$fail"
