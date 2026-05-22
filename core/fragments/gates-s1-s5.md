```
S1: Feature beyond request?            → cut
S2: Abstraction for single-use?        → inline
S3: Config / flexibility nobody asked? → cut
S4: Defensive code for impossible?     → make it structurally impossible
                                         (type system / data model / API
                                         constraint); if structure can't, the
                                         case is NOT impossible — handle it
S5: Same pattern in 3+ places?         → centralize before commit
```
Any "yes" → revise before commit. S4 example: a runtime null check becomes a compiler-enforced `Optional<T>`.
