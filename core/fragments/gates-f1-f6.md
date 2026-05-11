## Failure-mode gate — before declaring task done

Active checkpoint. Answer 5 questions before reporting completion to user:

```
F1: Hallucinated action?  Did you reference a function/file/API that doesn't exist?
                          → Read/Grep to verify each reference
F2: Scope creep?          Did the diff grow beyond the user's request?
                          → re-check intent, cut anything unrequested
F3: Cascading error?      Did one fix introduce a new bug?
                          → run full test suite, not just the targeted test
F4: Context loss?         Did you forget an earlier constraint mid-task?
                          → re-read user's request + CLAUDE.md gates
F5: Tool misuse?          Did you use a destructive cmd unannounced or
                          run something without verify-first?
                          → review tool calls, announce + re-verify
```

Any "yes" → stop and fix before declaring done.

### Skip criteria — mechanical, not category

Skip F-gate ONLY when ALL true (no rationalization by category):

```
- diff ≤5 lines changed (added + removed)
- single file touched
- zero logic-bearing lines (only comments / docstrings / whitespace / renames
  caught by typechecker)
- not on high-risk path (auth / billing / payment / migration / credit /
  permission / secret / crypto / token)
```

Any criterion fails → run full gate. Lead claiming "it's just a typo" without
diff inspection = honor-system bypass. PreCommit hook enforces mechanically.

### Structural-fix rule (former F6, now S4)

Folded into S4 (gates-s1-s5.md) — forward-looking placement catches the
design choice before code is written, not after. F-gate is now retrospective
only (catch hallucination / scope / cascade / context / tool-misuse).

Source: DAPLab failure-pattern research on agentic-LLM software failures (Foster, Jegan et al.).
