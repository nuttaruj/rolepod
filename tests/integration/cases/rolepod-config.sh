#!/bin/bash
# rolepod-config — the shared reader: `rolepod_config.py shell|pool` reads only
# $HOME/.rolepod/config.json; project pool is ignored with one warning while
# obsolete project review/gates/nudge keys are silent; broken file or unknown
# value -> defaults + one warning; exit 0.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
PY="$ROOT/hooks/lib/rolepod_config.py"
fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# run <cmd> <home-json|-> <proj-json|->; sets OUT, ERR, RC.
run() {
  local c="$1" h="$2" p="$3"
  local d; d=$(mktemp -d "$TMP/c.XXXXXX")
  mkdir -p "$d/home/.rolepod" "$d/proj/.rolepod"
  [ "$h" = - ] || printf '%s' "$h" > "$d/home/.rolepod/config.json"
  [ "$p" = - ] || printf '%s' "$p" > "$d/proj/.rolepod/config.json"
  RC=0
  OUT=$(cd "$d/proj" && HOME="$d/home" python3 -I "$PY" "$c" 2>"$d/err") || RC=$?
  ERR=$(cat "$d/err")
}

check() { # name expected-out expected-warn-lines
  local n=0; [ -n "$ERR" ] && n=$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')
  if [ "$OUT" = "$2" ] && [ "$n" = "$3" ] && [ "$RC" = 0 ]; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1 (out='$OUT' want='$2'; stderr lines=$n want=$3; rc=$RC)"
    fail=$((fail+1))
  fi
}

NL=$'\n'
S() { printf 'gates=%s\nnudge=%s' "$1" "$2"; }

run shell - -;                                         check "no file -> lite defaults" "$(S off on)" 0
run shell '{"workflow":{"mode":"lite"}}' -;             check "lite profile" "$(S off on)" 0
run shell '{"workflow":{"mode":"standard"}}' -;         check "standard profile" "$(S soft on)" 0
run shell '{"workflow":{"mode":"full"}}' -;             check "full profile" "$(S hard on)" 0
run shell '{"gates":{"mode":"HARD"}}' -;               check "legacy gates value ignored" "$(S off on)" 0
run shell '{"gates":"off"}' -;                         check "legacy gates object ignored" "$(S off on)" 0
run shell '{"nudge":{"enabled":false}}' -;             check "legacy nudge value ignored" "$(S off on)" 0
run shell '{"nudge":{"enabled":"no"}}' -;              check "legacy nudge type ignored" "$(S off on)" 0
run shell '{not json' -;                               check "broken JSON -> Standard safety fallback + warning" "$(S soft on)" 1
run shell '[1,2]' -;                                   check "non-object JSON -> Standard safety fallback + warning" "$(S soft on)" 1
run shell '{"gates":{"mode":"hard","x":1},"zzz":3,"version":9}' -
check "extra legacy keys ignored" "$(S off on)" 0
run shell - '{"gates":{"mode":"off"}}';                check "project gates ignored silently" "$(S off on)" 0
run shell - '{"nudge":{"enabled":false}}';             check "project nudge ignored silently" "$(S off on)" 0
run shell - '{"review":{"mode":"full"},"gates":{"mode":"off"},"nudge":{"enabled":false}}'; check "obsolete project review/gates/nudge ignored silently" "$(S off on)" 0
run shell - '{"pool":{"cross-family":"on"}}';          check "project pool ignored + warn" "$(S off on)" 1
case "$ERR" in *"project pool is ignored; global config only"*) echo "  ✓ project pool warning has the canonical meaning" ;; *) echo "  ✗ project pool warning text: $ERR"; fail=$((fail+1)) ;; esac
run shell '{"workflow":{"mode":"full"}}' '{"workflow":{"mode":"lite"}}'
check "workflow project beats global" "$(S off on)" 0
run shell - '{"review":{"mode":"full"}}';              check "project file without the keys: silent" "$(S off on)" 0
run shell - '{not json';                               check "broken project file warns and defaults to Standard" "$(S soft on)" 1

