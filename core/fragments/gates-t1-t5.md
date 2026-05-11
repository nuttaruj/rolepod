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

### Skip criteria — mechanical, not category

Skip T-gate ONLY when ALL true (no rationalization by category):

```
- diff ≤5 lines changed
- single file touched
- zero logic-bearing lines (only comments / docstrings / whitespace / renames
  caught by typechecker)
- not on high-risk path (auth / billing / payment / migration / credit /
  permission / secret / crypto / token)
```

Any criterion fails → write tests. PreCommit hook enforces mechanically.
Lead claiming "typo / pure rename" without diff inspection = honor-system bypass.

Internal execution: Lead via Bash (fast) or qa-tester subagent (complex). NEVER send to external AI.

Details: `~/.claude/rules/testing.md`
