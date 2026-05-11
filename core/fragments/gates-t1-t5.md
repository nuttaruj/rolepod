## Test gate — before every commit

```
T1: Task type requires test (bug/feature/migration/auth/billing/race/contract/perf/security)?
     yes + no test → block, write test
T2: New tests pass?                          no → fix
T3: Existing tests pass?                     no → fix regression
T4: Tests fast enough for pre-commit tier?   no → mark slow, move tier
T5: Tests isolated (no order dependency)?    no → fix
T6: Assertion correct? 1-char bug still passes?
     Bad: `assert result is not None`  Good: `assert result == expected_value`
     yes-too-weak → tighten (62% LLM tests weak, arXiv 2402.13521)
```

Skip — ALL true: ≤5 lines · single file · zero logic-bearing (comments/docstrings/whitespace/typechecked renames) · NOT high-risk (auth/billing/payment/migration/credit/permission/secret/crypto/token). Any fail → write tests. PreCommit hook enforces. Internal only. Details: `~/.claude/rules/test/testing.md`
