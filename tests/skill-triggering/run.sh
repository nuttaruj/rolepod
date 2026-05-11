#!/usr/bin/env bash
# rolepod skill-triggering harness — TDD for skills.
#
# For each tests/skill-triggering/cases/*.yml file, runs the prompt through
# `claude --print` (non-interactive, no skill preload) and asserts that the
# expected skill name appears in the output.
#
# Exit codes:
#   0 — all cases pass (or all skipped due to missing CLI)
#   1 — at least one case failed
#   2 — runner error (malformed case file, missing required field)

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASES_DIR="$ROOT/cases"
TMPDIR_RUN="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_RUN"' EXIT

pass=0
fail=0
skip=0
total=0

# Detect CLI availability. Missing CLI is not a runner error — the harness
# is designed to skip cleanly so CI runners without `claude` installed
# don't block the pipeline.
if ! command -v claude >/dev/null 2>&1; then
  echo "[skill-triggering] 'claude' CLI not on PATH — skipping all cases."
  echo "[skill-triggering] (Install Claude Code CLI to run this harness locally.)"
  exit 0
fi

# Minimal YAML field extractor — no external deps. Handles:
#   key: value
#   key: |
#     multi
#     line
# Does NOT handle nested maps, lists, or quoted values with colons.
extract_field() {
  local file="$1"
  local key="$2"
  python3 - "$file" "$key" <<'PY'
import sys, re
path, key = sys.argv[1], sys.argv[2]
with open(path) as f:
    lines = f.readlines()
i = 0
while i < len(lines):
    line = lines[i].rstrip("\n")
    m = re.match(rf"^{re.escape(key)}:\s*(.*)$", line)
    if m:
        val = m.group(1)
        if val == "|" or val == ">":
            i += 1
            buf = []
            while i < len(lines):
                nxt = lines[i].rstrip("\n")
                if nxt and not nxt.startswith(" ") and not nxt.startswith("\t"):
                    break
                buf.append(nxt.lstrip())
                i += 1
            print("\n".join(buf).rstrip())
            sys.exit(0)
        print(val.strip().strip('"').strip("'"))
        sys.exit(0)
    i += 1
sys.exit(0)
PY
}

if [ ! -d "$CASES_DIR" ]; then
  echo "[skill-triggering] no cases dir at $CASES_DIR" >&2
  exit 2
fi

shopt -s nullglob
cases=( "$CASES_DIR"/*.yml )
shopt -u nullglob

if [ "${#cases[@]}" -eq 0 ]; then
  echo "[skill-triggering] no cases found in $CASES_DIR"
  exit 0
fi

for case_file in "${cases[@]}"; do
  total=$((total + 1))
  name="$(extract_field "$case_file" name)"
  skill="$(extract_field "$case_file" skill)"
  prompt="$(extract_field "$case_file" prompt)"
  must_not_skip="$(extract_field "$case_file" must_not_skip_excuse)"

  if [ -z "$name" ] || [ -z "$skill" ] || [ -z "$prompt" ]; then
    echo "::error file=$case_file::missing required field (name/skill/prompt)"
    fail=$((fail + 1))
    continue
  fi

  out_file="$TMPDIR_RUN/$name.out"

  # Run the prompt through claude --print. Append-only options to keep the
  # invocation stable across CLI versions; if the user has a newer flag set,
  # they can override via CLAUDE_FLAGS.
  flags="${CLAUDE_FLAGS:---print}"
  if ! printf '%s\n' "$prompt" | claude $flags > "$out_file" 2>&1; then
    echo "FAIL [$name] claude CLI errored"
    fail=$((fail + 1))
    continue
  fi

  # Assertion 1: skill name appears in output
  if ! grep -qiF -- "$skill" "$out_file"; then
    echo "FAIL [$name] skill '$skill' not mentioned in output"
    fail=$((fail + 1))
    continue
  fi

  # Assertion 2: must-not-skip-excuse text does not appear verbatim
  # (only checked if a non-empty excuse was provided)
  if [ -n "$must_not_skip" ]; then
    if grep -qiF -- "$must_not_skip" "$out_file"; then
      echo "FAIL [$name] output parrots skip excuse: $must_not_skip"
      fail=$((fail + 1))
      continue
    fi
  fi

  echo "PASS [$name] skill='$skill'"
  pass=$((pass + 1))
done

echo ""
echo "[skill-triggering] total=$total pass=$pass fail=$fail skip=$skip"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
