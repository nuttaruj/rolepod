#!/bin/bash
# evidence-tools — locks the two evidence readers:
#   scripts/stats.sh          (phase-log/bypass observational readout)
#   scripts/junit-summary.sh  (JUnit XML → counted pass/fail + failed names)
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

# ── stats.sh ────────────────────────────────────────────────────────────
mkdir -p "$FIX/repo/.rolepod/evidence"
git -C "$FIX/repo" init -q
cat > "$FIX/repo/.rolepod/evidence/phase-log.jsonl" <<'EOF'
{"ts":"2026-07-31T01:00:00Z","phase":"route","tier":"R2","skill":"implement-plan"}
{"ts":"2026-07-31T01:05:00Z","phase":"route","tier":"R3","skill":"write-spec"}
{"ts":"2026-07-31T01:10:00Z","phase":"verify","verdict":"pass","evidence":"pytest -q"}
{"ts":"2026-07-31T01:20:00Z","phase":"verify","verdict":"fail","evidence":"pytest -q"}
{"ts":"2026-07-31T01:30:00Z","phase":"review","verdict":"APPROVED","blockers":0}
{"ts":"2026-07-31T01:40:00Z","phase":"ship","action":"pr"}
{"ts":"2026-07-31T01:45:00Z","phase":"dispatch","tier":"strong","override":"opus"}
{"ts":"2026-07-31T01:50:00Z","phase":"dispatch","tier":"strong","override":"none"}
{"ts":"2026-07-31T01:55:00Z","phase":"dispatch-proof","cli":"codex","agent_type":"qa-tester","model":"gpt-5.6-terra","provenance":"hook-stdin"}
{"ts":"2026-07-31T01:56:00Z","phase":"dispatch-proof","cli":"antigravity","agent_type":"","model":"gemini-3-pro","provenance":"hook-stdin"}
{"ts":"2026-07-31T01:57:00Z","phase":"dispatch","cli":"claude","tool":"Agent","provenance":"hook-auto","agent_type":"rolepod:scout","model":"inherit","override":"none"}
not json — must be skipped, not crash
EOF
printf '{"ts":"2026-07-31T01:15:00Z","hook":"precommit-gate","var":"ROLEPOD_GATES_SOFT","reason":"unreasoned"}\n' \
  > "$FIX/repo/.rolepod/evidence/bypass.log"

OUT=$(bash "$REPO_DIR/scripts/stats.sh" "$FIX/repo")
check "stats reports tier distribution"   "printf '%s' \"\$OUT\" | grep -q 'R2'"
check "stats reports verify fail rate"    "printf '%s' \"\$OUT\" | grep -q 'fail=1'"
check "stats reports review verdicts"     "printf '%s' \"\$OUT\" | grep -q 'APPROVED: 1'"
check "stats flags unreasoned bypasses"   "printf '%s' \"\$OUT\" | grep -q 'unreasoned'"
check "stats audits strong dispatches"    "printf '%s' \"\$OUT\" | grep -q 'Strong dispatches (2): 1 with explicit override, 1 inherit'"
check "stats reports hook-reported model proof" "printf '%s' \"\$OUT\" | grep -q 'Model proof — hook-reported (2'"
check "stats shows proof per cli+model"   "printf '%s' \"\$OUT\" | grep -q 'gpt-5.6-terra'"
printf '{"agent_type":"qa","model":"m1"}' > "$FIX/subagent-stop.json"
check "codex model-log hook is fail-open outside a repo" \
  "cd /tmp && bash '$REPO_DIR/adapters/codex/plugins/rolepod/hooks/subagent-model-log.sh' < '$FIX/subagent-stop.json'"
check "stats names the silent downgrade"  "printf '%s' \"\$OUT\" | grep -q 'silent downgrade'"
check "stats reports hook-auto dispatch intent" "printf '%s' \"\$OUT\" | grep -q 'Dispatch intent — hook-auto (1'"
check "stats flags hook-auto inherit"     "printf '%s' \"\$OUT\" | grep -q 'inherited the Lead'"
check "stats survives malformed lines"    "bash '$REPO_DIR/scripts/stats.sh' '$FIX/repo'"
# HOME sandboxed: stats also reads the machine-global ~/.rolepod/gate-bypass.log
# (v2.46.0) — the real machine's log must not leak into the empty-repo case.
OUT=$(HOME="$FIX" bash "$REPO_DIR/scripts/stats.sh" "$FIX")
check "stats handles empty repo (no data)" "printf '%s' \"\$OUT\" | grep -q 'no data yet'"

# v2.46.0: precommit auto-passes surface in stats, risky ones flagged.
mkdir -p "$FIX/.rolepod"
printf '2026-08-15T10:00:00 auto-pass on evidence (tests=1 reviewers=0 strong=0 risk=none): git commit -m x\n' \
  > "$FIX/.rolepod/gate-bypass.log"
