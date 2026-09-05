#!/bin/bash
# cross-family-runner — behavioral test of scripts/cross-family.sh with stub
# CLIs on a private PATH and a sandbox HOME (never touches the real CLIs or
# ~/.rolepod). Asserts OUTCOMES: which CLI ran, what flags it got, what
# evidence landed on disk, what the phase-log says.
#
#   - OPT-IN: no config file = OFF (exit 5, nothing logged, candidates listed);
#     `none` = OFF; the config file (global, project override) lists + orders
#     the pool; Lead family excluded (agy = google; gemini retired → never in
#     the pool), cursor/opencode family from their configured model
#   - NO model / effort flag ever reaches an external (TIER_MODELS is Lead-only)
#   - read-only flags present per CLI; ROLEPOD_BRAIN_SILENT=1 in the child env
#   - success → external/<ts>-<cli>.txt + phase-log review line the gate reads
#   - failure → external-fail line, next member; all fail → exit 3; empty → 4
#   - --all runs every usable member concurrently; timeout kills a hung CLI
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
RUNNER="$REPO_DIR/scripts/cross-family.sh"
fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi; }

FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-xfam-test.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
export HOME="$FIX/home"; mkdir -p "$HOME"
BIN="$FIX/bin"; mkdir -p "$BIN"
LOG="$FIX/calls.log"

# Stub: records "<name> | args | BRAIN=<env>" and behaves per $STUB_<NAME>:
#   ok (default) → prints ~600 bytes of review; fail → exit 1; empty → exit 0
#   with no output; hang → sleep 30.
mk_stub() { # $1 binary name, $2 label
  cat > "$BIN/$1" <<EOF
#!/bin/bash
_raw=\$(head -c 3000 2>/dev/null)
_in=\$(printf '%s' "\$_raw" | grep -o 'ADVERSARIAL code reviewer\|debugging advisor\|planning advisor\|spec critic' | head -1)
_bud=\$(printf '%s' "\$_raw" | grep -o 'Time budget: about [0-9]* minute' | grep -o '[0-9]*')
_argbud=\$(printf '%s' "\$*" | grep -o 'Time budget: about [0-9]* minute' | grep -o '[0-9]*')
case "\$_in" in *ADVERSARIAL*) _in=review ;; *debugging*) _in=consult ;; *planning*) _in=advise ;; *critic*) _in=critique ;; *) _in=none ;; esac
printf '%s | %s | BRAIN=%s | STDIN=%s | BUDGET=%s\n' "$2" "\$(printf '%s' "\$*" | tr '\n' ' ')" "\${ROLEPOD_BRAIN_SILENT:-unset}" "\$_in" "\${_bud:-\$_argbud}" >> "$LOG"
if [ "\$1" = "models" ]; then printf '%s\n' "\${CURSOR_MODELS_OUT:-auto - Auto (current, default)}"; exit 0; fi
mode=\$(eval "printf '%s' \"\\\${STUB_$2:-ok}\"")
case "\$mode" in
  fail) echo "auth error" >&2; exit 1 ;;
  empty) exit 0 ;;
  hang) sleep 30 & echo \$! > "$FIX/grandchild.\$\$"; wait; exit 0 ;;
  short) printf 'LGTM %s\n' "\$(head -c 300 /dev/zero | tr '\\0' 'y')"; exit 0 ;;
  slow) sleep 4 ;;
  partial) printf 'PARTIAL — budget nearly spent. Findings so far: %s\n' "\$(head -c 600 /dev/zero | tr '\\0' p)"; exit 0 ;;
  noverdict) printf 'Findings: %s\n' "\$(head -c 600 /dev/zero | tr '\\0' q)"; exit 0 ;;
