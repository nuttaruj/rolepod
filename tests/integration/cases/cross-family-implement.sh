#!/bin/bash
# cross-family-implement — behavioral test of `rolepod-cross-family --kind implement`
# with a stub member on a private PATH, a sandbox HOME and a scratch git repo.
# Asserts OUTCOMES: the member ran in its WRITE mode inside the repo, the runner
# captured its edits as patch.diff (tracked + untracked) and its final text as
# report.txt, the phase-log carries the implement line, a missing pool is OFF,
# a live job blocks a second one, and opencode without project permissions is
# skipped (not run).
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
RUNNER="$REPO_DIR/scripts/cross-family.sh"
fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi; }
FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-xfam-impl.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
export HOME="$FIX/home"; mkdir -p "$HOME/.rolepod"
BIN="$FIX/bin"; mkdir -p "$BIN"
LOG="$FIX/calls.log"
export PATH="$BIN:/usr/bin:/bin"
export ROLEPOD_XFAM_STALL=3

# Stub codex: records args + the preamble it saw; in implement mode writes one
# tracked edit + one new file inside the repo (-C <root>) and a report to -o.
cat > "$BIN/codex" <<STUB
#!/bin/bash
_raw=\$(head -c 4000 2>/dev/null)
_role=none; printf '%s' "\$_raw" | grep -q 'external IMPLEMENTER' && _role=implementer
printf '%s' "\$_raw" | grep -q 'ADVERSARIAL code reviewer' && _role=reviewer
_bud=\$(printf '%s' "\$_raw" | grep -o 'nothing half-written' | head -1)
printf 'codex | %s | ROLE=%s | BUDGET=%s\n' "\$(printf '%s' "\$*" | tr '\n' ' ')" "\$_role" "\${_bud:-none}" >> "$LOG"
_root=""; _msg=""; _prev=""; for a in "\$@"; do [ "\$_prev" = "-C" ] && _root="\$a"; [ "\$_prev" = "-o" ] && _msg="\$a"; _prev="\$a"; done
case "\${STUB_codex:-ok}" in
  hang) sleep 30 & wait; exit 0 ;;
  fail) echo "boom" >&2; exit 1 ;;
  short) [ -n "\$_msg" ] && printf 'ok\n' > "\$_msg"; echo noise; exit 0 ;;
esac
[ "\${STUB_codex:-ok}" = noop ] && _role=none
if [ "\$_role" = implementer ] && [ -n "\$_root" ]; then
  printf 'hello from codex\n' >> "\$_root/README.md"
  mkdir -p "\$_root/src"; printf 'export const added = true;\n' > "\$_root/src/added.ts"
  printf 'secret\n' > "\$_root/.rolepod/should-not-travel"
fi
_rep="\$(printf 'Implemented the ticket.\nFiles touched: README.md, src/added.ts\nTests: none in this repo\nNOT done: nothing\n%s' "\$(head -c 300 /dev/zero | tr '\0' r)")"
if [ -n "\$_msg" ]; then printf '%s\n' "\$_rep" > "\$_msg"; echo "stream noise"; else printf '%s\n' "\$_rep"; fi
STUB
chmod +x "$BIN/codex"
cat > "$BIN/opencode" <<'STUB'
#!/bin/bash
echo "opencode | $*" >> "${LOG_FILE:?}"; printf 'should not run\n'; exit 0
STUB
chmod +x "$BIN/opencode"; export LOG_FILE="$LOG"

# scratch repo
REPO="$FIX/repo"; mkdir -p "$REPO"; git -C "$REPO" init -q; git -C "$REPO" config user.email t@t; git -C "$REPO" config user.name t
printf 'readme\n' > "$REPO/README.md"; git -C "$REPO" add -A; git -C "$REPO" commit -qm init
mkdir -p "$REPO/.rolepod"
BRIEF="$FIX/brief.md"; printf '# Ticket: add src/added.ts\n\n## Files allowed\nREADME.md, src/added.ts\n\n## Done when\nsrc/added.ts exists.\n' > "$BRIEF"

echo "── implement: opt-in (no pool = OFF) ──"
rm -f "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "no pool file → exit 5, nothing ran" "[ $rc -eq 5 ] && [ ! -f '$LOG' ]"

