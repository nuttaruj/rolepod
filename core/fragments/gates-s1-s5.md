## Simplicity gate — before every commit

Active checkpoint. Answer 5 questions:

```
S1: Added feature beyond request?           yes → cut
S2: Added abstraction for single-use?       yes → inline
S3: Added config/flexibility nobody asked?  yes → cut
S4: Added defensive code for impossible?    yes → cut
S5: Same pattern now in 3+ places?          yes → centralize before commit
```

Any "yes" → revise. Senior engineer test: "would they call this overcomplicated?" Yes → simplify.

Details: `~/.claude/rules/code-quality.md`
