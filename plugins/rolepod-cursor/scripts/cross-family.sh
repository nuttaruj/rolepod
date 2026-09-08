#!/bin/bash
# rolepod cross-family runner — ONE command for every cross-CLI opinion:
# the adversarial review pass, the spec critique, the plan advisory panel,
# the stuck-state consult. Installed as `rolepod-cross-family` (install.sh)
# and shipped in every plugin tree as scripts/cross-family.sh.
#
# Why this exists (measured 2026-09 across 9 repos on one machine): 210
# subagent dispatches, 18 review lines, 0 anchored cross-family passes. The
# doctrine ALLOWED the pass, but every step was manual — detect the pool,
# write the brief, remember the clean-room prefix, tee the output, append
# the phase-log line — while the same-family reviewer was one Agent call
# away, and nothing measured the gap. This script is the whole path.
#
# Rules it encodes:
#   pool     OPT-IN. <git-root>/.rolepod/cross-family (project) overrides
#            ~/.rolepod/cross-family (machine). NO file = OFF, `none` = OFF —
#            rolepod never enables cross-family on its own: the SessionStart
#            loader asks the user ONCE, the answer is written to the file.
#            Format — one CLI per line in preference order, options after the
#            name, optional per-kind order lines:
#                codex timeout=1800      # slow-but-deep member gets 30 min
#                agy
#                consult: agy codex      # debug consults want the fast answer first
#            Names: codex claude agy cursor opencode (`gemini` is retired —
#            skipped with a note; list agy instead).
#   cli      only the Lead's OWN CLI is excluded. The model family is
#            recorded for information (agy = google; cursor / opencode = the
#            family of their default model, else `unknown`; what actually ran
#            is captured when the CLI reports it) — a member is never skipped
#            or failed for its model: a different CLI IS the point (owner rule).
#   model    NEVER a model or effort flag. TIER_MODELS applies only to the CLI
#            that is the Lead; an external runs whatever its owner set as
#            default. The phase-log records model:"default".
#   time     per member: --timeout > `timeout=` in the config > kind default
#            (review 1800 s detached / 600 s foreground · consult 300 ·
#            advise 900 · critique 600). The prompt carries the budget so the
#            model plans for it. `--detach` runs the whole chain as a job in
#            its own process group and returns at once — the Lead keeps
#            working, `--collect <job>` waits for the receipt, the commit gate
#            sees the job. Foreground calls are capped by the harness (Claude
#            Bash: 600 s) — the runner warns when a member's budget exceeds it.
#   slice    a diff attachment whose files carry working-tree edits it does
#            not contain is a partial slice (`git diff --cached` while the same
#            file has unstaged edits; a committed range while the tree moved
#            on). The reviewer reads the live tree, so the verdict is an
#            artifact before the run starts → refused, exit 7, no member
#            called (measured 2026-09-07: 3 of 4 rounds in one day). Attach
#            `git diff HEAD` or commit first; `--partial-ok` only when the
#            user asked for the staged part.
#   round 2+ `--since <job-id>`: the runner snapshots the working tree at every
#            detached dispatch (tree object, real index untouched) and, on
#            --since, attaches the fix delta (that snapshot → now, new files
#            included) plus the previous report — the reviewer verifies the
#            fixes, tags IN-FIX / NEW / REPEAT, and the budget goes to the
#            delta, not the cumulative diff. One live review job per repo: a
#            second `--kind review` is refused (exit 8) until --collect / --kill.
#   breaker  review rounds on ONE uncommitted tree are counted (reviewer
#            dispatches closer than 5 min = one round; internal roles from the
#            phase-log, external jobs from their start times). Round 3 gets a
#            notice; round 4 needs `--ledger <breaker file>` (a `## Class`
#            heading = the root cause was named); round 5 is refused, exit 9:
#            split & stop (review-code §5). Measured: 11+ rounds overnight,
#            no consult, no hand-back, when this was doctrine only.
#   read-only every invocation uses the CLI's read-only / plan mode; the
#            prompt says so too. ROLEPOD_BRAIN_SILENT=1 keeps ambient memory
#            out of the cold run (clean room).
#   health   installed ≠ usable: exit≠0, timeout, or too little output (review
#            < 500 bytes — the gate's floor; other kinds < 200) → next member;
#            every failure is a phase-log line; all fail → exit 3; enabled but
#            nothing usable → exit 4 (logged); OFF → exit 5 (not logged — the
#            user's choice is not a failure). The Lead then runs its own path.
#   evidence .rolepod/evidence/external/<utc>-<cli>.txt + one phase-log line
#            ({"phase":"review","reviewer":"external",...} is what
#            precommit-gate counts as the strong pass; consult / advise lines
#            feed `rolepod-stats`). Jobs live under external/jobs/<id>/.
#
# Usage:
#   cross-family.sh --kind review|consult|advise|critique --brief <file> [--attach <file>]...
#                   [--lead <cli>] [--all] [--timeout <sec>] [--detach] [--partial-ok] [--since <job-id>] [--ledger <file>]
#   cross-family.sh --rounds                               # review rounds since the last commit (breaker state)
#   cross-family.sh --kill <job-id>                        # abandon a running job (status 137, no anchor)
#   cross-family.sh --collect <job-id> [--timeout <sec>]   # wait for a detached job, print its output
#   cross-family.sh --jobs                                # list detached jobs (running / done)
#   cross-family.sh --pool [--lead <cli>] [--kind <k>]    # usable pool, no network
#   cross-family.sh --pool-names [--lead <cli>]           # names only (hooks use this)
#   cross-family.sh --probe [--lead <cli>]                # live "reply OK" per member
#   cross-family.sh --candidates                          # every installed CLI, the Lead's own included (opt-in question)
# Exit: 0 ok · 2 usage · 3 every member failed · 4 configured pool empty · 5 off · 6 job still running
set -uo pipefail

KIND=""; BRIEF=""; LEAD="${ROLEPOD_LEAD_CLI:-}"; ALL=0; FLAG_TIMEOUT="${ROLEPOD_XFAM_TIMEOUT:-}"
MODE="run"; ATTACH=""; DETACH=0; JOB_DIR=""; COLLECT_ID=""; ROOT_FLAG=""; CFG_FLAG=""; PARTIAL_OK=0; SINCE_ID=""; KILL_ID=""; LEDGER=""; ROUND_NOTE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --kind) KIND="${2:-}"; shift 2 ;;
    --brief) BRIEF="${2:-}"; shift 2 ;;
    --attach) ATTACH="$ATTACH${ATTACH:+
}${2:-}"; shift 2 ;;
    --lead) LEAD="${2:-}"; shift 2 ;;
    --root) ROOT_FLAG="${2:-}"; shift 2 ;;
    --all) ALL=1; shift ;;
    --timeout) FLAG_TIMEOUT="${2:-}"; shift 2 ;;
    --detach) DETACH=1; shift ;;
    --partial-ok) PARTIAL_OK=1; shift ;;         # the user asked for the staged part only
    --since) SINCE_ID="${2:-}"; shift 2 ;;         # round 2+: attach the fix delta since that job + its report
    --kill) MODE="kill"; KILL_ID="${2:-}"; shift 2 ;;
    --ledger) LEDGER="${2:-}"; shift 2 ;;            # breaker ledger — round 4 needs it (review-code §5)
    --rounds) MODE="rounds"; shift ;;               # print review rounds on this uncommitted tree
    --job) JOB_DIR="${2:-}"; shift 2 ;;          # internal: the detached child
    --config) CFG_FLAG="${2:-}"; shift 2 ;;      # internal: the job's config snapshot
    --collect) MODE="collect"; COLLECT_ID="${2:-}"; shift 2 ;;
    --jobs) MODE="jobs"; shift ;;
    --pool) MODE="pool"; shift ;;
    --pool-names) MODE="pool-names"; shift ;;
    --probe) MODE="probe"; shift ;;
    --candidates) MODE="candidates"; shift ;;
    -h|--help) sed -n '2,60p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "cross-family: unknown argument: $1" >&2; exit 2 ;;
  esac
done