echo "── implement: --all is refused (one writer per tree) ──"
printf 'codex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind implement --all --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "--kind implement --all → exit 2, nothing ran" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'ONE member at a time' && [ ! -f '$LOG' ]"

echo "── implement: happy path (codex, write mode, patch + report) ──"
printf 'codex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
printf '%s\n' "$out" > "$FIX/out1.txt"
check "exit 0 + ok line kind=implement cli=codex files=2" "[ $rc -eq 0 ] && grep -q 'ROLEPOD-XFAM ok kind=implement cli=codex family=[a-z]* files=2' '$FIX/out1.txt'"
check "codex ran in WRITE mode (-s workspace-write, -C repo), not read-only" "grep -q -- '-s workspace-write' '$LOG' && grep -q -- \"-C $REPO\" '$LOG' && ! grep -q -- 'read-only' '$LOG'"
check "implement preamble + implement budget line reached the member" "grep -q 'ROLE=implementer' '$LOG' && grep -q 'BUDGET=nothing half-written' '$LOG'"
PATCH="$REPO/.rolepod/evidence/$(sed -n 's/.*patch=\.rolepod\/evidence\/\([^ ]*\).*/\1/p' "$FIX/out1.txt" | head -1)"
check "patch.diff holds the tracked edit AND the new file, never .rolepod/" "[ -s '$PATCH' ] && grep -q '^+hello from codex' '$PATCH' && grep -q 'b/src/added.ts' '$PATCH' && grep -q '^+export const added' '$PATCH' && ! grep -q 'should-not-travel' '$PATCH'"
REPORT="$REPO/.rolepod/evidence/$(sed -n 's/.*report=\.rolepod\/evidence\/\([^ ]*\).*/\1/p' "$FIX/out1.txt" | head -1)"
check "report = the member's final message (codex -o), with the runner header" "[ -s '$REPORT' ] && grep -q '^# rolepod cross-family implement' '$REPORT' && grep -q 'Files touched: README.md, src/added.ts' '$REPORT' && ! grep -q 'stream noise' '$REPORT'"
check "phase-log implement line: cli, patch path, files=2" "grep -q '\"phase\":\"implement\".*\"cli\":\"codex\".*\"patch\":\"external/.*\"files\":2,' '$REPO/.rolepod/evidence/phase-log.jsonl'"
check "the tree keeps the member's edits (the Lead reviews + commits them)" "grep -q 'hello from codex' '$REPO/README.md' && [ -f '$REPO/src/added.ts' ]"
git -C "$REPO" checkout -q -- README.md; rm -rf "$REPO/src"

