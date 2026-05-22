```
F1: Hallucinated a fn / file / API that does not exist?  → Read / Grep to verify
F2: Scope creep — diff wider than the request?           → cut the extra
F3: Cascading error — the fix introduced a new bug?      → run the full suite
F4: Context loss — forgot an earlier constraint?         → re-read the request
F5: Tool misuse — ran something destructive unannounced? → review + announce
```
Any "yes" → fix before declaring done. Skip only when ALL hold: ≤5 lines · single file · zero logic-bearing · NOT a high-risk path.