printf '2026-08-15T10:05:00 auto-pass on evidence (tests=0 reviewers=1 strong=1 risk=auth/login.py): git commit -m y\n' \
  >> "$FIX/.rolepod/gate-bypass.log"
OUT=$(HOME="$FIX" bash "$REPO_DIR/scripts/stats.sh" "$FIX")
check "stats surfaces precommit auto-passes"      "printf '%s' \"\$OUT\" | grep -q 'Precommit auto-passes (2'"
check "stats flags the risky auto-pass (not the risk=none one)" "printf '%s' \"\$OUT\" | grep -q 'HIGH-RISK diff (labeled, v2.46+): 1'"
printf '2026-08-10T10:00:00 auto-pass on evidence (tests=3 reviewers=2): git commit -m old\n' >> "$FIX/.rolepod/gate-bypass.log"
OUT=$(HOME="$FIX" bash "$REPO_DIR/scripts/stats.sh" "$FIX")
check "stats reports pre-v2.46 unlabeled auto-passes separately (not as high-risk)" \
  "printf '%s' \"\$OUT\" | grep -q 'HIGH-RISK diff (labeled, v2.46+): 1' && printf '%s' \"\$OUT\" | grep -q 'pre-v2.46 unlabeled.*: 1'"

# ── claude dispatch hooks (tier nudge + auto-log) ───────────────────────
printf '{"tool_name":"Workflow","tool_input":{"script":"await agent(1)"}}' > "$FIX/wf-inherit.json"
printf '{"tool_name":"Workflow","tool_input":{"script":"await agent(1, {model: 1})"}}' > "$FIX/wf-tiered.json"
printf '{"tool_name":"Agent","tool_input":{"subagent_type":"rolepod:scout"}}' > "$FIX/agent-scout.json"
check "tier nudge fires on override-less Workflow fan-out" \
  "bash '$REPO_DIR/hooks/workflow-tier-nudge.sh' < '$FIX/wf-inherit.json' | grep -q additionalContext"
check "tier nudge silent when a per-stage override exists" \
  "[ -z \"\$(bash '$REPO_DIR/hooks/workflow-tier-nudge.sh' < '$FIX/wf-tiered.json')\" ]"
printf '{"tool_name":"Agent","tool_input":{"subagent_type":"Explore"}}' > "$FIX/agent-explore.json"
check "tier nudge fires on model-less platform sweep Agent (Explore)" \
  "bash '$REPO_DIR/hooks/workflow-tier-nudge.sh' < '$FIX/agent-explore.json' | grep -q additionalContext"
check "tier nudge silent on rolepod:scout (frontmatter-pinned cheap — was a false nudge)" \
  "[ -z \"\$(bash '$REPO_DIR/hooks/workflow-tier-nudge.sh' < '$FIX/agent-scout.json')\" ]"
check "tier nudge honors ROLEPOD_NUDGE_OFF" \
  "[ -z \"\$(ROLEPOD_NUDGE_OFF=1 bash '$REPO_DIR/hooks/workflow-tier-nudge.sh' < '$FIX/wf-inherit.json')\" ]"
check "dispatch auto-log appends a hook-auto line" \
  "cd '$FIX/repo' && bash '$REPO_DIR/hooks/dispatch-auto-log.sh' < '$FIX/agent-scout.json' && grep -c 'hook-auto' .rolepod/evidence/phase-log.jsonl | grep -q 2"
check "dispatch auto-log is fail-open outside a repo" \
  "cd /tmp && bash '$REPO_DIR/hooks/dispatch-auto-log.sh' < '$FIX/agent-scout.json'"

