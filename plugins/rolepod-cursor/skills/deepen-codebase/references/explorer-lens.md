<!-- Vocabulary adapted from mattpocock/skills codebase-design (MIT). The deepen-codebase explorer reads this first (Step 2). -->

# Explorer lens

The vocabulary every candidate uses and the evidence bar every claim meets.

## Vocabulary — use these words exactly

- **Module** — anything with an interface and an implementation: a function, a file, a script, a hook, a package. Scale-agnostic.
- **Interface** — everything a caller must know to use the module: the signature plus invariants, ordering, error modes, required config (env, files it expects), side effects.
- **Depth** — behaviour a caller gets per unit of interface it must learn. **Deep**: much behaviour behind a small interface. **Shallow**: the interface is nearly as complex as what it hides.
- **Seam** — the place where behaviour can change without editing that place; where a module's interface lives.
- **Adapter** — a concrete thing filling a seam. One adapter = a hypothetical seam (indirection); two = a real one.
- **Leverage** — what callers gain from depth: one implementation pays back across N call sites and M tests.
- **Locality** — what maintainers gain from depth: a change, a bug, a rule lives in ONE place — fixed once, fixed everywhere.

## Tests to apply

- **Deletion test** — imagine deleting the module and inlining it into its callers. Complexity reappears across N callers → it earns its keep (and N hand-kept copies of one rule elsewhere = a deepening candidate). Complexity just vanishes → a pass-through, shallow.
- **The interface is the test surface** — tests should cross the seam callers use. A test that pins text instead of behaviour, reaches past the interface, or exercises a function no production caller uses = friction: the real path is untested.
- **Drift check** — one concept computed in two or more places: compare the copies. Copies that already disagree are the strongest evidence a module is missing.
- **Dependency kind** — in-process (unit test through the interface) · local-substitutable: clock, fs, env (inject at the seam) · remote-but-owned (thin adapter, real local instance) · true-external (adapter you own + contract test). A module that hard-wires a substitutable dependency cannot be tested through its interface.

## Friction signals — a lens, not a filter

- understanding one concept means bouncing between many small modules
- a shallow module — interface as wide as its body
- pure functions extracted for testability while the bugs hide in how they are called
- modules leaking state or format knowledge across their seams (a file, a log line, an env var many modules parse)
- a part untested, or untestable through its current interface

Walk organically: hot spots first, then wherever the friction leads. Note where YOU struggle to understand — that struggle is the signal.

## Evidence bar

- Every claim carries `path:line`.
- A claimed bug or drift is reproduced with a command that writes nothing in the repo (grep, `git log`, run an existing test, a scratch script in the temp dir) — or marked `read only, not reproduced`.
- Never edit, create or delete a repo file. Never propose the new interface — name the friction and the direction only.
- A candidate that fails the deletion test is dropped, not softened.
