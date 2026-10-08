#!/usr/bin/env python3
"""Test helper: turn the legacy pool text (bare lines, `key = members`,
`kind: members`, [sections]) read on stdin into the config.json the runner now
reads, printed on stdout. Lets a case state a pool in one short line."""
import json
import sys

rev, rest = [], {}
for raw in sys.stdin.read().splitlines():
    ln = raw.split("#", 1)[0].strip()
    if not ln or (ln.startswith("[") and ln.endswith("]")):
        continue
    key, val = None, ln
    for sep in ("=", ":"):
        if sep in ln:
            k, v = ln.split(sep, 1)
            k = k.strip().lower()
            if k in ("review", "default", "consult", "critique"):
                key, val = k, v.strip()
                break
    if key in ("consult", "critique"):
        rest[key] = val
    else:
        rev.append(val)
reviewer = dict(rest)
if rev:
    reviewer["review"] = " ".join(rev)
pool = {}
if reviewer:
    pool["reviewer"] = reviewer
json.dump({"pool": pool}, sys.stdout)
sys.stdout.write("\n")
