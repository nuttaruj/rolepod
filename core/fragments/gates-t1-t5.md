## Test gate — before every commit

Active checkpoint. Answer 6 questions:

```
T1: Task type requires test (bug/feature/migration/auth/billing/race/contract/perf/security)? 
     yes + no test → block commit, write test
T2: New tests actually pass?                  no → fix code or test
T3: Existing tests still pass?                no → fix regression
T4: Tests fast enough for pre-commit tier?    no → mark slow, move to integration tier
T5: Tests isolated (no order dependency)?     no → fix isolation
T6: Assertion correct?                        Would a 1-character bug still let the assertion pass?
                                              Bad:  assert result is not None
                                              Good: assert result == expected_value
                                              62% of LLM-generated tests have wrong assertions (arXiv 2402.13521).
                                              no → tighten the assertion
```

Skip test for: typo / comment / docstring / pure rename / dead code removal.

Internal execution: Lead via Bash (fast) or qa-tester subagent (complex). NEVER send to external AI.

Details: `~/.claude/rules/testing.md`
