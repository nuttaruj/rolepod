---
name: write-spec
description: Use when turning a fuzzy goal, half-stated feature, or vague request into a sharp implementation spec. Discovery dialogue first, then design, then user approval, then a compact contract. Phase = Define.
---

# Write Spec

Turns a vague request into an approved spec the next phase executes against: discovery in frontier rounds → 2-3 approaches → Gate 1 → the contract.

## Skip when

- The user is musing ("what if we…", "would X be worth it?" in any language) → discuss it; offer the spec once when the idea firms up. A spec fires on a commission only.
- A one-line fix with an obvious diff.
- The user supplied a written spec, or approved an exact change list with each target named — that list is the spec.
- The user said "skip spec" / "just write the code".

### 1. Frame the goal

Quote the exact request. Read the repo state it touches (existing patterns, prior decisions) and the constraints already stated (deadline, stack, no-touch zones).
Repeat feature → the latest `docs/rolepod/specs/<feature>-*.md` Desired behavior is a hypothesis for today's Current behavior; verify it against the code.

Write the goal in one sentence, 2-3 likely constraints, and every high-risk surface: auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security.
The goal needs an "and" → possibly several specs: `references/scope-splitting.md`.
Open decisions block even listing the slices → chart the decisions first, then spec each slice: `references/chart-work.md`.

Name the **Product mode** from the repo: `change` (a product exists; this adds or alters part of it) or `new` (nothing to change yet). Ask only when the repo cannot tell (a new app beside an existing one). It scopes every later step, a prototype included.

Done when: the goal, constraints, risk surfaces and Product mode are written down.

### 2. Discovery

Model the open decisions as a tree; each answer unblocks the questions hanging off it.
Ask in **frontier rounds**: number every question whose prerequisites are settled and present them together. A question that depends on an open answer waits for the next round. A long frontier is grouped by topic and asked in full, never trimmed.
Ask only what changes the implementation if the answer changes; which questions do → `references/question-bank.md`.
**Recommend a default per question** — the simplest viable answer; the user confirms or overrides.
Use the CLI's native question UI when it has one; otherwise numbered questions with lettered options, the default marked, compact answers accepted (`1a 3c`, or `defaults`).

