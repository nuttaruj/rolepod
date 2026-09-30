---
name: write-spec
description: Use when turning a fuzzy goal, half-stated feature, or vague request into a sharp implementation spec. Discovery dialogue first, then design, then user approval, then a compact contract. Phase = Define.
---

# Write Spec

Turns a vague request into an approved spec the next phase executes against: discovery in frontier rounds → 2-3 approaches → Gate 1 → the contract.

## Skip when

- Musing ("what if we…", "would X be worth it?", any language) → discuss; offer the spec once the idea firms up. A spec fires on a commission only.
- A one-line fix with an obvious diff.
- The user supplied a written spec, or approved an exact change list with each target named — that list is the spec.
- The user said "skip spec" / "just write the code".

### 1. Frame the goal

Quote the request. Read the repo state it touches (patterns, prior decisions) and the stated constraints (deadline, stack, no-touch zones).
Repeat feature (a prior `docs/rolepod/specs/<feature>-*.md`) → its Desired behavior is a hypothesis for today's Current behavior, verified against the code. An unmoved Goal, User / actor, Non-goals, Constraints, Chosen approach or Rejected approaches reads `Unchanged — <prior spec> §<name>`; the other sections are always written fresh.
Write the goal in one sentence, 2-3 likely constraints, and every high-risk surface: auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security.
The goal needs an "and" → possibly several specs: `references/scope-splitting.md`.
Open decisions block listing the slices → chart them, then spec each slice: `references/chart-work.md`.
A slice handed off from a chart-work map → read the map and each Decided ticket it links first; a decided question is cited (`Decided — q-<slug>`), never asked again in Discovery.
Name the **Product mode** from the repo — `change` (adds to or alters an existing product) or `new` (nothing to change yet); ask only when the repo cannot tell (a new app beside an existing one). It scopes every later step, a prototype included.

Done when: the goal, constraints, risk surfaces and Product mode are written down.

### 2. Discovery

