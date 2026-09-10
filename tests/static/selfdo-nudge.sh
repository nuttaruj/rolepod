#!/bin/bash
# Behavioral test — worktree-guard self-do nudge (v2.116.0).
#
# Measured before the hook (90 days, every product repo): the Lead made
# ~5,500 edits to product files while writer roles were dispatched 70 times
# in total — reviewer roles fire because the commit gate counts them, writer
# roles had nothing. The nudge fires ONCE per route when the Lead is on an
# R3/R4 route, has made ≥ 6 edits to product code since that route, and
# dispatched no writer role. Never on R1/R2, never on a subagent's edit,
# never when a writer role was dispatched, never on a test / doc target,
# silent without a routing line.
#
# Runs the real hook in a throwaway git repo with a fabricated transcript.
# HOME is redirected so the session-lock registry never touches the real one.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_DIR/hooks/worktree-guard.sh"

fail=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"; mkdir -p "$HOME"
mkdir -p "$tmp/repo/src" "$tmp/repo/tests" && cd "$tmp/repo"
git init -q . && git config user.email t@t && git config user.name t

T="$tmp/t.jsonl"
SID="selfdotest$$"

# transcript builders — every event carries a timestamp so the since-route
# floor is exercised. Assistant text and tool_use blocks share one shape.
reset() { : > "$T"; }
route() {   # route <tier> <ts>
  printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"text","text":"Route: %s (multi-file) \\u2192 implement-plan \\u00b7 test"}]}}\n' "$2" "$1" >> "$T"
}
edit() {    # edit <file> <ts> [sidechain]
  local sc=""; [ "${3:-}" = "sidechain" ] && sc='"isSidechain":true,'
  printf '{"type":"assistant",%s"timestamp":"%s","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"%s"}}]}}\n' "$sc" "$2" "$1" >> "$T"
}
dispatch() {   # dispatch <subagent_type> <ts>
  printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"tool_use","name":"Agent","input":{"subagent_type":"%s","prompt":"x"}}]}}\n' "$2" "$1" >> "$T"
}
workflow() {   # workflow <agentType> <ts>
  printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"tool_use","name":"Workflow","input":{"script":"await agent(1, {agentType: \\u0027%s\\u0027})"}}]}}\n' "$2" "$1" >> "$T"
}
n_edits() {   # n_edits <count> <file> <ts-prefix> [sidechain]  → N edits at increasing seconds
  local i; for i in $(seq 1 "$1"); do edit "$2" "$3$(printf '%02d' "$i")Z" "${4:-}"; done
}

