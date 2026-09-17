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
_fa=\$(printf '%s' "\$_raw" | grep -c 'runner reverts every edit outside this list' | head -1)
_rs=\$(printf '%s' "\$_raw" | grep -c 'the user lifted the refusal' | head -1)
printf 'codex | %s | ROLE=%s | BUDGET=%s | FILES_ALLOWED=%s | RISKY_SCOPE=%s\n' "\$(printf '%s' "\$*" | tr '\n' ' ')" "\$_role" "\${_bud:-none}" "\$_fa" "\$_rs" >> "$LOG"
_root=""; _msg=""; _prev=""; for a in "\$@"; do [ "\$_prev" = "-C" ] && _root="\$a"; [ "\$_prev" = "-o" ] && _msg="\$a"; _prev="\$a"; done
case "\${STUB_codex:-ok}" in
  hang) [ "\$_role" = implementer ] && [ -n "\$_root" ] && { mkdir -p "\$_root/src" "\$_root/stray"; printf 'half\n' > "\$_root/src/half.ts"; for _i in \$(seq 1 400); do printf 's\n' > "\$_root/stray/f\$_i.txt"; done; [ -n "\${HANG_POKE:-}" ] && { printf '{"ts":"2026-01-01T00:00:00Z","phase":"review","reviewer":"external","kind":"review","cli":"codex","raw":"external/killforge.txt","verdict":"APPROVED"}\n' >> "\$_root/.rolepod/evidence/phase-log.jsonl"; printf '{"t": %s, "ts": "", "cli": "codex", "path": "tests/killghost.test.ts", "kind": "test", "agent": ""}\n' "\$(date +%s)" >> "\$_root/.rolepod/evidence/edits.jsonl"; git -C "\$_root" config --local user.name evilkill; }; }; sleep 30 & wait; exit 0 ;;
  fail) echo "boom" >&2; exit 1 ;;
  failafter) mkdir -p "\$_root/src"; printf 'broken\n' > "\$_root/src/broken.ts"; printf 'partial\n' >> "\$_root/README.md"; echo "crashed" >&2; exit 1 ;;
  commit) mkdir -p "\$_root/src"; printf 'c\n' > "\$_root/src/c.ts"; git -C "\$_root" add -A; git -C "\$_root" -c user.email=m@m -c user.name=m commit -qm "member commit"; _role=none ;;
  branch) git -C "\$_root" checkout -q -b evil; mkdir -p "\$_root/src"; printf 'b\n' > "\$_root/src/b.ts"; _role=none ;;
  stash) printf 's\n' >> "\$_root/README.md"; git -C "\$_root" stash -q; _role=none ;;
  nuke) git -C "\$_root" -c user.email=m@m -c user.name=m commit -q --allow-empty -m nuke; rm -rf "\$_root/.git"; _role=none ;;
  short) [ -n "\$_msg" ] && printf 'ok\n' > "\$_msg"; echo noise; exit 0 ;;
esac
case "\${STUB_codex:-ok}" in noop|leadrow|dirswap|libfile|forge|forgeonly|spacey|forgespaced|forgeledger|ignorefile|newbranch|config|githook|hookswap|exclude|forgekind|commitforge|failforge|shrink|poolforge) _role=none ;; esac   # these modes write only what they say
case "\${STUB_codex:-ok}" in
  forgespaced) printf '{"phase": "review", "reviewer": "external", "kind": "review", "cli": "codex", "raw": "external/spaced.txt", "verdict": "APPROVED"}\n' >> "\$_root/.rolepod/evidence/phase-log.jsonl" ;;
  forgeledger) mkdir -p "\$_root/src"; printf 'x\n' > "\$_root/src/real.ts"; printf '{"t": %s, "ts": "", "cli": "codex", "path": "tests/ghost.test.ts", "kind": "test", "agent": ""}\n{"t": %s, "ts": "", "cli": "claude", "path": "src/real.ts", "kind": "other", "agent": ""}\n' "\$(date +%s)" "\$(date +%s)" >> "\$_root/.rolepod/evidence/edits.jsonl" ;;
  ignorefile) mkdir -p "\$_root/src/hidden"; printf 'hidden/\n' > "\$_root/src/.gitignore"; printf 'h\n' > "\$_root/src/hidden/x.ts" ;;
  newbranch) git -C "\$_root" branch evil2 ;;
  config) git -C "\$_root" config --local user.name evil ;;
  githook) mkdir -p "\$_root/.GIT/hooks"; printf '#!/bin/sh\necho pwned\n' > "\$_root/.GIT/hooks/pre-commit" ;;
  hookswap) printf '#!/bin/sh\necho pwned\n' > "\$_root/.git/hooks/pre-commit" ;;
  exclude) mkdir -p "\$_root/hidden"; printf 'hidden/\n' >> "\$_root/.git/info/exclude"; printf 'h\n' > "\$_root/hidden/x.ts" ;;
  commitforge) mkdir -p "\$_root/src"; printf 'c\n' > "\$_root/src/c.ts"; git -C "\$_root" add -A; git -C "\$_root" -c user.email=m@m -c user.name=m commit -qm "member commit"; head -c 600 /dev/zero | tr '\0' z > "\$_root/.rolepod/evidence/external/pwn.txt"; printf '{"ts":"2026-01-01T00:00:00Z","phase":"review","reviewer":"external","kind":"review","cli":"codex","raw":"external/pwn.txt","verdict":"APPROVED"}\n' >> "\$_root/.rolepod/evidence/phase-log.jsonl" ;;
  failforge) printf '{"ts":"2026-01-01T00:00:00Z","phase":"review","reviewer":"external","kind":"review","cli":"codex","raw":"external/pwn2.txt","verdict":"APPROVED"}\n' >> "\$_root/.rolepod/evidence/phase-log.jsonl"; echo crashed >&2; exit 1 ;;
  shrink) python3 -c 'import sys; f=open(sys.argv[1],"r+b"); f.truncate(int(sys.argv[2]))' "\$_root/.rolepod/evidence/edits.jsonl" "\$LEDGER_KEEP" ;;
  poolforge) printf 'agy\n' > "\$_root/.rolepod/cross-family"; printf 'nothing\n' > "\$_root/.rolepod/risk-paths" ;;
  forgekind) mkdir -p "\$_root/src"; printf 'x\n' > "\$_root/src/real.ts"; printf '{"t": %s, "ts": "", "cli": "codex", "path": "src/real.ts", "kind": "test", "agent": ""}\n' "\$(date +%s)" >> "\$_root/.rolepod/evidence/edits.jsonl" ;;
