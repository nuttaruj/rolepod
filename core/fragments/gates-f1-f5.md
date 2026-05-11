## Failure-mode gate — before declaring task done

Active checkpoint. Answer 6 questions before reporting completion to user:

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
F6: Structurally fixable? Could this bug class be made structurally impossible
                          (type system / data model / API constraint) instead of
                          a runtime check?
                          → prefer the structural fix; only fall back to a runtime
                            check when the structural option is genuinely unavailable.
```

Any "yes" → stop and fix before declaring done. Skip if task was a typo / comment / docstring / pure rename.

Source: DAPLab failure-pattern research on agentic-LLM software failures (Foster, Jegan et al.).