is_num() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
if [ -n "$FLAG_TIMEOUT" ] && ! is_num "$FLAG_TIMEOUT"; then echo "cross-family: --timeout must be a whole number of seconds (got '$FLAG_TIMEOUT')" >&2; exit 2; fi
if [ -n "$ROOT_FLAG" ]; then ROOT="$ROOT_FLAG"; else ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; fi
EV="$ROOT/.rolepod/evidence"
JOBS="$EV/external/jobs"
ALL_CLIS="codex claude agy cursor opencode"
LEAD_CLIS="$ALL_CLIS gemini"
iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
TMPP=""
# A detached child records its exit status whatever path it leaves by —
# installed before the first `exit`, so --collect never waits on a job that
# died early (config gone, usage error, pool off).
finish() { _rc=$?; if [ -n "$JOB_DIR" ]; then { date +%s > "$JOB_DIR/finished"; printf '%s\n' "$_rc" > "$JOB_DIR/status.tmp" && mv -f "$JOB_DIR/status.tmp" "$JOB_DIR/status"; } 2>/dev/null; fi; [ -n "$TMPP" ] && rm -rf "$TMPP"; }
trap finish EXIT
if [ -n "$JOB_DIR" ]; then mkdir -p "$JOB_DIR" 2>/dev/null; [ -f "$JOB_DIR/started" ] || date +%s > "$JOB_DIR/started"; fi

# ── Jobs (no Lead needed) ──────────────────────────────────────────────
job_elapsed() { _st=$(cat "$1/started" 2>/dev/null || echo 0); echo $(( ($(date +%s) - _st) / 60 )); }
job_alive() { # $1 job dir → 0 when the recorded pid is alive AND is still this runner (SIGKILL skips the trap; pids get reused)
  _p=$(cat "$1/pid" 2>/dev/null); is_num "$_p" || return 1
  kill -0 "$_p" 2>/dev/null || return 1
  ps -o command= -p "$_p" 2>/dev/null | grep -q 'cross-family' || return 1
}
job_status() { _v=$(cat "$1/status" 2>/dev/null); is_num "$_v" && echo "$_v" || echo 3; }
if [ "$MODE" = "jobs" ]; then
  [ -d "$JOBS" ] || { echo "no cross-family jobs under $JOBS"; exit 0; }
  for d in "$JOBS"/*/; do
    [ -d "$d" ] || continue; id=$(basename "$d")
    if [ -f "$d/status" ]; then st="done exit=$(job_status "$d")"
    elif job_alive "$d"; then st="running $(job_elapsed "$d") min"
    else st="dead (no status — killed?)"; fi
    printf '  %-32s %-18s %s\n' "$id" "$st" "$(grep -E '^ROLEPOD-XFAM' "$d/out.txt" 2>/dev/null | tail -1 | cut -c1-110)"
  done
  exit 0
fi
# ── Review rounds on one uncommitted tree (v2.99.0) ─────────────────────
# Prints `rounds=<past clusters> current=<round a dispatch now would be>
# ledger=<path|-> class=<0|1>`. Events = external review jobs (`started`) +
# phase-log reviewer dispatches (internal roles, review-shaped Workflows),
# since the last commit; a gap > 5 min opens a new round. The breaker ledger
# = newest docs/rolepod/handoffs/*breaker*.md newer than the last commit.
review_rounds() {
  ROLEPOD_XFAM_ROOT="$ROOT" ROLEPOD_XFAM_JOBS="$JOBS" python3 - <<'PY' 2>/dev/null || echo "rounds=0 current=1 ledger=- class=0"
import glob, json, os, re, subprocess, time, datetime
root = os.environ["ROLEPOD_XFAM_ROOT"]; jobs = os.environ["ROLEPOD_XFAM_JOBS"]
try:
    last = int(subprocess.run(["git", "-C", root, "log", "-1", "--format=%ct"], capture_output=True, text=True).stdout.strip() or 0)
except Exception:
    last = 0
ev = []
for d in glob.glob(os.path.join(jobs, "*-review-*")):
    try:
        t = int(open(os.path.join(d, "started")).read().strip())
    except Exception:
        continue
    if t > last:
        ev.append(t)
log = os.path.join(root, ".rolepod", "evidence", "phase-log.jsonl")
ROLES = re.compile(r"(security-engineer|universal-reviewer|code-reviewer|qa-tester)")
if os.path.isfile(log):
    with open(log, "rb") as f:
        size = os.path.getsize(log); f.seek(max(0, size - 262144)); data = f.read().decode("utf-8", "ignore")
    for line in data.splitlines():
        if "dispatch" not in line:
            continue
        try:
            e = json.loads(line)
        except Exception:
            continue
        if e.get("phase") not in ("dispatch", "dispatch-proof"):
            continue
        blob = " ".join([str(e.get("agent_type") or ""), " ".join(str(x) for x in (e.get("agent_types") or []))])
        name = str(e.get("name") or "")
        if not ROLES.search(blob) and not re.search(r"review|verif|audit", name, re.I):
            continue
        try:
            t = int(datetime.datetime.fromisoformat(str(e.get("ts", "")).replace("Z", "+00:00")).timestamp())
        except Exception:
            continue
        if t > last:
            ev.append(t)
ev.sort()
rounds = 0; prev = None
for t in ev:
    if prev is None or t - prev > 300:
        rounds += 1
    prev = t
now = int(time.time())
current = rounds if (prev is not None and now - prev <= 300) else rounds + 1
ledger = "-"; klass = 0
cands = [p for p in glob.glob(os.path.join(root, "docs", "rolepod", "handoffs", "*breaker*.md")) if os.path.getmtime(p) > last]
if cands:
    ledger = max(cands, key=os.path.getmtime)
    try:
        klass = 1 if re.search(r"^## Class", open(ledger, encoding="utf-8", errors="ignore").read(), re.M) else 0
    except Exception:
        klass = 0
print("rounds=%d current=%d ledger=%s class=%d" % (rounds, current, ledger, klass))
PY
}
if [ "$MODE" = "rounds" ]; then review_rounds; exit 0; fi
if [ "$MODE" = "kill" ]; then
  d="$JOBS/$KILL_ID"; [ -d "$d" ] || { echo "cross-family: no job $KILL_ID under $JOBS" >&2; exit 2; }
  if [ -f "$d/status" ]; then echo "ROLEPOD-XFAM job=$KILL_ID already finished (exit $(job_status "$d"))"; exit 0; fi
  _kp=$(cat "$d/pid" 2>/dev/null)
  if job_alive "$d"; then   # the child is its own process group (set -m at spawn): the whole chain dies with it
    kill -TERM -- "-$_kp" 2>/dev/null || kill -TERM "$_kp" 2>/dev/null || true; sleep 1
    job_alive "$d" && { kill -KILL -- "-$_kp" 2>/dev/null || kill -KILL "$_kp" 2>/dev/null || true; }
  fi
  date +%s > "$d/finished"; printf '137\n' > "$d/status"
  echo "ROLEPOD-XFAM job=$KILL_ID killed — status 137, no anchor written. Re-dispatch when the tree is final."
  exit 0
fi
if [ "$MODE" = "collect" ]; then
  d="$JOBS/$COLLECT_ID"; [ -d "$d" ] || { echo "cross-family: no job $COLLECT_ID under $JOBS" >&2; exit 2; }
  W="${FLAG_TIMEOUT:-1800}"; s=$SECONDS
  while [ ! -f "$d/status" ]; do
    if ! job_alive "$d"; then
      sleep 1; [ -f "$d/status" ] && break
      echo "ROLEPOD-XFAM job=$COLLECT_ID died without a status (killed?) — see $d/err.txt; fall back to the internal path"; exit 3
    fi
    if [ $(( SECONDS - s )) -ge "$W" ]; then echo "ROLEPOD-XFAM job=$COLLECT_ID still running ($(job_elapsed "$d") min) — collect again later or fall back to the internal path"; exit 6; fi
    sleep 2
  done
  cat "$d/out.txt" 2>/dev/null; exit "$(job_status "$d")"
fi

# ── Lead detection ─────────────────────────────────────────────────────
if [ -z "$LEAD" ]; then
  if [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then LEAD=claude
  elif [ -n "${CODEX_SANDBOX:-}${CODEX_THREAD_ID:-}${CODEX_SANDBOX_NETWORK_DISABLED:-}" ]; then LEAD=codex
  elif [ -n "${GEMINI_CLI:-}" ]; then LEAD=gemini
  elif [ -n "${ANTIGRAVITY_CLI:-}${AGY_CLI:-}" ]; then LEAD=agy
  elif [ -n "${CURSOR_AGENT:-}" ]; then LEAD=cursor
  elif [ -n "${OPENCODE:-}${OPENCODE_SESSION_ID:-}" ]; then LEAD=opencode
  fi
fi
case " $LEAD_CLIS " in
  *" $LEAD "*) ;;
  *) echo "cross-family: pass --lead <codex|claude|agy|cursor|opencode|gemini> (could not detect the Lead CLI)" >&2; exit 2 ;;
esac

# ── Family resolution ──────────────────────────────────────────────────
classify_model() { # model id or "provider/model" → family; aggregators (openrouter, opencode, ollama…) classify by the model name
  _m=$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')
  case "$_m" in
    ""|auto|default) echo unknown ;;                 # Cursor "Auto" routes across vendors — no fixed family
    *anthropic*|*claude*|*sonnet*|*opus*|*fable*|*haiku*) echo anthropic ;;
    *grok*|*xai*) echo xai ;;
    composer*|cursor/*|*cursor-composer*) echo cursor ;;
    *google*|*gemini*|*gemma*) echo google ;;
    *openai*|*gpt*|*codex*|o1*|o3*|o4*) echo openai ;;
    *kimi*|*moonshot*) echo moonshot ;;
    *deepseek*) echo deepseek ;;
    *glm*|*zhipu*|*z-ai*|*z.ai*) echo zhipu ;;
    *qwen*|*alibaba*) echo alibaba ;;
    *minimax*) echo minimax ;;
    *mistral*|*devstral*|*codestral*|*magistral*) echo mistral ;;
    *nemotron*|*nvidia*) echo nvidia ;;
    *llama*|meta/*) echo meta ;;
    *) echo unknown ;;
  esac
}
json_model_field() { # $1 file (json or jsonc) → TOP-LEVEL "model" (never an agent's nested one)
  [ -f "$1" ] || return 0
  _v=$(python3 - "$1" 2>/dev/null <<'PYJ'
import json, re, sys
raw = open(sys.argv[1], encoding="utf-8", errors="replace").read()
txt = re.sub(r"/\*.*?\*/", "", raw, flags=re.S)
txt = re.sub(r"^\s*//.*$", "", txt, flags=re.M)
txt = re.sub(r",\s*([}\]])", r"\1", txt)
try:
    d = json.loads(txt)
    m = d.get("model") if isinstance(d, dict) else None
    if isinstance(m, dict):  # Cursor cli-config.json: {"model": {"modelId": "composer-2.5", …}}
        m = m.get("modelId") or m.get("displayModelId") or m.get("id") or ""
    print(m if isinstance(m, str) else "")
