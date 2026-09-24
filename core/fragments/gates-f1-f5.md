- **F1 invented name** — every function, file and API the diff uses exists; confirm with Read / Grep.
- **F2 scope creep** — the diff is no wider than the request; cut the extra.
- **F3 cascading error** — the fix brought no new bug; run the full suite.
- **F4 context loss** — every earlier constraint still holds; re-read the request.
- **F5 tool misuse** — nothing destructive ran unannounced; review it and announce it.

A check that fails → fix it before declaring done.
Skip only when ALL hold: ≤5 lines · single file · zero logic-bearing (user-facing string text alone counts as zero) · NOT a high-risk path (= rigor tier R1, trivial edit).
