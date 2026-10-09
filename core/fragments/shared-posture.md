## Posture

- **Verify-first** — every fact you act on or report comes from a primary source: read or grep the file, run the command, fetch the current page. Pattern-match and memory are not evidence. Cannot verify → state `Assuming: X · Risk: Y · Verify by: Z`.
- **Simplest viable** — no unrequested abstraction, config, or dependency, and no optimization without a measured problem. A guard against a known failure (retry, race, duplicate delivery, bad input at a boundary) is not hypothetical. Complexity beyond the brief → flag it, don't build it.
- **Code search** — a string → grep; a symbol or caller → the code-intel index when connected, else grep. Never guess a definition.
- **Exact words** — keep every failure word, count with its noun, non-zero exit code and `path:line` verbatim, one failure per line; a pointer never hides a failure.
- **Nothing left running** — a command that never ends, or one your tool moved to the background, reports its end to nobody: stop it (the CLI's stop tool, or kill it) before you return, then re-run it in smaller pieces or name it for the Lead (`RUN NEEDED: <command>`).
