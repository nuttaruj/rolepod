# Code Intelligence — tools reference

**Scope:** which tool to use for which lookup. CLI tools list. Decision tree.
**NOT this file:** when in workflow to fire each → `code-intel-workflow.md`.

Read when: need symbol / caller / impact / rename / past decision / external service info.

## Verify-first principle

Never claim code/external fact without verifying. Memory + pattern-match = unreliable.
Full guide: `verify-first.md`.

## Tier overview

| Tier | Tool | When |
|------|------|------|
| 1 (text) | `rg` via Bash | Unique strings / specific pattern / speed |
| 2 (live code) | GitNexus + LSP | Symbol meaning: definitions, callers, transitive deps |
| 3 (history) | MemPalace KG | Past decisions / cross-session memory |
| 4 (external) | WebFetch / WebSearch / CLI / MCP | Live 3rd-party state, current docs |

`grep` finds text. Code-intel understands meaning. Don't grep for symbol when GitNexus available.

## GitNexus

Project indexed → check `gitnexus://repo/<name>/context` for freshness.
Stale → reindex (see `code-intel-workflow.md`).

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

Deep guides — skills:
- `gitnexus-impact-analysis` — "what breaks if I change X"
- `gitnexus-debugging` — bug tracing
- `gitnexus-exploring` — architecture understanding
- `gitnexus-refactoring` — rename/extract/split
- `gitnexus-pr-review` — review workflow
- `gitnexus-cli` — CLI commands
- `gitnexus-guide` — full reference

## MemPalace — Knowledge Graph

Tier 3 — past sessions, decisions, cross-conversation context.

### Tools

| Tool | Use for |
|------|---------|
| `mempalace_kg_query` | Find past decision / fact |
| `mempalace_kg_add` | Save important decision |
| `mempalace_kg_timeline` | Chronological view |
| `mempalace_search` | Full-text search |
| `mempalace_find_tunnels` | Related concepts |
| `mempalace_kg_invalidate` | Mark stale |

### Read-then-verify

KG fact = snapshot at write time. Before acting on recalled fact:
1. Verify by reading current state of files/resources
2. If conflict → trust current state, update or remove stale memory

## `rg` (ripgrep) — Tier 1

Use for:
- Unique error messages: `rg "ConnectionRefusedError"`
- Config keys: `rg "DATABASE_URL"`
- Filename pattern: `rg --files | rg "test_.*\.py"`

Don't use for:
- Symbol/caller lookup → `gitnexus_context`
- Refactor planning → `gitnexus_rename`
- Concept search → `gitnexus_query`

## CLI tools — external services

Anthropic best practice: "CLI = most context-efficient way to interact with external services."

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

Without CLI → raw API → unauthenticated rate limits + verbose responses.

### Learning unknown CLI

```
Use 'foo-cli --help' to learn about foo, then solve A, B, C.
```

### Order of preference

1. Dedicated MCP server (if connected) — structured data
2. CLI tool — context-efficient text
3. Raw HTTP API — last resort

## Decision tree

```
Need to find something?
├─ Plain text / unique string?           → rg
├─ Symbol / function / class?            → gitnexus_context
├─ "What breaks if I change X?"          → gitnexus_impact
├─ "Where does concept X happen?"        → gitnexus_query
├─ Rename / refactor?                    → gitnexus_rename
├─ "What did we decide last time?"       → mempalace_kg_query
├─ Past conversation / cross-session?    → mempalace_search
├─ Live 3rd-party state?                 → MCP server / CLI tool
├─ Library API / docs?                   → WebFetch official
└─ Pricing / news / current state?       → WebSearch (current year)
```

## When tools unavailable — fallback

- **GitNexus down / index missing** → `rg` for symbol search + Read for context (less precise, slower)
- **MemPalace down** → check git log + project `decisions/` dir + recent PRs
- **No internet (no WebSearch/WebFetch)** → state assumption + risk explicitly, ask user for any external fact needed
- **MCP server disconnected** → CLI tool fallback; if no CLI, ask user

## Common mistakes — DO NOT

- `rg` for symbol lookup when GitNexus available
- Edit symbol without `gitnexus_impact` first
- Find-replace rename instead of `gitnexus_rename`
- Trust MemPalace fact without verifying current state
- Save trivial info to MemPalace KG (clutters graph)
- Skip CLI for external service when MCP/CLI exists
- Use raw API when MCP server provides structured access