esac
[ -n "\${CODEX_MSG_OUT:-}" ] && : # (unused)
_msg=""; _prev=""; for a in "\$@"; do [ "\$_prev" = "-o" ] && _msg="\$a"; _prev="\$a"; done
if [ -n "\$_msg" ]; then echo "event-stream noise" ; printf 'model: %s\n' "\${CODEX_RAN:-gpt-5.6-luna}" >&2; { printf '%s review by $2: ' "\${KIND_HINT:-}"; head -c 600 /dev/zero | tr '\0' 'x'; printf '\nVERDICT: APPROVED\n'; } > "\$_msg"; exit 0; fi
[ "$2" = opencode ] && printf '> plan · %s\n' "\${OPENCODE_RAN:-moonshotai/kimi-k3}" >&2   # real opencode prints this header on stderr
printf '%s review by $2: ' "\${KIND_HINT:-}"; head -c 600 /dev/zero | tr '\0' 'x'; printf '\nVERDICT: APPROVED\n'
EOF
  chmod +x "$BIN/$1"
}
for b in codex claude gemini agy opencode; do mk_stub "$b" "$b"; done   # gemini stub exists on PATH but is retired → never called
mk_stub cursor-agent cursor
export PATH="$BIN:/usr/bin:/bin"
unset ROLEPOD_LEAD_CLI CLAUDECODE CLAUDE_PLUGIN_ROOT

# Sandbox repo (git root = evidence root)
REPO="$FIX/repo"; mkdir -p "$REPO"; git -C "$REPO" init -q; cd "$REPO"
printf 'Review this diff.\n' > brief.md
printf -- '--- a/x.py\n+++ b/x.py\n+print(1)\n' > diff.patch

# ── pool ────────────────────────────────────────────────────────────────
echo "── cross-family: opt-in default (no config = OFF) ──"
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "no config file → pool EMPTY (cross-family is opt-in)" "[ -z \"$names\" ]"
out=$(bash "$RUNNER" --pool --lead claude)
check "--pool says OFF + lists installed candidates with families + the enable hint" \
  "printf '%s' \"\$out\" | grep -q 'OPT-IN and not enabled' && printf '%s' \"\$out\" | grep -q 'candidates: codex(openai) agy(google) cursor(unknown) opencode(unknown)' && printf '%s' \"\$out\" | grep -q 'enable: printf'"
cand=$(bash "$RUNNER" --candidates --lead claude | tr '\n' ' ')
check "--candidates lists the other installed CLIs (claude excluded, gemini never)" "[ \"$cand\" = 'codex(openai) agy(google) cursor(unknown) opencode(unknown) ' ]"
cand=$(bash "$RUNNER" --candidates --lead codex | tr '\n' ' ')
check "--candidates under a Codex Lead drops codex, keeps claude" "[ \"$cand\" = 'claude(anthropic) agy(google) cursor(unknown) opencode(unknown) ' ]"
: > "$LOG"; mkdir -p .rolepod/evidence; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "run while OFF → exit 5, ROLEPOD-XFAM off, no CLI called, NOTHING logged (a choice is not a failure)" \
  "[ $rc -eq 5 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM off' && [ ! -s '$LOG' ] && [ ! -s .rolepod/evidence/phase-log.jsonl ]"
rc=0; bash "$RUNNER" --probe --lead claude >/dev/null 2>&1 || rc=$?
check "--probe while OFF → exit 5 without calling anyone" "[ $rc -eq 5 ] && [ ! -s '$LOG' ]"

