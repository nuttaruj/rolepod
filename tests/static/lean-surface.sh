#!/bin/bash
# lean-surface — anti-drift static guards.
# Locks in structural invariants a per-hook seam test can't reach: skill
# dir/catalog counts, frontmatter shape (name/description, tier agreement,
# effort ceiling), packaging leaks, version-manifest lockstep, and a
# competitor brand name reappearing anywhere in source.
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

# ── Filesystem skill dirs = the 19 phase/helper skills + rolepod-stats ──
# The one skill-count owner (render reads these dirs).
FS_SKILLS=$(find core/skills -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
check "filesystem skill dirs = the 19 phase/helper skills + rolepod-stats = 20 (actual: $FS_SKILLS)" "[ $FS_SKILLS -eq 20 ]"

DC="core/skills/deepen-codebase/SKILL.md"
check "deepen-codebase command skill exists" "[ -f $DC ]"
if [ -f "$DC" ]; then
  check "deepen-codebase is manual-invoke only (disable-model-invocation)" "grep -q '^disable-model-invocation: true' $DC"
fi
WP="core/skills/write-prototype/SKILL.md"
check "write-prototype on-demand skill exists" "[ -f $WP ]"
if [ -f "$WP" ]; then
  check "write-prototype is model + user callable (not manual-invoke only)" "! grep -q '^disable-model-invocation' $WP"
fi

DMI_SET=$(grep -l '^disable-model-invocation: true' core/skills/*/SKILL.md | sed 's#core/skills/##; s#/SKILL.md##' | sort | tr '\n' ' ')
check "exactly deepen-codebase and rolepod-stats are manual-invoke; manage-context stays model-callable (U-C; actual: $DMI_SET)" "[ \"$DMI_SET\" = 'deepen-codebase rolepod-stats ' ]"

# Codex explicit-invoke gate: only the manual-invoke skills get an
# agents/openai.yaml (learn.chatgpt.com/docs/build-skills), and only those.
CODEX_YAML_SET=$(find plugins/rolepod-codex/skills -path '*/agents/openai.yaml' 2>/dev/null | sed 's#plugins/rolepod-codex/skills/##; s#/agents/openai.yaml##' | sort | tr '\n' ' ')
check "Codex agents/openai.yaml dirs equal the manual-invoke set (actual: $CODEX_YAML_SET)" "[ \"$CODEX_YAML_SET\" = \"$DMI_SET\" ]"
check "each manual-invoke skill's Codex openai.yaml holds allow_implicit_invocation: false" \
  "for s in $DMI_SET; do grep -q 'allow_implicit_invocation: false' plugins/rolepod-codex/skills/\$s/agents/openai.yaml || exit 1; done"
SHARED_YAML_SET=$(find skills -path '*/agents/openai.yaml' 2>/dev/null | sed 's#skills/##; s#/agents/openai.yaml##' | sort | tr '\n' ' ')
check "shared skills/ openai.yaml dirs equal the manual-invoke set (actual: $SHARED_YAML_SET)" "[ \"$SHARED_YAML_SET\" = \"$DMI_SET\" ]"

# Clause-chain guard: no prose line past 600 chars. The accretion shape
# was a 2,528-char line carrying eight directives with nested exceptions —
# a model drops or mis-orders clauses in such a line (three cross-CLI
# reviewers agreed, 2026-09-12). Table rows are one logical item each and
# are exempt; a table cell that runs long is still a smell, not a failure.
LONG_LINES=""
for d in core/skills/*/; do
  f="${d}SKILL.md"; [ -f "$f" ] || continue
  n=$(awk 'length > 600 && !/^\|/' "$f" | wc -l | tr -d ' ')
  [ "$n" -eq 0 ] || LONG_LINES="${LONG_LINES}$(basename "$d") ($n) "
done
if [ -z "$LONG_LINES" ]; then
  echo "  ✓ no SKILL.md prose line past 600 chars"
else
  echo "  ✗ SKILL.md prose line(s) past 600 chars: $LONG_LINES"
  fail=$((fail+1))
fi

# Platform fact (2026-10-05): Claude Code reattaches an invoked skill after
# compaction truncated at 20,000 characters. Every rendered SKILL.md on every
# target stays under it (chars, not bytes); the count guards a missing tree.
SKILL_20K=$(python3 -I - <<'PYEOF'
import glob
roots = ["skills", "plugins/rolepod/skills", "plugins/rolepod-cursor/skills", "plugins/rolepod-codex/skills",
         "build/rendered/antigravity/plugin/skills", "build/rendered/opencode/skills"]
files = [f for r in roots for f in sorted(glob.glob(r + "/*/SKILL.md"))]
bad = [f + "=" + str(n) for f in files for n in [len(open(f, encoding="utf-8").read())] if n >= 20000]
print(len(files), "; ".join(bad) or "none")
PYEOF
)
SKILL_N=${SKILL_20K%% *}; OVER_20K=${SKILL_20K#* }
check "every rendered SKILL.md is under 20,000 chars ($SKILL_N files; over: $OVER_20K)" "[ \"$SKILL_N\" -eq $((FS_SKILLS * 6)) ] && [ \"$OVER_20K\" = none ]"

# ── Standalone guard — plan task-block labels named in write-plan ─────
# Every bold task-block label of plan-template's Task 1 block must appear
# in write-plan/SKILL.md — plan-lint and implement-plan's ticket.sh parse
# those exact field names. A label added or renamed without updating the prose that
# asserts it fails here, before it ships as a silent drift.
STANDALONE_FIELD_MISSES=$(python3 -I - <<'PYEOF'
import pathlib, re
ROOT = pathlib.Path(".")
misses = []
plan_template = ROOT / "core/skills/write-plan/templates/plan-template.md"
write_plan = ROOT / "core/skills/write-plan/SKILL.md"
if not plan_template.is_file():
    misses.append("plan-template.md: file missing")
elif not write_plan.is_file():
    misses.append("write-plan/SKILL.md: file missing")
else:
    write_plan_text = write_plan.read_text(encoding="utf-8").lower()
    in_task1, task1_lines = False, []
    for line in plan_template.read_text(encoding="utf-8").splitlines():
        if line.startswith("### Task 1:"):
            in_task1 = True
            continue
        if in_task1 and line.startswith("### Task 2:"):
            break
        if in_task1:
            task1_lines.append(line)
    if not task1_lines:
        misses.append("plan-template.md: no ### Task 1: block found")
    for line in task1_lines:
        for m in re.finditer(r"\*\*([A-Za-z /]+):\*\*", line):
            if m.group(1).lower() not in write_plan_text:
                misses.append(m.group(1))
print("; ".join(misses))
PYEOF
)
check "every plan task-block label is named in write-plan/SKILL.md (misses: ${STANDALONE_FIELD_MISSES:-none})" "[ -z \"\$STANDALONE_FIELD_MISSES\" ]"

# ── Standalone continuity probes ─────────────────────────────────────
# Each probe must exercise one rendered skill through the public runner,
# with positive and negative assertions plus a quote/trace request.
PROBE_STRUCTURE_FAILURES=""
for probe_spec in \
  "L01-compact-spec:write-spec" \
  "L02-compact-plan:write-plan" \
  "L03-canonical-evidence:check-work" \
  "L04-jit-resume:manage-context" \
  "L05-conditional-finish:finish-work"; do
  probe_id=${probe_spec%%:*}
  probe_skill=${probe_spec#*:}
  probe_file="tests/probes/cases/${probe_id}.md"
  if [ ! -f "$probe_file" ]; then
    PROBE_STRUCTURE_FAILURES="${PROBE_STRUCTURE_FAILURES}${probe_id}: missing; "
    continue
  fi
  probe_skill_count=$(grep -c '^skill:' "$probe_file" || true)
  probe_expect_count=$(grep -c '^expect:' "$probe_file" || true)
  probe_has_forbid=0; grep -q '^forbid:' "$probe_file" && probe_has_forbid=1
  probe_has_trace=0; grep -q '^TRACE:' "$probe_file" && probe_has_trace=1
  [ "$probe_skill_count" -eq 1 ] && grep -qx "skill: ${probe_skill}" "$probe_file" \
    || PROBE_STRUCTURE_FAILURES="${PROBE_STRUCTURE_FAILURES}${probe_id}: expected exactly skill ${probe_skill}; "
  [ "$probe_expect_count" -ge 3 ] && [ "$probe_has_forbid" -eq 1 ] && [ "$probe_has_trace" -eq 1 ] \
    || PROBE_STRUCTURE_FAILURES="${PROBE_STRUCTURE_FAILURES}${probe_id}: needs 3+ expects, forbid, and trace; "
done
check "L01-L05 probe cases use one owning skill and expected/forbidden trace assertions (issues: ${PROBE_STRUCTURE_FAILURES:-none})" \
  '[ -z "$PROBE_STRUCTURE_FAILURES" ]'

# ── Skill skeleton checks (spec: minimal skeleton, D2/D3 cut) ──────────
# The spec's minimal skeleton only requires frontmatter `name` +
# `description` on every skill file. The old fixed-section requirements
# (## Boundary, the no-agent-fallback grep, the ## Next phase fallback
# check) assumed the old fixed skeleton and are cut (D3 doctrine wording).
ALL_SKILLS=(using-rolepod deepen-codebase write-prototype write-spec write-plan implement-plan debug-issue check-work review-code finish-work simplify-code manage-context cross-family tdd-flow adversarial-review security-review coordinating-parallel-tracks convening-code-review orchestrating-plans)
SKELETON_MISSING=""
for s in "${ALL_SKILLS[@]}"; do
  f="core/skills/$s/SKILL.md"
  if [ ! -f "$f" ]; then
    SKELETON_MISSING="${SKELETON_MISSING}${s}: file missing\n"; continue
  fi
  grep -q '^name: ' "$f" || SKELETON_MISSING="${SKELETON_MISSING}${s}: no frontmatter name\n"
  grep -q '^description: ' "$f" || SKELETON_MISSING="${SKELETON_MISSING}${s}: no frontmatter description\n"
done
if [ -z "$SKELETON_MISSING" ]; then
  echo "  ✓ all 19 skills carry frontmatter name + description"
else
  echo "  ✗ skills missing skeleton frontmatter:"
  printf "%b" "$SKELETON_MISSING" | sed 's/^/      /'
  fail=$((fail+1))
fi

# A plain YAML scalar holding ": " or " #" (or ending in ":") is invalid: strict
# loaders drop the whole skill / agent. Shared skills/ tree + every bundle's agents.
YAML_PLAIN=$(python3 - <<'PY'
import glob, re
bad = []
for f in sorted(glob.glob("skills/**/SKILL.md", recursive=True) + glob.glob("plugins/*/agents/*.md")):
    lines = open(f, encoding="utf-8").read().split("\n")
    if not lines or lines[0] != "---":
        continue
    for i, ln in enumerate(lines[1:], 2):
        if ln == "---":
            break
        m = re.match(r"^[A-Za-z_][\w-]*:\s+(\S.*)$", ln)
        if not m:
            continue
        v = m.group(1)
        if v[0] in "\"'":
            continue
        if ": " in v or " #" in v or v.endswith(":"):
            bad.append("%s:%d" % (f, i))
print("\n".join(bad))
PY
)
if [ -z "$YAML_PLAIN" ]; then
  echo "  ✓ frontmatter plain values carry no ': ' / ' #' / trailing ':' (skills + agents)"
else
  echo "  ✗ unquoted frontmatter value with ': ' / ' #' / trailing ':' (invalid YAML):"
  printf "%s\n" "$YAML_PLAIN" | sed 's/^/      /'
  fail=$((fail+1))
fi

check "adversarial-review keeps its stance heading" "[ \"$(/usr/bin/grep -c '^## Reviewer stance$' core/skills/adversarial-review/SKILL.md)\" -eq 1 ]"

# ── Packaging leak — what ships under plugins/ is only what is meant to ──
# `git ls-files plugins/` is exactly what a marketplace install copies. An
# extension outside the allow-list, a secret-shaped file or an OS artifact
# there is a leak, whatever wrote it (render, a stray git add, an editor).
LEAK=$(git ls-files plugins/ | python3 -c '
import re, sys
ok_ext = {"md", "sh", "py", "toml", "json", "mdc", "txt", "yml", "yaml"}
bad = []
for p in sys.stdin.read().split():
    name = p.rsplit("/", 1)[-1]
    low = name.lower()
    if low in (".ds_store", "thumbs.db") or re.search(r"(^|\.)(env|pem|key|p12|secrets|credentials)(\..*)?$", low) or low.endswith((".map", ".log", ".orig", ".rej", ".swp", ".bak")):
        bad.append(p); continue
    ext = name.rsplit(".", 1)[-1].lower() if "." in name else ""
    # No .js ships under plugins/ any more (ticket-fleet.js removed
    # v2.179.0 — every script now lives in the owner skill scripts dir,
    # shell only); a .js there is a leak, no exception.
    allowed = ext in ok_ext
    if not allowed and not name.startswith("."):
        bad.append(p)
print("\n".join(bad))
' 2>/dev/null || true)
check "plugins/ ships only allow-listed extensions, no secret-shaped or OS-artifact files (leak: ${LEAK:-none})" "[ -z \"$LEAK\" ]"

# ── Version manifests — one 2.x/0.x lockstep pair across all carriers ──
# 6 hand-edited sources (scripts/bump-version.sh) + 4 committed render
# copies = 10 files / 12 version fields. Antigravity tracks the release on
# a 0.x line (2.38.0 ↔ 0.38.0). Drift here shipped before: antigravity sat
# at 0.35.1 through two releases with nothing catching it.
V_MAIN=$(python3 -c "import json;print(json.load(open('adapters/claude/.claude-plugin/plugin.json'))['version'])")
V_LOCK="0.${V_MAIN#2.}"
version_drift=$(python3 - "$V_MAIN" "$V_LOCK" <<'PYEOF'
import re, sys
v_main, v_lock = sys.argv[1], sys.argv[2]
carriers = {
    "adapters/claude/.claude-plugin/plugin.json": v_main,
    "adapters/codex/plugins/rolepod/.codex-plugin/plugin.json": v_main,
    "adapters/cursor/.cursor-plugin/plugin.json": v_main,
    "adapters/cursor/.cursor-plugin/marketplace.json": v_main,
    "adapters/opencode/opencode.json": v_main,
    "adapters/antigravity/plugin.json": v_lock,
    "plugins/rolepod/.claude-plugin/plugin.json": v_main,
    "plugins/rolepod-codex/.codex-plugin/plugin.json": v_main,
    "plugins/rolepod-cursor/.cursor-plugin/plugin.json": v_main,
    ".cursor-plugin/marketplace.json": v_main,
}
bad = []
for path, want in carriers.items():
    try:
        text = open(path).read()
    except OSError:
        bad.append(f"{path}: missing")
        continue
    vals = re.findall(r'"version"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)"', text)
    if not vals:
        bad.append(f"{path}: no version field")
    for got in vals:
        if got != want:
            bad.append(f"{path}: {got} != {want}")
print("; ".join(bad))
PYEOF
)
check "version manifests consistent — 10 carriers on $V_MAIN / $V_LOCK lockstep" "[ -z \"\$version_drift\" ]"
if [ -n "$version_drift" ]; then echo "      drift: $version_drift"; fi

# ── Evidence JSONL doctrine examples must parse ───────────────────────
# finish-work shipped `{"ts","phase":"ship",...}` — invalid JSON that
# stats.sh's fail-open reader silently dropped, making the doctrine's own
# ship rows unreachable in `make stats`. Substitute <placeholders> with 0
# (valid in quoted AND unquoted positions) and json-parse every example.
JSONL_BAD=$(python3 - <<'PYEOF'
import glob, json, re
bad = []
for path in sorted(glob.glob("core/skills/**/SKILL.md", recursive=True)):
    for i, line in enumerate(open(path, encoding="utf-8"), 1):
        for m in re.finditer(r'\{"ts"[^`]*?\}', line):
            lit = re.sub(r"<[^>]*>", "0", m.group(0))
            try:
                json.loads(lit)
            except json.JSONDecodeError:
                bad.append(f"{path}:{i}")
print("; ".join(bad))
PYEOF
)
check "evidence JSONL examples in skills parse as JSON" "[ -z \"\$JSONL_BAD\" ]"
if [ -n "$JSONL_BAD" ]; then echo "      invalid: $JSONL_BAD"; fi

# ── Model tier — every overlay carries a valid tier, and Claude / Codex /
# agy agree per agent (frontmatter is what render reads). This is the one
# owner of the 4-type tiers (rolepod-scout cheap, the other three balanced; no
# type is strong — the Lead passes a strong model per call) — the agreement
# loop carries the Claude overlay's tier to Codex / agy, so a divergent tier
# on any one CLI fails here.
if python3 - <<'PYEOF' 2>&1
import sys, pathlib, re

TIERS = ("cheap", "balanced", "strong")
claude_d = pathlib.Path("adapters/claude/agent-frontmatter")
codex_d = pathlib.Path("adapters/codex/agent-frontmatter")
antigravity_d = pathlib.Path("adapters/antigravity/agent-frontmatter")

def tier_of(path):
    if not path.exists(): return None
    m = re.search(r'^tier:\s*(\S+)', path.read_text(), re.M)
    return m.group(1) if m else None

errs = []
agents = sorted(p.stem for p in claude_d.glob("*.yml"))
if not agents:
    errs.append("no Claude agent frontmatter found")
for a in agents:
    exp = tier_of(claude_d / f"{a}.yml")
    if exp not in TIERS:
        errs.append(f"{a}: claude tier {exp!r} not one of {TIERS}")
        continue
    for label, d in (("codex", codex_d), ("agy", antigravity_d)):
        got = tier_of(d / f"{a}.yml")
        if got != exp:
            errs.append(f"{a}: {label} tier {got} != claude {exp}")

if agents != ["rolepod-builder", "rolepod-qa", "rolepod-reviewer", "rolepod-scout"]:
    errs.append(f"expected exactly the 4 types, found {agents}")
for a, want in (("rolepod-builder", "balanced"), ("rolepod-reviewer", "balanced"), ("rolepod-qa", "balanced"), ("rolepod-scout", "cheap")):
    got = tier_of(claude_d / f"{a}.yml")
    if got != want:
        errs.append(f"{a}: claude tier {got!r} != {want}")

for e in errs: print("      " + e)
sys.exit(1 if errs else 0)
PYEOF
then
  echo "  ✓ model tier: every overlay carries a valid tier; Claude/Codex/agy agree per agent; the 4 types balanced, rolepod-scout cheap"
else
  echo "  ✗ model tier drift across overlays (see above)"
  fail=$((fail+1))
fi

# ── Generated Codex agent TOML — must be valid TOML ───────────────────
# Codex agents are generated (merge-agent.py → build/rendered/codex/agents/)
# from core/agents bodies. A malformed developer_instructions multiline
# string would only surface as a TOML parse error here.
if python3 - <<'PYEOF' 2>&1
import pathlib, tomllib, sys
errs = []
toml = sorted(pathlib.Path("build/rendered/codex/agents").glob("*.toml"))
if len(toml) != 4:
    errs.append(f"expected 4 rendered codex agent TOMLs, found {len(toml)}")
for f in toml:
    try:
        tomllib.load(open(f, "rb"))
    except Exception as e:
        errs.append(f"{f.name}: {e}")
for e in errs:
    print("      " + e)
sys.exit(1 if errs else 0)
PYEOF
then
  echo "  ✓ 4 generated Codex agent TOMLs parse valid"
else
  echo "  ✗ generated Codex agent TOML invalid (see above)"
  fail=$((fail+1))
fi

# ── Competitor brand scrub ─────────────────────────────────────────────
# Allowed: nothing. system files, entry docs, rendered output all clean.
BRAND_LEAKS=$(grep -rl -i "superpower" --include="*.md" --include="*.tmpl" --include="*.yml" . 2>/dev/null | grep -v "^./build/rendered/" | grep -v "^./.git/" | grep -v "^./brief/" | grep -v "^./docs/rolepod/" || true)
if [ -z "$BRAND_LEAKS" ]; then
  echo "  ✓ no competitor brand refs in source"
else
  echo "  ✗ competitor brand leaked in:"
  echo "$BRAND_LEAKS" | sed 's/^/      /'
  fail=$((fail+1))
fi

# ── Codex agent bundle (v2.75.0) — the manifest has no agents component, so
# the plugin carries agents/rolepod-*.toml + agents/AGENTS.rolepod.md and
# hooks/agent-sync.sh installs them on SessionStart. The block file must
# never be named AGENTS.md.
check "codex plugin bundles AGENTS.rolepod.md, never a file named AGENTS.md" \
  "cmp -s build/rendered/codex/AGENTS.md plugins/rolepod-codex/agents/AGENTS.rolepod.md && ! find plugins/rolepod-codex -name AGENTS.md | grep -q ."
AS_EVENTS=$(python3 -c "import json;d=json.load(open('adapters/codex/plugins/rolepod/hooks/hooks.json'));print(','.join(ev for ev,gs in d['hooks'].items() if any('agent-sync.sh' in h['command'] for g in gs for h in g['hooks'])))")
check "codex hooks.json registers agent-sync.sh at SessionStart only" \
  "[ \"\$AS_EVENTS\" = SessionStart ]"

# ── Codex effort pins (v2.74.0 no ultra; v2.75.0 xhigh ceiling) — `ultra` is
# proactive delegation (a fan-out: strong × N children), `max` is above the
# doctrine ceiling. xhigh is the highest effort any role rides on any CLI.
check "no Codex agent overlay pins model_reasoning_effort above xhigh (ultra/max)" \
  "! grep -lE 'model_reasoning_effort: (ultra|max)' adapters/codex/agent-frontmatter/*.yml"

# ── Fence-text parity (plan-fence contract, Round-3) — plan-lint.sh's
# FENCE_AWK and ticket.sh's FENCE_FN carry the same canonical awk fence
# text byte-identical (only the enclosing shell variable's name may
# differ); no shared lib across scripts, so this is the one drift guard.
FENCE_PL=$(sed -n '/^function leadspaces/,/^function fence_open_line/p' core/skills/write-plan/scripts/plan-lint.sh)
FENCE_TK=$(sed -n '/^function leadspaces/,/^function fence_open_line/p' core/skills/implement-plan/scripts/ticket.sh)
check "plan-lint.sh and ticket.sh carry byte-identical awk fence text" \
  '[ -n "$FENCE_PL" ] && [ "$FENCE_PL" = "$FENCE_TK" ]'

# ── Review-set parity (C61 / C62) — core/fragments/review-set.md and the cell
# plan-lint.sh --review-set prints must name the same depth and class per mode x
# tier. Token checks only, never a sentence pin. The fragment is read once; its
# Lite / Standard / Full segments are cut at "Standard:" and "Full:". A cell run
# with no --match names no specialist at R2, so the R2 specialist wording
# ("a matched row adds that role") is read from the fragment segment, R3 from the cell too.
RS_FRAG=$(cat core/fragments/review-set.md)
RS_LITE=${RS_FRAG%%Standard:*}
RS_REST=${RS_FRAG#*Standard:}
RS_STD=${RS_REST%%Full:*}
RS_FULL=${RS_REST#*Full:}
RS_HOME=$(mktemp -d)
has_all() { # $1 = text, $2.. = tokens that must all appear
  local t="$1" k; shift
  for k in "$@"; do case "$t" in *"$k"*) ;; *) return 1 ;; esac; done
}
has_none() { # $1 = text, $2.. = tokens that must not appear
  local t="$1" k; shift
  for k in "$@"; do case "$t" in *"$k"*) return 1 ;; esac; done
}
rs_ok=0
for mode in lite standard full; do
  for tier in R2 R3 R4; do
    out=$(HOME="$RS_HOME" ROLEPOD_SESSION_MODE=$mode ROLEPOD_SESSION_SOURCE=default bash core/skills/write-plan/scripts/plan-lint.sh --review-set --tier $tier 2>/dev/null || true)
    ok=1
    has_all "$out" 'lens: spec' 'lens: standards' || ok=0
    case "$mode $tier" in
      "lite "*)
        has_all "$out" 'rolepod-reviewer' || ok=0
        has_none "$out" 'universal-reviewer' 'lens: security' 'adversarial' 'lens: perf' || ok=0
        has_none "$RS_LITE" 'lens: security' 'adversarial' 'depth:' || ok=0 ;;
      "standard R2"|"full R2")
        has_none "$out" 'lens: security' 'adversarial' || ok=0
        has_all "$RS_STD" 'R2 / R3 the two lenses + each matched lens' || ok=0 ;;
      "standard R3"|"full R3")
        has_all "$out" 'lens: perf' 'lens: ui' 'lens: arch' || ok=0
        has_none "$out" 'lens: security' 'adversarial' || ok=0
        has_all "$RS_STD" 'each matched lens' || ok=0 ;;
      "standard R4")
        has_all "$out" 'lens: security' 'depth: checklist' 'security-review/SKILL.md' || ok=0
        has_none "$out" 'adversarial' 'depth: full' || ok=0
        has_all "$RS_STD" 'lens: security' 'depth: checklist' || ok=0
        has_none "$RS_STD" 'adversarial' 'depth: full' || ok=0 ;;
      "full R4")
        has_all "$out" 'lens: security' 'depth: full' 'lens: adversarial' 'adversarial-review/SKILL.md' || ok=0
        has_none "$out" 'depth: checklist' || ok=0
        has_all "$RS_FULL" 'depth: full' 'adversarial' || ok=0
        has_none "$RS_FULL" 'depth: checklist' || ok=0 ;;
    esac
    [ "$ok" -eq 1 ] && rs_ok=$((rs_ok + 1))
    check "review-set cell $mode $tier: fragment and plan-lint --review-set agree" "[ $ok -eq 1 ]"
  done
