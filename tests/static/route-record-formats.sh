#!/bin/bash
# route-record-formats — hooks/lib/route_check.py reads every CLI's transcript (v2.135.0).
# Fixtures are the measured line shapes of Claude, Cursor (agent-transcripts),
# Codex (rollout) and Antigravity (transcript_full.jsonl); --record-text is the
# opencode path (the plugin hands over the turn's text + the prompt time).
set -u
cd "$(dirname "$0")/../.."
fail=0
pass() { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1"; fail=$((fail + 1)); }
RC="$PWD/hooks/lib/route_check.py"
R="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-routefmt.XXXXXX")"
trap 'rm -rf "$R"' EXIT
git -C "$R" init -q; git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
LOG="$R/.rolepod/evidence/phase-log.jsonl"
ROUTE='Route: R3 (multi-file) → implement-plan · three files'
record() { (cd "$R" && printf '{"transcript_path":"%s","cwd":"%s"}' "$1" "$R" | python3 -I "$RC" --record 2>/dev/null); }
routes() { grep -c '"phase":"route"' "$LOG" 2>/dev/null || echo 0; }
last_route() { grep '"phase":"route"' "$LOG" | tail -1; }

# Claude (the existing contract): user + assistant with timestamps.
T1="$R/claude.jsonl"; NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '{"type":"user","timestamp":"2026-01-01T00:00:00Z","message":{"content":[{"type":"text","text":"fix the login bug"}]}}\n{"type":"assistant","timestamp":"2026-01-01T00:00:05Z","message":{"content":[{"type":"text","text":"%s\\nWorking."}]}}\n' "$ROUTE" > "$T1"
record "$T1"
[ "$(routes)" = 1 ] && last_route | grep -q '"tier":"R3","skill":"implement-plan"' && pass "Claude transcript → one route line (R3 / implement-plan)" || bad "Claude: $(routes) lines: $(last_route)"

# Cursor: role-keyed, no timestamps, user text wrapped in <timestamp>..<user_query>, "[REDACTED]" tails.
rm -f "$LOG"; T2="$R/cursor.jsonl"
printf '{"role":"user","message":{"content":[{"type":"text","text":"<timestamp>Wednesday, Sep 16, 2026, 2:17 PM (UTC+7)</timestamp>\\n<user_query>\\nfix the login bug\\n</user_query>"}]}}\n{"role":"assistant","message":{"content":[{"type":"text","text":"Route: R2 (one file + test) → implement-plan · one handler\\n\\n[REDACTED]"},{"type":"tool_use","name":"Read","input":{}}]}}\n{"type":"turn_ended","status":"success"}\n' > "$T2"
record "$T2"
[ "$(routes)" = 1 ] && last_route | grep -q '"tier":"R2","skill":"implement-plan"' && pass "Cursor transcript → route line (wrapped prompt counts as the turn boundary)" || bad "Cursor: $(routes) lines: $(last_route)"
record "$T2"
[ "$(routes)" = 1 ] && pass "Cursor: recording the same turn again → no duplicate" || bad "Cursor dup: $(routes)"

# Codex rollout: response_item/message with input_text / output_text; harness user blocks ignored.
rm -f "$LOG"; T3="$R/codex.jsonl"
printf '{"timestamp":"2026-01-01T00:00:00Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<recommended_plugins>\\n…"},{"type":"input_text","text":"# AGENTS.md instructions\\n…"}]}}\n{"timestamp":"2026-01-01T00:00:01Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"add a retry to the webhook client"}]}}\n{"timestamp":"2026-01-01T00:00:09Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"**Route: R4 — money surface** → write-spec · webhook retries"}]}}\n{"timestamp":"2026-01-01T00:00:10Z","type":"event_msg","payload":{"type":"task_complete"}}\n' > "$T3"
record "$T3"
[ "$(routes)" = 1 ] && last_route | grep -q '"tier":"R4","skill":"write-spec"' && pass "Codex rollout → route line (harness user blocks are not prompts)" || bad "Codex: $(routes) lines: $(last_route)"

# Antigravity transcript_full.jsonl: USER_INPUT (wrapped) + PLANNER_RESPONSE content.
rm -f "$LOG"; T4="$R/agy.jsonl"
printf '{"step_index":0,"source":"USER_EXPLICIT","type":"USER_INPUT","status":"DONE","created_at":"2026-01-01T00:00:00Z","content":"<USER_REQUEST>\\nrename the config loader\\n</USER_REQUEST>"}\n{"step_index":1,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","created_at":"2026-01-01T00:00:03Z","tool_calls":[{"name":"view_file","args":{}}]}\n{"step_index":2,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","created_at":"2026-01-01T00:00:08Z","content":"Route: R1 → implement-plan · rename only"}\n' > "$T4"
record "$T4"
[ "$(routes)" = 1 ] && last_route | grep -q '"tier":"R1","skill":"implement-plan"' && pass "Antigravity transcript → route line (USER_REQUEST wrapper stripped)" || bad "agy: $(routes) lines: $(last_route)"

# --record-text (opencode): assistant text + prompt_ts; the prompt time is the once-per-turn guard.
rm -f "$LOG"; PT=$(( $(date +%s) - 30 ))
(cd "$R" && printf '{"assistant_text":"Route: R2 (one file + test) → implement-plan · one handler\\nok","prompt_ts":%s}' "$PT" | python3 -I "$RC" --record-text 2>/dev/null)
[ "$(routes)" = 1 ] && last_route | grep -q '"tier":"R2","skill":"implement-plan"' && pass "--record-text → route line" || bad "record-text: $(routes) lines"
(cd "$R" && printf '{"assistant_text":"Route: R2 → implement-plan · again","prompt_ts":%s}' "$PT" | python3 -I "$RC" --record-text 2>/dev/null)
[ "$(routes)" = 1 ] && pass "--record-text: same prompt_ts again → no duplicate" || bad "record-text dup: $(routes)"
(cd "$R" && printf '{"assistant_text":"Route: R3 → implement-plan · next turn","prompt_ts":%s}' "$(( $(date +%s) + 1 ))" | python3 -I "$RC" --record-text 2>/dev/null)
[ "$(routes)" = 2 ] && pass "--record-text: a newer prompt_ts → the next turn is recorded" || bad "record-text next: $(routes)"
(cd "$R" && printf '{"assistant_text":"Route: R3 → implement-plan · no prompt"}' | python3 -I "$RC" --record-text 2>/dev/null)
[ "$(routes)" = 2 ] && pass "--record-text without prompt_ts → ignored (no guard, no line)" || bad "record-text no-ts: $(routes)"

echo
if [ "$fail" -eq 0 ]; then echo "route-record-formats: pass"; exit 0; fi
echo "route-record-formats: FAIL ($fail)"; exit 1
