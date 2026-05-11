## Test gate — before every commit

Active checkpoint. Answer 6 questions:

```
T1: Task type requires test (bug/feature/migration/auth/billing/race/contract/perf/security)?
     yes + no test → block commit, write test
T2: New tests actually pass?                  no → fix code or test
T3: Existing tests still pass?                no → fix regression
T4: Tests fast enough for pre-commit tier?    no → mark slow, move to integration tier
T5: Tests isolated (no order dependency)?     no → fix isolation
T6: Assertion correct?                        Would a 1-character bug still let it pass?
                                              Bad:  assert result is not None
                                              Good: assert result == expected_value
                                              62% of LLM-generated tests have wrong assertions (arXiv 2402.13521).
                                              no → tighten the assertion
```

### Skip criteria — mechanical

Skip T-gate ONLY when ALL true:

```
- diff ≤5 lines
- single file touched
- zero logic-bearing lines (comments / docstrings / whitespace / typechecked renames)
- not on high-risk path (auth / billing / payment / migration / credit /
  permission / secret / crypto / token)
```

Any fail → write tests. PreCommit hook enforces mechanically.

Internal execution: Lead via Bash (fast) or qa-tester subagent (complex). NEVER send to external AI.

Details: `~/.claude/rules/testing.md`
