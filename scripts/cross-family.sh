#!/bin/bash
# rolepod cross-family runner — ONE command for every cross-CLI opinion:
# the adversarial review pass, the plan advisory panel, the stuck-state
# consult. Installed as `rolepod-cross-family` (install.sh) and shipped in
# every plugin tree as scripts/cross-family.sh.
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
#            ~/.rolepod/cross-family (machine); one CLI per line in preference
#            order (codex claude agy cursor opencode), `#` comments. NO file =
#            OFF, `none` = OFF — rolepod never enables cross-family on its own:
#            the SessionStart loader asks the user ONCE (installed candidates
#            listed), the answer is written to the file (names, or `none`).
#            `gemini` is retired: Google moved individual accounts to
#            Antigravity (agy) — a `gemini` line is skipped with a note; a
#            Gemini-CLI Lead is still recognised for family exclusion.
#   family   the Lead's own model FAMILY is excluded (gemini ≡ agy = google;
#            cursor / opencode resolve to the family of their configured
#            default model, else `unknown` — used, but flagged).
#   model    NEVER a model or effort flag. TIER_MODELS applies only to the CLI
#            that is the Lead; an external runs whatever its owner set as
#            default. The phase-log records model:"default".
#   read-only every invocation uses the CLI's read-only / plan mode; the
#            prompt says so too. ROLEPOD_BRAIN_SILENT=1 keeps ambient memory
#            out of the cold run (clean room).
#   health   installed ≠ usable: exit≠0, timeout, or too little output (review
#            < 500 bytes — the gate's floor; consult / advise < 200) → next member;
#            every failure is a phase-log line; all fail → exit 3; configured
#            but nothing usable → exit 4 (logged); OFF → exit 5 (not logged —
#            the user's choice is not a failure). The Lead then runs its own path.
#   evidence .rolepod/evidence/external/<utc>-<cli>.txt + one phase-log line
#            ({"phase":"review","reviewer":"external",...} is what
#            precommit-gate counts as the strong pass; consult / advise
#            lines feed `rolepod-stats`).
#
# Usage:
#   cross-family.sh --kind review|consult|advise|critique --brief <file> [--attach <file>]...
#                   (critique = spec critic: ≤5 ranked open questions / ambiguities / missing criteria)
#                   [--lead <cli>] [--all] [--timeout <sec>]   (default 600s = the Claude Bash
#                   cap; a big diff → run in the background and read the raw file)
#   cross-family.sh --pool [--lead <cli>]          # usable pool, no network
#   cross-family.sh --pool-names [--lead <cli>]    # names only (hooks use this)
#   cross-family.sh --probe [--lead <cli>]         # live "reply OK" per member
#   cross-family.sh --candidates                   # installed other-family CLIs (for the opt-in question)
# Exit: 0 ok · 2 usage · 3 every member failed · 4 configured pool empty · 5 off (opt-in not given)
set -uo pipefail

KIND=""; BRIEF=""; LEAD="${ROLEPOD_LEAD_CLI:-}"; ALL=0; TIMEOUT="${ROLEPOD_XFAM_TIMEOUT:-600}"
MODE="run"; ATTACH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --kind) KIND="${2:-}"; shift 2 ;;
    --brief) BRIEF="${2:-}"; shift 2 ;;
    --attach) ATTACH="$ATTACH${ATTACH:+
}${2:-}"; shift 2 ;;
    --lead) LEAD="${2:-}"; shift 2 ;;
    --all) ALL=1; shift ;;
    --timeout) TIMEOUT="${2:-900}"; shift 2 ;;
    --pool) MODE="pool"; shift ;;
    --pool-names) MODE="pool-names"; shift ;;
    --probe) MODE="probe"; shift ;;
    --candidates) MODE="candidates"; shift ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "cross-family: unknown argument: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
EV="$ROOT/.rolepod/evidence"
ALL_CLIS="codex claude agy cursor opencode"
LEAD_CLIS="$ALL_CLIS gemini"

