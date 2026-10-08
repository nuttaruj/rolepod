#!/bin/bash
# evidence-tools — locks the evidence reader:
#   core/skills/rolepod-stats/scripts/stats.sh   (phase-log/bypass observational readout)
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1"; fail=1
  fi
}

FIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-evtools.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
# The nudge hook reads the user's config from $HOME: a scratch HOME per mode,
# so a real ~/.rolepod/config.json never steers a case.
export HOME="$FIX/home"
export ROLEPOD_SESSION_MODE=full ROLEPOD_SESSION_SOURCE=project ROLEPOD_SESSION_CLI=claude
mkdir -p "$FIX/home" "$FIX/home-off/.rolepod" "$FIX/home-nudge-off/.rolepod"
printf '{"gates":{"mode":"off"}}\n' > "$FIX/home-off/.rolepod/config.json"
printf '{"nudge":{"enabled":false}}\n' > "$FIX/home-nudge-off/.rolepod/config.json"

# ── stats.sh ────────────────────────────────────────────────────────────
# Every stats.sh call here runs under HOME="$FIX". stats.sh also reads the
# machine-global ~/.rolepod/gate-bypass.log, so without the sandbox this
# case passes or fails on whatever the developer's own log happens to hold
# — it once went red on a real corrupt byte that CI could never reproduce.
mkdir -p "$FIX/repo/.rolepod/evidence"
git -C "$FIX/repo" init -q
printf '{"workflow":{"mode":"full"},"gates":{"mode":"off"},"nudge":{"enabled":false}}\n' > "$FIX/repo/.rolepod/config.json"
cat > "$FIX/repo/.rolepod/evidence/phase-log.jsonl" <<'EOF'
{"ts":"2026-07-31T01:00:00Z","phase":"route","tier":"R2","skill":"implement-plan"}
{"ts":"2026-07-31T01:05:00Z","phase":"route","tier":"R3","skill":"write-spec"}
{"ts":"2026-07-31T01:10:00Z","phase":"verify","verdict":"pass","evidence":"pytest -q"}
{"ts":"2026-07-31T01:12:00Z","phase":"verify","verdict":"partial","evidence":"pytest -q"}
{"ts":"2026-07-31T01:20:00Z","phase":"verify","verdict":"fail","evidence":"pytest -q"}
{"ts":"2026-07-31T01:30:00Z","phase":"review","verdict":"APPROVED","blockers":0}
{"ts":"2026-07-31T01:40:00Z","phase":"ship","action":"pr","commit":"none"}
{"ts":"2026-07-31T01:45:00Z","phase":"dispatch","tier":"strong","override":"opus"}
{"ts":"2026-07-31T01:50:00Z","phase":"dispatch","tier":"strong","override":"none"}
{"ts":"2026-07-31T01:57:00Z","phase":"dispatch","cli":"claude","tool":"Agent","provenance":"hook-auto","agent_type":"rolepod:scout","model":"inherit","override":"none"}
{"ts":"2026-07-31T01:58:00Z","phase":"dispatch","cli":"claude","tool":"Agent","provenance":"hook-auto","agent_type":"rolepod:security-engineer","model":"inherit","override":"none","lead_class":"balanced"}
{"ts":"2026-07-31T01:58:30Z","phase":"dispatch","cli":"claude","tool":"Agent","provenance":"hook-auto","agent_type":"rolepod:rolepod-reviewer","model":"opus","override":"none","lead_class":"balanced"}
{"ts":"2026-07-31T02:10:00Z","phase":"dispatch","cli":"claude","tool":"Agent","provenance":"hook-auto","agent_type":"rolepod:backend-developer","model":"inherit","override":"none"}
{"ts":"2026-07-31T02:10:20Z","phase":"dispatch","cli":"claude","tool":"Agent","provenance":"hook-auto","agent_type":"rolepod:devops-sre","model":"inherit","override":"none"}
{"ts":"2026-07-31T02:10:40Z","phase":"dispatch","cli":"claude","tool":"Agent","provenance":"hook-auto","agent_type":"rolepod:content-strategist","model":"inherit","override":"none"}
{"ts":"2026-07-31T02:30:00Z","phase":"dispatch","cli":"claude","tool":"Agent","provenance":"hook-auto","agent_type":"rolepod:backend-developer","model":"inherit","override":"none"}
{"ts":"2026-07-31T02:31:00Z","phase":"dispatch","cli":"claude","tool":"Agent","provenance":"hook-auto","agent_type":"general-purpose","model":"inherit","override":"none"}
{"ts":"2026-07-31T01:59:00Z","phase":"dispatch","cli":"claude","tool":"Agent","provenance":"hook-auto","agent_type":"rolepod:security-engineer","model":"sonnet","override":"sonnet","lead_class":"balanced"}
{"ts":"2026-07-31T01:59:30Z","phase":"dispatch","cli":"claude","tool":"Agent","provenance":"hook-auto","tier":"strong","agent_type":"rolepod:rolepod-reviewer","model":"sonnet","override":"sonnet","lead_class":"balanced"}
not json — must be skipped, not crash
EOF
printf '{"ts":"2026-07-31T01:15:00Z","hook":"precommit-gate","var":"ROLEPOD_GATES_SOFT","reason":"unreasoned"}\n{"ts":"2026-07-31T01:16:00Z","hook":"gate-reminder","var":"ROLEPOD_GATES_SOFT","reason":"rolepod-selftest"}\n{"ts":"2026-07-31T01:17:00Z","hook":"worktree-guard","var":"ROLEPOD_ALLOW_SHARED_WORKTREE","reason":"doctor"}\n' \
  > "$FIX/repo/.rolepod/evidence/bypass.log"