echo "── cross-family: pool resolution (enabled with every CLI listed) ──"
mkdir -p "$HOME/.rolepod"; printf 'codex\nclaude\nagy\ncursor\nopencode\n' > "$HOME/.rolepod/cross-family"
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "all five listed, lead=claude → codex agy cursor opencode (claude excluded; gemini retired, never in the pool)" "[ \"$names\" = 'codex agy cursor opencode ' ]"
names=$(bash "$RUNNER" --pool-names --lead gemini | tr '\n' ' ')
check "lead=gemini (frozen adapter) still gets agy — a different CLI; family is not a filter" "[ \"$names\" = 'codex claude agy cursor opencode ' ]"
names=$(bash "$RUNNER" --pool-names --lead agy | tr '\n' ' ')
check "lead=agy → codex claude cursor opencode" "[ \"$names\" = 'codex claude cursor opencode ' ]"
out=$(bash "$RUNNER" --pool --lead claude); printf 'gemini\ncodex\n' > "$FIX/gcfg"
mkdir -p "$HOME/.rolepod"; cp "$FIX/gcfg" "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --pool --lead claude); printf 'codex\nclaude\nagy\ncursor\nopencode\n' > "$HOME/.rolepod/cross-family"
check "a 'gemini' config line is skipped as retired (points at agy), never invoked" "printf '%s' \"\$out\" | grep -qE 'gemini +skipped +google +retired'"
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
out=$(bash "$RUNNER" --pool --lead gemini)
check "cursor with a Gemini default model stays usable under a Gemini Lead" "printf '%s' \"\$out\" | grep -q 'cursor  *usable  *google'"
# v2.83.2: Cursor stores "model" as an object; Auto = no fixed family; more vendors; opencode last-used fallback
printf '{ "model": { "modelId": "composer-2.5", "displayName": "Composer 2.5" } }\n' > "$HOME/.cursor/cli-config.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "cursor object-form model.modelId=composer-2.5 → family cursor, model shown" "printf '%s' \"\$out\" | grep -q 'cursor  *usable  *cursor .*model=composer-2.5 (cli-config.json)'"
printf '{ "model": { "modelId": "cursor-grok-4.6-high-fast" } }\n' > "$HOME/.cursor/cli-config.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "cursor grok → family xai" "printf '%s' \"\$out\" | grep -q 'cursor  *usable  *xai '"
printf '{ "model": { "modelId": "default", "displayModelId": "auto" } }\n' > "$HOME/.cursor/cli-config.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "cursor Auto → family unknown with the pin-one hint" "printf '%s' \"\$out\" | grep -q 'cursor  *usable  *unknown .*Cursor Auto routes across vendors'"
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

# ── config: global, project override, none ──────────────────────────────
echo "── cross-family: config ──"
mkdir -p "$HOME/.rolepod"; printf '# my pool\nagy\ncodex\n' > "$HOME/.rolepod/cross-family"
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "global config filters AND orders the pool (agy before codex)" "[ \"$names\" = 'agy codex ' ]"
mkdir -p "$REPO/.rolepod"; printf 'codex\n' > "$REPO/.rolepod/cross-family"
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "project .rolepod/cross-family overrides the global file" "[ \"$names\" = 'codex ' ]"
printf 'none\n' > "$REPO/.rolepod/cross-family"
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "'none' empties the pool" "[ -z \"$names\" ]"
mkdir -p .rolepod/evidence; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "run with 'none' → exit 5 (off by choice), nothing logged" "[ $rc -eq 5 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM off' && [ ! -s .rolepod/evidence/phase-log.jsonl ]"
printf 'claude\n' > "$REPO/.rolepod/cross-family"
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "enabled but only the Lead's own family listed → exit 4 + ROLEPOD-XFAM empty + external-fail pool-empty line (this IS logged)" \
  "[ $rc -eq 4 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM empty' && grep -q '\"phase\":\"external-fail\".*pool-empty' .rolepod/evidence/phase-log.jsonl"
printf 'bogus\ncodex\n' > "$REPO/.rolepod/cross-family"
out=$(bash "$RUNNER" --pool --lead claude)
check "unknown CLI name in config is reported, not fatal" "printf '%s' \"\$out\" | grep -q 'bogus .*unknown CLI name'"
rm -f "$REPO/.rolepod/cross-family"
printf 'codex\nclaude\nagy\ncursor\nopencode\n' > "$HOME/.rolepod/cross-family"   # enabled for the run tests
rm -f "$HOME/.config/opencode/opencode.json" "$HOME/.cursor/cli-config.json"

