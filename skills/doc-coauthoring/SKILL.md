---
name: doc-coauthoring
description: Co-author docs, specs, and proposals with a user through structured iteration rather than one-shot drafting. Use when the user wants to write a document together — interview, outline, draft, refine — instead of "just write me one."
---

# Doc Co-Authoring

A document the user co-wrote gets used. A document Claude wrote alone gets pasted, then deleted. This skill is about turning vague "write me X" into a tight loop where the user supplies judgment, you supply structure, and the output reflects both.

## When to use

- User says "help me write a [proposal / spec / doc / RFC]"
- Topic requires the user's domain knowledge — Claude can structure but not invent the facts
- Multiple stakeholders will read it and the user owns the result
- First draft already exists but feels off and needs rework
- Long-form writing where one-shot output would miss context

Skip this skill when: the doc is purely templated (changelog, release notes from a diff), the user has a complete draft and wants only line edits, or the content is fully derivable from code.

## The four phases

```
1. Frame      → What is this, who reads it, what's the success criterion?
2. Outline    → Section structure with one-line intent per section
3. Draft      → Section by section, user reviews each before continuing
4. Refine     → Line-level pass for clarity, tone, redundancy
```

Don't skip phases. Don't merge phases. Each one catches mistakes the next can't.

### 1. Frame

Ask, before writing anything:

- **Audience** — who reads this? What do they already know? What do they not know?
- **Decision** — what should the reader do or decide after reading?
- **Length budget** — one page? Five? A 30-page deck? Hard cap up front.
- **Voice** — first person, team voice, formal, conversational?
- **Constraints** — must-include sections, must-avoid topics, existing templates.

Write Frame back to the user as a 5-line summary. Get a yes before moving on.

### 2. Outline

Produce a section list, each with a 1-line intent and rough length:

```
1. Problem (½ page) — what's broken today, with concrete examples
2. Proposal (1 page) — what we're going to build, at a high level
3. Tradeoffs (½ page) — what we're choosing not to do, and why
4. Rollout (½ page) — phasing, flags, fallback
5. Open questions (¼ page) — what we still need to decide
```

Get user approval on the outline. This is the cheapest place to fix structural problems. Restructuring at draft stage is 10x more expensive.

### 3. Draft

Section by section, NOT all at once.

- Draft the first section.
- Show the user.
- Get changes.
- Apply them and check tone against the rest of the planned doc.
- Draft the next section.

Why: tone calibrates early. If the user wanted "punchy and short" and you delivered "academic and exhaustive," catching it after section 1 saves the whole doc.

When the user's input is needed for facts (numbers, internal context, specific stories), pause and ask. Don't make up plausible-sounding details.

### 4. Refine

Final pass after the full draft exists. Read end-to-end and check:

- Does the opening hook match the closing call?
- Is each section necessary? Cut what doesn't serve the decision.
- Are there three different ways of saying the same thing? Pick one.
- Is the ladder of abstraction stable? Don't bounce between "vision" and "implementation detail" paragraph to paragraph.
- Does the doc work for someone who reads only the headings and bolded lines? (Many will.)

## How to handle disagreement

When the user pushes back on something you wrote:

- Don't re-justify. Their judgment about their own audience beats your generic patterns.
- Ask one clarifying question if you genuinely don't understand the change.
- Apply the change in the user's voice, not yours.
- Don't silently revert other parts to "your version" while editing.

## Common mistakes

- Skipping Frame and producing a beautifully-structured doc for the wrong audience
- Drafting all sections at once and discovering the tone is off in section 5
- Inventing numbers / quotes / names because the user didn't supply them — ASK
- Adding boilerplate ("Background", "Glossary") because docs "usually have it" — only if the audience needs it
- Treating user edits as wrong and re-arguing — they're the author
- Refining before the draft is complete — you'll polish text that's about to be cut
- Dumping the whole outline + draft + refine in one response — defeats the loop

## Quick reference

| Symptom | Phase to revisit |
|---------|------------------|
| "This doesn't sound like us" | Frame — voice / audience |
| "Why is section 3 here?" | Outline — section intent |
| "The numbers are wrong" | Draft — ask, don't invent |
| "It's too long" | Refine — cut, don't compress |
| "I rewrote it" (heavily) | Frame — likely missed audience |

## Output checkpoint format

At each phase boundary, present:

```
Phase complete: [Frame / Outline / Draft / Refine]
Decisions captured: [bullets]
Open questions for you: [bullets, or "none"]
Proposed next step: [phase + scope]
```

Don't proceed without user OK.