# v2.108.0 — fleet token footprint reads the Claude subagent transcripts of THIS repo (key = root with / → -)
KEY="$(cd "$FIX/repo" && pwd -P | tr "/" "-")"; SUB="$FIX/.claude/projects/$KEY/sess1/subagents"
mkdir -p "$SUB/workflows/wf_fixture1" "$SUB"
printf '{"type":"assistant","timestamp":"%s","message":{"model":"claude-opus-5","usage":{"output_tokens":1200,"cache_read_input_tokens":2500000},"content":[]}}\n' "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" > "$SUB/workflows/wf_fixture1/agent-a1.jsonl"
printf '{"type":"assistant","timestamp":"%s","message":{"model":"claude-opus-5","usage":{"output_tokens":800,"cache_read_input_tokens":1500000},"content":[]}}\n' "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" > "$SUB/workflows/wf_fixture1/agent-a2.jsonl"
printf '{"type":"assistant","timestamp":"%s","message":{"model":"claude-sonnet-5","usage":{"output_tokens":300,"cache_read_input_tokens":400000},"content":[]}}\nnot json\n' "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" > "$SUB/agent-b1.jsonl"
# one agent that switched model mid-file (haiku → opus): tokens land per model, the agent counts under both
printf '{"type":"assistant","timestamp":"%s","message":{"model":"claude-haiku-4-5","usage":{"output_tokens":600,"cache_read_input_tokens":200000},"content":[]}}\n{"type":"assistant","timestamp":"%s","message":{"model":"claude-opus-5","usage":{"output_tokens":900,"cache_read_input_tokens":10000},"content":[]}}\n' "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" > "$SUB/workflows/wf_fixture1/agent-a3.jsonl"
# a workflow agent's own sub-spawn lives one level deeper and still belongs to the workflow
mkdir -p "$SUB/workflows/wf_fixture1/subagents"; printf '{"type":"assistant","timestamp":"%s","message":{"model":"claude-haiku-4-5","usage":{"output_tokens":400,"cache_read_input_tokens":100000},"content":[]}}\n' "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" > "$SUB/workflows/wf_fixture1/subagents/agent-n1.jsonl"
# one API call written as 3 rows (thinking/text/tool_use) sharing message.id + usage: counted once (cache-read 900k, not 2.7M); effort from the row's top-level field
NOW="2098-03-01T00:00:00.000Z"; mkdir -p "$SUB/workflows/wf_dedupe"
for BLK in thinking text tool_use; do printf '{"type":"assistant","timestamp":"%s","effort":"high","message":{"id":"msg_dup1","model":"claude-haiku-4-5","usage":{"output_tokens":50,"input_tokens":7,"cache_creation_input_tokens":1000,"cache_read_input_tokens":900000},"content":[{"type":"%s"}]}}\n' "$NOW" "$BLK"; done > "$SUB/workflows/wf_dedupe/agent-d1.jsonl"
# ultracode turn in the main session (sess1.jsonl beside the sess1/ dir): marker 2098-01, a tool_result row (does not end the turn),
# the wf_dedupe fleet at 2098-03 (inside), the next typed prompt 2098-06 (ends it), then a later marker-less fleet at 2099 (NOT tagged)
{
  printf '{"type":"attachment","attachment":{"type":"workflow_keyword_request"},"timestamp":"2098-01-01T00:00:00.000Z"}\n'
  printf '{"type":"attachment","attachment":{"type":"workflow_keyword_request"},"timestamp":"2098-01-15T00:00:00.000Z"}\n'   # 2nd marker, same turn: still ONE turn
  printf '{"type":"user","promptId":"p0","timestamp":"2098-02-01T00:00:00.000Z","message":{"content":[{"type":"tool_result","content":"x"}]}}\n'
  printf '{"type":"user","promptId":"p1","timestamp":"2098-06-01T00:00:00.000Z","message":{"content":"next prompt, no keyword"}}\n'
} > "$FIX/.claude/projects/$KEY/sess1.jsonl"
mkdir -p "$SUB/workflows/wf_later"
printf '{"type":"assistant","timestamp":"2099-01-01T00:00:00.000Z","message":{"id":"msg_l1","model":"claude-sonnet-5","usage":{"output_tokens":10,"cache_read_input_tokens":1000},"content":[]}}\n' > "$SUB/workflows/wf_later/agent-l1.jsonl"
# ultracode as a SESSION setting: ultra_effort_enter opens a window, the next ultra_effort_exit closes it, no exit = open to the end.
# sess2: enter 2097-01, exit 2097-06 → wf_sin (2097-03) tagged, wf_sout (2097-09) not. sess3: enter, no exit → wf_sopen tagged.
for S in sess2 sess3; do for W in sin sout sopen; do
  [ "$S:$W" = "sess2:sin" ] && TS="2097-03-01" || { [ "$S:$W" = "sess2:sout" ] && TS="2097-09-01" || { [ "$S:$W" = "sess3:sopen" ] && TS="2097-03-01" || continue; }; }
  mkdir -p "$FIX/.claude/projects/$KEY/$S/subagents/workflows/wf_$W"
  printf '{"type":"assistant","timestamp":"%sT00:00:00.000Z","message":{"id":"msg_%s","model":"claude-sonnet-5","usage":{"output_tokens":10,"cache_read_input_tokens":1000},"content":[]}}\n' "$TS" "$W" > "$FIX/.claude/projects/$KEY/$S/subagents/workflows/wf_$W/agent-s1.jsonl"
done; done
{
  printf '{"type":"attachment","attachment":{"type":"ultra_effort_enter","reminderType":"full"},"timestamp":"2097-01-01T00:00:00.000Z"}\n'
  printf '{"type":"attachment","attachment":{"type":"ultra_effort_enter","reminderType":"sparse"},"timestamp":"2097-02-01T00:00:00.000Z"}\n'   # repeated enter inside an open window must not open a second one
  printf '{"type":"attachment","attachment":{"type":"ultra_effort_exit"},"timestamp":"2097-06-01T00:00:00.000Z"}\n'
} > "$FIX/.claude/projects/$KEY/sess2.jsonl"
printf '{"type":"attachment","attachment":{"type":"ultra_effort_enter","reminderType":"full"},"timestamp":"2097-01-01T00:00:00.000Z"}\n' > "$FIX/.claude/projects/$KEY/sess3.jsonl"

OUT=$(HOME="$FIX" bash "$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh" "$FIX/repo")
check "stats reports tier distribution" "printf '%s' \"\$OUT\" | grep -q 'R2'"
check "stats reports verify fail rate"    "printf '%s' \"\$OUT\" | grep -q 'fail=1'"
check "stats reports partial verdicts (Status PARTIAL mirrored, v2.85.0)" "printf '%s' \"\$OUT\" | grep -q 'partial=1'"
check "stats reports review verdicts"     "printf '%s' \"\$OUT\" | grep -q 'APPROVED: 1'"
check "stats flags unreasoned bypasses"   "printf '%s' \"\$OUT\" | grep -q 'unreasoned'"
check "stats counts self-test bypass rows apart (rolepod-selftest + legacy doctor, v2.85.1)" "printf '%s' \"\$OUT\" | grep -q 'Bypasses (1 ' && printf '%s' \"\$OUT\" | grep -q 'self-test rows excluded: 2'"
check "stats audits strong dispatches"    "printf '%s' \"\$OUT\" | grep -q 'Strong dispatches (4): 2 with explicit override, 2 frontmatter opus, 0 inherit (pre-2.104), 1 pinned low'"
check "stats: the legacy security-engineer rows (model inherit; model sonnet, no tier) are not strong — STRONG_ROLES is gone, so the strong count is only tier=strong or an opus-class model" "! printf '%s' \"\$OUT\" | grep -q 'Strong dispatches (6'"
check "stats names an explicit low pin on a strong role as the silent downgrade (v2.104)"  "printf '%s' \"\$OUT\" | grep -q 'explicit cheap/balanced pin on a strong dispatch is the silent downgrade'"
check "stats reports hook-auto dispatch intent" "printf '%s' \"\$OUT\" | grep -q 'Dispatch intent — hook-auto (10'"
check "stats reports task-owner dispatch bursts (widths + partnered share)" "printf '%s' \"\$OUT\" | grep -q 'Task-owner dispatch bursts (4 task dispatches, 2 bursts; ≤ 90 s apart = one burst — dispatch time only, not proof of concurrent runs)' && printf '%s' \"\$OUT\" | grep -q 'widths: 3, 1 · dispatched within 90 s of another: 3/4 (75%)'"
check "stats: a rolepod role with no model on the call ran its frontmatter model (not the Lead's)" "printf '%s' \"\$OUT\" | grep -q 'with no model on the call ran the role'"
check "stats flags ONLY a generic agent type as inheriting the Lead's model" "printf '%s' \"\$OUT\" | grep -q '1 generic dispatch(es) inherited the Lead'"
check "stats survives malformed lines"    "HOME='$FIX' bash '$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh' '$FIX/repo'"
check "stats fleet token footprint (v2.108): per fleet per model from subagent transcripts — tokens per model per line (mid-file model switch), nested sub-spawn stays in its workflow, Agent-tool bucket, totals" \
  "printf '%s' \"\$OUT\" | grep -q 'Fleet token footprint — subagent transcripts (last 14d, 7 fleet(s), 10 agents; output + cache-read tokens only — not total tokens, not billed cost)' && printf '%s' \"\$OUT\" | grep -q 'wf_fixture1 .* opus 3 (out 3k, cache-read 4M) · haiku 2 (out 1k, cache-read 300k)' && printf '%s' \"\$OUT\" | grep -q 'agent-tool:[^ ]* .* sonnet 1 (out 0k, cache-read 400k)' && printf '%s' \"\$OUT\" | grep -q 'total: sonnet 5 · haiku 3 · opus 3'"