# ── v2.47.0: Lead-aware nudge + strong-role floor + honest "mixed" ────────
printf '{"type":"assistant","timestamp":"2026-08-17T01:00:00.000Z","message":{"model":"claude-sonnet-5","content":[]}}\n' > "$FIX/lead-sonnet.jsonl"
printf '{"type":"assistant","timestamp":"2026-08-17T01:00:00.000Z","message":{"model":"claude-fable-5","content":[]}}\n' > "$FIX/lead-fable.jsonl"
printf '{"type":"assistant","timestamp":"2026-08-17T01:00:00.000Z","message":{"model":"claude-nova-9","content":[]}}\n' > "$FIX/lead-unknown.jsonl"
mkj() { # $1 out, $2 tool, $3 transcript, $4 tool_input json
  printf '{"tool_name":"%s","transcript_path":"%s","tool_input":%s}' "$2" "$3" "$4" > "$1"
}
mkj "$FIX/rev-sonnet.json"  Agent "$FIX/lead-sonnet.jsonl"  '{"subagent_type":"rolepod:universal-reviewer","prompt":"review"}'
mkj "$FIX/sec-sonnet.json"  Agent "$FIX/lead-sonnet.jsonl"  '{"subagent_type":"security-engineer","prompt":"audit"}'
mkj "$FIX/rev-fable.json"   Agent "$FIX/lead-fable.jsonl"   '{"subagent_type":"rolepod:universal-reviewer","prompt":"review"}'
mkj "$FIX/rev-unknown.json" Agent "$FIX/lead-unknown.jsonl" '{"subagent_type":"rolepod:universal-reviewer","prompt":"review"}'
mkj "$FIX/rev-explicit.json" Agent "$FIX/lead-fable.jsonl"  '{"subagent_type":"rolepod:universal-reviewer","model":"sonnet","prompt":"review"}'
mkj "$FIX/arch-sonnet.json" Agent "$FIX/lead-sonnet.jsonl"  '{"subagent_type":"rolepod:system-architect","prompt":"design"}'
mkj "$FIX/wf-effort.json"   Workflow "$FIX/lead-sonnet.jsonl" '{"script":"name: \"w\" await agent(1, {effort: \"high\"})"}'
mkj "$FIX/wf-strong.json"   Workflow "$FIX/lead-fable.jsonl"  '{"script":"name: \"w\" await agent(1)"}'
NUDGE="$REPO_DIR/hooks/workflow-tier-nudge.sh"
check "floor: universal-reviewer + sonnet Lead → allow + updatedInput model=opus" \
  "bash '$NUDGE' < '$FIX/rev-sonnet.json' | python3 -c 'import json,sys; o=json.load(sys.stdin)[\"hookSpecificOutput\"]; assert o[\"permissionDecision\"]==\"allow\" and o[\"updatedInput\"][\"model\"]==\"opus\" and o[\"updatedInput\"][\"prompt\"]==\"review\"'"
check "floor: bare security-engineer name is lifted too" \
  "bash '$NUDGE' < '$FIX/sec-sonnet.json' | grep -q '\"updatedInput\"'"
check "floor: fable Lead → untouched (never pin a stronger session down)" \
  "[ -z \"\$(bash '$NUDGE' < '$FIX/rev-fable.json')\" ]"
check "floor: unknown Lead family → untouched (fail = no upgrade, never a downgrade)" \
  "[ -z \"\$(bash '$NUDGE' < '$FIX/rev-unknown.json')\" ]"
check "floor: explicit model=sonnet on a strong role → named, not rewritten" \
  "bash '$NUDGE' < '$FIX/rev-explicit.json' | grep -q 'EXPLICIT downgrade' && ! bash '$NUDGE' < '$FIX/rev-explicit.json' | grep -q updatedInput"
check "floor honors ROLEPOD_NUDGE_OFF" \
  "[ -z \"\$(ROLEPOD_NUDGE_OFF=1 bash '$NUDGE' < '$FIX/rev-sonnet.json')\" ]"
check "system-architect under sonnet Lead → nudge only (cohesion may deny it)" \
  "bash '$NUDGE' < '$FIX/arch-sonnet.json' | grep -q 'system-architect' && ! bash '$NUDGE' < '$FIX/arch-sonnet.json' | grep -q updatedInput"
check "nudge: effort-only Workflow is NOT a tier choice → still nudged, Lead-aware" \
  "bash '$NUDGE' < '$FIX/wf-effort.json' | grep -q 'effort is depth' && bash '$NUDGE' < '$FIX/wf-effort.json' | grep -q 'claude-sonnet-5'"
check "nudge: model-less Workflow under a strong Lead → cost wording (pin build to sonnet)" \
  "bash '$NUDGE' < '$FIX/wf-strong.json' | grep -q \"model:'sonnet'\""
# ── v2.48.0: fleet-tier gate — deny a model-less fan-out under a strong Lead ──
printf '{"type":"assistant","timestamp":"2026-08-17T01:00:00.000Z","message":{"model":"claude-opus-5","content":[]}}\n' > "$FIX/lead-opus.jsonl"
mkj "$FIX/wf-opus-bare.json"    Workflow "$FIX/lead-opus.jsonl"    '{"script":"name: \"fleet\" await agent(1); await agent(2); await agent(3)"}'
mkj "$FIX/wf-fable-bare.json"   Workflow "$FIX/lead-fable.jsonl"   '{"script":"await agent(1)"}'
mkj "$FIX/wf-unknown-bare.json" Workflow "$FIX/lead-unknown.jsonl" '{"script":"await agent(1)"}'
mkj "$FIX/wf-opus-reason.json"  Workflow "$FIX/lead-opus.jsonl"    '{"script":"// fleet-inherit: every stage is adversarial judgment\nawait agent(1)"}'
mkj "$FIX/wf-opus-atype.json"   Workflow "$FIX/lead-opus.jsonl"    '{"script":"await agent(1, {agentType: \"rolepod:frontend-developer\"})"}'
mkj "$FIX/wf-opus-model.json"   Workflow "$FIX/lead-opus.jsonl"    '{"script":"await agent(1, {model: \"sonnet\"}); await agent(2)"}'
mkj "$FIX/wf-opus-noagent.json" Workflow "$FIX/lead-opus.jsonl"    '{"script":"log(1)"}'
GOUT=$(cd "$FIX/repo" && bash "$NUDGE" < "$FIX/wf-opus-bare.json")
check "gate: opus Lead + model-less fan-out → deny naming the per-stage fix" \
  "printf '%s' \"\$GOUT\" | grep -q '\"permissionDecision\": \"deny\"' && printf '%s' \"\$GOUT\" | grep -q \"model:'sonnet'\" && printf '%s' \"\$GOUT\" | grep -q '3 agent() call'"
