<!-- Load when hand-editing the pool file. SKILL.md step 6 writes it through --setup. -->

# The pool file

`<git-root>/.rolepod/cross-family` (project) overrides `~/.rolepod/cross-family` (machine). No file = off. `none` = off.

```ini
[reviewer]
review = cursor agy codex stall=900   # default order for every kind; stall= binds to codex
consult = agy codex                   # debug consults want the fast answer first
critique = cursor agy codex
tier = R2                             # the external replaces universal-reviewer from this tier up (default R4)
[implement]
cli = codex claude                    # the members that may WRITE (--kind implement)
```

- Members in preference order: `codex` `claude` `agy` `cursor` `opencode`. `gemini` is retired — skipped with a note; list `agy` instead.
- A missing kind key falls back to `review`. The older shape (bare lines plus `consult: agy codex` per-kind lines) still reads; a `timeout=` on a kind line binds to that kind only.
- Options follow a member name: `stall=<s>` (silence before a member counts as dead, default 600) and `timeout=<s>` (the wall-clock insurance cap). Whole seconds only; anything else is ignored with a warning.
- Precedence: `--stall` / `--timeout` flag > the file > the kind default (review 7200 s detached / 600 s foreground · consult 300 · critique 600).
- `rolepod-cross-family --candidates` lists the installed CLIs; `--review-tier` prints the effective `tier`.