except Exception:
    print("__PARSE_FAIL__")
PYJ
)
  if [ "$_v" = "__PARSE_FAIL__" ] || [ -z "$_v" ] && ! python3 -c 1 2>/dev/null; then
    sed -e 's#^[[:space:]]*//.*##' "$1" 2>/dev/null | grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/'
  else
    [ "$_v" = "__PARSE_FAIL__" ] && _v=""
    printf '%s' "$_v"
  fi
}
cursor_default_model() { json_model_field "$HOME/.cursor/cli-config.json"; }
opencode_default_model() {
  for _c in "$ROOT/opencode.jsonc" "$ROOT/opencode.json" \
            "${OPENCODE_CONFIG_DIR:-}/opencode.jsonc" "${OPENCODE_CONFIG_DIR:-}/opencode.json" \
            "$HOME/.config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.json"; do
    [ -n "$_c" ] && [ "$_c" != "/opencode.jsonc" ] && [ "$_c" != "/opencode.json" ] || continue
    _f=$(json_model_field "$_c"); [ -n "$_f" ] && { printf '%s' "$_f"; return; }
  done
  opencode_last_used_model
}
# `opencode models` lists but never marks the default; the CLI remembers the last-used model in its state file.
opencode_last_used_model() {
  _s="${XDG_STATE_HOME:-$HOME/.local/state}/opencode/model.json"
  [ -f "$_s" ] || return 0
  python3 - "$_s" 2>/dev/null <<'PYS'
import json, sys
try:
    r = json.load(open(sys.argv[1], encoding="utf-8")).get("recent") or []
    m = r[0] if r else {}
    p, i = m.get("providerID", ""), m.get("modelID", "")
    print(f"{p}/{i}" if p and i else "")
except Exception:
    print("")
PYS
}
# Human note for --pool / --probe: which model the member will run and where that came from.
describe_default_model() {
  case "$1" in
    cursor) _m=$(cursor_default_model); [ -n "$_m" ] && printf 'model=%s (cli-config.json)' "$_m" || printf 'model=none' ;;
    opencode) _m=""; for _c in "$ROOT/opencode.jsonc" "$ROOT/opencode.json" \
            "${OPENCODE_CONFIG_DIR:-}/opencode.jsonc" "${OPENCODE_CONFIG_DIR:-}/opencode.json" \
            "$HOME/.config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.json"; do
        [ -n "$_c" ] && [ "$_c" != "/opencode.jsonc" ] && [ "$_c" != "/opencode.json" ] || continue
        _m=$(json_model_field "$_c"); [ -n "$_m" ] && break
      done
      if [ -n "$_m" ]; then printf 'model=%s (config)' "$_m"
      else _m=$(opencode_last_used_model); [ -n "$_m" ] && printf 'model=%s (last used — pin with "model" in opencode.json(c))' "$_m" || printf 'model=none'; fi ;;
  esac
}
# The model that ACTUALLY ran, from the CLI's own output — per run, per machine, no config guessing:
# codex prints a banner line `model: <id>` (event stream); opencode prints `> <agent> · <model>`.
# claude / agy / cursor do not name the model in -p output (cursor: `cursor-agent models` is the authority).
ran_model_of() { # $1 cli, $2 outfile base → model id or ""
  case "$1" in
    codex) for _x in "$2.err" "$2.stream" "$2"; do [ -f "$_x" ] || continue
             _r=$(grep -m1 '^model: ' "$_x" 2>/dev/null | sed -e 's/^model: *//' -e 's/[[:space:]]*$//'); [ -n "$_r" ] && { printf '%s' "$_r"; return; }; done ;;
    opencode) for _x in "$2.err" "$2"; do [ -f "$_x" ] || continue   # the `> agent · model` header goes to stderr
             _r=$(tr -d '\033' < "$_x" | sed 's/\[[0-9;]*m//g' | grep -m1 '^> .* · ' | sed -e 's/^> .* · //' -e 's/[[:space:]]*$//'); [ -n "$_r" ] && { printf '%s' "$_r"; return; }; done ;;
  esac
}
family_of() {
  case "$1" in
    codex) echo openai ;;
    claude) echo anthropic ;;
    gemini|agy) echo google ;;
    cursor) classify_model "$(cursor_default_model)" ;;
    opencode) classify_model "$(opencode_default_model)" ;;
    *) echo unknown ;;
  esac
}
bin_of() {
  case "$1" in
    cursor) command -v cursor-agent 2>/dev/null || command -v agent 2>/dev/null ;;
    *) command -v "$1" 2>/dev/null ;;
  esac
}
LEAD_FAMILY=$(family_of "$LEAD")

# ── Candidates (EVERY installed CLI, the Lead's own included) — the opt-in question.
# The file is Lead-independent: list them all once; whichever CLI is the Lead is
# skipped at run time, so switching Lead never means editing the pool.
CANDIDATES=""
for cli in $ALL_CLIS; do
  [ -n "$(bin_of "$cli")" ] || continue
  fam=$(family_of "$cli")   # information only — never a filter
  CANDIDATES="$CANDIDATES${CANDIDATES:+ }$cli($fam)"
done
if [ "$MODE" = "candidates" ]; then printf '%s\n' $CANDIDATES; exit 0; fi

