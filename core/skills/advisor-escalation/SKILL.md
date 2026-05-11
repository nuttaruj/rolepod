---
name: advisor-escalation
description: Consult Claude Opus when Lead (Sonnet/Haiku) is stuck on root cause, architecture, or convergence.
when_to_use: '"stuck", "consult Opus", "advice mode", "/advice", third agent on same issue, 50k tokens no convergence, architecture decision needing 2nd opinion'
---

# Advisor Tool — Consult Opus

Read when: Lead = Sonnet/Haiku + stuck.

Docs: https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

## What

Consult Claude Opus from current session. Lead stays. Opus answers 1 specific question.

Pattern: smaller model executes, escalates judgment to bigger model.

## When to use

Lead = Sonnet/Haiku AND any of:

- Root cause analysis too complex (model spinning)
- Architecture decision needs Opus 2nd opinion
- 3rd agent on same issue (CLAUDE.md hard stop)
- 50k+ tokens no convergence
- Multi-system tradeoff (perf vs correctness vs cost)
- User says "consult Opus" / "advice mode" / "/advice"
- Big task high blast radius — verify approach before exec

## When NOT to use

- Lead = Opus already (latency + cost, zero gain)
- Simple lookup ("where is X defined") → GitNexus
- Mechanical task → just do it
- Question user answers faster → ask user

## Invoke

```
Advisor consultation needed.
Context: [1-2 sentence problem]
Specific question: [what you want Opus to decide]
Constraints: [tried / non-negotiable]
Expected output: [decision / approach / yes-no / ranked options]
```

Keep focused. Opus answers — doesn't take over.

## What to ask

Good:
- "Two architectures: A (microservice) vs B (monolith). Tradeoffs for our scale?"
- "Bug under concurrent load. 3 hypotheses wrong. Other angles?"
- "30-file refactor: 1 PR or 5?"
- "Race fix: optimistic vs pessimistic vs queue serialization?"

Bad:
- "Can you fix this bug?" (too broad — no context)
- "Write the code for X" (Lead's job)
- "Is this code correct?" (reviewer flow)

## After Opus responds

Lead **interprets**. Doesn't blindly apply.
- Disagree → push back, follow-up
- Missing context → re-ask with more detail
- Clear → execute and verify

## Position in workflow

```
Stuck →
  ├─ Fresh angle
  ├─ MemPalace past similar
  ├─ Specialist subagent
  └─ Still stuck → Advisor → resume
```

Advisor = escalation, not first resort.

## Cost

Each call = Opus tokens. Sparingly. 1 well-framed > 5 vague.

## Common mistakes — DO NOT

- Advisor when Lead = Opus
- Ask Opus to "do the task" — ask for decision/approach
- Skip framing context — Opus has zero session memory
- Advisor instead of qa-tester (review = reviewer flow)
- Advisor as default escalation — try MemPalace + subagent first