done
rm -rf "$RS_HOME"
echo "review-set parity: $rs_ok/9"
check "review-set parity: 9/9" "[ $rs_ok -eq 9 ]"

# ── High-risk regex parity — the copy path-verdicts.sh does not run ──
# The canonical ERE is owned by tests/static/path-verdicts.sh (edit /
# commit-time classifiers). No adapter carries its own edit-time copy any
# more: Cursor's and agy's only hook left is the commit-gate translator,
# which shells out to the shared hooks/precommit-gate.sh (spec Desired 10,
# 2026-09-25); the retired Gemini CLI adapter (removed v2.177.0) was the
# last one with a local wide-prefix string pin — nothing to check here now.

# ── no dispatch-mechanism text in core/ (spec actor-rebuild criterion 9) ──
check "core/ holds no dispatch-mechanism text (run_in_background, Foreground only, WAITING:, Report in:, CLAUDE_CODE_ENTRYPOINT)" "! /usr/bin/grep -rqE 'run_in_background|Foreground only|WAITING:|Report in:|CLAUDE_CODE_ENTRYPOINT' core/"
# Spec actor-rebuild NM1: the run-* names became orchestrating-plans,
# convening-code-review and coordinating-parallel-tracks; no payload names the old ones.
check "payload names no run-plan / run-review / run-tracks (NM1)" "! /usr/bin/grep -rqE '\\brun-(plan|review|tracks)\\b' core/ hooks/ adapters/"

