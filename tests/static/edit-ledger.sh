#!/bin/bash
# edit-ledger — the CLI-neutral edit evidence behind the commit gate (v2.134.0).
# Pins: classification byte-identical to hooks/lib/session_state.py; append /
# count / window / rotation / apply_patch multi-file / fail-open outside git.
set -u
cd "$(dirname "$0")/../.."
fail=0
pass() { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1"; fail=$((fail + 1)); }
L=hooks/edit-ledger.py

# 1. The three regexes are the transcript scan's, byte-for-byte.
if python3 -I - <<'PY'
import re, sys
def body(path, name):
    src = open(path).read()
    m = re.search(name + r' = re\.compile\((.*?)re\.IGNORECASE', src, re.S)
    return ''.join(re.findall(r'r"(.*?)"', m.group(1))) if m else 'PARSE-FAIL:' + name
for name in ("HIGH_RISK_PATH", "TEST_FILE", "CODE_FILE"):
    a = body("hooks/lib/session_state.py", name); b = body("hooks/edit-ledger.py", name)
    assert a == b and not a.startswith("PARSE-FAIL"), (name, a[:60], b[:60])
PY
then pass "HIGH_RISK_PATH / TEST_FILE / CODE_FILE identical to session_state.py"
else bad "edit-ledger.py classification drifted from session_state.py"; fi

R="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-ledger.XXXXXX")"
trap 'rm -rf "$R"' EXIT
git -C "$R" init -q; git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
LEDGER="$R/.rolepod/evidence/edits.jsonl"
ROOT="$(git -C "$R" rev-parse --show-toplevel)"

# 2. append classifies like the scan: test wins, risk needs a code file, else other.
python3 -I "$L" append cursor "$ROOT/src/auth/login.ts" "$ROOT/tests/auth.test.ts" "$ROOT/docs/auth.md" "$ROOT/src/util.ts" --cwd "$R" --agent backend-developer
if [ -f "$LEDGER" ] && python3 -I - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
kinds = {r["path"]: r["kind"] for r in rows}
assert kinds == {"src/auth/login.ts": "risk", "tests/auth.test.ts": "test", "docs/auth.md": "other", "src/util.ts": "other"}, kinds
assert all(r["cli"] == "cursor" and r["agent"] == "backend-developer" and r["t"] > 0 and r["ts"].endswith("Z") for r in rows)
PY
then pass "append: risk = high-risk path AND code file; docs/auth.md is other; paths repo-relative; cli + agent recorded"
else bad "append wrote the wrong rows: $(cat "$LEDGER" 2>/dev/null | head -c 300)"; fi

# 3. count = "TEST_EDITS HIGH_RISK_EDITS", windowed by epoch.
out=$(python3 -I "$L" count "" --cwd "$R"); [ "$out" = "1 1" ] && pass "count (no window): 1 test / 1 risk" || bad "count no-window: got [$out]"
out=$(python3 -I "$L" count "$(( $(date +%s) + 60 ))" --cwd "$R"); [ "$out" = "0 0" ] && pass "count windowed to the future → 0 0" || bad "count future window: got [$out]"
out=$(python3 -I "$L" count "$(( $(date +%s) - 60 ))" --cwd "$R"); [ "$out" = "1 1" ] && pass "count windowed to a minute ago → 1 1" || bad "count past window: got [$out]"

# 4. append-stdin: Claude shape (Write) and Codex apply_patch (three files in one patch).
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/src/billing/charge.py","content":""},"cwd":"%s","agent_type":"billing-engineer"}' "$ROOT" "$R" | python3 -I "$L" append-stdin claude
printf '{"tool_name":"apply_patch","tool_input":{"input":"*** Begin Patch\\n*** Update File: src/auth/token.go\\n@@\\n+x\\n*** Add File: tests/token_test.go\\n+y\\n*** Delete File: README.md\\n*** End Patch"},"cwd":"%s"}' "$R" | python3 -I "$L" append-stdin claude
printf '{"tool_name":"Read","tool_input":{"file_path":"%s/src/auth/login.ts"},"cwd":"%s"}' "$ROOT" "$R" | python3 -I "$L" append-stdin claude
if python3 -I - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
tail = rows[4:]
assert [(r["path"], r["kind"], r["cli"]) for r in tail] == [
    ("src/billing/charge.py", "risk", "claude"), ("src/auth/token.go", "risk", "codex"),
    ("tests/token_test.go", "test", "codex"), ("README.md", "other", "codex")], tail
assert tail[0]["agent"] == "billing-engineer"
PY
then pass "append-stdin: Write → risk (claude); apply_patch → 3 rows tagged codex; Read → nothing"
else bad "append-stdin rows wrong: $(tail -4 "$LEDGER" | head -c 400)"; fi
out=$(python3 -I "$L" count "" --cwd "$R"); [ "$out" = "2 3" ] && pass "count after both shapes: 2 test / 3 risk" || bad "count: got [$out]"

# 5. Rotation keeps the newest 2000 lines once the file passes 512 KB.
python3 - "$LEDGER" <<'PY'
import json, sys, time
with open(sys.argv[1], "a") as f:
    for i in range(6000):
        f.write(json.dumps({"t": time.time(), "ts": "x", "cli": "claude", "path": "pad/%05d.md" % i, "kind": "other", "agent": ""}) + "\n")
PY
python3 -I "$L" append claude "$ROOT/src/last.ts" --cwd "$R"
n=$(wc -l < "$LEDGER" | tr -d ' ')
[ "$n" -eq 2000 ] && tail -1 "$LEDGER" | grep -q '"src/last.ts"' && pass "rotation: 6000+ lines → newest 2000 kept, latest row intact" || bad "rotation: $n lines"

# 6. Fail-open: no git root → nothing written, count prints 0 0, rc 0 everywhere.
NG="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-ledger-nogit.XXXXXX")"
python3 -I "$L" append claude "$NG/a.ts" --cwd "$NG"; rc1=$?
out=$(python3 -I "$L" count "" --cwd "$NG"); rc2=$?
printf 'not json' | python3 -I "$L" append-stdin claude; rc3=$?
[ $rc1 -eq 0 ] && [ $rc2 -eq 0 ] && [ $rc3 -eq 0 ] && [ "$out" = "0 0" ] && [ ! -e "$NG/.rolepod" ] && pass "outside git / bad stdin → silent, rc 0, count 0 0" || bad "fail-open broken (rc $rc1/$rc2/$rc3, out [$out])"
rm -rf "$NG"

echo
if [ "$fail" -eq 0 ]; then echo "edit-ledger: pass"; exit 0; fi
echo "edit-ledger: FAIL ($fail)"; exit 1