check "stats dedupes one API call written as 3 rows by message.id (cache-read 900k once, input 7 + cache-write 1k), shows the row effort, tags the ultracode turn and only the fleet inside it (a later marker-less fleet is not tagged)" \
  "printf '%s' \"\$OUT\" | grep -q 'wf_dedupe .* haiku 1 (out 0k, cache-read 900k)  · effort high×1  \[ultracode\]' && printf '%s' \"\$OUT\" | grep -q 'cache-write 1k' && printf '%s' \"\$OUT\" | grep -q 'ultracode turns: 1 ' && printf '%s' \"\$OUT\" | grep -q 'wf_fixture1 .*effort -×4' && ! printf '%s' \"\$OUT\" | grep 'wf_later' | grep -q 'ultracode\]'"
check "stats tags a fleet inside an ultracode SESSION window (ultra_effort_enter .. next ultra_effort_exit, or open to the end) and not one after the exit; names both sources" \
  "printf '%s' \"\$OUT\" | grep 'wf_sin' | grep -q 'ultracode\]' && printf '%s' \"\$OUT\" | grep 'wf_sopen' | grep -q 'ultracode\]' && ! printf '%s' \"\$OUT\" | grep 'wf_sout' | grep -q 'ultracode\]' && printf '%s' \"\$OUT\" | grep -q 'ultracode turns: 1 · ultracode sessions: 2' && printf '%s' \"\$OUT\" | grep -q 'ultracode fleets: 3 of 7 (keyword turn or ultracode session)'"
check "stats fleet token footprint: no inverted-tier warning when strong (3) does not outnumber cheap+balanced (3)" \
  "! printf '%s' \"\$OUT\" | grep -q 'strong-class agents outnumber'"
# HOME sandboxed: stats also reads the machine-global ~/.rolepod/gate-bypass.log
# (v2.46.0) — the real machine's log must not leak into the empty-repo case.
OUT=$(HOME="$FIX" bash "$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh" "$FIX")
check "stats handles empty repo (no data)" "printf '%s' \"\$OUT\" | grep -q 'no data yet'"

# v2.46.0: precommit auto-passes surface in stats, risky ones flagged.
mkdir -p "$FIX/.rolepod"
printf '2026-08-15T10:00:00 auto-pass on evidence (tests=1 reviewers=0 strong=0 risk=none): git commit -m x\n' \
  > "$FIX/.rolepod/gate-bypass.log"
printf '2026-08-15T10:05:00 auto-pass on evidence (tests=0 reviewers=1 strong=1 risk=auth/login.py): git commit -m y\n' \
  >> "$FIX/.rolepod/gate-bypass.log"
OUT=$(HOME="$FIX" bash "$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh" "$FIX")
check "stats surfaces precommit auto-passes"      "printf '%s' \"\$OUT\" | grep -q 'Precommit auto-passes (2'"
check "stats flags the risky auto-pass (not the risk=none one)" "printf '%s' \"\$OUT\" | grep -q 'HIGH-RISK diff (labeled, v2.46+): 1'"
printf '2026-08-10T10:00:00 auto-pass on evidence (tests=3 reviewers=2): git commit -m old\n' >> "$FIX/.rolepod/gate-bypass.log"
OUT=$(HOME="$FIX" bash "$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh" "$FIX")
check "stats reports pre-v2.46 unlabeled auto-passes separately (not as high-risk)" \
  "printf '%s' \"\$OUT\" | grep -q 'HIGH-RISK diff (labeled, v2.46+): 1' && printf '%s' \"\$OUT\" | grep -q 'pre-v2.46 unlabeled.*: 1'"

# A machine-global log is append-only and shared by every rolepod version on
# the box, so one bad byte must not take the reader down. Fixture: an
# auto-pass line whose tail is a truncated multi-byte sequence — exactly what
# a byte-precision printf produced before the writer sliced by character.
printf 'auto-pass on evidence (tests=1 reviewers=0 strong=0 risk=none): git commit -m \xe0\xb8\n' \
  >> "$FIX/.rolepod/gate-bypass.log"
check "stats survives invalid UTF-8 in the machine-global log" \
  "HOME='$FIX' bash '$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh' '$FIX'"
OUT=$(HOME="$FIX" bash "$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh" "$FIX")
check "stats still counts the entries around the corrupt line" \
  "printf '%s' \"\$OUT\" | grep -q 'Precommit auto-passes (4'"

# ── claude dispatch hooks (tier nudge + auto-log) ───────────────────────
# workflow-tier-nudge.sh runs on Workflow only (hook-layer-lean-2026-09-25,
# Desired 8): three denies remain — bare-fanout (a fan-out agent() call with
# no tier at all, under a strong-class or unknown Lead), strong-fanout (a
# fan-out call pinned strong, any Lead) and bare-writer (an
# agent() call on a writing stage with no agentType:). None yields;
# every other verdict (no-tier, single-tier, judge floors, spreads,
# downgrades, the loop valve, the low-Lead nudge, the tier-reason escape,
# the Agent-tool floor rewrite) is gone.
printf '{"tool_name":"Agent","tool_input":{"subagent_type":"rolepod:scout"}}' > "$FIX/agent-scout.json"
check "dispatch auto-log appends a hook-auto line" \
  "cd '$FIX/repo' && bash '$REPO_DIR/hooks/dispatch-auto-log.sh' < '$FIX/agent-scout.json' && grep -c 'hook-auto' .rolepod/evidence/phase-log.jsonl | grep -q 11"
