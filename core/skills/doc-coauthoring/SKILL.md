---
name: doc-coauthoring
description: Co-author docs, specs, and proposals with a user through structured iteration rather than one-shot drafting. Use when the user wants to write a document together — interview, outline, draft, refine — instead of "just write me one."
---

# Doc Co-Authoring

User co-wrote → doc gets used. Claude wrote alone → pasted, deleted.

## When to use

- "Help me write a [proposal / spec / doc / RFC]"
- Topic needs user's domain knowledge (Claude structures, can't invent facts)
- Multiple stakeholders, user owns result
- First draft exists but feels off
- Long-form where one-shot misses context

Skip: purely templated (changelog from diff), user has complete draft wanting line edits, fully derivable from code.

## The four phases

```
1. Frame      → What is this, who reads it, success criterion?
2. Outline    → Sections with one-line intent each
3. Draft      → Section by section, user reviews each
4. Refine     → Line-level pass for clarity, tone, redundancy
```

Don't skip. Don't merge. Each catches mistakes the next can't.

### 1. Frame

Ask before writing:
- **Audience** — who reads? what do they know? not know?
- **Decision** — what should reader do/decide after?
- **Length budget** — one page? Five? 30-page deck? Hard cap up front.
- **Voice** — first person, team, formal, conversational?
- **Constraints** — must-include sections, must-avoid topics, templates

Write Frame back as 5-line summary. Get yes before moving on.

### 2. Outline

Section list, 1-line intent + rough length:

```
1. Problem (½ page) — what's broken, with concrete examples
2. Proposal (1 page) — what we'll build, high level
3. Tradeoffs (½ page) — what we're not doing, why
4. Rollout (½ page) — phasing, flags, fallback
5. Open questions (¼ page) — what's still undecided
```

Get user approval. Cheapest place to fix structural problems. Restructuring at draft = 10x more expensive.

### 3. Draft

Section by section, NOT all at once.

- Draft first section
- Show user
- Get changes
- Apply, check tone against rest of planned doc
- Draft next section

Tone calibrates early. "Punchy and short" vs delivered "academic exhaustive" — catching after section 1 saves whole doc.

User input needed for facts (numbers, internal context, stories) → pause and ask. Don't make up plausible details.

### 4. Refine

Final pass after full draft. Read end-to-end:

- Opening hook matches closing call?
- Each section necessary? Cut what doesn't serve decision.
- Three different ways saying same thing? Pick one.
- Ladder of abstraction stable? Don't bounce vision↔implementation per paragraph.
- Works for reader who only reads headings + bold? (Many will.)

## Disagreement handling

User pushes back:
- Don't re-justify. Their judgment about their audience beats your patterns.
- One clarifying question if you don't understand the change
- Apply in user's voice
- Don't silently revert other parts to "your version"

## Common mistakes

- Skip Frame, produce beautiful doc for wrong audience
- Draft all sections at once, tone off by section 5
- Invent numbers/quotes/names — ASK
- Add boilerplate ("Background", "Glossary") because docs "usually have it"
- Treat user edits as wrong and re-argue
- Refine before draft complete (polish text about to be cut)
- Dump outline + draft + refine in one response

## Quick reference

| Symptom | Phase to revisit |
|---------|------------------|
| "Doesn't sound like us" | Frame — voice/audience |
| "Why is section 3 here?" | Outline — section intent |
| "Numbers are wrong" | Draft — ask, don't invent |
| "Too long" | Refine — cut, don't compress |
| "I rewrote it heavily" | Frame — missed audience |

## Output checkpoint

At each phase boundary:

```
Phase complete: [Frame / Outline / Draft / Refine]
Decisions captured: [bullets]
Open questions for you: [bullets, or "none"]
Proposed next step: [phase + scope]
```

Don't proceed without user OK.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Faster to write myself" | Solo docs miss reader's question. Co-authoring catches author↔reader model gap. |
| "Simple change, no skill needed" | DAPLab: 41% failures in 'trivial' diffs. |
| "I already know" | Confirmation bias. |
| "Time pressure" | 5 min saved = 50 min debugging. |

Default: run skill.
