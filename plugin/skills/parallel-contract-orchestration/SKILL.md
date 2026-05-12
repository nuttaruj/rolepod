---
name: parallel-contract-orchestration
description: Write a cohesion contract before spawning multiple parallel agents on the same feature. Pattern adopted from evanflow — prevents inter-agent interface drift when 2+ engineering agents touch shared types, invariants, or integration points.
when_to_use: when Lead is about to spawn multiple agents in parallel and they will produce code that has to compose together
---

# Parallel Contract Orchestration

2+ parallel agents on same feature each work in isolated context. Without a written contract, integration touchpoints drift — types diverge, invariants disagree — and Lead burns the next round merging.

Pattern from evanflow: **write contract before spawning, write integration tests RED before any agent implements, verify RED checkpoint, then let agents work in parallel against fixed target.**

## Iron Law

<EXTREMELY-IMPORTANT>
1. NEVER spawn 2+ parallel agents touching shared types/invariants/integration points without a written cohesion contract.
2. ALWAYS write integration tests RED before any agent writes implementation. RED checkpoint must pass before spawn.
3. NEVER let agents amend contract mid-flight. Drift = re-converge at Lead, update contract, re-spawn.

Contract = only thing keeping parallel work composable.
</EXTREMELY-IMPORTANT>

## Red Flags

| Thought | Reality |
|---------|---------|
| "Agents will figure out the interface" | They won't. Each context is isolated; interface invisible without contract. |
| "Just 2 agents, I'll merge manually" | Manual merge of disagreeing types = rework one of them. |
| "Integration tests can come after" | Then interface is post-hoc rationalized. Tests = contract executable. |
| "Contract is in my head" | Two briefings drift by round 2. Write it down. |
| "Lead can patch disagreements at merge" | That's the rework you tried to avoid. |

## When to use

Trigger when ALL true:
- About to spawn 2+ agents in parallel
- Outputs must compose (shared types, API surface, schema, invariants, or one's output is another's input)
- Non-trivial (>1 file per agent, or any business logic)

1 agent → no contract.
2 agents producing independent artifacts → no contract.

## When NOT to use

- Single agent
- 2 agents on fully independent artifacts (tech-writer + frontend that never integrate)
- "Quick" 2-agent task — temptation is exactly when drift happens

## Workflow

### Step 1 — Lead writes contract BEFORE spawning

Path: `.claude/orchestration/<topic>-contract.md`

Required sections:

```markdown
# Contract: <feature name>

## Shared types
<every type crossing agent boundary, exact field names + types>

## Invariants
<rules every agent's code must respect — e.g. "user_id never null after auth">

## Integration touchpoints
<exact functions/APIs/events connecting agents — name, signature, who calls, who implements>

## Named integration tests
<test name + assertion + which agents it spans — success criteria>

## Out of scope
<things explicitly NOT covered>
```

Contract = source of truth. Not in contract = not allowed to assume.

### Step 2 — Lead writes integration tests (RED) to file

Failing tests before spawning. Reference contract types/functions. Should fail to import/compile (nothing implemented yet). RED state, locked.

### Step 3 — Spawn agents with contract in brief

Each brief includes:

```
Path to contract: .claude/orchestration/<topic>-contract.md
Path to integration tests (RED): tests/integration/<topic>_test.py
Your scope: <which contract sections this agent owns>
You may NOT change: contract types/signatures (escalate to Lead)
You MUST: respect invariants, make your slice of integration tests green
```

### Step 4 — RED-checkpoint (Lead-side, before any GREEN)

Before any agent finishes:
- Tests fail with right error (missing impl, NOT contract drift)
- First commits reference contract types correctly
- No agent renamed type or invented field

Agent diverged → correct same round (cheap), not end-of-round merge (expensive).

### Step 5 — Implement, Lead merges via integration tests

- Lead runs integration tests
- Pass → ship to next phase
- Fail → tests = source of truth, route failures back

Integration tests = only acceptance criterion. Self-reports don't override failing test.

## Quick reference

| Stage | Who | Output |
|-------|-----|--------|
| 1. Write contract | Lead | `.claude/orchestration/<topic>-contract.md` |
| 2. Write RED tests | Lead | `tests/integration/<topic>_test.py` |
| 3. Spawn agents | Lead | N briefs with contract path |
| 4. RED-check | Lead | Verify tests still fail correctly |
| 5. Implement | Agents | Code making their slice green |
| 6. Merge | Lead | Run tests, route failures |

## Common mistakes

- Skip contract for "just 2 small agents"
- Write contract AFTER spawning — agents already diverged
- Let agents edit contract — only Lead changes
- Skip RED-checkpoint — silent drift in first 5 minutes is most expensive
- Treat self-reports as proof of integration
- Allow "improve" types beyond contract

## Influence

Cohesion-contract from [evanklem/evanflow](https://github.com/evanklem/evanflow) — orchestrator writes shared spec + RED tests before spawning. Highest-leverage anti-drift mechanism for multi-agent parallel work.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Spawn them, they'll figure out interface" | Parallel agents without contract = interface-divergent code 100% of the time. |
| "Simple change" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). |
| "Time pressure" | Tech debt compounds. |

Default: run anyway.