# ── run: success path anchors evidence ──────────────────────────────────
echo "── cross-family: run + evidence ──"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(KIND_HINT=adversarial bash "$RUNNER" --kind review --brief brief.md --attach diff.patch --lead claude 2>/dev/null) || rc=$?
check "review run → exit 0, first usable member (codex) answered" "[ $rc -eq 0 ] && grep -q '^codex |' '$LOG' && ! grep -q '^gemini |' '$LOG'"
check "output ends with the ROLEPOD-XFAM ok trailer naming cli + raw path" "printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM ok kind=review cli=codex family=openai raw=.rolepod/evidence/external/'"
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
printf 'agy codex # both on one line\n' > "$REPO/.rolepod/cross-family"
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "two names on one config line are two members, not one squashed word" "[ \"$names\" = 'agy codex ' ]"
rm -f "$REPO/.rolepod/cross-family"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=short bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "review output under the 500-byte gate floor is a failure → next member (consult floor stays 200)" \
  "grep -q '\"cli\":\"codex\".*\"reason\":\"empty output (3[0-9][0-9] bytes, floor 500)' .rolepod/evidence/phase-log.jsonl && grep -q '^agy |' '$LOG'"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=short bash "$RUNNER" --kind consult --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "…the same 300-byte answer passes as a consult" "[ $rc -eq 0 ] && grep -q '\"phase\":\"consult\".*\"cli\":\"codex\"' .rolepod/evidence/phase-log.jsonl"

# ── run: failure → next member; all fail → exit 3 ───────────────────────
echo "── cross-family: fallback ──"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=fail STUB_agy=fail bash "$RUNNER" --kind consult --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "codex + agy fail → cursor answers, exit 0 (gemini stub on PATH never called)" "[ $rc -eq 0 ] && grep -q '^cursor |' '$LOG' && ! grep -q '^gemini |' '$LOG'"
check "failure recorded as an external-fail line naming the cli + reason" "grep -q '\"phase\":\"external-fail\",\"kind\":\"consult\",\"cli\":\"codex\".*\"reason\":\"exit 1' .rolepod/evidence/phase-log.jsonl"
check "consult success logs phase=consult (not review — never counts as the strong pass)" "grep -q '\"phase\":\"consult\",\"reviewer\":\"external\".*\"cli\":\"cursor\"' .rolepod/evidence/phase-log.jsonl"
check "failed raw kept as *.failed.txt for audit" "ls .rolepod/evidence/external/*-codex-*.failed.txt >/dev/null"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=empty bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "exit 0 but empty output counts as a failure (installed ≠ usable)" "grep -q '\"cli\":\"codex\".*\"reason\":\"empty output' .rolepod/evidence/phase-log.jsonl && grep -q '^agy |' '$LOG'"
printf 'codex\nagy\n' > "$REPO/.rolepod/cross-family"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(STUB_codex=fail STUB_agy=fail bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "every member fails → exit 3 + ROLEPOD-XFAM none listing each failure" \
  "[ $rc -eq 3 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM none' && printf '%s' \"\$out\" | grep -q 'codex: exit 1' && printf '%s' \"\$out\" | grep -q 'agy: exit 1'"
check "no review line was written on total failure" "! grep -q '\"reviewer\":\"external\"' .rolepod/evidence/phase-log.jsonl"
check "agy got plan mode + print timeout, no --model / --effort" "grep '^agy |' '$LOG' | grep -q -- '--mode plan' && ! grep '^agy |' '$LOG' | grep -qE -- '--model|--effort'"
rm -f "$REPO/.rolepod/cross-family"

# ── timeout ─────────────────────────────────────────────────────────────
echo "── cross-family: timeout ──"
printf 'codex\nagy\n' > "$REPO/.rolepod/cross-family"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
s=$(date +%s); rc=0; out=$(STUB_codex=hang bash "$RUNNER" --kind review --brief brief.md --lead claude --timeout 3 2>/dev/null) || rc=$?; secs=$(( $(date +%s) - s ))
check "hung CLI is killed at --timeout and the next member answers (took ${secs}s, exit $rc)" "[ $rc -eq 0 ] && [ $secs -lt 20 ] && grep -q '\"cli\":\"codex\".*\"reason\":\"timeout 3s' .rolepod/evidence/phase-log.jsonl && grep -q '^agy |' '$LOG'"
gc=$(cat "$FIX"/grandchild.* 2>/dev/null | head -1); sleep 1
check "…and the hung CLI's grandchild (sleep 30) is dead too — no process leak (pgid kill)" "[ -n \"$gc\" ] && ! kill -0 \"$gc\" 2>/dev/null"
rm -f "$REPO/.rolepod/cross-family"

# ── --all panel ─────────────────────────────────────────────────────────
echo "── cross-family: --all panel ──"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind advise --brief brief.md --lead claude --all 2>/dev/null) || rc=$?
check "--all runs every usable member concurrently (codex + agy + cursor + opencode)" \
  "[ $rc -eq 0 ] && grep -q '^codex |' '$LOG' && grep -q '^agy |' '$LOG' && ! grep -q '^gemini |' '$LOG' && grep -q '^cursor |' '$LOG' && grep -q '^opencode |' '$LOG'"