# ── Config (opt-in: no file = off) ─────────────────────────────────────
# default list = bare lines; `<kind>:` lines = per-kind order; `key=value`
# tokens attach to the CLI named just before them (timeout= today).
CFG=""; CFG_SRC=""; STATE="on"
if [ -n "$CFG_FLAG" ] && [ -f "$CFG_FLAG" ]; then CFG="$CFG_FLAG"; CFG_SRC="$(head -1 "$CFG_FLAG.src" 2>/dev/null || echo "$CFG_FLAG") (job snapshot)"
elif [ -f "$ROOT/.rolepod/cross-family" ]; then CFG="$ROOT/.rolepod/cross-family"; CFG_SRC="$CFG"
elif [ -f "$HOME/.rolepod/cross-family" ]; then CFG="$HOME/.rolepod/cross-family"; CFG_SRC="$CFG"; fi
DEFAULT_LIST=""; KIND_LIST=""; TO_LIST=""
if [ -n "$CFG" ]; then
  while IFS= read -r _ln || [ -n "$_ln" ]; do
    _ln=$(printf '%s' "$_ln" | sed -e 's/#.*//' | tr 'A-Z' 'a-z' | tr -s '[:space:]' ' ' | sed -e 's/^ //' -e 's/ $//')
    [ -n "$_ln" ] || continue
    _k=""; case "$_ln" in review:*|consult:*|advise:*|critique:*) _k="${_ln%%:*}"; _ln="${_ln#*:}";; esac
    _acc=""; _last=""
    for _t in $_ln; do
      case "$_t" in
        *=*) _key="${_t%%=*}"; _val="${_t#*=}"
             if [ "$_key" = "timeout" ] && [ -n "$_last" ]; then
               if ! is_num "$_val"; then echo "cross-family: ignoring timeout='$_val' for $_last in $CFG (whole seconds only)" >&2
               elif [ -z "$_k" ] || [ "$_k" = "$KIND" ]; then TO_LIST="$TO_LIST $_last=$_val"; fi   # a kind line's options bind to that kind only
             fi ;;
        *) _last="$_t"; _acc="$_acc${_acc:+ }$_t" ;;
      esac
    done
    if [ -z "$_k" ]; then DEFAULT_LIST="$DEFAULT_LIST${DEFAULT_LIST:+ }$_acc"
    elif [ "$_k" = "$KIND" ]; then KIND_LIST="$_acc"; fi
  done < "$CFG"
  printf '%s' "$DEFAULT_LIST" | grep -qw none && STATE="none"
  [ -z "$DEFAULT_LIST$KIND_LIST" ] && STATE="none"
else
  STATE="off"; CFG_SRC="no ~/.rolepod/cross-family (opt-in not given)"
fi
CONFIGURED="${KIND_LIST:-$DEFAULT_LIST}"
ENABLE_HINT="enable: printf 'codex timeout=1800\\nclaude\\nagy\\ncursor\\nopencode\\n' > ~/.rolepod/cross-family  (list EVERY CLI you want, this one included — the Lead's own CLI is skipped at run time, so one file serves every Lead; your order = preference; 'consult: agy codex' = per-kind order; project override: <git-root>/.rolepod/cross-family; 'none' = keep off)"

timeout_for() { # $1 cli → seconds (flag > config > kind default)
  [ -n "$FLAG_TIMEOUT" ] && { echo "$FLAG_TIMEOUT"; return; }
  _c=$(printf '%s' "$TO_LIST" | tr ' ' '\n' | grep "^$1=" | tail -1 | cut -d= -f2)
  [ -n "$_c" ] && { echo "$_c"; return; }
  case "$KIND" in
    review) if [ -n "$JOB_DIR" ]; then echo 1800; else echo 600; fi ;;
    consult) echo 300 ;;
    advise) echo 900 ;;
    critique) echo 600 ;;
    *) echo 600 ;;
  esac
}

# Rows: "<cli> <status> <family> <note>" — status ∈ usable|skipped|absent
POOL_ROWS=""; USABLE=""; SEEN_FAMILIES=""
if [ "$STATE" != "on" ]; then
  if [ "$STATE" = "none" ]; then POOL_ROWS="-  off  -  cross-family disabled by $CFG_SRC (none)"
  else POOL_ROWS="-  off  -  cross-family is OPT-IN and not enabled on this machine"; fi
else
  for cli in $CONFIGURED; do
    if [ "$cli" = "gemini" ]; then POOL_ROWS="$POOL_ROWS
gemini  skipped  google  retired — Google moved individual accounts to Antigravity; list agy instead"; continue; fi
    case " $ALL_CLIS " in *" $cli "*) ;; *) POOL_ROWS="$POOL_ROWS
$cli  skipped  -  unknown CLI name in $CFG_SRC"; continue ;; esac
    bin=$(bin_of "$cli")
    if [ -z "$bin" ]; then POOL_ROWS="$POOL_ROWS
$cli  absent  -  not on PATH"; continue; fi
    fam=$(family_of "$cli")
    if [ "$cli" = "$LEAD" ]; then POOL_ROWS="$POOL_ROWS
$cli  skipped  $fam  is the Lead"; continue; fi
    note="bin=$bin · timeout=$(timeout_for "$cli")s"
    case "$cli" in cursor|opencode) note="$note · $(describe_default_model "$cli")" ;; esac
    if [ "$fam" = "unknown" ]; then
      case "$cli" in
        cursor) case "$(cursor_default_model | tr 'A-Z' 'a-z')" in
                  ""|auto|default) note="$note · family unknown: Cursor Auto routes across vendors — pin one (run \`cursor-agent\`, type /model) — info only, still used" ;;
                  *) note="$note · family unknown: model not recognized — info only, still used" ;;
                esac ;;
        opencode) if [ -z "$(opencode_default_model)" ]; then note="$note · family unknown: no \"model\" in opencode.json(c) and no last-used model — info only, still used"
                  else note="$note · family unknown: model not recognized — info only, still used"; fi ;;
      esac
    fi
    POOL_ROWS="$POOL_ROWS
$cli  usable  $fam  $note"
    USABLE="$USABLE${USABLE:+ }$cli"
    SEEN_FAMILIES="$SEEN_FAMILIES $fam"
  done
fi

print_pool() {
  echo "cross-family pool — lead=$LEAD ($LEAD_FAMILY)${KIND:+ · kind=$KIND}${KIND_LIST:+ (per-kind order)} · config: $CFG_SRC"
  printf '%s\n' "$POOL_ROWS" | sed '/^$/d' | awk '{printf "  %-9s %-8s %-10s", $1, $2, $3; $1=$2=$3=""; sub(/^ +/, ""); print $0}'
  if [ -n "$USABLE" ]; then echo "  → usable, in order: $USABLE"
  elif [ "$STATE" = "off" ]; then
    echo "  → OFF. Installed candidates: ${CANDIDATES:-none}"
    echo "  → $ENABLE_HINT"
  elif [ "$STATE" = "none" ]; then echo "  → OFF by choice (none). Installed candidates: ${CANDIDATES:-none}; edit $CFG to enable"
  else echo "  → configured but nothing usable (see rows) — internal strong reviewer is the pass; recorded as a limitation"; fi
}

case "$MODE" in
  pool) print_pool; exit 0 ;;
  pool-names) [ -n "$USABLE" ] && printf '%s\n' $USABLE; exit 0 ;;
esac

