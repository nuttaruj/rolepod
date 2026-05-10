---
name: user-facing-content
description: Write user-facing content that helps people, not impresses them. Covers FAQs, error messages, onboarding flows, empty states, help articles, and any text the end user reads inside the product or in support contexts.
---

# User-Facing Content

The text in your product is part of the product. A confusing error message creates a support ticket. A clear one prevents one. This skill is about the writing that meets the user when something is harder than expected — and helps them keep going.

## When to use

- Writing or auditing error messages
- Onboarding flow copy (first-run, empty states, tutorials)
- FAQ / help center articles
- In-app tooltips, microcopy, button labels
- Email templates triggered by product events (welcome, password reset, payment failed)
- Status messages, system notifications, confirmation dialogs

Skip for: marketing copy (different skill — different goal), internal docs, technical reference.

## Three principles

1. **Help, don't sell.** Marketing copy persuades. User-facing content explains. The tone shift is real and visible.
2. **Match the user's emotional state.** Frustrated users don't want jokes. Lost users don't want clever metaphors.
3. **Be specific where it matters, brief where it doesn't.** "Your file couldn't be saved because the connection dropped — try again." beats "Oops! Something went wrong."

## Plain language baseline

- 8th-grade reading level for general audiences. Lower if you're addressing distress (errors, support).
- Short sentences. One idea per sentence.
- Active voice. "We saved your changes" beats "Your changes have been saved."
- Concrete nouns. "Your invoice" beats "the requested document."
- Cut filler. "Please note that you may want to consider..." → "You can..."

## Error messages — the most important content in the product

Most apps treat errors as a chore. Errors are the moment the user is most likely to leave. Write them carefully.

A good error message has three parts:

```
1. What happened — in their language, not yours
2. Why it happened — only if it helps them act
3. What they can do next — concrete next step
```

Examples:

| Bad | Good |
|-----|------|
| "Error 500: Internal Server Error" | "We couldn't save your post. We've been notified — try again in a minute." |
| "Invalid credentials" | "Email or password didn't match. Try again, or reset your password." |
| "Operation failed" | "We couldn't process your payment. Your card wasn't charged. Check the card details and try again." |
| "Required field" | "Add your email so we can send the receipt." |
| "Network error" | "Couldn't reach the server. Check your connection and try again." |

Rules:

- Never blame the user. "You entered the wrong password" → "Email or password didn't match."
- Never expose stack traces, codes, or internal paths to end users (logs are for engineers).
- Always offer a next action. "Try again" is the minimum; specific is better.
- Match severity to tone. A failed save needs calm clarity, not exclamation points.

## Onboarding and empty states

The first 60 seconds set everything. The empty state is your first impression.

- **Show what success looks like.** Show a populated example, not just "Add your first item."
- **One next action.** Don't list five things. Pick the most important.
- **Reduce decision fatigue.** Sensible defaults, skip-able steps, clear progress.
- **Talk like a teammate, not a wizard.** "Let's get your first project set up" beats "Welcome to the onboarding wizard."
- **Acknowledge the user's reality.** "We know setting this up takes a few minutes — here's what you'll get."

Empty state hierarchy:

1. Headline: what this view is for
2. One sentence: why it's empty and what to do
3. Primary action button
4. Optional: link to a richer guide for users who want depth

## FAQ and help articles

FAQs aren't a dumping ground for everything. They're a curated answer to questions you actually receive.

- **Real questions only.** If support has never been asked it, it doesn't go in the FAQ.
- **Question-shaped headings.** Users scan for their question, not your topic name.
- **Answer first, context after.** "Yes — here's how" or "No — here's why" in the first sentence.
- **Show, don't only tell.** Screenshots, GIFs, short clips for anything visual.
- **Date your articles.** "Last updated: Mar 2026" — UI changes; old screenshots mislead.
- **Link to the action.** If the answer is "go to settings," provide a deep link.

## Microcopy — the small text that does big work

Buttons, labels, hints, placeholders, tooltips.

- **Action verbs on buttons.** "Save changes" beats "Submit." "Send invite" beats "OK."
- **Avoid yes/no buttons in destructive flows.** "Delete account" / "Cancel" — the action is the label.
- **Placeholder ≠ label.** Placeholders disappear; required labels stay.
- **Helper text under inputs explains intent.** "We'll send a confirmation here."
- **Tooltips for clarification, not for hiding important info.**

## Tone and voice

Match the moment. Same product, different moments, different tone.

| Moment | Tone |
|--------|------|
| Welcoming new user | Warm, encouraging, brief |
| Routine action | Neutral, fast |
| Error | Calm, specific, no humor |
| Success after effort | Brief acknowledgement, no fanfare |
| Destructive action | Slow down, be precise, confirm |
| Account / billing issue | Reassuring, factual, action-first |
| Long wait / slow operation | Honest about what's happening |

A friendly product can still be serious when the user is upset. Don't make jokes during outages.

## Accessibility and inclusion

User-facing content is read by screen readers, translated, scanned by people who don't read English natively. Write for that.

- Don't rely on color alone to convey meaning.
- Write meaningful link text — never "click here" or "more."
- Avoid idioms that don't translate ("piece of cake," "ballpark figure").
- Use gender-neutral language by default — "they" works.
- Don't use ableist phrasing ("crazy", "lame", "blind to") in product copy.
- Read content aloud. Hard to say = hard to read.

## Common mistakes

- Error messages that say "something went wrong" with no next step
- Onboarding that explains the UI instead of getting the user to value
- Empty states that scold ("You haven't added any...")
- Tooltips full of critical information the user needed before clicking
- "Please" + "kindly" + "if you wouldn't mind" — pad without warmth
- Long welcome emails with five CTAs and no clear primary action
- Help articles written for the system's vocabulary instead of the user's
- Confirmation dialogs with "OK" / "Cancel" for destructive actions (re-state the action)
- Copy approved by committee where every team added a sentence and clarity died

## Quick reference — does this copy pass?

```
1. Would my user understand this without internal context?
2. Is there a clear next action?
3. Does the tone match the moment?
4. Is the most important word in the most important position?
5. Did I cut every word that doesn't earn its space?
6. Would a stressed user, on a phone, in a hurry, get this right?
```

Six yeses → ship. Any no → revise.

## Output checklist for a content audit

- [ ] All error states have a clear next action
- [ ] All empty states show what success looks like
- [ ] No internal jargon visible to end users
- [ ] No stack traces, codes, or paths leaked to users
- [ ] Microcopy is verb-led where it should be
- [ ] Tone matches each moment, not just one global voice
- [ ] Accessibility checks pass (color, link text, language)
- [ ] Help articles dated, with current screenshots
