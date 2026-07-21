## Code search

Plain text or a unique string → `rg`. Symbol, caller, impact, rename →
code-intel index when connected, otherwise `rg` + Read. Never guess where a
symbol is defined — locate it.

**Scout for wide sweeps + bulk reads.** Broad sweep or any raw read past
~10k tokens (many files, unknown location, several naming conventions,
online sources) and the harness can spawn subagents → dispatch ONE read-only
**scout on a cheap model** (`scout` when installed) instead of sweeping
yourself. It returns a research report — conclusion, then one pointer per
finding (file:line, or URL + date online), then gaps — never raw dumps; the
Lead reads only what it points at. No subagent support → sweep yourself per
Verify-first. Scouts never edit, run state-changing commands, or address the
user.
