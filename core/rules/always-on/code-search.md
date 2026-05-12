# Code Search — pick right tool

Read when: about to find/look up anything in codebase.

## Hard rule (conditional on GitNexus being available)

<EXTREMELY-IMPORTANT>
**IF GitNexus installed + index fresh → Symbol lookup uses GitNexus, plain text uses rg.**
**IF GitNexus NOT installed → rg / grep is correct default. No warning, no nag.**

Check availability: `gitnexus` MCP tools present in tool list OR `gitnexus://` resource resolvable. Absent → skip entire rule, use rg normally.

Default assumption WHEN available: code-intel beats text search. `grep` / `rg` finds bytes. GitNexus understands meaning (defs, callers, impact, types). Pick by intent:
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

## Forbidden (only when GitNexus available)

- `rg ClassName` — use `gitnexus_context`
- `rg "function foo"` — use `gitnexus_context`
- `rg "import .* from"` — use `gitnexus_impact`
- find-replace rename — use `gitnexus_rename`
- "let me grep for it" without checking GitNexus first

## Fallback behavior

| Situation | Action |
|---|---|
| GitNexus not installed | Use `rg` / `grep` normally. No warning, no degraded-mode note. |
| GitNexus installed + index fresh | Apply hard rule above |
| GitNexus installed + index stale | Apply rule + suggest `npx gitnexus analyze` once per session |
| GitNexus installed + offline/error | Degrade to `rg` + state risk in summary |

Silent fallback is correct when the tool simply isn't there. Rule applies only when capability exists.
