#!/bin/bash
# Regression test — the commit gate's review evidence is lens REPORT FILES
# (role-reduction s2a): `session_state.py gate-evidence <dir>` prints
# `test_edits high_risk_edits reviewers strong lite_lenses` and counts only
# regular, non-empty files in <root>/.rolepod/evidence/review/ whose exact
# suffix names a lens (-spec -standards -security -adversarial,
# -r<digits> re-check), modified inside the window.
# A dispatch, a transcript row, a meta file or a phase-log row counts nothing.
# Threat-model ids (A1..A12) follow
# docs/rolepod/specs/actor-rebuild-evidence/role-reduction-s2a/threat-model.md.
#
# Wired into `make test-static`.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"

SS="$REPO_DIR/hooks/lib/session_state.py"
fail=0
G="$(mktemp -d)"
tmp="$(mktemp)"
trap 'chmod -R u+rwx "$G" 2>/dev/null || true; rm -rf "$G" "$tmp"' EXIT

echo "── hook-agent-matching ──"

ts() { python3 -c "import datetime,sys;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$1"; }
( cd "$G" && git init -q . && git config user.email t@t && git config user.name t \
  && printf 'a\n' > a.txt && git add a.txt \
  && GIT_COMMITTER_DATE="$(ts 60)" git commit -q -m init --date="$(ts 60)" )
RV="$G/.rolepod/evidence/review"

reset() { chmod -R u+rwx "$RV" 2>/dev/null || true; rm -rf "$RV"; mkdir -p "$RV"; }
# put <name> [age-minutes | empty]: a report file (non-empty unless "empty")
put() {
  mkdir -p "$(dirname "$RV/$1")"
  if [ "${2:-}" = empty ]; then : > "$RV/$1"; else printf 'report\n' > "$RV/$1"; fi
  case "${2:-}" in ''|empty) ;; *) python3 -c "import os,sys,time;t=time.time()-60*int(sys.argv[2]);os.utime(sys.argv[1],(t,t))" "$RV/$1" "$2" ;; esac
}
# ge <expected "t h r s l"> <label>: gate-evidence from the repo's own cwd
ge() {
  local got
  got=$(cd "$G" && printf '{"transcript_path":""}' | python3 "$SS" gate-evidence "$G" 2>/dev/null || echo ERR)
  if [ "$got" = "$1" ]; then
    echo "  ✓ $2 (got $got)"
  else
    echo "  ✗ $2 — expected $1, got $got"
    fail=$((fail+1))
  fi
}

reset;                                        ge "0 0 0 0 0" "no report file → everything 0"
reset; put t-spec.md; put t-standards.md;     ge "0 0 2 0 2" "spec + standards → reviewers 2, lite_lenses 2"
reset; put t-spec.md;                         ge "0 0 1 0 1" "spec alone → reviewers 1, lite_lenses 1"
reset; put t-security.md;                     ge "0 0 1 1 0" "security → reviewers 1, strong 1, lite_lenses 0"
reset; put t-adversarial.md;                  ge "0 0 1 0 0" "adversarial → reviewers 1, never strong, never a lite lens"
reset; put t-security-engineer.md;            ge "0 0 0 0 0" "retired -security-engineer.md counts nothing"
reset; put t-spec-r2.md; put t-r12.md;        ge "0 0 2 0 0" "-r<digits> re-checks count as reviewers, never a lite lens"
reset; put t-security.md; put t-spec.md; put t-standards.md; put t-adversarial.md
                                              ge "0 0 4 1 2" "all four lenses → 4 / 1 / 2 (strong ≤ reviewers, lite_lenses ≤ 2)"

# A1 stale: mtime before the window (last commit 60 min ago)
reset; put t-spec.md 120; put t-security.md 120
                                              ge "0 0 0 0 0" "A1: a report older than the window counts 0"
reset; put t-spec.md 120; put t-standards.md
                                              ge "0 0 1 0 1" "A1: only the in-window report of a pair counts"
