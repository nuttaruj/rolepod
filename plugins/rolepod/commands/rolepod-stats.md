---
description: Show rolepod evidence stats for this project — tier routes, verify/review verdicts, strong-dispatch overrides, bypasses, plus which models actually ran (transcript proof).
---

Report rolepod usage stats for the current project. Two layers — run both, present one compact readout:

## 1. Intent record — evidence log

Run the first of these that exists (they are the same script):

```bash
rolepod-stats
bash ~/.rolepod/bin/stats.sh
bash ~/.claude/plugins/cache/rolepod/rolepod/*/scripts/stats.sh
```

It reads `<git-root>/.rolepod/evidence/phase-log.jsonl` + `bypass.log`: tier distribution (R1-R4), verify pass/fail, review verdicts, strong dispatches with/without explicit override (silent-downgrade audit), unreasoned bypasses.

## 2. Execution proof — transcript scan

Count which models ACTUALLY ran, in TWO separate tables — the Lead's own turns (main session files) and the subagent turns (`<session>/subagents/**/agent-*.jsonl` — Agent tool + Workflow fleets). Never merge them: the Lead's histogram is what `/model` was set to, not what fleets ran.

```bash
python3 -c "
import json, glob, collections, os
proj = os.path.expanduser('~/.claude/projects/') + os.getcwd().replace('/', '-')
def tally(paths):
    c = collections.Counter()
    for f in paths:
        for line in open(f, errors='ignore'):
            if '\"model\"' not in line or '\"assistant\"' not in line: continue
            try: d = json.loads(line)
            except: continue
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

Codex / Gemini / Antigravity runs are external CLIs — they never appear in Claude transcripts; their proof is the `dispatch-proof` lines in the intent layer (hook-reported).

## Report format

One short table per layer (three tables total: intent, Lead turns, subagent turns). Flag: any strong dispatch without explicit override (intent layer), and any SUBAGENT model the tier policy would not predict (proof layer) — a Lead histogram is never a tier-policy finding. No data yet → say so and name the file paths that will fill in as rolepod runs. Do not paste raw tool output — summarize.