check "--all output carries one ===== block + ok trailer per member" "[ \"\$(printf '%s' \"\$out\" | grep -c '^ROLEPOD-XFAM ok kind=advise')\" -eq 4 ]"
check "advise lines logged with phase=advise" "[ \"\$(grep -c '\"phase\":\"advise\",\"reviewer\":\"external\"' .rolepod/evidence/phase-log.jsonl)\" -eq 4 ]"
check "cursor got plan mode + --trust, opencode got --agent plan; neither got a model flag" \
  "grep '^cursor |' '$LOG' | grep -q -- '--mode plan' && grep '^cursor |' '$LOG' | grep -q -- '--trust' && grep '^opencode |' '$LOG' | grep -q -- '--agent plan' && ! grep -E '^(cursor|opencode) \|' '$LOG' | grep -qE -- '--model| -m '"

# ── critique kind (write-spec) ──────────────────────────────────────────
echo "── cross-family: --kind critique ──"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind critique --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "critique → spec-critic framing on stdin, logged as phase=advise kind=critique (never a strong pass)" \
  "[ $rc -eq 0 ] && grep -q 'STDIN=critique' '$LOG' && grep -q '\"phase\":\"advise\",\"reviewer\":\"external\",\"kind\":\"critique\"' .rolepod/evidence/phase-log.jsonl && ! grep -q '\"phase\":\"review\"' .rolepod/evidence/phase-log.jsonl"

# ── per-CLI timeout, per-kind order, budget line ─────────────────────────
echo "── cross-family: timeouts / per-kind order / budget ──"
printf 'codex timeout=1800\nagy\nconsult: agy codex\n' > "$REPO/.rolepod/cross-family"
out=$(bash "$RUNNER" --pool --lead claude --kind review)
check "review order = default list; codex carries timeout=1800s from config, agy the review default 600s (foreground)" \
  "printf '%s' \"\$out\" | grep -qE 'codex +usable +openai +.*timeout=1800s' && printf '%s' \"\$out\" | grep -qE 'agy +usable +google +.*timeout=600s' && printf '%s' \"\$out\" | grep -q 'usable, in order: codex agy'"
out=$(bash "$RUNNER" --pool --lead claude --kind consult)
check "consult uses the per-kind line: agy first, codex second; agy gets the consult default 300s" \
  "printf '%s' \"\$out\" | grep -q 'per-kind order' && printf '%s' \"\$out\" | grep -q 'usable, in order: agy codex' && printf '%s' \"\$out\" | grep -qE 'agy +usable +google +.*timeout=300s'"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind consult --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "consult run → agy answers first (per-kind order) with a 5-minute budget line in its prompt" "[ $rc -eq 0 ] && grep -q '^agy |.*BUDGET=5' '$LOG' && ! grep -q '^codex |' '$LOG'"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>"$FIX/warn.txt") || rc=$?
