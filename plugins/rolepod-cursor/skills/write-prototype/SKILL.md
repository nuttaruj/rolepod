---
name: write-prototype
description: Build a throwaway prototype that answers ONE design question from a spec — layout variants to compare, or a clickable logic demo a non-developer can drive. Use when write-spec offers a prototype and the user accepts, or the user asks for a prototype, demo or layout options of a spec'd change.
---

# Write Prototype — throwaway code that answers one question

A prototype is throwaway code that answers ONE question from the spec; the question decides the shape. A demo and a decision, never production code.

## Boundary

Owns: the spec check, the branch pick, the throwaway build in a spike worktree, the hand-over with links, the answer written back into the spec.

Does not own: the spec (`write-spec`), the real build (`write-plan` → `implement-plan`), tests.

Hand off: no spec → `write-spec`; answer captured → back to `write-spec` for Gate 1 (spec already approved and the verdict changed a decision → write-spec re-opens Gate 1, Gate 2 in file mode).

## Iron rules

<EXTREMELY-IMPORTANT>
1. NEVER build without a spec — a draft whose other questions are settled, an approved spec, or a chart-work `probe` ticket — that names the Product mode and the ONE question. Missing → `write-spec` first; an unsettled spec builds the wrong demo.
2. ONE question per prototype, written at the top of the demo. It does not fit one sitting → the question is too broad: back to write-spec to split it.
3. Scope follows the Product mode: `change` → only the surface the spec changes, the rest stays the real app; `new` → only the screen or flow the question names. Never the whole product.
4. NEVER merge, cherry-pick or copy prototype code into a non-spike branch. A prototype the user wants for real becomes a change: its decision goes into the spec → `write-plan` → `implement-plan` rebuilds it with tests.
5. Throwaway rules: no tests, no persistence (state in memory; a question about persistence gets a scratch store named PROTOTYPE), no abstractions, no error handling beyond what runs.
</EXTREMELY-IMPORTANT>

## Step 1 — check the spec

Read the Product mode, the question, and in change mode the paths the spec touches; any missing → `write-spec`. Labels use the spec's words and `CONTEXT.md` terms.

## Step 2 — pick the branch

"What should this look like?" → Layout; "Does this logic / state model feel right?" → Logic; ambiguous with the user away → match the surrounding code (page / component → Layout, module → Logic) and state the assumption at the top.

Required elements, one line each:

**Layout**: 3 variants by default, 5 at most; they differ in structure (layout, information hierarchy, primary affordance), never only colour or copy; switched by `?variant=` and a floating bottom bar (previous / next, current label, arrow keys), reload-stable, hidden in production builds; change mode → mounted on the existing route with its real data; new mode or no runnable app → one self-contained HTML file with the same switcher.

**Logic**: one self-contained HTML file (inline CSS/JS, no build, no server) that opens by double-click; the logic as a pure module (reducer, state machine or pure functions) that never touches the DOM; a readable state panel re-rendered after every action (labelled fields, what just changed); free-play buttons, one per action; scenario tabs — the happy path, a tricky edge, something that should be illegal — each resetting to a known state; every label in domain words, written for a non-developer.

Depth: `references/ui.md` / `references/logic.md` — load only the chosen one.

## Step 3 — build in a spike worktree

`git worktree add <dir> -b spike/<name>`; everything happens there, the user's working tree is never touched; name the files so a reader sees "prototype"; one command to run it (the project's task runner) or a double-click.

## Step 4 — hand over

Change mode: run the prototype on its own port and give BOTH links — the original route (the running app, or a server from the main tree) and the prototype route with each `?variant=` key — same route, side by side.

Logic / new mode: the file path, opened.

`rolepod-uiproof` installed → a screenshot per variant is optional. Ask for the verdict; "the header from B with the sidebar from C" is a verdict. Iterate on request.

## Step 5 — capture

Write into the spec: the question, the verdict, and the line `Prototype: spike/<name> — reference only, never merged, rebuilt from this spec`. Commit the prototype on its spike branch (pushed only when the user asks), remove the worktree (the branch keeps the evidence), then return to `write-spec`.

## References

Load only when needed:
- `references/ui.md` — sub-shapes, the switcher's behaviour, variant rules, anti-patterns.
- `references/logic.md` — module shapes, the non-developer page, scenario choice, anti-patterns.