# ── actor-rebuild T3: agent-protocol retired, fragment loads, read-only role shape ──
check "agent-protocol fragment gone and unnamed" "[ -d core/fragments ] && [ -d adapters ] && [ -f build/merge-agent.py ] && [ ! -e core/fragments/agent-protocol.md ] && ! /usr/bin/grep -rq --exclude-dir=__pycache__ --exclude='*.pyc' 'agent-protocol' core build/merge-agent.py adapters"
check "no Remembered notes left (OD13)" "[ -d core ] && [ -d adapters ] && ! /usr/bin/grep -rq 'Remembered notes' core adapters"

# Count a fragment's INCLUDE lines per role (exact line, once for shared-posture and agent-core).
inc() { /usr/bin/grep -cx "{{INCLUDE: core/fragments/$2.md}}" "core/agents/$1.md"; }
ROLES=$(cd core/agents && ls *.md | sed 's/\.md$//')
READONLY="rolepod-reviewer rolepod-scout"
role_n=0; core_ok=1; writer_ok=1; revcore_ok=1
for r in $ROLES; do
  role_n=$((role_n + 1))
  [ "$(inc $r shared-posture)" -eq 1 ] && [ "$(inc $r agent-core)" -eq 1 ] || core_ok=0
  want=1; case " $READONLY " in *" $r "*) want=0 ;; esac
  [ "$(inc $r writer-core)" -eq $want ] || writer_ok=0
  want=0; case "$r" in rolepod-reviewer) want=1 ;; esac
  [ "$(inc $r reviewer-core)" -eq $want ] || revcore_ok=0