# ── Invocation (read-only, default model, clean room) ──────────────────
RUN_STDIN=/dev/null; TIMEOUT=600
run_to() { # $1 outfile, $2... command; stdin = $RUN_STDIN (a `&` job gets /dev/null otherwise)
  _out="$1"; shift
  # Job control ON for the launch → the job is its own process group, so a
  # timeout kills the CLI AND its grandchildren (node runners, sandboxes)
  # with one `kill -- -pgid`; pkill -P would leave them orphaned.
  set -m
  ( cd "$ROOT" && ROLEPOD_BRAIN_SILENT=1 exec "$@" ) < "$RUN_STDIN" > "$_out" 2> "$_out.err" &
  _pid=$!
  set +m
  _start=$SECONDS
  while kill -0 "$_pid" 2>/dev/null; do
    if [ $(( SECONDS - _start )) -ge "$TIMEOUT" ]; then
      kill -TERM -- "-$_pid" 2>/dev/null; kill -TERM "$_pid" 2>/dev/null; sleep 2
      kill -KILL -- "-$_pid" 2>/dev/null; kill -KILL "$_pid" 2>/dev/null
      wait "$_pid" 2>/dev/null; return 124
    fi
    sleep 1
  done
  wait "$_pid"
}
invoke() { # $1 cli, $2 promptfile, $3 outfile — TIMEOUT already set for this member
  _cli="$1"; _p="$2"; _o="$3"; _bin=$(bin_of "$_cli")
  RUN_STDIN=/dev/null
  case "$_cli" in
    codex)    RUN_STDIN="$_p"; run_to "$_o" "$_bin" exec -s read-only --skip-git-repo-check --ephemeral --color never -C "$ROOT" -o "$_o.msg" - ;;
    claude)   RUN_STDIN="$_p"; run_to "$_o" "$_bin" -p --permission-mode plan --no-session-persistence ;;
    agy)      run_to "$_o" "$_bin" -p "$(cat "$_p")" --mode plan --print-timeout "${TIMEOUT}s" ;;
    cursor)   run_to "$_o" "$_bin" -p --mode plan --output-format text --trust "$(cat "$_p")" ;;
    opencode) run_to "$_o" "$_bin" run --agent plan "$(cat "$_p")" ;;
    *) return 2 ;;
  esac
}
jlog() { mkdir -p "$EV" 2>/dev/null || return 0; printf '%s\n' "$1" >> "$EV/phase-log.jsonl" 2>/dev/null || true; }
jesc() { # JSON string body (no surrounding quotes) — control chars escaped too
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().replace("\n"," "))[1:-1], end="")' 2>/dev/null && return
  fi
  printf '%s' "$1" | tr -d '\000-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# ── Probe ──────────────────────────────────────────────────────────────
if [ "$MODE" = "probe" ]; then
  print_pool
  [ "$STATE" = "on" ] || exit 5
  [ -n "$USABLE" ] || exit 4
  TMPP=$(mktemp -d "${TMPDIR:-/tmp}/rolepod-xfam.XXXXXX")
  printf 'Reply with exactly the word OK and nothing else. Do not read files, do not run commands.\n' > "$TMPP/p.txt"
  echo "probe (≤180s each):"
  rc_all=3
  for cli in $USABLE; do
    if [ "$cli" = "cursor" ]; then # the CLI is the authority on its own default: `cursor-agent models` marks "(current, default)"
      _live=$("$(bin_of cursor)" models </dev/null 2>/dev/null | grep -i '(current' | head -1 | sed -e 's/ - .*//' -e 's/^[[:space:]]*//')
      _cfg=$(cursor_default_model); case "$(printf '%s' "$_cfg" | tr 'A-Z' 'a-z')" in ""|default|auto) _cfg=auto ;; esac
      if [ -n "$_live" ]; then
        _diff=""; [ "$_live" != "$_cfg" ] && _diff=" — cli-config.json says $_cfg; the CLI wins"
        printf '  %-9s default per CLI: %s (%s)%s\n' cursor "$_live" "$(classify_model "$_live")" "$_diff"
      fi
    fi
    [ "$cli" = "opencode" ] && printf '  %-9s %s\n' opencode "$(describe_default_model opencode)"
    TIMEOUT=$(timeout_for "$cli"); [ "$TIMEOUT" -gt 180 ] && TIMEOUT=180
    s=$SECONDS; invoke "$cli" "$TMPP/p.txt" "$TMPP/$cli.out"; rc=$?; secs=$(( SECONDS - s ))
    ran=$(ran_model_of "$cli" "$TMPP/$cli.out"); ranfam=""; [ -n "$ran" ] && ranfam=$(classify_model "$ran")
    [ "$cli" = "codex" ] && [ -s "$TMPP/$cli.out.msg" ] && mv "$TMPP/$cli.out.msg" "$TMPP/$cli.out"
    bytes=$(wc -c < "$TMPP/$cli.out" | tr -d ' ')
    if [ "$rc" -eq 0 ] && [ "$bytes" -gt 0 ]; then
      printf '  %-9s ok    %3ss  %s%s\n' "$cli" "$secs" "$(head -c 60 "$TMPP/$cli.out" | tr '\n' ' ')" "${ran:+ · ran=$ran ($ranfam)}"; rc_all=0
    else
      why="exit $rc"; [ "$rc" -eq 124 ] && why="timeout ${TIMEOUT}s"
      printf '  %-9s FAIL  %3ss  %s — %s\n' "$cli" "$secs" "$why" "$(head -c 120 "$TMPP/$cli.out.err" | tr '\n' ' ')"
    fi
  done
  exit $rc_all
fi

# ── Run ────────────────────────────────────────────────────────────────
case "$KIND" in review|consult|advise|critique) ;; *) echo "cross-family: --kind review|consult|advise|critique required" >&2; exit 2 ;; esac
[ -n "$BRIEF" ] && [ -f "$BRIEF" ] || { echo "cross-family: --brief <file> required (write the cold-context brief to a file first)" >&2; exit 2; }
case "$KIND" in
  review) PHASE=review ;;
  consult) PHASE=consult ;;
  advise|critique) PHASE=advise ;;
esac

if [ "$STATE" != "on" ]; then
  print_pool >&2
  echo "ROLEPOD-XFAM off — cross-family is opt-in and not enabled (lead=$LEAD; $CFG_SRC). Use the Lead's own path (internal strong reviewer / vertical consult). To enable, ASK the user which CLIs (candidates: ${CANDIDATES:-none}); $ENABLE_HINT"
  exit 5
fi
if [ -z "$USABLE" ]; then
  print_pool >&2
  jlog "{\"ts\":\"$(iso_now)\",\"phase\":\"external-fail\",\"kind\":\"$KIND\",\"cli\":\"-\",\"family\":\"-\",\"lead\":\"$LEAD\",\"reason\":\"pool-empty: $(jesc "$CFG_SRC")\"}"
  echo "ROLEPOD-XFAM empty — cross-family is enabled ($CFG_SRC) but no listed CLI is usable for a $LEAD Lead. Fall back to the internal strong reviewer and record the limitation."
  exit 4
fi

# ── One live review per repo (v2.98.0) ────────────────────────────────
# Measured 2026-09-07: three review jobs launched 20 min apart on one tree,
# each with a 30-min member budget — all three timed out, zero verdicts.
# The parent (not the detached child, which carries --job) refuses a second
# review while one is alive; consult / advise / critique are unaffected.
if [ "$KIND" = "review" ] && [ -z "$JOB_DIR" ] && [ -d "$JOBS" ]; then
  for _ld in "$JOBS"/*-review-*/; do
    [ -d "$_ld" ] || continue; [ -f "$_ld/status" ] && continue
    job_alive "$_ld" || continue
    _lid=$(basename "$_ld")
    echo "ROLEPOD-XFAM refused stacked — review job $_lid is still running ($(job_elapsed "$_ld") min) on this repo; a second review of the same tree doubles the budget for one verdict. Fix: rolepod-cross-family --collect $_lid (waits), then round 2 with --since $_lid. Abandon it instead: --kill $_lid."
    exit 8
  done
fi

# ── Round breaker (v2.99.0) ─────────────────────────────────────────────
# Round 3 = notice; round 4 needs the breaker ledger (--ledger, `## Class`);
# round 5+ is terminal — split & stop, the user decides. Parent only.
if [ "$KIND" = "review" ] && [ -z "$JOB_DIR" ]; then
  RR=$(review_rounds)
  CUR=$(printf '%s' "$RR" | sed -n 's/.*current=\([0-9]*\).*/\1/p'); CUR=${CUR:-1}
  LCLASS=$(printf '%s' "$RR" | sed -n 's/.*class=\([01]\).*/\1/p'); LCLASS=${LCLASS:-0}
  if [ -n "$LEDGER" ]; then
    { [ -f "$LEDGER" ] && grep -q '^## Class' "$LEDGER"; } || { echo "cross-family: --ledger $LEDGER must exist and carry a '## Class' heading (review-code §5 step 2)" >&2; exit 2; }
    LCLASS=1; ATTACH="$LEDGER${ATTACH:+
