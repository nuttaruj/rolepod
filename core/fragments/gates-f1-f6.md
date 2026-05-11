## Failure-mode gate — before declaring done

```
F1: Hallucinated action?  fn/file/API doesn't exist?  → Read/Grep verify
F2: Scope creep?          diff > user request?        → cut unrequested
F3: Cascading error?      fix introduced new bug?     → run full tests
F4: Context loss?         forgot constraint?          → re-read request + gates
F5: Tool misuse?          destructive unannounced?    → review, announce, re-verify
```

Any "yes" → fix before declaring done. Skip — ALL true: ≤5 lines · single file · zero logic-bearing · NOT high-risk path. Structural-fix folded into S4. Source: DAPLab failure-pattern research.