done
check "4 types under core/agents, named rolepod-*" "[ $role_n -eq 4 ] && [ -f core/agents/rolepod-builder.md ] && [ -f core/agents/rolepod-reviewer.md ] && [ -f core/agents/rolepod-qa.md ] && [ -f core/agents/rolepod-scout.md ]"
check "every role loads shared-posture and agent-core exactly once" "[ $core_ok -eq 1 ]"
check "writer-core in exactly rolepod-builder and rolepod-qa (not rolepod-reviewer, rolepod-scout)" "[ $writer_ok -eq 1 ]"
check "reviewer-core in exactly rolepod-reviewer" "[ $revcore_ok -eq 1 ]"
check "specialist-review fragment is gone and unnamed under core/ build/ adapters/" "[ ! -e core/fragments/specialist-review.md ] && ! /usr/bin/grep -rq --exclude-dir=__pycache__ --exclude='*.pyc' 'specialist-review' core build/merge-agent.py build/render.sh adapters"
check "rolepod-builder carries the five irreversible-action lines (C2) and its domain tag rule" "[ \"\$(/usr/bin/grep -cE '^- (A secret, token or credential never lands in code, logs, fixtures or responses\\.|An auth, session, token or permission flow the brief leaves open → BLOCKED\\.|A paid provider, model or price change, or a public API / schema contract change, that the brief does not name → BLOCKED\\.|Anything that reaches outside the repo and that the brief does not state → BLOCKED: a production deploy, a feature-flag default, a freeze window, or a message, email or webhook to real users\\.|Deleting data, or a destructive schema change, without the brief.s explicit yes → BLOCKED\\.)\$' core/agents/rolepod-builder.md)\" -eq 5 ] && /usr/bin/grep -q 'architecture' core/agents/rolepod-builder.md && /usr/bin/grep -q 'writing' core/agents/rolepod-builder.md"
check "rolepod-qa carries the test-files-only line (C3) and INCLUDEs ui-observe and test-quality once each" "/usr/bin/grep -qF -- '- test files only; product code that needs a change → a finding for the owner' core/agents/rolepod-qa.md && [ \"\$(inc rolepod-qa ui-observe)\" -eq 1 ] && [ \"\$(inc rolepod-qa test-quality)\" -eq 1 ]"
check "rolepod-reviewer names its seven lenses and loads no report template" "/usr/bin/grep -q 'spec.*standards.*security.*adversarial.*perf.*ui.*arch' core/agents/rolepod-reviewer.md && ! /usr/bin/grep -q 'review-report' core/agents/rolepod-reviewer.md"
check "rendered size budgets: builder <= 7900, reviewer <= 7700, scout <= 6725 (task 1 notes)" "python3 -c \"import sys; b={'rolepod-builder':7900,'rolepod-reviewer':7700,'rolepod-scout':6725}; sys.exit(any(len(open('plugins/rolepod/agents/%s.md'%n).read())>m for n,m in b.items()))\""

