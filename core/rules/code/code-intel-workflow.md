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

## Auto-triggers (global)

| Event | Hook | Effect |
|-------|------|--------|
| SessionStart | `mempalace hook --hook session-start` | Recall recent decisions |
| SessionStart | `project-context-loader.sh` | Inject git log + hot files |
| PreToolUse Grep/Glob/Bash | `gitnexus-hook.cjs` | Enrich query with graph |
| PostToolUse Bash | `gitnexus-hook.cjs` | Index freshness check |
| PostToolUse Bash (ship) | `post-ship-detect.sh` | Suggest reindex on big merges |
| Stop | `mempalace hook --hook stop` | Capture session → KG |
| PreCompact | `mempalace hook --hook precompact` | Save state |

Lead doesn't invoke these — auto.

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

### Auto-reindex (default — no user action)

Rolepod ships two hooks that auto-spawn `npx gitnexus analyze --no-stats` in the background. Lead never asks the user to run analyze manually.

| Hook | Trigger | Cadence |
|------|---------|---------|
| `gitnexus-wrap.sh` | Plugin emits "index stale" notice on any PostToolUse Bash | Once/day/repo (shared marker) |
| `post-ship-detect.sh` | Ship cmd (`gh pr merge` / `git push main` / `git merge main`) touched ≥5 files in last 5 commits | Once/day/repo (shared marker) |

Both write to `/tmp/gitnexus-reindex-<repo>.log`. Block seeding is auto-detected:

- **First-time repo** (no `<!-- gitnexus:start -->` in CLAUDE.md/AGENTS.md) → reindex runs WITHOUT `--skip-agents-md` → block seeded. User commits the block once.
- **Subsequent reindex** (block already present) → hooks add `--skip-agents-md` → block frozen, zero diff churn.

User never has to run `gitnexus analyze` manually — first reindex seeds, all future reindexes stay clean.

### Manual reindex (rare)

```bash
cd /path/to/repo
npx gitnexus analyze
```

Only when:
- GitNexus plugin uninstalled after install (hooks no-op)
- Lead needs immediate fresh index mid-task (structural refactor in progress)
- User explicitly asks ("reindex now")

### Don't reindex

- Every commit (expensive — daily cadence is enough)
- Typo / 1-line fix
- During active task (blocks tools)
- Recent (<2 hrs) + no big change → marker already in place

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
