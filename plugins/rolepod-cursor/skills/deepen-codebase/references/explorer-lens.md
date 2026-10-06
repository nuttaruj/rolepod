<!-- Vocabulary adapted from mattpocock/skills codebase-design (MIT). The deepen-codebase explorer reads this first (Explore). -->

# Explorer lens

The vocabulary every candidate uses.

## Vocabulary — use these words exactly

- **Module** — anything with an interface and an implementation: a function, a file, a script, a hook, a package. Scale-agnostic.
- **Interface** — everything a caller must know to use the module: the signature plus invariants, ordering, error modes, required config (env, files it expects), side effects.
- **Depth** — behaviour a caller gets per unit of interface it must learn. **Deep**: much behaviour behind a small interface. **Shallow**: the interface is nearly as complex as what it hides.
- **Seam** — the place where behaviour can change without editing that place; where a module's interface lives.
- **Adapter** — a concrete thing filling a seam. One adapter = a hypothetical seam (indirection); two = a real one.
- **Leverage** — what callers gain from depth: one implementation pays back across N call sites and M tests.
- **Locality** — what maintainers gain from depth: a change, a bug, a rule lives in ONE place — fixed once, fixed everywhere.

## Tests to apply

- **The interface is the test surface** — tests should cross the seam callers use. A test that pins text instead of behaviour, reaches past the interface, or exercises a function no production caller uses = friction: the real path is untested.
- **Drift check** — one concept computed in two or more places: compare the copies. Copies that already disagree are the strongest evidence a module is missing.
- **Dependency kind** — a hard-wired substitutable dependency cannot be tested through its interface.

## Friction signals — a lens, not a filter

- understanding one concept means bouncing between many small modules
- a shallow module — interface as wide as its body
- pure functions extracted for testability while the bugs hide in how they are called
- modules leaking state or format knowledge across their seams (a file, a log line, an env var many modules parse)
- a part untested, or untestable through its current interface