check "dispatch auto-log is fail-open outside a repo" \
  "cd /tmp && bash '$REPO_DIR/hooks/dispatch-auto-log.sh' < '$FIX/agent-scout.json'"

printf '{"type":"assistant","timestamp":"2026-08-17T01:00:00.000Z","message":{"model":"claude-sonnet-5","content":[]}}\n' > "$FIX/lead-sonnet.jsonl"
printf '{"type":"assistant","timestamp":"2026-08-17T01:00:00.000Z","message":{"model":"claude-opus-5","content":[]}}\n' > "$FIX/lead-opus.jsonl"
mkj() { # $1 out, $2 tool, $3 transcript, $4 tool_input json, optional $5 cwd
  if [ -n "${5:-}" ]; then
    printf '{"cwd":"%s","tool_name":"%s","transcript_path":"%s","tool_input":%s}' "$5" "$2" "$3" "$4" > "$1"
  else
    printf '{"tool_name":"%s","transcript_path":"%s","tool_input":%s}' "$2" "$3" "$4" > "$1"
  fi
}
NUDGE="$REPO_DIR/hooks/workflow-tier-nudge.sh"
mkj "$FIX/wf-bare-fanout.json"   Workflow "$FIX/lead-opus.jsonl"   '{"script":"name: \"fleet\" phase(\"Browse\"); await parallel(BROWSE.map((b) => () => agent(b.prompt, {label: `browse:${b.key}`, phase: \"Browse\"})))"}'
mkj "$FIX/wf-allsonnet.json"     Workflow "$FIX/lead-opus.jsonl"   '{"script":"phase(\"Browse\"); await parallel(BROWSE.map((b) => () => agent(b.prompt, {model: \"sonnet\", label: `browse:${b.key}`})))"}'
mkj "$FIX/wf-strongpin-fanout.json" Workflow "$FIX/lead-opus.jsonl" '{"script":"phase(\"Verify\"); await parallel(fs.map((f) => () => agent(`verify ${f}`, {model: \"opus\", label: `verify:${f}`})))"}'
mkj "$FIX/wf-gp-fanout.json" Workflow "$FIX/lead-opus.jsonl" '{"script":"phase(\"Browse\"); await parallel(BROWSE.map((b) => () => agent(b.prompt, {agentType: \"general-purpose\", label: `browse:${b.key}`})))"}'
mkj "$FIX/wf-bare-writer.json"   Workflow "$FIX/lead-opus.jsonl"   '{"script":"phase(\"Implement\"); await agent(1,{model:\"sonnet\", effort:\"high\", label:\"impl:a\"}); phase(\"Review\"); await agent(2,{agentType:\"rolepod:security-engineer\"})"}'
mkj "$FIX/wf-single-inherit.json" Workflow "$FIX/lead-opus.jsonl"  '{"script":"await agent(1)"}'
mkj "$FIX/agent-call.json"       Agent    "$FIX/lead-opus.jsonl"   '{"subagent_type":"rolepod:universal-reviewer"}'
GOUT=$(cd "$FIX/repo" && bash "$NUDGE" < "$FIX/wf-bare-fanout.json")
check "gate: bare fan-out under an opus Lead → deny (criterion 8)" \
  "printf '%s' \"\$GOUT\" | grep -q '\"deny\"' && printf '%s' \"\$GOUT\" | grep -q 'bare fan-out' && grep -q '\"reason\": \"bare-fanout\"' '$FIX/repo/.rolepod/evidence/phase-log.jsonl'"
check "gate: all-sonnet fan-out stages → silent (criterion 8)" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-allsonnet.json')\" ]"
mkj "$FIX/wf-judge-single.json" Workflow "$FIX/lead-opus.jsonl" '{"script":"await agent(\"judge\", {model: \"opus\"})"}'
mkj "$FIX/wf-strongrole-fanout.json" Workflow "$FIX/lead-opus.jsonl" '{"script":"await parallel(items.map((i) => () => agent(`r ${i}`, {agentType: \"rolepod:rolepod-reviewer\", label: `r:${i}`})))"}'
check "gate: a strong (opus) model pin on a fan-out → deny strong-fanout" \
  "GOUT=\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-strongpin-fanout.json'); printf '%s' \"\$GOUT\" | grep -q '\"deny\"' && printf '%s' \"\$GOUT\" | grep -q 'strong model pinned on fan-out' && grep -q '\"reason\": \"strong-fanout\"' '$FIX/repo/.rolepod/evidence/phase-log.jsonl'"
mkj "$FIX/wf-mixed-fanout.json" Workflow "$FIX/lead-opus.jsonl" '{"script":"phase(\"Browse\"); await parallel(B.map((b) => () => agent(b.p, {label: `b:${b.k}`}))); phase(\"Verify\"); await parallel(fs.map((f) => () => agent(`v ${f}`, {model: \"opus\", label: `v:${f}`})))"}'
check "gate: bare + strong fan-out together → ONE deny naming both stages, ≤600 chars, no strong-role advice" \
  "GOUT=\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-mixed-fanout.json'); printf '%s' \"\$GOUT\" | grep -q '\"deny\"' && printf '%s' \"\$GOUT\" | grep -q 'Browse' && printf '%s' \"\$GOUT\" | grep -q 'Verify' && grep -q '\"reason\": \"bare-fanout+strong-fanout\"' '$FIX/repo/.rolepod/evidence/phase-log.jsonl' && [ \"\$(printf '%s' \"\$GOUT\" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)[\"hookSpecificOutput\"][\"permissionDecisionReason\"]))')\" -le 600 ]"
LONGP=$(python3 -c 'print("A"*70)'); LONGQ=$(python3 -c 'print("B"*70)')
mkj "$FIX/wf-mixed-long.json" Workflow "$FIX/lead-opus.jsonl" "{\"script\":\"phase(\\\"$LONGP\\\"); await parallel(B.map((b) => () => agent(b.p, {label: \`b:\${b.k}\`}))); phase(\\\"$LONGQ\\\"); await parallel(fs.map((f) => () => agent(\`v \${f}\`, {model: \\\"opus\\\", label: \`v:\${f}\`})))\"}"
check "gate: mixed deny with 70-char stage names stays ≤600 chars" \
  "GOUT=\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-mixed-long.json'); printf '%s' \"\$GOUT\" | grep -q 'bare-fanout\\|fleet-tier' && [ \"\$(printf '%s' \"\$GOUT\" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)[\"hookSpecificOutput\"][\"permissionDecisionReason\"]))')\" -le 600 ]"
