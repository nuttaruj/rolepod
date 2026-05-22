<!-- Load for any repo-wide task: audit, sweep, dead-code hunt, "find all X". -->

# Scope-then-spawn

Default for any task that touches the **whole repo** (audit, refactor sweep,
dead-code hunt, security pass, dependency map, "find every usage of X").
Stops Lead from fanning out parallel agents over hundreds of files when a
structural query can narrow the list first.

```
1. Scope    →  list the files / symbols / processes actually in scope
2. Narrow   →  filter to the suspicious / risky / changed subset
3. Spawn    →  parallel agents ONLY on the narrowed list (or self-do)
```

## Tool order — GitNexus if available, fallback otherwise

| Step | GitNexus installed + fresh | GitNexus NOT installed |
|---|---|---|
| Scope | `gitnexus_query("audit target")` → process / cluster list | `rg -l <pattern>` + `find` |
| Narrow | `gitnexus_impact(target, upstream)` + `gitnexus_context(symbol)` → callers + blast radius | `rg` cross-reference + Read on hotspots |
| Spawn | Parallel agents on 5-10 narrowed files | Parallel agents on the rg-filtered list |

GitNexus path: sub-second graph query, no per-file LLM read. Cuts token cost
~90% on structural audits.
Fallback path: `rg` + `find` are universal. No GitNexus = no block. Lead does
not nag the user to install anything.

## When scope-then-spawn does NOT apply

- Single-file change → direct edit, no scoping
- Semantic-only audit (logic bugs, design smell, security reasoning) →
  GitNexus can't reason about meaning; spawn agents directly but cap the file
  count and ask the user to narrow if >20
- User already named the files → skip step 1

## Anti-pattern

Spawning 1 agent per file across 100+ files for "audit the whole repo"
without a scoping pass. Burns tokens, drowns Lead in summaries, misses
cross-file patterns GitNexus would surface in one query.
