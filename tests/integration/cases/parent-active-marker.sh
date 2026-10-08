#!/bin/bash
# parent-active-marker — combined mode is cross-CLI (v2.14.1): every CLI's
# session-start surface writes <git-root>/.rolepod/parent-active so child
# plugins (uiproof / wplab / dblab) pick with-rolepod mode. Locks the write
# in every adapter + proves session-lifecycle.sh --lock's write functionally
# (v2.180.4: the root loader writes no lock/marker of its own any more).
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_DIR"

# Lock and parent-marker lifecycle run the same in every mode (Lite included);
# the whole file runs under Lite, the profile with the fewest gates.
export ROLEPOD_SESSION_MODE=lite ROLEPOD_SESSION_SOURCE=global

fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1"; fail=1
  fi
}
cleanup() { rm -rf "${FIX:-}" "${CDX:-}" "${S2:-}" "${SIB:-}" "${JNK:-}" "${CLI:-}" "${WG:-}"; }
trap cleanup EXIT

# Decode a hook's SessionStart JSON so a check reads the literal text the
# host would see (ensure_ascii is back to the json default — the raw stdout
# carries ×, not ×; MAJOR review round 2).
decode_ctx() { python3 -c 'import json,sys
try: print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception: print("")'; }

# Static: agy has no behavior case of its own here (its own antigravity-adapter
# case covers its hooks elsewhere) so its marker write stays a string pin;
# every other CLI's write is proven by its own behavior case.
check "antigravity session-start writes marker" "grep -q 'parent-active' adapters/antigravity/hooks/session-start.sh"

# Functional: session-lifecycle.sh --lock is the sole owner of the marker
# write (v2.180.4 — the loader used to write it too on the CLAUDE_PROJECT_DIR-
# empty path, which double-owned it on Codex where both hooks run at
# SessionStart; see the regression case below).
FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-marker.XXXXXX")"
git -C "$FIX" init -q
git -C "$FIX" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
( cd "$FIX" && unset CLAUDE_PROJECT_DIR && printf '{"session_id":"s1","cwd":"%s"}' "$FIX" \
  | HOME="$FIX/home" bash "$REPO_DIR/hooks/session-lifecycle.sh" --lock >/dev/null 2>&1 ) || true
check "lifecycle --lock creates .rolepod/parent-active" "[ -f '$FIX/.rolepod/parent-active' ]"
check "marker carries protocol version v1"              "grep -qx 'v1' '$FIX/.rolepod/parent-active'"

# Regression (v2.180.4): on Codex, SessionStart fires the loader AND
# session-lifecycle.sh --lock for the SAME session, both with CLAUDE_PROJECT_DIR
# unset. Before the fix, the loader's own concurrent-session branch wrote an
# `auto-$PPID.lock` that session-lifecycle then counted as a sibling (a false
# "concurrent session" warning either order), and it was never cleaned by
# --unlock (which only removes `<session_id>.lock`). After the fix the loader
# is context-only: no auto-*.lock, no sibling warning, and --unlock leaves a
# clean lock dir + marker kept (v2.180.5: Stop fires per turn).
CDX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-marker-codex.XXXXXX")"
git -C "$CDX" init -q
git -C "$CDX" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
PAYLOAD=$(printf '{"session_id":"s1","cwd":"%s","hook_event_name":"SessionStart"}' "$CDX")
( cd "$CDX" && unset CLAUDE_PROJECT_DIR
  printf '%s' "$PAYLOAD" | HOME="$CDX/home" bash "$REPO_DIR/hooks/project-context-loader.sh" >/dev/null 2>&1
  LIFECYCLE_OUT=$(printf '%s' "$PAYLOAD" | HOME="$CDX/home" bash "$REPO_DIR/hooks/session-lifecycle.sh" --lock 2>&1)
  printf '%s' "$LIFECYCLE_OUT" > "$CDX/lifecycle-lock.out"
) || true
_CDX_REAL=$(git -C "$CDX" rev-parse --show-toplevel)
_h=$(printf '%s' "$_CDX_REAL" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
_ld="$CDX/home/.rolepod/session-locks/$_h"
check "no sibling warning when loader + lifecycle --lock run on the same Codex payload" \
  "! grep -q 'Sibling' '$CDX/lifecycle-lock.out'"
check "lock dir has only s1.lock, no auto-*.lock" \
  "[ -f '$_ld/s1.lock' ] && [ \$(ls '$_ld'/auto-*.lock 2>/dev/null | wc -l) -eq 0 ]"
( cd "$CDX" && printf '%s' "$PAYLOAD" | HOME="$CDX/home" bash "$REPO_DIR/hooks/session-lifecycle.sh" --unlock >/dev/null 2>&1 ) || true
check "unlock leaves no .lock files"        "[ \$(find '$_ld' -maxdepth 1 -name '*.lock' 2>/dev/null | wc -l) -eq 0 ]"
check "unlock keeps .rolepod/parent-active" "[ -f '$CDX/.rolepod/parent-active' ]"

# Nearest input that must stay the same: a REAL second session lock still
# warns.
S2="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-marker-s2.XXXXXX")"
git -C "$S2" init -q
git -C "$S2" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
( cd "$S2" && printf '{"session_id":"s1","cwd":"%s"}' "$S2" | HOME="$S2/home" bash "$REPO_DIR/hooks/session-lifecycle.sh" --lock >/dev/null 2>&1 ) || true
OUT2=$( cd "$S2" && printf '{"session_id":"s2","cwd":"%s"}' "$S2" | HOME="$S2/home" bash "$REPO_DIR/hooks/session-lifecycle.sh" --lock 2>&1 ) || true
check "a real second session lock still produces the sibling warning" "printf '%s' \"\$OUT2\" | grep -q 'Sibling'"
check "override env still silences the warning" \
  "! ( cd '$S2' && printf '{\"session_id\":\"s3\",\"cwd\":\"%s\"}' '$S2' | HOME='$S2/home' ROLEPOD_ALLOW_SHARED_WORKTREE=1 bash '$REPO_DIR/hooks/session-lifecycle.sh' --lock 2>&1 | grep -q 'Sibling' )"

# Per-CLI breakdown: a lock's content names the CLI that wrote it; an empty
# lock (written by an older version) reads as "unknown".
SIB="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-marker-sib.XXXXXX")"
git -C "$SIB" init -q
git -C "$SIB" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
_SIB_REAL=$(git -C "$SIB" rev-parse --show-toplevel)
_sh=$(printf '%s' "$_SIB_REAL" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
_sld="$SIB/home/.rolepod/session-locks/$_sh"
mkdir -p "$_sld"
printf 'opencode' > "$_sld/oc1.lock"
printf 'codex\n4242' > "$_sld/cx1.lock"   # a two-line lock: the name is line 1, line 2 is the CLI pid
: > "$_sld/empty1.lock"
OUT3=$( cd "$SIB" && printf '{"session_id":"c1","cwd":"%s"}' "$SIB" | HOME="$SIB/home" bash "$REPO_DIR/hooks/session-lifecycle.sh" --lock 2>&1 | decode_ctx )
check "sibling warning breaks down by CLI: an opencode lock reads its name" "printf '%s' \"\$OUT3\" | grep -q 'opencode ×1'"
check "sibling warning breaks down by CLI: a two-line lock (name + pid) reads its name" "printf '%s' \"\$OUT3\" | grep -q 'codex ×1'"
check "sibling warning breaks down by CLI: an empty (older-version) lock reads as unknown" "printf '%s' \"\$OUT3\" | grep -q 'unknown ×1'"

# One lock-name rule (MAJOR, review round 2): junk content (not [a-z0-9_-]+
# after stripping one trailing newline) reads as "unknown", same as empty.
JNK="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-marker-jnk.XXXXXX")"
git -C "$JNK" init -q
git -C "$JNK" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
_JNK_REAL=$(git -C "$JNK" rev-parse --show-toplevel)
_jh=$(printf '%s' "$_JNK_REAL" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
_jld="$JNK/home/.rolepod/session-locks/$_jh"
mkdir -p "$_jld"
printf 'a b"c' > "$_jld/junk1.lock"
OUT4=$( cd "$JNK" && printf '{"session_id":"c1","cwd":"%s"}' "$JNK" | HOME="$JNK/home" bash "$REPO_DIR/hooks/session-lifecycle.sh" --lock 2>&1 | decode_ctx )
check "sibling warning: a lock with junk content reads as unknown" "printf '%s' \"\$OUT4\" | grep -q 'unknown ×1'"

# --cli codex writes the lock's content as "codex" (MINOR default fix: no
# --cli now reads "unknown", not "claude" — covered by the writer checks
# above needing no --cli at all).
CLI="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-marker-cli.XXXXXX")"
git -C "$CLI" init -q
( cd "$CLI" && printf '{"session_id":"cdx1","cwd":"%s"}' "$CLI" | HOME="$CLI/home" bash "$REPO_DIR/hooks/session-lifecycle.sh" --lock --cli codex >/dev/null 2>&1 ) || true
_CLI_REAL=$(git -C "$CLI" rev-parse --show-toplevel)
_ch=$(printf '%s' "$_CLI_REAL" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
check "--cli codex writes the lock's content as codex" "[ \"\$(head -n 1 '$CLI/home/.rolepod/session-locks/$_ch/cdx1.lock' 2>/dev/null)\" = codex ]"

# worktree-guard (MAJOR, review round 2): a missing lock (this session's Stop
# already deleted it this turn) is recreated with THIS CLI's name, not an
# empty touch — worktree-guard runs on Claude only.
WG="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-marker-wg.XXXXXX")"
git -C "$WG" init -q
: > "$WG/foo.txt"
( cd "$WG" && printf '{"tool_name":"Edit","session_id":"wg1","cwd":"%s","tool_input":{"file_path":"%s/foo.txt"}}' "$WG" "$WG" \
  | HOME="$WG/home" bash "$REPO_DIR/hooks/worktree-guard.sh" >/dev/null 2>&1 ) || true
_WG_REAL=$(git -C "$WG" rev-parse --show-toplevel)
_wh=$(printf '%s' "$_WG_REAL" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | awk '{print $1}' | head -c 16)
check "worktree-guard on a missing lock writes claude + a numeric pid line" "[ \"\$(sed -n 1p '$WG/home/.rolepod/session-locks/$_wh/wg1.lock' 2>/dev/null)\" = claude ] && sed -n 2p '$WG/home/.rolepod/session-locks/$_wh/wg1.lock' | grep -qE '^[0-9]+\$'"

exit $fail