check "review run (foreground) → codex gets the configured 1800s budget (30 min in prompt) + a foreground-cap warning on stderr; receipt shows budget" \
  "[ $rc -eq 0 ] && grep -q '^codex |.*BUDGET=30' '$LOG' && grep -q 'exceeds the 600 s foreground cap' '$FIX/warn.txt' && printf '%s' \"\$out\" | grep -q 'budget=1800s' && grep -q '\"budget\":1800' .rolepod/evidence/phase-log.jsonl"
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude --timeout 120 2>/dev/null) || rc=$?
check "--timeout flag overrides the config timeout" "printf '%s' \"\$out\" | grep -q 'budget=120s'"

# ── detach / collect / jobs ──────────────────────────────────────────────
echo "── cross-family: --detach job ──"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
s=$(date +%s); rc=0; out=$(STUB_codex=slow bash "$RUNNER" --kind review --brief brief.md --attach diff.patch --lead claude --detach 2>/dev/null) || rc=$?; secs=$(( $(date +%s) - s ))
jid=$(printf '%s' "$out" | grep -o 'job=[^ ]*' | head -1 | cut -d= -f2)
check "--detach returns at once (${secs}s) with a job id + members + budgets (review detached default 1800s → codex 1800 from config, agy 1800)" \
  "[ $rc -eq 0 ] && [ $secs -lt 3 ] && [ -n \"$jid\" ] && printf '%s' \"\$out\" | grep -q 'members=codex agy' && printf '%s' \"\$out\" | grep -q 'budgets=codex=1800s agy=1800s'"
check "job dir has pid + started + args, no status yet (still running)" "[ -f .rolepod/evidence/external/jobs/$jid/pid ] && [ -f .rolepod/evidence/external/jobs/$jid/started ] && [ ! -f .rolepod/evidence/external/jobs/$jid/status ]"
out=$(bash "$RUNNER" --jobs)
check "--jobs lists the job as running" "printf '%s' \"\$out\" | grep -q \"$jid *running\""
rc=0; out=$(bash "$RUNNER" --collect "$jid" --timeout 1 2>/dev/null) || rc=$?
check "--collect with a short wait → exit 6 'still running'" "[ $rc -eq 6 ] && printf '%s' \"\$out\" | grep -q 'still running'"
rc=0; out=$(bash "$RUNNER" --collect "$jid" --timeout 30 2>/dev/null) || rc=$?
check "--collect waits for the job → prints the review + receipt, exit 0; the child anchored the review line + raw file" \
  "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM ok kind=review cli=codex' && grep -q '\"phase\":\"review\",\"reviewer\":\"external\".*\"cli\":\"codex\"' .rolepod/evidence/phase-log.jsonl && [ -f .rolepod/evidence/external/jobs/$jid/status ] && [ \"\$(cat .rolepod/evidence/external/jobs/$jid/status)\" = 0 ]"
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
rm -f "$REPO/.rolepod/cross-family"; rm -f "$HOME/.rolepod/cross-family"
rc=0; out=$(bash "$RUNNER" --collect "$jid3" --timeout 30 2>/dev/null) || rc=$?
check "config deleted right after --detach → the job still runs on its snapshot and anchors (no exit-5 surprise)" \
  "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM ok kind=review cli=codex' && [ -f .rolepod/evidence/external/jobs/$jid3/cross-family ]"
printf 'codex\nclaude\nagy\ncursor\nopencode\n' > "$HOME/.rolepod/cross-family"
# a child that dies early still leaves a status (trap installed before any exit)
mkdir -p .rolepod/evidence/external/jobs/t-early; : > .rolepod/evidence/external/jobs/t-early/cross-family
rc=0; bash "$RUNNER" --kind review --brief nope.md --lead claude --job "$REPO/.rolepod/evidence/external/jobs/t-early" >/dev/null 2>&1 || rc=$?
check "a job child that exits early (usage error) still writes status (=$rc) so --collect never hangs" "[ $rc -eq 2 ] && [ \"\$(cat .rolepod/evidence/external/jobs/t-early/status)\" = 2 ]"
rm -rf .rolepod/evidence/external/jobs/t-early

