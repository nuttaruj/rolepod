# Code Search — pick right tool

Read when: about to find/look up anything in codebase.

## Hard rule

<EXTREMELY-IMPORTANT>
**Symbol lookup → GitNexus. Plain text → rg. NEVER grep-and-guess for symbols.**

Default assumption: code-intel beats text search. `grep` / `rg` finds bytes.
GitNexus understands meaning (defs, callers, impact, types). Pick by intent:
</EXTREMELY-IMPORTANT>

## Decision tree

```
Need               →  Tool
----               ----
function/class/method def?     gitnexus_context
who calls X?                   gitnexus_context (callers)
what breaks if I change X?     gitnexus_impact
concept "where does Y happen"? gitnexus_query
rename Y across repo?          gitnexus_rename
API/route map?                 gitnexus_route_map
unique error msg / string?     rg
filename pattern?              rg --files | rg
TODO/FIXME?                    rg
config key?                    rg
past decision / rationale?     mempalace_kg_query
external service state?        MCP / CLI
```

## Forbidden

- `rg ClassName` — use `gitnexus_context`
- `rg "function foo"` — use `gitnexus_context`
- `rg "import .* from"` — use `gitnexus_impact`
- find-replace rename — use `gitnexus_rename`
- "let me grep for it" without checking GitNexus first

## Fallback

GitNexus index missing/stale → degrade to `rg` + state risk. Don't silently fall back.
