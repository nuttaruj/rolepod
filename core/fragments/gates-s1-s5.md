## Simplicity gate — before every commit

Active checkpoint. Answer 5 questions:

```
S1: Added feature beyond request?           yes → cut
S2: Added abstraction for single-use?       yes → inline
S3: Added config/flexibility nobody asked?  yes → cut
S4: Added defensive code for impossible?    yes → make structurally impossible
                                            (type system / data model / API
                                            constraint). If structural unavailable,
                                            the case is NOT impossible — handle properly.
S5: Same pattern in 3+ places?              yes → centralize before commit
```

Any "yes" → revise. Senior-engineer test: "overcomplicated?" Yes → simplify.

### S4 — bad/good pairs

```
Bad:  Runtime null check at every call site (forget one → crash)
Good: Type system enforces non-null (Optional<T> + .unwrap()/?.)

Bad:  Validate user input at every function entry
Good: Sanitize at boundary (HTTP layer) → typed value flows inward

Bad:  if (!isAuthenticated()) throw — scattered through codebase
Good: Middleware enforces auth → handlers only receive authenticated users
```

Rule: bug class structurally impossible → do that. Runtime check = fallback.

Source: DAPLab failure-pattern research (Foster, Jegan et al.).

Details: `~/.claude/rules/code-quality.md`
