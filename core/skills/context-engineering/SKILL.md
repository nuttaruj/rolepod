---
name: context-engineering
description: Optimize agent context — what gets loaded, when, and at what cost. Covers lazy loading, isolation, compression, and the tradeoffs between them.
when_to_use: when starting a new session, when output quality degrades, when costs spike, or when designing multi-agent systems
---

# Context Engineering

Context = working memory: precious, expensive, finite. Stuff it → dull/slow/costly. Starve it → guessing.

## When to use

- Starting new session
- Output quality dropped mid-session
- Token costs higher than expected
- Designing multi-agent system
- Long-running task across hours/turns
- Switching unrelated tasks in same session
- Cache hit rate degraded
- Repeating same explanation each turn

## How to apply

### 1. Four context tiers

| Tier | Examples | When loaded |
|------|----------|-------------|
| **Always-on** | Identity, CLAUDE.md, tool list | Every turn |
| **Task-local** | Files being edited, current goal | Active task |
| **Lazy** | Reference docs, deep rules, skills | On trigger |
| **Compressed** | Summaries, KG entries | When recall needed |

Most common waste: reference docs in always-on; load-bearing rules in lazy.

### 2. Lazy load — pull, don't push

Load on demand, not preemptively.

```
GOOD: skill/rule fires when trigger met → load file → apply
BAD:  preload 30 skills at session start "just in case"
```

Triggers fail when: they overlap (same condition fires 5 skills), they're vague ("when relevant"), they fire too late.

Fix: each rule states ONE specific trigger.

### 3. Isolate — fresh context for subagents

Subagent context is separate. Doesn't pollute lead. Use aggressively.

| Task | Lead context | Subagent |
|------|--------------|----------|
| Investigate (5+ files) | ✗ pollutes | ✓ returns summary |
| 1-file change | ✓ lead | ✗ overhead |
| Run tests + report | ✗ output noise | ✓ summary |
| Multi-step research | ✗ exhausts | ✓ findings |
| Quick file read | ✓ lead | ✗ overhead |

Lead gets summary, not raw outputs.

### 4. Compress — summarize, don't repeat

Context >50% full:

- `/compact <focus>` — manual, biased toward what matters
- Save key decisions to KG/notes
- Drop transient state (tool errors, abandoned paths)
- Keep: file paths touched, decisions, current goal, open questions

Compression is lossy. Drop transient, keep load-bearing.

### 5. Refresh — `/clear` between tasks

Signals to clear:
- Unrelated next task
- Repeatedly correcting same point
- High tokens, low progress
- Stuck in hypothesis loop

After clear: better prompt incorporating what you learned. Clean context + good prompt > polluted + corrections.

### 6. Cache-aware structure

Cache wants stable prefixes. Order most-stable → least-stable:

```
system prompt (stable)
  ↓
tool definitions (stable)
  ↓
project rules (stable per-project)
  ↓
few-shot examples (stable per-task)
  ↓
conversation history (append-only)
  ↓
current turn (volatile)
```

Anything varying (timestamp, random ID, reordered list) before cache breakpoint kills cache.

### 7. Multi-agent: brief well, scope tight

Brief includes:
- Paths (file paths, line numbers)
- Lines (specific ranges)
- Criteria (what "done" looks like)
- Caps (≤12 tool uses, ≤5 files, time budget)

Vague brief → wrong work → wasted round.

Subagent reading 40 files isn't isolating, it's burning. Split into multi subagents with non-overlapping scopes.

### 8. Verify before recall

Memory is a snapshot. Code may have moved. Before acting on recalled fact:
1. Verify file/symbol still exists
2. Verify code matches claim
3. Conflict → trust current state, update/invalidate

Confident wrong recall > known-unknown? No.

## Common mistakes

- Loading every skill at session start "for completeness"
- Skipping subagent for big investigations because "context already loaded"
- Pasting huge command output instead of summarizing
- Same explanation re-typed each turn instead of saving to file
- `/clear` never used
- Subagent brief is "fix the bug" with no paths/criteria
- Cache breakpoint after varying field
- Trusting memory without verifying
- Multi-agent where each reads same 20 files

## Quick reference

| Symptom | Fix |
|---------|-----|
| Quality dropped | `/clear` + re-prompt |
| Same correction 3+ times | Polluted context — restart |
| Big investigation looming | Delegate to subagent |
| Cost spike, no quality gain | Cache structure broken — find varying prefix |
| Long session, near limit | `/compact <focus>` |
| Subagent wrong work | Vague brief — re-brief with paths + criteria |
| Forgotten earlier decision | Save to KG; recall + verify |
| Repeating instructions per turn | Move to system prompt or rules file |

## Tradeoffs

- **Lazy load** saves tokens, costs latency on first trigger
- **Isolation** keeps lead clean, costs orchestration
- **Compression** keeps long sessions alive, loses fidelity
- **Refresh** removes pollution, loses history

None is free.

## Before each session

- [ ] Clear if unrelated to last
- [ ] State goal in one sentence
- [ ] Load only needed rules/skills
- [ ] Identify delegable work

## During each session

- [ ] Watch for drift signals
- [ ] Delegate when scope grows
- [ ] Compact at 60%+ mid-task
- [ ] Save decisions worth recalling

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Load everything, it's easier" | Long context drops recall on middle items. Curate beats stuff. |
| "Simple change" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). |
| "Time pressure" | Tech debt compounds. |

Default: run anyway.