C77_HEADINGS=$'## Role & Identity\n## Skill Mapping\n## Persona & Tone\n## Constraints & Guardrails'
ro_head=1; ro_test=1; ro_mode=1; ro_set=1
for r in $ROLES; do
  f="core/agents/$r.md"
  [ "$(/usr/bin/grep -E '^## ' "$f" | /usr/bin/grep -vx '## Objective & Focus')" = "$C77_HEADINGS" ] || ro_head=0
  # top-level cards only (`^- \*\*`); nested smell bullets are not cards
  [ "$(awk '/^## /{s=($0=="## Objective & Focus")} s&&/^- \*\*/{c++; if(/Test:/)t++} END{print (c==t) ? "ok" : "bad"}' "$f")" = ok ] || ro_test=0
  ! /usr/bin/grep -qE '\b(Lite|Standard|Full)\b|`lite\|standard\|full` mode|review mode|workflow mode' "$f" || ro_mode=0
  ! /usr/bin/grep -qE 'lens: spec.*lens: standards|lens: standards.*lens: spec|Review set' "$f" || ro_set=0
done
check "every type: the ## headings equal C77 in order (Objective & Focus optional)" "[ $ro_head -eq 1 ]"
check "every role: every top-level Objective & Focus card contains Test:" "[ $ro_test -eq 1 ]"
check "every role: no workflow mode name" "[ $ro_mode -eq 1 ]"
check "every role: no review-set line" "[ $ro_set -eq 1 ]"
check "rolepod-scout never blocks and has no Skill grant (OD8)" "[ -f core/agents/rolepod-scout.md ] && [ -f adapters/claude/agent-frontmatter/rolepod-scout.yml ] && ! /usr/bin/grep -q BLOCKED core/agents/rolepod-scout.md && ! /usr/bin/grep -qx '  - Skill' adapters/claude/agent-frontmatter/rolepod-scout.yml"
check "FW1 a: every gh pr merge line carries --match-head-commit" "/usr/bin/grep -rq 'gh pr merge' core/skills && ! /usr/bin/grep -rn 'gh pr merge' core/skills |/usr/bin/grep -v -- '--match-head-commit'"
check "FW1 b: finish-menu has the Rulings made block" "/usr/bin/grep -qx '## Rulings made' core/skills/finish-work/templates/finish-menu.md"
check "FW1 c: no thread reply sends its body inline (-f body=\")" "! /usr/bin/grep -rqF -- '-f body=\"' core/skills"
check "rolepod-reviewer: no Agent / SendMessage / Skill grant on Claude" "! /usr/bin/grep -qxE '  - (Agent|SendMessage|Skill)' adapters/claude/agent-frontmatter/rolepod-reviewer.yml"
check "security-review keeps SR1 and SR2" "/usr/bin/grep -qF 'Trust follows who wrote a value, not which channel delivered it.' core/skills/security-review/SKILL.md && /usr/bin/grep -qF 'a finding with no scenario is MINOR' core/skills/security-review/SKILL.md"
check "adversarial-review holds no orderer text and one stance heading" "[ \"$(/usr/bin/grep -c '^## Reviewer stance$' core/skills/adversarial-review/SKILL.md)\" -eq 1 ] && ! /usr/bin/grep -qE 'four sections|Pick the rung|Cross-model|mode: adversarial|vertical fallback|pool routing' core/skills/adversarial-review/SKILL.md"

# ── Grants (actor rebuild T4b): a role's Skill Mapping is the one home of its skills ──
# merge-agent reads `## Skill Mapping` of core/agents/<role>.md: "the `x` skill" in a
# sentence saying "preloaded" is a preload (Claude `skills:`, Codex inline), any other
# backticked skill is a call (Claude `Skill` tool). PRELOAD_PAIRS = the preload roles.
PRELOAD_PAIRS="rolepod-reviewer:review-code rolepod-builder:implement-plan rolepod-qa:implement-plan"
if python3 - <<'PYEOF' 2>&1
import pathlib, shutil, subprocess, sys, tempfile

errs = []
root = pathlib.Path(tempfile.mkdtemp(prefix="rolepod-preload-fixture."))
try:
    (root / "build").mkdir()
    shutil.copy("build/merge-agent.py", root / "build" / "merge-agent.py")
    def put(rel, text):
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
    put("core/skills/demo/SKILL.md",
        "---\nname: demo\ndescription: The demo reviewer's method.\n---\n\n# Demo method\n\nSENTINEL-DEMO-LINE\n\n{{INCLUDE: core/fragments/frag.md}}\n")
    put("core/skills/demo2/SKILL.md", "---\nname: demo2\ndescription: A called helper.\n---\n\nDemo2.\n")
    put("core/fragments/frag.md", "Fragment line.\n")
    put("core/skills/manual/SKILL.md",
        "---\nname: manual\ndescription: Manual only.\ndisable-model-invocation: true\n---\n\nManual.\n")
    put("core/skills/manualq/SKILL.md",
        "---\nname: manualq\ndescription: Manual only, quoted.\ndisable-model-invocation: \"true\"\n---\n\nManual.\n")
    put("core/skills/manualsq/SKILL.md",
        "---\nname: manualsq\ndescription: Manual only, single-quoted.\ndisable-model-invocation: 'true'\n---\n\nManual.\n")
    put("adapters/codex/agent-frontmatter/demo-role.yml",
        "tier: balanced\nmodel_reasoning_effort: high\nsandbox_mode: read-only\n")
    put("adapters/antigravity/agent-frontmatter/demo-role.yml", "tier: balanced\n")

    def role(mapping, tools=("Read",), extra=""):
        put("core/agents/demo-role.md",
            '---\nname: demo-role\ndescription: "Demo role."\ncolor: red\n---\n## Role & Identity\n\nDemo body.\n'
            + ("\n## Skill Mapping\n\n%s\n" % mapping if mapping is not None else "")
            + "\n## Persona & Tone\n\nTerse; `nope` here sits outside the mapping.\n")
        put("adapters/claude/agent-frontmatter/demo-role.yml",
            "tier: balanced\neffort: high\n"
            + ("tools:\n" + "".join("  - %s\n" % t for t in tools) if tools is not None else "") + extra)
    PRE = "Your procedure is the `demo` skill, preloaded into your context when you start."
    CALL = "Your procedure is the `demo` skill: load it with your CLI's skill tool. It calls `demo2` for a seam."

    def run(target, *extra):
        r = subprocess.run([sys.executable, str(root / "build" / "merge-agent.py"),
                            "--target=" + target, "--name=demo-role", *extra],
                           capture_output=True, text=True)
        return r.returncode, r.stdout, r.stderr

    role(PRE)
    rc, out, _ = run("claude", "--preload=native")
    fm = out.split("\n---\n", 1)[0]
    if rc or "\nskills:\n  - rolepod:demo" not in fm:
        errs.append("claude: a preload mapping not emitted as '  - rolepod:demo'")
    if "  - Skill" in fm:
        errs.append("claude: a preload-only role must get no Skill tool")
    if "SENTINEL-DEMO-LINE" in out:
        errs.append("claude: native preload must not inline the skill")
    rc, out, _ = run("codex", "--preload=inline")
    if rc or '<preloaded_skill name="demo">\n# Demo method' not in out or "Fragment line.\n</preloaded_skill>" not in out:
        errs.append("codex: skill body not inlined (frontmatter off, INCLUDE resolved)")
    if "disable-model-invocation" in out or "name: demo" in out:
        errs.append("codex: skill frontmatter leaked into the role")
    for t in ("cursor", "opencode", "antigravity"):
        rc, out, _ = run(t, "--preload=none")
        if rc or "SENTINEL-DEMO-LINE" in out or "skills:" in out:
            errs.append("%s: mode none must emit nothing of the skill" % t)
        rc, out, _ = run(t, "--preload=inline")
        if rc or '<preloaded_skill name="demo">' not in out:
            errs.append("%s: mode inline must append the skill body" % t)
    rc, out, _ = run("claude", "--preload=inline")
    if rc or "\nskills:" in out or "SENTINEL-DEMO-LINE" not in out:
        errs.append("--preload=inline on claude: skills key stays or body missing")
    rc, out, err = run("antigravity", "--preload=native")
    if rc == 0:
        errs.append("a native preload with no per-CLI form must fail the render")
    role(CALL, tools=("Read", "mcp__x"))
    rc, out, _ = run("claude")
    fm = out.split("\n---\n", 1)[0] + "\n"
    if rc or "\ntools:\n  - Read\n  - Skill\n  - mcp__x\n" not in fm or "skills:" in fm:
        errs.append("claude: a call mapping must insert '  - Skill' before the first mcp__ entry, no skills:")
    rc, out, _ = run("codex")
    if rc or "<preloaded_skill" in out:
        errs.append("codex: a call mapping must inline nothing")
    role(CALL)
    rc, out, _ = run("claude")
    if rc or not out.split("\n---\n", 1)[0].endswith("\ntools:\n  - Read\n  - Skill"):
        errs.append("claude: a call mapping with no mcp__ entry must append '  - Skill'")
    for mapping, kw, why in (
            (PRE + " It calls `demo2` for a seam.", {}, "a role mapping both preload and call"),
            (PRE, {"extra": "skills:\n  - demo\n"}, "an overlay skills: block"),
            (PRE, {"extra": "skills: [demo]\n"}, "an overlay flow-style skills:"),
            (CALL, {"tools": ("Read", "Skill")}, "an overlay Skill line"),
            (PRE, {"tools": ("Read", "Skill  # stale")}, "an overlay Skill line with a comment"),
            (PRE, {"tools": None, "extra": "tools: [Read, Skill]\n"}, "an overlay flow-style tools:"),
            (CALL, {"tools": None}, "a mapped skill with no overlay tools: list"),
            (None, {}, "a role with no Skill Mapping section"),
            ("Your procedure is the `nope` skill: load it.", {}, "a missing mapped skill"),
            ("Your procedure is the `manual` skill: load it.", {}, "a disable-model-invocation skill"),
            ("Your procedure is the `manualq` skill: load it.", {}, "a quoted disable-model-invocation skill"),
            ("Your procedure is the `manualsq` skill: load it.", {}, "a single-quoted disable-model-invocation skill")):
        role(mapping, **kw)
        for t in ("claude", "cursor"):
            rc, _, _ = run(t, "--preload=none")
            if rc == 0:
                errs.append("%s: %s must fail the render" % (t, why))
    role("No `Skill` tool and no manual to load: this file is your whole method.", extra="omitClaudeMd: true\n")
    rc, out, _ = run("claude", "--preload=native")
    if rc or "\nomitClaudeMd: true\n" not in out.split("\n---\n", 1)[0] + "\n":
        errs.append("omitClaudeMd missing from render: an overlay key must reach the Claude frontmatter")
    role("No `Skill` tool and no manual to load: this file is your whole method.")
    rc, out, _ = run("claude", "--preload=native")
    if rc or "omitClaudeMd" in out.split("\n---\n", 1)[0]:
        errs.append("omitClaudeMd rendered with no overlay key")
    fm = out.split("\n---\n", 1)[0]
    if rc or "skills:" in fm or "  - Skill" in fm:
        errs.append("a role naming no skill must render with no skills key and no Skill tool")
finally:
    shutil.rmtree(root, ignore_errors=True)
for e in errs:
    print("      " + e)
sys.exit(1 if errs else 0)
PYEOF
then
  echo "  ✓ grant mechanism (fixture): Skill Mapping → preload (native / inline / none) or Skill tool; an overlay grant, both kinds, a missing or manual-invoke skill fails the render"
else
  echo "  ✗ grant mechanism (fixture, see above)"
  fail=$((fail+1))
fi
if python3 - "$PRELOAD_PAIRS" <<'PYEOF' 2>&1
import pathlib, re, sys

import importlib.util, json
spec = importlib.util.spec_from_file_location("merge_agent", "build/merge-agent.py")
ma = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ma)
mode = ma.PRELOAD_MODE
if json.load(open("adapters/claude/.claude-plugin/plugin.json"))["name"] + ":" != ma.CLAUDE_SKILL_PREFIX:
    print("      CLAUDE_SKILL_PREFIX is not the Claude plugin name")
    sys.exit(1)
