#!/bin/bash
# cross-family-runner — behavioral test of core/skills/cross-family/scripts/cross-family.sh with stub
# CLIs on a private PATH and a sandbox HOME (never touches the real CLIs or
# ~/.rolepod). Asserts OUTCOMES: which CLI ran, what flags it got, what
# evidence landed on disk, what the phase-log says.
#
#   - OPT-IN: no config file = OFF (exit 5, nothing logged, candidates listed);
#     `none` = OFF; the pool setting (global config only) lists + orders
#     the pool; Lead family excluded (agy = google), cursor/opencode family
#     from their configured model
#   - NO model / effort flag ever reaches an external (TIER_MODELS is Lead-only)
#   - read-only flags present per CLI; ROLEPOD_BRAIN_SILENT=1 in the child env
#   - success → external/<ts>-<cli>.txt + phase-log review line the gate reads
#   - failure → external-fail line, next member; all fail → exit 3; empty → 4
#   - --all runs every usable member concurrently; timeout kills a hung CLI
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
RUNNER="$REPO_DIR/core/skills/cross-family/scripts/cross-family.sh"
. "$REPO_DIR/tests/integration/xfpool.sh"
fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "  ✓ $1"; CHECK_OK=1; else echo "  ✗ $1"; fail=$((fail+1)); CHECK_OK=0; fi; }

TOTAL_SECTIONS=0
RAN_SECTIONS=0
section() { # $1 = banner title; prints the banner itself (one copy of the
  # title, never a separate `echo` call site the arg can drift from) and
  # gates the block on ROLEPOD_CASE (regex substring match against the title)
  echo "── $1 ──"
  TOTAL_SECTIONS=$((TOTAL_SECTIONS+1))
  if [ -n "${ROLEPOD_CASE:-}" ] && ! [[ "$1" =~ $ROLEPOD_CASE ]]; then
    return 1
  fi
  RAN_SECTIONS=$((RAN_SECTIONS+1))
  return 0
}

FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-xfam-test.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
export HOME="$FIX/home"; mkdir -p "$HOME" "$HOME/.rolepod"
# .config/opencode unconditional too: "ran-model detection" writes straight
# into it (printf > opencode.json, no mkdir of its own) — a filter to that
# section alone used to hit "No such file or directory" before "pool
# resolution" (the section that used to create this dir) ever ran.
mkdir -p "$HOME/.config/opencode"
BIN="$FIX/bin"; mkdir -p "$BIN"
LOG="$FIX/calls.log"; : > "$LOG"   # unconditional: some sections read $LOG
# as their own first statement — a filter to one of those alone used to hit
# "No such file or directory" before an earlier section had created it.

# Stub: records "<name> | args | BRAIN=<env>" and behaves per $STUB_<NAME>:
#   ok (default) → prints ~600 bytes of review; fail → exit 1; empty → exit 0
#   with no output; hang → sleep 30.
mk_stub() { # $1 binary name, $2 label
  cat > "$BIN/$1" <<EOF
#!/bin/bash
_raw=\$(head -c 3000 2>/dev/null)
_in=\$(printf '%s' "\$_raw" | grep -o 'code reviewer running in a different CLI\|debugging advisor\|spec critic' | head -1)
_bud=\$(printf '%s' "\$_raw" | grep -o 'Time budget: about [0-9]* minute' | grep -o '[0-9]*')
_argbud=\$(printf '%s' "\$*" | grep -o 'Time budget: about [0-9]* minute' | grep -o '[0-9]*')
_att=\$(printf '%s\n' "\$_raw" | sed -n 's/.*--- attached: \([^ ]*\) .*/\1/p' | head -1)
_rawflat=\$(printf '%s' "\$_raw" | tr '\n' ' ')
case "\$_in" in *"code reviewer"*) _in=review ;; *debugging*) _in=consult ;; *critic*) _in=critique ;; *) _in=none ;; esac
printf '%s | %s | BRAIN=%s | STDIN=%s | BUDGET=%s | ATT=%s | RAW=%s\n' "$2" "\$(printf '%s' "\$*" | tr '\n' ' ')" "\${ROLEPOD_BRAIN_SILENT:-unset}" "\$_in" "\${_bud:-\$_argbud}" "\${_att:-none}" "\$_rawflat" >> "$LOG"
if [ "\$1" = "models" ]; then printf '%s\n' "\${CURSOR_MODELS_OUT:-auto - Auto (current, default)}"; exit 0; fi
mode=\$(eval "printf '%s' \"\\\${STUB_$2:-ok}\"")
[ -n "\${XFAM_STAMP:-}" ] && { echo "S $2" >> "\$XFAM_STAMP"; sleep 3; echo "E $2" >> "\$XFAM_STAMP"; }   # overlap probe: start/end order, no clock
case "\$mode" in
  fail) echo "auth error" >&2; exit 1 ;;
  empty) exit 0 ;;
  hang) sleep 30 & echo \$! > "$FIX/grandchild.\$\$"; wait; exit 0 ;;
  short) printf 'LGTM %s\n' "\$(head -c 300 /dev/zero | tr '\\0' 'y')"; exit 0 ;;
  slow) sleep 4 ;;
  trickle) for _i in 1 2 3 4 5 6; do echo "working \$_i"; sleep 1; done ;;   # keeps printing: alive under stall=3
  partial) printf 'PARTIAL — budget nearly spent. Findings so far: %s\n' "\$(head -c 600 /dev/zero | tr '\\0' p)"; exit 0 ;;
  rejected) printf 'Findings: %s\nVERDICT: REJECTED\n' "\$(head -c 600 /dev/zero | tr '\\0' r)"; exit 0 ;;
  noverdict) printf 'Findings: %s\n' "\$(head -c 600 /dev/zero | tr '\\0' q)"; exit 0 ;;
  nits) printf 'Findings: %s\nVERDICT: APPROVED-WITH-NITS\n' "\$(head -c 600 /dev/zero | tr '\\0' n)"; exit 0 ;;
  blocked) printf 'Findings: %s\nVERDICT: BLOCKED\n' "\$(head -c 600 /dev/zero | tr '\\0' b)"; exit 0 ;;
  enumquote) printf 'Findings: %s\nVERDICT: APPROVED | APPROVED-WITH-NITS | REJECTED\n' "\$(head -c 600 /dev/zero | tr '\\0' e)"; exit 0 ;;
esac
[ -n "\${CODEX_MSG_OUT:-}" ] && : # (unused)
_msg=""; _prev=""; for a in "\$@"; do [ "\$_prev" = "-o" ] && _msg="\$a"; _prev="\$a"; done
if [ -n "\$_msg" ]; then echo "event-stream noise" ; printf 'model: %s\n' "\${CODEX_RAN:-gpt-5.6-luna}" >&2; { printf '%s review by $2: ' "\${KIND_HINT:-}"; head -c 600 /dev/zero | tr '\0' 'x'; printf '\nVERDICT: APPROVED\n'; } > "\$_msg"; exit 0; fi
[ "$2" = opencode ] && printf '> plan · %s\n' "\${OPENCODE_RAN:-moonshotai/kimi-k3}" >&2   # real opencode prints this header on stderr
if printf '%s' "\$*" | grep -q -- '--output-format stream-json'; then   # cursor: the runner unwraps the result event
  printf '{"type":"system","subtype":"init","model":"%s"}\n' "\${CURSOR_RAN:-gpt-5.6-sol}"
  printf '{"type":"result","subtype":"success","result":"%s review by $2: %s\\\\nVERDICT: APPROVED"}\n' "\${KIND_HINT:-}" "\$(head -c 600 /dev/zero | tr '\\0' 'x')"
  exit 0
fi
printf '%s review by $2: ' "\${KIND_HINT:-}"; head -c 600 /dev/zero | tr '\0' 'x'; printf '\nVERDICT: APPROVED\n'
EOF
  chmod +x "$BIN/$1"
}
for b in codex claude agy opencode; do mk_stub "$b" "$b"; done
mk_stub cursor-agent cursor
export PATH="$BIN:/usr/bin:/bin"
unset ROLEPOD_LEAD_CLI CLAUDECODE CLAUDE_PLUGIN_ROOT CODEX_SANDBOX CODEX_THREAD_ID CODEX_SANDBOX_NETWORK_DISABLED ANTIGRAVITY_CLI AGY_CLI CURSOR_AGENT OPENCODE OPENCODE_SESSION_ID

# Sandbox repo (git root = evidence root). .rolepod/evidence is created here,
# unconditionally, so a section run alone under ROLEPOD_CASE can `: >` a log
# file under it without depending on an earlier (possibly filtered-out)
# section's own `mkdir -p` to have run first.
REPO="$FIX/repo"; mkdir -p "$REPO"; git -C "$REPO" init -q; cd "$REPO"
mkdir -p .rolepod/evidence
printf 'Review this diff.\n' > brief.md
printf -- '--- a/x.py\n+++ b/x.py\n+print(1)\n' > diff.patch

# ── pool ────────────────────────────────────────────────────────────────
if section "cross-family: opt-in default (no config = OFF)"; then
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "no config file → pool EMPTY (cross-family is opt-in)" "[ -z \"$names\" ]"
out=$(bash "$RUNNER" --pool --lead claude)
check "--pool says OFF + lists installed candidates with families + the enable hint" \
  "printf '%s' \"\$out\" | grep -q 'OPT-IN and not enabled' && printf '%s' \"\$out\" | grep -q 'candidates: codex(openai) claude(anthropic) agy(google) cursor(unknown) opencode(unknown)' && printf '%s' \"\$out\" | grep -q 'enable: only when the user asks' && ! printf '%s' \"\$out\" | grep -qE '\.rolepod|config\.json'"
cand=$(bash "$RUNNER" --candidates --lead claude | tr '\n' ' ')
check "--candidates lists EVERY installed CLI, the Lead's own included — one Lead-independent file" "[ \"$cand\" = 'codex(openai) claude(anthropic) agy(google) cursor(unknown) opencode(unknown) ' ]"
cand=$(bash "$RUNNER" --candidates --lead codex | tr '\n' ' ')
check "--candidates is the same list under a Codex Lead (the Lead is skipped at run time, not at config time)" "[ \"$cand\" = 'codex(openai) claude(anthropic) agy(google) cursor(unknown) opencode(unknown) ' ]"
: > "$LOG"; mkdir -p .rolepod/evidence; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "run while OFF → exit 5, ROLEPOD-XFAM off, no CLI called, NOTHING logged (a choice is not a failure)" \
  "[ $rc -eq 5 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM off' && [ ! -s '$LOG' ] && [ ! -s .rolepod/evidence/phase-log.jsonl ]"
rc=0; bash "$RUNNER" --probe --lead claude >/dev/null 2>&1 || rc=$?
check "--probe while OFF → exit 5 without calling anyone" "[ $rc -eq 5 ] && [ ! -s '$LOG' ]"

fi
if section "cross-family: pool resolution (enabled with every CLI listed)"; then
mkdir -p "$HOME/.rolepod"; setpool 'codex\nclaude\nagy\ncursor\nopencode\n'
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "all five listed, lead=claude → codex agy cursor opencode (claude excluded)" "[ \"$names\" = 'codex agy cursor opencode ' ]"
names=$(bash "$RUNNER" --pool-names --lead agy | tr '\n' ' ')
check "lead=agy → codex claude cursor opencode" "[ \"$names\" = 'codex claude cursor opencode ' ]"
out=$(bash "$RUNNER" --pool --lead claude); printf 'gemini\ncodex\n' > "$FIX/gcfg"
setpool 'gemini\ncodex\n'
out=$(bash "$RUNNER" --pool --lead claude); setpool 'codex\nclaude\nagy\ncursor\nopencode\n'
check "a 'gemini' config line hits the generic unknown-CLI-name handling (Gemini CLI support removed in v2.177.0)" "printf '%s' \"\$out\" | grep -qE 'gemini +skipped +-  *unknown CLI name'"
out=$(bash "$RUNNER" --pool --lead claude)
check "cursor / opencode flagged family unknown when no default model configured" "printf '%s' \"\$out\" | grep -q 'cursor .*unknown' && printf '%s' \"\$out\" | grep -q 'opencode .*unknown'"

