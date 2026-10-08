#!/bin/bash
# bootstrap — functional coverage for the curl|bash front door (bootstrap.sh),
# which until v2.43.0 had only `bash -n` anywhere in the suite.
#
# Hermetic by construction: a local `git init` fixture repo carrying a STUB
# install.sh that records "$@", pre-cloned into the DEST candidates so
# bootstrap takes the reuse path (fetch/pull from the clone's own origin —
# no network, no ROLEPOD_REPO_URL override needed). Never clone the CI
# workspace itself: actions/checkout@v4 on pull_request is a detached HEAD
# with no local `main`, so a fixture cloned from it makes
# `git fetch origin main` fail rc=128 — red on every PR, green locally.
#
# Pinned invariants:
#   (a) explicit $ROLEPOD_DEST wins DEST resolution and install.sh runs there
#   (b) an existing $HOME/rolepod/.git clone is REUSED (fetch/pull, no re-clone)
#   (c) destructive-branch guard: on (a) and (b) CLEANUP_DEST stays empty —
#       the user-owned directory must survive the run (a regression here
#       rm -rf's a user directory)
#   (d) the defensive default --target=claude reaches install.sh when the
#       caller passes no target
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

fail=0
check() { if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=$((fail+1)); fi; }

FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-bootstrap.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

# ── Fixture: source repo with a stub install.sh on branch main ──────────
SRC="$FIX/src"
mkdir -p "$SRC"
git -C "$SRC" init -q -b main
git -C "$SRC" config user.email t@t
git -C "$SRC" config user.name t
cat > "$SRC/install.sh" <<'EOF'
#!/bin/bash
# stub — records the args bootstrap forwarded, writes nothing else
printf '%s\n' "$@" > .args-recorded
echo "stub install ok"
EOF
chmod +x "$SRC/install.sh"
git -C "$SRC" add -A
git -C "$SRC" commit -qm fixture

# ── (a) explicit ROLEPOD_DEST wins + (c) survives + (d) default target ──
DEST_A="$FIX/dest-a"
git clone -q "$SRC" "$DEST_A"
HOME_A="$FIX/home-a"; mkdir -p "$HOME_A"
if HOME="$HOME_A" ROLEPOD_DEST="$DEST_A" bash "$REPO_DIR/bootstrap.sh" </dev/null >"$FIX/a.log" 2>&1; then
  check "explicit ROLEPOD_DEST: bootstrap exits 0"       "true"
else
  check "explicit ROLEPOD_DEST: bootstrap exits 0"       "false"
fi
check "explicit ROLEPOD_DEST: install.sh ran there"      "[ -f '$DEST_A/.args-recorded' ]"
check "default --target=claude forwarded"                "grep -qx -- '--target=claude' '$DEST_A/.args-recorded'"
check "explicit ROLEPOD_DEST survives the run (no rm -rf)" "[ -d '$DEST_A/.git' ]"

# ── (b) existing $HOME/rolepod reused via fetch/pull + (c) survives ─────
HOME_B="$FIX/home-b"; mkdir -p "$HOME_B"
git clone -q "$SRC" "$HOME_B/rolepod"
# Advance the source so a REUSE (fetch/pull) is observable vs a re-clone.
echo "v2" >> "$SRC/marker.txt"
git -C "$SRC" add -A && git -C "$SRC" commit -qm v2
if HOME="$HOME_B" bash "$REPO_DIR/bootstrap.sh" </dev/null >"$FIX/b.log" 2>&1; then
  check "HOME/rolepod reuse: bootstrap exits 0"          "true"
else
  check "HOME/rolepod reuse: bootstrap exits 0"          "false"
fi
check "HOME/rolepod reuse: install.sh ran there"         "[ -f '$HOME_B/rolepod/.args-recorded' ]"
check "HOME/rolepod reuse: pulled latest (fetch, not re-clone)" "[ -f '$HOME_B/rolepod/marker.txt' ]"
check "HOME/rolepod survives the run (no rm -rf)"        "[ -d '$HOME_B/rolepod/.git' ]"

exit $fail