# ── review quality gates: PARTIAL / no VERDICT are not a pass ───────────
echo "── cross-family: PARTIAL / VERDICT ──"
printf 'codex\nclaude\nagy\ncursor\nopencode\n' > "$HOME/.rolepod/cross-family"
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
echo "── cross-family: ran-model detection ──"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "codex banner 'model: …' → phase-log + receipt carry ran=gpt-5.6-luna (family stays openai)" \
  "[ $rc -eq 0 ] && grep -q '\"cli\":\"codex\",\"family\":\"openai\",\"model\":\"default\".*\"ran\":\"gpt-5.6-luna\"' .rolepod/evidence/phase-log.jsonl && printf '%s' \"\$out\" | grep -q 'ran=gpt-5.6-luna'"
printf 'opencode\n' > "$HOME/.rolepod/cross-family"; rm -f "$HOME/.config/opencode/opencode.json"
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
printf 'codex\nclaude\nagy\ncursor\nopencode\n' > "$HOME/.rolepod/cross-family"
printf '{ "model": "openai/gpt-5.6" }\n' > "$HOME/.config/opencode/opencode.json"

# ── hardening from the live codex review ─────────────────────────────────
echo "── cross-family: hardening ──"
rc=0; bash "$RUNNER" --kind review --brief brief.md --lead claude --timeout nope >/dev/null 2>&1 || rc=$?
check "--timeout nope → exit 2 (never a watchdog that compares against a word)" "[ $rc -eq 2 ]"
printf 'codex timeout=abc\nagy\n' > "$REPO/.rolepod/cross-family"
out=$(bash "$RUNNER" --pool --lead claude --kind review 2>&1)
check "timeout=abc in the config is ignored with a warning; codex keeps the kind default" "printf '%s' \"\$out\" | grep -q \"ignoring timeout='abc'\" && printf '%s' \"\$out\" | grep -qE 'codex +usable +openai +.*timeout=600s'"
printf 'codex\nagy\nconsult: agy timeout=7 codex\n' > "$REPO/.rolepod/cross-family"
out=$(bash "$RUNNER" --pool --lead claude --kind review); out2=$(bash "$RUNNER" --pool --lead claude --kind consult)
check "a timeout on a consult: line binds to consult only — review keeps agy at 600s, consult sees 7s" \
  "printf '%s' \"\$out\" | grep -qE 'agy +usable +google +.*timeout=600s' && printf '%s' \"\$out2\" | grep -qE 'agy +usable +google +.*timeout=7s'"
rm -f "$REPO/.rolepod/cross-family"
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

# ── usage errors ────────────────────────────────────────────────────────
echo "── cross-family: usage ──"
rc=0; bash "$RUNNER" --kind review --brief brief.md >/dev/null 2>&1 || rc=$?
check "no --lead and no env marker → exit 2 (family exclusion needs the Lead)" "[ $rc -eq 2 ]"
rc=0; CLAUDECODE=1 bash "$RUNNER" --pool-names >/dev/null 2>&1 || rc=$?
check "CLAUDECODE=1 auto-detects a Claude Lead" "[ $rc -eq 0 ]"
rc=0; bash "$RUNNER" --brief brief.md --lead claude >/dev/null 2>&1 || rc=$?
check "missing --kind → exit 2" "[ $rc -eq 2 ]"
rc=0; bash "$RUNNER" --kind review --brief nope.md --lead claude >/dev/null 2>&1 || rc=$?
check "missing brief file → exit 2" "[ $rc -eq 2 ]"

if [ $fail -eq 0 ]; then echo "cross-family-runner: pass"; exit 0; fi
echo "cross-family-runner: $fail failure(s)"; exit 1
