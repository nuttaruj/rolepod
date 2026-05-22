```
T1: Task needs a test (bug / feature / migration / auth / billing / race /
    contract / perf / security) and none exists?   → write it
T2: New tests pass?      T3: Existing tests pass (no regression)?
T4: Tier-appropriate speed?    T5: Isolated (no order dependency)?
T6: Assertion tight — would a 1-char bug still pass?   → tighten
    (weak: `assert x is not None` · tight: `assert x == expected`)
```
Skip only when ALL hold: ≤5 lines · single file · zero logic-bearing · NOT a high-risk path. Any fail → write the test.