mkj "$FIX/wf-bare-long.json" Workflow "$FIX/lead-opus.jsonl" "{\"script\":\"phase(\\\"$LONGP\\\"); await parallel(B.map((b) => () => agent(b.p, {label: \`b:\${b.k}\`}))); phase(\\\"$LONGQ\\\"); await parallel(fs.map((f) => () => agent(\`v \${f}\`, {label: \`v:\${f}\`})))\"}"
check "gate: bare-only deny with long stage names stays ≤600 chars" \
  "GOUT=\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-bare-long.json'); printf '%s' \"\$GOUT\" | grep -q 'bare fan-out call' && [ \"\$(printf '%s' \"\$GOUT\" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)[\"hookSpecificOutput\"][\"permissionDecisionReason\"]))')\" -le 600 ]"
LONGLEAD=$(python3 -c 'print("zzz-" + "m"*56)')
printf '{"type":"assistant","timestamp":"2026-08-17T01:00:00.000Z","message":{"model":"%s","content":[]}}\n' "$LONGLEAD" > "$FIX/lead-longunk.jsonl"
mkj "$FIX/wf-bare-longlead.json" Workflow "$FIX/lead-longunk.jsonl" "$(sed 's/.*"tool_input"://; s/}$//' "$FIX/wf-bare-long.json")"
mkj "$FIX/wf-mixed-longlead.json" Workflow "$FIX/lead-longunk.jsonl" "$(sed 's/.*"tool_input"://; s/}$//' "$FIX/wf-mixed-long.json")"
for LL in bare mixed; do
  check "gate: $LL deny with a 60-char unknown-family Lead stays ≤600 chars" \
    "GOUT=\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-$LL-longlead.json'); printf '%s' \"\$GOUT\" | grep -q '\"deny\"' && [ \"\$(printf '%s' \"\$GOUT\" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)[\"hookSpecificOutput\"][\"permissionDecisionReason\"]))')\" -le 600 ]"
done
check "gate: strong-fanout text asks for a non-strong type" \
  "GOUT=\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-strongpin-fanout.json'); printf '%s' \"\$GOUT\" | grep -q 'non-strong rolepod type'"
check "gate: a single strong judge call outside a fan-out → silent" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-judge-single.json')\" ]"
check "gate: a type-name agentType fan-out with no strong model → silent (A10: strong-fanout follows the model, never the type name)" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-strongrole-fanout.json')\" ]"
check "gate: strong-fanout denies under a sonnet Lead too" \
  "sed 's#lead-opus#lead-sonnet#' '$FIX/wf-strongpin-fanout.json' | bash '$NUDGE' | grep -q 'strong model pinned'"
mkdir -p "$FIX/repo-standard/.rolepod/evidence" "$FIX/repo-lite/.rolepod/evidence" "$FIX/process-cwd"
git -C "$FIX/repo-standard" init -q; git -C "$FIX/repo-lite" init -q
printf '{"workflow":{"mode":"standard"}}\n' > "$FIX/repo-standard/.rolepod/config.json"
printf '{"workflow":{"mode":"lite"}}\n' > "$FIX/repo-lite/.rolepod/config.json"
mkj "$FIX/wf-standard.json" Workflow "$FIX/lead-opus.jsonl" \
  '{"script":"phase(\"Verify\"); await parallel(fs.map((f) => () => agent(`verify ${f}`, {model: \"opus\", label: `verify:${f}`})))"}' "$FIX/repo-standard"
check "gate: payload cwd selects Standard from a different process cwd and denies" \
  "OUT=\$(cd '$FIX/process-cwd' && ROLEPOD_SESSION_MODE=standard ROLEPOD_SESSION_SOURCE=project ROLEPOD_SESSION_CLI=claude bash '$NUDGE' < '$FIX/wf-standard.json'); printf '%s' \"\$OUT\" | grep -q '\"deny\"'"
mkj "$FIX/wf-lite.json" Workflow "$FIX/lead-opus.jsonl" \
  '{"script":"phase(\"Verify\"); await parallel(fs.map((f) => () => agent(`verify ${f}`, {model: \"opus\", label: `verify:${f}`})))"}' "$FIX/repo-lite"
check "gate: Lite from payload cwd denies too" \
  "OUT=\$(cd '$FIX/process-cwd' && ROLEPOD_SESSION_MODE=lite ROLEPOD_SESSION_SOURCE=project ROLEPOD_SESSION_CLI=claude bash '$NUDGE' < '$FIX/wf-lite.json'); printf '%s' \"\$OUT\" | grep -q '\"deny\"'"
check "gate: agentType:'general-purpose' fan-out under an opus Lead → deny (platform agentType pins nothing, B-spec/B-standards)" \
  "GOUT=\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-gp-fanout.json'); printf '%s' \"\$GOUT\" | grep -q '\"deny\"' && printf '%s' \"\$GOUT\" | grep -q 'bare fan-out'"
GOUT=$(cd "$FIX/repo" && bash "$NUDGE" < "$FIX/wf-bare-writer.json")
check "gate: bare writer (no agentType on a writing stage) → deny (criterion 8)" \
  "printf '%s' \"\$GOUT\" | grep -q '\"deny\"' && printf '%s' \"\$GOUT\" | grep -q 'write-scope: bare agent() on writing stage' && grep -q '\"reason\": \"bare-writer\"' '$FIX/repo/.rolepod/evidence/phase-log.jsonl'"
check "gate: a single model-less agent() call, not a fan-out, not a writing stage → silent (no-tier nudge removed)" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-single-inherit.json')\" ]"
check "gate: an Agent-tool call → the hook does not run (Workflow-only matcher, criterion 8)" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/agent-call.json')\" ]"
check "gate: bare-fanout never yields — 3rd submission still denies" \
  "cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-bare-fanout.json' >/dev/null; bash '$NUDGE' < '$FIX/wf-bare-fanout.json' >/dev/null; bash '$NUDGE' < '$FIX/wf-bare-fanout.json' | grep -q '\"deny\"'"
check "gate: bare-writer never yields — 3rd submission still denies" \
  "cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-bare-writer.json' >/dev/null; bash '$NUDGE' < '$FIX/wf-bare-writer.json' >/dev/null; bash '$NUDGE' < '$FIX/wf-bare-writer.json' | grep -q '\"deny\"'"
check "gate: obsolete nudge.enabled has no effect on Full" \
  "OUT=\$(cd '$FIX/repo' && HOME='$FIX/home-nudge-off' bash '$NUDGE' < '$FIX/wf-bare-fanout.json'); printf '%s' \"\$OUT\" | grep -q '\"deny\"'"
check "gate: obsolete gates.mode=off has no effect on Full" \
  "OUT=\$(cd '$FIX/repo' && HOME='$FIX/home-off' bash '$NUDGE' < '$FIX/wf-bare-fanout.json'); printf '%s' \"\$OUT\" | grep -q '\"deny\"'"
check "gate: the old ROLEPOD_GATES_SOFT / ROLEPOD_NUDGE_OFF env change nothing" \
  "OUT=\$(cd '$FIX/repo' && ROLEPOD_GATES_SOFT=1 ROLEPOD_NUDGE_OFF=1 bash '$NUDGE' < '$FIX/wf-bare-fanout.json') && printf '%s' \"\$OUT\" | grep -q '\"deny\"'"
