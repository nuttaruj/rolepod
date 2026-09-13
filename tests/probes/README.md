# Skill probes

A probe asks a cheap model one question about one rendered skill — "what do
you do next?" — with the skill text inlined and nothing else loaded. It checks
the thing the static tests cannot: that a small model, holding only the skill,
picks the branch the text intends.

Not an eval harness. No arms, no graders, no metrics, never in `make test`.
One probe is ~25k tokens; run `all` only after a change to an exit / branch /
verdict line. Read the answer; the expect / forbid lines are a first filter,
not a verdict.

```
tests/probes/run.sh all              # every case, on `claude -p --model haiku`
tests/probes/run.sh E02-verify-only  # one case
tests/probes/run.sh --dry-run E02-verify-only | pbcopy   # paste into any CLI
PROBE_CMD='codex exec' tests/probes/run.sh all           # another headless CLI
```

## Case file

`cases/<id>.md`: header lines, a `---` line, then the prompt.

```
skill: check-work            # rendered copy under plugins/rolepod-codex/skills/
expect: FINAL:\*{0,2} *STOP  # ERE, one per line, must match the answer
forbid: CONTINUE             # ERE, one per line, must not
---
<the situation and the answer format>
```

Cases come from the 2026-09-13 skills audit (report §9); before the fix all
four answered the forbidden branch on haiku, after it all four passed once.
Add a case when a skill's branch text changes and a static grep cannot prove
the branch a model takes.
