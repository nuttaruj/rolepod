---
paths:
  - "**/*.{ts,tsx,js,jsx,mjs,cjs}"
  - "**/*.{py,pyi}"
  - "**/*.{go,rs,rb,java,kt,swift,cs,cpp,c,h,hpp,php,lua,sh,zsh,bash}"
---

# Code Intelligence — workflow integration

**Scope:** when to fire each tool. Reindex strategy. MemPalace lifecycle.
**NOT this file:** tools reference → rule `code/code-intel.md`.

Read when: planning task with code intel / reindex question / lifecycle question.

## Auto-triggers (rolepod core)

| Event | Hook | Effect |
|-------|------|--------|
| SessionStart | `project-context-loader.sh` | Inject git log + hot files |

MemPalace + GitNexus integrate via their own vendor plugins/CLI, not rolepod hooks. The vendors' own installations handle:
- MemPalace: SessionStart / Stop / PreCompact hooks (via marketplace plugin for Claude, `.codex-plugin` for Codex, manual for Gemini)
- GitNexus: SessionStart / PreToolUse / PostToolUse hooks + stale-index notice (via `npx gitnexus@latest mcp` registration and GitNexus's own hook set)

Lead doesn't invoke rolepod-owned hooks manually — they fire automatically.

## Workflow stage map

### Stage 0 — Pre-task verify

| Action | Tool |
|--------|------|
| Past decision? | `mempalace_kg_query` |
| Index fresh? | `gitnexus://repo/<name>/context` |
| Prior conversation? | `mempalace_search` |

### Stage 1 — Explore

| Action | Tool |
|--------|------|
| Concept "how does X work" | `gitnexus_query` |
| Symbol detail | `gitnexus_context` |
| API endpoints | `gitnexus_route_map` |
| "Why built this way" | `mempalace_kg_query` + `kg_timeline` |

### Stage 2 — Plan (before edit)

| Action | Tool | Mandatory? |
|--------|------|-----------|
| Blast radius | `gitnexus_impact({target, direction:"upstream"})` | **YES** |
| API contract | `gitnexus_api_impact` | If touching API |
| Schema | `gitnexus_shape_check` | If touching DB/types |
| Past similar | `mempalace_kg_query` | When in doubt |

### Stage 3 — Implement

| Action | Tool |
|--------|------|
| Rename | `gitnexus_rename` |
| Verify caller | `gitnexus_context` |

### Stage 4 — Pre-commit

| Action | Tool | Mandatory? |
|--------|------|-----------|
| Verify scope | `gitnexus_detect_changes()` | **YES** |

### Stage 5 — Post-merge

| Action | Tool | When |
|--------|------|------|
| Reindex | `npx gitnexus analyze` | ≥5 files / structural / new module / warning |
| Save decision | `mempalace_kg_add` | Architecture / non-obvious workaround |

### Stage 6 — Session end

| Action | Tool |
|--------|------|
| Summary | `mempalace_diary_write` (or Stop hook auto) |
| Mark stale | `mempalace_kg_invalidate` |

## Reindex — `npx gitnexus analyze`

Stale → tools return wrong facts.

### Manual reindex

Rolepod does NOT ship auto-reindex hooks. GitNexus has no built-in auto-reindex either. The agent runs the reindex manually or GitNexus's own PostToolUse stale-index notice prompts it.

```bash
cd /path/to/repo
npx gitnexus analyze
```

When:
- Structural refactor in progress, need fresh index mid-task
- GitNexus stale-index notice appears on PostToolUse
- User explicitly asks ("reindex now")

Don't reindex:
- Every commit (expensive)
- Typo / 1-line fix
- During active task (blocks tools)

## MemPalace lifecycle

### Query (read)

- Verify-first: "decided this before?"
- User "why" → rationale in KG
- Architecture decision → past similar
- 3rd agent same issue → past attempts

### Add (write) — when ALL true

- Architectural / non-obvious / load-bearing
- Future session benefits
- Won't be obvious from current code

| Save | Skip |
|------|------|
| "Chose X over Y because constraint Z" | "Renamed foo to bar" |
| "Service offline, route to alt" | "Fixed typo" |
| "Cross-subdomain cookie requires `.example.com`" | "Bumped lib version" |
| "Workaround for upstream bug #1234" | "Reformatted file" |

### Invalidate

- Code contradicts stored fact
- User corrects
- Periodic review reveals stale

### Verify-first

Before recommending from KG:
1. Verify file/symbol exists (`Read` / `gitnexus_context`)
2. Check code matches stored claim
3. Mismatch → invalidate + use current state

## When auto-trigger hooks fail

- SessionStart no context → Lead manually checks git log + queries MemPalace via MCP
- PostBash silent → Lead manually `gitnexus_detect_changes` before commit
- Stop fails → Lead manually `mempalace_kg_add` if session had arch choice

Hooks = nice-to-have. Manual checkpoints = mandatory.

## Skill commands

`.claude/skills/gitnexus/`: `gitnexus-exploring/SKILL.md`, `gitnexus-impact-analysis/SKILL.md`, `gitnexus-debugging/SKILL.md`, `gitnexus-refactoring/SKILL.md`, `gitnexus-pr-review/SKILL.md`, `gitnexus-cli/SKILL.md`, `gitnexus-guide/SKILL.md`.

Suggested: `/reindex` → `npx gitnexus analyze`. `/impact <symbol>` → `gitnexus_impact`. `/decision <text>` → `mempalace_kg_add`. `/recall <topic>` → `mempalace_kg_query`.

## Common mistakes — DO NOT

- Skip Stage 2 mandatory `gitnexus_impact` before edit
- Skip Stage 4 `gitnexus_detect_changes` before commit
- Reindex after every commit
- Save trivial info to KG
- Trust auto-hook output without verifying when stakes high
