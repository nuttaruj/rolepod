## Code search

Plain text or a unique string → `rg`. Symbol, caller, impact, rename →
code-intel index when connected, otherwise `rg` + Read. Never guess where a
symbol is defined — locate it.

**Scout for wide sweeps.** When answering needs a broad sweep — many files,
unknown location, several naming conventions, or online sources — and the
harness can spawn subagents: dispatch ONE read-only **scout on a cheap
model** (the `scout` agent when installed) instead of sweeping yourself. It returns a short research report —
conclusion first, then one line per finding with its pointer (file:line, or
URL + date for online sources), then open gaps — never raw file dumps. The
Lead reads only what the report points at and stays the decider. No subagent
support in this harness → sweep yourself per Verify-first. Scouts never
edit, never run state-changing commands, never address the user.