$ATTACH}"
  fi
  if [ "$CUR" -ge 5 ] && [ "${ROLEPOD_GATES_SOFT:-0}" != "1" ]; then
    echo "ROLEPOD-XFAM refused round=$CUR — review round $CUR on one uncommitted tree is past the breaker budget (ledger, class fix once, ONE round). Fix: split & stop (review-code §5 step 5) — commit the slices with no open finding, park the churning surface as a delta spec / Follow-ups, end the turn with the decision brief; the user decides. Exception: ROLEPOD_GATES_SOFT=1 (user-set)."
    exit 9
  fi
  if [ "$CUR" -ge 4 ] && [ "$LCLASS" != "1" ] && [ "${ROLEPOD_GATES_SOFT:-0}" != "1" ]; then
    echo "ROLEPOD-XFAM refused round=$CUR — round 4 on one uncommitted tree without a breaker ledger. Fix: write docs/rolepod/handoffs/<feature>-breaker-<date>.md (## Rounds: one line per round · ## Class: the one root cause, its single point, every consumer · ## Decision), make the class-level fix ONCE with a class test, then re-run with --ledger <file> --since <job>. Exception: ROLEPOD_GATES_SOFT=1 (user-set)."
    exit 9
  fi
  if [ "$CUR" -ge 3 ]; then
    ROUND_NOTE="ROLEPOD-XFAM round=$CUR on one uncommitted tree — the breaker is armed: after this verdict no more point fixes; ledger (## Rounds · ## Class · ## Decision) → class fix once (class test + consumer list) → ONE round with --ledger --since → else split & stop (review-code §5)."
    echo "$ROUND_NOTE"
  fi
fi

# Working-tree snapshot as a tree object — tracked + untracked-not-ignored
# minus .rolepod/ and docs/rolepod/ (evidence + private working docs move
# during a round and are not the reviewed change), the real index untouched. Recorded per detached job (tree file); --since
# diffs that snapshot against a fresh one (tree-to-tree: new files count).
snapshot_tree() {
  _ti=$(mktemp) || return 1; rm -f "$_ti"
  ( export GIT_INDEX_FILE="$_ti"; { git -C "$ROOT" read-tree HEAD 2>/dev/null || git -C "$ROOT" read-tree --empty 2>/dev/null; } && git -C "$ROOT" add -A -- . ':(exclude).rolepod' ':(exclude)docs/rolepod' 2>/dev/null && git -C "$ROOT" write-tree 2>/dev/null ); _src=$?
  rm -f "$_ti"; return $_src
}

# ── Partial-slice stop (v2.94.0) ───────────────────────────────────────
# A diff attachment is a slice when, for a file it touches that differs
# from HEAD in the working tree, its +/- lines are not that file's block of
# `git diff HEAD`. Both sides go through the same awk (renames, binaries
# and prefixes cancel out); a file clean vs HEAD is never a slice, so a
# committed range on a clean tree passes. No git repo → no check.
partial_slice() { # stdin: attachment paths → stdout: files whose tree edits the attachment does not cover
  _ps_a=$(mktemp) || return 0; _ps_w=$(mktemp) || { rm -f "$_ps_a"; return 0; }
  _ps_awk='/^\+\+\+ b\//{f=substr($0,7); sub(/[ \t]+$/,"",f); next} /^(--- |\+\+\+ )/{next} /^[+-]/{if (f != "") print f "\t" $0}'
  git -C "$ROOT" diff HEAD 2>/dev/null | awk "$_ps_awk" > "$_ps_w" 2>/dev/null || :
  if [ -s "$_ps_w" ]; then
    while IFS= read -r a; do
      [ -f "$a" ] && grep -q '^+++ b/' "$a" 2>/dev/null || continue
      awk "$_ps_awk" "$a" > "$_ps_a" 2>/dev/null || continue
      cut -f1 "$_ps_a" | sort -u | while IFS= read -r f; do
        [ -n "$f" ] || continue
        wip=$(awk -F'\t' -v f="$f" '$1 == f {sub(/^[^\t]*\t/, ""); print}' "$_ps_w" | sort)
        [ -n "$wip" ] || continue
        att=$(awk -F'\t' -v f="$f" '$1 == f {sub(/^[^\t]*\t/, ""); print}' "$_ps_a" | sort)
        [ "$wip" = "$att" ] || printf '%s\n' "$f"
      done
    done | sort -u
  fi
  rm -f "$_ps_a" "$_ps_w"
}
# Parent only: the detached child re-execs with --job and would re-check a
# runner-built --since delta against git diff HEAD (a false refusal).
if [ -n "$ATTACH" ] && [ -z "$JOB_DIR" ] && [ "$PARTIAL_OK" -ne 1 ] && git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  SLICE=$(printf '%s\n' "$ATTACH" | partial_slice 2>/dev/null || true)
  if [ -n "$SLICE" ]; then
    _sn=$(printf '%s\n' "$SLICE" | grep -c . || true)
    jlog "{\"ts\":\"$(iso_now)\",\"phase\":\"external-refused\",\"kind\":\"$KIND\",\"lead\":\"$LEAD\",\"reason\":\"partial-slice\",\"files\":$_sn}"
    echo "ROLEPOD-XFAM refused partial-slice files=$_sn — the attachment does not contain this tree's edits to: $(printf '%s' "$SLICE" | tr '\n' ' '). The reviewer reads the live tree, so its verdict would be an artifact. Fix: git diff HEAD > <diff> (staged + unstaged together), or commit first, then re-run. Exception: the user asked for the staged part only → --partial-ok."
    exit 7
  fi
fi

# ── Oversized diff notice (v2.100.0) ───────────────────────────────────
# Measured: one 40-file / 2.6k-line uncommitted tree went through 11 rounds;
# every round found what the previous one had no capacity to read. Notice
# only — the split belongs to the Lead (finish-work P gate: one concern).
if [ "$KIND" = "review" ] && [ -z "$JOB_DIR" ] && [ -n "$ATTACH" ]; then
  _df=0; _dl=0
  while IFS= read -r a; do
    [ -f "$a" ] && grep -q '^+++ b/' "$a" 2>/dev/null || continue
    _df=$(( _df + $(grep -c '^diff --git ' "$a" 2>/dev/null || echo 0) ))
    _dl=$(( _dl + $(grep -c -E '^[+-][^+-]' "$a" 2>/dev/null || echo 0) ))
  done <<EOF
$ATTACH
EOF
  if [ "$_df" -gt 15 ] || [ "$_dl" -gt 800 ]; then
    echo "ROLEPOD-XFAM notice: diff = $_df files / $_dl changed lines — past reviewer capacity (~15 files / ~800 lines); each round reads what the last one could not. Fix: split by concern (finish-work P gate) and review each slice, or accept a partial read. Continuing."
  fi
fi

# ── Round 2+: --since <job-id> (v2.98.0) ──────────────────────────────
if [ -n "$SINCE_ID" ]; then
  _sd="$JOBS/$SINCE_ID"; [ -d "$_sd" ] || { echo "cross-family: --since: no job $SINCE_ID under $JOBS" >&2; exit 2; }
  [ -f "$_sd/status" ] || { echo "cross-family: --since $SINCE_ID is still running — --collect it first" >&2; exit 2; }
  _old=$(cat "$_sd/tree" 2>/dev/null); [ -n "$_old" ] || { echo "cross-family: --since: job $SINCE_ID has no tree snapshot (pre-v2.98 job, or not a git repo) — attach the fix diff yourself" >&2; exit 2; }
  _new=$(snapshot_tree) || { echo "cross-family: --since: cannot snapshot the working tree" >&2; exit 2; }
  SINCE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/rolepod-xfam-since.XXXXXX")
  git -C "$ROOT" diff-tree -p "$_old" "$_new" > "$SINCE_DIR/fix-delta-since-$SINCE_ID.patch" 2>/dev/null || { echo "cross-family: --since: diff against the snapshot failed" >&2; exit 2; }
  [ -s "$SINCE_DIR/fix-delta-since-$SINCE_ID.patch" ] || { echo "cross-family: --since $SINCE_ID: nothing changed since that round — nothing to review" >&2; rm -rf "$SINCE_DIR"; exit 2; }
  cp "$_sd/out.txt" "$SINCE_DIR/previous-round-report-$SINCE_ID.txt" 2>/dev/null || : > "$SINCE_DIR/previous-round-report-$SINCE_ID.txt"
  ATTACH="$SINCE_DIR/fix-delta-since-$SINCE_ID.patch
