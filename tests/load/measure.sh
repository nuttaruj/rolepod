#!/usr/bin/env bash
# tests/load/measure.sh — per-reader load (python len, UTF-8 chars) of the rendered payload.
#
# Prints TSV `reader<TAB>artifact<TAB>chars`, no header, sorted by reader then artifact.
# Not part of `make test`: a measuring tool, run by hand or by a growth lock.
#
#   tests/load/measure.sh [--mode lite|standard|full] [--plan <plan.md> [--contract <contract.md>]]...
#   --contract applies to the --plan right before it; --mode defaults to lite
#   (passed to plan-lint as ROLEPOD_SESSION_MODE; session-start always runs at the default mode, lite,
#   in a throwaway repo under a fresh HOME). Needs `make render` first.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
usage() { echo "usage: tests/load/measure.sh [--mode lite|standard|full] [--loads] [--plan <plan.md> [--contract <contract.md>]]..." >&2; exit 2; }
mode=lite; loads=0; plans=(); contracts=()
while [ $# -gt 0 ]; do
  case "$1" in
    --loads) loads=1; shift ;;
    --mode) [ $# -ge 2 ] || usage; mode="$2"; shift 2 ;;
    --plan) [ $# -ge 2 ] || usage; plans+=("$2"); contracts+=(""); shift 2 ;;
    --contract) [ $# -ge 2 ] && [ ${#plans[@]} -gt 0 ] || usage; contracts[$((${#plans[@]}-1))]="$2"; shift 2 ;;
    *) usage ;;
  esac
done
case "$mode" in lite|standard|full) ;; *) usage ;; esac
for f in plugins/rolepod/hooks/session-start.sh plugins/rolepod/hooks/always-on-core.md plugins/rolepod/skills/using-rolepod/SKILL.md \
         build/rendered/codex/AGENTS.md build/rendered/antigravity/AGENTS.md build/rendered/opencode/AGENTS.md \
         plugins/rolepod-cursor/rules/always-on-core.mdc; do
  [ -f "$f" ] || { echo "missing rendered file: $f (run make render)" >&2; exit 2; }
done
home=$(mktemp -d); briefs=$(mktemp); trap 'rm -rf "$home" "$briefs"' EXIT
# Hermetic inputs: a fresh HOME (no user config, lock or cross-family pool) and a throwaway one-commit repo as the
# project, so session-start (git activity, project config) and plan-lint do not depend on the live tree's state.
# session-start therefore always measures the default mode (lite); --mode only reaches plan-lint.
scratch="$home/proj"; mkdir -p "$scratch"
export GIT_CONFIG_NOSYSTEM=1
HOME="$home" git -C "$scratch" init -q
HOME="$home" git -C "$scratch" symbolic-ref HEAD refs/heads/main
HOME="$home" git -C "$scratch" -c user.name=measure -c user.email=measure@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m "measure fixture"
ss=$(printf '{"cwd":"%s","source":"startup","session_id":"measure"}' "$scratch" | HOME="$home" bash plugins/rolepod/hooks/session-start.sh --cli claude)
export MEASURE_SS="$ss"
# brief tasks: lines "name<TAB>len" per plan task, from plan-lint --brief N (N = 1.. until "Task N not found").
# A brief length is len($(...)): trailing newlines are stripped (1-2 chars below the raw stream).
# Brief rows still print the checkout path (baseroot) and inline predecessor receipts when present (gitignored dir).
i=0
while [ "$i" -lt "${#plans[@]}" ]; do
  p="${plans[$i]}"; c="${contracts[$i]}"; name=$(basename "$p" .md); [ -n "$c" ] && name="$name+contract"
  [ -f "$p" ] || { echo "missing plan: $p" >&2; exit 2; }
  n=1
  while :; do
    err="$home/err"
    if out=$(HOME="$home" ROLEPOD_PROJECT_ROOT="$scratch" ROLEPOD_SESSION_MODE="$mode" ROLEPOD_SESSION_SOURCE=default \
             bash plugins/rolepod/skills/write-plan/scripts/plan-lint.sh --brief "$n" "$p" ${c:+"$c"} --main 2>"$err"); then
      printf '%s\t%s\n' "$name" "$(printf '%s' "$out" | python3 -I -c 'import sys; print(len(sys.stdin.buffer.read().decode("utf-8")))')" >> "$briefs"
      n=$((n+1))
    elif /usr/bin/grep -q "Task $n not found" "$err"; then
      break
    else
      echo "plan-lint --brief $n failed for $p:" >&2; cat "$err" >&2; exit 2
    fi
  done
  [ "$n" -gt 1 ] || { echo "no tasks in plan: $p" >&2; exit 2; }
  i=$((i+1))
