## Simplicity gate — before every commit

```
S1: Feature beyond request?           yes → cut
S2: Abstraction for single-use?       yes → inline
S3: Config/flexibility nobody asked?  yes → cut
S4: Defensive code for impossible?    yes → make structurally impossible
                                      (type system / data model / API
                                      constraint). Structural unavailable →
                                      case NOT impossible, handle properly.
S5: Same pattern in 3+ places?        yes → centralize before commit
```

Any "yes" → revise. S4 example: runtime null check → `Optional<T>` compiler-enforced. Deep guide: skill `simplify-code`.