check "gate: fable Lead → deny too (strong class)" \
  "cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-fable-bare.json' | grep -q '\"deny\"'"
GOUT=$(cd "$FIX/repo" && bash "$NUDGE" < "$FIX/wf-unknown-bare.json")
check "gate: unknown non-empty family → deny (assumed strong for cost)" \
  "printf '%s' \"\$GOUT\" | grep -q '\"deny\"' && printf '%s' \"\$GOUT\" | grep -q 'unknown family'"
# v2.50.0 — the escape hatch closes: sonnet pasted on every stage / judge below the Lead
mkj "$FIX/wf-mono-stages.json" Workflow "$FIX/lead-opus.jsonl" '{"script":"phase(\"Audit\"); await agent(1,{model:\"sonnet\"}); phase(\"Verify findings\"); await agent(2,{model:\"sonnet\"}); phase(\"Fix\"); await agent(3,{model:\"sonnet\"})"}'
mkj "$FIX/wf-mono-1stage.json" Workflow "$FIX/lead-opus.jsonl" '{"script":"await agent(1,{model:\"sonnet\"}); await agent(2,{model:\"sonnet\"})"}'
mkj "$FIX/wf-judge-low.json"   Workflow "$FIX/lead-opus.jsonl" '{"script":"name: \"refund-audit\" await agent(1,{model:\"haiku\", label:\"sweep:a\", prompt:\"find refund paths\"}); await agent(2,{model:\"sonnet\", label:\"rank:all\"})"}'
mkj "$FIX/wf-judge-routine.json" Workflow "$FIX/lead-opus.jsonl" '{"script":"name: \"i18n-audit\" await agent(1,{model:\"haiku\", label:\"sweep:a\", prompt:\"find hard-coded Thai strings\"}); await agent(2,{model:\"sonnet\", label:\"rank:all\"})"}'
mkj "$FIX/wf-judge-ok.json"    Workflow "$FIX/lead-opus.jsonl" '{"script":"await agent(1,{model:\"haiku\", label:\"sweep:a\"}); await agent(2,{model:\"opus\", label:\"rank:all\"})"}'
mkj "$FIX/wf-judge-role.json"  Workflow "$FIX/lead-opus.jsonl" '{"script":"phase(\"Build\"); await agent(1,{model:\"sonnet\"}); phase(\"Review\"); await agent(2,{agentType:\"rolepod:universal-reviewer\"})"}'
mkj "$FIX/wf-mono-reason.json" Workflow "$FIX/lead-opus.jsonl" '{"script":"// tier-reason: boilerplate i18n edits in every stage\nphase(\"A\"); await agent(1,{model:\"sonnet\"}); phase(\"B\"); await agent(2,{model:\"sonnet\"})"}'
mkj "$FIX/wf-mono-sonnetlead.json" Workflow "$FIX/lead-sonnet.jsonl" '{"script":"phase(\"A\"); await agent(1,{model:\"sonnet\"}); phase(\"B\"); await agent(2,{model:\"sonnet\"})"}'
mkj "$FIX/wf-dynamic.json"     Workflow "$FIX/lead-opus.jsonl" '{"script":"const M=pick(); phase(\"A\"); await agent(1,{model: M}); phase(\"B\"); await agent(2,{model: M})"}'
GOUT=$(cd "$FIX/repo" && bash "$NUDGE" < "$FIX/wf-mono-stages.json")
check "gate v2.50: 3 stages all sonnet under opus Lead → deny (single-tier) naming the stages" \
  "printf '%s' \"\$GOUT\" | grep -q '\"deny\"' && printf '%s' \"\$GOUT\" | grep -q 'Verify findings'"
check "gate v2.50: all sonnet but no discernible stages → silent (cannot judge spread)" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-mono-1stage.json')\" ]"
check "gate v2.50: haiku sweep + sonnet rank on a MONEY fleet under opus Lead → deny (no-strong-judge)" \
  "cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-judge-low.json' | grep -q 'judgment stage'"
