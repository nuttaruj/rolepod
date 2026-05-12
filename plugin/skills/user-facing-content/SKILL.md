---
name: user-facing-content
description: Write user-facing content that helps people, not impresses them.
when_to_use: FAQs, error messages, onboarding flows, empty states, help articles, and any text the end user reads inside the product or in support contexts
---

# User-Facing Content

Product text = part of the product. Confusing error = support ticket. Clear error = prevented one.

## When to use

- Error messages
- Onboarding (first-run, empty states, tutorials)
- FAQ / help articles
- Tooltips, microcopy, button labels
- Email templates (welcome, reset, payment failed)
- Status messages, notifications, confirms

Skip: marketing copy, internal docs, technical reference.

## Three principles

1. **Help, don't sell.** Marketing persuades; this explains.
2. **Match user's emotional state.** Frustrated users don't want jokes.
3. **Specific where it matters, brief where it doesn't.**

## Plain language baseline

- 8th-grade reading level (lower for distress)
- Short sentences, one idea each
- Active voice ("We saved your changes" > "Your changes have been saved")
- Concrete nouns ("Your invoice" > "the requested document")
- Cut filler

## Error messages — most important text in the product

Three parts:

```
1. What happened — in their language
2. Why — only if it helps them act
3. What they can do next — concrete step
```

| Bad | Good |
|-----|------|
| "Error 500" | "We couldn't save your post. We've been notified — try again in a minute." |
| "Invalid credentials" | "Email or password didn't match. Try again, or reset your password." |
| "Operation failed" | "We couldn't process your payment. Your card wasn't charged. Check the details and try again." |
| "Required field" | "Add your email so we can send the receipt." |
| "Network error" | "Couldn't reach the server. Check your connection and try again." |

Rules:
- Never blame ("You entered wrong password" → "Email or password didn't match")
- Never expose stack traces / codes / paths to end users
- Always offer next action
- Match severity to tone — no exclamation points on failed save

## Onboarding and empty states

First 60 seconds set everything.

- **Show what success looks like** — populated example, not "Add your first item"
- **One next action** — don't list five
- **Sensible defaults, skip-able steps, clear progress**
- **Talk like a teammate** — "Let's get your first project set up" > "Welcome to the onboarding wizard"

Empty state hierarchy:
1. Headline: what this view is for
2. One sentence: why empty, what to do
3. Primary action
4. Optional: link to richer guide

## FAQ and help articles

- **Real questions only** — if support never gets asked, skip
- **Question-shaped headings** — users scan for their question
- **Answer first, context after** — "Yes — here's how" / "No — here's why" in first sentence
- **Show with screenshots/GIFs for visual answers**
- **Date articles** — "Last updated: Mar 2026"
- **Link to action** — deep link to settings

## Microcopy

- **Action verbs on buttons** — "Save changes" > "Submit", "Send invite" > "OK"
- **No yes/no on destructive** — "Delete account" / "Cancel" — action = label
- **Placeholder ≠ label** — placeholders disappear
- **Helper text explains intent** — "We'll send a confirmation here"
- **Tooltips for clarification, not hiding critical info**

## Tone

| Moment | Tone |
|--------|------|
| New user | Warm, encouraging, brief |
| Routine action | Neutral, fast |
| Error | Calm, specific, no humor |
| Success after effort | Brief acknowledgment |
| Destructive | Slow down, precise, confirm |
| Account/billing | Reassuring, factual, action-first |
| Long wait | Honest about what's happening |

Friendly product can still be serious. Don't make jokes during outages.

## Accessibility and inclusion

- Don't rely on color alone
- Meaningful link text (never "click here")
- Avoid idioms that don't translate
- Gender-neutral default ("they")
- No ableist phrasing
- Read aloud — hard to say = hard to read

## Common mistakes

- "Something went wrong" with no next step
- Onboarding that explains UI instead of getting to value
- Empty states that scold ("You haven't added any...")
- Tooltips with critical info needed before clicking
- "Please" + "kindly" + "if you wouldn't mind" — pad without warmth
- Long welcome emails with 5 CTAs
- Articles using system's vocabulary, not user's
- Confirm dialogs with "OK"/"Cancel" for destructive actions
- Committee-edited copy where every team added a sentence

## Quick reference — pass check

```
1. Understandable without internal context?
2. Clear next action?
3. Tone matches the moment?
4. Most important word in most important position?
5. Cut every word that doesn't earn space?
6. Stressed user on phone in a hurry — gets it right?
```

Six yeses → ship.

## Audit checklist

- [ ] All error states have clear next action
- [ ] All empty states show success
- [ ] No internal jargon
- [ ] No stack traces / codes / paths leaked
- [ ] Microcopy is verb-led
- [ ] Tone matches each moment
- [ ] Accessibility passes (color, link text, language)
- [ ] Help articles dated, current screenshots

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Engineers can write it, it's just words" | Engineer-default copy is jargon-loaded; cuts support tickets when done right. |
| "Simple change" | 41% of agentic-LLM failures hide in trivial diffs (DAPLab). |
| "Time pressure" | Tech debt compounds. |

Default: run anyway.
