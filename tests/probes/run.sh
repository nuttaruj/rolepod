#!/usr/bin/env bash
# tests/probes/run.sh — a one-turn probe of a rendered skill on a cheap model.
#
# Not a harness and never part of `make test`: one probe costs ~25k tokens
# (the skill text is inlined). Run it by hand after editing an exit / branch
# line of a skill, read the answer, compare with the case's expect / forbid
# lines. A wrong STOP / CONTINUE is a text defect to fix in the skill.
#
#   tests/probes/run.sh <case-id|all>        cases live in tests/probes/cases/
#   tests/probes/run.sh --dry-run <case-id>  print the prompt, call nothing
#   PROBE_CMD='codex exec -m <model>' …      any headless CLI reading stdin
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
usage() { echo "usage: tests/probes/run.sh [--dry-run] <case-id|all>   (PROBE_CMD overrides 'claude -p --model haiku')" >&2; exit 2; }
dry=0; [ "${1:-}" = "--dry-run" ] && { dry=1; shift; }
[ $# -eq 1 ] || usage
if [ "$1" = all ]; then cases=(tests/probes/cases/*.md); else cases=("tests/probes/cases/$1.md"); fi
cmd="${PROBE_CMD:-claude -p --model haiku}"
fail=0
for c in "${cases[@]}"; do
  [ -f "$c" ] || { echo "no such case: $c" >&2; exit 2; }
  skill=$(sed -n 's/^skill: *//p' "$c" | head -1)
  path="plugins/rolepod-codex/skills/$skill/SKILL.md"   # the standalone-rendered copy, includes expanded
  [ -f "$path" ] || { echo "missing rendered skill: $path (run make render)" >&2; exit 2; }
  prompt=$( { sed '1,/^---$/d' "$c"; printf '\n--- SKILL (%s) ---\n' "$path"; cat "$path"; } )
  if [ $dry -eq 1 ]; then printf '%s\n' "$prompt"; continue; fi
  echo "── $(basename "$c" .md) → $skill"
  if ! answer=$(printf '%s' "$prompt" | $cmd); then echo "  ✗ probe command failed: $cmd"; fail=$((fail+1)); continue; fi
  printf '%s\n' "$answer" | sed 's/^/  │ /'
  while IFS= read -r rx; do
    [ -n "$rx" ] || continue
    if grep -Eq "$rx" <<<"$answer"; then echo "  ✓ expect: $rx"; else echo "  ✗ expect: $rx"; fail=$((fail+1)); fi
  done < <(sed -n 's/^expect: *//p' "$c")
  while IFS= read -r rx; do
    [ -n "$rx" ] || continue
    if grep -Eq "$rx" <<<"$answer"; then echo "  ✗ forbid: $rx"; fail=$((fail+1)); else echo "  ✓ forbid absent: $rx"; fi
  done < <(sed -n 's/^forbid: *//p' "$c")
done
[ $dry -eq 1 ] && exit 0
echo; [ $fail -eq 0 ] && { echo "probes: pass"; exit 0; }
echo "probes: $fail failure(s)"; exit 1