$SINCE_DIR/previous-round-report-$SINCE_ID.txt${ATTACH:+
$ATTACH}"
fi

# ── Detach: run the whole chain as a job in its own process group ──────
abspath() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$(cd "$(dirname "$1")" && pwd)" "$(basename "$1")" ;; esac; }
if [ "$DETACH" -eq 1 ]; then
  JOB_ID="$(date -u +%Y%m%dT%H%M%SZ)-$KIND-$$"; JD="$JOBS/$JOB_ID"
  mkdir -p "$JD" 2>/dev/null || { echo "cross-family: cannot create $JD" >&2; exit 2; }
  # Snapshot the pool the user had when they started it — fail closed: a
  # job must never silently run on a different config than the one shown.
  if ! cp "$CFG" "$JD/cross-family" 2>/dev/null; then echo "cross-family: cannot snapshot $CFG into $JD — not detaching" >&2; rm -rf "$JD"; exit 2; fi
  printf '%s\n' "$CFG" > "$JD/cross-family.src"
  # Child argv as an ARRAY — paths with spaces / globs survive the re-exec.
  CHILD_ARGS=(--kind "$KIND" --brief "$(abspath "$BRIEF")" --lead "$LEAD" --root "$ROOT" --job "$JD" --config "$JD/cross-family")
  [ "$ALL" -eq 1 ] && CHILD_ARGS=("${CHILD_ARGS[@]}" --all)
  [ -n "$FLAG_TIMEOUT" ] && CHILD_ARGS=("${CHILD_ARGS[@]}" --timeout "$FLAG_TIMEOUT")
  if [ -n "$ATTACH" ]; then
    while IFS= read -r a; do [ -f "$a" ] && CHILD_ARGS=("${CHILD_ARGS[@]}" --attach "$(abspath "$a")"); done <<EOF
$ATTACH
EOF
  fi
  printf '%q ' "${CHILD_ARGS[@]}" > "$JD/args"; echo >> "$JD/args"
  snapshot_tree > "$JD/tree" 2>/dev/null || : > "$JD/tree"   # --since reference (fail-open)
  date +%s > "$JD/started"
  set -m; nohup bash "$0" "${CHILD_ARGS[@]}" > "$JD/out.txt" 2> "$JD/err.txt" < /dev/null & echo $! > "$JD/pid"; set +m
  TOS=""; for c in $USABLE; do TOS="$TOS${TOS:+ }$c=$( JOB_DIR="$JD" timeout_for "$c" )s"; done
  echo "ROLEPOD-XFAM job=$JOB_ID kind=$KIND members=$USABLE budgets=$TOS — the tree under review is FROZEN until collected (work outside the diff; no stash / reset / checkout); collect with: rolepod-cross-family --collect $JOB_ID --root $ROOT   (list: --jobs --root $ROOT). The chain falls through on its own and anchors the receipt; the commit gate sees the job."
  exit 0
fi
TMPP=$(mktemp -d "${TMPDIR:-/tmp}/rolepod-xfam.XXXXXX")

# Body = brief + attachments (shared); each member gets its own preamble +
# time budget so the model plans for its deadline instead of exploring.
BODY="$TMPP/body.md"
{
  cat "$BRIEF"
  if [ -n "$ATTACH" ]; then
    printf '%s\n' "$ATTACH" | while IFS= read -r a; do
      [ -f "$a" ] || continue
      printf '\n\n--- attached: %s ---\n```\n' "$(basename "$a")"; cat "$a"; printf '\n```\n'
    done
  fi
} > "$BODY"
preamble() { # $1 kind
  case "$1" in
    review) printf '%s' "You are a cold-context ADVERSARIAL code reviewer running in a different CLI than the author. Read only — never edit files, never run write commands. Try to make the change fail. Report findings severity-ordered (BLOCKER / MAJOR / MINOR / NIT) with file:line, label each TRACED (path walked) or SUSPECTED (pattern-level), name what is missing as hard as what is present, then end with one line: VERDICT: APPROVED | APPROVED-WITH-NITS | REJECTED. Label every finding's provenance: INTRODUCED (this diff caused it), EXPOSED (pre-existing, on a path this diff changes) or ADJACENT (pre-existing, path untouched) — the diff is the scope, ADJACENT findings are reported once under their own heading and never drive the verdict. If a previous round's report is attached, also prefix every finding with IN-FIX (a defect inside the previous round's fixes), NEW (not flagged before) or REPEAT (flagged before, still open); an ADJACENT item already listed there is not repeated." ;;
    consult) printf '%s' "You are a cold-context debugging advisor running in a different CLI than the author. The author has failed twice; do not repeat their fixes. Read only — never edit files. Return exactly one of: CORRECTION (new hypothesis + the smallest change to test it), CONFIRMATION (approach right — check X), or STOP (wrong path — why). Reason from the evidence given; say what you would verify first." ;;
    advise) printf '%s' "You are a cold-context planning advisor running in a different CLI than the author. Advise, never execute: return a RECOMMENDED option with reasoning and the risks you see, or a CORRECTION if the framing or all options are flawed, or a STOP signal. Do not edit files or run the plan." ;;
    critique) printf '%s' "You are a cold-context spec critic running in a different CLI than the author. The author has finished their discovery dialogue with the user (the questions already asked and answered are attached — never re-ask those). Return AT MOST 5 items, ranked by implementation risk, each tagged QUESTION (a decision only the user can make — the answer would change the implementation), AMBIGUITY (wording two engineers would read differently — quote it), or MISSING (an acceptance criterion, failure mode, or edge case with no 'proven by'). No design proposals, no praise, no restating the spec. If nothing material remains, reply exactly: NO FURTHER QUESTIONS." ;;
  esac
}
budget_line() { # $1 seconds
  _m=$(( ($1 + 59) / 60 ))
  printf 'Time budget: about %s minute(s) — a hard stop kills the run and loses everything. The brief and attachments are complete: do NOT run builds, test suites, linters, or package managers; read only the files the diff touches when you need surrounding context, and start writing your answer well before the budget ends. If the budget is nearly spent, stop and output what you have, prefixed PARTIAL.' "$_m"
}
BBYTES=$(wc -c < "$BODY" | tr -d ' ')
# codex / claude take the prompt on stdin (400 KB cap); agy / cursor / opencode
# take it as ONE argv string — Linux caps a single argument at 128 KiB
# (MAX_ARG_STRLEN), so those get 118 000 bytes. Over the cap → that member is
# skipped with a logged reason rather than failing at exec with E2BIG.
[ "$BBYTES" -le 398000 ] || { echo "cross-family: brief + attachments are ${BBYTES} bytes (>398000) — trim them" >&2; exit 2; }
ARGV_CAP=118000
mkdir -p "$EV/external" 2>/dev/null || true
BRIEF_SHA=$( { shasum -a 256 "$BODY" 2>/dev/null || sha256sum "$BODY" 2>/dev/null; } | awk '{print substr($1,1,12)}')
JOB_ID_TAG=""; [ -n "$JOB_DIR" ] && JOB_ID_TAG=$(basename "$JOB_DIR")
RUN_TAG="${JOB_ID_TAG:-fg-$$}"