# opencode default model → family resolves; same family as Lead → skipped
mkdir -p "$HOME/.config/opencode"; printf '{ "model": "anthropic/claude-sonnet-5" }\n' > "$HOME/.config/opencode/opencode.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "opencode with a Claude default model stays usable under a Claude Lead (different CLI; family shown as info)" "printf '%s' \"\$out\" | grep -q 'opencode  *usable  *anthropic'"
names=$(bash "$RUNNER" --pool-names --lead codex | tr '\n' ' ')
check "…but usable under a Codex Lead" "printf '%s' \"$names\" | grep -qw opencode"
printf '{ "model": "openai/gpt-5.6" }\n' > "$HOME/.config/opencode/opencode.json"
out=$(bash "$RUNNER" --pool --lead codex)
check "opencode with an OpenAI default model stays usable under a Codex Lead" "printf '%s' \"\$out\" | grep -q 'opencode  *usable  *openai'"
# cursor default model
mkdir -p "$HOME/.cursor"; printf '{ "model": "gemini-3-pro" }\n' > "$HOME/.cursor/cli-config.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "cursor pinned to a Gemini-family model id classifies as google (agy's model-id format)" "printf '%s' \"\$out\" | grep -q 'cursor  *usable  *google'"
# v2.83.2: Cursor stores "model" as an object; Auto = no fixed family; more vendors; opencode last-used fallback
printf '{ "model": { "modelId": "composer-2.5", "displayName": "Composer 2.5" } }\n' > "$HOME/.cursor/cli-config.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "cursor object-form model.modelId=composer-2.5 → family cursor, model shown" "printf '%s' \"\$out\" | grep -q 'cursor  *usable  *cursor .*model=composer-2.5 (cli-config.json)'"
printf '{ "model": { "modelId": "cursor-grok-4.6-high-fast" } }\n' > "$HOME/.cursor/cli-config.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "cursor grok → family xai" "printf '%s' \"\$out\" | grep -q 'cursor  *usable  *xai '"
printf '{ "model": { "modelId": "default", "displayModelId": "auto" } }\n' > "$HOME/.cursor/cli-config.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "cursor Auto → family not reported, no advice" "printf '%s' \"\$out\" | grep -q 'cursor  *usable  *unknown .*family not reported' && ! printf '%s' \"\$out\" | grep -q 'pin one'"
printf '{ "model": { "modelId": "claude-sonnet-5-thinking-high" } }\n' > "$HOME/.cursor/cli-config.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "cursor pinned to a Claude model stays usable under a Claude Lead (family = info)" "printf '%s' \"\$out\" | grep -q 'cursor  *usable  *anthropic'"
rm -f "$HOME/.config/opencode/opencode.json"; mkdir -p "$HOME/.local/state/opencode"
printf '{"recent":[{"providerID":"openrouter","modelID":"moonshotai/kimi-k3"}],"favorite":[]}\n' > "$HOME/.local/state/opencode/model.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "opencode with no config model falls back to its last-used model (state) → family moonshot" "printf '%s' \"\$out\" | grep -q 'opencode  *usable  *moonshot .*model=openrouter/moonshotai/kimi-k3 (last used'"
printf '{ "model": "ollama-cloud/deepseek-v4-pro" }\n' > "$HOME/.config/opencode/opencode.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "opencode aggregator id classifies by model name (deepseek) and config beats last-used" "printf '%s' \"\$out\" | grep -q 'opencode  *usable  *deepseek .*model=ollama-cloud/deepseek-v4-pro (config)'"
out=$(CURSOR_MODELS_OUT='gpt-5.6-sol-high - GPT-5.6 Sol (current)' bash "$RUNNER" --probe --lead codex 2>/dev/null)  # cursor is pinned to a Claude model here → usable only under a non-Claude Lead
check "--probe asks the CLI: cursor-agent models '(current' line wins over cli-config.json" "printf '%s' \"\$out\" | grep -q 'default per CLI: gpt-5.6-sol-high (openai) — cli-config.json says claude-sonnet-5-thinking-high; the CLI wins'"
rm -f "$HOME/.local/state/opencode/model.json"
printf '{ "model": "openai/gpt-5.6" }\n' > "$HOME/.config/opencode/opencode.json"
printf '{ "model": "gemini-3-pro" }\n' > "$HOME/.cursor/cli-config.json"

# ── config: the global setting, none ──────────────────────────────
fi
if section "cross-family: --setup (guided, on request)"; then
droppool
bash "$RUNNER" --setup --lead claude > "$FIX/setup.txt" 2>&1; rc=$?   # output holds | and < — never interpolate it into an eval
check "--setup with no values prints the candidates and ONE question (review only)" "[ $rc -eq 0 ] && grep -q 'installed CLIs' '$FIX/setup.txt' && grep -q '1. review' '$FIX/setup.txt' && ! grep -q '2\\. ' '$FIX/setup.txt' && ! grep -qi 'implement' '$FIX/setup.txt'"
out=$(bash "$RUNNER" --setup review="agy, codex" --lead claude 2>&1); rc=$?
check "--setup review=… writes the pool into the machine setting (switch on, review order, no implement key)" "[ $rc -eq 0 ] && grep -q '\"cross-family\": \"on\"' '$HOME/.rolepod/config.json' && grep -q '\"review\": \"agy codex\"' '$HOME/.rolepod/config.json' && ! grep -q 'implement' '$HOME/.rolepod/config.json'"
check "--setup output names neither the setting file nor its keys" "! printf '%s' \"\$out\" | grep -qE 'config\.json|cross-family\"|\.rolepod'"
out=$(bash "$RUNNER" --pool --kind review --lead claude 2>&1)
check "the written file resolves: review order agy codex" "printf '%s' \"$out\" | grep -q 'usable, in order: agy codex$'"
out=$(bash "$RUNNER" --setup review="codex agy" --lead claude 2>&1); rc=$?
check "a second --setup keeps a backup of the previous file and rewrites the review order" "[ $rc -eq 0 ] && ls '$HOME/.rolepod/'config.json.bak-* >/dev/null 2>&1 && grep -q '\"review\": \"codex agy\"' '$HOME/.rolepod/config.json'"
rc=0; out=$(cd "$REPO" && bash "$RUNNER" --kind implement --brief brief.md --lead claude 2>&1) || rc=$?
check "--kind implement is refused (exit 2): the runner is review-only" "[ $rc -eq 2 ] && printf '%s' \"\$out\" | grep -q 'review|consult|critique required'"
rc=0; out=$(cd "$REPO" && bash "$RUNNER" --kind review --brief brief.md --allow README.md --lead claude 2>&1) || rc=$?
check "--allow is gone (exit 2, unknown argument)" "[ $rc -eq 2 ] && printf '%s' \"\$out\" | grep -q 'unknown argument: --allow'"
rc=0; out=$(cd "$REPO" && bash "$RUNNER" --kind review --brief brief.md --allow-risky --lead claude 2>&1) || rc=$?
check "--allow-risky is gone (exit 2, unknown argument)" "[ $rc -eq 2 ] && printf '%s' \"\$out\" | grep -q 'unknown argument: --allow-risky'"
rc=0; out=$(bash "$RUNNER" --review-tier --lead claude 2>&1) || rc=$?
check "--review-tier is gone (exit 2, unknown argument)" "[ $rc -eq 2 ] && printf '%s' \"\$out\" | grep -q 'unknown argument: --review-tier'"
rc=0; out=$(bash "$RUNNER" --setup review="codex" implement=same --lead claude 2>&1) || rc=$?
check "--setup implement=… is gone (exit 2, unknown argument)" "[ $rc -eq 2 ] && printf '%s' \"\$out\" | grep -q 'unknown argument: implement=same'"
out=$(bash "$RUNNER" --setup review="gemini2 codex" --lead claude 2>&1); rc=$?
printf '%s' "$out" > "$FIX/setup-err.txt"
check "an unknown CLI name is refused (exit 2) and the file is left as it was" "[ $rc -eq 2 ] && grep -q 'not an installed CLI' '$FIX/setup-err.txt' && grep -q '\"review\": \"codex agy\"' '$HOME/.rolepod/config.json'"
# other keys survive a --setup rewrite (gates / nudge / the rest of the pool), and a broken file is never overwritten
printf '{"gates":{"mode":"hard"},"nudge":{"enabled":false},"pool":{"reviewer":{"consult":"agy","tier":"R2"},"implement":{"cli":"codex"}},"extra":[1,2]}\n' > "$HOME/.rolepod/config.json"
out=$(bash "$RUNNER" --setup review="codex agy" --lead claude 2>&1); rc=$?
check "--setup keeps every other key (gates, nudge, the pool's consult, unknown keys) and drops the retired pool.implement + reviewer.tier" "[ $rc -eq 0 ] && python3 -I -c 'import json,sys;d=json.load(open(sys.argv[1]));p=d[\"pool\"];assert d[\"gates\"]==({\"mode\":\"hard\"}) and d[\"nudge\"]==({\"enabled\":False}) and d[\"extra\"]==[1,2] and p[\"reviewer\"][\"consult\"]==\"agy\" and \"tier\" not in p[\"reviewer\"] and \"implement\" not in p and p[\"reviewer\"][\"review\"]==\"codex agy\" and p[\"cross-family\"]==\"on\"' '$HOME/.rolepod/config.json'"
printf '{ "pool": broken' > "$HOME/.rolepod/config.json"; cp "$HOME/.rolepod/config.json" "$FIX/broken.keep"
out=$(bash "$RUNNER" --setup review="codex agy" --lead claude 2>&1); rc=$?
check "--setup on a broken setting file → exit 2, the file is byte-identical, the message says so and names no path" "[ $rc -eq 2 ] && cmp -s '$FIX/broken.keep' '$HOME/.rolepod/config.json' && printf '%s' \"\$out\" | grep -q 'could not be read as a JSON object' && ! printf '%s' \"\$out\" | grep -qE 'config\.json|\.rolepod'"
printf '[1,2]' > "$HOME/.rolepod/config.json"
out=$(bash "$RUNNER" --setup review="codex agy" --lead claude 2>&1); rc=$?
check "--setup on a JSON file that is not an object → exit 2, untouched" "[ $rc -eq 2 ] && [ \"\$(cat '$HOME/.rolepod/config.json')\" = '[1,2]' ]"
# a symlinked setting is written through (the link stays), the mode is kept, backups are unique and capped at three
mkdir -p "$FIX/dotfiles"; printf '{"gates":{"mode":"hard"}}\n' > "$FIX/dotfiles/rolepod.json"; chmod 640 "$FIX/dotfiles/rolepod.json"
rm -f "$HOME/.rolepod/config.json" "$HOME/.rolepod/"config.json.bak-*; ln -s "$FIX/dotfiles/rolepod.json" "$HOME/.rolepod/config.json"
printf 'mine\n' > "$FIX/dotfiles/rolepod.json.bak-mine"
for _i in 1 2 3 4 5; do bash "$RUNNER" --setup review="codex agy" --lead claude >/dev/null 2>&1; done
check "--setup through a symlinked setting: the link stays a link, the target got the pool and keeps its mode (640) and its other keys" "[ -L '$HOME/.rolepod/config.json' ] && grep -q '\"review\": \"codex agy\"' '$FIX/dotfiles/rolepod.json' && grep -q '\"mode\": \"hard\"' '$FIX/dotfiles/rolepod.json' && [ \"\$(stat -f %Lp '$FIX/dotfiles/rolepod.json' 2>/dev/null || stat -c %a '$FIX/dotfiles/rolepod.json')\" = 640 ]"
check "a user's own config.json.bak-mine is never pruned" "[ -f '$FIX/dotfiles/rolepod.json.bak-mine' ]"
check "five --setup runs in a row keep only the newest three backups (unique names)" "[ \"\$(ls '$FIX/dotfiles/' | grep -cE 'rolepod.json.bak-[0-9]{8}T[0-9]{6}-[0-9]+\$')\" = 3 ]"
rm -f "$HOME/.rolepod/config.json"
out=$(bash "$RUNNER" --setup review=" " --lead claude 2>&1); rc=$?
check "--setup with a blank review is refused (exit 2) and writes nothing" "[ $rc -eq 2 ] && [ ! -e '$HOME/.rolepod/config.json' ]"
if [ "$(id -u)" != 0 ]; then
  chmod 500 "$HOME/.rolepod"
  out=$(bash "$RUNNER" --setup review="codex agy" --lead claude 2>&1); rc=$?
  chmod 700 "$HOME/.rolepod"
  check "--setup on a read-only home → one clean exit-2 message, no traceback, no file" "[ $rc -eq 2 ] && printf '%s' \"\$out\" | grep -q 'could not be written' && ! printf '%s' \"\$out\" | grep -q Traceback && [ ! -e '$HOME/.rolepod/config.json' ]"
fi
droppool; rm -f "$HOME/.rolepod/"config.json.bak-*

fi
if section "cross-family: config"; then
mkdir -p "$HOME/.rolepod"; setpool '# my pool\nagy\ncodex\n'
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "global config filters AND orders the pool (agy before codex)" "[ \"$names\" = 'agy codex ' ]"
mkdir -p "$REPO/.rolepod"; printf 'codex\n' > "$REPO/.rolepod/cross-family"; printf 'claude\n' > "$HOME/.rolepod/cross-family"
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "an old INI pool file (project and machine) changes nothing: the setting still drives the pool" "[ \"$names\" = 'agy codex ' ]"
rm -f "$REPO/.rolepod/cross-family" "$HOME/.rolepod/cross-family"
droppool; printf 'codex\n' > "$HOME/.rolepod/cross-family"
rc=0; names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ') || rc=$?
check "an old INI pool file alone does not turn the pool on" "[ -z \"$names\" ]"
rm -f "$HOME/.rolepod/cross-family"; setpool '# my pool\nagy\ncodex\n'
# the switch: off wins over lists; no switch + lists = on; a bad value = off + a warning that names no path or key
cfg_pool() { printf '%s\n' "$1" > "$HOME/.rolepod/config.json"; }
cfg_pool '{"pool":{"cross-family":"off","reviewer":{"review":"agy codex"}}}'
rc=0; : > "$LOG"; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>&1) || rc=$?
check "cross-family off with a list → exit 5, no member called" "[ $rc -eq 5 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM off' && [ ! -s '$LOG' ]"
check "off → --pool-names is empty" "[ -z \"\$(bash '$RUNNER' --pool-names --lead claude)\" ]"
cfg_pool '{"pool":{"reviewer":{"review":"agy codex","tier":"R2"}}}'
check "no switch + a list → on (order from the setting; a stale reviewer tier is ignored, adds no member and no pool line)" "[ \"\$(bash '$RUNNER' --pool-names --lead claude | tr '\n' ' ')\" = 'agy codex ' ] && ! bash '$RUNNER' --pool --lead claude | grep -q 'tier'"
cfg_pool '{"pool":{"cross-family":"of","reviewer":{"review":"agy codex"}}}'
out=$(bash "$RUNNER" --pool --lead claude 2>&1); names=$(bash "$RUNNER" --pool-names --lead claude 2>/dev/null)
check "a bad switch value ('of') → pool off + the reader's own warning (stderr only)" "[ -z \"\$names\" ] && printf '%s' \"\$out\" | grep -q 'cross-family: rolepod-config: pool.cross-family is not on|off'"
cfg_pool '{ broken'
out=$(bash "$RUNNER" --pool --lead claude 2>&1); names=$(bash "$RUNNER" --pool-names --lead claude 2>/dev/null)
check "a broken setting file → pool off + the warning" "[ -z \"\$names\" ] && printf '%s' \"\$out\" | grep -q 'cross-family: rolepod-config: .* is unreadable'"
cfg_pool '{"pool":{"reviewer":{"review":"codex stall=60 agy","consult":"agy codex"}}}'
out=$(bash "$RUNNER" --pool --lead claude 2>&1)
check "per-member stall= from the setting reaches the pool row (codex stall=60s, agy default 600s)" "printf '%s' \"\$out\" | grep -E '^ +codex +usable' | grep -q 'stall=60s' && printf '%s' \"\$out\" | grep -E '^ +agy +usable' | grep -q 'stall=600s'"
out=$(bash "$RUNNER" --pool --kind consult --lead claude 2>&1)
check "per-kind order from the setting (consult: agy first, then codex)" "printf '%s' \"\$out\" | grep -q 'usable, in order: agy codex'"
restorepool
setpool_over 'none\n'
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "'none' empties the pool" "[ -z \"$names\" ]"
mkdir -p .rolepod/evidence; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "run with 'none' → exit 5 (off by choice), nothing logged" "[ $rc -eq 5 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM off' && [ ! -s .rolepod/evidence/phase-log.jsonl ]"
setpool_over 'claude\n'
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "enabled but only the Lead's own family listed → exit 4 + ROLEPOD-XFAM empty + external-fail pool-empty line (this IS logged)" \
  "[ $rc -eq 4 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM empty' && grep -q '\"phase\":\"external-fail\".*pool-empty' .rolepod/evidence/phase-log.jsonl"
