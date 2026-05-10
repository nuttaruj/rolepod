# Advisor Tool — Consult Opus

Read when: Lead = Sonnet/Haiku + stuck on hard problem.

Docs: https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

## What it is

Advisor tool = consult Claude Opus from current session.
Lead stays as-is. Opus answers 1 specific question. Result returned to Lead.

Pattern: smaller model handles execution, escalates judgment calls to bigger model.

## When to use

Lead is **Sonnet or Haiku** AND any of:

- Root cause analysis too complex (current model spinning)
- Architecture decision needs Opus-level second opinion
- 3rd agent on same issue (CLAUDE.md hard stop)
- 50k+ tokens no convergence
- Multi-system tradeoff (perf vs correctness vs cost)
- User explicitly says "consult Opus" / "advice mode" / "/advice"
- Big task with high blast radius — verify approach before execution

## When NOT to use

- **Lead = Opus already** → advisor adds latency + cost, zero gain
- Simple lookup ("where is X defined") → use GitNexus
- Mechanical task → just do it
- Question user can answer faster → ask user instead

## How to invoke

```
Advisor consultation needed.
Context: [1-2 sentence problem]
Specific question: [what you want Opus to decide]
Constraints: [what's already tried / non-negotiable]
Expected output: [decision / approach / yes-no / ranked options]
```

Keep prompt focused. Opus answers the question — doesn't take over the task.

## What to ask Opus

Good asks:
- "Two valid architectures: A (microservice) vs B (monolith). Tradeoffs for our scale?"
- "Bug reproduces only under concurrent load. 3 hypotheses tried, all wrong. Other angles to investigate?"
- "Plan for 30-file refactor: split as 1 PR or 5 PRs?"
- "Race condition fix: optimistic lock vs pessimistic vs queue serialization — which fits this domain?"

Bad asks:
- "Can you fix this bug?" (too broad — Opus can't see your context)
- "Write the code for X" (Lead's job, not Opus's)
- "Is this code correct?" (use reviewer flow instead)

## After Opus responds

Lead **interprets** advice. Doesn't blindly apply.
- Disagree with reasoning → push back, ask follow-up
- Advice misses context → re-ask with more detail
- Advice clear → execute and verify

## Position in workflow

```
Stuck → 
  ├─ Try once more with fresh angle
  ├─ Check MemPalace for past similar problem
  ├─ Spawn specialist subagent (might unstick)
  └─ Still stuck → Advisor (Opus) → resume
```

Advisor = escalation, not first resort.

## Cost note

Each advisor call = Opus tokens. Use sparingly.
1 well-framed advisor call > 5 vague ones.

## Common mistakes — DO NOT

- Use advisor when Lead = Opus
- Ask Opus to "do the task" — ask for **decision** or **approach**
- Skip framing context — Opus has zero memory of your session
- Use advisor instead of qa-tester (review = reviewer flow, not advisor)
- Use advisor as default escalation — try MemPalace + subagent first
