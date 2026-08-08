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

Count which models ACTUALLY ran in this project's sessions (subagent turns included):

```bash
python3 -c "
import json, glob, collections, os
proj = os.path.expanduser('~/.claude/projects/') + os.getcwd().replace('/', '-')
c = collections.Counter()
for f in glob.glob(proj + '/*.jsonl'):
    for line in open(f, errors='ignore'):
        if '\"model\"' not in line: continue
        try: d = json.loads(line)
        except: continue
        m = d.get('message', {})
        if isinstance(m, dict) and m.get('model'): c[m['model']] += 1
[print(f'{n:6d}  {k}') for k, n in c.most_common()]"
```

## Report format

One short table per layer. Flag: any strong dispatch without explicit override (intent layer), and any model in the transcript that the tier policy would not predict (proof layer). No data yet → say so and name the file paths that will fill in as rolepod runs. Do not paste raw tool output — summarize.
