- **T1 test exists** — a bug, feature, migration, auth, billing, race, contract, perf or security task has a test; none → write it. A task its plan marks evidence-after (no test can express the behaviour yet: acceptance criteria + a mechanical check on its Test / evidence line) passes on that proof, walked and green — never a test-first task (bug fix, new business logic, auth, billing, migration, race).
- **T2 new tests pass.**
- **T3 existing tests pass, none weakened** — a loosened assertion, a deleted case or a skip to get green is a T3 fail.
- **T4 speed** — the tests run at the speed their tier allows.
- **T5 isolated** — no order, clock or seed dependency: no literal date, one frozen now, expectations taken from the spec.
- **T6 tight assertion** — a 1-char bug makes it fail; tighten a loose one (`is not None` → `== expected`).

Skip when the diff is docs-only (prose / comments / config text / string literals — any size: tests cover the work, not the words), or when ALL hold: ≤5 lines · single file · zero logic-bearing · NOT a high-risk path (= rigor tier R1, trivial edit). Otherwise → write the test.
