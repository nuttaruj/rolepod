## Code search

Plain text or a unique string → `rg`. Symbol, caller, impact, rename →
code-intel index when connected, otherwise `rg` + Read. Never guess where a
symbol is defined — locate it.

**Scout for wide sweeps.** Broad sweep (many files, unknown location, several
naming conventions, or online sources) and the harness can spawn subagents →
dispatch ONE read-only **scout on a cheap model** (the `scout` agent when
installed) instead of sweeping yourself. It returns a short research report —
conclusion, then one pointer per finding (file:line, or URL + date online),
then gaps — never raw dumps; the Lead reads only what it points at and stays
the decider. No subagent support → sweep yourself per Verify-first. Scouts
never edit, run state-changing commands, or address the user.