# mode is the shared contract consumed by hook bridges and skill wrappers.
run mode '{"workflow":{"mode":"full"}}' '{"workflow":{"mode":"lite"}}'
check "workflow.mode project beats global" "mode=lite${NL}source=project${NL}modern=yes${NL}gates=off${NL}nudge=on${NL}review=standard${NL}review-source=project" 0
run mode '{"workflow":{"mode":"full"}}' -
check "workflow.mode global profile" "mode=full${NL}source=global${NL}modern=yes${NL}gates=hard${NL}nudge=on${NL}review=full${NL}review-source=global" 0
run mode '{not json' '{"workflow":{"mode":"lite"}}'
check "project mode still wins over broken global config" "mode=lite${NL}source=project${NL}modern=yes${NL}gates=off${NL}nudge=on${NL}review=standard${NL}review-source=project" 1
run mode - -
check "workflow.mode default profile" "mode=lite${NL}source=default${NL}modern=no${NL}gates=off${NL}nudge=on${NL}review=standard${NL}review-source=default" 0
OUT=$(ROLEPOD_SESSION_MODE=lite ROLEPOD_SESSION_SOURCE=project bash "$ROOT/core/skills/using-rolepod/scripts/workflow-mode.sh" --source)
[ "$OUT" = "lite (project)" ] && echo "  ✓ workflow-mode reads the frozen Lite session profile" || { echo "  ✗ workflow-mode frozen profile ($OUT)"; fail=$((fail+1)); }
run mode '{"workflow":{"mode":"bad"},"review":{"mode":"full"}}' -
check "invalid workflow.mode falls back to standard" "mode=standard${NL}source=global${NL}modern=yes${NL}gates=soft${NL}nudge=on${NL}review=standard${NL}review-source=global" 1
run mode '{"review":{"mode":"full"},"gates":{"mode":"hard"},"nudge":{"enabled":false}}' -
check "legacy settings ignored" "mode=lite${NL}source=default${NL}modern=no${NL}gates=off${NL}nudge=on${NL}review=standard${NL}review-source=default" 0

POOL='{"version":1,"pool":{"cross-family":"on","reviewer":{"review":"opencode cursor stall=60 agy","consult":"codex claude","critique":"opencode","tier":"R4"},"implement":{"cli":"opencode cursor"}}}'
run pool - -;                                          check "pool: no file -> off, not configured" "enabled=off${NL}configured=no" 0
run pool '{"gates":{"mode":"soft"}}' -;                check "pool: no pool key -> off, not configured" "enabled=off${NL}configured=no" 0
run pool "$POOL" -
check "pool: spec example (old tier / implement keys read silently, not printed)" "enabled=on${NL}configured=yes${NL}review=opencode cursor stall=60 agy${NL}consult=codex claude${NL}critique=opencode" 0
run pool '{"pool":{"cross-family":"off","reviewer":{"review":"codex"}}}' -
check "pool: cross-family off wins over lists (configured)" "enabled=off${NL}configured=yes" 0
run pool '{"pool":{"reviewer":{"review":"codex claude"}}}' -
check "pool: no switch, list present -> on" "enabled=on${NL}configured=yes${NL}review=codex claude" 0
run pool '{"pool":{"cross-family":"of","reviewer":{"review":"codex"}}}' -
check "pool: bad switch -> off + warn" "enabled=off${NL}configured=yes" 1
run pool '{"pool":{"cross-family":"on","reviewer":{"review":"none"}}}' -
check "pool: review none -> off" "enabled=off${NL}configured=yes" 0
run pool '{"pool":{"cross-family":"on"}}' -;           check "pool: on without lists -> off" "enabled=off${NL}configured=yes" 0
run pool '{"pool":{"cross-family":"on","implement":{"cli":"codex"}}}' -
check "pool: implement only -> off" "enabled=off${NL}configured=yes" 0
run pool '{"pool":{"cross-family":"on","reviewer":{"review":["a"],"tier":"R3"}}}' -
check "pool: non-string member list is left out + one warning; tier ignored" "enabled=off${NL}configured=yes" 1
run pool '{"pool":"on"}' -;                            check "pool: not an object -> off + warn (configured)" "enabled=off${NL}configured=yes" 1
run pool '{oops' -;                                    check "pool: broken JSON -> off + one warning, configured=yes (the loader stays silent)" "enabled=off${NL}configured=yes" 1
run pool - "$POOL";                                    check "pool: project pool ignored + warn" "enabled=off${NL}configured=no" 1