check "gate: a deny names no env or config key" \
  "OUT=\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-bare-fanout.json') && ! printf '%s' \"\$OUT\" | grep -q 'ROLEPOD_\\|config'"


# ── auto-log: the model of the call (no strong-role floor row since the 4-type roster) ────
mkj "$FIX/rev-opus-explicit.json" Agent "$FIX/lead-sonnet.jsonl" '{"subagent_type":"rolepod:rolepod-reviewer","model":"opus","prompt":"review"}'
mkj "$FIX/rev-sonnet.json" Agent "$FIX/lead-sonnet.jsonl" '{"subagent_type":"rolepod:rolepod-reviewer","prompt":"review"}'
LOG="$REPO_DIR/hooks/dispatch-auto-log.sh"
check "auto-log: an explicit model=opus on the call is logged as the model, with no floor row" \
  "cd '$FIX/repo' && bash '$LOG' < '$FIX/rev-opus-explicit.json' && tail -1 .rolepod/evidence/phase-log.jsonl | grep -q '\"model\": \"opus\"' && ! tail -1 .rolepod/evidence/phase-log.jsonl | grep -q floor"
check "auto-log: a model-less reviewer call logs model=inherit, no opus assumed, no floor row" \
  "cd '$FIX/repo' && bash '$LOG' < '$FIX/rev-sonnet.json' && tail -1 .rolepod/evidence/phase-log.jsonl | grep -q '\"model\": \"inherit\"' && ! tail -1 .rolepod/evidence/phase-log.jsonl | grep -q floor"
mkj "$FIX/rev-downgrade.json" Agent "$FIX/lead-sonnet.jsonl" '{"subagent_type":"rolepod:rolepod-reviewer","model":"sonnet","prompt":"review"}'
check "auto-log: an explicit low model on a reviewer call logs that model, no floor=missed row" \
  "cd '$FIX/repo' && bash '$LOG' < '$FIX/rev-downgrade.json' && tail -1 .rolepod/evidence/phase-log.jsonl | grep -q '\"model\": \"sonnet\"' && ! tail -1 .rolepod/evidence/phase-log.jsonl | grep -q floor"
# (unused leftover fixture below — its escaped-quote literal defeats this
# file's exact-match editor; left inert rather than risk a corrupted line;
# the check that used to read it is gone, per Desired 8)
mkj "$FIX/wf-gp-prose.json"   Workflow "$FIX/lead-opus.jsonl"   '{"name":"gp-prose","script":"await agent(`rewrite each sweep call with agentType: \u0027rolepod:scout\u0027`); await agent(2); await agent(3)"}'

# ── context-bloat check (v2.49.0) — rides the UserPromptSubmit hook ────────
CVN="$REPO_DIR/hooks/claim-verify-nudge.sh"
printf '{"type":"assistant","timestamp":"2026-08-18T01:00:00.000Z","message":{"model":"claude-opus-5","usage":{"input_tokens":2,"cache_read_input_tokens":574899,"cache_creation_input_tokens":1055,"output_tokens":10},"content":[]}}\n' > "$FIX/ctx-big.jsonl"
printf '{"type":"assistant","timestamp":"2026-08-18T01:00:00.000Z","message":{"model":"claude-opus-5","usage":{"input_tokens":2,"cache_read_input_tokens":120000,"cache_creation_input_tokens":1000,"output_tokens":10},"content":[]}}\n' > "$FIX/ctx-small.jsonl"
mkdir -p "$FIX/home"
check "context-check: 575k context → additionalContext for the Lead only (no user-facing systemMessage, v2.49.1)" \
  "printf '{\"session_id\":\"c1\",\"transcript_path\":\"$FIX/ctx-big.jsonl\",\"prompt\":\"fix the button\"}' | HOME='$FIX/home' bash '$CVN' | python3 -c 'import json,sys; o=json.load(sys.stdin); a=o[\"hookSpecificOutput\"][\"additionalContext\"]; assert \"575k\" in a and \"scout\" in a and \"/compact\" in a and \"systemMessage\" not in o'"
check "context-check: still above the line in the same session → silent (one crossing = one note)" \
  "! printf '{\"session_id\":\"c1\",\"transcript_path\":\"$FIX/ctx-big.jsonl\",\"prompt\":\"fix the button\"}' | HOME='$FIX/home' bash '$CVN' | grep -q context-check"
check "context-check: 121k context + a question prompt → completely silent (read-first nudge removed v2.163.0)" \
  "[ -z \"\$(printf '{\"session_id\":\"c2\",\"transcript_path\":\"$FIX/ctx-small.jsonl\",\"prompt\":\"why is this broken\"}' | HOME='$FIX/home' bash '$CVN')\" ]"
printf '{"type":"assistant","timestamp":"2026-08-18T01:00:00.000Z","message":{"model":"claude-opus-5","usage":{"input_tokens":2,"cache_read_input_tokens":250000,"cache_creation_input_tokens":1000,"output_tokens":10},"content":[]}}\n' > "$FIX/ctx-mid.jsonl"
check "context-check: 251k context → silent — the line is 400k, not the old 200k pricing knee (v2.119.1, moved 500k→400k 2026-09-28)" \
  "! printf '{\"session_id\":\"c4\",\"transcript_path\":\"$FIX/ctx-mid.jsonl\",\"prompt\":\"fix the button\"}' | HOME='$FIX/home' bash '$CVN' | grep -q context-check"
printf '{"type":"assistant","timestamp":"2026-08-18T01:00:00.000Z","message":{"model":"claude-opus-5","usage":{"input_tokens":100,"cache_read_input_tokens":449900,"cache_creation_input_tokens":0,"output_tokens":10},"content":[]}}\n' > "$FIX/ctx-450k.jsonl"
check "context-check: 450k context → one note fires (line moved 500k→400k, 2026-09-28)" \
  "printf '{\"session_id\":\"c5\",\"transcript_path\":\"$FIX/ctx-450k.jsonl\",\"prompt\":\"fix the button\"}' | HOME='$FIX/home' bash '$CVN' | python3 -c 'import json,sys; o=json.load(sys.stdin); a=o[\"hookSpecificOutput\"][\"additionalContext\"]; assert \"450k\" in a and \"context-check\" in a'"
check "context-check: 121k in session c1 after the note → silent, and the line re-arms (a /compact brought it under)" \
  "! printf '{\"session_id\":\"c1\",\"transcript_path\":\"$FIX/ctx-small.jsonl\",\"prompt\":\"fix the button\"}' | HOME='$FIX/home' bash '$CVN' | grep -q context-check && [ ! -f '$FIX/home/.rolepod/ctx-nudge/c1' ]"
check "context-check: 575k in session c1 again → one more note (crossed the line a second time)" \
  "printf '{\"session_id\":\"c1\",\"transcript_path\":\"$FIX/ctx-big.jsonl\",\"prompt\":\"fix the button\"}' | HOME='$FIX/home' bash '$CVN' | python3 -c 'import json,sys; a=json.load(sys.stdin)[\"hookSpecificOutput\"][\"additionalContext\"]; assert \"context-check\" in a and \"575k\" in a and \"THIS turn\" in a'"