# run <label> <target> <expect: nudge|silent> [agent_id]
run() {
  local aid="" out verdict=silent
  [ -n "${4:-}" ] && aid='"agent_id":"sub1",'
  out=$(printf '{"session_id":"%s",%s"cwd":"%s","transcript_path":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' \
        "$SID" "$aid" "$tmp/repo" "$T" "$2" | bash "$HOOK" 2>/dev/null)
  echo "$out" | grep -q 'self-do' && verdict=nudge
  if [ "$verdict" = "$3" ]; then echo "  ✓ $1"; else echo "  ✗ $1 — expected $3, got $verdict"; fail=$((fail+1)); fi
}
mark() { rm -f "$HOME"/.rolepod/session-locks/*/"$SID".selfdo 2>/dev/null; }

echo "── selfdo-nudge ──"
F="$tmp/repo/src/a.ts"

reset; route R3 2026-01-01T10:00:00Z; n_edits 6 "$F" 2026-01-01T10:01:
run "R3 + 6 product edits + 0 writer dispatch → nudge" "$F" nudge
run "same route again → silent (once per route)" "$F" silent

mark; reset; route R3 2026-01-01T10:00:00Z; n_edits 5 "$F" 2026-01-01T10:01:
run "R3 + 5 edits → silent (below 6)" "$F" silent

mark; reset; route R2 2026-01-01T10:00:00Z; n_edits 8 "$F" 2026-01-01T10:01:
run "R2 + 8 edits → silent (R1/R2 self-do lane)" "$F" silent

mark; reset; route R4 2026-01-01T10:00:00Z; n_edits 6 "$F" 2026-01-01T10:01:
run "R4 + 6 edits → nudge" "$F" nudge

mark; reset; route R3 2026-01-01T10:00:00Z; dispatch rolepod:frontend-developer 2026-01-01T10:00:30Z; n_edits 6 "$F" 2026-01-01T10:01:
run "writer role dispatched after the route → silent" "$F" silent

mark; reset; route R3 2026-01-01T10:00:00Z; workflow rolepod:backend-developer 2026-01-01T10:00:30Z; n_edits 6 "$F" 2026-01-01T10:01:
run "Workflow agentType writer after the route → silent" "$F" silent

mark; reset; route R3 2026-01-01T10:00:00Z; dispatch rolepod:qa-tester 2026-01-01T10:00:30Z; dispatch rolepod:scout 2026-01-01T10:00:31Z; n_edits 6 "$F" 2026-01-01T10:01:
run "reviewer / scout dispatch is not a writer → nudge" "$F" nudge

mark; reset; dispatch rolepod:frontend-developer 2026-01-01T09:00:00Z; route R3 2026-01-01T10:00:00Z; n_edits 6 "$F" 2026-01-01T10:01:
run "writer dispatched BEFORE the route does not count → nudge" "$F" nudge

mark; reset; n_edits 6 "$F" 2026-01-01T10:01:; edit "$F" 2026-01-01T10:02:00Z
run "no routing line → silent" "$F" silent

mark; reset; route R3 2026-01-01T10:00:00Z; n_edits 6 "$F" 2026-01-01T10:01:
run "subagent edit (agent_id) → silent" "$F" silent sub

mark; reset; route R3 2026-01-01T10:00:00Z; n_edits 6 "$tmp/repo/tests/a.test.ts" 2026-01-01T10:01:
run "6 test-file edits → silent (tests are not product code)" "$F" silent

mark; reset; route R3 2026-01-01T10:00:00Z; n_edits 6 "$F" 2026-01-01T10:01:
run "doc target → silent (scan only on a product-code target)" "$tmp/repo/README.md" silent

mark; reset; route R3 2026-01-01T10:00:00Z; n_edits 6 "$tmp/repo/src/test_foo.py" 2026-01-01T10:01:
run "6 pytest test_*.py edits → silent (same classifier counts and gates)" "$F" silent

mark; reset; route R3 2026-01-01T10:00:00Z; n_edits 6 "$tmp/repo/src/__mocks__/m.js" 2026-01-01T10:01:
run "6 __mocks__/ edits → silent" "$F" silent

mark; reset; route R3 2026-01-01T10:00:00Z; n_edits 3 "$tmp/repo/src/test_foo.py" 2026-01-01T10:01:; n_edits 3 "$F" 2026-01-01T10:02:
run "3 test_*.py + 3 product edits → silent (tests never inflate the count)" "$F" silent

mark; reset; route R3 2026-01-01T10:00:00Z; n_edits 6 "$F" 2026-01-01T10:01: sidechain
run "sidechain edits do not count → silent" "$F" silent

mark; reset; route R2 2026-01-01T09:00:00Z; n_edits 6 "$F" 2026-01-01T09:01:; route R3 2026-01-01T10:00:00Z; n_edits 6 "$F" 2026-01-01T10:01:
run "re-route R2 → R3: edits before the new route do not count, 6 after → nudge" "$F" nudge

mark; reset; route R3 2026-01-01T10:00:00Z; n_edits 6 "$F" 2026-01-01T10:01:
ROLEPOD_NUDGE_OFF=1 run "ROLEPOD_NUDGE_OFF=1 → silent" "$F" silent

# message shape: fact → Fix → Exception, the WHOLE additionalContext ≤ 600
# chars — also on a first-touch product file (ladder would join) and on a
# dependency manifest (manifest nudge would join): self-do replaces both.
msg_of() { printf '{"session_id":"%s","cwd":"%s","transcript_path":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$SID" "$tmp/repo" "$T" "$1" \
      | bash "$HOOK" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])'; }
mark; reset; route R4 2026-01-01T10:00:00Z; n_edits 23 "$F" 2026-01-01T10:01:
MSG=$(msg_of "$tmp/repo/src/fresh.ts")
if printf '%s' "$MSG" | grep -q 'route R4, 23 Lead edits' && printf '%s' "$MSG" | grep -q 'Fix:' && printf '%s' "$MSG" | grep -q 'Exception:' && ! printf '%s' "$MSG" | grep -q 'first touch' && [ "${#MSG}" -le 600 ]; then
  echo "  ✓ first-touch product file: whole message = self-do only (tier + count, Fix, Exception), ≤ 600 chars (${#MSG})"
else
  echo "  ✗ message shape: ${MSG:0:160} (${#MSG} chars)"; fail=$((fail+1))
fi
mark; reset; route R4 2026-01-01T10:00:00Z; n_edits 23 "$F" 2026-01-01T10:01:
run "dependency manifest target (Gemfile) is not product code → manifest nudge only, no self-do" "$tmp/repo/Gemfile" silent

[ "$fail" -eq 0 ] && echo "  → selfdo-nudge passed" || { echo "  ✗ selfdo-nudge: $fail failure(s)"; exit 1; }
