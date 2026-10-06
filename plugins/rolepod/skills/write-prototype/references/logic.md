<!-- Adapted from mattpocock/skills prototype LOGIC.md (MIT). Load from write-prototype Pick the branch. -->

# Logic Prototype

A single, self-contained HTML file (a shareable demo) that lets anyone drive a state model by clicking buttons. Use this when the question is about business logic, state transitions, or data shape: the kind of thing that looks reasonable on paper but only feels wrong once it is pushed through real cases.

Because it is one file with nothing to install, hand it to a non-developer (a designer, a PM, a domain expert) and let them feel the model for themselves. So it speaks their language — `CONTEXT.md` terms for the domain — not the code's.

## Process

### 1. State the question

Before writing code, write down what state model and what question this prototypes. One paragraph, at the top of the demo. A logic prototype that answers the wrong question is pure waste, so make the question explicit so it can be checked later, whether the user is watching now or returning to it AFK.

### 2. Isolate the logic in a portable module

Put the actual logic (the bit answering the question) in a single `<script>` block written as a small, pure module. The page around it is throwaway; this module is the validated design.

The right shape depends on the question:

- A pure reducer: `(state, action) => state`. Good when actions are discrete events and state is a single value.
- A state machine: explicit states and transitions. Good when "which actions are even legal right now" is part of the question.
- A small set of pure functions over a plain data type. Good when there's no implicit current state, just transformations.
- A class or module with a clear method surface when the logic genuinely owns ongoing internal state.

Pick whichever shape best fits the question, not whichever is easiest to wire to a page. Keep it pure: no DOM, no `document`, no button handlers reaching inside it. The page calls into it; nothing flows the other direction.

### 3. Build the shareable HTML file

One file, plain HTML/CSS/JS: no framework, no bundler, no server, everything inline so it opens by double-click and survives being emailed around. Anyone should be able to run it by opening it.

Write it for a non-developer. Every label is in domain language — `CONTEXT.md` terms — not code: buttons and state read like the business, not the reducer. Explain in plain words what's happening.

Lay it out with a clean hierarchy, top to bottom:

1. Title and one-line explanation of what this demo lets you explore (the question from step 1).
2. Current state: the full relevant state, rendered as a readable panel (labelled fields, not a raw JSON dump), re-rendered after every click so the change is visible. Where it helps a non-developer follow, call out what just changed.
3. Free-play buttons: one button per action, always available, so anyone can poke at the model in any order. Each click dispatches its action and re-renders the state.
4. Guided walkthroughs: a set of scenarios, one per tab. Each tab holds a short plain-language description of the scenario (the situation it sets up and what to watch for) and underneath it, the ordered buttons to press for that scenario. Each step is a real button: clicking it performs that action and moves to the next step. Starting a walkthrough resets to a known initial state so the scenario runs the same way every time.

Choose scenarios that demonstrate the awkward cases, the ones hard to reason about on paper: the happy path, a tricky edge case, an attempt at something that should be illegal.

Keep it beautiful but restrained: clean typography, generous spacing, one accent colour. No animations, no gimmicks: nothing that competes with the state and the buttons.