run pool '{"pool":{"reviewer":"codex"}}' -;             check "pool: reviewer not an object -> off + one warning" "enabled=off${NL}configured=yes" 1
run pool '{"pool":{"cross-family":"on","reviewer":{"review":5,"tier":"R2"}}}' -; check "pool: review of the wrong type -> warned, tier ignored" "enabled=off${NL}configured=yes" 1
run pool '{"pool":{"cross-family":"on","reviewer":{"review":"codex"},"implement":{"cli":["x"]}}}' -; check "pool: implement of any shape is ignored silently" "enabled=on${NL}configured=yes${NL}review=codex" 0
run pool '{"pool":{"reviewer":{"review":"a\nenabled=on\nreview=evil"}}}' -;  check "pool: a newline inside a value collapses to one line (no forged key)" "enabled=on${NL}configured=yes${NL}review=a enabled=on review=evil" 0

# git subdir: the project file is the git root's.
g="$TMP/g"; mkdir -p "$g/home" "$g/repo/.rolepod" "$g/repo/sub"
git -C "$g/repo" init -q
printf '{"pool":{"cross-family":"on"}}' > "$g/repo/.rolepod/config.json"
RC=0; OUT=$(cd "$g/repo/sub" && HOME="$g/home" python3 -I "$PY" shell 2>"$g/err") || RC=$?
ERR=$(cat "$g/err")
check "git subdir sees the root project pool warning" "$(S off on)" 1

# A hook may set ROLEPOD_PROJECT_ROOT to the tool's cwd inside a repository.
# Both implicit cwd discovery and this explicit override must walk to the .git
# boundary rather than treating the nested directory as a separate project.
printf '{"workflow":{"mode":"lite"}}' > "$g/repo/.rolepod/config.json"
for explicit in no yes; do
  if [ "$explicit" = yes ]; then
    OUT=$(cd "$g/repo/sub" && HOME="$g/home" ROLEPOD_PROJECT_ROOT="$g/repo/sub" python3 -I "$PY" mode 2>"$g/err") || RC=$?
  else
    OUT=$(cd "$g/repo/sub" && HOME="$g/home" python3 -I "$PY" mode 2>"$g/err") || RC=$?
  fi
  ERR=$(cat "$g/err")
  case "$OUT" in *"mode=lite"*"source=project"*) [ -z "$ERR" ] && [ "${RC:-0}" = 0 ] && echo "  ✓ nested cwd discovers root project mode (explicit=$explicit)" || { echo "  ✗ nested cwd warnings or nonzero exit (explicit=$explicit, err='$ERR')"; fail=$((fail+1)); } ;;
    *) echo "  ✗ nested cwd did not resolve root project mode (explicit=$explicit, out='$OUT')"; fail=$((fail+1)) ;;
  esac
  RC=0
done

# Worktrees represent .git as a file. Directory discovery must accept either
# filesystem shape; the file content is intentionally just the marker here.
mkdir -p "$g/worktree/.rolepod" "$g/worktree/src"
printf 'gitdir: ../admin/worktrees/example\n' > "$g/worktree/.git"
printf '{"workflow":{"mode":"full"}}' > "$g/worktree/.rolepod/config.json"
OUT=$(cd "$g/worktree/src" && HOME="$g/home" ROLEPOD_PROJECT_ROOT="$g/worktree/src" python3 -I "$PY" mode 2>"$g/err") || RC=$?
ERR=$(cat "$g/err")
case "$OUT" in *"mode=full"*"source=project"*) [ -z "$ERR" ] && [ "${RC:-0}" = 0 ] && echo "  ✓ explicit nested cwd discovers file-shaped .git boundary" || { echo "  ✗ file-shaped .git produced warning or nonzero exit"; fail=$((fail+1)); } ;;
  *) echo "  ✗ file-shaped .git did not resolve root project mode (out='$OUT')"; fail=$((fail+1)) ;;
esac
RC=0

