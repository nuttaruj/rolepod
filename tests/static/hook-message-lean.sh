#!/bin/bash
# Static test — hook messages stay lean (v2.92.0).
#
# A gate message is read by the Lead at the moment a tool call is denied or
# nudged. It has three jobs: state the fact of THIS call, say the fix, name
# the exception. Anything else — measured history, doctrine explanation,
# persuasion — costs tokens on every fire and buys nothing: the model cannot
# bypass a deny (bypass envs are user-set), so it never needed convincing.
# Real case: the fleet-tier no-tier deny ran 894 chars (223 tok) with a
# "measured: one project burned 5,196 agent turns…" clause; rewritten to
# 339 chars with the same decision surface.
#
# Guards: (1) no rationale vocabulary in message text (comments may keep
# it — that is where the why belongs); (2) no single message literal run
# above the cap, so a message cannot regrow one clause at a time.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"
fail=0
CAP=600

# 1. rationale words outside comments
HITS=$(grep -nE 'measured:|observed:|burned [0-9]|≈ ?[0-9.]+M tokens|shipped money bugs' hooks/*.sh \
       | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
if [ -z "$HITS" ]; then
  echo "  ✓ no measured/observed/burned rationale inside hook message text"
else
  echo "  ✗ rationale vocabulary in message text (move it to a comment or docs/hooks.md):"
  printf '%s\n' "$HITS" | cut -c1-140 | sed 's/^/      /'
  fail=$((fail+1))
fi

# 2. message literal runs ≤ CAP chars. The scanner lives in a temp file — a
#    heredoc inside $( ) trips bash on the regex parens.
SCAN="$(mktemp)"; trap 'rm -f "$SCAN"' EXIT
cat > "$SCAN" <<'PY'
import re, sys
cap = int(sys.argv[1]); bad = []; longest = [0, ""]
for f in sys.argv[2:]:
    src = open(f).read()
    buf = []
    def flush():
        j = "".join(buf)
        if j:
            if len(j) > longest[0]: longest[0], longest[1] = len(j), f
            if len(j) > cap: bad.append((f, len(j), j[:60]))
        del buf[:]
    lit = re.compile(r'^(?:[A-Za-z_]+ = \(|ctx\([^"]*|print\(|\'[A-Za-z]+\': \()?\s*"((?:[^"\\]|\\.)*)"\s*[\\,)%]?.*$')
    for line in src.splitlines():
        s = line.strip()
        if s.startswith("#"):
            flush(); continue
        m = lit.match(s)
        if m and '"' in s:
            buf.append(m.group(1)); continue
        flush()
    flush()
    for m in re.finditer(r'^\s*[A-Z_]+\+?="((?:[^"\\]|\\.)*)"', src, re.M):
        j = m.group(1)
        if len(j) > longest[0]: longest[0], longest[1] = len(j), f
        if len(j) > cap: bad.append((f, len(j), j[:60]))
for f, n, head in bad:
    print("BAD %s %d %s" % (f, n, head))
print("LONGEST %d %s" % (longest[0], longest[1]))
PY
OUT=$(python3 "$SCAN" "$CAP" hooks/*.sh)
BAD=$(printf '%s\n' "$OUT" | grep '^BAD ' || true)
LONGEST=$(printf '%s\n' "$OUT" | grep '^LONGEST ' | cut -d' ' -f2-)
if [ -z "$BAD" ]; then
  echo "  ✓ every hook message literal ≤ $CAP chars (longest: $LONGEST)"
else
  echo "  ✗ message literal(s) over $CAP chars:"
  printf '%s\n' "$BAD" | sed 's/^BAD /      /'
  fail=$((fail+1))
fi

if [ "$fail" -eq 0 ]; then echo "hook-message-lean: pass"; exit 0; fi
echo "hook-message-lean: $fail failure(s)"; exit 1