check "context-check: the note ends with the mid-plan sentence and stays under 600 chars" \
  "printf '{\"session_id\":\"c9\",\"transcript_path\":\"$FIX/ctx-450k.jsonl\",\"prompt\":\"why is the button red\"}' | HOME='$FIX/home' bash '$CVN' | python3 -c 'import json,sys; a=json.load(sys.stdin)[\"hookSpecificOutput\"][\"additionalContext\"]; assert \"Mid-plan: say it in your next progress line and keep working; never end the turn for it.\" in a and len(a) < 600, len(a)'"
check "context-check: big context + a question prompt → context note fires alone (read-first nudge removed v2.163.0)" \
  "printf '{\"session_id\":\"c3\",\"transcript_path\":\"$FIX/ctx-big.jsonl\",\"prompt\":\"why is this broken\"}' | HOME='$FIX/home' bash '$CVN' | python3 -c 'import json,sys; o=json.load(sys.stdin); a=o[\"hookSpecificOutput\"][\"additionalContext\"]; assert \"context-check\" in a'"
check "context-check: no transcript, no session id → hook exits cleanly, no crash (read-first nudge removed v2.163.0)" \
  "printf '{\"prompt\":\"why is this broken\"}' | HOME='$FIX/home' bash '$CVN'"
check "session_state context-tokens reads input+cache_read+cache_creation of the last turn" \
  "[ \"\$(printf '{\"transcript_path\":\"$FIX/ctx-big.jsonl\"}' | python3 '$REPO_DIR/hooks/lib/session_state.py' context-tokens)\" = 575956 ]"

# v2.180.10 — external review mode split (Task 5): a phase:review,
# reviewer:external row with mode:adversarial counts apart from one with no
# mode key (standard), on the "strong pass source" line.
AMIX="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-evtools-amix.XXXXXX")"
mkdir -p "$AMIX/repo/.rolepod/evidence"
git -C "$AMIX/repo" init -q
cat > "$AMIX/repo/.rolepod/evidence/phase-log.jsonl" <<'EOF'
{"ts":"2026-09-28T01:00:00Z","phase":"review","reviewer":"external","kind":"review","cli":"codex","family":"openai","mode":"adversarial","lead":"claude"}
{"ts":"2026-09-28T01:05:00Z","phase":"review","reviewer":"external","kind":"review","cli":"codex","family":"openai","lead":"claude"}
EOF
OUT=$(HOME="$AMIX" bash "$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh" "$AMIX/repo")
check "stats splits external reviews by mode (adversarial vs standard)" \
  "printf '%s' \"\$OUT\" | grep -q 'external review mode: adversarial 1 · standard 1'"
rm -rf "$AMIX"

# T5 Task 4 — Lead turns (main session, deduped, 14d), gate / write-scope / external verdict tables.
# Own repo + HOME: write-scope rows carry provenance hook-auto, which the dispatch auto-log count above pins.
XT="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-evtools-xt.XXXXXX")"
mkdir -p "$XT/repo/.rolepod/evidence"
git -C "$XT/repo" init -q
cat > "$XT/repo/.rolepod/evidence/phase-log.jsonl" <<'EOF'
{"ts":"2026-10-01T01:00:00+00:00","phase":"gate","decision":"soft","tests":1,"risk":2,"reviewers":0,"strong":0,"head":"aaaaaaa1111111"}
{"ts":"2026-10-01T02:00:00+00:00","phase":"gate","decision":"pass","tests":1,"risk":1,"reviewers":1,"strong":1,"head":"bbbbbbb2222222"}
{"ts":"2026-10-01T03:00:00+00:00","phase":"gate","decision":"pass","tests":1,"risk":0,"reviewers":0,"strong":0,"head":"ccccccc3333333"}
{"ts":"2026-10-01T04:00:00+00:00","phase":"gate","decision":"deny","tests":0,"risk":3,"reviewers":0,"strong":0,"head":"ddddddd4444444"}
{"ts":"2026-10-01T05:00:00Z","phase":"write-scope","class":"read-only","agent_type":"rolepod:scout","tool":"Write","path":"a.py","decision":"deny","provenance":"hook-auto"}
{"ts":"2026-10-01T05:01:00Z","phase":"write-scope","class":"read-only","agent_type":"rolepod:scout","tool":"Edit","path":"b.py","decision":"deny","provenance":"hook-auto"}
{"ts":"2026-10-01T05:02:00Z","phase":"write-scope","class":"test-only","agent_type":"rolepod:qa-tester","tool":"Write","path":"c.py","decision":"deny","provenance":"hook-auto"}
{"ts":"2026-10-01T06:00:00Z","phase":"review","reviewer":"external","kind":"review","cli":"codex","family":"openai","secs":30,"budget":600,"brief_sha":"x","verdict":"APPROVED"}
{"ts":"2026-10-01T06:10:00Z","phase":"review","reviewer":"external","kind":"review","cli":"codex","family":"openai","secs":50,"budget":600,"brief_sha":"x","verdict":"REJECTED"}
{"ts":"2026-10-01T06:20:00Z","phase":"review","reviewer":"external","kind":"review","cli":"codex","family":"openai","secs":90,"budget":600,"brief_sha":"x","verdict":"APPROVED"}
{"ts":"2026-10-01T06:30:00Z","phase":"review","reviewer":"external","kind":"review","cli":"antigravity","family":"google","secs":70,"budget":600,"brief_sha":"x","verdict":"none"}
{"ts":"2026-10-01T06:40:00Z","phase":"consult","reviewer":"external","kind":"consult","cli":"codex","family":"openai","secs":5,"budget":600,"brief_sha":"x"}
{"ts":"2026-10-01T07:00:00Z","phase":"dispatch-proof","model":"zzproofmodel","agent":"scout","provenance":"hook-auto"}
EOF
XKEY="$(cd "$XT/repo" && pwd -P | tr "/" "-")"; XPROJ="$XT/.claude/projects/$XKEY"; mkdir -p "$XPROJ"
XNOW="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
# one API call as 3 rows sharing message.id counts once; a second call; a <synthetic> row is skipped
for BLK in thinking text tool_use; do printf '{"type":"assistant","timestamp":"%s","message":{"id":"msg_lead1","model":"claude-opus-5","usage":{"output_tokens":20},"content":[{"type":"%s"}]}}\n' "$XNOW" "$BLK"; done > "$XPROJ/lead1.jsonl"
printf '{"type":"assistant","timestamp":"%s","message":{"id":"msg_lead2","model":"claude-sonnet-5","usage":{"output_tokens":5},"content":[]}}\n{"type":"assistant","timestamp":"%s","message":{"id":"msg_syn","model":"<synthetic>","usage":{"output_tokens":0},"content":[]}}\n' "$XNOW" "$XNOW" >> "$XPROJ/lead1.jsonl"
# a main-session file older than 14 days is not counted (5 distinct calls that would show opus ×6)
for N in 1 2 3 4 5; do printf '{"type":"assistant","timestamp":"2020-01-01T00:00:00.000Z","message":{"id":"msg_old%s","model":"claude-opus-5","usage":{"output_tokens":9},"content":[]}}\n' "$N"; done > "$XPROJ/old.jsonl"
touch -t 202001010000 "$XPROJ/old.jsonl"
XOUT=$(HOME="$XT" bash "$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh" "$XT/repo")
# a resumed session copies lead1's history into a second file: the same ids must not count twice
cp "$XPROJ/lead1.jsonl" "$XPROJ/lead2.jsonl"
XOUT2=$(HOME="$XT" bash "$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh" "$XT/repo")
check "stats Lead turns: one API call written as 3 rows counts once, <synthetic> skipped, a file older than 14d ignored" \
  "printf '%s' \"\$XOUT\" | grep -q 'Lead turns — main session transcripts (last 14d, 1 session(s), 2 turns' && printf '%s' \"\$XOUT\" | grep -q 'opus ×1 · sonnet ×1' && ! printf '%s' \"\$XOUT\" | grep -q 'opus ×6'"
