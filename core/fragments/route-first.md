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

Executing an approved plan → load `implement-plan` first and run its tasks to the end without stopping between them; do not restart Define or Plan because of a skill invocation. Concrete bugs, regressions, or failing tests route to `debug-issue` before edits at every tier; after root cause, use `write-spec` only if behavior/design is unresolved before editing, and `write-plan` only when sequencing or ownership requires it.

Manual or mid-task use of `using-rolepod` is valid with or without hooks. Select workflow mode once at native session startup; without startup capture, select once at the first manual `using-rolepod` entry and carry active mode and source in session context, phase briefs, and compaction summaries.
Configured-mode inspection is distinct from active session mode. A tool call, config change, or skill reload never reselects mode or reroutes; route each user request on its intent, scope, and tier, and resume the visible owning phase when it still matches. Re-evaluate routing only when intent, scope, or tier changes.
Reload skill text after compaction or skill reload within the same session, then reuse the carried mode. A fresh native startup/resume/clear supplies its newly captured profile. Never persist an on-disk loaded-skill stamp. Report-only requests are read-only answers unless the user explicitly requested a saved artifact.
