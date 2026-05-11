## Failure-mode gate — before declaring task done

Active checkpoint. Answer 5 questions:

```
F1: Hallucinated action?  Referenced function/file/API that doesn't exist?
                          → Read/Grep to verify each reference
F2: Scope creep?          Diff grew beyond user's request?
                          → re-check intent, cut unrequested
F3: Cascading error?      One fix introduced a new bug?
                          → run full test suite
F4: Context loss?         Forgot an earlier constraint mid-task?
                          → re-read user's request + CLAUDE.md gates
F5: Tool misuse?          Destructive cmd unannounced / skipped verify-first?
                          → review tool calls, announce + re-verify
```

Any "yes" → stop and fix before declaring done.

### Skip criteria — mechanical

Skip F-gate ONLY when ALL true:

```
- diff ≤5 lines (added + removed)
- single file touched
- zero logic-bearing lines (comments / docstrings / whitespace / typechecked renames)
- not on high-risk path (auth / billing / payment / migration / credit /
  permission / secret / crypto / token)
```

Any fail → run full gate. PreCommit hook enforces mechanically.

### Structural-fix rule

Folded into S4. F-gate now retrospective only.

Source: DAPLab failure-pattern research (Foster, Jegan et al.).
