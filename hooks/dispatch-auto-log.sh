#!/bin/bash
# Claude PostToolUse(Workflow|Agent) — auto-append the dispatch intent line.
#
# The dispatch-log rule ("Log EVERY dispatch — ad-hoc fan-outs included",
# using-rolepod tier paragraph) relied on the Lead remembering to append the
# line at dispatch time; the model that wrote the rule forgot it on the very
# next fleet it launched. Automation over doctrine: this hook writes the line
# itself, so /rolepod-stats always has intent data even when the Lead forgets.
#
# Class-tier labels (cheap/balanced/strong) stay the Lead's job — a hook
# cannot classify model names without hardcoding them (rename-proof rule);
# it records the raw facts: explicit model/effort override vs inherit.
# Runtime companion: the "dispatch-proof" transcript/hook layer.
#
# Fail-open everywhere: no git root, no JSON, missing fields → exit 0.

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
EV_DIR="$GIT_ROOT/.rolepod/evidence"
mkdir -p "$EV_DIR" 2>/dev/null || exit 0

printf '%s' "$INPUT" | python3 -c '
import json, re, sys, datetime
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tool = d.get("tool_name") or ""
if tool not in ("Workflow", "Agent", "Task"):
    sys.exit(0)
ti = d.get("tool_input") or {}
line = {
    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "phase": "dispatch",
    "cli": "claude",
    "tool": "Agent" if tool == "Task" else tool,
    "provenance": "hook-auto",
}
if tool == "Workflow":
    script = ti.get("script") or ""
    if not script and ti.get("scriptPath"):
        try:
            with open(ti["scriptPath"]) as f:
                script = f.read()
        except OSError:
            script = ""
    m = re.search("name:\\s*[\x27\"]([^\x27\"]+)", script)
    line["name"] = m.group(1) if m else (ti.get("name") or "?")
    n_over = len(re.findall("[,{\\s](model|effort)\\s*:", script))
    line["model_overrides"] = n_over
    line["model"] = "mixed" if n_over else "inherit"
    line["override"] = "per-stage" if n_over else "none"
else:
    line["agent_type"] = ti.get("subagent_type") or "general-purpose"
    line["model"] = ti.get("model") or "inherit"
    line["override"] = ti.get("model") or "none"
print(json.dumps(line, ensure_ascii=False))
' >> "$EV_DIR/phase-log.jsonl" 2>/dev/null || true

exit 0