# ── init: the defaults are written once, only when nothing is there ──
ok() { echo "  ✓ $1"; }
bad() { echo "  ✗ $1"; fail=$((fail+1)); }
EXPECT="$TMP/init.expected"
python3 -I -c "import sys; sys.path.insert(0, '$ROOT/hooks/lib'); import rolepod_config as c; sys.stdout.write(c.DEFAULT_CONFIG)" > "$EXPECT"
python3 -c "import json,sys; d=json.load(open('$EXPECT')); assert d['version']==1 and d['workflow']['mode']=='lite' and 'review' not in d and 'gates' not in d and 'nudge' not in d and d['pool']['cross-family']=='off' and d['pool']['reviewer']['review']=='claude codex agy' and d['pool']['reviewer']['consult']=='claude codex agy' and d['pool']['reviewer']['critique']=='claude codex agy' and 'implement' not in d['pool']" \
  && ok "init: DEFAULT_CONFIG is the documented default" || bad "init: DEFAULT_CONFIG content"
IH="$TMP/ih1"; mkdir -p "$IH"
O=$(HOME="$IH" python3 -I "$PY" init 2>"$TMP/ie"); RC=$?
if [ "$O" = "wrote $IH/.rolepod/config.json (missing)" ] && [ ! -s "$TMP/ie" ] && [ "$RC" = 0 ] && cmp -s "$EXPECT" "$IH/.rolepod/config.json"; then ok "init: writes the exact default, one 'wrote <path>' line"; else bad "init first run (out='$O' rc=$RC)"; fi
cp "$IH/.rolepod/config.json" "$TMP/ih1.keep"
O=$(HOME="$IH" python3 -I "$PY" init 2>&1); RC=$?
if [ -z "$O" ] && [ "$RC" = 0 ] && cmp -s "$TMP/ih1.keep" "$IH/.rolepod/config.json"; then ok "init: second run is silent and byte-identical"; else bad "init second run (out='$O')"; fi
R=$(HOME="$IH" python3 -I "$PY" shell | tr '\n' ' '); P=$(HOME="$IH" python3 -I "$PY" pool | tr '\n' ' ')
[ "$R" = "gates=off nudge=on " ] && [ "$P" = "enabled=off configured=yes " ] \
  && ok "init: the written file reads gates=off nudge=on, pool off configured=yes" || bad "init: reader of the written file ('$R' / '$P')"
# a valid modern file (even --force at install) and a dangling symlink: untouched, silent
for kind in modern-full dangling; do
  H="$TMP/ik-$kind"; mkdir -p "$H/.rolepod"
  case "$kind" in
    modern-full) printf '{"workflow":{"mode":"full"},"extra":1}\n' > "$H/.rolepod/config.json" ;;
    dangling) ln -s "$H/nowhere" "$H/.rolepod/config.json" ;;
  esac
  before=$(ls -l "$H/.rolepod"; [ -f "$H/.rolepod/config.json" ] && cat "$H/.rolepod/config.json" || true)
  O=$(HOME="$H" python3 -I "$PY" init 2>&1); RC=$?
  after=$(ls -l "$H/.rolepod"; [ -f "$H/.rolepod/config.json" ] && cat "$H/.rolepod/config.json" || true)
  if [ -z "$O" ] && [ "$RC" = 0 ] && [ "$before" = "$after" ] && { [ "$kind" != dangling ] || { [ -L "$H/.rolepod/config.json" ] && [ ! -e "$H/nowhere" ]; }; }; then ok "init: existing $kind config untouched"; else bad "init: $kind config touched (out='$O')"; fi
