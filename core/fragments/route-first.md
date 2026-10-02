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

Executing an approved plan → load `implement-plan` first and run its tasks to the end without stopping between them; only BLOCKED, a plan gap or a gate stops it.
