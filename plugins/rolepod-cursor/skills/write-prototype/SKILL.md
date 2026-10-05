---
name: write-prototype
description: Use when write-spec offers a prototype and the user accepts; user asks for a prototype, demo, or layout options; user needs throwaway code to explore a design question
---

# Write Prototype — throwaway code that answers one question

Turns ONE question from a spec into throwaway code the user can react to, then writes the verdict back into the spec. A demo and a decision, never production code.

## Skip when

- No spec yet → `write-spec` first. An unsettled spec builds the wrong demo.

### 1. Check the spec

A spec here is a draft whose other questions are settled, an approved spec, or a chart-work `probe` ticket.
Read its Product mode, the ONE question, and in change mode the paths the spec touches. Any missing → `write-spec`; a `probe` ticket missing one → fill that line in the ticket from the repo (ask only what the repo cannot tell) — it stays a ticket, never a new spec.
The question does not fit one sitting → it is too broad: back to `write-spec` to split it (a `probe` ticket: split it on the map, chart-work's Ripple step).
Labels use the spec's words and the `CONTEXT.md` terms.

Done when: the Product mode and exactly one question are named.

### 2. Pick the branch

"What should this look like?" → **Layout**. "Does this logic / state model feel right?" → **Logic**.
Ambiguous with the user away → match the surrounding code (page / component → Layout, module → Logic) and state the assumption at the top of the demo.

Scope follows the Product mode: `change` → only the surface the spec changes, the rest stays the real app; `new` → only the screen or flow the question names. Never the whole product.

**Layout** — required elements:
- 3 variants by default (2 for a two-way question; 1 when the user already named the layout to test — no switcher then), 5 at most, differing in structure (layout, information hierarchy, primary affordance), never only colour or copy;
- 2+ variants → switched by `?variant=` and a floating bottom bar (previous / next, current label, arrow keys), reload-stable, hidden in production builds;
- change mode → mounted on the existing route with its real data; new mode or no runnable app → one self-contained HTML file, with the same switcher when there are 2+ variants.

**Logic** — required elements:
- one self-contained HTML file (inline CSS/JS, no build, no server) that opens by double-click;
- the logic as a pure module (reducer, state machine or pure functions) that never touches the DOM;
- a readable state panel re-rendered after every action (labelled fields, what just changed);
- free-play buttons, one per action;
- scenario tabs — the happy path, a tricky edge, something that should be illegal — each resetting to a known state;
- every label in domain words, written for a non-developer.

Depth → `references/ui.md` (Layout) or `references/logic.md` (Logic); load only the chosen one.

Done when: the branch is picked and its required elements are listed for the build.

### 3. Build in a spike worktree

A new worktree starts from HEAD and never carries uncommitted changes. Change mode → first `git status --porcelain -- <the spec's paths>`: dirty → ask the user to commit them or build on HEAD; user away → HEAD. Built on HEAD over dirty paths → the top of the demo names the base SHA and says it excludes the uncommitted changes to those paths.
Run `git worktree add <dir> -b spike/<name>`; everything happens there, and the user's working tree is never touched.
Write the ONE question at the top of the demo.
Name the files so a reader sees "prototype". One command runs it (the project's task runner), or a double-click.
Keep it throwaway: no tests, no persistence (state in memory; a question about persistence gets a scratch store named PROTOTYPE), no abstractions, no error handling beyond what runs.

Done when: the prototype runs with one command or a double-click.

### 4. Hand over

Change mode with a runnable app: run the prototype on its own port and give BOTH links — the original route (the running app, or a server from the main tree) and the prototype route with each `?variant=` key (one variant: the prototype route alone) — same route, side by side.
Logic, new mode, or change mode with no runnable app: give the file path, opened; for the last, say the variants were not seen against the real app.
`rolepod-uiproof` installed → a screenshot per variant is optional.
Ask for the verdict; "the header from B with the sidebar from C" is a verdict. Iterate on request.

Done when: the user gave a verdict.

### 5. Capture

Write into the spec (a `probe` ticket: its `## Resolution`, the line ending `rebuilt from the spec that cites this ticket`): the question, the verdict, and the line `Prototype: spike/<name> — reference only, never merged, rebuilt from this spec`.
Commit the prototype on its spike branch (pushed only when the user asks), then remove the worktree; the branch keeps the evidence.

Done when: the verdict is in the spec (or the probe ticket) and the worktree is removed.

## Guardrails

- A prototype the user wants for real becomes a change: its decision goes into the spec → `write-plan` → `implement-plan` rebuilds it with tests. Never merge, cherry-pick or copy prototype code into a non-spike branch.

## Next phase

- From a `probe` ticket → back to the map: `write-spec`'s `references/chart-work.md`, Working the map step 3 (Record) — the ticket flips resolved and its gist goes under Decided.
- From a spec → `write-spec` for Gate 1 with the verdict. The spec was already approved and the verdict changed a decision → `write-spec` re-opens Gate 1 on the file.
- If `write-spec` is not available, hand the user the question, the verdict and the spike branch name as the design decision to build from.
