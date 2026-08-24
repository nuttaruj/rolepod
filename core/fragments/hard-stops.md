## Hard stops — stop and ask the user

- Third failed attempt at the same target → stop; the first escalation rung
  is NOT the user — get ONE clean-room cross-family opinion
  (`ROLEPOD_BRAIN_SILENT=1 codex exec ...` / `claude -p` / `gemini -m pro -p`)
  with a short ledger of attempts, then escalate with both views. Never retry blind.
- Fix rounds whose defect count is not strictly falling (any round back up)
  → same clean-room consult BEFORE the next round; one outside-family call
  is cheaper than round N+1 and catches a wrong mental model iterating cannot.
- About to run a destructive command → confirm first.
- Cannot state what the user asked for in one sentence → re-read the request.
- Context degrading (compaction warning, poor recall) with no convergence → summarize and ask.
- A file disagrees with an agent's claim → trust the file, re-verify.
- An assumption creates real risk with multiple valid readings → ask.
- A gate conflicts with a user instruction → surface options (self-review + limitation note); bypass envs are user-set, never yours.
