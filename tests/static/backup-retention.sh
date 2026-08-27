#!/bin/bash
# Behavioral test — install.sh backup retention (v2.67.0).
#
# Gap (real case 2026-08-27): install.sh stamped a new backup on every
# --force run and never pruned. A machine that reinstalled daily for three
# weeks held 122 backup dirs + 31 stamped config copies = 457MB.
#
# prune_backups() must keep exactly the N newest entries matching a prefix,
# delete the rest, leave non-matching siblings alone, count both dirs and
# files, and write nothing under --dry-run.
#
# Extracts the real function from install.sh — no fixture copy to drift.
# Wired into `make test-static`.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

fail=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Extract prune_backups + the helpers it calls, so the test exercises the
# shipped implementation rather than a copy.
{
  echo 'DRY_RUN=${DRY_RUN:-0}'
  sed -n '/^BACKUP_KEEP=/p' "$REPO_DIR/install.sh"
  echo 'dry()  { echo "DRY: $*"; }'
  echo 'warn() { echo "WARN: $*"; }'
  sed -n '/^prune_backups() {/,/^}/p' "$REPO_DIR/install.sh"
} > "$tmp/lib.sh"

grep -q '^prune_backups() {' "$tmp/lib.sh" || {
  echo "  ✗ prune_backups not found in install.sh"; exit 1; }
grep -q '^BACKUP_KEEP=3$' "$tmp/lib.sh" || {
  echo "  ✗ BACKUP_KEEP=3 constant missing from install.sh"; fail=$((fail+1)); }

# remaining <dir> <prefix> → matching entry names, newest first
remaining() { find "$1" -maxdepth 1 -mindepth 1 -name "$2*" | sed "s|^$1/||" | sort -r | tr '\n' ' '; }

echo "── dirs: keeps exactly 3 newest ──"
D="$tmp/backups/claude"; mkdir -p "$D"
for st in 20260801-090000 20260802-090000 20260803-090000 20260804-090000 20260805-090000; do
  mkdir -p "$D/rolepod-$st"; done
mkdir -p "$D/keep-me-unrelated"
OUT=$(bash -c "source '$tmp/lib.sh'; prune_backups '$D/rolepod-'" 2>&1)
GOT=$(remaining "$D" "rolepod-")
WANT="rolepod-20260805-090000 rolepod-20260804-090000 rolepod-20260803-090000 "
if [ "$GOT" = "$WANT" ]; then echo "  ✓ 5 dirs → 3 newest kept"
else echo "  ✗ expected [$WANT] got [$GOT]"; fail=$((fail+1)); fi

if [ -d "$D/keep-me-unrelated" ]; then echo "  ✓ non-matching sibling untouched"
else echo "  ✗ pruned a non-matching sibling"; fail=$((fail+1)); fi

echo "$OUT" | grep -q "WARN: Pruned 2 " && echo "  ✓ reports the exact count pruned" || {
  echo "  ✗ count not reported: $OUT"; fail=$((fail+1)); }

echo ""
echo "── files: stamped config copies ──"
C="$tmp/codex"; mkdir -p "$C"; : > "$C/config.toml"
for st in 20260801-090000 20260802-090000 20260803-090000 20260804-090000 20260805-090000; do
  : > "$C/config.toml.rolepod-bak.$st"; done
bash -c "source '$tmp/lib.sh'; prune_backups '$C/config.toml.rolepod-bak.'" >/dev/null 2>&1
GOT=$(remaining "$C" "config.toml.rolepod-bak.")
WANT="config.toml.rolepod-bak.20260805-090000 config.toml.rolepod-bak.20260804-090000 config.toml.rolepod-bak.20260803-090000 "
if [ "$GOT" = "$WANT" ]; then echo "  ✓ 5 config copies → 3 newest kept"
else echo "  ✗ expected [$WANT] got [$GOT]"; fail=$((fail+1)); fi

if [ -f "$C/config.toml" ]; then echo "  ✓ live config.toml never matched by the prefix"
else echo "  ✗ prune deleted the live config.toml"; fail=$((fail+1)); fi

echo ""
echo "── dry-run writes nothing ──"
E="$tmp/dryrun"; mkdir -p "$E"
for st in 20260801-090000 20260802-090000 20260803-090000 20260804-090000 20260805-090000; do
  mkdir -p "$E/rolepod-$st"; done
OUT=$(bash -c "DRY_RUN=1; source '$tmp/lib.sh'; prune_backups '$E/rolepod-'" 2>&1)
N=$(find "$E" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
if [ "$N" -eq 5 ]; then echo "  ✓ dry-run deleted 0 of 5"
else echo "  ✗ dry-run deleted $((5 - N))"; fail=$((fail+1)); fi
echo "$OUT" | grep -q "^DRY: prune 2 " && echo "  ✓ dry-run previews the prune" || {
  echo "  ✗ dry-run silent about pruning: $OUT"; fail=$((fail+1)); }

echo ""
echo "── below threshold is a no-op ──"
F="$tmp/few"; mkdir -p "$F"
mkdir -p "$F/rolepod-20260801-090000" "$F/rolepod-20260802-090000"
OUT=$(bash -c "source '$tmp/lib.sh'; prune_backups '$F/rolepod-'" 2>&1)
N=$(find "$F" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
if [ "$N" -eq 2 ] && [ -z "$OUT" ]; then echo "  ✓ 2 entries, keep 3 → silent no-op"
else echo "  ✗ n=$N out=$OUT"; fail=$((fail+1)); fi

echo ""
echo "── missing parent is a no-op ──"
OUT=$(bash -c "source '$tmp/lib.sh'; prune_backups '$tmp/nope/rolepod-'" 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ -z "$OUT" ]; then echo "  ✓ absent directory → rc=0, silent"
else echo "  ✗ rc=$RC out=$OUT"; fail=$((fail+1)); fi

echo ""
echo "── every backup site prunes ──"
# claude/codex/gemini go through selective_backup; cursor has its own branch;
# both codex config.toml copies are stamped separately. A site added later
# without a prune call is the exact regression this guards.
SITES=$(grep -c 'prune_backups "' "$REPO_DIR/install.sh")
if [ "$SITES" -ge 5 ]; then echo "  ✓ $SITES prune call sites wired"
else echo "  ✗ only $SITES prune call sites (expected >= 5)"; fail=$((fail+1)); fi
for anchor in 'prune_backups "$(dirname "$backup")/rolepod-"' \
              'prune_backups "$(dirname "$BACKUP")/rolepod-"' \
              'prune_backups "$CODEX_CONFIG.rolepod-bak."' \
              'prune_backups "$X_CONFIG.rolepod-bak."'; do
  grep -qF "$anchor" "$REPO_DIR/install.sh" && echo "  ✓ site: $anchor" || {
    echo "  ✗ missing site: $anchor"; fail=$((fail+1)); }
done

echo ""
if [ $fail -eq 0 ]; then
  echo "backup-retention: pass"
  exit 0
fi
echo "backup-retention: $fail failure(s)"
exit 1
