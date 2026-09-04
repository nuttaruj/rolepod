#!/bin/bash
# cross-family-runner — behavioral test of scripts/cross-family.sh with stub
# CLIs on a private PATH and a sandbox HOME (never touches the real CLIs or
# ~/.rolepod). Asserts OUTCOMES: which CLI ran, what flags it got, what
# evidence landed on disk, what the phase-log says.
#
#   - default pool = every installed CLI in order, Lead family excluded
#     (agy = google; gemini retired → never in the pool), cursor/opencode
#     family from their configured model
#   - config file (global, then project override) filters + orders; `none` off
#   - NO model / effort flag ever reaches an external (TIER_MODELS is Lead-only)
#   - read-only flags present per CLI; ROLEPOD_BRAIN_SILENT=1 in the child env
#   - success → external/<ts>-<cli>.txt + phase-log review line the gate reads
#   - failure → external-fail line, next member; all fail → exit 3; empty → 4
#   - --all runs one member per family concurrently; timeout kills a hung CLI
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
_in=\$(head -c 2000 2>/dev/null | grep -o 'ADVERSARIAL code reviewer\|debugging advisor\|planning advisor' | head -1)
case "\$_in" in *ADVERSARIAL*) _in=review ;; *debugging*) _in=consult ;; *planning*) _in=advise ;; *) _in=none ;; esac
printf '%s | %s | BRAIN=%s | STDIN=%s\n' "$2" "\$(printf '%s' "\$*" | tr '\n' ' ')" "\${ROLEPOD_BRAIN_SILENT:-unset}" "\$_in" >> "$LOG"
mode=\$(eval "printf '%s' \"\\\${STUB_$2:-ok}\"")
case "\$mode" in
  fail) echo "auth error" >&2; exit 1 ;;
  empty) exit 0 ;;
  hang) sleep 30 & echo \$! > "$FIX/grandchild.\$\$"; wait; exit 0 ;;
  short) printf 'LGTM %s\n' "\$(head -c 300 /dev/zero | tr '\\0' 'y')"; exit 0 ;;
esac
[ -n "\${CODEX_MSG_OUT:-}" ] && : # (unused)
_msg=""; _prev=""; for a in "\$@"; do [ "\$_prev" = "-o" ] && _msg="\$a"; _prev="\$a"; done
if [ -n "\$_msg" ]; then echo "event-stream noise" ; { printf '%s review by $2: ' "\${KIND_HINT:-}"; head -c 600 /dev/zero | tr '\0' 'x'; printf '\nVERDICT: APPROVED\n'; } > "\$_msg"; exit 0; fi
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
echo "── cross-family: pool resolution ──"
names=$(bash "$RUNNER" --pool-names --lead claude | tr '\n' ' ')
check "default pool, lead=claude → codex agy cursor opencode (claude excluded; gemini retired, never in the pool)" "[ \"$names\" = 'codex agy cursor opencode ' ]"
names=$(bash "$RUNNER" --pool-names --lead gemini | tr '\n' ' ')
check "lead=gemini (frozen adapter) excludes agy (same family)" "[ \"$names\" = 'codex claude cursor opencode ' ]"
names=$(bash "$RUNNER" --pool-names --lead agy | tr '\n' ' ')
check "lead=agy → codex claude cursor opencode" "[ \"$names\" = 'codex claude cursor opencode ' ]"
out=$(bash "$RUNNER" --pool --lead claude); printf 'gemini\ncodex\n' > "$FIX/gcfg"
mkdir -p "$HOME/.rolepod"; cp "$FIX/gcfg" "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --pool --lead claude); rm -f "$HOME/.rolepod/cross-family"
check "a 'gemini' config line is skipped as retired (points at agy), never invoked" "printf '%s' \"\$out\" | grep -qE 'gemini +skipped +google +retired'"
out=$(bash "$RUNNER" --pool --lead claude)
check "cursor / opencode flagged family unknown when no default model configured" "printf '%s' \"\$out\" | grep -q 'cursor .*unknown' && printf '%s' \"\$out\" | grep -q 'opencode .*unknown'"

