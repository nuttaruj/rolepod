#!/usr/bin/env bash
# tests/probes/repeat.sh — run each probe case N times in parallel, print a pass table.
#
#   tests/probes/repeat.sh <runs> <id>...
#     <id> = a case file name without .md, or its prefix before the first "-"
#            (R09b -> R09b-role-listing.md, C12 -> C12-r4-standard.md); exactly one match, else exit 2
#   PROBE_JOBS (default 4) runs in parallel; PROBE_CMD and PROBE_REV pass through to run.sh;
#   PROBE_LOG_DIR (default mktemp -d) keeps one log per run: <id>.r<k>.log; the log dir is printed on stderr
#   stdout: header "id case pass runs cmdfail detail", then one TSV row per id; a run passes when
#   run.sh exits 0; cmdfail = runs whose log holds "probe command failed" or whose run.sh exit is >= 2
#   (missing render, bad PROBE_REV, no .rc); detail = per run
#   "<✓ lines>/<expect + forbid lines>", comma-joined
#   exit 0 when every run produced an answer (cmdfail 0 for all ids), 1 otherwise, 2 on usage or an unknown id;
#   expect / forbid results are data, never the exit code
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
usage() { echo "usage: tests/probes/repeat.sh <runs> <id>..." >&2; exit 2; }
[ $# -ge 2 ] || usage
runs=$1; shift
case "$runs" in ''|*[!0-9]*|0) usage ;; esac
dir="${PROBE_LOG_DIR:-$(mktemp -d)}"; mkdir -p "$dir"
echo "probe logs: $dir" >&2
jobs_n="${PROBE_JOBS:-4}"

ids=(); names=()
for id in "$@"; do
  m=()
  for f in tests/probes/cases/*.md; do
    n=$(basename "$f" .md)
    if [ "$n" = "$id" ] || [ "${n%%-*}" = "$id" ]; then m+=("$n"); fi
  done
  [ ${#m[@]} -eq 1 ] || { echo "case id '$id': ${#m[@]} matches (want exactly 1)" >&2; exit 2; }
  ids+=("$id"); names+=("${m[0]}")
done

# one job per (case, run); run.sh exit code goes to <log>.rc
i=0
for n in "${names[@]}"; do
  k=1
  while [ "$k" -le "$runs" ]; do
    printf '%s %s %s\n' "$n" "$k" "${ids[$i]}"
    k=$((k+1))
  done
  i=$((i+1))
done | xargs -P "$jobs_n" -L 1 bash -c '
  n=$1; k=$2; id=$3; log="$0/$id.r$k.log"
  bash tests/probes/run.sh "$n" > "$log" 2>&1; echo $? > "$log.rc"
' "$dir"

printf 'id\tcase\tpass\truns\tcmdfail\tdetail\n'
bad=0; i=0
for n in "${names[@]}"; do
  id=${ids[$i]}; i=$((i+1))
  pass=0; cf=0; detail=""
  k=1
  while [ "$k" -le "$runs" ]; do
    log="$dir/$id.r$k.log"
    rc=$(cat "$log.rc" 2>/dev/null || echo 2)
    [ "$rc" = 0 ] && pass=$((pass+1))
    # no answer: the model command failed, or run.sh itself exited 2 (missing render, bad PROBE_REV) / left no .rc
    if [ "$rc" -ge 2 ] || /usr/bin/grep -q 'probe command failed' "$log"; then cf=$((cf+1)); fi
    ok=$(/usr/bin/grep -c '^  ✓ ' "$log" || true)
    tot=$(/usr/bin/grep -Ec '^  (✓|✗) (expect|forbid)' "$log" || true)
    detail="${detail:+$detail,}$ok/$tot"
    k=$((k+1))
  done
  [ "$cf" -eq 0 ] || bad=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$n" "$pass" "$runs" "$cf" "$detail"
done
exit $bad
