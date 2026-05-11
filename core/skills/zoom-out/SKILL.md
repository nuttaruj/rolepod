---
name: zoom-out
description: Step back from implementation details to high-level perspective. Meta-cognitive recovery tool.
when_to_use: when stuck in details, drifting from goal, multiple correction rounds, or losing sight of the actual problem
---

# Zoom Out

Deep in code → lose sight of problem. Restore perspective.

## When to use

- 3+ files read in a row
- 2nd correction on same issue
- Lost track of what user asked
- Implementation feels harder than expected
- 50k+ tokens, no convergence
- Lead drift triggers (per `triage-deep.md`)

## Protocol

Answer in order, in response.

### Z1 — What did user actually ask?

Quote verbatim. Not paraphrase.

### Z2 — What am I doing right now?

One sentence. Current sub-task.

### Z3 — Does Z2 serve Z1?

- YES → continue, check Z4
- NO → STOP, return to Z1, drop current path
- PARTIAL → identify drift, prune

### Z4 — Simplest path forward?

3 alternatives:
- A: continue current (cost? success likelihood?)
- B: restart different angle
- C: ask user for clarification

Pick lowest-cost with reasonable success.

### Z5 — Have I been here before?

`mempalace_kg_query` for similar past problem. Solved? How?

### Z6 — Should I delegate?

Per Q1-Q4 (CLAUDE.md). Yes → hand off via Agent tool.

## Output format

```
Zoom out:
- User asked: [verbatim]
- Currently: [1-sentence activity]
- Drift check: [aligned / drifted / unsure]
- Decision: [continue / restart / delegate / ask user]
- Reason: [1-sentence why]
```

## Common drift patterns

| Pattern | Recovery |
|---------|----------|
| "Just one more file" (3rd time) | Hard stop — wrong scope |
| "Let me also fix this related thing" | Out of scope, mention, don't do |
| Multi-file refactor without plan | Stop, write plan, get user OK |
| Debugging chain 5+ hypotheses | Step away, write known/unknown |
| "Almost done" for 30+ min | Ship partial + report |

## After zoom-out

Either:
- Continue with renewed focus (write 1-line plan first)
- Hand off to specialist
- Ask user for input
- Declare blocked + summarize tried

NEVER continue without explicit decision.

## Anti-pattern — DO NOT

- Skip zoom-out because "almost done"
- Use as procrastination instead of acting
- Repeat without changing approach

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm almost done" | 'Almost done' for 30+ min IS the drift signal. Zoom-out costs 60s; wrong path costs rest of session. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