done
export MEASURE_LOADS=$loads
python3 -I - "$briefs" <<'PY'
import glob, json, os, re, sys

def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()

def frontmatter(p):
    m = re.match(r"---\n(.*?)\n---\n", read(p), re.S)
    return m.group(1) if m else ""

def fm_scalar(fm, key):
    m = re.search(r"^%s: (.*)$" % key, fm, re.M)
    if not m:
        return ""
    v = m.group(1)
    return json.loads(v) if v.startswith('"') else v

def fm_tools(fm):
    m = re.search(r"^tools:\n((?:  - .*\n?)+)", fm + "\n", re.M)
    return [l[4:].strip() for l in m.group(1).splitlines()] if m else []

S, A = "plugins/rolepod/skills/", "plugins/rolepod/agents/"
rows = {}
def add(reader, artifact, n):
    rows[(reader, artifact)] = n

ss = json.loads(os.environ["MEASURE_SS"])["hookSpecificOutput"]["additionalContext"]
session_start = len(ss)
add("lead", "session-start", session_start)

skill_listing = 0
for f in sorted(glob.glob(S + "*/SKILL.md")):
    fm = frontmatter(f)
    if "disable-model-invocation: true" in fm:
        continue
    skill_listing += len("- rolepod:%s: %s\n" % (os.path.basename(os.path.dirname(f)), fm_scalar(fm, "description")))
add("lead", "skill-listing", skill_listing)

agent_listing = 0
for f in sorted(glob.glob(A + "*.md")):
    fm = frontmatter(f)
    agent_listing += len("- rolepod:%s: %s (Tools: %s)" % (fm_scalar(fm, "name"), fm_scalar(fm, "description"), ", ".join(fm_tools(fm))))
add("lead", "agent-listing", agent_listing)

L = lambda rel: len(read(S + rel))
standing = session_start + skill_listing + L("using-rolepod/SKILL.md")
add("lead", "standing", standing)
add("lead", "session-path", standing + agent_listing + sum(L("%s/SKILL.md" % s) for s in ("write-spec", "write-plan", "orchestrating-plans", "check-work", "finish-work")))
add("lead", "hooks/always-on-core.md", len(read("plugins/rolepod/hooks/always-on-core.md")))

owner_skills = ("tdd-flow", "simplify-code")
both_skills = ('debug-issue', 'implement-plan')
preloaded = {'security-review': ('reviewer',), 'adversarial-review': ('reviewer',), 'review-code': ('reviewer', 'lead')}
author_files = ('review-code/references/receiving-findings.md',)
for f in sorted(glob.glob(S + "**/*.md", recursive=True)):
    rel = f[len(S):]
    n, top = len(read(f)), rel.split("/")[0]
    art = "skills/" + rel
    if rel == top + '/SKILL.md' and top in preloaded:
        for rd in preloaded[top]:
            add(rd, art, n)
    elif rel in author_files:
        add("lead", art, n); add("owner", art, n)
    elif top in owner_skills:
        add("owner", art, n)
    elif top in both_skills:
        add("lead", art, n); add("owner", art, n)
    else:
        add("lead", art, n)

