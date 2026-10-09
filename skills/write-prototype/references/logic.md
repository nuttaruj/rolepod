# Logic Prototype

An HTML file you can email around — self-contained, no server, opens in any browser — that makes a state model feel real through interaction. Use this to test whether business logic, state transitions, or data shapes work when pushed through actual scenarios instead of just on paper.

Hand it to a non-developer (domain expert, product, design) so they can feel the model themselves. It speaks their language: the terms in `CONTEXT.md` for the domain, not the code's names.

## How to build it

### 1. Name what you're testing

Before any code, write one paragraph at the top of the page: which state model this is and the exact question it answers. A prototype answering the wrong question is wasted work, so state it plainly enough to check later, whether the user is watching now or returns away from the keyboard.

### 2. Separate the logic from the page

Write your logic (the reducer, state machine, pure functions, or class) in a single `<script>` block. Keep it portable and pure — no DOM touching, no `document`, no wired-up handlers. The page calls your logic; your logic doesn't reach back into the page. The page is throwaway; the logic is the design you're testing.

Pick the shape that matches the question you are testing, never the one that is simplest to hook up to a page:

- Pure reducer (`(state, action) => state`) — good for discrete events and single values.
- State machine with explicit legal transitions — good when "what's allowed right now?" matters.
- Plain functions over data — good when you're just transforming, not holding state.
- Class or module with methods — good when internal state genuinely belongs together.

### 3. Write the shareable page

One HTML file, everything inline. Plain CSS and JS: no framework, no bundler, no server. It opens by double-click and survives being emailed.

Every label uses `CONTEXT.md` terms, not code terms: buttons and state read like the business, not the reducer. Explain in plain words what is happening, for someone who has never seen a state machine.

Organize top to bottom:

1. **Title and one line** of what to explore (your question from step 1).
2. **Current state** — a readable panel showing every relevant field, not a JSON dump. Highlight what just changed when someone clicks.
3. **Free-play buttons** — one per action, always clickable. Anyone can click them in any order. Each click updates and re-renders.
4. **Scenario tabs** — a few scenarios that expose the tricky parts: the happy case, an edge that breaks reasoning, something that should fail. Each tab describes the scenario in plain language (the situation and what to watch for), then shows its steps in order as real buttons: pressing one performs that action and advances to the next step. Starting a scenario resets to a known initial state so it plays the same way every time.

Keep visuals clean and restrained: clean typography, generous whitespace, one accent color. No animations fighting for attention — the point is the state and the buttons.