want = dict(p.split(":") for p in sys.argv[1].split())
errs = []

def items(text, key):
    m = re.search(r"^%s:\n((?:  - .*\n?)+)" % key, text + "\n", re.M)
    return [l[4:].strip() for l in m.group(1).splitlines()] if m else []

claude = {p.stem: p.read_text() for p in pathlib.Path("adapters/claude/agent-frontmatter").glob("*.yml")}
for role in sorted(want):
    if role not in claude:
        errs.append("%s: no Claude overlay" % role)
for role, text in sorted(claude.items()):
    sk, call = ma.mapped_skills(role)
    exp = [want[role]] if role in want else []
    if sk != exp:
        errs.append("%s: preload %s, expected %s" % (role, sk or "none", exp or "none"))
    # The mapping's own Tools: line names Skill exactly when the role calls a skill.
    sm = ma.SKILL_MAPPING_RE.search(pathlib.Path("core/agents/%s.md" % role).read_text())
    tl = re.search(r"\bTools: ([^\n]*)", sm.group(1)) if sm else None
    if not tl or ("Skill" in re.findall(r"\w+", tl.group(1))) != bool(call):
        errs.append("%s: Skill Mapping Tools: line disagrees with its call skills %s" % (role, call or "none"))
    for s in sk + call:
        f = pathlib.Path("core/skills") / s / "SKILL.md"
        if not f.exists():
            errs.append("%s: mapped %s has no core/skills/%s/SKILL.md" % (role, s, s))
        elif re.search(r"^disable-model-invocation:\s*[\"']?true", f.read_text().split("\n---\n", 1)[0], re.M):
            errs.append("%s: mapped %s sets disable-model-invocation" % (role, s))
    rendered = {
        "claude": "plugins/rolepod/agents/%s.md" % role,
        "codex": "build/rendered/codex/agents/%s.toml" % role,
        "antigravity": "build/rendered/antigravity/plugin/agents/%s.md" % role,
        "cursor": "plugins/rolepod-cursor/agents/%s.md" % role,
        "opencode": "build/rendered/opencode/agents/%s.md" % role,
    }
    for target, path in rendered.items():
        text = pathlib.Path(path).read_text()
        inl = re.findall(r'^<preloaded_skill name="([^"]+)">$', text, re.M)
        nat = items(text.split("\n---\n", 1)[0] + "\n", "skills") if target in ("claude", "antigravity") else []
        if mode[target] == "native":
            if nat != [ma.NATIVE_SKILL_REF[target](s) for s in sk] or inl:
                errs.append("%s: %s native preload %s, expected %s" % (role, target, nat or "none", sk or "none"))
        elif mode[target] == "inline":
            if inl != sk or nat:
                errs.append("%s: %s inline skills %s, expected %s" % (role, target, inl or "none", sk or "none"))
        elif inl or nat:
            errs.append("%s: %s carries a preload but its mode is none" % (role, target))
        fm = text.split("\n---\n", 1)[0] + "\n" if target != "codex" else ""
        if target == "claude":
            if ("Skill" in items(fm, "tools")) != bool(call):
                errs.append("%s: claude Skill tool %s, call skills %s" % (role, "Skill" in items(fm, "tools"), call or "none"))
        elif re.search(r"^(tools|skills):", fm, re.M):
            errs.append("%s: %s frontmatter carries a tools / skills grant" % (role, target))