done
# old format (legacy top-level key, or no workflow.mode): rewritten, pool kept, no backup
for kind in old-gates old-with-workflow no-mode; do
  IR="$TMP/iold-$kind"; mkdir -p "$IR/.rolepod"
  case "$kind" in
    old-gates) printf '{"gates":{"mode":"hard"},"pool":{"cross-family":"on","reviewer":{"review":"codex claude"}}}' > "$IR/.rolepod/config.json" ;;
    old-with-workflow) printf '{"review":{"mode":"full"},"gates":{"mode":"off"},"nudge":{"enabled":false},"workflow":{"mode":"full"},"pool":{"cross-family":"on","reviewer":{"review":"codex claude"}}}' > "$IR/.rolepod/config.json" ;;
    no-mode) printf '{"version":1,"pool":{"cross-family":"on","reviewer":{"review":"codex claude"}}}' > "$IR/.rolepod/config.json" ;;
  esac
  O=$(HOME="$IR" python3 -I "$PY" init 2>"$TMP/iold.err"); RC=$?
  if [ "$O" = "wrote $IR/.rolepod/config.json (old format)" ] && [ ! -s "$TMP/iold.err" ] && [ "$(ls -A "$IR/.rolepod" | wc -l | tr -d ' ')" = 1 ] && python3 -c "import json; d=json.load(open('$IR/.rolepod/config.json')); assert d['workflow']=={'mode':'lite'} and d['pool']=={'cross-family':'on','reviewer':{'review':'codex claude'}} and 'review' not in d and 'gates' not in d and 'nudge' not in d"; then ok "init: $kind rewritten to Lite, pool kept, no backup"; else bad "init: $kind failed (out='$O' rc=$RC)"; fi
done
# unreadable JSON: rewritten with the defaults
IR="$TMP/ibroken"; mkdir -p "$IR/.rolepod"; printf '{ not json' > "$IR/.rolepod/config.json"
O=$(HOME="$IR" python3 -I "$PY" init 2>&1); RC=$?
if [ "$O" = "wrote $IR/.rolepod/config.json (unreadable)" ] && cmp -s "$EXPECT" "$IR/.rolepod/config.json" && [ "$(ls -A "$IR/.rolepod" | wc -l | tr -d ' ')" = 1 ]; then ok "init: unreadable file rewritten with the defaults"; else bad "init: unreadable (out='$O' rc=$RC)"; fi
# the old init-replace command is gone
O=$(HOME="$IR" python3 -I "$PY" init-replace 2>&1 | head -1)
case "$O" in wrote*) bad "init-replace still writes" ;; *) ok "init-replace is not a command" ;; esac
# read-only HOME: exit 0, silent
H="$TMP/iro"; mkdir -p "$H"; chmod 555 "$H"
O=$(HOME="$H" python3 -I "$PY" init 2>&1); RC=$?
chmod 755 "$H"
if [ -z "$O" ] && [ "$RC" = 0 ] && [ ! -e "$H/.rolepod" ]; then ok "init: read-only HOME exits 0, silent"; elif [ "$(id -u)" = 0 ]; then ok "init: read-only HOME (root, skipped)"; else bad "init: read-only HOME (out='$O' rc=$RC)"; fi
# two concurrent inits: one valid file, exactly one 'wrote'
H="$TMP/iconc"; mkdir -p "$H"
(HOME="$H" python3 -I "$PY" init > "$TMP/c1.out" 2>&1 &
 HOME="$H" python3 -I "$PY" init > "$TMP/c2.out" 2>&1 &
 wait)
if [ "$(cat "$TMP/c1.out" "$TMP/c2.out" | grep -c '^wrote ')" = 1 ] && python3 -c "import json; json.load(open('$H/.rolepod/config.json'))" 2>/dev/null; then ok "init: two concurrent runs leave one valid file"; else bad "init: concurrent runs"; fi