Facts are researched, never asked: what the codebase or docs can answer, explore.
While a round is out, dispatch a scout on the researchable unknowns; a running scout is an open prerequisite, so only its downstream questions wait. No subagents → the Lead researches between rounds.
A user answer naming a file, symbol, library or pattern is a claim: check it (the round's scout, else grep) before recording it. A mismatch opens the next round with the code quoted.
Scope, user stories, priorities and cost / ROI come from the user — the user is the product owner.

A domain term with more than one live reading → resolve it in the round against the repo's `CONTEXT.md` when one exists, quote the code back when it disagrees with the user, and propose ONE canonical word.
Settled and used beyond this feature → write it into `CONTEXT.md` at the repo root at that moment (create the file then, never at the end); entry shape: `references/question-bank.md` Domain term. A feature-only term gets one line in the spec.

A layout or state-logic question talking cannot settle → offer `write-prototype` in one line (yes / skip) and park that question. Yes → it builds once the rest of the frontier is settled and before Gate 1; its verdict settles the parked question.

A round's answers did not close the ambiguity → name the one unresolved thing and offer two concrete framings. Still unresolved → stop and record what is needed to resume. Never re-ask the same question in a new shape.

Done when: the frontier is empty and no scout is still out.

### 3. Approaches

Present 2-3 approaches, one per **lens** so they differ for real: **minimal** (smallest diff, maximum reuse) · **clean** (the boundary a maintainer would want, more files) · **pragmatic** (the seam between).
Give each its trade-offs (complexity, blast radius, reversibility, cost) and recommend one; simplest viable wins by default.
The clean lens earns its place by naming what minimal costs later, so `## Rejected approaches` records a real trade-off, not `None`.

The approach adds or changes a DB table / migration, a public API contract, or a module boundary → ONE `system-architect` dispatch (API / data-model / integration design) drafts the three lenses inline (no file), briefed with the request, the answers so far and the approval gate the user expects; the Lead judges. Otherwise, or with no subagents, the Lead drafts them.
Write an ADR only when all three hold: hard to reverse · surprising without context · a real trade-off between genuine alternatives. Then `docs/adr/NNNN-<slug>.md` (context, decision, consequences — one page; `content-strategist` with `audience: dev` may write it and any other durable spec artifact). Any one missing → the spec is the record.

The user declines every approach → stop and report what is blocking.

Done when: the user has 2-3 lensed approaches with one recommended.

### 4. Self-review

Fix in the draft:
- placeholders (`[[FILL: …]]`, `TODO`, `tbd`), contradictions between sections, ambiguous wording ("maybe", "should", "if needed");
- a Success criterion with no "proven by", proven only at a seam the implementation alone can reach, or naming a command that does not exist yet without saying so — pair each with a real or explicitly-new command / observation a caller can reach;
- a technical claim behind the chosen approach with no verifiable pointer (file:line, commit, or URL + date);
- a high-risk surface with no security / migration / audit plan — add it, or delegate to `security-engineer` / `system-architect`;
- untested assumptions about the user's intent, scope creep, over-engineering for hypothetical needs.

Done when: no item above remains.

### 5. Cross-family critique

Only when the cross-family pool is enabled (opt-in; off → skip silently) and the spec is R4 (high-risk) or the user asks; R3 stays internal.
Run `rolepod-cross-family --kind critique --brief spec-draft.md` on the draft plus the Q&A ledger. Settle from the repo what you can, ask the rest in ONE extra Discovery round, and record one line under **Open questions**. It never blocks a spec.
Brief, triage and degradation → `references/question-bank.md` Cross-family critique.

Done when: the critique line is recorded, or the step was skipped.

### 6. Gate 1 — direction approval

Present the chosen approach and its rationale. Wait for accept / edit / reject.

Done when: the user accepted a direction. No contract before it.

### 7. Contract

Legacy code (no prior spec) → Current behavior lists every consumer of the behavior that moves (grep the call sites; code-intel callers when connected); each becomes a plan task or a Non-goal.
Fill `templates/spec-template.md`, every section resolved: Goal · User / actor · Non-goals · Current behavior · Desired behavior · Success criteria · Constraints · High-risk surfaces · Chosen approach · Rejected approaches · Open questions.
Repeat feature → a section that did not move reads `Unchanged — <prior spec> §<name>`; the template header lists which sections may inherit.

Run the **spec-lint** on the filled text (piped in inline mode, the saved file in file mode): `grep -niE '\[\[FILL:|TODO|TBD'` must print nothing. A printed line or a grep error is a lint failure, never a silent pass. It catches an unfilled marker or a stray TODO/TBD — never legitimate angle brackets like `<h1>` / `List<T>`, and not vague wording.

- One-session work → inline in chat; Gate 1 is the only approval. The default when unsure.
- Multi-session, high-risk surface, or repeat feature → file mode: save under `docs/rolepod/specs/` (private by default), then Gate 2 — the user reads and confirms the FILE, not the chat. Save rule, anchor check and Gate 2 → `references/file-mode.md`.

Spec shapes, good and bad → `examples/spec-examples.md`.

Done when: the spec-lint prints nothing, and the spec is inline, or saved with the file confirmed at Gate 2.

## Guardrails

- An ambiguous goal, scope or success criterion, or a high-risk surface, gets a spec. Never skip it there.
- Implementation starts after the user approves the direction at Gate 1. Never before.
- A spec saved as a file gets a second approval on the written file (Gate 2). Never hand it off on verbal agreement alone.

## Next phase

- `write-plan` with the approved spec (a complete user-supplied spec goes there directly).
- If `write-plan` is not available, hand off an implementation outline: files to touch, ordered tasks, test plan, risks, done criteria.