for cli in ("claude", "codex", "antigravity"):
    for p in sorted(pathlib.Path("adapters/%s/agent-frontmatter" % cli).glob("*.yml")):
        t = p.read_text()
        if re.search(r"^skills:", t, re.M) or re.search(r"^\s+- Skill\s*(#.*)?$|^tools:.*\bSkill\b", t, re.M):
            errs.append("%s: a skills: / Skill grant in an overlay (the Skill Mapping is its home)" % p)
for e in errs:
    print("      " + e)
sys.exit(1 if errs else 0)
PYEOF
then
  echo "  ✓ grants: every CLI's render matches the Skill Mapping — the named roles preload (by PRELOAD_MODE), Claude Skill tool iff a call skill, no overlay grant"
else
  echo "  ✗ grant tree (see above)"
  fail=$((fail+1))
fi

# ── actor-rebuild T4a reviewer skills ──
check "review-report is a fragment and the review-code template is gone" "[ -f core/fragments/review-report.md ] && [ ! -e core/skills/review-code/templates/review-report.md ]"
check "review-report fragment holds no orderer-only field and carries BLOCKED" "! /usr/bin/grep -qE '^## Reviewers|Lite isolation|Cross-model adversarial' core/fragments/review-report.md && /usr/bin/grep -q BLOCKED core/fragments/review-report.md"
check "review-code description starts with the performer (OD5)" "/usr/bin/grep -q '^description: The reviewer' core/skills/review-code/SKILL.md"
check "review-code holds no orderer step" "! /usr/bin/grep -qE '^### [0-9]+[.] (Freeze the diff|Pick reviewers|Run the round|Fix-verify rounds|Author response)' core/skills/review-code/SKILL.md"
check "review-code INCLUDEs the report and test-quality fragments once each" "[ \"$(/usr/bin/grep -cx '{{INCLUDE: core/fragments/review-report.md}}' core/skills/review-code/SKILL.md)\" -eq 1 ] && [ \"$(/usr/bin/grep -cx '{{INCLUDE: core/fragments/test-quality.md}}' core/skills/review-code/SKILL.md)\" -eq 1 ]"
check "scout renders omitClaudeMd: true on Claude (role-reduction s1, spike-proven)" "/usr/bin/grep -qx 'omitClaudeMd: true' plugins/rolepod/agents/rolepod-scout.md"
check "rolepod-reviewer loads no report template (its method is preloaded)" "! /usr/bin/grep -q 'review-report' core/agents/rolepod-reviewer.md"

