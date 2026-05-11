---
name: internal-comms
description: Write clear internal communication — status updates, announcements, decision memos, escalations, retros. Conveys information without selling.
when_to_use: for messages whose audience is teammates, leadership, or cross-functional partners
---

# Internal Comms

Internal writing fails when people act on the wrong thing because the message was unclear, buried, or padded.

## When to use

- Weekly/monthly status update to leadership
- Cross-team announcement (launch, change, deprecation)
- Decision memo needing sign-off
- Escalation when stuck
- Postmortem / retro summary
- Onboarding doc for internal process
- Async update replacing a meeting

Skip: external customer comms, technical reference docs, marketing copy.

## Universal rules

1. **Lead with the answer.** First sentence: what this is, what I should do.
2. **BLUF.** If reader stops at line one, they should still know the most important thing.
3. **One purpose per message.** Status update with 3 asks gets none.
4. **Structure ruthlessly.** Headings, bullets, tables. Walls of prose lose readers.
5. **Name owners and dates.** "Someone should look at this" produces nothing. "Alex, by Friday" produces something.
6. **Cut hedging.** "It might possibly be the case that" → "we think."
7. **Match formality to audience.**

## Format templates

### Status update

```
[Project/team] — [date range]

TL;DR
[1-3 sentences. The headline.]

This period
- [What shipped/progressed]
- [What we learned]

Next period
- [What's planned, with owners]

Risks / blockers
- [Issue] — [impact] — [what we need]

Asks
- [Specific request, recipient, date]
```

### Announcement

```
What: [the change, one sentence]
When: [date/time/phasing]
Who is affected: [audience]
Why: [1-2 sentences]
What you need to do: [actions, or "nothing"]
Where to ask questions: [channel/person]
```

If "what you need to do" is longest → it's an instruction doc, not announcement.

### Decision memo

```
Decision needed: [one sentence]
Recommendation: [one sentence]
By when: [date]
Decider: [name]

Context
[Background needed to evaluate]

Options considered
- A: [summary, pros, cons]
- B: [summary, pros, cons]
- C: [summary, pros, cons]

Recommendation rationale
[Why A over B and C, 2-4 sentences]

Risks
[What could go wrong, what to watch]

Questions for decider
```

Decider should be able to skim everything except Recommendation and leave thumbs up if they trust you.

### Escalation

```
Issue: [one sentence]
Impact: [who's affected, how badly]
What I've tried: [actions, results]
What I need: [help, decision, resource — be specific]
By when: [deadline + what happens if missed]
```

Escalations fail when they read like complaints. Lead with what you tried.

### Postmortem / retro

```
What happened: [user-visible impact, timeline]
Why: [root cause, not trigger]
What worked: [credit explicitly]
What didn't: [the gap, blamelessly]
Actions: [what + owner + date]
```

Blameless. Owners on actions.

## Channel choice

| Audience | Time-sensitivity | Channel |
|----------|-----------------|---------|
| 1-2 | Low | DM |
| 1-2 | High | DM + ping |
| Team (5-15) | Low | Channel post |
| Team | High | Channel + at-mentions |
| Cross-team | Medium | Email or doc + channel link |
| Org-wide | Any | Doc + email + channel link |

>5 paragraphs in chat thread → move to doc. Threads collapse context.

## Subject lines

Read in list of 30. Front-load verb or conclusion.

- Bad: "Update" → Better: "Q3 update" → Best: "Q3 update — on track for revenue, behind on hiring"
- Bad: "Question" → Better: "Question on billing migration timeline" → Best: "Need decision by Thu: billing migration timeline"

## Tone calibration

| Audience | Tone |
|----------|------|
| Peers | Direct, casual, jokes OK |
| Skip-level / leadership | Direct, structured, no slang |
| Cross-functional | Direct, contextual, define internal jargon |
| All-hands | Warmer, still direct |
| Board / investors | Tight, structured, careful with claims |

Direct = constant. Adjust formality, not clarity.

## Common mistakes

- Buried lede — actual ask in paragraph 4
- Multiple unrelated topics in one message
- "Per my last email" — restate, don't shame
- Assuming reader has full context
- Vague question ("thoughts?") to busy person — give binary or draft
- "Soon" / "shortly" / "ASAP" instead of date
- Long Slack thread that should have been a doc on day one
- Announcement before affected people heard from manager
- Over-formality during incidents reads as evasive; over-casual reads as careless

## Quick reference — every message

```
Q1: What do I want reader to do or know?
Q2: Did I say it in the first sentence?
Q3: Can a busy reader skim and still get it right?
Q4: Are owners and dates named for every action?
Q5: Did I cut every word that doesn't earn space?
```

Five yeses → send.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Quick Slack will do" | Quick Slacks bury context needed 3 weeks later. Structure once = searchable forever. |
| "Simple change" | 41% of agentic-LLM failures hide in trivial diffs (DAPLab). |
| "Time pressure" | Tech debt compounds. |

Default: run anyway.