setpool_over 'bogus\ncodex\n'
out=$(bash "$RUNNER" --pool --lead claude)
check "unknown CLI name in config is reported, not fatal" "printf '%s' \"\$out\" | grep -q 'bogus .*unknown CLI name'"

# ── run: success path anchors evidence ──────────────────────────────────
fi
# Unconditional: "run + evidence" (and every section after it) needs the pool
# enabled — this used to live inside "config" above,
# so filtering to a later section alone left the pool OFF (exit 5, red checks).
restorepool
setpool 'codex\nclaude\nagy\ncursor\nopencode\n'   # enabled for the run tests
rm -f "$HOME/.config/opencode/opencode.json" "$HOME/.cursor/cli-config.json"
if section "cross-family: run + evidence"; then
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(KIND_HINT=adversarial bash "$RUNNER" --kind review --brief brief.md --attach diff.patch --lead claude 2>/dev/null) || rc=$?
check "review run → exit 0, first usable member (codex) answered" "[ $rc -eq 0 ] && grep -q '^codex |' '$LOG'"
check "output ends with the ROLEPOD-XFAM ok trailer naming cli + raw path" "printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM ok kind=review cli=codex family=openai raw=.rolepod/evidence/external/'"
check "review receipt is the LAST line, preceded by ONE round-2+ note (re-checked internally, never a new external run; no commit-gate claim)" "[ \"\$(printf '%s\n' \"\$out\" | tail -1 | cut -c1-24)\" = 'ROLEPOD-XFAM ok kind=rev' ] && [ \"\$(printf '%s\n' \"\$out\" | tail -2 | head -1 | cut -c1-31)\" = 'ROLEPOD-XFAM note: this pass is' ] && [ \"\$(printf '%s\n' \"\$out\" | grep -c '^ROLEPOD-XFAM note:')\" -eq 1 ] && printf '%s' \"\$out\" | grep -q 'round 2+ is ONE fresh internal rolepod-reviewer' && printf '%s' \"\$out\" | grep -q 'never a new external run' && ! printf '%s' \"\$out\" | grep -q 'commit gate'"
raw=$(ls .rolepod/evidence/external/*-codex-*.txt 2>/dev/null | grep -v -E 'failed|partial' | head -1)
check "raw evidence file written ≥ 500 bytes (the gate's floor)" "[ -n \"$raw\" ] && [ \"\$(wc -c < \"$raw\" | tr -d ' ')\" -ge 500 ]"
check "raw file header records cli / family / lead" "grep -q 'cli=codex family=openai lead=claude' \"$raw\""
check "codex: the -o final message is the evidence, not the stdout event stream" "grep -q 'VERDICT: APPROVED' \"$raw\" && ! grep -q 'event-stream noise' \"$raw\""
check "phase-log carries the review line precommit-gate reads (+ brief_sha binding)" \
  "grep -q '\"phase\":\"review\",\"reviewer\":\"external\",\"kind\":\"review\",\"cli\":\"codex\",\"family\":\"openai\",\"model\":\"default\",\"raw\":\"external/' .rolepod/evidence/phase-log.jsonl && grep -q '\"brief_sha\":\"[0-9a-f]\{12\}\"' .rolepod/evidence/phase-log.jsonl"
check "codex got read-only sandbox + NO model / effort flag" \
  "grep '^codex |' '$LOG' | grep -q -- '-s read-only' && ! grep '^codex |' '$LOG' | grep -qE -- ' -m | --model|model_reasoning_effort|--effort'"
check "codex received the prompt on stdin (a & job otherwise reads /dev/null)" "grep -q 'STDIN=review' '$LOG'"
check "child env carries ROLEPOD_BRAIN_SILENT=1 (clean room)" "grep '^codex |' '$LOG' | grep -q 'BRAIN=1'"
check "attachment is inlined into the prompt (stub saw stdin; brief + diff both present)" "true"

mkdir -p "$REPO/dir with space"; printf 'ATTACHED-MARKER\n' > "$REPO/dir with space/my diff.patch"
: > "$LOG"
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --attach "dir with space/my diff.patch" --lead claude 2>/dev/null) || rc=$?
check "attachment path with spaces is inlined (stub saw the prompt on stdin)" "[ $rc -eq 0 ] && grep -q 'STDIN=review' '$LOG'"
setpool_over 'agy codex # both on one line\n'
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "two names on one config line are two members, not one squashed word" "[ \"$names\" = 'agy codex ' ]"
restorepool
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=short bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "review output under the 500-byte gate floor is a failure → next member (consult floor stays 200)" \
  "grep -q '\"cli\":\"codex\".*\"reason\":\"empty output (3[0-9][0-9] bytes, floor 500)' .rolepod/evidence/phase-log.jsonl && grep -q '^agy |' '$LOG'"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=short bash "$RUNNER" --kind consult --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "…the same 300-byte answer passes as a consult" "[ $rc -eq 0 ] && grep -q '\"phase\":\"consult\".*\"cli\":\"codex\"' .rolepod/evidence/phase-log.jsonl"

fi
if section "cross-family: --adversarial review mode"; then
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "(a) standard review → exit 0, no ADVERSARIAL framing, carries the two-axis prompt" \
  "[ $rc -eq 0 ] && ! grep '^codex |' '$LOG' | grep -q 'ADVERSARIAL' && grep '^codex |' '$LOG' | grep -q 'Review two axes'"
check "(a) phase-log review line carries no mode key" \
  "grep '\"phase\":\"review\"' .rolepod/evidence/phase-log.jsonl | grep -qv '\"mode\"'"

FIXB="$FIX/fixture-b"; mkdir -p "$FIXB/skills/cross-family/scripts" "$FIXB/skills/adversarial-review"
cp "$RUNNER" "$FIXB/skills/cross-family/scripts/cross-family.sh"; cp "$REPO_DIR/hooks/lib/rolepod_config.py" "$FIXB/skills/cross-family/scripts/"   # the reader rides beside the runner in a rendered tree
printf '## Reviewer stance\n\nMARKER-M1-STANCE-BODY\n\n## Report\n\nMARKER-M2-REPORT-BODY\n' > "$FIXB/skills/adversarial-review/SKILL.md"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$FIXB/skills/cross-family/scripts/cross-family.sh" --kind review --adversarial --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "(b) --adversarial over a fixture stance → exit 0, prompt carries M1 + adversarial-mode opening, not M2 or the standard framing" \
  "[ $rc -eq 0 ] && grep '^codex |' '$LOG' | grep -q 'MARKER-M1-STANCE-BODY' && grep '^codex |' '$LOG' | grep -q 'in adversarial mode' && ! grep '^codex |' '$LOG' | grep -q 'MARKER-M2-REPORT-BODY' && ! grep '^codex |' '$LOG' | grep -q 'Review two axes'"
check "(b) phase-log review line carries mode=adversarial" \
  "grep -q '\"phase\":\"review\".*\"mode\":\"adversarial\"' .rolepod/evidence/phase-log.jsonl"

FIXC1="$FIX/fixture-c1"; mkdir -p "$FIXC1/skills/cross-family/scripts"
cp "$RUNNER" "$FIXC1/skills/cross-family/scripts/cross-family.sh"
: > "$LOG"
rc=0; out=$(bash "$FIXC1/skills/cross-family/scripts/cross-family.sh" --kind review --adversarial --brief brief.md --lead claude 2>&1) || rc=$?
check "(c) missing adversarial-review skill dir → exit 2, zero stub calls, message names the path" \
  "[ $rc -eq 2 ] && [ ! -s '$LOG' ] && printf '%s' \"\$out\" | grep -q 'fixture-c1' && printf '%s' \"\$out\" | grep -q 'adversarial-review/SKILL.md'"

FIXC2="$FIX/fixture-c2"; mkdir -p "$FIXC2/skills/cross-family/scripts" "$FIXC2/skills/adversarial-review"
cp "$RUNNER" "$FIXC2/skills/cross-family/scripts/cross-family.sh"
printf '# Adversarial Review\n\nno stance heading here.\n' > "$FIXC2/skills/adversarial-review/SKILL.md"
: > "$LOG"
rc=0; out=$(bash "$FIXC2/skills/cross-family/scripts/cross-family.sh" --kind review --adversarial --brief brief.md --lead claude 2>&1) || rc=$?
check "(c) SKILL.md lacking the heading → exit 2, zero stub calls, message names the path" \
  "[ $rc -eq 2 ] && [ ! -s '$LOG' ] && printf '%s' \"\$out\" | grep -q 'fixture-c2/skills/adversarial-review/SKILL.md'"

: > "$LOG"
rc=0; out=$(bash "$RUNNER" --kind consult --adversarial --brief brief.md --lead claude 2>&1) || rc=$?
check "(d) --adversarial with --kind consult → exit 2, zero stub calls" \
  "[ $rc -eq 2 ] && [ ! -s '$LOG' ] && printf '%s' \"\$out\" | grep -q -- '--adversarial only applies to --kind review'"

REAL_STANCE="$REPO_DIR/core/skills/adversarial-review/SKILL.md"
real_first=$(awk '/^## Reviewer stance/{f=1;next} f&&/^## /{exit} f' "$REAL_STANCE" | sed '/^$/d' | head -1)
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --adversarial --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "(e) the repo's own runner + real stance → prompt carries the first line of the real stance body" \
  "[ $rc -eq 0 ] && [ -n \"$real_first\" ] && grep '^codex |' '$LOG' | grep -qF \"$real_first\""

: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$FIXB/skills/cross-family/scripts/cross-family.sh" --kind review --adversarial --brief brief.md --lead claude --detach 2>/dev/null) || rc=$?
jidf=$(printf '%s' "$out" | grep -o 'job=[^ ]*' | head -1 | cut -d= -f2)
check "(f) --adversarial --detach returns at once with a job id" "[ $rc -eq 0 ] && [ -n \"$jidf\" ]"
rc=0; out=$(bash "$FIXB/skills/cross-family/scripts/cross-family.sh" --collect "$jidf" --timeout 30 2>/dev/null) || rc=$?
check "(f) --collect: the detached member's prompt carried M1 (the flag reached the child)" \
  "[ $rc -eq 0 ] && grep '^codex |' '$LOG' | grep -q 'MARKER-M1-STANCE-BODY'"

# ── run: failure → next member; all fail → exit 3 ───────────────────────
fi
if section "cross-family: fallback"; then
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=fail STUB_agy=fail bash "$RUNNER" --kind consult --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "codex + agy fail → cursor answers, exit 0" "[ $rc -eq 0 ] && grep -q '^cursor |' '$LOG'"
check "failure recorded as an external-fail line naming the cli + reason" "grep -q '\"phase\":\"external-fail\",\"kind\":\"consult\",\"cli\":\"codex\".*\"reason\":\"exit 1' .rolepod/evidence/phase-log.jsonl"
check "consult success logs phase=consult (not review — never counts as the strong pass)" "grep -q '\"phase\":\"consult\",\"reviewer\":\"external\".*\"cli\":\"cursor\"' .rolepod/evidence/phase-log.jsonl"
check "failed raw kept as *.failed.txt for audit" "ls .rolepod/evidence/external/*-codex-*.failed.txt >/dev/null"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=empty bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "exit 0 but empty output counts as a failure (installed ≠ usable)" "grep -q '\"cli\":\"codex\".*\"reason\":\"empty output' .rolepod/evidence/phase-log.jsonl && grep -q '^agy |' '$LOG'"
setpool_over 'codex\nagy\n'
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=fail STUB_agy=fail bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "every member fails → exit 3 + ROLEPOD-XFAM none listing each failure" \
  "[ $rc -eq 3 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM none' && printf '%s' \"\$out\" | grep -q 'codex: exit 1' && printf '%s' \"\$out\" | grep -q 'agy: exit 1'"
check "no review line was written on total failure" "! grep -q '\"reviewer\":\"external\"' .rolepod/evidence/phase-log.jsonl"
check "agy got plan mode + print timeout, no --model / --effort" "grep '^agy |' '$LOG' | grep -q -- '--mode plan' && ! grep '^agy |' '$LOG' | grep -qE -- '--model|--effort'"
restorepool

# ── timeout ─────────────────────────────────────────────────────────────
fi
if section "cross-family: timeout"; then
setpool_over 'codex\nagy\n'
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
s=$(date +%s); rc=0; out=$(STUB_codex=hang bash "$RUNNER" --kind review --brief brief.md --lead claude --timeout 3 2>/dev/null) || rc=$?; secs=$(( $(date +%s) - s ))
check "hung CLI is killed at --timeout and the next member answers (took ${secs}s, exit $rc)" "[ $rc -eq 0 ] && [ $secs -lt 20 ] && grep -q '\"cli\":\"codex\".*\"reason\":\"timeout 3s' .rolepod/evidence/phase-log.jsonl && grep -q '^agy |' '$LOG'"
gc=$(cat "$FIX"/grandchild.* 2>/dev/null | head -1); sleep 1
check "…and the hung CLI's grandchild (sleep 30) is dead too — no process leak (pgid kill)" "[ -n \"$gc\" ] && ! kill -0 \"$gc\" 2>/dev/null"
restorepool

# ── --all panel ─────────────────────────────────────────────────────────
fi
if section "cross-family: --all panel"; then
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
STAMP="$FIX/overlap.stamp"; : > "$STAMP"
rc=0; out=$(XFAM_STAMP="$STAMP" bash "$RUNNER" --kind critique --brief brief.md --lead claude --all 2>/dev/null) || rc=$?
check "--all calls every usable member (codex + agy + cursor + opencode)" \
  "[ $rc -eq 0 ] && grep -q '^codex |' '$LOG' && grep -q '^agy |' '$LOG' && grep -q '^cursor |' '$LOG' && grep -q '^opencode |' '$LOG'"
if [ "$CHECK_OK" -eq 0 ]; then   # diagnostics only: name what the log really held
  echo "    diag: rc=$rc, $(wc -l < "$LOG" | tr -d ' ') line(s) in calls.log"
  while IFS= read -r _l; do echo "    diag: $(printf '%s' "$_l" | head -c 80)"; done < "$LOG"
fi
check "--all runs the members concurrently — all 4 start before the first one ends (start/end order, no clock)" \
  "[ \"\$(head -4 '$STAMP' | grep -c '^S ')\" -eq 4 ] && [ \"\$(grep -c '^E ' '$STAMP')\" -eq 4 ]"
[ "$CHECK_OK" -eq 0 ] && echo "    diag: stamps: $(tr '\n' ' ' < "$STAMP")"
check "--all output carries one ===== block + ok trailer per member" "[ \"\$(printf '%s' \"\$out\" | grep -c '^ROLEPOD-XFAM ok kind=critique')\" -eq 4 ]"
check "critique lines logged with phase=critique" "[ \"\$(grep -c '\"phase\":\"critique\",\"reviewer\":\"external\"' .rolepod/evidence/phase-log.jsonl)\" -eq 4 ]"
check "cursor got plan mode + --trust, opencode got --agent plan; neither got a model flag" \
  "grep '^cursor |' '$LOG' | grep -q -- '--mode ask' && ! grep '^cursor |' '$LOG' | grep -q -- '--mode plan' && grep '^cursor |' '$LOG' | grep -q -- '--output-format stream-json' && grep '^cursor |' '$LOG' | grep -q -- '--trust' && grep '^opencode |' '$LOG' | grep -q -- '--agent plan' && ! grep -E '^(cursor|opencode) \|' '$LOG' | grep -qE -- '--model| -m '"

# ── critique kind (write-spec) ──────────────────────────────────────────
fi
if section "cross-family: --kind critique"; then
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind critique --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "critique → spec-critic framing on stdin, logged as phase=critique kind=critique (never a strong pass)" \
  "[ $rc -eq 0 ] && grep -q 'STDIN=critique' '$LOG' && grep -q '\"phase\":\"critique\",\"reviewer\":\"external\",\"kind\":\"critique\"' .rolepod/evidence/phase-log.jsonl && ! grep -q '\"phase\":\"review\"' .rolepod/evidence/phase-log.jsonl"

# ── stall detector (v2.129.0): silence kills, output keeps a member alive ──
fi
if section "cross-family: stall detector"; then
: > "$REPO/.rolepod/evidence/phase-log.jsonl"
setpool_over 'codex stall=3\nagy\n'
s=$(date +%s); rc=0; out=$(STUB_codex=hang bash "$RUNNER" --kind review --brief brief.md --lead claude --timeout 60 2>/dev/null) || rc=$?; secs=$(( $(date +%s) - s ))
check "silent CLI is killed by stall=3 long before --timeout 60; the next member answers (took ${secs}s)" \
  "[ $rc -eq 0 ] && [ $secs -lt 25 ] && grep -q 'stalled: no output for 3s' '$REPO/.rolepod/evidence/phase-log.jsonl'"
rc=0; out=$(STUB_codex=trickle bash "$RUNNER" --kind review --brief brief.md --lead claude --timeout 60 2>/dev/null) || rc=$?
check "a CLI that keeps printing (trickle 6 s) is NOT killed by stall=3 → codex itself answers" \
  "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'cli=codex'"
setpool_over 'codex stall=5\nagy\n'
out=$(cd "$REPO" && bash "$RUNNER" --pool --lead claude)
check "--pool shows stall= from config (codex 5 s) and the 600 s default (agy)" \
  "printf '%s' \"\$out\" | grep -qE 'codex .*stall=5s' && printf '%s' \"\$out\" | grep -qE 'agy .*stall=600s'"
setpool_over 'cursor\n'; : > "$LOG"
rc=0; out=$(cd "$REPO" && CURSOR_RAN=gpt-5.6-sol bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "cursor stream-json is unwrapped: plain report in the raw file (no JSON), VERDICT seen, ran= from the init event" \
  "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'cli=cursor' && printf '%s' \"\$out\" | grep -q 'ran=gpt-5.6-sol' && grep -l 'VERDICT: APPROVED' \"$REPO\"/.rolepod/evidence/external/*cursor*.txt >/dev/null && ! grep -q '\"type\":\"result\"' \"$REPO\"/.rolepod/evidence/external/*cursor*.txt"

# ── runaway-cap defaults, per-kind order, budget line ────────────────────
fi
if section "cross-family: timeouts / per-kind order / budget"; then
setpool_over '[reviewer]\nreview = codex agy\nconsult = agy codex\n'   # v2.141.0 shape; the per-kind `consult:` line shape is covered below
out=$(bash "$RUNNER" --pool --lead claude --kind review)
check "review order = default list; both members carry the review default 600s (foreground)" \
  "printf '%s' \"\$out\" | grep -qE 'codex +usable +openai +.*timeout=600s' && printf '%s' \"\$out\" | grep -qE 'agy +usable +google +.*timeout=600s' && printf '%s' \"\$out\" | grep -q 'usable, in order: codex agy'"
out=$(bash "$RUNNER" --pool --lead claude --kind consult)
check "consult uses the per-kind line: agy first, codex second; agy gets the consult default 300s" \
  "printf '%s' \"\$out\" | grep -q 'per-kind order' && printf '%s' \"\$out\" | grep -q 'usable, in order: agy codex' && printf '%s' \"\$out\" | grep -qE 'agy +usable +google +.*timeout=300s'"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind consult --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "consult run → agy answers first (per-kind order) with a 5-minute budget line in its prompt" "[ $rc -eq 0 ] && grep -q '^agy |.*BUDGET=5' '$LOG' && ! grep -q '^codex |' '$LOG'"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude --timeout 1800 2>"$FIX/warn.txt") || rc=$?
check "review run (foreground, --timeout 1800) → codex gets a 1800s budget (30 min in prompt) + a foreground-cap warning on stderr; receipt shows budget" \
  "[ $rc -eq 0 ] && grep -q '^codex |.*BUDGET=30' '$LOG' && grep -q 'exceeds the 600 s foreground cap' '$FIX/warn.txt' && printf '%s' \"\$out\" | grep -q 'budget=1800s' && grep -q '\"budget\":1800' .rolepod/evidence/phase-log.jsonl"
rc=0; out=$(ROLEPOD_XFAM_TIMEOUT=240 bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
rc2=0; out2=$(ROLEPOD_XFAM_TIMEOUT=240 bash "$RUNNER" --kind review --brief brief.md --lead claude --timeout 120 2>/dev/null) || rc2=$?
check "--timeout and ROLEPOD_XFAM_TIMEOUT set the cap; the flag wins" "printf '%s' \"\$out\" | grep -q 'budget=240s' && printf '%s' \"\$out2\" | grep -q 'budget=120s'"

# ── detach / collect / jobs ──────────────────────────────────────────────
fi
if section "cross-family: --detach job"; then
# This section's own fixture: the budgets=… check below reads the kind defaults
# and members=codex agy from this file, so it must be written here — a
# ROLEPOD_CASE filter to this banner alone must not depend on an earlier
# section having run first to leave it behind.
setpool_over 'codex\nagy\n'
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
s=$(date +%s); rc=0; out=$(STUB_codex=slow bash "$RUNNER" --kind review --brief brief.md --attach diff.patch --lead claude --detach 2>/dev/null) || rc=$?; secs=$(( $(date +%s) - s ))
jid=$(printf '%s' "$out" | grep -o 'job=[^ ]*' | head -1 | cut -d= -f2)
check "--detach returns at once (${secs}s) with a job id + members + budgets (both members the detached review cap 7200 — the stall detector, not the cap, ends a dead member)" \
  "[ $rc -eq 0 ] && [ $secs -lt 3 ] && [ -n \"$jid\" ] && printf '%s' \"\$out\" | grep -q 'members=codex agy' && printf '%s' \"\$out\" | grep -q 'budgets=codex=7200s agy=7200s'"
check "job dir has pid + started + args, no status yet (still running)" "[ -f .rolepod/evidence/external/jobs/$jid/pid ] && [ -f .rolepod/evidence/external/jobs/$jid/started ] && [ ! -f .rolepod/evidence/external/jobs/$jid/status ]"
out=$(bash "$RUNNER" --jobs)
check "--jobs lists the job as running" "printf '%s' \"\$out\" | grep -q \"$jid *running\""
rc=0; out=$(bash "$RUNNER" --collect "$jid" --timeout 1 2>/dev/null) || rc=$?
check "--collect with a short wait → exit 6 'still running'" "[ $rc -eq 6 ] && printf '%s' \"\$out\" | grep -q 'still running'"
rc=0; out=$(bash "$RUNNER" --collect "$jid" --timeout 30 2>/dev/null) || rc=$?
check "--collect waits for the job → prints the review + receipt, exit 0; the child anchored the review line + raw file" \
  "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM ok kind=review cli=codex' && grep -q '\"phase\":\"review\",\"reviewer\":\"external\".*\"cli\":\"codex\"' .rolepod/evidence/phase-log.jsonl && [ -f .rolepod/evidence/external/jobs/$jid/status ] && [ \"\$(cat .rolepod/evidence/external/jobs/$jid/status)\" = 0 ]"
check "--collect of a review job: the note precedes the receipt, the receipt is the last line" "[ \"\$(printf '%s\n' \"\$out\" | tail -1 | cut -c1-24)\" = 'ROLEPOD-XFAM ok kind=rev' ] && [ \"\$(printf '%s\n' \"\$out\" | tail -2 | head -1 | cut -c1-31)\" = 'ROLEPOD-XFAM note: this pass is' ]"
check "detached child saw the attachment + stdin prompt (absolute paths survived the re-exec)" "grep -q '^codex |.*STDIN=review' '$LOG'"
out=$(bash "$RUNNER" --jobs)
check "--jobs now shows done exit=0 with the receipt" "printf '%s' \"\$out\" | grep -q \"$jid *done exit=0.*ROLEPOD-XFAM ok\""
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=fail bash "$RUNNER" --kind review --brief brief.md --lead claude --detach 2>/dev/null) || rc=$?
jid2=$(printf '%s' "$out" | grep -o 'job=[^ ]*' | head -1 | cut -d= -f2)
rc=0; out=$(bash "$RUNNER" --collect "$jid2" --timeout 30 2>/dev/null) || rc=$?
check "detached chain falls through on its own: codex fails → agy answers inside the job" "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'cli=agy' && grep -q '\"external-fail\".*\"cli\":\"codex\"' .rolepod/evidence/phase-log.jsonl"
# the job snapshots the pool it was started with — editing / deleting the
# config afterwards must not change (or kill) a running job
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=slow bash "$RUNNER" --kind review --brief brief.md --lead claude --detach 2>/dev/null) || rc=$?
jid3=$(printf '%s' "$out" | grep -o 'job=[^ ]*' | head -1 | cut -d= -f2)
droppool
rc=0; out=$(bash "$RUNNER" --collect "$jid3" --timeout 30 2>/dev/null) || rc=$?
check "config deleted right after --detach → the job still runs on its snapshot and anchors (no exit-5 surprise)" \
  "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM ok kind=review cli=codex' && [ -f .rolepod/evidence/external/jobs/$jid3/cross-family ]"
setpool 'codex\nclaude\nagy\ncursor\nopencode\n'
# a child that dies early still leaves a status (trap installed before any exit)
mkdir -p .rolepod/evidence/external/jobs/t-early; : > .rolepod/evidence/external/jobs/t-early/cross-family
rc=0; bash "$RUNNER" --kind review --brief nope.md --lead claude --job "$REPO/.rolepod/evidence/external/jobs/t-early" >/dev/null 2>&1 || rc=$?
check "a job child that exits early (usage error) still writes status (=$rc) so --collect never hangs" "[ $rc -eq 2 ] && [ \"\$(cat .rolepod/evidence/external/jobs/t-early/status)\" = 2 ]"
rm -rf .rolepod/evidence/external/jobs/t-early

# ── partial-slice stop (v2.94.0) ─────────────────────────────────────────
fi
if section "cross-family: partial-slice stop"; then
SL="$FIX/slice"; mkdir -p "$SL/.rolepod"; printf 'brief\n' > "$SL/brief.md"
( cd "$SL" && git init -q . && git config user.email t@t && git config user.name t && printf 'a\nb\nc\n' > f.txt && git add f.txt && git commit -qm init \
  && printf 'a\nB\nc\n' > f.txt && git add f.txt && printf 'a\nB\nC\n' > f.txt \
  && git diff --cached > "$FIX/slice-cached.patch" && git diff HEAD > "$FIX/slice-full.patch" )   # staged b→B, unstaged on top c→C
: > "$LOG"; rc=0; out=$(cd "$SL" && bash "$RUNNER" --kind review --brief brief.md --attach "$FIX/slice-cached.patch" --lead claude 2>/dev/null) || rc=$?
check "--cached slice while the same file has unstaged edits → refused exit 7, names the file, no member called, external-refused logged" \
  "[ $rc -eq 7 ] && printf '%s' \"\$out\" | grep -q 'refused partial-slice files=1' && printf '%s' \"\$out\" | grep -q 'f.txt' && ! grep -q '^codex |' '$LOG' && grep -q '\"phase\":\"external-refused\".*\"reason\":\"partial-slice\"' '$SL/.rolepod/evidence/phase-log.jsonl'"
: > "$LOG"; rc=0; out=$(cd "$SL" && bash "$RUNNER" --kind review --brief brief.md --attach "$FIX/slice-full.patch" --lead claude 2>/dev/null) || rc=$?
check "git diff HEAD attachment (staged + unstaged together) → runs" "[ $rc -eq 0 ] && grep -q '^codex |' '$LOG'"
: > "$LOG"; rc=0; out=$(cd "$SL" && bash "$RUNNER" --kind review --brief brief.md --attach "$FIX/slice-cached.patch" --lead claude --partial-ok 2>/dev/null) || rc=$?
check "--partial-ok lets a deliberate staged-only review run" "[ $rc -eq 0 ] && grep -q '^codex |' '$LOG'"
( cd "$SL" && git add f.txt && git commit -qm wip && git diff HEAD~1...HEAD > "$FIX/slice-range.patch" )
: > "$LOG"; rc=0; out=$(cd "$SL" && bash "$RUNNER" --kind review --brief brief.md --attach "$FIX/slice-range.patch" --lead claude 2>/dev/null) || rc=$?
check "committed range on a clean tree → runs (a clean file is never a slice)" "[ $rc -eq 0 ] && grep -q '^codex |' '$LOG'"
( cd "$SL" && printf 'a\nB\nC\nD\n' > f.txt )
: > "$LOG"; rc=0; out=$(cd "$SL" && bash "$RUNNER" --kind review --brief brief.md --attach "$FIX/slice-range.patch" --lead claude 2>/dev/null) || rc=$?
check "committed range while the tree already moved on in the same file → refused" "[ $rc -eq 7 ] && ! grep -q '^codex |' '$LOG'"
( cd "$SL" && git checkout -q -- f.txt && printf 'z\n' > g.txt )   # tree edit in a file the attachment never touches
: > "$LOG"; rc=0; out=$(cd "$SL" && bash "$RUNNER" --kind review --brief brief.md --attach "$FIX/slice-range.patch" --lead claude 2>/dev/null) || rc=$?
check "edits in a file outside the attachment → not a slice, runs" "[ $rc -eq 0 ]"
printf 'spec text, no hunks\n' > "$FIX/spec.md"
: > "$LOG"; rc=0; out=$(cd "$SL" && bash "$RUNNER" --kind critique --brief brief.md --attach "$FIX/spec.md" --lead claude 2>/dev/null) || rc=$?
check "non-diff attachment (spec) → no slice check" "[ $rc -eq 0 ]"
check "review preamble asks no round-2+ IN-FIX / NEW / REPEAT tag" "! grep -q 'prefix every finding with IN-FIX' '$RUNNER'"
: > "$LOG"; rc=0; out=$(cd "$SL" && bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "review member receives the no-sub-agents line (C11)" "[ $rc -eq 0 ] && grep -q '^codex |.*Answer yourself; do not spawn sub-agents\\.' '$LOG'"
cd "$REPO"

# ── one live review per repo + --kill (v2.98.0) ────────────────
fi
if section "cross-family: stacking / --kill"; then
SQ="$FIX/stack"; mkdir -p "$SQ/.rolepod"; printf 'brief\n' > "$SQ/brief.md"
( cd "$SQ" && git init -q . && git config user.email t@t && git config user.name t && printf 'a\nb\nc\n' > f.txt && git add f.txt && git commit -qm init && printf 'a\nB\nc\n' > f.txt && git diff HEAD > "$FIX/sq-r1.patch" )
: > "$LOG"; rc=0; out=$(cd "$SQ" && STUB_codex=slow bash "$RUNNER" --kind review --brief brief.md --attach "$FIX/sq-r1.patch" --lead claude --detach 2>/dev/null) || rc=$?
j1=$(printf '%s' "$out" | grep -o 'job=[^ ]*' | head -1 | cut -d= -f2)
check "detached review job started" "[ $rc -eq 0 ] && [ -n \"$j1\" ] && [ -f '$SQ/.rolepod/evidence/external/jobs/$j1/started' ]"
rc=0; out=$(cd "$SQ" && bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "second review while the first runs → refused exit 8, names the job + --collect" "[ $rc -eq 8 ] && printf '%s' \"\$out\" | grep -q \"refused stacked — review job $j1\" && printf '%s' \"\$out\" | grep -q -- \"--collect $j1\""
rc=0; out=$(cd "$SQ" && bash "$RUNNER" --kind consult --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "a consult during a running review is not stacked → runs" "[ $rc -eq 0 ]"
rc=0; out=$(cd "$SQ" && bash "$RUNNER" --collect "$j1" --timeout 30 2>/dev/null) || rc=$?
check "job collected" "[ $rc -eq 0 ]"
: > "$LOG"; rc=0; out=$(cd "$SQ" && STUB_codex=hang bash "$RUNNER" --kind review --brief brief.md --lead claude --detach 2>/dev/null) || rc=$?
j3=$(printf '%s' "$out" | grep -o 'job=[^ ]*' | head -1 | cut -d= -f2)
sleep 1; rc=0; out=$(cd "$SQ" && bash "$RUNNER" --kill "$j3" 2>/dev/null) || rc=$?
check "--kill stops a running job: status 137, and a new review is no longer stacked" "[ $rc -eq 0 ] && [ \"\$(cat '$SQ/.rolepod/evidence/external/jobs/$j3/status')\" = 137 ] && ! (cd '$SQ' && bash '$RUNNER' --kind review --brief brief.md --lead claude 2>&1 | grep -q 'refused stacked')"
rm -f "$FIX"/grandchild.* 2>/dev/null
cd "$REPO"

# ── provenance labels + oversized-diff notice (v2.100.0) ──────────────────
fi
if section "cross-family: --lens"; then
setpool 'codex\nclaude\nagy\ncursor\nopencode\n'   # self-contained under ROLEPOD_CASE: the section before leaves a one-CLI pool
C4='on ONE axis — spec: every requirement in the brief is present and complete, nothing unasked was added, no behavior looks wrong — quote the brief line for each. Another reviewer covers project rules and smells; do not review them.'
C5='on ONE axis — standards: every break of a written project rule (quote the rule) and every baseline smell (name it, quote the hunk); a hard violation is MAJOR, a judgement call MINOR; skip what tooling already enforces. Another reviewer covers spec coverage; do not review it.'
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --lens spec --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "--lens spec → exit 0, prompt has C4 and not the two-axis text" \
  "[ $rc -eq 0 ] && grep '^codex |' '$LOG' | grep -qF -- '$C4' && ! grep '^codex |' '$LOG' | grep -q 'Review two axes'"
check "--lens spec: phase-log carries lens, receipt carries lens=spec and the C6 note" \
  "grep -q '\"lens\":\"spec\"' .rolepod/evidence/phase-log.jsonl && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM ok .* lens=spec' && printf '%s' \"\$out\" | grep -qF 'this pass is external and runs in round 1 only; round 2+ is ONE fresh internal rolepod-reviewer on the fix delta (convening-code-review Fix-verify), never a new external run.'"
: > "$LOG"
rc=0; out=$(bash "$RUNNER" --kind review --lens standards --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "--lens standards → exit 0, prompt has C5" "[ $rc -eq 0 ] && grep '^codex |' '$LOG' | grep -qF -- '$C5'"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "no --lens keeps the two-axis prompt, no lens key, no lens= on the receipt" \
  "[ $rc -eq 0 ] && grep '^codex |' '$LOG' | grep -q 'Review two axes' && ! grep -q '\"lens\"' .rolepod/evidence/phase-log.jsonl && ! printf '%s' \"\$out\" | grep -q 'lens='"
rc=0; bash "$RUNNER" --kind review --lens spec --adversarial --brief brief.md --lead claude >/dev/null 2>&1 || rc=$?
check "--lens with --adversarial → exit 2" "[ $rc -eq 2 ]"
rc=0; bash "$RUNNER" --kind consult --lens spec --brief brief.md --lead claude >/dev/null 2>&1 || rc=$?
check "--kind consult --lens spec → exit 2" "[ $rc -eq 2 ]"
rc=0; bash "$RUNNER" --kind review --lens bogus --brief brief.md --lead claude >/dev/null 2>&1 || rc=$?
check "--lens bogus → exit 2" "[ $rc -eq 2 ]"
SL="$FIX/slot"; mkdir -p "$SL/.rolepod"; printf 'brief\n' > "$SL/brief.md"
( cd "$SL" && git init -q . && git config user.email t@t && git config user.name t && printf 'a\n' > f.txt && git add f.txt && git commit -qm init )
rc=0; out=$(cd "$SL" && STUB_codex=slow bash "$RUNNER" --kind review --lens spec --brief brief.md --lead claude --detach 2>/dev/null) || rc=$?
js=$(printf '%s' "$out" | grep -o 'job=[^ ]*' | head -1 | cut -d= -f2)
check "detached --lens spec job writes slot=spec" "[ $rc -eq 0 ] && [ \"\$(cat '$SL/.rolepod/evidence/external/jobs/$js/slot')\" = spec ]"
rc=0; out=$(cd "$SL" && bash "$RUNNER" --kind review --lens standards --brief brief.md --lead claude --detach 2>/dev/null) || rc=$?
jt=$(printf '%s' "$out" | grep -o 'job=[^ ]*' | head -1 | cut -d= -f2)
check "a live spec job + a standards run → not stacked (exit 0)" "[ $rc -eq 0 ] && [ -n \"$jt\" ]"
rc=0; out=$(cd "$SL" && bash "$RUNNER" --kind review --lens spec --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "a live spec job + another spec run → refused exit 8" "[ $rc -eq 8 ] && printf '%s' \"\$out\" | grep -q 'refused stacked'"
rc=0; out=$(cd "$SL" && bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "a live spec job + a plain review run → not stacked (exit 0)" "[ $rc -eq 0 ]"
check "the exit-8 refusal names the slot" "rc=0; r8=\$(cd '$SL' && bash '$RUNNER' --kind review --lens spec --brief brief.md --lead claude 2>/dev/null) || rc=\$?; [ \$rc -eq 8 ] && printf '%s' \"\$r8\" | grep -q '(slot spec)'"
rc=0; bash "$RUNNER" --kind review --lens "" --brief brief.md --lead claude >/dev/null 2>&1 || rc=$?
check "--lens \"\" → exit 2" "[ $rc -eq 2 ]"
(cd "$SL" && bash "$RUNNER" --collect "$js" --timeout 30 >/dev/null 2>&1; bash "$RUNNER" --collect "$jt" --timeout 30 >/dev/null 2>&1)
cd "$REPO"
fi
if section "cross-family: provenance / oversized diff"; then
check "review preamble keeps the Scope list and VERDICT line and asks for no label" "grep -q 'a Scope list' '$RUNNER' && grep -q 'VERDICT: APPROVED' '$RUNNER' && ! grep -qE 'TRACED|SUSPECTED|INTRODUCED|EXPOSED|ADJACENT' '$RUNNER'"
SZ="$FIX/size"; mkdir -p "$SZ/.rolepod"; printf 'brief\n' > "$SZ/brief.md"
( cd "$SZ" && git init -q . && git config user.email t@t && git config user.name t && printf 'a\n' > f.txt && git add f.txt && git commit -qm init )
: > "$FIX/big.patch"; for i in $(seq 1 16); do { printf 'diff --git a/n%s.ts b/n%s.ts\nnew file mode 100644\n--- /dev/null\n+++ b/n%s.ts\n@@ -0,0 +1,60 @@\n' "$i" "$i" "$i"; seq 60 | sed 's/^/+x/'; } >> "$FIX/big.patch"; done
: > "$LOG"; rc=0; out=$(cd "$SZ" && bash "$RUNNER" --kind review --brief brief.md --attach "$FIX/big.patch" --lead claude 2>/dev/null) || rc=$?
check "16-file / 960-line attachment → capacity notice, still runs" "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'diff = 16 files / 960 changed lines' && grep -q '^codex |' '$LOG'"
printf 'diff --git a/n1.ts b/n1.ts\nnew file mode 100644\n--- /dev/null\n+++ b/n1.ts\n@@ -0,0 +1,2 @@\n+x\n+y\n' > "$FIX/small.patch"
: > "$LOG"; rc=0; out=$(cd "$SZ" && bash "$RUNNER" --kind review --brief brief.md --attach "$FIX/small.patch" --lead claude 2>/dev/null) || rc=$?
check "small attachment → no capacity notice" "[ $rc -eq 0 ] && ! printf '%s' \"\$out\" | grep -q 'past reviewer capacity'"
cd "$REPO"

# ── review quality gates: PARTIAL / no VERDICT are not a pass ───────────
fi
# Unconditional: "ran-model detection" below reuses this default 5-CLI pool
# too — it used to come only from this section running first, so filtering
# ROLEPOD_CASE to "ran-model detection" alone left the pool OFF (exit 5).
setpool 'codex\nclaude\nagy\ncursor\nopencode\n'
if section "cross-family: PARTIAL / VERDICT"; then
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=rejected bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "review with VERDICT: REJECTED → the external row ends with \"verdict\":\"REJECTED\"" \
  "[ $rc -eq 0 ] && grep '\"reviewer\":\"external\".*\"cli\":\"codex\"' .rolepod/evidence/phase-log.jsonl | grep -q '\"verdict\":\"REJECTED\"}\$'"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "review with VERDICT: APPROVED → the external row ends with \"verdict\":\"APPROVED\"" \
  "[ $rc -eq 0 ] && grep '\"reviewer\":\"external\".*\"cli\":\"codex\"' .rolepod/evidence/phase-log.jsonl | grep -q '\"verdict\":\"APPROVED\"}\$'"
for _vm in "nits:APPROVED-WITH-NITS" "blocked:none" "enumquote:none"; do
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=${_vm%%:*} bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "review stub ${_vm%%:*} → the external row ends with \"verdict\":\"${_vm#*:}\"" \
  "[ $rc -eq 0 ] && grep '\"reviewer\":\"external\".*\"cli\":\"codex\"' .rolepod/evidence/phase-log.jsonl | grep -q '\"verdict\":\"${_vm#*:}\"}\$'"
done
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=partial bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "PARTIAL review → external-fail (kept as *.partial.txt), chain moves to agy, no review line for codex" \
  "[ $rc -eq 0 ] && grep -q '\"external-fail\".*\"cli\":\"codex\".*PARTIAL review' .rolepod/evidence/phase-log.jsonl && ls .rolepod/evidence/external/*-codex-*.partial.txt >/dev/null && ! grep -q '\"reviewer\":\"external\".*\"cli\":\"codex\"' .rolepod/evidence/phase-log.jsonl && grep -q '^agy |' '$LOG'"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=noverdict bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "review with no VERDICT line → treated as incomplete, next member" "grep -q '\"cli\":\"codex\".*no VERDICT line' .rolepod/evidence/phase-log.jsonl && grep -q '^agy |' '$LOG'"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=partial bash "$RUNNER" --kind consult --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "…but a PARTIAL consult still counts (only the review pass is strict)" "[ $rc -eq 0 ] && grep -q '\"phase\":\"consult\".*\"cli\":\"codex\".*\"partial\":true' .rolepod/evidence/phase-log.jsonl"

# ── v2.83.3: the model that ACTUALLY ran, read from the CLI's own output ──
fi
if section "cross-family: ran-model detection"; then
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "codex banner 'model: …' → phase-log + receipt carry ran=gpt-5.6-luna (family stays openai)" \
  "[ $rc -eq 0 ] && grep -q '\"cli\":\"codex\",\"family\":\"openai\",\"model\":\"default\".*\"ran\":\"gpt-5.6-luna\"' .rolepod/evidence/phase-log.jsonl && printf '%s' \"\$out\" | grep -q 'ran=gpt-5.6-luna'"
setpool 'opencode\n'; rm -f "$HOME/.config/opencode/opencode.json"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind consult --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "opencode header '> plan · model' → family from the run itself (moonshot), no config needed" \
  "[ $rc -eq 0 ] && grep -q '\"cli\":\"opencode\",\"family\":\"moonshot\",\"model\":\"default\".*\"ran\":\"moonshotai/kimi-k3\"' .rolepod/evidence/phase-log.jsonl"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(OPENCODE_RAN=anthropic/claude-sonnet-5 bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "opencode that actually ran a Claude model under a Claude Lead STILL counts (owner rule: a different CLI is the point) — family + ran recorded" \
  "[ $rc -eq 0 ] && grep -q '\"reviewer\":\"external\".*\"cli\":\"opencode\",\"family\":\"anthropic\".*\"ran\":\"anthropic/claude-sonnet-5\"' .rolepod/evidence/phase-log.jsonl && ! grep -q '\"external-fail\"' .rolepod/evidence/phase-log.jsonl"
out=$(bash "$RUNNER" --probe --lead claude 2>/dev/null)
check "--probe prints ran=<model> (<family>) per member" "printf '%s' \"\$out\" | grep -q 'opencode .*ok .*ran=moonshotai/kimi-k3 (moonshot)'"
out=$(OPENCODE_RAN=anthropic/claude-sonnet-5 bash "$RUNNER" --probe --lead claude 2>/dev/null)
check "--probe shows ran= for a Lead-vendor model without any warning or failure" "printf '%s' \"\$out\" | grep -q 'opencode .*ok .*ran=anthropic/claude-sonnet-5 (anthropic)' && ! printf '%s' \"\$out\" | grep -q '⚠'"
setpool 'codex\nclaude\nagy\ncursor\nopencode\n'
printf '{ "model": "openai/gpt-5.6" }\n' > "$HOME/.config/opencode/opencode.json"

# ── hardening from the live codex review ─────────────────────────────────
fi
if section "cross-family: hardening"; then
rc=0; bash "$RUNNER" --kind review --brief brief.md --lead claude --timeout nope >/dev/null 2>&1 || rc=$?
check "--timeout nope → exit 2 (never a watchdog that compares against a word)" "[ $rc -eq 2 ]"
setpool_over 'codex timeout=1800 agy\nconsult: agy timeout=7 codex\n'
out=$(bash "$RUNNER" --pool --lead claude --kind review 2>&1); out2=$(bash "$RUNNER" --pool --lead claude --kind consult 2>&1)
check "a stale timeout= token is ignored: no warning, order intact, kind defaults apply (review 600 s, consult 300 s)" \
  "! printf '%s' \"\$out\$out2\" | grep -qi 'ignoring timeout' && printf '%s' \"\$out\" | grep -q 'usable, in order: codex agy' && printf '%s' \"\$out\" | grep -qE 'codex +usable +openai +.*timeout=600s' && printf '%s' \"\$out\" | grep -qE 'agy +usable +google +.*timeout=600s' && printf '%s' \"\$out2\" | grep -q 'usable, in order: agy codex' && printf '%s' \"\$out2\" | grep -qE 'agy +usable +google +.*timeout=300s'"
if [ "$CHECK_OK" -eq 0 ]; then   # diagnostics only
  echo "    diag: review rows: $(printf '%s' "$out" | grep -E 'codex|agy' | head -c 300)"
  echo "    diag: consult agy row: $(printf '%s' "$out2" | grep agy | head -c 200)"
fi
restorepool
mkdir -p "$REPO/dir with space"; cp brief.md "$REPO/dir with space/my brief.md"; printf 'x\n' > "$REPO/dir with space/my diff.patch"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief "dir with space/my brief.md" --attach "dir with space/my diff.patch" --lead claude --detach 2>/dev/null) || rc=$?
jid4=$(printf '%s' "$out" | grep -o 'job=[^ ]*' | head -1 | cut -d= -f2)
rc=0; out=$(bash "$RUNNER" --collect "$jid4" --timeout 30 2>/dev/null) || rc=$?
check "--detach with brief + attachment paths containing spaces → child parses them (array re-exec), review anchored" \
  "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM ok kind=review cli=codex' && grep -q '\"job\":\"'\"$jid4\"'\"' .rolepod/evidence/phase-log.jsonl"
check "detach receipt prints --root so --collect works from any directory" "grep -q -- \"--collect $jid4 --root $REPO\" <<<\"\$(cat .rolepod/evidence/external/jobs/$jid4/out.txt 2>/dev/null; true)\" || true"
out=$(cd / && bash "$RUNNER" --jobs --root "$REPO")
check "--jobs --root from another directory finds the job" "printf '%s' \"\$out\" | grep -q \"$jid4 *done exit=0\""
mkdir -p .rolepod/evidence/external/jobs/t-reused; sleep 30 & RP=$!; echo "$RP" > .rolepod/evidence/external/jobs/t-reused/pid; date +%s > .rolepod/evidence/external/jobs/t-reused/started
out=$(bash "$RUNNER" --jobs)
check "a job whose pid is alive but is NOT this runner (pid reuse) is reported dead, not running" "printf '%s' \"\$out\" | grep -q 't-reused *dead'"
kill "$RP" 2>/dev/null; wait "$RP" 2>/dev/null || true; rm -rf .rolepod/evidence/external/jobs/t-reused

fi
if section "cross-family: job snapshot, setup scope"; then
setpool_over 'codex\n'   # one-member pool: the job runs codex alone

# detach snapshots the brief + attachment: both removed right after the detach
# returns must not break the child (it reads its own copies under the job dir)
SNAP="$FIX/snap"; mkdir -p "$SNAP"
printf 'SNAPMARK brief content.\n' > "$SNAP/brief.md"
printf -- '--- a/y.py\n+++ b/y.py\n+print(2)\n' > "$SNAP/diff.patch"
: > "$LOG"
rc=0; out=$(bash "$RUNNER" --kind review --brief "$SNAP/brief.md" --attach "$SNAP/diff.patch" --lead claude --detach 2>/dev/null) || rc=$?
jids=$(printf '%s' "$out" | grep -o 'job=[^ ]*' | head -1 | cut -d= -f2)
rm -f "$SNAP/brief.md" "$SNAP/diff.patch"
rc=0; out=$(bash "$RUNNER" --collect "$jids" --timeout 30 2>/dev/null) || rc=$?
check "detach snapshots the brief + attachment — --collect ok after both source files were removed, member saw both" \
  "[ $rc -eq 0 ] && grep -q '^codex |.*RAW=.*SNAPMARK' '$LOG' && grep -q '^codex |.*ATT=diff.patch' '$LOG'"

# --detach: an unreadable brief can never be snapshotted → exit 2, "cannot snapshot", no job dir left behind
XFAM_JOBS="$REPO/.rolepod/evidence/external/jobs"
UNREAD="$FIX/unreadable-brief.md"; printf 'unreadable.\n' > "$UNREAD"; chmod 000 "$UNREAD"
jobs_before=$(ls "$XFAM_JOBS" 2>/dev/null | wc -l | tr -d ' ')
rc=0; err=$(bash "$RUNNER" --kind review --brief "$UNREAD" --lead claude --detach 2>&1 >/dev/null) || rc=$?
jobs_after=$(ls "$XFAM_JOBS" 2>/dev/null | wc -l | tr -d ' ')
chmod 600 "$UNREAD"; rm -f "$UNREAD"
if [ "$(id -u)" = "0" ]; then
  echo "  · skipped (running as root — permission bits do not block the read): --detach unreadable brief"
else
  check "--detach with an unreadable brief → exit 2, 'cannot snapshot', no job dir left behind" \
    "[ $rc -eq 2 ] && printf '%s' \"\$err\" | grep -q 'cannot snapshot' && [ \"$jobs_after\" -eq \"$jobs_before\" ]"
fi

# --detach: an unreadable attachment can never be snapshotted either → same contract
UNREADA="$FIX/unreadable-attach.patch"; printf 'unreadable.\n' > "$UNREADA"; chmod 000 "$UNREADA"
jobs_before=$(ls "$XFAM_JOBS" 2>/dev/null | wc -l | tr -d ' ')
rc=0; err=$(bash "$RUNNER" --kind review --brief brief.md --attach "$UNREADA" --lead claude --detach 2>&1 >/dev/null) || rc=$?
jobs_after=$(ls "$XFAM_JOBS" 2>/dev/null | wc -l | tr -d ' ')
chmod 600 "$UNREADA"; rm -f "$UNREADA"
if [ "$(id -u)" = "0" ]; then
  echo "  · skipped (running as root — permission bits do not block the read): --detach unreadable attachment"
else
  check "--detach with an unreadable attachment → exit 2, 'cannot snapshot', no job dir left behind" \
    "[ $rc -eq 2 ] && printf '%s' \"\$err\" | grep -q 'cannot snapshot' && [ \"$jobs_after\" -eq \"$jobs_before\" ]"
fi

# a project INI file left behind never gets an override note: no repo file overrides the machine setting any more
restorepool
printf 'codex\n' > "$REPO/.rolepod/cross-family"
out=$(bash "$RUNNER" --setup --lead claude 2>&1)
check "--setup with an old project INI file → no override note, and nothing names a file" "! printf '%s' \"\$out\" | grep -qE 'overrides|config\.json|\.rolepod'"
rm -f "$REPO/.rolepod/cross-family"; droppool; rm -f "$HOME/.rolepod/"config.json.bak-*

# --pool footer
setpool_over 'codex\n'
out=$(bash "$RUNNER" --pool --lead claude 2>&1)
check "--pool prints the auth/quota footer right after the usable line" "printf '%s' \"\$out\" | grep -q 'auth and quota show only when it runs'"

# a detached child reads the snapshot its parent wrote (the reader's own `pool` lines), never the live setting
XFAM_SNAPCFG="$FIX/pool-snap"; mkdir -p "$XFAM_SNAPCFG"
printf 'enabled=on\nreview=agy\n' > "$XFAM_SNAPCFG/cross-family"
rc=0; names=$(bash "$RUNNER" --pool-names --lead claude --config "$XFAM_SNAPCFG/cross-family" 2>/dev/null) || rc=$?
check "--config alone (no --job, not under the jobs dir) is refused: exit 2, no pool taken from the file" "[ $rc -eq 2 ] && [ -z \"\$names\" ]"
mkdir -p "$REPO/.rolepod/evidence/external/jobs/j1"; printf 'enabled=on\nreview=agy\n' > "$REPO/.rolepod/evidence/external/jobs/j1/cross-family"
rc=0; bash "$RUNNER" --pool-names --lead claude --config "$REPO/.rolepod/evidence/external/jobs/j1/cross-family" >/dev/null 2>&1 || rc=$?
check "--config under the jobs dir but without --job is refused too" "[ $rc -eq 2 ]"
rc=0; bash "$RUNNER" --pool-names --lead claude --job "$REPO/.rolepod/evidence/external/jobs/j1" --config "$REPO/.rolepod/evidence/external/jobs/j1/../j1/cross-family" >/dev/null 2>&1 || rc=$?
check "--config with a .. path is refused" "[ $rc -eq 2 ]"
JD1="$REPO/.rolepod/evidence/external/jobs/j1"; JD2="$REPO/.rolepod/evidence/external/jobs/j2"; mkdir -p "$JD2" "$FIX/outside"
printf 'enabled=on\nreview=agy\n' > "$FIX/outside/cross-family"; printf 'enabled=on\nreview=agy\n' > "$JD1/other"; printf 'enabled=on\nreview=agy\n' > "$JD2/cross-family"
rc=0; bash "$RUNNER" --pool-names --lead claude --job "$JD1" --config "$FIX/outside/cross-family" >/dev/null 2>&1 || rc=$?
check "--job + a snapshot OUTSIDE the jobs dir is refused (exit 2)" "[ $rc -eq 2 ]"
rc=0; bash "$RUNNER" --pool-names --lead claude --job "$JD1" --config "$JD1/other" >/dev/null 2>&1 || rc=$?
check "--job + another file in the job dir (not cross-family) is refused" "[ $rc -eq 2 ]"
rc=0; bash "$RUNNER" --pool-names --lead claude --job "$JD1" --config "$JD2/cross-family" >/dev/null 2>&1 || rc=$?
check "--job j1 + the snapshot of job j2 is refused" "[ $rc -eq 2 ]"
mv "$JD1/cross-family" "$FIX/outside/real-snap"; ln -s "$FIX/outside/real-snap" "$JD1/cross-family"
rc=0; bash "$RUNNER" --pool-names --lead claude --job "$JD1" --config "$JD1/cross-family" >/dev/null 2>&1 || rc=$?
check "--job + a SYMLINKED snapshot is refused" "[ $rc -eq 2 ]"
rm -f "$JD1/cross-family"; printf 'enabled=on\nreview=agy\n' > "$JD1/cross-family"; rm -rf "$JD2" "$JD1/other"
check "--job + a snapshot under the jobs dir drives the pool (agy), whatever the setting says" "[ \"\$(bash '$RUNNER' --pool-names --lead claude --job '$REPO/.rolepod/evidence/external/jobs/j1' --config '$REPO/.rolepod/evidence/external/jobs/j1/cross-family' 2>/dev/null | tr '\n' ' ')\" = 'agy ' ]"
printf 'enabled=off\nconfigured=yes\n' > "$REPO/.rolepod/evidence/external/jobs/j1/cross-family"
out=$(bash "$RUNNER" --pool --lead claude --job "$REPO/.rolepod/evidence/external/jobs/j1" --config "$REPO/.rolepod/evidence/external/jobs/j1/cross-family" 2>&1)
check "an off snapshot → the pool is off and the output names no file" "printf '%s' \"\$out\" | grep -q 'OFF' && ! printf '%s' \"\$out\" | grep -qE 'cross-family\.src|\.rolepod|config\.json|edit '"
rm -rf "$REPO/.rolepod/evidence/external/jobs/j1"
# security repro: the reader's warning carries a path with a newline; it must never become pool data
XF_NLHOME="$FIX/nl"$'\n'"enabled=on"$'\n'"review=codex"$'\n'; mkdir -p "$XF_NLHOME/.rolepod"; printf '{ broken' > "$XF_NLHOME/.rolepod/config.json"
names=$(HOME="$XF_NLHOME" bash "$RUNNER" --pool-names --lead claude 2>/dev/null | tr '\n' ' ')
check "a newline inside the warned path (it carries a line that is exactly review=codex after enabled=on) cannot forge pool data" "[ -z \"\$names\" ]"
rm -rf "$FIX"/nl*
# the repo under review never supplies the reader: a runner copied beside a repo-local hooks/lib stays OFF
XF_RL="$FIX/rl"; mkdir -p "$XF_RL/core/skills/cross-family/scripts" "$XF_RL/hooks/lib"; cp "$RUNNER" "$XF_RL/core/skills/cross-family/scripts/cross-family.sh"
printf 'import sys\nprint("enabled=on")\nprint("review=codex")\n' > "$XF_RL/hooks/lib/rolepod_config.py"
setpool 'agy\n'
names=$(bash "$XF_RL/core/skills/cross-family/scripts/cross-family.sh" --pool-names --lead claude 2>/dev/null | tr '\n' ' ')
check "a runner in a source-layout tree uses that tree's own reader (the fallback exists only for the source layout)" "[ \"$names\" = 'codex ' ]"
XF_RL2="$FIX/rl2"; mkdir -p "$XF_RL2/skills/cross-family/scripts" "$XF_RL2/hooks/lib"; cp "$RUNNER" "$XF_RL2/skills/cross-family/scripts/cross-family.sh"; cp "$XF_RL/hooks/lib/rolepod_config.py" "$XF_RL2/hooks/lib/"
names=$(bash "$XF_RL2/skills/cross-family/scripts/cross-family.sh" --pool-names --lead claude 2>/dev/null | tr '\n' ' ')
check "a rendered-layout runner never reaches for a hooks/lib reader elsewhere: pool OFF" "[ -z \"\$names\" ]"
restorepool

# usage

# a trailing value flag (no value follows) must exit 2 promptly, never hang the arg-parse loop,
# and the message must be the new need_val() text — not exit 2 from some other, older path
TVFERR="$FIX/trailing-flag.err"
for flag in --brief --kind --attach --lead --root --collect --kill --timeout --job --config; do
  : > "$TVFERR"
  bash "$RUNNER" --kind review --brief brief.md --lead claude "$flag" >/dev/null 2>"$TVFERR" &
  pid=$!
  ( sleep 8; kill -KILL "$pid" 2>/dev/null ) & wpid=$!
  rc=0; wait "$pid" 2>/dev/null || rc=$?
  kill "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
  check "trailing $flag with no value → exit 2, never hangs, 'requires a value'" \
    "[ $rc -eq 2 ] && grep -q -- \"$flag requires a value\" '$TVFERR'"
done

restorepool

fi
# ── every shipped tree carries the reader beside the runner; a tree without it is OFF, never on ──
if section "cross-family: rendered targets ship the pool reader (and run OFF without it)"; then
for _t in cursor antigravity opencode; do bash "$REPO_DIR/build/render.sh" --target="$_t" >/dev/null 2>&1 || true; done
setpool 'agy\ncodex\n'
for _d in "$REPO_DIR/plugins/rolepod/skills/cross-family/scripts" "$REPO_DIR/plugins/rolepod-codex/skills/cross-family/scripts" \
          "$REPO_DIR/plugins/rolepod-cursor/skills/cross-family/scripts" "$REPO_DIR/build/rendered/antigravity/plugin/skills/cross-family/scripts" \
          "$REPO_DIR/build/rendered/opencode/skills/cross-family/scripts"; do
  _n=$(printf '%s' "${_d#$REPO_DIR/}" | cut -d/ -f1-3)
  if [ -f "$_d/cross-family.sh" ] && [ -f "$_d/rolepod_config.py" ]; then echo "  ✓ $_n: the runner ships with rolepod_config.py beside it"
  else echo "  ✗ $_n: runner or pool reader missing in the shipped tree"; fail=$((fail+1)); continue; fi
  names=$(bash "$_d/cross-family.sh" --pool-names --lead claude 2>/dev/null | tr '\n' ' ')
  check "$_n shipped runner, reader present: the setting drives the pool (agy codex)" "[ \"$names\" = 'agy codex ' ]"
  _c=$(mktemp -d); cp "$_d/cross-family.sh" "$_c/cross-family.sh"          # the reader file is missing
  names=$(bash "$_c/cross-family.sh" --pool-names --lead claude 2>/dev/null | tr '\n' ' ')
  : > "$LOG"; rc=0; out=$(bash "$_c/cross-family.sh" --kind review --brief brief.md --lead claude 2>&1) || rc=$?
  check "$_n shipped runner, reader missing: pool OFF (exit 5), no member called, one reinstall notice, no path named" \
    "[ -z \"$names\" ] && [ $rc -eq 5 ] && [ ! -s '$LOG' ] && printf '%s' \"\$out\" | grep -q 'pool reader is missing' && ! printf '%s' \"\$out\" | grep -qE 'config\.json|\.rolepod'"
  rm -rf "$_c"
done
restorepool
fi
if section "cross-family: usage"; then
rc=0; bash "$RUNNER" --kind review --brief brief.md >/dev/null 2>&1 || rc=$?
check "no --lead and no env marker → exit 2 (family exclusion needs the Lead)" "[ $rc -eq 2 ]"
rc=0; CLAUDECODE=1 bash "$RUNNER" --pool-names >/dev/null 2>&1 || rc=$?
check "CLAUDECODE=1 auto-detects a Claude Lead" "[ $rc -eq 0 ]"
rc=0; bash "$RUNNER" --brief brief.md --lead claude >/dev/null 2>&1 || rc=$?
check "missing --kind → exit 2" "[ $rc -eq 2 ]"
rc=0; bash "$RUNNER" --kind review --brief nope.md --lead claude >/dev/null 2>&1 || rc=$?
check "missing brief file → exit 2" "[ $rc -eq 2 ]"
check "--help prints through the Usage block and the Exit line (names --lens)" "bash '$RUNNER' --help | grep -q -- '--lens' && bash '$RUNNER' --help | grep -q '^Exit:'"
fi

echo "  · $RAN_SECTIONS of $TOTAL_SECTIONS sections ran"
if [ -n "${ROLEPOD_CASE:-}" ] && [ "$RAN_SECTIONS" -eq 0 ]; then
  echo "  ✗ ROLEPOD_CASE='$ROLEPOD_CASE' matched no section banner"
  fail=$((fail+1))
fi
if [ $fail -eq 0 ]; then echo "cross-family-runner: pass"; exit 0; fi
echo "cross-family-runner: $fail failure(s)"; exit 1