# Session profile: one resolver call at startup, cached through same-session
# config edits and compact; a new startup recaptures even with a reused ID.
SP_HOME="$TMP/session-home"; SP_REPO="$TMP/session-project"; mkdir -p "$SP_HOME" "$SP_REPO/nested" "$SP_REPO/.rolepod"
git -C "$SP_REPO" init -q
printf '{"workflow":{"mode":"lite"}}' > "$SP_REPO/.rolepod/config.json"
SP_REAL_PY=$(command -v python3); SP_BIN="$TMP/session-bin"; mkdir -p "$SP_BIN"
printf '#!/bin/bash\necho call >> "%s/session-python-count"\ncase " $* " in *hooks/lib/rolepod_config.py\ mode*) echo mode >> "%s/session-resolver-count" ;; esac\nexec "%s" "$@"\n' "$TMP" "$TMP" "$SP_REAL_PY" > "$SP_BIN/python3"
chmod +x "$SP_BIN/python3"
SP_PAYLOAD=$(printf '{"session_id":"fixed-session","cwd":"%s/nested","source":"startup"}' "$SP_REPO")
SP_OUT=$(printf '%s' "$SP_PAYLOAD" | PATH="$SP_BIN:$PATH" HOME="$SP_HOME" bash "$ROOT/hooks/session-start.sh" --cli cursor)
SP_PROFILE="$SP_HOME/.rolepod/session-profiles/cursor/fixed-session.mode"
SP_MODE=$(sed -n '1p' "$SP_PROFILE" 2>/dev/null || true)
printf '{"workflow":{"mode":"full"}}' > "$SP_REPO/.rolepod/config.json"
SP_CACHED=$(printf '%s' "$SP_PAYLOAD" | PATH="$SP_BIN:$PATH" HOME="$SP_HOME" ROLEPOD_SESSION_CLI=cursor bash -c '. "$1/hooks/lib/session-mode.sh"; rolepod_session_profile_load "$(cat)" cursor; printf "%s %s" "$ROLEPOD_SESSION_MODE" "$ROLEPOD_SESSION_SOURCE"' _ "$ROOT")
SP_COUNT=0; [ -f "$TMP/session-resolver-count" ] && SP_COUNT=$(wc -l < "$TMP/session-resolver-count" | tr -d ' ')
if [ "$SP_MODE" = lite ] && [ "$SP_CACHED" = "lite project" ] && [ "$SP_COUNT" = 1 ] \
  && [ "$(stat -f %Lp "$SP_PROFILE" 2>/dev/null || stat -c %a "$SP_PROFILE" 2>/dev/null)" = 600 ] \
  && [[ "$SP_OUT" == *"Active Rolepod workflow profile: lite (source: project)"* ]]; then ok "session profile: startup captures one read; same-session config change keeps Lite; private snapshot"; else bad "session profile cache ($SP_MODE / '$SP_CACHED' / reads=$SP_COUNT)"; fi
SP_BEFORE_HOOKS=$(wc -l < "$TMP/session-python-count" | tr -d ' ')
SP_HOOK_PAYLOAD=$(printf '{"session_id":"fixed-session","cwd":"%s/nested","tool_name":"Bash","tool_input":{"command":"git push"}}' "$SP_REPO")
for SP_HOOK in subagent-core.sh claim-verify-nudge.sh push-ref-check.sh workflow-tier-nudge.sh gate-reminder.sh worktree-guard.sh project-context-loader.sh fix-loop-breaker.sh block-subagent-commit.sh subagent-write-scope.sh dispatch-auto-log.sh precommit-gate.sh; do
  printf '%s' "$SP_HOOK_PAYLOAD" | PATH="$SP_BIN:$PATH" HOME="$SP_HOME" ROLEPOD_SESSION_CLI=cursor bash "$ROOT/hooks/$SP_HOOK" >/dev/null 2>&1 || true
