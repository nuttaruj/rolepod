---
name: context-engineering
description: Optimize agent context — what gets loaded, when, and at what cost. Apply when starting a new session, when output quality degrades, when costs spike, or when designing multi-agent systems. Covers lazy loading, isolation, compression, and the tradeoffs between them.
---

# Context Engineering

An agent's context is its working memory: precious, expensive, and finite. Stuff it with everything and the model gets dull, slow, and costly. Starve it of what matters and the agent guesses. This skill is about choosing what gets in, when, and how much.

## When to use

- Starting a new session — what to preload?
- Agent output quality dropped mid-session
- Token costs higher than expected
- Designing a multi-agent system (lead + subagents)
- Long-running task spans hours and many turns
- Switching between unrelated tasks in same session
- Cache hit rate degraded
- Repeating the same explanation each turn

## How to apply

### 1. Distinguish four context tiers

| Tier | Examples | When loaded |
|------|----------|-------------|
| **Always-on** | Identity, project rules (CLAUDE.md), tool list | Every turn |
| **Task-local** | Files being edited, current goal | Active task only |
| **Lazy** | Reference docs, deep rules, skills | On trigger |
| **Compressed** | Summaries of past work, KG entries | When recall needed |

Tier mismatch is the most common waste — putting reference docs in always-on, putting load-bearing rules in lazy.

### 2. Lazy load — pull, don't push

Default: load on demand, not preemptively.

```
GOOD: skill / rule fires when trigger condition met → load file → apply
BAD:  preload 30 skill files at session start "just in case"
```

Triggers are explicit conditions:
- "About to commit" → load pre-merge gate
- "Editing auth code" → load security rules
- "User asks about pricing" → fetch live pricing, don't recall

A trigger system fails when:
- Triggers overlap (same condition fires 5 skills)
- Triggers are vague ("when relevant" — relevant to whom?)
- Triggers fire too late (post-decision instead of pre-decision)

Fix: each rule states ONE specific trigger condition.

### 3. Isolate — give subagents fresh context

A subagent runs in a separate context window. Its work does not pollute the lead's context. Use this aggressively.

| Task | In lead context | In subagent |
|------|----------------|-------------|
| Investigate how X works (5+ files) | ✗ pollutes lead | ✓ returns summary |
| Implement a 1-file change | ✓ lead does it | ✗ overhead |
| Run tests + report | ✗ output noise | ✓ pass/fail summary |
| Multi-step research | ✗ exhausts lead | ✓ returns findings |
| Quick file read | ✓ lead does it | ✗ overhead |

Lead receives **summary** from subagent — not raw outputs. Lead context stays clean.

### 4. Compress — summarize, don't repeat

When context approaches 50%+ full:

- `/compact <focus>` — manual compaction, biased toward what matters
- Save key decisions to a knowledge graph or notes file
- Drop transient state (tool errors, tangents, abandoned paths)
- Keep: file paths touched, decisions made, current goal, open questions

Compression is lossy. Lose what's truly transient, keep what's load-bearing.

### 5. Refresh — reset between tasks

Switching from morning bug-fix to afternoon feature? `/clear`. The morning's context contaminates the afternoon's plan.

Signals to clear:
- Unrelated next task
- Repeatedly correcting the agent on same point (polluted context)
- Token usage high but progress low
- Stuck in a hypothesis loop

After clear: write a better initial prompt that incorporates what you learned. Clean context + good prompt > polluted context + corrections.

### 6. Cache-aware structure

Cache (Anthropic prompt cache, similar systems) wants stable prefixes. Order content most-stable → least-stable:

```
system prompt (stable)
  ↓
tool definitions (stable)
  ↓
project rules (stable per-project)
  ↓
few-shot examples (stable per-task)
  ↓
conversation history (grows, but append-only)
  ↓
current turn (volatile)
```

Anything that varies (timestamp, random ID, reordered list) before the cache breakpoint kills the cache.

### 7. Multi-agent: brief well, scope tight

When delegating to a subagent:

```
Brief includes:
- Paths (file paths, line numbers)
- Lines (specific ranges)
- Criteria (what "done" looks like)
- Caps (≤12 tool uses, ≤5 files, time budget)
```

Vague brief → subagent guesses → wrong work → wasted round.

Caps prevent runaway: a subagent that reads 40 files isn't isolating context, it's burning tokens. If the task requires 40 files, split into multiple subagents with non-overlapping scopes.

### 8. Verify before recall

Memory (knowledge graph, summaries, "we decided last time") is a snapshot. Code may have moved. Before acting on recalled fact:

1. Verify file/symbol still exists (Read or symbol lookup)
2. Verify code still matches the recalled claim
3. If conflict → trust current state, update or invalidate the memory

A confident wrong recall is worse than a known-unknown.

## Common mistakes

- Loading every skill / rule at session start "for completeness"
- Skipping subagent for big investigations because "context is already loaded"
- Pasting huge command output into context instead of summarizing
- Same explanation re-typed every turn instead of saving to a file the agent can reload
- `/clear` never used — one giant session for everything
- Subagent brief is "fix the bug" with no paths or criteria
- Cache breakpoint after a varying field (timestamp, request ID)
- Trusting memory without verifying current state
- Multi-agent system where each agent reads the same 20 files (no scope filter)
- Preemptively loading docs for libraries you might not even use this session

## Quick reference

| Symptom | Fix |
|---------|-----|
| Agent quality dropped | `/clear` + re-prompt with key context |
| Same correction 3+ times | Polluted context — restart |
| Big investigation looming | Delegate to subagent |
| Cost spike with no quality gain | Cache structure broken — find varying prefix |
| Long session, context near limit | `/compact <focus>` |
| Subagent returned wrong work | Brief was vague — re-brief with paths + criteria |
| Forgotten decision from earlier | Save to KG / notes; recall + verify |
| Repeating instructions per turn | Move to system prompt or project rules file |

## Tradeoffs

- **Lazy load** saves tokens, costs latency on first trigger
- **Isolation** keeps lead clean, costs orchestration overhead
- **Compression** keeps long sessions alive, loses fidelity
- **Refresh** removes pollution, loses session history

Pick the right one for the situation. None is free; all are useful.

## Before each session

- [ ] Clear if unrelated to last session
- [ ] State the goal in one sentence at the top
- [ ] Load only the rules/skills needed
- [ ] Identify which work is delegable

## During each session

- [ ] Watch for drift signals (re-correction, off-topic)
- [ ] Delegate when scope grows
- [ ] Compact if hitting 60%+ full mid-task
- [ ] Save decisions worth recalling