check "gate v2.51.1: haiku sweep + sonnet rank on a ROUTINE fleet (i18n) → silent (balanced judge is R2 policy)" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-judge-routine.json')\" ]"
check "gate v2.50: haiku sweep + opus rank → silent (real spread)" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-judge-ok.json')\" ]"
check "gate v2.50: sonnet build + agentType reviewer → silent (role-pin counts as the strong stage)" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-judge-role.json')\" ]"
check "gate v2.50: // tier-reason: accepted for a deliberate single tier" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-mono-reason.json')\" ]"
check "gate v2.50: sonnet Lead + sonnet everywhere → silent (no cost leak; nudge covers judge)" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-mono-sonnetlead.json')\" ]"
check "gate v2.50: model from a variable (dynamic) → trusted, silent" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-dynamic.json')\" ]"
# loop valve: same fleet denied twice within 30 min → third submission passes with a nudge (logged yield)
mkj "$FIX/wf-loop.json" Workflow "$FIX/lead-opus.jsonl" '{"script":"name: \"loopy\" phase(\"A\"); await agent(1,{model:\"sonnet\"}); phase(\"B\"); await agent(2,{model:\"sonnet\"})"}'
check "gate valve: 1st and 2nd submission of the same fleet → deny, deny" \
  "cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-loop.json' | grep -q '\"deny\"' && bash '$NUDGE' < '$FIX/wf-loop.json' | grep -q '\"deny\"'"
check "gate valve: 3rd submission within 30 min → passes with a YIELDED nudge, logged" \
  "cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-loop.json' | grep -q 'YIELDED' && ! bash '$NUDGE' < '$FIX/wf-loop.json' | grep -q '\"deny\"' && grep -q '\"action\": \"yield\"' .rolepod/evidence/phase-log.jsonl"
check "gate v2.50: dispatch-gate lines carry reason + tiers + stages" \
  "grep -q '\"reason\": \"single-tier\"' '$FIX/repo/.rolepod/evidence/phase-log.jsonl' && grep -q '\"reason\": \"no-strong-judge\"' '$FIX/repo/.rolepod/evidence/phase-log.jsonl'"
check "gate: stated // fleet-inherit: reason → nudge, not deny" \
  "cd '$FIX/repo' && ! bash '$NUDGE' < '$FIX/wf-opus-reason.json' | grep -q '\"deny\"' && bash '$NUDGE' < '$FIX/wf-opus-reason.json' | grep -q 'Stated reason accepted'"
check "gate: agentType per stage counts as a tier choice → silent" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-opus-atype.json')\" ]"
check "gate: any per-stage model: → silent" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-opus-model.json')\" ]"
check "gate: no agent() fan-out → silent" \
  "[ -z \"\$(cd '$FIX/repo' && bash '$NUDGE' < '$FIX/wf-opus-noagent.json')\" ]"
check "gate: sonnet Lead → nudge only (fleet already cheap)" \
  "! bash '$NUDGE' < '$FIX/wf-effort.json' | grep -q '\"deny\"'"
check "gate: fresh session (no transcript) → nudge, never deny" \
  "! bash '$NUDGE' < '$FIX/wf-inherit.json' | grep -q '\"deny\"'"
check "gate: ROLEPOD_GATES_SOFT degrades to nudge + logs the bypass" \
  "cd '$FIX/repo' && ! ROLEPOD_GATES_SOFT=1 bash '$NUDGE' < '$FIX/wf-opus-bare.json' | grep -q '\"deny\"' && grep -q '\"hook\":\"workflow-tier-nudge\",\"var\":\"ROLEPOD_GATES_SOFT\"' .rolepod/evidence/bypass.log"
check "gate: each deny logs a dispatch-gate line (denied fleets never reach PostToolUse)" \
  "grep -c '\"action\": \"deny\"' '$FIX/repo/.rolepod/evidence/phase-log.jsonl' | grep -qE '^([3-9]|[1-9][0-9])'"
mkj "$FIX/wf-mono.json"  Workflow "$FIX/lead-opus.jsonl" '{"script":"name: \"mono\" await agent(1,{model: \"sonnet\"}); await agent(2,{model: \"sonnet\"})"}'
mkj "$FIX/wf-multi.json" Workflow "$FIX/lead-opus.jsonl" '{"script":"name: \"multi\" await agent(1,{model: \"haiku\"}); await agent(2,{agentType: \"rolepod:qa-tester\"}); await agent(3,{model: \"opus\"})"}'
LOG="$REPO_DIR/hooks/dispatch-auto-log.sh"
check "auto-log: Workflow records the model literals + tier_mix (v2.48.1)" \
  "cd '$FIX/repo' && bash '$LOG' < '$FIX/wf-mono.json' && tail -1 .rolepod/evidence/phase-log.jsonl | grep -q '\"tier_mix\": \[\"balanced\"\]' && bash '$LOG' < '$FIX/wf-multi.json' && tail -1 .rolepod/evidence/phase-log.jsonl | grep -q 'role-pin'"
OUT=$(bash "$REPO_DIR/scripts/stats.sh" "$FIX/repo")
check "stats shows the fleet tier spread (single-tier vs multi-tier)" \
  "printf '%s' \"\$OUT\" | grep -q 'single-tier balanced ×1' && printf '%s' \"\$OUT\" | grep -q 'multi-tier'"
check "stats reports fleet-tier gate denials by reason" \
  "printf '%s' \"\$OUT\" | grep -q 'Fleet-tier gate: denied' && printf '%s' \"\$OUT\" | grep -q 'single-tier ×'"