echo "── implement: the Lead's own WIP never travels; a no-op member reports files=0 on one line ──"
printf 'lead wip\n' > "$REPO/lead-wip.txt"; printf 'lead edit\n' >> "$REPO/README.md"
: > "$LOG"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
PATCH="$REPO/.rolepod/evidence/$(printf '%s' "$out" | sed -n 's/.*patch=\.rolepod\/evidence\/\([^ ]*\).*/\1/p' | head -1)"
check "patch = member delta only (src/added.ts + codex line), not lead-wip.txt or the lead edit" "grep -q 'b/src/added.ts' '$PATCH' && grep -q '^+hello from codex' '$PATCH' && ! grep -q 'lead-wip' '$PATCH' && ! grep -q '^+lead edit' '$PATCH'"
rm -f "$REPO/lead-wip.txt"; git -C "$REPO" checkout -q -- README.md; rm -rf "$REPO/src"
out=$(STUB_codex=noop bash "$RUNNER" --kind implement --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "no-op member → exit 0, ONE ok line carrying files=0 AND patch= AND report=" "[ $rc -eq 0 ] && printf '%s\n' \"$out\" | grep -q '^ROLEPOD-XFAM ok kind=implement cli=codex family=[a-z]* files=0 patch=.rolepod/evidence/.* report=.rolepod/evidence/'"
check "every phase-log line is valid JSON (files=0 did not split it)" "python3 -c \"import json,sys; [json.loads(l) for l in open('$REPO/.rolepod/evidence/phase-log.jsonl') if l.strip()]\""
check "phase-log implement line uses phase=implement + report + budget (same vocabulary as review)" "grep -q '\"phase\":\"implement\",\"kind\":\"implement\",\"cli\":\"codex\".*\"report\":\"external/.*\"budget\":' '$REPO/.rolepod/evidence/phase-log.jsonl'"
out=$(STUB_codex=short bash "$RUNNER" --kind implement --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "member report under the 200-byte floor → not a pass (exit 3, external-fail logged)" "[ $rc -eq 3 ] && grep -q '\"phase\":\"external-fail\",\"kind\":\"implement\",\"cli\":\"codex\"' '$REPO/.rolepod/evidence/phase-log.jsonl'"

echo "── implement: --probe stays read-only even with --kind implement ──"
: > "$LOG"
out=$(bash "$RUNNER" --probe --kind implement --lead claude --root "$REPO" 2>&1); rc=$?
check "probe ran codex with -s read-only, never workspace-write" "grep -q -- '-s read-only' '$LOG' && ! grep -q -- 'workspace-write' '$LOG'"

echo "── implement: a live job blocks a second one (either kind) ──"
: > "$LOG"
out=$(STUB_codex=hang bash "$RUNNER" --kind implement --brief "$BRIEF" --lead claude --root "$REPO" --detach 2>&1); rc=$?
JOB=$(printf '%s' "$out" | sed -n 's/.*job=\([^ ]*\).*/\1/p' | head -1)
check "detached implement returns a job id + EDITING notice" "[ $rc -eq 0 ] && [ -n '$JOB' ] && printf '%s' \"$out\" | grep -q 'EDITING this tree'"
sleep 1
out2=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc2=$?
check "second implement while live → exit 8 refused stacked" "[ $rc2 -eq 8 ] && printf '%s' \"$out2\" | grep -q 'refused stacked'"
out3=$(bash "$RUNNER" --kind review --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc3=$?
check "a review while the implement job is live → exit 8 too" "[ $rc3 -eq 8 ]"
bash "$RUNNER" --kill "$JOB" --root "$REPO" >/dev/null 2>&1
check "--kill ends the job (status 137)" "[ \"\$(cat '$REPO/.rolepod/evidence/external/jobs/$JOB/status' 2>/dev/null)\" = 137 ]"
sleep 2
check "--kill took the member itself down (no stub process left in the fixture)" "! pgrep -f '$BIN/codex' >/dev/null"

echo "── implement: opencode without project permissions is skipped, next member runs ──"
: > "$LOG"; rm -f "$REPO/opencode.json"
printf 'opencode\ncodex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "opencode never invoked, codex implemented (exit 0)" "[ $rc -eq 0 ] && ! grep -q '^opencode' '$LOG' && grep -q '^codex' '$LOG'"
check "phase-log external-fail says no opencode config grants edit+bash (and where it looked)" "grep -q '\"phase\":\"external-fail\".*\"cli\":\"opencode\".*no opencode config grants edit+bash (checked the project, OPENCODE_CONFIG_DIR and ~/.config/opencode)' '$REPO/.rolepod/evidence/phase-log.jsonl'"
git -C "$REPO" checkout -q -- README.md; rm -rf "$REPO/src"
printf '{"permission":{"edit":"allow","bash":{"*":"allow"}}}\n' > "$REPO/opencode.json"
: > "$LOG"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "opencode WITH edit+bash allow is invoked (run, no --agent plan)" "grep -q '^opencode | run ' '$LOG' && ! grep -q -- '--agent plan' '$LOG'"
rm -f "$REPO/opencode.json"; printf '{\n  // project config with comments\n  "permission": {"edit": "allow", "bash": {"*": "allow"},},\n}\n' > "$REPO/opencode.jsonc"
: > "$LOG"; git -C "$REPO" checkout -q -- README.md; rm -rf "$REPO/src"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "opencode.jsonc (comments, trailing commas) granting edit+bash is honoured" "grep -q '^opencode | run ' '$LOG'"
rm -f "$REPO/opencode.jsonc"

echo "── implement: other kinds stay read-only ──"
: > "$LOG"; printf 'codex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind review --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "review still runs codex with -s read-only" "grep -q -- '-s read-only' '$LOG' && ! grep -q -- 'workspace-write' '$LOG'"

if [ "$fail" -eq 0 ]; then echo "  all cross-family-implement checks passed"; else echo "  $fail cross-family-implement check(s) failed"; exit 1; fi
