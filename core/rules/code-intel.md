# Code Intelligence — tools reference

**Scope:** which tool for which lookup. CLI list. Decision tree.
**NOT this file:** when in workflow → `code-intel-workflow.md`.

Read when: need symbol / caller / impact / rename / past decision / external service info.

## Verify-first

Never claim code/external fact without verifying. Full guide: `verify-first.md`.

## Tier overview

| Tier | Tool | When |
|------|------|------|
| 1 (text) | `rg` | Unique strings / specific pattern |
| 2 (live code) | GitNexus + LSP | Symbol meaning: defs, callers, deps |
| 3 (history) | MemPalace KG | Past decisions / cross-session |
| 4 (external) | WebFetch / WebSearch / CLI / MCP | Live 3rd-party, current docs |

`grep` finds text. Code-intel understands meaning. Don't grep for symbol when GitNexus available.

## GitNexus

Check `gitnexus://repo/<name>/context` for freshness. Stale → reindex (`code-intel-workflow.md`).

### Core tools

| Tool | Use for | Lead direct? |
|------|---------|--------------|
| `gitnexus_impact` | Blast radius before edit | YES |
| `gitnexus_context` | Symbol callers/callees/flows | YES |
| `gitnexus_detect_changes` | Pre-commit scope verify | YES |
| `gitnexus_rename` | Graph-aware rename | YES |
| `gitnexus_query` | Concept exploration | subagent OK |
| `gitnexus_route_map` / `tool_map` | API/MCP map | subagent OK |
| `gitnexus_api_impact` / `shape_check` | Contract/schema drift | YES |

Exception: refactor >30 files OR ≥5 levels deep → subagent compresses graph first.

Deep guides (skills): `gitnexus-impact-analysis` / `gitnexus-debugging` / `gitnexus-exploring` / `gitnexus-refactoring` / `gitnexus-pr-review` / `gitnexus-cli` / `gitnexus-guide`.

## MemPalace — KG

Tier 3 — past sessions, decisions, cross-conversation.

**Distinct from native agent memory.** Each rolepod agent has `memory: project` or `memory: user` in frontmatter (Claude Code native, scopes own memory). MemPalace KG = optional cross-session decision recall via Stop / SessionStart / PreCompact hooks. Without MemPalace → native memory still works, just no cross-session KG recall.

### Tools

| Tool | Use for |
|------|---------|
| `mempalace_kg_query` | Find past decision / fact |
| `mempalace_kg_add` | Save important decision |
| `mempalace_kg_timeline` | Chronological view |
| `mempalace_search` | Full-text |
| `mempalace_find_tunnels` | Related concepts |
| `mempalace_kg_invalidate` | Mark stale |

### Read-then-verify

KG fact = snapshot. Before acting:
1. Verify current state of files
2. Conflict → trust current, update/remove stale memory

## `rg` (ripgrep) — Tier 1

Use: unique error messages (`rg "ConnectionRefusedError"`) / config keys (`rg "DATABASE_URL"`) / filename pattern (`rg --files | rg "test_.*\.py"`).

Don't use: symbol/caller → `gitnexus_context`. Refactor → `gitnexus_rename`. Concept → `gitnexus_query`.

## CLI tools

Anthropic: "CLI = most context-efficient way to interact with external services."

| Service | CLI |
|---------|-----|
| GitHub | `gh` |
| AWS | `aws` |
| GCP | `gcloud` |
| Sentry | `sentry-cli` |
| Stripe | `stripe` |
| Vercel | `vercel` |
| Railway | `railway` |
| Cloudflare | `wrangler` |
| Docker | `docker` |
| K8s | `kubectl` |

Without CLI → raw API → rate limits + verbose responses.

### Learning unknown CLI

```
Use 'foo-cli --help' to learn about foo, then solve A, B, C.
```

### Order of preference

1. MCP server (structured)
2. CLI tool (context-efficient)
3. Raw HTTP API (last resort)

## Decision tree

```
Plain text / unique string?       → rg
Symbol / function / class?        → gitnexus_context
"What breaks if I change X?"      → gitnexus_impact
"Where does concept X happen?"    → gitnexus_query
Rename / refactor?                → gitnexus_rename
Past decision?                    → mempalace_kg_query
Cross-session conversation?       → mempalace_search
Live 3rd-party state?             → MCP / CLI
Library API / docs?               → WebFetch official
Pricing / news / current state?   → WebSearch (current year)
```

## Fallback when tools unavailable

- GitNexus down/missing → `rg` + Read (less precise)
- MemPalace down → git log + `decisions/` dir + recent PRs
- No internet → state assumption + risk, ask user
- MCP disconnected → CLI; no CLI → ask user

## Common mistakes — DO NOT

- `rg` for symbol when GitNexus available
- Edit symbol without `gitnexus_impact`
- Find-replace rename instead of `gitnexus_rename`
- Trust MemPalace without verifying current state
- Save trivial info to KG
- Raw API when MCP/CLI exists