LOG="$REPO_DIR/hooks/dispatch-auto-log.sh"
check "auto-log: effort-only Workflow logs model=inherit + effort_overrides=1 (was a false 'mixed')" \
  "cd '$FIX/repo' && bash '$LOG' < '$FIX/wf-effort.json' && tail -1 .rolepod/evidence/phase-log.jsonl | grep -q '\"model\": \"inherit\"' && tail -1 .rolepod/evidence/phase-log.jsonl | grep -q '\"effort_overrides\": 1'"
# PostToolUse sees the lifted input (live-verified): model=opus → floor applied;
# a model-less strong role under a low Lead at PostToolUse = the lift did not
# happen → floor missed (observable, never inferred).
mkj "$FIX/rev-lifted.json" Agent "$FIX/lead-sonnet.jsonl" '{"subagent_type":"rolepod:universal-reviewer","model":"opus","prompt":"review"}'
check "auto-log: lifted reviewer (model=opus at PostToolUse) logs floor=applied + lead_class" \
  "cd '$FIX/repo' && bash '$LOG' < '$FIX/rev-lifted.json' && tail -1 .rolepod/evidence/phase-log.jsonl | grep -q '\"floor\": \"applied\"' && tail -1 .rolepod/evidence/phase-log.jsonl | grep -q '\"lead_class\": \"balanced\"'"
check "auto-log: model-less strong role under a low Lead logs floor=missed (not inferred as lifted)" \
  "cd '$FIX/repo' && bash '$LOG' < '$FIX/rev-sonnet.json' && tail -1 .rolepod/evidence/phase-log.jsonl | grep -q '\"floor\": \"missed\"' && tail -1 .rolepod/evidence/phase-log.jsonl | grep -q '\"model\": \"inherit\"'"
OUT=$(bash "$REPO_DIR/scripts/stats.sh" "$FIX/repo")
check "stats reports floor applied/missed + Lead class at dispatch" \
  "printf '%s' \"\$OUT\" | grep -q 'applied ×1, missed ×1' && printf '%s' \"\$OUT\" | grep -q 'Lead class at dispatch'"

# ── coordinator-loop check (v2.51.0) — 3rd sequential Agent round-trip in one turn ──
mkturn() { # $1 out, $2 prior dispatch rounds (0..3) — one Agent tool_use per assistant msg + a tool_result
  : > "$1"
  printf '{"type":"user","timestamp":"2026-08-18T01:00:00.000Z","message":{"role":"user","content":"do the thing"}}\n' >> "$1"
  local i=1
  while [ "$i" -le "$2" ]; do
    printf '{"type":"assistant","timestamp":"2026-08-18T01:0%s:00.000Z","message":{"model":"claude-opus-5","usage":{"input_tokens":1,"cache_read_input_tokens":300000,"cache_creation_input_tokens":100,"output_tokens":5},"content":[{"type":"tool_use","id":"t%s","name":"Agent","input":{"subagent_type":"general-purpose","prompt":"x","model":"sonnet"}}]}}\n' "$i" "$i" >> "$1"
    printf '{"type":"user","timestamp":"2026-08-18T01:0%s:30.000Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t%s","content":"ok"}]}}\n' "$i" "$i" >> "$1"
    i=$((i+1))
  done
}
mkturn "$FIX/turn0.jsonl" 0; mkturn "$FIX/turn2.jsonl" 2; mkturn "$FIX/turn3.jsonl" 3
printf '{"type":"user","message":{"role":"user","content":"go"}}\n{"type":"assistant","message":{"model":"claude-opus-5","content":[{"type":"tool_use","name":"Agent","input":{}},{"type":"tool_use","name":"Agent","input":{}},{"type":"tool_use","name":"Agent","input":{}}]}}\n' > "$FIX/turn-par.jsonl"
SS="$REPO_DIR/hooks/lib/session_state.py"
check "dispatch-rounds: counts assistant messages with an Agent dispatch since the last user prompt (0 / 2 / 3)" \
  "[ \"\$(printf '{\"transcript_path\":\"$FIX/turn0.jsonl\"}' | python3 '$SS' dispatch-rounds)\" = 0 ] && [ \"\$(printf '{\"transcript_path\":\"$FIX/turn2.jsonl\"}' | python3 '$SS' dispatch-rounds)\" = 2 ] && [ \"\$(printf '{\"transcript_path\":\"$FIX/turn3.jsonl\"}' | python3 '$SS' dispatch-rounds)\" = 3 ]"
check "dispatch-rounds: parallel fan-out inside ONE message counts as one round" \
  "[ \"\$(printf '{\"transcript_path\":\"$FIX/turn-par.jsonl\"}' | python3 '$SS' dispatch-rounds)\" = 1 ]"