# ── Lead detection ─────────────────────────────────────────────────────
# Explicit --lead / ROLEPOD_LEAD_CLI wins (the adapters' hooks.json sets it
# on Codex). Otherwise the CLIs' own child-env markers. Unknown → refuse:
# without the Lead's family the exclusion rule cannot run.
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
classify_model() { # model / provider string → family
  _m=$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')
  case "$_m" in
    "") echo unknown ;;
    *anthropic*|*claude*) echo anthropic ;;
    *openai*|*gpt*|*codex*|o1*|o3*|o4*) echo openai ;;
    *google*|*gemini*) echo google ;;
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
  _f=""
  for _c in "$ROOT/opencode.jsonc" "$ROOT/opencode.json" \
            "${OPENCODE_CONFIG_DIR:-}/opencode.jsonc" "${OPENCODE_CONFIG_DIR:-}/opencode.json" \
            "$HOME/.config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.json"; do
    [ -n "$_c" ] && [ "$_c" != "/opencode.jsonc" ] && [ "$_c" != "/opencode.json" ] || continue
    _f=$(json_model_field "$_c"); [ -n "$_f" ] && { printf '%s' "$_f"; return; }
  done
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

# ── Candidates (installed, not the Lead's family) — the opt-in question ──
CANDIDATES=""
for cli in $ALL_CLIS; do
  [ -n "$(bin_of "$cli")" ] || continue
  [ "$cli" = "$LEAD" ] && continue
  fam=$(family_of "$cli"); [ "$fam" != "unknown" ] && [ "$fam" = "$LEAD_FAMILY" ] && continue
  CANDIDATES="$CANDIDATES${CANDIDATES:+ }$cli($fam)"
done
if [ "$MODE" = "candidates" ]; then printf '%s\n' $CANDIDATES; exit 0; fi

# ── Pool from config (opt-in: no file = off) ───────────────────────────
CFG=""; CFG_SRC=""; STATE="on"
if [ -f "$ROOT/.rolepod/cross-family" ]; then CFG="$ROOT/.rolepod/cross-family"; CFG_SRC="$CFG"
elif [ -f "$HOME/.rolepod/cross-family" ]; then CFG="$HOME/.rolepod/cross-family"; CFG_SRC="$CFG"; fi
if [ -n "$CFG" ]; then
  CONFIGURED=$(sed -e 's/#.*//' "$CFG" 2>/dev/null | tr 'A-Z' 'a-z' | tr -s '[:space:]' ' ')
  printf '%s' "$CONFIGURED" | grep -qw none && STATE="none"
  [ -z "$(printf '%s' "$CONFIGURED" | tr -d ' ')" ] && STATE="none"
else
  CONFIGURED=""; STATE="off"; CFG_SRC="no ~/.rolepod/cross-family (opt-in not given)"
fi
ENABLE_HINT="enable: printf 'agy\\ncodex\\n' > ~/.rolepod/cross-family  (one CLI per line, your order; project override: <git-root>/.rolepod/cross-family; 'none' = keep off)"

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
    if [ "$fam" != "unknown" ] && [ "$fam" = "$LEAD_FAMILY" ]; then POOL_ROWS="$POOL_ROWS
$cli  skipped  $fam  same family as the Lead ($LEAD)"; continue; fi
    note="bin=$bin"
    case " $SEEN_FAMILIES " in *" $fam "*) [ "$fam" != "unknown" ] && note="$note · same family as an earlier member — sequential fallback only, not in --all" ;; esac
    if [ "$fam" = "unknown" ]; then
      case "$cli" in
        cursor) note="$note · family unknown: no \"model\" in ~/.cursor/cli-config.json — decorrelation unverified" ;;
        opencode) note="$note · family unknown: no \"model\" in opencode.json(c) — decorrelation unverified" ;;
      esac
    fi
    POOL_ROWS="$POOL_ROWS
$cli  usable  $fam  $note"
    USABLE="$USABLE${USABLE:+ }$cli"
    SEEN_FAMILIES="$SEEN_FAMILIES $fam"
  done
fi

