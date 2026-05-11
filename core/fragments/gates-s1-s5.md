## Simplicity gate — before every commit

Active checkpoint. Answer 5 questions:

```
S1: Added feature beyond request?           yes → cut
S2: Added abstraction for single-use?       yes → inline
S3: Added config/flexibility nobody asked?  yes → cut
S4: Added defensive code for impossible?    yes → make it structurally impossible
                                            (type system / data model / API
                                            constraint), not defensive. If
                                            structurally impossible is unavailable,
                                            the case is NOT impossible — handle
                                            properly.
S5: Same pattern now in 3+ places?          yes → centralize before commit
```

Any "yes" → revise. Senior engineer test: "would they call this overcomplicated?" Yes → simplify.

### S4 — bad/good worked pairs

Concrete pattern (S4 = forward-looking; catches design before code written. Folded from former F6 to remove redundancy):

```
Bad:  Runtime null check → catches null at every call site (forgets one → crash)
Good: Type system enforces non-null (Optional<T> + .unwrap()/?.) — compiler
      ensures handled

Bad:  Validate user input at every function entry
Good: Sanitize at boundary (HTTP layer) → typed value flows inward, no
      re-check needed

Bad:  if (!isAuthenticated()) throw — scattered through codebase
Good: Middleware enforces auth → handler signatures only receive
      authenticated users
```

Rule: bug class structurally impossible → do that. Runtime check = fallback only when structural unavailable.

Source: DAPLab failure-pattern research on agentic-LLM software failures (Foster, Jegan et al.).

Details: `~/.claude/rules/code-quality.md`