mkj "$FIX/agent-3rd.json" Agent "$FIX/turn2.jsonl" '{"subagent_type":"rolepod:backend-developer","prompt":"x"}'
mkj "$FIX/agent-4th.json" Agent "$FIX/turn3.jsonl" '{"subagent_type":"rolepod:backend-developer","prompt":"x"}'
mkj "$FIX/agent-3rd-explore.json" Agent "$FIX/turn2.jsonl" '{"subagent_type":"Explore","prompt":"x"}'
check "coordinator-check: the 3rd sequential Agent round-trip in a turn → nudge to move to a Workflow pipeline (with context size)" \
  "bash '$NUDGE' < '$FIX/agent-3rd.json' | grep -q 'coordinator-check' && bash '$NUDGE' < '$FIX/agent-3rd.json' | grep -q '300k tokens'"
check "coordinator-check: 4th round-trip → silent again (fires once per turn)" \
  "[ -z \"\$(bash '$NUDGE' < '$FIX/agent-4th.json')\" ]"
check "coordinator-check: merges with a tier note when both apply (Explore on the 3rd round-trip)" \
  "bash '$NUDGE' < '$FIX/agent-3rd-explore.json' | python3 -c 'import json,sys; a=json.load(sys.stdin)[\"hookSpecificOutput\"][\"additionalContext\"]; assert \"coordinator-check\" in a and \"tier-check\" in a'"

# ── context-bloat check (v2.49.0) — rides the UserPromptSubmit hook ────────
CVN="$REPO_DIR/hooks/claim-verify-nudge.sh"
printf '{"type":"assistant","timestamp":"2026-08-18T01:00:00.000Z","message":{"model":"claude-opus-5","usage":{"input_tokens":2,"cache_read_input_tokens":574899,"cache_creation_input_tokens":1055,"output_tokens":10},"content":[]}}\n' > "$FIX/ctx-big.jsonl"
printf '{"type":"assistant","timestamp":"2026-08-18T01:00:00.000Z","message":{"model":"claude-opus-5","usage":{"input_tokens":2,"cache_read_input_tokens":120000,"cache_creation_input_tokens":1000,"output_tokens":10},"content":[]}}\n' > "$FIX/ctx-small.jsonl"
mkdir -p "$FIX/home"
check "context-check: 575k context → additionalContext for the Lead only (no user-facing systemMessage, v2.49.1)" \
  "printf '{\"session_id\":\"c1\",\"transcript_path\":\"$FIX/ctx-big.jsonl\",\"prompt\":\"fix the button\"}' | HOME='$FIX/home' bash '$CVN' | python3 -c 'import json,sys; o=json.load(sys.stdin); a=o[\"hookSpecificOutput\"][\"additionalContext\"]; assert \"575k\" in a and \"scout\" in a and \"/compact\" in a and \"systemMessage\" not in o'"
check "context-check: same 200k bucket in the same session → silent (once per bucket)" \
  "[ -z \"\$(printf '{\"session_id\":\"c1\",\"transcript_path\":\"$FIX/ctx-big.jsonl\",\"prompt\":\"fix the button\"}' | HOME='$FIX/home' bash '$CVN')\" ]"
check "context-check: 121k context → no context wording (claim-check still works)" \
  "printf '{\"session_id\":\"c2\",\"transcript_path\":\"$FIX/ctx-small.jsonl\",\"prompt\":\"why is this broken\"}' | HOME='$FIX/home' bash '$CVN' | python3 -c 'import json,sys; o=json.load(sys.stdin); a=o[\"hookSpecificOutput\"][\"additionalContext\"]; assert \"claim-check\" in a and \"context-check\" not in a and \"systemMessage\" not in o'"
check "context-check: big context + claim prompt → both notes in one payload" \
  "printf '{\"session_id\":\"c3\",\"transcript_path\":\"$FIX/ctx-big.jsonl\",\"prompt\":\"why is this broken\"}' | HOME='$FIX/home' bash '$CVN' | python3 -c 'import json,sys; o=json.load(sys.stdin); a=o[\"hookSpecificOutput\"][\"additionalContext\"]; assert \"context-check\" in a and \"claim-check\" in a'"
check "context-check: no transcript → plain claim-nudge behaviour, no crash" \
  "printf '{\"prompt\":\"why is this broken\"}' | HOME='$FIX/home' bash '$CVN' | grep -q claim-check"
check "session_state context-tokens reads input+cache_read+cache_creation of the last turn" \
  "[ \"\$(printf '{\"transcript_path\":\"$FIX/ctx-big.jsonl\"}' | python3 '$REPO_DIR/hooks/lib/session_state.py' context-tokens)\" = 575956 ]"

# ── junit-summary.sh ────────────────────────────────────────────────────
cat > "$FIX/report.xml" <<'EOF'
<testsuite name="suite" tests="3" failures="1" errors="0" skipped="1">
  <testcase classname="pkg.TestA" name="test_TC1_boundary"/>
  <testcase classname="pkg.TestA" name="test_TC2_minimum">
    <failure message="expected 48 got 50"/>
  </testcase>
  <testcase classname="pkg.TestB" name="test_skipped"><skipped/></testcase>
