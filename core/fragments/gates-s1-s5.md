- **S1 extra feature** — the diff builds only what was requested; cut the rest.
- **S2 single-use abstraction** — an abstraction with one caller is inlined.
- **S3 unasked config** — no config or flexibility nobody asked for; cut it.
- **S4 impossible case** — defensive code for a case that cannot happen becomes structurally impossible (type system / data model / API constraint), e.g. a runtime null check becomes a compiler-enforced `Optional<T>`. Structure cannot rule it out → the case is NOT impossible: handle it.
- **S5 repeated pattern** — the same pattern in 3+ places is centralized before commit.

A check that fails → revise before commit.