# ── actor-rebuild T4b owner skill ──
check "implement-plan description starts with the performer (OD5)" "/usr/bin/grep -q \"^description: The owner's build procedure\" core/skills/implement-plan/SKILL.md"
check "implement-plan holds no Lead step and its Lead files are gone (D#10)" "! /usr/bin/grep -qE '^### [0-9]+[.] (Lint the plan|Brief each ready task|Accept and integrate|Review at its seam|Tracks|Final branch review)' core/skills/implement-plan/SKILL.md && [ ! -e core/skills/implement-plan/references/subagent-dispatch.md ] && [ ! -e core/skills/implement-plan/templates/implementation-manifest.md ]"
check "implement-plan INCLUDEs gates-f1-f5 once; F3 leaves the whole suite to the Lead (OD15)" "[ \"$(/usr/bin/grep -cx '{{INCLUDE: core/fragments/gates-f1-f5.md}}' core/skills/implement-plan/SKILL.md)\" -eq 1 ] && /usr/bin/grep -q 'once per release, by the Lead' core/fragments/gates-f1-f5.md"
check "tdd-flow INCLUDEs test-quality once and holds no copy of it (TD1)" "[ \"$(/usr/bin/grep -cx '{{INCLUDE: core/fragments/test-quality.md}}' core/skills/tdd-flow/SKILL.md)\" -eq 1 ] && ! /usr/bin/grep -qiE 'frozen .now.|modifying an existing test' core/skills/tdd-flow/SKILL.md"
# ui-observe: only rolepod-qa INCLUDEs it, once (T4-16, VR1; ui-ux-designer folded into the builder).
UIO='{{INCLUDE: core/fragments/ui-observe.md}}'
check "ui-observe fragment INCLUDEd only by rolepod-qa, exactly once (T4-16)" "[ -f core/fragments/ui-observe.md ] && [ -z \"\$(/usr/bin/grep -rlxF '$UIO' core adapters | /usr/bin/grep -vxE 'core/agents/rolepod-qa\.md')\" ] && [ \"\$(/usr/bin/grep -cxF '$UIO' core/agents/rolepod-qa.md)\" -eq 1 ]"
# writer-loop and report-economy dissolved into implement-plan and writer-core (B1, T4-16).
check "writer-loop and report-economy fragments gone and unnamed (B1)" "[ -d core/fragments ] && [ -d adapters ] && [ -f build/merge-agent.py ] && [ ! -e core/fragments/writer-loop.md ] && [ ! -e core/fragments/report-economy.md ] && ! /usr/bin/grep -rqE --exclude-dir=__pycache__ --exclude='*.pyc' 'writer-loop|report-economy|Writer loop' core build/merge-agent.py adapters"

echo ""
if [ $fail -eq 0 ]; then
  echo "lean-surface: pass"
  exit 0
fi
echo "lean-surface: $fail failure(s)"
exit 1