</testsuite>
EOF
OUT=$(bash "$REPO_DIR/scripts/junit-summary.sh" "$FIX/report.xml" || true)
check "junit counts totals"               "printf '%s' \"\$OUT\" | grep -q '3 tests — 1 passed, 1 failed, 0 errors, 1 skipped'"
check "junit names the failed test"       "printf '%s' \"\$OUT\" | grep -q 'pkg.TestA::test_TC2_minimum'"
check "junit exits 1 on failures"         "! bash '$REPO_DIR/scripts/junit-summary.sh' '$FIX/report.xml'"

cat > "$FIX/green.xml" <<'EOF'
<testsuite name="suite" tests="1" failures="0" errors="0" skipped="0">
  <testcase classname="pkg.TestA" name="test_ok"/>
</testsuite>
EOF
check "junit exits 0 on green"            "bash '$REPO_DIR/scripts/junit-summary.sh' '$FIX/green.xml'"

# v2.42.0 regression guards: nested suites double-counted (outer attrs
# already roll up inner); attr-only suites must still count (no false green).
cat > "$FIX/nested.xml" <<'EOF'
<testsuite name="outer" tests="5" failures="2" errors="0" skipped="0">
  <testcase classname="pkg.A" name="t1"/>
  <testcase classname="pkg.A" name="t2"><failure message="x"/></testcase>
  <testcase classname="pkg.A" name="t3"/>
  <testsuite name="inner" tests="2" failures="1" errors="0" skipped="0">
    <testcase classname="pkg.B" name="t4"/>
    <testcase classname="pkg.B" name="t5"><failure message="y"/></testcase>
  </testsuite>
</testsuite>
EOF
OUT=$(bash "$REPO_DIR/scripts/junit-summary.sh" "$FIX/nested.xml" || true)
check "junit nested suites: no double-count"  "printf '%s' \"\$OUT\" | grep -q '5 tests — 3 passed, 2 failed, 0 errors, 0 skipped'"
check "junit nested suites: both failed names listed" "printf '%s' \"\$OUT\" | grep -q 'pkg.A::t2' && printf '%s' \"\$OUT\" | grep -q 'pkg.B::t5'"
check "junit nested exits 1"                  "! bash '$REPO_DIR/scripts/junit-summary.sh' '$FIX/nested.xml'"

cat > "$FIX/mixed.xml" <<'EOF'
<testsuites>
  <testsuite name="withcases" tests="2" failures="0" errors="0" skipped="0">
    <testcase classname="pkg.C" name="ok1"/>
    <testcase classname="pkg.C" name="ok2"/>
  </testsuite>
  <testsuite name="attronly" tests="4" failures="2" errors="1" skipped="0"/>
</testsuites>
EOF
OUT=$(bash "$REPO_DIR/scripts/junit-summary.sh" "$FIX/mixed.xml" || true)
check "junit attr-only suite still counted (no false green)" "printf '%s' \"\$OUT\" | grep -q '6 tests — 3 passed, 2 failed, 1 errors, 0 skipped'"
check "junit mixed exits 1"                   "! bash '$REPO_DIR/scripts/junit-summary.sh' '$FIX/mixed.xml'"
check "check-work cites junit-summary"    "grep -q 'junit-summary.sh' '$REPO_DIR/core/skills/check-work/SKILL.md'"

# ── shipped copies — installed users read evidence without the source repo ──
check "claude plugin tree ships stats.sh (byte-exact)" \
  "diff -q '$REPO_DIR/scripts/stats.sh' '$REPO_DIR/plugins/rolepod/scripts/stats.sh'"
check "claude plugin tree ships junit-summary.sh (byte-exact)" \
  "diff -q '$REPO_DIR/scripts/junit-summary.sh' '$REPO_DIR/plugins/rolepod/scripts/junit-summary.sh'"
check "codex plugin tree ships stats.sh" \
  "diff -q '$REPO_DIR/scripts/stats.sh' '$REPO_DIR/plugins/rolepod-codex/scripts/stats.sh'"
check "installer wires rolepod-stats launcher" \
  "grep -q 'rolepod-stats' '$REPO_DIR/install.sh'"
check "installer wires launcher removal on uninstall" \
  "grep -A6 'Removing rolepod-stats' '$REPO_DIR/install.sh' | grep -q 'rm -rf.*rolepod/bin'"
check "launcher install+removal guarded against ALL temp-target vars (test runs must never touch real HOME)" \
  "[ \"\$(grep -c 'ROLEPOD_TARGET:-}\${ROLEPOD_CLAUDE_TARGET:-}\${ROLEPOD_CODEX_TARGET:-}\${ROLEPOD_GEMINI_TARGET:-}\${ROLEPOD_CURSOR_TARGET:-}\${ROLEPOD_ANTIGRAVITY_TARGET:-}\${ROLEPOD_OPENCODE_TARGET' '$REPO_DIR/install.sh')\" = 2 ]"

exit $fail
