---
name: zoom-out
description: Step back from implementation details to high-level perspective. Use when stuck in details, drifting from goal, multiple correction rounds, or losing sight of the actual problem. Meta-cognitive recovery tool.
---

# Zoom Out

When deep in code, you lose sight of the problem. This skill restores perspective.

## When to use

- 3+ files read in a row
- 2nd correction on same issue
- Lost track of what user actually asked
- Implementation feels harder than expected
- 50k+ tokens spent, no convergence
- Lead drift triggers fired (per `triage-deep.md`)

## Protocol

Answer these in order. Out loud (in response).

### Z1 — What did the user actually ask?

Quote the user's original request verbatim. Not paraphrase.

### Z2 — What am I doing right now?

One sentence. What's the current sub-task?

### Z3 — Does Z2 serve Z1?

- YES → continue, but check Z4
- NO → STOP, return to Z1, drop current path
- PARTIAL → identify what's drifted, prune

### Z4 — Simplest path forward?

If 3 alternatives:
- A: continue current path (cost: ?, success likelihood: ?)
- B: restart with different angle
- C: ask user for clarification

Pick lowest-cost path with reasonable success.

### Z5 — Have I been here before?

`mempalace_kg_query` for similar past problem. Was it solved? How?

### Z6 — Should I delegate?

Per Q1-Q4 checklist (CLAUDE.md). If yes → hand off via Agent tool.

## Output format

```
Zoom out:
- User asked: [verbatim]
- Currently: [1-sentence current activity]
- Drift check: [aligned / drifted / unsure]
- Decision: [continue / restart / delegate / ask user]
- Reason: [1-sentence why]
```

## Common drift patterns

| Pattern | Recovery |
|---------|----------|
| "Just one more file to fix" (3rd time) | Hard stop — wrong scope |
| "I see — let me also fix this related thing" | Out of scope, mention to user, don't do |
| Multi-file refactor without plan | Stop, write plan, get user OK |
| Debugging chain 5+ hypotheses | Step away, write down what's known/unknown |
| "Almost done" for 30+ minutes | Ship partial + report, don't keep promising |

## After zoom-out

Either:
- Continue with renewed focus (write 1-line plan first)
- Hand off to specialist
- Ask user for input
- Declare blocked + summarize what tried

NEVER continue without explicit decision.

## Anti-pattern — DO NOT

- Skip zoom-out because "almost done"
- Use zoom-out as procrastination instead of acting
- Repeat zoom-out without changing approach

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "I'm almost done, no need to zoom out" | 'Almost done' for 30+ minutes IS the drift signal. Zoom-out costs 60 seconds; chasing a wrong path costs the rest of the session. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