# A2 empty
reset; put t-spec.md empty;                   ge "0 0 0 0 0" "A2: a 0-byte report counts 0"
# A3 duplicate lens
reset; put a-task1-spec.md; put b-task2-spec.md
                                              ge "0 0 2 0 1" "A3: two -spec files, no -standards → lite_lenses 1"
# A4 specialist only
reset; put t-perf.md; put t-ui.md; put t-arch.md
                                              ge "0 0 0 0 0" "A4: -perf / -ui / -arch alone count 0 (code-no-test cannot auto-pass)"
# A5 role-named
reset; put t-universal-reviewer.md; put t-performance-engineer.md; put t-reviewer.md; put t-security-engineer.txt
                                              ge "0 0 0 0 0" "A5: role-named reports count 0"
# A6 look-alikes
reset; put x-Spec.md; put x-specs.md; put x-spec.md.bak; put x-security-engineer-x.md; put x-r.md; put x-rx.md; put x-Security.md; put x-spec.markdown; put x-STANDARDS.md
                                              ge "0 0 0 0 0" "A6: suffix look-alikes count 0 (exact, case-sensitive)"
# A7 not a regular file
reset; mkdir "$RV/x-spec.md"; put sub/x-standards.md
                                              ge "0 0 0 0 0" "A7: a directory named x-spec.md and a file under review/sub/ count 0"
reset; printf 'report\n' > "$G/outside.md"; ln -s "$G/outside.md" "$RV/x-spec.md"
                                              ge "0 0 0 0 0" "A7: a symlink named x-spec.md is not a regular file → 0"
# A12 scan error: never an exception, always 0 review counts
reset; rm -rf "$RV"; printf 'x' > "$RV"
                                              ge "0 0 0 0 0" "A12: review path is a file, not a directory → 0, no crash"
reset; put t-spec.md; put t-standards.md; chmod 000 "$RV"
if [ -r "$RV" ]; then
  echo "  · A12: chmod 000 still readable here (root?) — skipped"
else
                                              ge "0 0 0 0 0" "A12: unreadable review dir → all review counts 0, no crash"
fi
chmod 755 "$RV"

# A9 one file seen through two roots (a symlinked .rolepod) counts once
reset; put t-security.md
# a second checkout whose .rolepod is a symlink to the first: two roots, one evidence dir
G2="$(mktemp -d)"; ln -s "$G/.rolepod" "$G2/.rolepod"
( cd "$G2" && git init -q . && git config user.email t@t && git config user.name t && printf 'a\n' > a.txt && git add a.txt \
  && GIT_COMMITTER_DATE="$(ts 60)" git commit -q -m init --date="$(ts 60)" )
got=$(cd "$G2" && printf '{"transcript_path":""}' | python3 "$SS" gate-evidence "$G" 2>/dev/null || echo ERR)
if [ "$got" = "0 0 1 1 0" ]; then
  echo "  ✓ A9: one report reached through two roots (shared .rolepod) counts once (got $got)"
else
  echo "  ✗ A9: expected 0 0 1 1 0, got $got"; fail=$((fail+1))
fi
rm -rf "$G2"

# A8 a dispatch with no report file counts nothing — the transcript is no evidence
reset
printf '%s\n' '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' \
  '{"type":"tool_use","name":"Task","input":{"subagent_type":"rolepod:universal-reviewer","prompt":"review"}}' > "$tmp"
got=$(cd "$G" && printf '{"transcript_path":"%s"}' "$tmp" | python3 "$SS" gate-evidence "$G" 2>/dev/null || echo ERR)
if [ "$got" = "0 0 0 0 0" ]; then
  echo "  ✓ A8: finished security-engineer / universal-reviewer dispatches without a report count 0 (got $got)"
else
  echo "  ✗ A8: expected 0 0 0 0 0, got $got"; fail=$((fail+1))
