---
name: rolepod-stats
description: Show rolepod evidence stats for this project — tier routes, verify/review verdicts, strong-dispatch overrides, bypasses, plus which models actually ran (transcript proof). Use when the user asks for rolepod stats, the evidence report, or which models ran.
---

# Rolepod Stats

One project's evidence log and transcripts → three compact tables.

### 1. Intent record

Run `bash <this skill's folder>/scripts/stats.sh` from the project root — it reads the current git root (`$1` overrides); never `cd` into the skill folder.

It reads `<git-root>/.rolepod/evidence/phase-log.jsonl` + `bypass.log`: tier distribution (R1-R4), verify pass/fail, review verdicts, strong dispatches with/without explicit override (silent-downgrade audit), unreasoned bypasses.

Done when: the intent table is filled, or "no data" with the file paths named.

### 2. Execution proof

Claude Code only — on another CLI skip this layer and say the execution proof is Claude-only.

Layer 2 reads Claude Code transcripts (`~/.claude/projects`); on another CLI skip it and say so. Count which models ACTUALLY ran, in TWO separate tables — the Lead's own turns (main session files) and the subagent turns (`<session>/subagents/**/agent-*.jsonl` — Agent tool + Workflow fleets). Never merge them: the Lead's histogram is what `/model` was set to, not what fleets ran.

```bash
python3 -I -c "
import json, glob, collections, os
proj = os.path.expanduser('~/.claude/projects/') + os.getcwd().replace('/', '-')
def tally(paths):
    c = collections.Counter()
    for f in paths:
        for line in open(f, errors='ignore'):
            if '\"model\"' not in line or '\"assistant\"' not in line: continue
            try: d = json.loads(line)
            except ValueError: continue
            if d.get('type') != 'assistant': continue
            m = (d.get('message') or {}).get('model')
            if m and m != '<synthetic>': c[m] += 1
    return c
lead = tally(glob.glob(proj + '/*.jsonl'))
subs = tally(glob.glob(proj + '/*/subagents/**/agent-*.jsonl', recursive=True))
print('LEAD turns (main sessions — the /model choice, NOT fleet proof):')
[print(f'  {n:6d}  {k}') for k, n in lead.most_common()]
print('SUBAGENT turns (Agent tool + Workflow fleets — the execution proof):')
[print(f'  {n:6d}  {k}') for k, n in subs.most_common()] or print('  (none)')"
```

Codex / Antigravity runs are external CLIs — they never appear in Claude transcripts. When a cross-family pass ran, its proof is the runner's own phase-log rows (`phase: review|consult|critique|implement`, `reviewer: external`); older `dispatch-proof` rows are read if still present in the log.

Done when: both model tables are filled, or the layer is skipped with its reason.

## Guardrails

- One short table per layer (three tables total: intent, Lead turns, subagent turns). Never paste raw tool output — summarize.
- Flag any strong dispatch without explicit override (intent layer) and any SUBAGENT model the tier policy would not predict (proof layer); never flag the Lead's own histogram as a tier-policy finding.

## Next phase

- None — the readout is the deliverable.
- If `scripts/stats.sh` is missing, run layer 2 alone and say the intent layer needs the skill's script.