check "stats gate table: a soft row with risk>0 and strong=0 is listed as parent <sha7>" \
  "printf '%s' \"\$XOUT\" | grep -q 'parent aaaaaaa'"
check "stats gate table: a strong=1 row, a risk=0 row and a deny row are not listed" \
  "! printf '%s' \"\$XOUT\" | grep -q 'parent bbbbbbb' && ! printf '%s' \"\$XOUT\" | grep -q 'parent ccccccc' && ! printf '%s' \"\$XOUT\" | grep -q 'parent ddddddd' && printf '%s' \"\$XOUT\" | grep -q 'strong = 0 on a committed row (1;'"
check "stats write-scope: denies per agent_type, rolepod: stripped" \
  "printf '%s' \"\$XOUT\" | grep -q 'Write-scope denies (3): scout ×2 · qa-tester ×1'"
check "stats external verdicts: count per verdict (consult row excluded) and median secs per cli" \
  "printf '%s' \"\$XOUT\" | grep -q 'External review verdicts (4): APPROVED ×2 · REJECTED ×1 · none ×1' && printf '%s' \"\$XOUT\" | grep -q 'median secs: antigravity 70 (n=1) · codex 50 (n=3)'"
check "stats ignores a dispatch-proof row: nothing of it is printed" \
  "! printf '%s' \"\$XOUT\" | grep -qi 'dispatch-proof\|model proof\|zzproofmodel'"
check "stats Lead turns: a second main-session file repeating message ids counts them once across files (still 2 turns)" \
  "printf '%s' \"\$XOUT2\" | grep -q 'Lead turns — main session transcripts (last 14d, 2 session(s), 2 turns' && printf '%s' \"\$XOUT2\" | grep -q 'opus ×1 · sonnet ×1'"
rm -rf "$XT"
# six flagged gate rows: only the newest five are shown
XG="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-evtools-xg.XXXXXX")"
mkdir -p "$XG/repo/.rolepod/evidence"; git -C "$XG/repo" init -q
for N in 1 2 3 4 5 6; do printf '{"ts":"2026-10-0%sT01:00:00+00:00","phase":"gate","decision":"soft","tests":1,"risk":2,"reviewers":0,"strong":0,"head":"%s%s%s%s%s%s%s222"}\n' "$N" "$N" "$N" "$N" "$N" "$N" "$N" "$N"; done > "$XG/repo/.rolepod/evidence/phase-log.jsonl"
XGOUT=$(HOME="$XG" bash "$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh" "$XG/repo")
check "stats gate table: 6 flagged rows → count 6, newest 5 shown, the oldest (parent 1111111) is cut" \
  "printf '%s' \"\$XGOUT\" | grep -q 'strong = 0 on a committed row (6; newest 5 shown' && printf '%s' \"\$XGOUT\" | grep -q 'parent 6666666' && printf '%s' \"\$XGOUT\" | grep -q 'parent 2222222' && ! printf '%s' \"\$XGOUT\" | grep -q 'parent 1111111'"
rm -rf "$XG"
# a verdict row with no numeric secs: the verdict count prints, a bare "median secs:" never does
XS="$(mktemp -d "${TMPDIR:-/tmp}/rolepod-evtools-xs.XXXXXX")"
mkdir -p "$XS/repo/.rolepod/evidence"; git -C "$XS/repo" init -q
printf '{"ts":"2026-10-01T06:00:00Z","phase":"review","reviewer":"external","kind":"review","cli":"codex","family":"openai","budget":600,"brief_sha":"x","verdict":"APPROVED"}\n' > "$XS/repo/.rolepod/evidence/phase-log.jsonl"
XSOUT=$(HOME="$XS" bash "$REPO_DIR/core/skills/rolepod-stats/scripts/stats.sh" "$XS/repo")
check "stats external verdicts: a row without secs prints no median secs line" \
  "printf '%s' \"\$XSOUT\" | grep -q 'External review verdicts (1): APPROVED ×1' && ! printf '%s' \"\$XSOUT\" | grep -q 'median secs:'"
rm -rf "$XS"

# The jsonl content scan stays capped at 60: 62 plain agent transcripts each
# holding one test-file edit -> only the 60 newest are read (test_edits=60).
# Review evidence is not scanned here: a security-engineer dispatch or a
# Workflow agent meta.json counts nothing, only a lens report file does.
JSCAP=$(python3 -I - "$REPO_DIR/hooks/lib" "$FIX" <<'PYEOF'
import json, os, sys, time
sys.path.insert(0, sys.argv[1])
import session_state as ss

now = time.time()
base = os.path.join(sys.argv[2], "jscap")
sub = os.path.join(base, "s1", "subagents")
os.makedirs(sub)
tp = os.path.join(base, "s1.jsonl")
with open(tp, "w") as f:
    f.write(json.dumps({"type": "user", "message": {"role": "user", "content": "hi"}}) + "\n")
ev = {"type": "assistant", "message": {"role": "assistant", "content": [
    {"type": "tool_use", "name": "Edit", "input": {"file_path": "tests/test_x.py"}},
    {"type": "tool_use", "name": "Agent", "input": {"subagent_type": "rolepod:security-engineer", "prompt": "review"}}]}}
for i in range(62):
    j = os.path.join(sub, "agent-j%03d.jsonl" % i)
    with open(j, "w") as f:
        f.write(json.dumps(ev) + "\n")
    os.utime(j, (now - 4000 + i, now - 4000 + i))
print(ss.count_all(tp, now - 10000)[0])
PYEOF
)
check "commit gate: the agent-transcript content scan stays capped at 60 (62 files -> test_edits=60)" \
  "[ \"\$JSCAP\" = '60' ]"

exit $fail
