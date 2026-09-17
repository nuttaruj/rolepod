```
T1: Task needs a test (bug / feature / migration / auth / billing / race /
    contract / perf / security) and none exists?   → write it
T2: New tests pass?      T3: Existing tests pass — and none weakened
    to get there (loosened assertion / deleted case / skip = T3 fail)?
T4: Tier-appropriate speed?    T5: Isolated — no order, clock or seed
    dependency (no literal date · one frozen now · expectations from spec)?
T6: Assertion tight — a 1-char bug still passes? → tighten (`is not None` → `== expected`)
```
Skip when the diff is docs-only (prose / comments / config text / string literals — any size: tests cover the work, not the words), or when ALL hold: ≤5 lines · single file · zero logic-bearing · NOT a high-risk path (= rigor tier R1). Otherwise → write the test.