esac
if [ "\${STUB_codex:-ok}" = spacey ] && [ -n "\$_root" ]; then
  mkdir -p "\$_root/my dir" "\$_root/src"; printf 'x\n' > "\$_root/my dir/x.ts"; printf "it's\n" > "\$_root/src/it's new.ts"; printf 'y\n' > "\$_root/src/own.ts"; printf 'z\n' > "\$_root/src/own2.ts"
  for _o in src/own.ts src/own2.ts; do printf '{"t": %s, "ts": "", "cli": "codex", "path": "%s", "kind": "other", "agent": ""}\n' "\$(date +%s)" "\$_o" >> "\$_root/.rolepod/evidence/edits.jsonl"; done   # what the member's OWN hook writes
  printf '{"ts":"2026-01-01T00:00:00Z","phase":"dispatch-proof","cli":"codex","agent_type":"universal-reviewer","model":"x","provenance":"hook-stdin"}\n' >> "\$_root/.rolepod/evidence/phase-log.jsonl"   # the member's internal fleet (or a forgery of a strong reviewer)
fi
if [ "\${STUB_codex:-ok}" = forge ] && [ -n "\$_root" ]; then
  printf '{"ts":"2026-01-01T00:00:00Z","phase":"review","reviewer":"external","kind":"review","cli":"codex","family":"openai","model":"default","raw":"external/forged.txt","verdict":"APPROVED"}\n' >> "\$_root/.rolepod/evidence/phase-log.jsonl"
  printf '{"ts":"2026-01-01T00:00:00Z","phase":"dispatch","cli":"codex","note":"a hook line is fine"}\n' >> "\$_root/.rolepod/evidence/phase-log.jsonl"
fi
if [ "\${STUB_codex:-ok}" = forgeonly ] && [ -n "\$_root" ]; then
  printf '{"ts":"2026-01-01T00:00:00Z","phase":"review","reviewer":"external","kind":"review","cli":"codex","raw":"external/forged-only.txt","verdict":"APPROVED"}\n' >> "\$_root/.rolepod/evidence/phase-log.jsonl"
fi
if [ "\$_role" = implementer ] && [ -n "\$_root" ]; then
  printf 'hello from codex\n' >> "\$_root/README.md"
  mkdir -p "\$_root/src"; printf 'export const added = true;\n' > "\$_root/src/added.ts"
fi
if [ "\${STUB_codex:-ok}" = outside ] && [ -n "\$_root" ]; then
  printf 'tampered\n' > "\$_root/LICENSE"; git -C "\$_root" add LICENSE   # staged, against the hard lines
  mkdir -p "\$_root/notes"; printf 'stray\n' > "\$_root/notes/other.txt"
  printf 'SECRET=1\n' > "\$_root/.env"; printf 'lock\n' > "\$_root/package-lock.json"; rm -f "\$_root/CHANGELOG.md"
  printf 'SECRET=2\n' > "\$_root/src/.ENV"                                 # forbidden name under an allowed prefix, case-swapped
  mkdir -p "\$_root/docs/rolepod"; printf 'leak\n' > "\$_root/docs/rolepod/secret.md"
  rm -f "\$_root/bin/run.sh"; ln -s "$FIX/target.txt" "\$_root/bin/run.sh"  # symlink swap of a tracked executable → restore must not follow it
  printf '{"t": %s, "ts": "", "cli": "codex", "path": "README.md", "kind": "other", "agent": ""}\n' "\$(date +%s)" >> "\$_root/.rolepod/evidence/edits.jsonl"   # the member's own hook row for a touched path: kept
fi
if [ "\${STUB_codex:-ok}" = leadrow ] && [ -n "\$_root" ]; then
  printf 'lead was here\n' >> "\$_root/LICENSE"
  printf '{"t": %s, "ts": "", "cli": "claude", "path": "LICENSE", "kind": "other", "agent": ""}\n' "\$(date +%s)" >> "\$_root/.rolepod/evidence/edits.jsonl"   # what the Lead's own hook writes when the Lead edits during the job
fi
if [ "\${STUB_codex:-ok}" = dirswap ] && [ -n "\$_root" ]; then
  rm -f "\$_root/README.md"; mkdir -p "\$_root/README.md"; printf 'x\n' > "\$_root/README.md/x"   # an exact-file entry must not become a subtree
fi
if [ "\${STUB_codex:-ok}" = libfile ] && [ -n "\$_root" ]; then printf 'new\n' > "\$_root/lib/new.ts"; fi
_rep="\$(printf 'Implemented the ticket.\nFiles touched: README.md, src/added.ts\nTests: none in this repo\nNOT done: nothing\n%s' "\$(head -c 300 /dev/zero | tr '\0' r)")"
if [ -n "\$_msg" ]; then printf '%s\n' "\$_rep" > "\$_msg"; echo "stream noise"; else printf '%s\n' "\$_rep"; fi
STUB
chmod +x "$BIN/codex"
cat > "$BIN/opencode" <<'STUB'
#!/bin/bash
echo "opencode | $*" >> "${LOG_FILE:?}"; printf 'should not run\n'; exit 0
STUB
chmod +x "$BIN/opencode"; export LOG_FILE="$LOG"
cat > "$BIN/agy" <<'STUB'
#!/bin/bash
echo "agy | $*" >> "${LOG_FILE:?}"
if printf '%s' "$*" | grep -q -- '--mode accept-edits'; then _r=""; _p=""; for a in "$@"; do [ "$_p" = "--add-dir" ] && _r="$a"; _p="$a"; done; mkdir -p "$_r/src"; printf 'agy\n' > "$_r/src/from-agy.ts"; printf 'Implemented by agy.\nFiles touched: src/from-agy.ts\n%s\n' "$(head -c 300 /dev/zero | tr '\0' g)"; exit 0; fi
printf 'agy review: %s\nVERDICT: APPROVED\n' "$(head -c 600 /dev/zero | tr '\0' a)"; exit 0
STUB
chmod +x "$BIN/agy"

# scratch repo
REPO="$FIX/repo"; mkdir -p "$REPO"; git -C "$REPO" init -q; git -C "$REPO" config user.email t@t; git -C "$REPO" config user.name t
printf 'readme\n' > "$REPO/README.md"; printf 'MIT\n' > "$REPO/LICENSE"; printf 'log\n' > "$REPO/CHANGELOG.md"
mkdir -p "$REPO/bin" "$REPO/lib" "$REPO/.rolepod/evidence"; printf '#!/bin/sh\necho run\n' > "$REPO/bin/run.sh"; chmod 755 "$REPO/bin/run.sh"; printf 'lib\n' > "$REPO/lib/old.ts"
printf 'src/billing/\n' > "$REPO/.rolepod/risk-paths"   # a rolepod config file under the guard — committed so the guard has a baseline
git -C "$REPO" add -A; git -C "$REPO" commit -qm init
printf 'keep\n' > "$FIX/target.txt"
BRIEF="$FIX/brief.md"; printf '# Ticket: add src/added.ts\n\n## Files allowed\nREADME.md, src/added.ts\n\n## Done when\nsrc/added.ts exists.\n' > "$BRIEF"

echo "── implement: opt-in (no pool = OFF) ──"
rm -f "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "no pool file → exit 5, nothing ran" "[ $rc -eq 5 ] && [ ! -f '$LOG' ]"

echo "── implement: --all is refused (one writer per tree) ──"
printf 'codex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind implement --all --brief "$BRIEF" --allow README.md --lead claude --root "$REPO" 2>&1); rc=$?
check "--kind implement --all → exit 2, nothing ran" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'ONE member at a time' && [ ! -f '$LOG' ]"