for f in sorted(glob.glob(A + "*.md")):
    role = os.path.basename(f)[:-3]
    n = len(read(f))
    if role == "system-architect":
        add("architect", "agents/%s.md" % role, n)
    elif role in ('universal-reviewer', 'security-engineer', 'adversarial-reviewer', 'rolepod-reviewer'):
        add("reviewer", "agents/%s.md" % role, n)
    elif role in ("scout", "rolepod-scout"):
        add("scout", "agents/%s.md" % role, n)
    else:
        add("owner", "agents/%s.md" % role, n)

# role-reduction s2b: the 4 types replace the 15 roles; a composite reads the type file when it exists,
# else the old role (a commit before the roster swap). A lens dispatch is rolepod-reviewer + review-code
# (preloaded) + the lens skill its brief names.
TYPED = os.path.exists(A + "rolepod-reviewer.md")
agent = lambda new, old: len(read(A + (new if os.path.exists(A + new + ".md") else old) + ".md"))
code_own = agent("rolepod-builder", "backend-developer") + L("implement-plan/SKILL.md") + L("tdd-flow/SKILL.md")
add("owner", "code-writer-own", code_own)
ccr = L('convening-code-review/SKILL.md')
lens = agent("rolepod-reviewer", "universal-reviewer") + L('review-code/SKILL.md')
lite = ccr + 2 * lens
add("review-round", "lite-r4-round1", lite)
sec = (lens if TYPED else len(read(A + "security-engineer.md"))) + L('security-review/SKILL.md')
add("review-round", "standard-r4-round1", lite + sec)

add("cli-codex", "AGENTS.md", len(read("build/rendered/codex/AGENTS.md")))
add("cli-antigravity", "AGENTS.md", len(read("build/rendered/antigravity/AGENTS.md")))
add("cli-opencode", "AGENTS.md", len(read("build/rendered/opencode/AGENTS.md")))
add("cli-cursor", "rules/always-on-core.mdc", len(read("plugins/rolepod-cursor/rules/always-on-core.mdc")))

per = {}
for line in read(sys.argv[1]).splitlines():
    name, n = line.split("\t")
    per.setdefault(name, []).append(int(n))
for name, ns in per.items():
    avg = round(sum(ns) / len(ns))
    add("owner", "brief-avg/" + name, avg)
    add("owner", "brief-max/" + name, max(ns))
    add("owner", "dispatch-own/" + name, code_own + avg)

# --loads: display only (never in the lock; the default output is unchanged). A role file or
# skill that does not exist yet at this commit simply prints no row.
if os.environ.get("MEASURE_LOADS") == "1":
    def size(p):
        return len(read(p)) if os.path.exists(p) else None
    if TYPED:
        pairs = (("rolepod-reviewer", "review-code"),)
    else:
        pairs = (("universal-reviewer", "review-code"), ("security-engineer", "security-review"),
                 ("adversarial-reviewer", "adversarial-review"))
    pair_n = {}
    for role, skill in pairs:
        r, s = size(A + role + ".md"), size(S + skill + "/SKILL.md")
        if r is not None and s is not None:
            pair_n[role] = r + s
            add("reader-load", "%s+%s" % (role, skill), r + s)
    adv = lens + L("adversarial-review/SKILL.md") if TYPED else pair_n.get("adversarial-reviewer")
    if adv is not None and ("review-round", "standard-r4-round1") in rows:
        add("review-round", "full-r4-round1", rows[("review-round", "standard-r4-round1")] + adv)
    ccr = size(S + "convening-code-review/SKILL.md")
    if ccr is not None:
        for name, ns in per.items():
            add("owner", "delegating-own/" + name, code_own + round(sum(ns) / len(ns)) + ccr)

for (reader, art), n in sorted(rows.items()):
    print("%s\t%s\t%d" % (reader, art, n))
PY