fi

# A10 external pass: a phase-log review row and an external/*.txt file count 0
reset; mkdir -p "$G/.rolepod/evidence/external"
printf 'APPROVED\n' > "$G/.rolepod/evidence/external/codex-review.txt"
printf '{"ts":"%s","phase":"review","reviewer":"external","kind":"review","cli":"codex","verdict":"APPROVED"}\n' "$(ts 1)" > "$G/.rolepod/evidence/phase-log.jsonl"
printf '{"ts":"%s","phase":"dispatch","provenance":"hook-auto","agent_type":"security-engineer"}\n' "$(ts 1)" >> "$G/.rolepod/evidence/phase-log.jsonl"
ge "0 0 0 0 0" "A10: external pass files / phase-log review + dispatch rows count 0"

# count-all prints exactly two ints (test_edits high_risk_edits); a reviewer dispatch moves neither
printf '%s\n' '{"type":"tool_use","name":"Agent","input":{"subagent_type":"rolepod:security-engineer","prompt":"review"}}' > "$tmp"
got=$(printf '{"transcript_path":"%s"}' "$tmp" | python3 "$SS" count-all 2>/dev/null || echo ERR)
if [ "$got" = "0 0" ]; then
  echo "  ✓ count-all prints two ints and ignores a reviewer dispatch (got $got)"
else
  echo "  ✗ count-all — expected '0 0', got $got"; fail=$((fail+1))
fi
printf '%s\n' '{"type":"tool_use","name":"Edit","input":{"file_path":"tests/test_x.py"}}' > "$tmp"
got=$(printf '{"transcript_path":"%s"}' "$tmp" | python3 "$SS" count-all 2>/dev/null || echo ERR)
if [ "$got" = "1 0" ]; then
  echo "  ✓ count-all still counts a test edit (got $got)"
else
  echo "  ✗ count-all — expected '1 0', got $got"; fail=$((fail+1))
fi

# The dispatch-count machinery is gone from session_state.
left=$(/usr/bin/grep -c 'REVIEWER_AGENTS\|_phase_log_reviewer_counts\|_workflow_meta_reviewer' "$SS" || true)
if [ "$left" = "0" ]; then
  echo "  ✓ no dispatch-count helper left in session_state.py"
else
  echo "  ✗ session_state.py still names $left dispatch-count symbol line(s)"; fail=$((fail+1))
fi

# _bare_agent_name credits a bare name or the rolepod: namespace only; any
# other namespace stays whole and matches no role set.
bare=$(python3 - <<'PYEOF'
import sys
sys.path.insert(0, "hooks/lib")
import session_state as ss
cases = {"backend-developer": "backend-developer", "rolepod:backend-developer": "backend-developer",
         "otherplugin:backend-developer": "otherplugin:backend-developer", None: ""}
print("; ".join("%r -> %r" % (k, ss._bare_agent_name(k)) for k, v in cases.items() if ss._bare_agent_name(k) != v))
PYEOF
)
if [ -z "$bare" ]; then
  echo "  ✓ _bare_agent_name: bare and rolepod: reduce, another namespace stays whole"
else
  echo "  ✗ _bare_agent_name: $bare"; fail=$((fail+1))
fi