# opencode default model → family resolves; same family as Lead → skipped
mkdir -p "$HOME/.config/opencode"; printf '{ "model": "anthropic/claude-sonnet-5" }\n' > "$HOME/.config/opencode/opencode.json"
out=$(bash "$RUNNER" --pool --lead claude)
check "opencode with a Claude default model is skipped under a Claude Lead" "printf '%s' \"\$out\" | grep -q 'opencode  skipped  anthropic'"
names=$(bash "$RUNNER" --pool-names --lead codex | tr '\n' ' ')
check "…but usable under a Codex Lead" "printf '%s' \"$names\" | grep -qw opencode"
printf '{ "model": "openai/gpt-5.6" }\n' > "$HOME/.config/opencode/opencode.json"
out=$(bash "$RUNNER" --pool --lead codex)
check "opencode with an OpenAI default model is skipped under a Codex Lead" "printf '%s' \"\$out\" | grep -q 'opencode  skipped  openai'"
# cursor default model
mkdir -p "$HOME/.cursor"; printf '{ "model": "gemini-3-pro" }\n' > "$HOME/.cursor/cli-config.json"
out=$(bash "$RUNNER" --pool --lead gemini)
check "cursor with a Gemini default model is skipped under a Gemini Lead" "printf '%s' \"\$out\" | grep -q 'cursor  *skipped  google'"

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
rc=0; out=$(bash "$RUNNER" --kind review --brief brief.md --lead claude 2>/dev/null) || rc=$?
check "run with an empty pool → exit 4 + ROLEPOD-XFAM empty + external-fail pool-empty line" \
  "[ $rc -eq 4 ] && printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM empty' && grep -q '\"phase\":\"external-fail\".*pool-empty' .rolepod/evidence/phase-log.jsonl"
printf 'bogus\ncodex\n' > "$REPO/.rolepod/cross-family"
out=$(bash "$RUNNER" --pool --lead claude)
check "unknown CLI name in config is reported, not fatal" "printf '%s' \"\$out\" | grep -q 'bogus .*unknown CLI name'"
rm -f "$REPO/.rolepod/cross-family" "$HOME/.rolepod/cross-family"
rm -f "$HOME/.config/opencode/opencode.json" "$HOME/.cursor/cli-config.json"

# ── run: success path anchors evidence ──────────────────────────────────
echo "── cross-family: run + evidence ──"
: > "$LOG"; : > .rolepod/evidence/phase-log.jsonl
rc=0; out=$(KIND_HINT=adversarial bash "$RUNNER" --kind review --brief brief.md --attach diff.patch --lead claude 2>/dev/null) || rc=$?
check "review run → exit 0, first usable member (codex) answered" "[ $rc -eq 0 ] && grep -q '^codex |' '$LOG' && ! grep -q '^gemini |' '$LOG'"
check "output ends with the ROLEPOD-XFAM ok trailer naming cli + raw path" "printf '%s' \"\$out\" | grep -q 'ROLEPOD-XFAM ok kind=review cli=codex family=openai raw=.rolepod/evidence/external/'"
raw=$(ls .rolepod/evidence/external/*-codex.txt 2>/dev/null | head -1)
check "raw evidence file written ≥ 500 bytes (the gate's floor)" "[ -n \"$raw\" ] && [ \"\$(wc -c < \"$raw\" | tr -d ' ')\" -ge 500 ]"
check "raw file header records cli / family / lead" "grep -q 'cli=codex family=openai lead=claude' \"$raw\""
check "codex: the -o final message is the evidence, not the stdout event stream" "grep -q 'VERDICT: APPROVED' \"$raw\" && ! grep -q 'event-stream noise' \"$raw\""
check "phase-log carries the review line precommit-gate reads" \
  "grep -q '\"phase\":\"review\",\"reviewer\":\"external\",\"kind\":\"review\",\"cli\":\"codex\",\"family\":\"openai\",\"model\":\"default\",\"raw\":\"external/' .rolepod/evidence/phase-log.jsonl"
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
check "failed raw kept as *.failed.txt for audit" "ls .rolepod/evidence/external/*-codex.failed.txt >/dev/null"
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
check "--all runs one member per family concurrently (codex + agy + cursor + opencode)" \
  "[ $rc -eq 0 ] && grep -q '^codex |' '$LOG' && grep -q '^agy |' '$LOG' && ! grep -q '^gemini |' '$LOG' && grep -q '^cursor |' '$LOG' && grep -q '^opencode |' '$LOG'"
check "--all output carries one ===== block + ok trailer per member" "[ \"\$(printf '%s' \"\$out\" | grep -c '^ROLEPOD-XFAM ok kind=advise')\" -eq 4 ]"
check "advise lines logged with phase=advise" "[ \"\$(grep -c '\"phase\":\"advise\",\"reviewer\":\"external\"' .rolepod/evidence/phase-log.jsonl)\" -eq 4 ]"
check "cursor got plan mode + --trust, opencode got --agent plan; neither got a model flag" \
  "grep '^cursor |' '$LOG' | grep -q -- '--mode plan' && grep '^cursor |' '$LOG' | grep -q -- '--trust' && grep '^opencode |' '$LOG' | grep -q -- '--agent plan' && ! grep -E '^(cursor|opencode) \|' '$LOG' | grep -qE -- '--model| -m '"

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