print_pool() {
  echo "cross-family pool — lead=$LEAD ($LEAD_FAMILY) · config: $CFG_SRC"
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
# stdout → $2, stderr → $2.err; bash-3.2-safe timeout (macOS ships no `timeout`).
RUN_STDIN=/dev/null
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
invoke() { # $1 cli, $2 promptfile, $3 outfile
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
iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
jlog() { # append one phase-log line, fail-open
  mkdir -p "$EV" 2>/dev/null || return 0
  printf '%s\n' "$1" >> "$EV/phase-log.jsonl" 2>/dev/null || true
}
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
  TMPP=$(mktemp -d "${TMPDIR:-/tmp}/rolepod-xfam.XXXXXX"); trap 'rm -rf "$TMPP"' EXIT
  printf 'Reply with exactly the word OK and nothing else. Do not read files, do not run commands.\n' > "$TMPP/p.txt"
  TIMEOUT="${TIMEOUT:-120}"; [ "$TIMEOUT" -gt 180 ] && TIMEOUT=180
  echo "probe (timeout ${TIMEOUT}s each):"
  rc_all=3
  for cli in $USABLE; do
    s=$SECONDS; invoke "$cli" "$TMPP/p.txt" "$TMPP/$cli.out"; rc=$?; secs=$(( SECONDS - s ))
    [ "$cli" = "codex" ] && [ -s "$TMPP/$cli.out.msg" ] && mv "$TMPP/$cli.out.msg" "$TMPP/$cli.out"
    bytes=$(wc -c < "$TMPP/$cli.out" | tr -d ' ')
    if [ "$rc" -eq 0 ] && [ "$bytes" -gt 0 ]; then
      printf '  %-9s ok    %3ss  %s\n' "$cli" "$secs" "$(head -c 60 "$TMPP/$cli.out" | tr '\n' ' ')"; rc_all=0
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

TMPP=$(mktemp -d "${TMPDIR:-/tmp}/rolepod-xfam.XXXXXX"); trap 'rm -rf "$TMPP"' EXIT
PROMPT="$TMPP/prompt.md"
{
  case "$KIND" in
    review) printf '%s\n\n' "You are a cold-context ADVERSARIAL code reviewer from a different model family than the author. Read only — never edit files, never run write commands. Try to make the change fail. Report findings severity-ordered (BLOCKER / MAJOR / MINOR / NIT) with file:line, label each TRACED (path walked) or SUSPECTED (pattern-level), name what is missing as hard as what is present, then end with one line: VERDICT: APPROVED | APPROVED-WITH-NITS | REJECTED." ;;
    consult) printf '%s\n\n' "You are a cold-context debugging advisor from a different model family. The author has failed twice; do not repeat their fixes. Read only — never edit files. Return exactly one of: CORRECTION (new hypothesis + the smallest change to test it), CONFIRMATION (approach right — check X), or STOP (wrong path — why). Reason from the evidence given; say what you would verify first." ;;
    advise) printf '%s\n\n' "You are a cold-context planning advisor from a different model family. Advise, never execute: return a RECOMMENDED option with reasoning and the risks you see, or a CORRECTION if the framing or all options are flawed, or a STOP signal. Do not edit files or run the plan." ;;
    critique) printf '%s\n\n' "You are a cold-context spec critic from a different model family. The author has finished their discovery dialogue with the user (the questions already asked and answered are attached — never re-ask those). Return AT MOST 5 items, ranked by implementation risk, each tagged QUESTION (a decision only the user can make — the answer would change the implementation), AMBIGUITY (wording two engineers would read differently — quote it), or MISSING (an acceptance criterion, failure mode, or edge case with no 'proven by'). No design proposals, no praise, no restating the spec. If nothing material remains, reply exactly: NO FURTHER QUESTIONS." ;;
  esac
  cat "$BRIEF"
  if [ -n "$ATTACH" ]; then
    printf '%s\n' "$ATTACH" | while IFS= read -r a; do
      [ -f "$a" ] || continue
      printf '\n\n--- attached: %s ---\n```\n' "$(basename "$a")"; cat "$a"; printf '\n```\n'
    done
  fi
} > "$PROMPT"
PBYTES=$(wc -c < "$PROMPT" | tr -d ' ')
# codex / claude take the prompt on stdin (400 KB cap); agy / cursor / opencode
# take it as ONE argv string — Linux caps a single argument at 128 KiB
# (MAX_ARG_STRLEN), so those get 120 000 bytes. Over the cap → that member is
# skipped with a logged reason rather than failing at exec with E2BIG.
[ "$PBYTES" -le 400000 ] || { echo "cross-family: prompt is ${PBYTES} bytes (>400000) — trim the brief / attachments" >&2; exit 2; }
ARGV_CAP=120000
mkdir -p "$EV/external" 2>/dev/null || true