# TIER_PINNED_AGENTS must mirror the tier overlays: every type whose Claude
# tier renders a real model pin (cheap -> haiku, balanced -> sonnet) is in the
# set, and no overlay is strong (the Lead passes a strong model per call; no
# type is strong by name, STRONG_ROLE_AGENTS is gone). Drift here silently
# re-opens the gate hole a general-purpose agentType used to punch (v2.88.0).
drift=$(python3 - <<'PYEOF'
import re, pathlib, sys
sys.path.insert(0, "hooks/lib")
import session_state as ss
bad = []
if hasattr(ss, "STRONG_ROLE_AGENTS"):
    bad.append("STRONG_ROLE_AGENTS must be gone")
if ss.WRITER_ROLE_AGENTS != {"rolepod-builder"}:
    bad.append("WRITER_ROLE_AGENTS must be exactly {rolepod-builder}, got %s" % sorted(ss.WRITER_ROLE_AGENTS))
for y in sorted(pathlib.Path("adapters/claude/agent-frontmatter").glob("*.yml")):
    m = re.search(r"^tier:\s*(\S+)", y.read_text(), re.M)
    if not m:
        bad.append("%s: no tier:" % y.name); continue
    tier, name = m.group(1), y.stem
    if tier in ("cheap", "balanced"):
        if name not in ss.TIER_PINNED_AGENTS:
            bad.append("%s (%s) missing from TIER_PINNED_AGENTS" % (name, tier))
    else:
        bad.append("%s: tier %s (no type is strong)" % (name, tier))
known = {y.stem for y in pathlib.Path("adapters/claude/agent-frontmatter").glob("*.yml")}
if known != {"rolepod-builder", "rolepod-reviewer", "rolepod-qa", "rolepod-scout"}:
    bad.append("overlay set is not the 4 types: %s" % sorted(known))
for extra in sorted(ss.TIER_PINNED_AGENTS - known):
    bad.append("%s in TIER_PINNED_AGENTS but has no tier overlay" % extra)
print("; ".join(bad))
PYEOF
)
if [ -z "$drift" ]; then
  echo "  ✓ TIER_PINNED_AGENTS matches the tier overlays (4 types, none strong, no drift)"
else
  echo "  ✗ tier-set drift — $drift"
  fail=$((fail+1))
fi

# strong-fanout follows the model the call passes, never the type name.
NG="$G/nudge"; mkdir -p "$NG/home" "$NG/repo/.rolepod/evidence"
git -C "$NG/repo" init -q
printf '{"workflow":{"mode":"full"},"nudge":{"enabled":false}}\n' > "$NG/repo/.rolepod/config.json"
printf '{"type":"assistant","timestamp":"2026-08-17T01:00:00.000Z","message":{"model":"claude-opus-5","content":[]}}\n' > "$NG/lead-opus.jsonl"
nudge() {   # nudge <script> -> hook stdout
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"Workflow","transcript_path":sys.argv[1],"tool_input":{"script":sys.argv[2]}}))' "$NG/lead-opus.jsonl" "$1" \
    | (cd "$NG/repo" && HOME="$NG/home" ROLEPOD_SESSION_MODE=full ROLEPOD_SESSION_SOURCE=project ROLEPOD_SESSION_CLI=claude bash "$PWD_REPO/hooks/workflow-tier-nudge.sh")
}
PWD_REPO="$(pwd)"
out=$(nudge 'phase("Review"); await parallel(items.map((i) => () => agent(`r ${i}`, {agentType: "rolepod:rolepod-reviewer", label: `r:${i}`})))')
if [ -z "$out" ]; then echo "  ✓ strong-fanout: a fan-out of rolepod:rolepod-reviewer (no strong model on the call) is silent"
else echo "  ✗ strong-fanout: a type name alone denied: $out"; fail=$((fail+1)); fi
out=$(nudge 'phase("Review"); await parallel(items.map((i) => () => agent(`r ${i}`, {agentType: "rolepod:rolepod-reviewer", model: "opus", label: `r:${i}`})))')
if printf '%s' "$out" | /usr/bin/grep -q '"deny"' && printf '%s' "$out" | /usr/bin/grep -q 'strong model pinned on fan-out'; then
  echo "  ✓ strong-fanout: a fan-out that passes model opus is denied"
else echo "  ✗ strong-fanout: model opus on a fan-out not denied: $out"; fail=$((fail+1)); fi

echo ""
if [ $fail -eq 0 ]; then
  echo "hook-agent-matching: pass"
  exit 0
fi
echo "hook-agent-matching: $fail failure(s)"
exit 1