echo "── implement: happy path (codex, write mode, patch + report) ──"
printf 'codex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
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
check "dispatch-proof line for the commit gate: cli=codex pool_cli=codex agent_type=external-implementer provenance=cross-family paths=2 edits=2" "grep -q '\"phase\":\"dispatch-proof\",\"cli\":\"codex\",\"pool_cli\":\"codex\",\"agent_type\":\"external-implementer\",\"model\":\"[^\"]*\",\"provenance\":\"cross-family\",\"paths\":2,\"edits\":2' '$REPO/.rolepod/evidence/phase-log.jsonl'"
check "edit-ledger rows: one per touched path, cli=codex agent=external-implementer" "grep -c '\"cli\": \"codex\".*\"agent\": \"external-implementer\"' '$REPO/.rolepod/evidence/edits.jsonl' | grep -qx 2 && grep -q '\"path\": \"src/added.ts\"' '$REPO/.rolepod/evidence/edits.jsonl'"
check "ok line says edits=2; the implement line records the allow scope as a JSON list and edits=2" "grep -q ' edits=2 ' '$FIX/out1.txt' && grep -q '\"allow\":\[\"README.md\",\"src/\"\],\"risky\":\"no\",\"edits\":2,' '$REPO/.rolepod/evidence/phase-log.jsonl'"
echo "── implement: paths with spaces and quotes; the member's own ledger rows are not doubled; member-internal dispatch-proof lines leave the Lead's log ──"
git -C "$REPO" checkout -q -- README.md; rm -rf "$REPO/src"; : > "$LOG"
out=$(STUB_codex=spacey bash "$RUNNER" --kind implement --brief "$BRIEF" --allow "my dir/" --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "spaces + a quote in touched paths → exit 0, paths=4, edits=4 (the member's own window rows are replaced by runner-classified rows, none doubled)" "[ $rc -eq 0 ] && grep -q '\"paths\":4,\"edits\":4,\"ledger_forged\":0' '$REPO/.rolepod/evidence/phase-log.jsonl' && [ \"\$(grep -c 'src/own2.ts' '$REPO/.rolepod/evidence/edits.jsonl')\" = 1 ]"
check "ledger rows carry the exact paths (space and quote intact), one row each" "grep -q '\"path\": \"my dir/x.ts\"' '$REPO/.rolepod/evidence/edits.jsonl' && grep -q \"src/it's new.ts\" '$REPO/.rolepod/evidence/edits.jsonl' && [ \"\$(grep -c 'src/own.ts' '$REPO/.rolepod/evidence/edits.jsonl')\" = 1 ]"
check "the member-internal dispatch-proof line is moved out of the Lead's phase-log (moved=1, not forged), kept under external/*.member-phase-log.jsonl" "! grep -q '\"agent_type\":\"universal-reviewer\"' '$REPO/.rolepod/evidence/phase-log.jsonl' && grep -q '\"moved\":1' '$REPO/.rolepod/evidence/phase-log.jsonl' && grep -q 'universal-reviewer' '$REPO'/.rolepod/evidence/external/*codex*.member-phase-log.jsonl && ! printf '%s' \"$out\" | grep -q 'forged=1'"
: > "$LOG"; printf 'codex\nagy\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind review --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "review skip works for a ticket whose allowed path has a space (codex skipped, agy runs)" "[ $rc -eq 0 ] && ! grep -q '^codex' '$LOG' && grep -q '^agy' '$LOG'"
printf 'unrelated\n' > "$REPO/UNRELATED.md"; git -C "$REPO" add UNRELATED.md; git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm unrelated; : > "$LOG"
out=$(bash "$RUNNER" --kind review --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "an unrelated commit while the ticket is still dirty does NOT clear the skip" "[ $rc -eq 0 ] && ! grep -q '^codex' '$LOG' && grep -q '^agy' '$LOG'"
printf 'codex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind review --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "a one-member pool whose member built the ticket → exit 4 with the commit-first message" "[ $rc -eq 4 ] && printf '%s' \"$out\" | grep -q 'built this uncommitted ticket'"
git -C "$REPO" reset -q --hard HEAD~1; rm -rf "$REPO/my dir" "$REPO/src"; git -C "$REPO" checkout -q -- .; printf 'codex\n' > "$HOME/.rolepod/cross-family"
: > "$LOG"; out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
printf '%s\n' "$out" > "$FIX/out1.txt"

echo "── implement: the implement: pool line parses and binds to this kind only ──"
printf '[reviewer]\nreview = codex agy\n\n[implement]\ncli = agy codex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --pool --kind implement --lead claude --root "$REPO" 2>&1)
check "[implement] cli = agy codex → implement order agy codex" "printf '%s' \"$out\" | grep -q 'usable, in order: agy codex$'"
printf 'codex\nagy\nimplement: agy codex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --pool --kind implement --lead claude --root "$REPO" 2>&1)
check "the older implement: line still reads (agy codex)" "printf '%s' \"$out\" | grep -q 'usable, in order: agy codex$'"
printf '[reviewer]\nreview = none\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --lead claude --root "$REPO" 2>&1); rc=$?
check "[reviewer] review = none → off (exit 5)" "[ $rc -eq 5 ]"
printf '[reviewer]\nreview = codex agy\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --pool --kind implement --lead claude --root "$REPO" 2>&1)
check "no [implement] section → implement falls back to the review order (codex agy)" "printf '%s' \"$out\" | grep -q 'usable, in order: codex agy$'"
printf 'codex\nagy\nimplement: agy codex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --pool --kind consult --lead claude --root "$REPO" 2>&1)
check "the default order for other kinds is untouched (codex agy) — no fake member, no pollution" "printf '%s' \"$out\" | grep -q 'usable, in order: codex agy$' && ! printf '%s' \"$out\" | grep -q 'implement:'"
printf 'codex\nagy\n' > "$HOME/.rolepod/cross-family"

echo "── implement: the implementer never reviews its own uncommitted ticket ──"
: > "$LOG"; printf 'codex\nagy\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind review --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "--kind review while the codex-built ticket is uncommitted → codex skipped, agy reviews" "[ $rc -eq 0 ] && ! grep -q '^codex' '$LOG' && grep -q '^agy' '$LOG' && printf '%s' \"$out\" | grep -q 'cli=agy'"
out=$(bash "$RUNNER" --pool --kind review --lead claude --root "$REPO" 2>&1)
check "--pool names why: implemented the uncommitted ticket" "printf '%s' \"$out\" | grep -q 'codex.*skipped.*implemented the uncommitted ticket'"
git -C "$REPO" add -A; git -C "$REPO" commit -qm "ticket landed"; : > "$LOG"
out=$(bash "$RUNNER" --kind review --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "after the Lead commits the ticket, codex reviews again" "[ $rc -eq 0 ] && grep -q '^codex' '$LOG'"
git -C "$REPO" reset -q --hard HEAD~1; printf 'codex\n' > "$HOME/.rolepod/cross-family"
git -C "$REPO" checkout -q -- README.md; rm -rf "$REPO/src"

echo "── implement: the Lead's own WIP never travels; a no-op member reports files=0 on one line ──"
printf 'lead wip\n' > "$REPO/lead-wip.txt"; printf 'lead edit\n' >> "$REPO/LICENSE"   # Lead WIP lives OUTSIDE the allowed paths (inside = refused as dirty)
: > "$LOG"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
PATCH="$REPO/.rolepod/evidence/$(printf '%s' "$out" | sed -n 's/.*patch=\.rolepod\/evidence\/\([^ ]*\).*/\1/p' | head -1)"
check "patch = member delta only (src/added.ts + codex line), not lead-wip.txt or the lead edit" "grep -q 'b/src/added.ts' '$PATCH' && grep -q '^+hello from codex' '$PATCH' && ! grep -q 'lead-wip' '$PATCH' && ! grep -q '^+lead edit' '$PATCH'"
check "the Lead's pre-existing WIP outside the list is not a violation and is left alone" "[ $rc -eq 0 ] && [ -f '$REPO/lead-wip.txt' ] && grep -q 'lead edit' '$REPO/LICENSE'"
rm -f "$REPO/lead-wip.txt"; git -C "$REPO" checkout -q -- README.md LICENSE; rm -rf "$REPO/src"
out=$(STUB_codex=noop bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "no-op member → exit 0, ONE ok line carrying files=0 AND patch= AND report=" "[ $rc -eq 0 ] && printf '%s\n' \"$out\" | grep -q '^ROLEPOD-XFAM ok kind=implement cli=codex family=[a-z]* files=0 edits=0 patch=.rolepod/evidence/.* report=.rolepod/evidence/'"
check "every phase-log line is valid JSON (files=0 did not split it)" "python3 -c \"import json,sys; [json.loads(l) for l in open('$REPO/.rolepod/evidence/phase-log.jsonl') if l.strip()]\""
check "phase-log implement line uses phase=implement + report + budget (same vocabulary as review)" "grep -q '\"phase\":\"implement\",\"kind\":\"implement\",\"cli\":\"codex\".*\"report\":\"external/.*\"budget\":' '$REPO/.rolepod/evidence/phase-log.jsonl'"
out=$(STUB_codex=short bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "member report under the 200-byte floor → not a pass (exit 3, external-fail logged)" "[ $rc -eq 3 ] && grep -q '\"phase\":\"external-fail\",\"kind\":\"implement\",\"cli\":\"codex\"' '$REPO/.rolepod/evidence/phase-log.jsonl'"

echo "── implement: --probe stays read-only even with --kind implement ──"
: > "$LOG"
out=$(bash "$RUNNER" --probe --kind implement --lead claude --root "$REPO" 2>&1); rc=$?
check "probe ran codex with -s read-only, never workspace-write" "grep -q -- '-s read-only' '$LOG' && ! grep -q -- 'workspace-write' '$LOG'"

echo "── implement: allowed-path guard (Task 2) ──"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow missing → exit 2 usage, nothing ran" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'needs --allow'"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow /etc/passwd --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow with an absolute path → exit 2" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'relative to the repo root'"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow . --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow . → exit 2 (not a scope)" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'not a scope'"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow .env --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow .env → exit 2 (off-limits, refused at the gate)" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'off-limits'"
printf 'wip\n' >> "$REPO/README.md"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "dirty allowed path before the run → exit 2 (ticket starts from a committed slate)" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'must start clean'"
git -C "$REPO" checkout -q -- README.md
: > "$LOG"
out=$(STUB_codex=outside bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
printf '%s\n' "$out" > "$FIX/out2.txt"
check "member wrote outside the list → exit 21 + violations line (files=2 kept, outside=8 reverted, copies dir named)" "[ $rc -eq 21 ] && grep -q '^ROLEPOD-XFAM violations kind=implement cli=codex family=[a-z]* files=2 outside=8 forged=0 patch=' '$FIX/out2.txt' && grep -q 'copies under .rolepod/evidence/external/.*reverted/' '$FIX/out2.txt'"
check "LICENSE restored AND unstaged (member had git-added it), CHANGELOG.md is back" "[ \"\$(cat '$REPO/LICENSE')\" = MIT ] && [ -z \"\$(git -C '$REPO' diff --cached --name-only)\" ] && [ \"\$(cat '$REPO/CHANGELOG.md')\" = log ]"
check "stray file, .env, package-lock.json, src/.ENV (case-swapped) are gone; notes/ dir pruned" "[ ! -e '$REPO/notes/other.txt' ] && [ ! -e '$REPO/.env' ] && [ ! -e '$REPO/package-lock.json' ] && [ ! -e '$REPO/src/.ENV' ] && [ ! -d '$REPO/notes' ]"
check "the private docs dir is guarded: docs/rolepod/secret.md gone" "[ ! -e '$REPO/docs/rolepod/secret.md' ]"
check "a member row for a touched path is replaced by the runner's classified row (one row, agent external-implementer)" "[ \"\$(grep -c '\"path\": \"README.md\"' '$REPO/.rolepod/evidence/edits.jsonl')\" -ge 1 ] && ! grep -q '\"cli\": \"codex\", \"path\": \"README.md\", \"kind\": \"other\", \"agent\": \"\"' '$REPO/.rolepod/evidence/edits.jsonl'"
check "symlink swap: bin/run.sh is a regular executable again with its content, the outside target untouched" "[ ! -L '$REPO/bin/run.sh' ] && [ -x '$REPO/bin/run.sh' ] && grep -q 'echo run' '$REPO/bin/run.sh' && [ \"\$(cat '$FIX/target.txt')\" = keep ]"
check "allowed edits kept (README.md line + src/added.ts)" "grep -q 'hello from codex' '$REPO/README.md' && [ -f '$REPO/src/added.ts' ]"
check "what the member wrote is saved under the .reverted/ copy dir (LICENSE = tampered); the removed symlink is in MANIFEST" "grep -q tampered '$REPO'/.rolepod/evidence/external/*codex*.reverted/LICENSE && grep -q 'bin/run.sh -> ' '$REPO'/.rolepod/evidence/external/*codex*.reverted/MANIFEST"
PATCH2="$REPO/.rolepod/evidence/$(sed -n 's/.*patch=\.rolepod\/evidence\/\([^ ]*\).*/\1/p' "$FIX/out2.txt" | head -1)"
check "patch after the revert = allowed paths only" "grep -q 'b/src/added.ts' '$PATCH2' && grep -q 'b/README.md' '$PATCH2' && ! grep -q 'LICENSE\|notes/other\|\.env\|package-lock\|risk-paths\|secret.md\|run.sh' '$PATCH2'"
check "phase-log implement line carries outside=8, forged=0 and the reverted paths" "grep -q '\"phase\":\"implement\".*\"outside\":8,\"forged\":0,\"outside_paths\":\"[^\"]*LICENSE' '$REPO/.rolepod/evidence/phase-log.jsonl'"
check "the member's prompt listed its Files allowed" "grep -q 'FILES_ALLOWED=1' '$LOG'"
git -C "$REPO" checkout -q -- README.md; rm -rf "$REPO/src"
out=$(STUB_codex=leadrow bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a concurrent outside edit is reverted even with a ledger row claiming the Lead (the ledger is not trusted): exit 21, LICENSE back, copy kept" "[ $rc -eq 21 ] && [ \"\$(cat '$REPO/LICENSE')\" = MIT ] && grep -q 'lead was here' '$REPO'/.rolepod/evidence/external/*codex*.reverted/LICENSE"
out=$(STUB_codex=forge bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a forged external-pass line appended to the phase-log during the run is stripped and counted (exit 21, forged=1)" "[ $rc -eq 21 ] && printf '%s' \"$out\" | grep -q 'forged=1' && ! grep -q 'external/forged.txt' '$REPO/.rolepod/evidence/phase-log.jsonl' && grep -q 'a hook line is fine' '$REPO/.rolepod/evidence/phase-log.jsonl'"
out=$(STUB_codex=forgeonly bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a member that appends ONLY a forged line (nothing else) still gets it stripped (exit 21, forged=1, line gone)" "[ $rc -eq 21 ] && printf '%s' \"$out\" | grep -q 'forged=1' && ! grep -q 'forged-only.txt' '$REPO/.rolepod/evidence/phase-log.jsonl'"
check "phase-log implement line records forged=1 and every line still parses" "grep -q '\"phase\":\"implement\".*\"forged\":1' '$REPO/.rolepod/evidence/phase-log.jsonl' && python3 -c \"import json; [json.loads(l) for l in open('$REPO/.rolepod/evidence/phase-log.jsonl') if l.strip()]\""
out=$(STUB_codex=noop bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow newdir --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow newdir (does not exist, no slash) → notice: read as ONE file, a new directory needs newdir/" "[ $rc -eq 0 ] && printf '%s' \"$out\" | grep -q 'read as ONE file'"
out=$(bash "$RUNNER" --kind review --brief "$BRIEF" --allow README.md --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow with a read-only kind → exit 2" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'only applies to --kind implement'"
printf 'tmp/\n' > "$REPO/.gitignore"; git -C "$REPO" add .gitignore; git -C "$REPO" commit -qm ignore
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow tmp/ --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow on a gitignored path → exit 2 (the guard cannot see it)" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'gitignored'"
git -C "$REPO" checkout -q -- LICENSE README.md; rm -rf "$REPO/src"
out=$(STUB_codex=dirswap bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --lead claude --root "$REPO" 2>&1); rc=$?
check "an exact-file entry never covers a subtree: README.md/x flagged + removed (exit 21)" "[ $rc -eq 21 ] && [ ! -e '$REPO/README.md/x' ] && printf '%s' \"$out\" | grep -q 'README.md/x'"
rm -rf "$REPO/README.md"; git -C "$REPO" checkout -q -- README.md
out=$(STUB_codex=libfile bash "$RUNNER" --kind implement --brief "$BRIEF" --allow lib --lead claude --root "$REPO" 2>&1); rc=$?
check "an existing directory named without a slash is a prefix (lib → lib/new.ts allowed, exit 0)" "[ $rc -eq 0 ] && printf '%s' \"$out\" | grep -q 'files=1' && [ -f '$REPO/lib/new.ts' ]"
rm -f "$REPO/lib/new.ts"

echo "── implement: money / auth / data paths refused unless --allow-risky (Task 5) ──"
git -C "$REPO" checkout -q -- .; rm -rf "$REPO/src"; printf 'codex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow src/billing/ --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow src/billing/ → exit 2: fact (money/auth/data path) → fix (the Lead builds it) → exception (the USER lifts it)" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'src/billing is a money / auth / data path' && printf '%s' \"$out\" | grep -q 'only the USER lifts it'"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow src/Auth.ts --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow src/Auth.ts (case-insensitive, like the gate) → exit 2" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'money / auth / data path'"
: > "$LOG"
out=$(STUB_codex=noop bash "$RUNNER" --kind implement --brief "$BRIEF" --allow src/author/ --allow README.md --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow src/author/ is not a risk word (auth followed by a letter) → runs" "[ $rc -eq 0 ] && grep -q '^codex' '$LOG'"
: > "$LOG"
out=$(STUB_codex=noop bash "$RUNNER" --kind implement --brief "$BRIEF" --allow src/billing/ --allow-risky --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow-risky lifts the refusal → runs; the implement line records risky=lifted; the member is told" "[ $rc -eq 0 ] && grep -q '^codex' '$LOG' && grep -q '\"risky\":\"lifted\"' '$REPO/.rolepod/evidence/phase-log.jsonl' && grep -q 'RISKY_SCOPE=1' '$LOG'"
out=$(bash "$RUNNER" --kind review --brief "$BRIEF" --allow-risky --lead claude --root "$REPO" 2>&1); rc=$?
check "--allow-risky on a read-only kind → exit 2" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'only applies to --kind implement'"
printf '+(^|/)wallet(/|\\.|_|$)\n-(^|/)security/docs\n' > "$REPO/.rolepod/risk-paths"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow src/wallet/ --lead claude --root "$REPO" 2>&1); rc=$?
check "the repo's .rolepod/risk-paths ADD line makes src/wallet/ risky → exit 2 (same as the commit gate)" "[ $rc -eq 2 ] && printf '%s' \"$out\" | grep -q 'money / auth / data path'"
: > "$LOG"
out=$(STUB_codex=noop bash "$RUNNER" --kind implement --brief "$BRIEF" --allow src/security/docs/ --allow README.md --lead claude --root "$REPO" 2>&1); rc=$?
check "the EXCLUDE line un-risks src/security/docs/ → runs (risky=no on THIS run's line)" "[ $rc -eq 0 ] && grep -q '^codex' '$LOG' && grep '\"phase\":\"implement\"' '$REPO/.rolepod/evidence/phase-log.jsonl' | tail -1 | grep -q '\"risky\":\"no\"'"
printf 'src/billing/\n' > "$REPO/.rolepod/risk-paths"; git -C "$REPO" checkout -q -- .rolepod/risk-paths

echo "── implement: external-review round (ship group A) ──"
git -C "$REPO" checkout -q -- .; rm -rf "$REPO/src"; printf 'codex\n' > "$HOME/.rolepod/cross-family"
out=$(STUB_codex=forgespaced bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a forged external-pass line with SPACED JSON (what the gate parses) is stripped too (exit 21, forged=1)" "[ $rc -eq 21 ] && printf '%s' \"$out\" | grep -q 'forged=1' && ! grep -q 'external/spaced.txt' '$REPO/.rolepod/evidence/phase-log.jsonl'"
out=$(STUB_codex=forgeledger bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "forged ledger rows (a test row for an untouched path, a row claiming another CLI) are removed and counted (exit 21, ledger_forged=2); the real path gets its row" "[ $rc -eq 21 ] && ! grep -q 'tests/ghost.test.ts' '$REPO/.rolepod/evidence/edits.jsonl' && grep -q '\"ledger_forged\":2' '$REPO/.rolepod/evidence/phase-log.jsonl' && grep -q '\"cli\": \"codex\".*\"path\": \"src/real.ts\".*external-implementer' '$REPO/.rolepod/evidence/edits.jsonl'"
rm -rf "$REPO/src"
out=$(STUB_codex=ignorefile bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a .gitignore the member adds under its own prefix is off-limits (reverted, exit 21) so nothing can hide from the snapshot" "[ $rc -eq 21 ] && [ ! -e '$REPO/src/.gitignore' ] && printf '%s' \"$out\" | grep -q 'src/.gitignore'"
rm -rf "$REPO/src"
out=$(STUB_codex=newbranch bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a branch created without checkout → exit 22 (the ref set changed)" "[ $rc -eq 22 ] && printf '%s' \"$out\" | grep -q 'the ref set changed'"
git -C "$REPO" branch -q -D evil2 2>/dev/null
out=$(STUB_codex=config bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a .git/config change → exit 22 and the config is restored byte-for-byte (user.name back to t)" "[ $rc -eq 22 ] && printf '%s' \"$out\" | grep -q 'metadata changed and was restored: config' && [ \"\$(git -C '$REPO' config --local user.name)\" = t ]"
printf '#!/bin/sh\necho original\n' > "$REPO/.git/hooks/pre-commit"; chmod +x "$REPO/.git/hooks/pre-commit"
out=$(STUB_codex=hookswap bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a pre-existing hook whose CONTENT the member swapped is restored byte-for-byte (exit 22)" "[ $rc -eq 22 ] && grep -q 'echo original' '$REPO/.git/hooks/pre-commit' && ! grep -q pwned '$REPO/.git/hooks/pre-commit'"
rm -f "$REPO/.git/hooks/pre-commit"
out=$(STUB_codex=exclude bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "an ignore rule added to .git/info/exclude is restored and the file it hid is reverted (exit 22)" "[ $rc -eq 22 ] && ! grep -q hidden '$REPO/.git/info/exclude' 2>/dev/null && [ ! -e '$REPO/hidden/x.ts' ]"
out=$(STUB_codex=poolforge bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "rolepod config is metadata: a member-created .rolepod/cross-family (pool override) is removed and a tracked-and-ignored .rolepod/risk-paths restored (exit 22)" "[ $rc -eq 22 ] && [ ! -e '$REPO/.rolepod/cross-family' ] && [ \"\$(cat '$REPO/.rolepod/risk-paths')\" = src/billing/ ] && printf '%s' \"$out\" | grep -q 'cross-family(removed'"
check "the runner primed .rolepod/ into .git/info/exclude (what the member's own session hook would add) — no false git-state violation from it" "grep -qxF '.rolepod/' '$REPO/.git/info/exclude'"
NL="$FIX/nonl"; mkdir -p "$NL/.rolepod/evidence"; git -C "$NL" init -q; printf 'r\n' > "$NL/README.md"; git -C "$NL" add -A; git -C "$NL" -c user.email=t@t -c user.name=t commit -qm init; printf 'node_modules' > "$NL/.git/info/exclude"
out=$(STUB_codex=noop bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --lead claude --root "$NL" 2>&1); rc=$?
check "priming an exclude file that lacks a final newline keeps the user's last rule intact and adds .rolepod/ on its own line" "[ $rc -eq 0 ] && grep -qxF 'node_modules' '$NL/.git/info/exclude' && grep -qxF '.rolepod/' '$NL/.git/info/exclude'"
printf 'agy\n' > "$REPO/.rolepod/untracked-note"; : > "$LOG"
out=$(STUB_codex=noop bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "an untracked .rolepod/ file that exists before the run is never read as a deletion (exit 0, outside=0)" "[ $rc -eq 0 ] && [ -f '$REPO/.rolepod/untracked-note' ] && printf '%s' \"$out\" | grep -q 'ROLEPOD-XFAM ok'"
rm -f "$REPO/.rolepod/untracked-note"
out=$(STUB_codex=forgekind bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a member row claiming kind:test for a touched non-test path is replaced by the runner's classified row (kind other)" "[ $rc -eq 0 ] && ! grep -q '\"path\": \"src/real.ts\", \"kind\": \"test\"' '$REPO/.rolepod/evidence/edits.jsonl' && grep -q '\"path\": \"src/real.ts\", \"kind\": \"other\", \"agent\": \"external-implementer\"' '$REPO/.rolepod/evidence/edits.jsonl'"
rm -rf "$REPO/src"
out=$(STUB_codex=githook bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a write to .GIT/hooks/ → exit 22 with the new hook removed (case-insensitive FS) or exit 21 reverted (case-sensitive FS); nothing pwned survives" "{ [ $rc -eq 22 ] || [ $rc -eq 21 ]; } && [ ! -e '$REPO/.git/hooks/pre-commit' ] && [ ! -e '$REPO/.GIT/hooks/pre-commit' ]"
git -C "$REPO" checkout -q -- .   # never `rm -rf "$REPO/.GIT"` here: on APFS that IS the repo's .git — the guard already removed the planted hook / reverted the path
out=$(STUB_codex=noop bash "$RUNNER" --kind implement --brief "$BRIEF" --allow src/billing/ --allow-risky --lead claude --root "$REPO" --detach 2>&1); rc=$?
JOBR=$(printf '%s' "$out" | sed -n 's/.*job=\([^ ]*\).*/\1/p' | head -1)
out=$(bash "$RUNNER" --collect "$JOBR" --root "$REPO" 2>&1); rc=$?
check "--detach carries --allow-risky to the child (the job runs, exit 0, not a usage refusal)" "[ $rc -eq 0 ] && printf '%s' \"$out\" | grep -q 'ROLEPOD-XFAM ok kind=implement'"
: > "$LOG"; NOGIT="$FIX/nogit"; mkdir -p "$NOGIT/.rolepod/evidence"; printf 'r\n' > "$NOGIT/README.md"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --lead claude --root "$NOGIT" 2>&1); rc=$?
chmod 000 "$REPO/.git/config"; : > "$LOG"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
chmod 644 "$REPO/.git/config"
check "unreadable .git/config → the metadata copy cannot be verified → the member is never run (exit 3)" "[ $rc -eq 3 ] && printf '%s' \"$out\" | grep -q 'member not run' && ! grep -q 'ROLE=implementer' '$LOG'"
check "no git repo → no baseline → the member is never run (exit 3, external-fail says member not run)" "[ $rc -eq 3 ] && printf '%s' \"$out\" | grep -q 'member not run' && ! grep -q 'ROLE=implementer' '$LOG'"

out=$(STUB_codex=commitforge bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a member that commits AND forges an external pass → exit 22 with forged=1; the forged line is gone even on the git-state path" "[ $rc -eq 22 ] && printf '%s' \"$out\" | grep -q 'forged=1' && ! grep -q 'external/pwn.txt' '$REPO/.rolepod/evidence/phase-log.jsonl'"
git -C "$REPO" checkout -q -- .; rm -rf "$REPO/src"
out=$(STUB_codex=failforge bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a member that forges an external pass and then crashes → the failure path scrubs it too (exit 3, line gone, external-fail notes it)" "[ $rc -eq 3 ] && ! grep -q 'external/pwn2.txt' '$REPO/.rolepod/evidence/phase-log.jsonl' && printf '%s' \"$out\" | grep -q 'evidence window scrubbed (1 forged'"
printf '{"t": 1, "ts": "", "cli": "claude", "path": "tests/old.test.ts", "kind": "test", "agent": ""}\n{"t": 2, "ts": "", "cli": "claude", "path": "src/old.ts", "kind": "other", "agent": ""}\n' >> "$REPO/.rolepod/evidence/edits.jsonl"
export LEDGER_KEEP=$(( $(wc -c < "$REPO/.rolepod/evidence/edits.jsonl") - 40 ))
out=$(STUB_codex=shrink bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "a member that truncates the ledger → counted as forged (exit 21), but the surviving prefix (older rows) is NOT wiped" "[ $rc -eq 21 ] && printf '%s' \"$out\" | grep -q 'forged=1' && grep -q 'tests/old.test.ts' '$REPO/.rolepod/evidence/edits.jsonl'"
unset LEDGER_KEEP

echo "── implement: restore on failure, fall-through, git-state violations (Task 4) ──"
git -C "$REPO" checkout -q -- .; rm -rf "$REPO/src" "$REPO/my dir"; H0=$(git -C "$REPO" rev-parse HEAD)
printf 'codex\nagy\n' > "$HOME/.rolepod/cross-family"; : > "$LOG"
out=$(STUB_codex=failafter bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "member exits 1 after half-writing → its edits reverted, next member (agy) implements from a clean tree, exit 0" "[ $rc -eq 0 ] && printf '%s' \"$out\" | grep -q 'cli=agy' && [ ! -e '$REPO/src/broken.ts' ] && ! grep -q partial '$REPO/README.md' && [ -f '$REPO/src/from-agy.ts' ]"
check "external-fail line for codex says the tree was restored; a copy of the half-written file is kept" "grep -q '\"phase\":\"external-fail\",\"kind\":\"implement\",\"cli\":\"codex\".*tree restored' '$REPO/.rolepod/evidence/phase-log.jsonl' && grep -q broken '$REPO'/.rolepod/evidence/external/*codex*.reverted/src/broken.ts"
rm -rf "$REPO/src"; printf 'codex\n' > "$HOME/.rolepod/cross-family"
out=$(STUB_codex=hang ROLEPOD_XFAM_STALL=3 bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "stalled member (rc 118) → tree restored (half.ts gone), exit 3 when no member is left" "[ $rc -eq 3 ] && [ ! -e '$REPO/src/half.ts' ] && printf '%s' \"$out\" | grep -q 'stalled'"
printf 'codex\nagy\n' > "$HOME/.rolepod/cross-family"; : > "$LOG"
out=$(STUB_codex=commit bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
printf '%s\n' "$out" > "$FIX/out4.txt"
check "member commits → exit 22 with git-state=1 exit= and a report= pointer" "[ $rc -eq 22 ] && printf '%s' \"$out\" | grep -q 'git-state=1 exit=0 reverted=1 forged=0 report=.rolepod/evidence/external/'"
check "member commits → HEAD back to the pre-run commit" "[ \"\$(git -C '$REPO' rev-parse HEAD)\" = '$H0' ]"
check "member commits → tree back (src/c.ts gone)" "[ ! -e '$REPO/src/c.ts' ]"
check "member commits → its commit stays in the reflog" "[ \"\$(git -C '$REPO' reflog | grep -c 'member commit')\" -ge 1 ]"   # grep -c, not -q: pipefail + an early-closing grep would fail the pipeline on git's SIGPIPE
check "member commits → no fall-through (agy not run)" "! grep -q '^agy' '$LOG'"
check "git-state violation is logged as external-fail with reason git-state" "grep -q '\"phase\":\"external-fail\",\"kind\":\"implement\",\"cli\":\"codex\".*\"reason\":\"git-state: HEAD' '$REPO/.rolepod/evidence/phase-log.jsonl'"
B0=$(git -C "$REPO" symbolic-ref HEAD)
out=$(STUB_codex=branch bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "member switches branch → exit 22, HEAD symbolic ref restored, tree back" "[ $rc -eq 22 ] && [ \"\$(git -C '$REPO' symbolic-ref HEAD)\" = '$B0' ] && [ ! -e '$REPO/src/b.ts' ] && printf '%s' \"$out\" | grep -q 'branch refs/heads/'"
git -C "$REPO" branch -q -D evil 2>/dev/null
out=$(STUB_codex=stash bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "member stashes → exit 22, the stash is reported and left in place, tree back" "[ $rc -eq 22 ] && printf '%s' \"$out\" | grep -q 'the stash ref changed' && git -C '$REPO' stash list | grep -q . && ! grep -q '^s$' '$REPO/README.md'"
git -C "$REPO" stash drop -q 2>/dev/null; git -C "$REPO" checkout -q -- .; rm -rf "$REPO/src"; printf 'codex\n' > "$HOME/.rolepod/cross-family"
git -C "$REPO" checkout -q --detach "$H0"
out=$(STUB_codex=branch bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "detached start + member checks out a branch and writes → HEAD detached at H0 again, the member's branch NOT rewound to H0" "[ $rc -eq 22 ] && ! git -C '$REPO' symbolic-ref -q HEAD >/dev/null && [ \"\$(git -C '$REPO' rev-parse HEAD)\" = '$H0' ] && [ ! -e '$REPO/src/b.ts' ]"
git -C "$REPO" checkout -q "$(printf '%s' "$B0" | sed 's#refs/heads/##')"; git -C "$REPO" branch -q -D evil 2>/dev/null
UNB="$FIX/unborn"; mkdir -p "$UNB/.rolepod/evidence"; git -C "$UNB" init -q; printf 'r\n' > "$UNB/README.md"
out=$(STUB_codex=commit bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$UNB" 2>&1); rc=$?
check "unborn HEAD + member makes the first commit → exit 22, the branch is unborn again, the tree back to the untracked README only" "[ $rc -eq 22 ] && ! git -C '$UNB' rev-parse -q --verify HEAD >/dev/null && [ ! -e '$UNB/src/c.ts' ] && [ -f '$UNB/README.md' ]"
check "unborn case: nothing of the member's stays staged" "[ -z \"\$(git -C '$UNB' diff --cached --name-only 2>/dev/null)\" ]"
NUKE="$FIX/nuke"; mkdir -p "$NUKE/.rolepod/evidence"; git -C "$NUKE" init -q; printf 'r\n' > "$NUKE/README.md"; git -C "$NUKE" add -A; git -C "$NUKE" -c user.email=t@t -c user.name=t commit -qm init
out=$(STUB_codex=nuke bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$NUKE" 2>&1); rc=$?
check "member commits then deletes .git → exit 22, no shell error, the line says the tree could NOT be restored" "[ $rc -eq 22 ] && ! printf '%s' \"$out\" | grep -q 'integer expression' && printf '%s' \"$out\" | grep -q 'could NOT be restored'"

echo "── implement: a live job blocks a second one (either kind) ──"
: > "$LOG"
out=$(STUB_codex=hang HANG_POKE=1 bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" --detach 2>&1); rc=$?
JOB=$(printf '%s' "$out" | sed -n 's/.*job=\([^ ]*\).*/\1/p' | head -1)
check "detached implement returns a job id + EDITING notice" "[ $rc -eq 0 ] && [ -n '$JOB' ] && printf '%s' \"$out\" | grep -q 'EDITING this tree'"
check "the job dir records the allow list for the child" "grep -qx 'README.md' '$REPO/.rolepod/evidence/external/jobs/$JOB/allow' && grep -qx 'src/' '$REPO/.rolepod/evidence/external/jobs/$JOB/allow'"
sleep 1
out2=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc2=$?
check "second implement while live → exit 8 refused stacked" "[ $rc2 -eq 8 ] && printf '%s' \"$out2\" | grep -q 'refused stacked'"
out3=$(bash "$RUNNER" --kind review --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc3=$?
check "a review while the implement job is live → exit 8 too" "[ $rc3 -eq 8 ]"
bash "$RUNNER" --kill "$JOB" --root "$REPO" >/dev/null 2>&1
check "--kill ends the job (status 137)" "[ \"\$(cat '$REPO/.rolepod/evidence/external/jobs/$JOB/status' 2>/dev/null)\" = 137 ]"
sleep 2
check "--kill took the member itself down (no stub process left in the fixture)" "! pgrep -f '$BIN/codex' >/dev/null"
check "--kill also scrubbed the forged phase-log line, dropped the forged ledger row and restored .git/config" "! grep -q 'external/killforge.txt' '$REPO/.rolepod/evidence/phase-log.jsonl' && ! grep -q 'tests/killghost.test.ts' '$REPO/.rolepod/evidence/edits.jsonl' && [ \"\$(git -C '$REPO' config --local user.name)\" = t ]"
check "--kill restored the tree (src/half.ts and 400 stray files gone, git status clean)" "[ ! -e '$REPO/src/half.ts' ] && [ ! -d '$REPO/stray' ] && [ -z \"\$(git -C '$REPO' status --porcelain -- . ':(exclude).rolepod')\" ]"

echo "── implement: opencode without project permissions is skipped, next member runs ──"
: > "$LOG"; rm -f "$REPO/opencode.json"
printf 'opencode\ncodex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "opencode never invoked, codex implemented (exit 0)" "[ $rc -eq 0 ] && ! grep -q '^opencode' '$LOG' && grep -q '^codex' '$LOG'"
check "phase-log external-fail says no opencode config grants edit+bash (and where it looked)" "grep -q '\"phase\":\"external-fail\".*\"cli\":\"opencode\".*no opencode config grants edit+bash (checked the project, OPENCODE_CONFIG_DIR and ~/.config/opencode)' '$REPO/.rolepod/evidence/phase-log.jsonl'"
git -C "$REPO" checkout -q -- README.md; rm -rf "$REPO/src"
printf '{"permission":{"edit":"allow","bash":{"*":"allow"}}}\n' > "$REPO/opencode.json"
: > "$LOG"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "opencode WITH edit+bash allow is invoked (run, no --agent plan)" "grep -q '^opencode | run ' '$LOG' && ! grep -q -- '--agent plan' '$LOG'"
rm -f "$REPO/opencode.json"; printf '{\n  // project config with comments\n  "permission": {"edit": "allow", "bash": {"*": "allow"},},\n}\n' > "$REPO/opencode.jsonc"
: > "$LOG"; git -C "$REPO" checkout -q -- README.md; rm -rf "$REPO/src"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "opencode.jsonc (comments, trailing commas) granting edit+bash is honoured" "grep -q '^opencode | run ' '$LOG'"
rm -f "$REPO/opencode.jsonc"; printf '{"permission":{"edit":"allow","bash":{"*":"allow"}}}\n' > "$REPO/opencode.json"; git -C "$REPO" add opencode.json; git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm "opencode config"
cat > "$BIN/opencode" <<'STUB'
#!/bin/bash
echo "opencode | $*" >> "${LOG_FILE:?}"; _r=$(git rev-parse --show-toplevel 2>/dev/null); printf '{"$schema":"x","permission":{"edit":"allow","bash":{"*":"allow"}}}\n' > "$_r/opencode.json"; mkdir -p "$_r/src"; printf 'o\n' > "$_r/src/oc.ts"; printf 'Implemented by opencode.\n%s\n' "$(head -c 300 /dev/zero | tr '\0' o)"; exit 0
STUB
chmod +x "$BIN/opencode"; git -C "$REPO" checkout -q -- README.md; rm -rf "$REPO/src"; : > "$LOG"
out=$(bash "$RUNNER" --kind implement --brief "$BRIEF" --allow README.md --allow src/ --lead claude --root "$REPO" 2>&1); rc=$?
check "opencode rewriting the project opencode.json on start is housekeeping: restored, noted, exit 0 (its real edit kept)" "[ $rc -eq 0 ] && printf '%s' \"$out\" | grep -q 'housekeeping restored, not a violation.*opencode.json' && ! grep -q 'schema' '$REPO/opencode.json' && [ -f '$REPO/src/oc.ts' ]"
rm -rf "$REPO/src"; git -C "$REPO" rm -q --cached opencode.json; rm -f "$REPO/opencode.json"; git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm "drop opencode config"
cat > "$BIN/opencode" <<'STUB'
#!/bin/bash
echo "opencode | $*" >> "${LOG_FILE:?}"; printf 'should not run\n'; exit 0
STUB
chmod +x "$BIN/opencode"
rm -f "$REPO/opencode.jsonc"

echo "── implement: other kinds stay read-only ──"
git -C "$REPO" checkout -q -- README.md; rm -rf "$REPO/src"   # the ticket is clean again → codex is no longer "the implementer of an uncommitted ticket"
: > "$LOG"; printf 'codex\n' > "$HOME/.rolepod/cross-family"
out=$(bash "$RUNNER" --kind review --brief "$BRIEF" --lead claude --root "$REPO" 2>&1); rc=$?
check "review still runs codex with -s read-only" "grep -q -- '-s read-only' '$LOG' && ! grep -q -- 'workspace-write' '$LOG'"

if [ "$fail" -eq 0 ]; then echo "  all cross-family-implement checks passed"; else echo "  $fail cross-family-implement check(s) failed"; echo "--- out1:"; tail -5 "$FIX/out1.txt" 2>/dev/null; echo "--- out2:"; tail -5 "$FIX/out2.txt" 2>/dev/null; echo "--- out4:"; tail -3 "$FIX/out4.txt" 2>/dev/null; git -C "$REPO" reflog | head -3; exit 1; fi