Model open decisions as a tree; each answer unblocks the questions under it.
Pace by how clear the goal is. Goal, user or scope still vague (step 1's one-sentence goal was a guess) → one question per message, each shaped by the last answer, until those three are settled; then the rest of the tree goes out in frontier rounds. Goal already clear → frontier rounds from the start.
Ask in **frontier rounds**: number every question whose prerequisites are settled and present them together; a question depending on an open answer waits. A long frontier is grouped by topic and asked in full, never trimmed.
Ask only what changes the implementation; which questions do → `references/question-bank.md`.
**Recommend a default per question** — the simplest viable answer; the user confirms or overrides.
Native question UI when the CLI has one; else numbered questions with lettered options, the default marked, compact answers accepted (`1a 3c`, or `defaults`).
A partial reply (`1a 3c`) closes only those questions; the rest stay open next round, never defaulted. `defaults` takes only the recommendations shown that round; silence is not an answer.
"Don't know" → a fact becomes research; a decision stays open, or the user takes the default and Gate 1 lists it as an assumption. No option fits → the user's own words are the answer. The user asks for one question at a time → the same frontier, one question per message.

Facts are researched, never asked: what the codebase or docs can answer, explore.
While a round is out, scouts research the unknowns — one per independent unknown, all in ONE message; only questions downstream of a running scout wait. No subagents → the Lead researches between rounds.
A user answer naming a file, symbol, library or pattern is a claim: check it (the scout, else grep) before recording; a mismatch opens the next round with the code quoted.
Scope, user stories, priorities and cost / ROI come from the user — the product owner.
A domain term with more than one live reading → resolve it in the round (`CONTEXT.md` handling: `references/question-bank.md` Domain term).
A layout or state-logic question talking cannot settle → offer `write-prototype` and park it (`references/question-bank.md` Prototype offer).

A round's answers did not close the ambiguity → name the one unresolved thing and offer two concrete framings. Still unresolved → stop and record what is needed to resume. Never re-ask the same question in a new shape.

Done when: the frontier is empty and no scout is still out.

### 3. Approaches

Present 2-3 approaches, one per **lens** so they differ for real: **minimal** (smallest diff, maximum reuse) · **clean** (the boundary a maintainer would want, more files) · **pragmatic** (the seam between).
Each with trade-offs (complexity, blast radius, reversibility, cost); recommend one — simplest viable wins by default.
The clean lens names what minimal costs later, so Rejected approaches records a real trade-off, not `None`. The minimal diff already is the clean boundary → present that one design and record in one line what the clean lens checked; never invent an alternative.
The approach adds or changes a DB table / migration, a public API contract, or a module boundary → ONE `system-architect` dispatch drafts the lenses (`references/approaches.md`). Otherwise, or no subagents, the Lead drafts them.
ADR only when all three hold: hard to reverse · surprising without context · a real trade-off between genuine alternatives (shape: `references/approaches.md`). Any one missing → the spec is the record.
The user declines every approach → stop; report the block.

Done when: the user has 2-3 lensed approaches with one recommended, or one design with its converged-lens line.

### 4. Self-review

Fix in the draft:
- placeholders (`[[FILL: …]]`, `TODO`, `tbd`), contradictions between sections, ambiguous wording ("maybe", "should", "if needed");
- a Success criterion without "proven by", provable only at a seam the implementation alone reaches, or naming a not-yet-existing command unflagged — pair each with a real or explicitly-new command / observation a caller can reach;
- Testing decisions missing, a seam lower or newer than an existing one that reaches the behavior, or an edge / error / race case with neither a Success criterion nor an R4 (high-risk) floor behind it — deny path, money math, migration rollback, shared-state race (`tdd-flow`);
- a technical claim behind the approach with no verifiable pointer (file:line, commit, or URL + date);
- a high-risk surface with no security / migration / audit plan — add it, or delegate to `security-engineer` / `system-architect`;
- untested assumptions about the user's intent, scope creep, over-engineering for hypothetical needs.

Done when: no item above remains.

### 5. Cross-family critique

Only when the cross-family pool is enabled (opt-in; off → skip silently), the session is not wide-effort, and the spec is R4 (high-risk) or the user asks; R3 stays internal.
Pool on → `cross-family` kind critique with the draft + Q&A ledger; skipped → record why: `Cross-family critique: not run — off` (or `— wide-effort session`, `— cross-family absent`, `— not R4`).
Settle what the repo can, ask the rest in ONE extra Discovery round. Once per spec: a draft revised after it (a Gate 1 edit or reject included) never re-runs it. The status line goes under **High-risk surfaces**, never Open questions. Never blocks a spec. Protocol → `references/question-bank.md` Cross-family critique.

Done when: the critique status line is recorded.

### 6. Gate 1 — file review and approval

After the approaches round, write the whole spec to `docs/rolepod/specs/<feature>-YYYY-MM-DD.md`, run Self-review and the spec-lint on the file, then point the user to it and list the `assumption` items in chat. Accept → `write-plan`; edit → patch the same file and ask again; reject → stop. One gate, on the file — no inline mode, no Gate 2.

Run the **spec-lint**: `grep -niE '\[\[FILL:|TODO|TBD' <spec>` must print nothing. A printed line or a grep error is a lint failure, never a silent pass.

Fill `templates/spec-template.md`, every section resolved (legacy code: Current behavior lists every consumer, per its hint): Goal · User / actor · Non-goals · Current behavior · Desired behavior · Success criteria · Testing decisions · Constraints · High-risk surfaces · Chosen approach · Rejected approaches · Open questions.

**Testing decisions** — the Lead picks the seams: the highest seam that reaches the behavior, the fewest (ideally one per feature), an existing seam over a new one; plus what a good test is here and the prior-art test files. They are approved with the spec at its gate — no extra question. Edge / error / race cases only where a Success criterion names them or an R4 floor covers them.

**Chosen approach** — the direction and its one-line rationale; when the architect trigger fired (DB table / migration, public API contract, module boundary), also the accepted interface, data shape, compatibility rule and invariants `write-plan` must keep.

A new decision it would add (a criterion, a Non-goal, an interface choice) → one question to the user before the hand-off, never written in unconfirmed.

Save to `docs/rolepod/specs/<feature>-YYYY-MM-DD.md` under the private `docs/rolepod/` directory. Before the first save run:
```bash
grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore
```

Spec shapes, good and bad → `examples/spec-examples.md`.

Done when: the spec-lint prints nothing, the spec is saved to the file, and the user confirms it.

### 7. Language

Write the spec's (the plan's) prose in the user's language unless they ask for another; section headings, the field labels plan-lint reads, identifiers, paths, commands and quoted code stay verbatim.

## Guardrails

- An ambiguous goal, scope or success criterion, or a high-risk surface, gets a spec. Never skip it there.
- Implementation starts after the user approves the direction at Gate 1. Never before.
- The spec is always saved to a file and confirmed by the user on the file itself. Never hand it off on verbal agreement alone.

## Next phase

- `write-plan` with the approved spec (a complete user-supplied spec goes there directly).
- If `write-plan` is not available, hand off an implementation outline: files to touch, ordered tasks, test plan, risks, done criteria.