one() { # $1 cli → 0 ok / 1 fail; writes $TMPP/$1.{out,err,line,jsonl} — the PARENT appends .jsonl
  _c="$1"; _f=$(family_of "$_c"); _ts=$(date -u +%Y%m%dT%H%M%SZ)
  TIMEOUT=$(timeout_for "$_c")
  case "$_c" in codex|claude) ;; *) if [ "$BBYTES" -gt "$ARGV_CAP" ]; then
    printf '{"ts":"%s","phase":"external-fail","kind":"%s","cli":"%s","family":"%s","lead":"%s","reason":"prompt %s bytes exceeds the %s-byte argv cap for %s — trim attachments"}\n' \
      "$(iso_now)" "$KIND" "$_c" "$_f" "$LEAD" "$BBYTES" "$ARGV_CAP" "$_c" > "$TMPP/$_c.jsonl"
    printf '%s: prompt %s bytes > argv cap %s\n' "$_c" "$BBYTES" "$ARGV_CAP" > "$TMPP/$_c.line"; return 1; fi ;; esac
  { preamble "$KIND"; printf '\n\n'; budget_line "$TIMEOUT"; printf '\n\n'; cat "$BODY"; } > "$TMPP/$_c.prompt"
  if [ -z "$JOB_DIR" ] && [ "$TIMEOUT" -gt 600 ]; then
    echo "⚠ $_c budget ${TIMEOUT}s exceeds the 600 s foreground cap of the Claude Bash tool — prefer --detach (job + --collect) so the harness cannot kill the chain mid-run" >&2
  fi
  echo "→ $_c ($_f) · $KIND · budget ${TIMEOUT}s" >&2
  _s=$SECONDS; invoke "$_c" "$TMPP/$_c.prompt" "$TMPP/$_c.out"; _rc=$?; _secs=$(( SECONDS - _s ))
  # codex streams its event log to stderr; the reviewer's answer is the -o message file
  if [ "$_c" = "codex" ] && [ -s "$TMPP/$_c.out.msg" ]; then mv "$TMPP/$_c.out" "$TMPP/$_c.out.stream"; mv "$TMPP/$_c.out.msg" "$TMPP/$_c.out"; fi
  _bytes=$(wc -c < "$TMPP/$_c.out" | tr -d ' ')
  # Record what actually ran (the CLI's own banner / header): the family follows the reported model.
  # Information only — a member is never failed for its model family; a different CLI is the point (owner rule).
  _ran=$(ran_model_of "$_c" "$TMPP/$_c.out"); _ranfam=""
  if [ -n "$_ran" ]; then _ranfam=$(classify_model "$_ran"); [ "$_ranfam" != "unknown" ] && _f="$_ranfam"; fi
  _floor=200; [ "$KIND" = "review" ] && _floor=500   # the commit gate's raw-file floor
  _partial=""; head -c 400 "$TMPP/$_c.out" 2>/dev/null | grep -q 'PARTIAL' && _partial=" partial=1"
  _verdict=1; if [ "$KIND" = "review" ]; then grep -qi 'VERDICT' "$TMPP/$_c.out" 2>/dev/null || _verdict=0; fi
  # A review that ran out of budget (PARTIAL) or never reached its VERDICT line
  # is information for the Lead, never the strong pass: it is kept as
  # *.partial.txt, logged as external-fail, and the chain moves on.
  if [ "$_rc" -eq 0 ] && [ "$_bytes" -ge "$_floor" ] && [ "$KIND" = "review" ] && { [ -n "$_partial" ] || [ "$_verdict" -eq 0 ]; }; then
    _rc=125
  fi
  if [ "$_rc" -eq 0 ] && [ "$_bytes" -ge "$_floor" ]; then
    _raw="external/$_ts-$_c-$RUN_TAG.txt"
    { printf '# rolepod cross-family %s · cli=%s family=%s lead=%s (%s) · %s · exit=%s secs=%s bytes=%s budget=%ss%s%s\n# brief: %s\n\n' \
        "$KIND" "$_c" "$_f" "$LEAD" "$LEAD_FAMILY" "$(iso_now)" "$_rc" "$_secs" "$_bytes" "$TIMEOUT" "$_partial" "${_ran:+ ran=$_ran}" "$BRIEF"
      cat "$TMPP/$_c.out"; } > "$EV/$_raw" 2>/dev/null || true
    printf '%s\n' "{\"ts\":\"$(iso_now)\",\"phase\":\"$PHASE\",\"reviewer\":\"external\",\"kind\":\"$KIND\",\"cli\":\"$_c\",\"family\":\"$_f\",\"model\":\"default\",\"raw\":\"$_raw\",\"lead\":\"$LEAD\",\"secs\":$_secs,\"budget\":$TIMEOUT,\"brief_sha\":\"$BRIEF_SHA\"${JOB_ID_TAG:+,\"job\":\"$JOB_ID_TAG\"}${_partial:+,\"partial\":true}${_ran:+,\"ran\":\"$(jesc "$_ran")\"}}" > "$TMPP/$_c.jsonl"
    printf 'ROLEPOD-XFAM ok kind=%s cli=%s family=%s raw=.rolepod/evidence/%s secs=%s budget=%ss%s%s\n' "$KIND" "$_c" "$_f" "$_raw" "$_secs" "$TIMEOUT" "$_partial" "${_ran:+ ran=$_ran}" > "$TMPP/$_c.line"
    return 0
  fi
  _why="exit $_rc"; [ "$_rc" -eq 124 ] && _why="timeout ${TIMEOUT}s"
  [ "$_rc" -eq 0 ] && _why="empty output ($_bytes bytes, floor $_floor)"
  _suffix="failed"
  if [ "$_rc" -eq 125 ]; then _suffix="partial"; if [ -n "$_partial" ]; then _why="PARTIAL review (budget nearly spent) — kept as evidence, not a pass"; else _why="review has no VERDICT line (incomplete) — kept as evidence, not a pass"; fi; fi
  _first=$(head -c 160 "$TMPP/$_c.out.err" 2>/dev/null | tr '\n' ' ')
  { printf '# rolepod cross-family %s %s · cli=%s family=%s lead=%s · %s · %s · budget=%ss · run=%s\n\n--- stdout ---\n' "$KIND" "$(printf '%s' "$_suffix" | tr a-z A-Z)" "$_c" "$_f" "$LEAD" "$(iso_now)" "$_why" "$TIMEOUT" "$RUN_TAG"
    cat "$TMPP/$_c.out"; printf '\n--- stderr ---\n'; cat "$TMPP/$_c.out.err"; } > "$EV/external/$_ts-$_c-$RUN_TAG.$_suffix.txt" 2>/dev/null || true
  printf '%s\n' "{\"ts\":\"$(iso_now)\",\"phase\":\"external-fail\",\"kind\":\"$KIND\",\"cli\":\"$_c\",\"family\":\"$_f\",\"lead\":\"$LEAD\",\"secs\":$_secs,\"brief_sha\":\"$BRIEF_SHA\"${JOB_ID_TAG:+,\"job\":\"$JOB_ID_TAG\"},\"reason\":\"$(jesc "$_why: $_first")\"${_ran:+,\"ran\":\"$(jesc "$_ran")\"}}" > "$TMPP/$_c.jsonl"
  printf '%s: %s%s\n' "$_c" "$_why" "${_first:+ — $_first}" > "$TMPP/$_c.line"
  [ "$_rc" -eq 125 ] && printf '  (partial text kept: .rolepod/evidence/external/%s-%s-%s.partial.txt)\n' "$_ts" "$_c" "$RUN_TAG" >> "$TMPP/$_c.line"
  return 1
}

if [ "$ALL" -eq 1 ]; then
  # Panel: every usable member concurrently — each CLI is one opinion (owner rule:
  # a different CLI is the point; the model family is recorded, never a filter).
  PANEL="$USABLE"
  for c in $PANEL; do one "$c" & done; wait
  for c in $PANEL; do [ -f "$TMPP/$c.jsonl" ] && jlog "$(cat "$TMPP/$c.jsonl")"; done   # serial appends — no interleaving
  OK=0
  for c in $PANEL; do
    if [ -f "$TMPP/$c.line" ] && grep -q '^ROLEPOD-XFAM ok' "$TMPP/$c.line"; then
      printf '\n===== %s =====\n' "$c"; cat "$TMPP/$c.out"; echo; cat "$TMPP/$c.line"; OK=$((OK+1))
    else
      printf '\n===== %s — FAILED: %s\n' "$c" "$(cat "$TMPP/$c.line" 2>/dev/null)"
    fi
  done
  [ "$OK" -gt 0 ] && exit 0
  echo "ROLEPOD-XFAM none — every panel member failed. Fall back to the internal path and record the limitation."
  exit 3
fi

FAILS=""
for c in $USABLE; do
  one "$c"; _ok=$?
  [ -f "$TMPP/$c.jsonl" ] && jlog "$(cat "$TMPP/$c.jsonl")"
  if [ "$_ok" -eq 0 ]; then cat "$TMPP/$c.out"; echo; cat "$TMPP/$c.line"; exit 0; fi
  FAILS="$FAILS${FAILS:+; }$(cat "$TMPP/$c.line")"
done
echo "ROLEPOD-XFAM none — $FAILS. Fall back to the internal strong reviewer / vertical consult and record the limitation."
exit 3
