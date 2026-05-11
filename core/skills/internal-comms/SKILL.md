---
name: internal-comms
description: Write clear internal communication — status updates, announcements, decision memos, escalations, retros. Use for messages whose audience is teammates, leadership, or cross-functional partners and whose job is to convey information without selling.
---

# Internal Comms

Internal writing fails differently from marketing writing. Marketing copy fails when nobody acts. Internal copy fails when people act on the wrong thing because the message was unclear, buried, or padded. This skill is about the formats and habits that make a busy reader's day easier.

## When to use

- Weekly / monthly status update to leadership
- Cross-team announcement (launch, change, deprecation)
- Decision memo that needs sign-off
- Escalation when something is stuck or going sideways
- Postmortem / retrospective summary
- Onboarding doc for an internal process
- Async update replacing what would have been a meeting

Skip for: external customer comms (different skill), technical reference docs, marketing copy.

## Universal rules

1. **Lead with the answer.** First sentence tells me what this is and what I should do. No throat-clearing.
2. **Bottom-line up front (BLUF).** If the reader stops at line one, they should still know the most important thing.
3. **One purpose per message.** A status update with three asks buried in it gets none of them done. Split them.
4. **Use structure ruthlessly.** Headings, bullets, tables. Walls of prose lose most readers by paragraph two.
5. **Name owners and dates.** "Someone should look at this" produces nothing. "Alex, by Friday" produces something.
6. **Cut hedging.** "It might possibly be the case that" → "we think." "Going forward" → cut.
7. **Match formality to audience.** Skip-level CEO update reads differently than a Slack thread to peers.

## Format templates

### Status update (weekly / monthly)

```
[Project / team] — [date range]

TL;DR
[1-3 sentences. The headline.]

This period
- [What shipped / progressed]
- [What we learned]

Next period
- [What's planned, with named owners]

Risks / blockers
- [Issue] — [impact] — [what we need]

Asks
- [Specific request, named recipient, date]
```

Without a TL;DR, the message ends up being read carefully by no one and skimmed badly by everyone.

### Announcement

```
What: [the change, in one sentence]
When: [date / time / phasing]
Who is affected: [audience]
Why we're doing this: [1-2 sentences]
What you need to do: [action items, or "nothing"]
Where to ask questions: [channel / person]
```

If "what you need to do" is the longest section, you have an instructions document, not an announcement.

### Decision memo

```
Decision needed: [one sentence]
Recommendation: [what we propose, in one sentence]
By when: [date]
Decider: [name]

Context
[Background a smart reader needs to evaluate]

Options considered
- A: [summary, pros, cons]
- B: [summary, pros, cons]
- C: [summary, pros, cons]

Recommendation rationale
[Why A over B and C, in 2-4 sentences]

Risks
[What could go wrong, what we'd watch for]

Questions for the decider
[Anything you want them to weigh in on]
```

The decider should be able to skim everything except "Recommendation" and still leave a thumbs up if they trust you.

### Escalation

```
Issue: [one sentence]
Impact: [who's affected, how badly]
What I've tried: [actions taken, results]
What I need: [help, decision, resource — be specific]
By when: [deadline + what happens if missed]
```

Escalations fail when they read like complaints. Lead with what you've tried — that's what makes the ask credible.

### Postmortem / retro summary

```
What happened: [user-visible impact, timeline]
Why: [root cause, not the trigger]
What worked: [credit it explicitly]
What didn't: [the gap, blamelessly]
Actions: [what + owner + date]
```

Blameless. Owners on actions. Without owners, nothing changes and the same incident recurs.

## Channel choice

| Audience size | Time-sensitivity | Best channel |
|---------------|------------------|--------------|
| 1-2 | Low | Direct message |
| 1-2 | High | Direct message + ping |
| Team (5-15) | Low | Channel post |
| Team | High | Channel post + at-mentions |
| Cross-team | Medium | Email or doc + channel post linking it |
| Org-wide | Any | Doc + email + channel post linking it |
| External-facing | Any | Through the right approval path, not internal-comms |

If you're writing more than 5 paragraphs in a chat thread, move to a doc. Threads collapse context.

## Subject lines and titles — the hardest line

Internal subject lines are read in a list of 30 others. Earn the click.

- Bad: "Update"
- Better: "Q3 update"
- Best: "Q3 update — on track for revenue, behind on hiring"

Bad: "Question"
Better: "Question on the billing migration timeline"
Best: "Need decision by Thu: billing migration timeline"

Front-load the verb or the conclusion. Don't make me open it to learn the topic.

## Tone calibration

| Audience | Default tone |
|----------|--------------|
| Peers | Direct, casual, jokes OK |
| Skip-level / leadership | Direct, structured, no slang, no jokes that age badly |
| Cross-functional partners | Direct, contextual, define internal jargon |
| All-hands / company-wide | Warmer, but still direct |
| External-facing internal (board, investors) | Tight, structured, careful with claims |

Direct is the constant. Adjust formality, don't adjust clarity.

## Common mistakes

- Buried lede — the actual ask is in paragraph 4
- Multiple unrelated topics in one message
- "Per my last email" — restate; don't shame
- Writing as if the reader has full context (they don't)
- Asking a vague question ("thoughts?") to a busy person — give them a binary or a draft to react to
- Using "soon" / "shortly" / "ASAP" instead of a date
- Long Slack thread that should have been a doc on day one
- Sending an announcement before the affected people heard it from their manager
- Tone-deaf comms during incidents — over-formality reads as evasive; over-casual reads as careless

## Quick reference — every message

```
Q1: What do I want the reader to do or know?
Q2: Did I say it in the first sentence?
Q3: Can a busy reader skim and still get it right?
Q4: Are owners and dates named for every action?
Q5: Did I cut every word that doesn't earn its space?
```

Five yeses → send. Any no → revise.

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "Quick Slack will do, no need for a structured update" | Quick Slacks bury context that's needed 3 weeks later when the question resurfaces. Structure once = searchable forever. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