one() { # $1 cli → 0 ok / 1 fail; writes $TMPP/$1.{out,err,line,jsonl} — the PARENT appends .jsonl
  _c="$1"; _f=$(family_of "$_c"); _ts=$(date -u +%Y%m%dT%H%M%SZ)
  case "$_c" in codex|claude) ;; *) if [ "$PBYTES" -gt "$ARGV_CAP" ]; then
    printf '{"ts":"%s","phase":"external-fail","kind":"%s","cli":"%s","family":"%s","lead":"%s","reason":"prompt %s bytes exceeds the %s-byte argv cap for %s — trim attachments"}\n' \
      "$(iso_now)" "$KIND" "$_c" "$_f" "$LEAD" "$PBYTES" "$ARGV_CAP" "$_c" > "$TMPP/$_c.jsonl"
    printf '%s: prompt %s bytes > argv cap %s\n' "$_c" "$PBYTES" "$ARGV_CAP" > "$TMPP/$_c.line"; return 1; fi ;; esac
  echo "→ $_c ($_f) · $KIND · timeout ${TIMEOUT}s" >&2
  _s=$SECONDS; invoke "$_c" "$PROMPT" "$TMPP/$_c.out"; _rc=$?; _secs=$(( SECONDS - _s ))
  # codex streams its event log to stdout; the reviewer's answer is the -o message file
  if [ "$_c" = "codex" ] && [ -s "$TMPP/$_c.out.msg" ]; then mv "$TMPP/$_c.out" "$TMPP/$_c.out.stream"; mv "$TMPP/$_c.out.msg" "$TMPP/$_c.out"; fi
  _bytes=$(wc -c < "$TMPP/$_c.out" | tr -d ' ')
  _floor=200; [ "$KIND" = "review" ] && _floor=500   # the commit gate's raw-file floor
  if [ "$_rc" -eq 0 ] && [ "$_bytes" -ge "$_floor" ]; then
    _raw="external/$_ts-$_c.txt"
    { printf '# rolepod cross-family %s · cli=%s family=%s lead=%s (%s) · %s · exit=%s secs=%s bytes=%s\n# brief: %s\n\n' \
        "$KIND" "$_c" "$_f" "$LEAD" "$LEAD_FAMILY" "$(iso_now)" "$_rc" "$_secs" "$_bytes" "$BRIEF"
      cat "$TMPP/$_c.out"; } > "$EV/$_raw" 2>/dev/null || true
    printf '%s\n' "{\"ts\":\"$(iso_now)\",\"phase\":\"$PHASE\",\"reviewer\":\"external\",\"kind\":\"$KIND\",\"cli\":\"$_c\",\"family\":\"$_f\",\"model\":\"default\",\"raw\":\"$_raw\",\"lead\":\"$LEAD\",\"secs\":$_secs}" > "$TMPP/$_c.jsonl"
    printf 'ROLEPOD-XFAM ok kind=%s cli=%s family=%s raw=.rolepod/evidence/%s secs=%s\n' "$KIND" "$_c" "$_f" "$_raw" "$_secs" > "$TMPP/$_c.line"
    return 0
  fi
  _why="exit $_rc"; [ "$_rc" -eq 124 ] && _why="timeout ${TIMEOUT}s"
  [ "$_rc" -eq 0 ] && _why="empty output ($_bytes bytes, floor $_floor)"
  _first=$(head -c 160 "$TMPP/$_c.out.err" 2>/dev/null | tr '\n' ' ')
  { printf '# rolepod cross-family %s FAILED · cli=%s family=%s lead=%s · %s · %s\n\n--- stdout ---\n' "$KIND" "$_c" "$_f" "$LEAD" "$(iso_now)" "$_why"
    cat "$TMPP/$_c.out"; printf '\n--- stderr ---\n'; cat "$TMPP/$_c.out.err"; } > "$EV/external/$_ts-$_c.failed.txt" 2>/dev/null || true
  printf '%s\n' "{\"ts\":\"$(iso_now)\",\"phase\":\"external-fail\",\"kind\":\"$KIND\",\"cli\":\"$_c\",\"family\":\"$_f\",\"lead\":\"$LEAD\",\"reason\":\"$(jesc "$_why: $_first")\"}" > "$TMPP/$_c.jsonl"
  printf '%s: %s%s\n' "$_c" "$_why" "${_first:+ — $_first}" > "$TMPP/$_c.line"
  return 1
}

if [ "$ALL" -eq 1 ]; then
  # Panel: one member per family, concurrently. Same-family duplicates stay
  # sequential fallbacks (they only add a harness, not a second opinion).
  PANEL=""; FAMS=""
  for c in $USABLE; do f=$(family_of "$c"); case " $FAMS " in *" $f "*) [ "$f" != "unknown" ] && continue ;; esac; PANEL="$PANEL${PANEL:+ }$c"; FAMS="$FAMS $f"; done
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