done
printf '%s' "$SP_HOOK_PAYLOAD" | PATH="$SP_BIN:$PATH" HOME="$SP_HOME" ROLEPOD_SESSION_CLI=cursor bash "$ROOT/hooks/session-lifecycle.sh" --lock >/dev/null 2>&1 || true
HOME="$SP_HOME" bash -c '. "$1/hooks/lib/session-mode.sh"; rolepod_session_profile_store antigravity fixed-session lite project' _ "$ROOT"
printf '%s' "$SP_HOOK_PAYLOAD" | PATH="$SP_BIN:$PATH" HOME="$SP_HOME" bash "$ROOT/plugins/rolepod-cursor/scripts/precommit-gate.sh" >/dev/null 2>&1
printf '%s' "$SP_HOOK_PAYLOAD" | PATH="$SP_BIN:$PATH" HOME="$SP_HOME" bash "$ROOT/build/rendered/antigravity/plugin/hooks/pre-tool.sh" >/dev/null 2>&1
SP_RES_AFTER_HOOKS=0; [ -f "$TMP/session-resolver-count" ] && SP_RES_AFTER_HOOKS=$(wc -l < "$TMP/session-resolver-count" | tr -d ' ')
[ "$SP_RES_AFTER_HOOKS" = "$SP_COUNT" ] && ok "session profile: Lite hooks and adapter wrappers never re-read config (the startup capture is the only read)" || bad "Lite callbacks re-read config ($SP_COUNT -> $SP_RES_AFTER_HOOKS)"
SP_COMPACT=$(printf '%s\n' "$SP_PAYLOAD" | sed 's/"startup"/"compact"/' )
printf '%s' "$SP_COMPACT" | PATH="$SP_BIN:$PATH" HOME="$SP_HOME" bash "$ROOT/hooks/session-start.sh" --cli cursor >/dev/null
SP_COUNT_AFTER_COMPACT=0; [ -f "$TMP/session-resolver-count" ] && SP_COUNT_AFTER_COMPACT=$(wc -l < "$TMP/session-resolver-count" | tr -d ' ')
SP_RESUME=$(printf '%s\n' "$SP_PAYLOAD" | sed 's/"startup"/"resume"/' )
SP_OUT=$(printf '%s' "$SP_RESUME" | PATH="$SP_BIN:$PATH" HOME="$SP_HOME" bash "$ROOT/hooks/session-start.sh" --cli cursor)
SP_COUNT_AFTER_RESUME=0; [ -f "$TMP/session-resolver-count" ] && SP_COUNT_AFTER_RESUME=$(wc -l < "$TMP/session-resolver-count" | tr -d ' ')
if [ "$SP_COUNT_AFTER_COMPACT" = 1 ] && [ "$SP_COUNT_AFTER_RESUME" = 2 ] \
  && [ "$(sed -n '1p' "$SP_PROFILE")" = full ] \
  && [[ "$SP_OUT" == *"Active Rolepod workflow profile: full (source: project)"* ]]; then ok "session profile: compact reuses; resume recaptures changed config"; else bad "session profile recapture (compact=$SP_COUNT_AFTER_COMPACT resume=$SP_COUNT_AFTER_RESUME)"; fi
printf '{"workflow":{"mode":"lite"}}' > "$SP_REPO/.rolepod/config.json"
SP_CLEAR=$(printf '%s\n' "$SP_PAYLOAD" | sed 's/"startup"/"clear"/' )
SP_CLEAR_OUT=$(printf '%s' "$SP_CLEAR" | PATH="$SP_BIN:$PATH" HOME="$SP_HOME" bash "$ROOT/hooks/session-start.sh" --cli cursor --format env)
[ "$(sed -n '1p' "$SP_PROFILE")" = lite ] && [[ "$SP_CLEAR_OUT" == *'"ROLEPOD_SESSION_MODE": "lite"'* ]] && ok "session profile: fresh native clear recaptures configuration" || bad "session profile clear did not recapture"
printf '{"workflow":{"mode":"full"}}' > "$SP_REPO/.rolepod/config.json"
SP_ENV=$(printf '%s' "$SP_RESUME" | PATH="$SP_BIN:$PATH" HOME="$SP_HOME" bash "$ROOT/hooks/session-start.sh" --cli cursor --format env)
case "$SP_ENV" in *'"ROLEPOD_SESSION_MODE": "full"'*'"ROLEPOD_SESSION_SOURCE": "project"'*'"ROLEPOD_SESSION_CLI": "cursor"'*) ok "session profile: env output carries frozen constants" ;; *) bad "session profile env output ($SP_ENV)" ;; esac
SP_OTHER="$TMP/session-other"; mkdir -p "$SP_OTHER/.rolepod"
printf '{"workflow":{"mode":"lite"}}' > "$SP_OTHER/.rolepod/config.json"
SP_OTHER_PAYLOAD=$(printf '{"session_id":"other-session","cwd":"%s","source":"startup"}' "$SP_OTHER")
printf '%s' "$SP_OTHER_PAYLOAD" | PATH="$SP_BIN:$PATH" HOME="$SP_HOME" bash "$ROOT/hooks/session-start.sh" --cli cursor --format env >/dev/null
SP_OWN_A=$(sed -n '1p' "$SP_HOME/.rolepod/session-profiles/cursor/fixed-session.mode")
SP_OWN_B=$(sed -n '1p' "$SP_HOME/.rolepod/session-profiles/cursor/other-session.mode")
if [ "$SP_OWN_A" = full ] && [ "$SP_OWN_B" = lite ]; then ok "session profile: parallel session IDs retain independent modes"; else bad "session profile parallel isolation ($SP_OWN_A / $SP_OWN_B)"; fi

