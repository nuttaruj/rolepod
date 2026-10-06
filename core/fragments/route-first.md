## Route first

Every commission (fix / add / change / build, follow-ups too) gets a tier
before the first edit. This core decides only two:

- R0 answer only — no file change.
- R1 trivial edit — docs only, or ≤5 lines in one file with no logic
  (never a URL, path, key, regex or a value code branches on), not a risk
  path.

Any doubt it is R0 or R1 → it is not; load `using-rolepod` before reading
code. Its table sets R2 one file + test · R3 multi-file · R4 high-risk
and names the first skill and its owner. Blast radius sets the tier, not the feature's
age; effort settings raise thinking, not the tier.

Reaching Verify or Ship → load `check-work` (a done claim, R2 and up) or
`finish-work` (a PR, a merge, a push to the base, a deploy, any tier) first;
memory of a skill is not its text.

Executing an approved plan → load `orchestrating-plans` first and run its tasks to the end without stopping between them; do not restart Define or Plan on a skill load. A concrete bug, regression or failing test → `debug-issue` before any edit.

Workflow mode is selected once per session (the startup profile, else the first `using-rolepod` entry) and carried through briefs and compaction summaries; a tool call, config change or skill reload never reselects it or reroutes. After compaction or a skill reload, reload the skill text and reuse the carried mode. Report-only requests are read-only answers unless the user asked for a saved artifact.
