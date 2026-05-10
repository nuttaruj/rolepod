## Test gate — before every commit

Active checkpoint. Answer 5 questions:

```
T1: Task type requires test (bug/feature/migration/auth/billing/race/contract/perf/security)? 
     yes + no test → block commit, write test
T2: New tests actually pass?                  no → fix code or test
T3: Existing tests still pass?                no → fix regression
T4: Tests fast enough for pre-commit tier?    no → mark slow, move to integration tier
T5: Tests isolated (no order dependency)?     no → fix isolation
```

Skip test for: typo / comment / docstring / pure rename / dead code removal.

Internal execution: Lead via Bash (fast) or qa-tester subagent (complex). NEVER send to external AI.

Details: `~/.claude/rules/testing.md`
