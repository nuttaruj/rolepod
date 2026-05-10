# Code Intelligence — workflow integration

**Scope:** when in workflow to fire each tool. Reindex strategy. MemPalace lifecycle.
**NOT this file:** tools reference / which tool to use → `code-intel.md`.

Read when: planning task with code intel / wondering when to reindex / lifecycle question.

## Auto-triggers (configured globally)

| Event | Hook | Effect |
|-------|------|--------|
| SessionStart | `mempalace hook run --hook session-start` | Auto-recall recent decisions |
| SessionStart | `project-context-loader.sh` | Inject git log + hot files |
| PreToolUse Grep/Glob/Bash | `gitnexus-hook.cjs` | Enrich query with graph context |
| PostToolUse Bash | `gitnexus-hook.cjs` | Index freshness check |
| PostToolUse Bash (ship cmds) | `post-ship-detect.sh` | Suggest reindex on big merges |
| Stop | `mempalace hook run --hook stop` | Capture session learnings → KG |
| PreCompact | `mempalace hook run --hook precompact` | Save state before compaction |

Lead doesn't invoke these — they fire automatically.

## Workflow stage map — when Lead invokes manually

### Stage 0 — Pre-task verify (before plan)

| Action | Tool |
|--------|------|
| Past decision on this topic? | `mempalace_kg_query` |
| Index fresh? | `gitnexus://repo/<name>/context` resource |
| Prior conversation on feature? | `mempalace_search` |

### Stage 1 — Explore

| Action | Tool |
|--------|------|
| Concept search — "how does X work" | `gitnexus_query` |
| Symbol detail | `gitnexus_context` |
| API endpoint discovery | `gitnexus_route_map` |
| "Why was it built this way" | `mempalace_kg_query` + `kg_timeline` |

### Stage 2 — Plan (before code change)

| Action | Tool | Mandatory? |
|--------|------|-----------|
| Blast radius for symbol | `gitnexus_impact({target, direction:"upstream"})` | **YES** |
| API contract impact | `gitnexus_api_impact` | If touching API |
| Schema impact | `gitnexus_shape_check` | If touching DB/types |
| Past similar planning | `mempalace_kg_query` | When in doubt |

### Stage 3 — Implement

| Action | Tool |
|--------|------|
| Rename symbol | `gitnexus_rename` |
| Verify caller before mod | `gitnexus_context` |

### Stage 4 — Pre-commit

| Action | Tool | Mandatory? |
|--------|------|-----------|
| Verify scope of changes | `gitnexus_detect_changes()` | **YES** |

### Stage 5 — Post-merge

| Action | Tool | When |
|--------|------|------|
| Reindex | `npx gitnexus analyze` | ≥5 files / structural refactor / new module / index warning |
| Save major decision | `mempalace_kg_add` | Architecture choice / non-obvious workaround |

### Stage 6 — Session end

| Action | Tool |
|--------|------|
| Summary note | `mempalace_diary_write` (or auto via Stop hook) |
| Mark stale fact | `mempalace_kg_invalidate` if code contradicted memory |

## Reindex strategy — `npx gitnexus analyze`

Index goes stale → tools return wrong facts (function moved, signature changed, calls renamed).

### Trigger reindex when

- ✅ Tool warning "index is stale" appears
- ✅ Just merged PR with ≥5 files changed
- ✅ Structural refactor (split package / move module / rename namespace)
- ✅ New module added (new top-level dir)
- ✅ User asks "audit whole system"
- ✅ Weekly cadence as safety net

### Don't reindex when

- ❌ After every commit (too expensive)
- ❌ After typo / 1-line fix
- ❌ During active task (blocks tools mid-flow)
- ❌ Recent reindex (<2 hours) + no big change since

### How to run

```bash
cd /path/to/repo
npx gitnexus analyze
```

Run in user terminal, NOT via Bash tool (long-running, blocks Claude session).
Lead suggests user run; user executes.

## MemPalace lifecycle

### When to query (read)

- Verify-first phase: "have we decided this before?"
- User asks "why" → check rationale in KG
- About to make architecture decision → check past similar
- 3rd agent same issue → past attempts may be in KG

### When to add (write)

Save when ALL true:
- Decision is architectural / non-obvious / load-bearing
- Future session would benefit
- Fact won't be obvious from reading current code

| Save (architectural / non-obvious) | Skip (obvious from git log) |
|------|------|
| "Chose tech X over Y because of team expertise / constraint Z" | "Variable renamed from foo to bar" |
| "Service offline, route to alternate" | "Fixed typo in README" |
| "Cross-subdomain cookie requires `.example.com` domain" | "Bumped lib version" |
| "Workaround for upstream bug #1234 — remove when fixed" | "Reformatted file" |

### When to invalidate

- Code change contradicts stored fact
- User corrects ("no, we use Y now")
- Periodic review reveals stale entry

### MemPalace + verify-first

Before recommending from KG:
1. Verify file/symbol still exists (`Read` / `gitnexus_context`)
2. Check code matches stored claim
3. Mismatch → invalidate + use current state

## When auto-trigger hooks fail

If hook output silent / errors / mempalace CLI unavailable:
- SessionStart no context → Lead manually checks git log, queries MemPalace via MCP if available
- PostBash hooks silent → Lead manually runs `gitnexus_detect_changes` before commit
- Stop hook fails → Lead manually saves key decision via `mempalace_kg_add` if session had architectural choice

Hooks = nice-to-have. Lead's manual checkpoints = mandatory regardless.

## Skill commands (user-invokable)

Existing project skills in `.claude/skills/gitnexus/`:
- `gitnexus-exploring/SKILL.md`
- `gitnexus-impact-analysis/SKILL.md`
- `gitnexus-debugging/SKILL.md`
- `gitnexus-refactoring/SKILL.md`
- `gitnexus-pr-review/SKILL.md`
- `gitnexus-cli/SKILL.md`
- `gitnexus-guide/SKILL.md`

Suggested additions (project-specific):
- `/reindex` → `npx gitnexus analyze`
- `/impact <symbol>` → `gitnexus_impact` + format
- `/decision <text>` → `mempalace_kg_add`
- `/recall <topic>` → `mempalace_kg_query` + format

## Common mistakes — DO NOT

- Skip Stage 2 mandatory `gitnexus_impact` before edit
- Skip Stage 4 mandatory `gitnexus_detect_changes` before commit
- Reindex after every commit (waste)
- Save trivial info to KG
- Trust auto-hook output without verifying when stakes are high
