---
name: parallel-contract-orchestration
description: Write a cohesion contract before spawning multiple parallel agents on the same feature. Pattern adopted from evanflow — prevents inter-agent interface drift when 2+ engineering agents touch shared types, invariants, or integration points. Use when Lead is about to spawn multiple agents in parallel and they will produce code that has to compose together.
---

# Parallel Contract Orchestration

When Lead spawns 2+ engineering agents in parallel on the same feature, each agent works in its own context with no view of the others. Without a written contract, the integration touchpoints drift — types diverge, invariants disagree, calling conventions clash — and Lead spends the next round merging incompatible work.

Pattern adopted from evanflow's orchestrator workflow: **write the contract before spawning, write the integration tests RED before any agent writes implementation, verify the RED checkpoint, then let agents work in parallel against a fixed target.**

## When to use

Trigger this skill when ALL of these are true:
- Lead is about to spawn 2 or more agents (engineering, design, or mixed) in parallel
- Their outputs have to compose — shared types, shared API surface, shared data schema, shared invariants, or one agent's output is another agent's input
- The change is non-trivial (>1 file per agent, or any business logic)

If only 1 agent → contract is unnecessary, just brief the agent.
If 2 agents but their outputs are independent (different artifacts, no integration point) → no contract needed.

## When NOT to use

- Single agent task — overhead with no payoff
- Two agents producing fully independent artifacts (e.g. `tech-writer` writes a doc while `frontend-developer` writes a component, and they never integrate)
- "Quick" 2-agent task — the temptation is exactly when drift happens. Don't skip the contract because it feels small.

## Workflow

### Step 1 — Lead writes the contract BEFORE spawning

Path: `.claude/orchestration/<topic>-contract.md`

Required sections:

```markdown
# Contract: <feature name>

## Shared types
<every type that crosses an agent boundary, with exact field names + types>

## Invariants
<rules every agent's code must respect — e.g. "user_id is never null after auth", "credits >= 0 always">

## Integration touchpoints
<exact functions/APIs/events that connect agents — name, signature, who calls, who implements>

## Named integration tests
<test name + what it asserts + which agents it spans — these are the success criteria>

## Out of scope
<things explicitly NOT covered, so agents don't grow into them>
```

The contract is the source of truth. If something isn't in the contract, agents are not allowed to assume it.

### Step 2 — Lead writes the integration tests (RED) to file

Lead writes the **failing** integration tests before spawning any implementation agent. The tests reference types and functions from the contract — they should fail to even import / compile, because nothing is implemented yet.

This is the RED state in TDD terms. The tests are concrete, executable, and locked. They define "done" for the parallel work.

### Step 3 — Spawn agents with the contract in their brief

Each agent's brief must include:

```
Path to contract: .claude/orchestration/<topic>-contract.md
Path to integration tests (RED): tests/integration/<topic>_test.py
Your scope: <which contract sections this agent owns>
You may NOT change: contract types/signatures (escalate to Lead if needed)
You MUST: respect named invariants, make your slice of the integration tests turn green
```

### Step 4 — RED-checkpoint verification (Lead-side, before any GREEN)

Before any agent finishes, Lead verifies:

```
- Integration tests fail with the right error (missing impl, NOT contract drift)
- Each agent's first commit/draft references the contract types correctly
- No agent renamed a contract type or invented a new field
```

If an agent diverged from the contract → Lead corrects in same round (cheap), don't wait for end-of-round merge (expensive).

### Step 5 — Agents implement, Lead merges via integration tests

Once all agents return work:
- Lead runs the integration test suite from Step 2
- Tests pass → integration is real, ship to next phase
- Tests fail → tests are the source of truth, Lead routes the failing assertions back to the right agent

The integration tests are the only acceptance criterion. Individual agent self-reports do not override a failing integration test.

## Quick reference

| Stage | Who | Output |
|-------|-----|--------|
| 1. Write contract | Lead | `.claude/orchestration/<topic>-contract.md` |
| 2. Write RED tests | Lead | `tests/integration/<topic>_test.py` (failing) |
| 3. Spawn agents | Lead | N agent briefs, each with contract path |
| 4. RED-check | Lead | Verify tests still fail for the right reason |
| 5. Implement | Agents | Code that makes their slice green |
| 6. Merge | Lead | Run integration tests, route failures back |

## Common mistakes — DO NOT

- Skip the contract for "just 2 small agents" — that's exactly when drift starts
- Write the contract AFTER spawning — agents have already diverged, contract becomes a referee instead of a spec
- Let agents edit the contract — only Lead changes it; agents escalate if they disagree
- Skip the RED-checkpoint — silent drift in the first 5 minutes is the most expensive bug to fix
- Treat agent self-reports as proof of integration — only the integration test suite is proof
- Allow agents to "improve" types beyond the contract — every type widening or renaming creates a new integration point Lead has to manage

## Influence

Cohesion-contract pattern adopted from [evanklem/evanflow](https://github.com/evanklem/evanflow) — their orchestrator writes a shared spec + RED tests before spawning sub-agents, which we found to be the highest-leverage anti-drift mechanism for multi-agent parallel work.
