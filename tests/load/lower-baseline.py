#!/usr/bin/env python3
# ratchet tests/static/load-lock.baseline down to a measure.sh output
#   lower-baseline.py --measured <tsv> [--baseline <file>] [--apply] [--drop-gone] [--tidy-notes]
import argparse, collections, sys
ap = argparse.ArgumentParser()
ap.add_argument('--measured', required=True)
ap.add_argument('--baseline', default='tests/static/load-lock.baseline')
ap.add_argument('--apply', action='store_true')
ap.add_argument('--drop-gone', action='store_true')
ap.add_argument('--tidy-notes', action='store_true')
a = ap.parse_args()
meas = {}
for l in open(a.measured, encoding='utf-8').read().splitlines():
    r, art, n = l.split('\t')
    meas[(r, art)] = int(n)
src = open(a.baseline, encoding='utf-8').read().splitlines()
rows = {}
for l in src:
    p = l.split('\t')
    if l.strip() and not l.startswith('#') and p[0] != 'note':
        rows[(p[0], p[1])] = int(p[2])
out, changed = [], []
for l in src:
    p = l.split('\t')
    if not l.strip() or l.startswith('#'):
        out.append(l)
    elif p[0] == 'note':
        k, m = (p[1], p[2]), meas.get((p[1], p[2]))
        if a.tidy_notes and m is not None and rows.get(k, -1) >= m:
            changed.append('drop note %s %s (row %d >= %d)' % (k + (rows[k], m)))
        elif a.tidy_notes and m is not None and int(p[3]) > m:
            changed.append('lower note %s %s %s -> %d' % (k + (p[3], m)))
            p[3] = str(m)
            out.append('\t'.join(p))
        else:
            out.append(l)
    else:
        k, m = (p[0], p[1]), meas.get((p[0], p[1]))
        if m is None:
            changed.append('gone %s %s' % k)
            if not a.drop_gone:
                out.append(l)
        elif m < int(p[2]):
            changed.append('lower row %s %s %s -> %d' % (k + (p[2], m)))
            p[2] = str(m)
            out.append('\t'.join(p))
        else:
            out.append(l)
allow, tot = collections.Counter(), collections.Counter()
new_rows, new_notes = {}, {}
for l in out:
    p = l.split('\t')
    if l.strip() and not l.startswith('#'):
        (new_notes if p[0] == 'note' else new_rows)[(p[1], p[2]) if p[0] == 'note' else (p[0], p[1])] = int(p[3] if p[0] == 'note' else p[2])
for k in set(new_rows) | set(new_notes):
    allow[k[0]] += max(new_rows.get(k, 0), new_notes.get(k, 0))
for k, n in meas.items():
    tot[k[0]] += n
for r in sorted(set(allow) | set(tot)):
    print('%-16s allowed %7d measured %7d headroom %6d' % (r, allow[r], tot[r], allow[r] - tot[r]))
for c in changed:
    print(c)
for k, m in sorted(meas.items()):
    if m > max(new_rows.get(k, 0), new_notes.get(k, 0)):
        print('needs note: %s %s %d' % (k + (m,)))
if a.apply:
    open(a.baseline, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