# A selected non-Standard mode is valid only if the startup profile can be
# consumed later. Store failure or a missing/unsafe native ID must produce the
# same explicit Lite/uncaptured profile in startup output and hook reads.
SP_FAIL_HOME="$TMP/session-store-fail"; SP_FAIL_PROJECT="$TMP/session-store-project"
mkdir -p "$SP_FAIL_HOME/.rolepod" "$SP_FAIL_PROJECT/.rolepod"
printf 'blocked\n' > "$SP_FAIL_HOME/.rolepod/session-profiles"
printf '{"workflow":{"mode":"lite"}}' > "$SP_FAIL_PROJECT/.rolepod/config.json"
SP_FAIL_PAYLOAD=$(printf '{"session_id":"safe-session","cwd":"%s","source":"startup"}' "$SP_FAIL_PROJECT")
SP_FAIL_ENV=$(printf '%s' "$SP_FAIL_PAYLOAD" | HOME="$SP_FAIL_HOME" bash "$ROOT/hooks/session-start.sh" --cli cursor --format env)
SP_FAIL_HOOK=$(printf '%s' "$SP_FAIL_PAYLOAD" | HOME="$SP_FAIL_HOME" ROLEPOD_SESSION_CLI=cursor bash -c '. "$1/hooks/lib/session-mode.sh"; rolepod_session_profile_load "$(cat)" cursor; printf "%s %s" "$ROLEPOD_SESSION_MODE" "$ROLEPOD_SESSION_SOURCE"' _ "$ROOT")
printf '%s' "$SP_FAIL_ENV" | grep -q '"ROLEPOD_SESSION_MODE": "lite"' && printf '%s' "$SP_FAIL_ENV" | grep -q '"ROLEPOD_SESSION_SOURCE": "uncaptured"' && [ "$SP_FAIL_HOOK" = 'lite uncaptured' ] \
  && ok "session profile: failed snapshot store reports Lite/uncaptured to startup and hooks" || bad "session profile store failure split ($SP_FAIL_ENV / $SP_FAIL_HOOK)"
SP_UNSAFE_HOME="$TMP/session-unsafe-home"; mkdir -p "$SP_UNSAFE_HOME" "$SP_FAIL_PROJECT/.rolepod"
printf '{"workflow":{"mode":"full"}}' > "$SP_FAIL_PROJECT/.rolepod/config.json"
SP_UNSAFE_PAYLOAD=$(printf '{"session_id":"../unsafe","cwd":"%s","source":"startup"}' "$SP_FAIL_PROJECT")
SP_UNSAFE_ENV=$(printf '%s' "$SP_UNSAFE_PAYLOAD" | HOME="$SP_UNSAFE_HOME" bash "$ROOT/hooks/session-start.sh" --cli cursor --format env)
SP_UNSAFE_HOOK=$(printf '%s' "$SP_UNSAFE_PAYLOAD" | HOME="$SP_UNSAFE_HOME" ROLEPOD_SESSION_CLI=cursor bash -c '. "$1/hooks/lib/session-mode.sh"; rolepod_session_profile_load "$(cat)" cursor; printf "%s %s" "$ROLEPOD_SESSION_MODE" "$ROLEPOD_SESSION_SOURCE"' _ "$ROOT")
printf '%s' "$SP_UNSAFE_ENV" | grep -q '"ROLEPOD_SESSION_MODE": "lite"' && printf '%s' "$SP_UNSAFE_ENV" | grep -q '"ROLEPOD_SESSION_SOURCE": "uncaptured"' && [ "$SP_UNSAFE_HOOK" = 'lite uncaptured' ] \
  && ok "session profile: missing safe session ID reports Lite/uncaptured consistently" || bad "session profile unsafe ID split ($SP_UNSAFE_ENV / $SP_UNSAFE_HOOK)"

[ "$fail" = 0 ] || { echo "FAIL: $fail"; exit 1; }
echo "rolepod-config: all passed"
