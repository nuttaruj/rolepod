---
name: write-spec
description: Use when a non-trivial request has an unclear goal, scope, success criterion or risk surface; when a fuzzy goal or half-stated feature must become a spec before planning; when the user asks for a spec.
---

# Write Spec

Turns an unclear, non-trivial request into an approved spec file — the contract `write-plan` builds from. Clear requests and user-approved change lists take the shortest path.

## Skip when

- Musing ("what if we…", "would X be worth it?", any language) → discuss; offer the spec once the idea firms up. A spec fires on a commission only.
- A one-line fix with an obvious diff.
- The user supplied a written spec, or approved an exact change list with each target named — that list is the spec.
- The user said "skip spec" / "just write the code".

### 1. Route and frame

- User-supplied spec or exact approved change list naming each target → use it as the spec; do not interview again.
- Otherwise, quote the request and inspect relevant code and decisions, constraints, and the project's follow-up list (`docs/rolepod/backlog.md` or its issue tracker). Remove an adopted backlog item when the spec is approved.
- Record one-sentence goal, actor, product mode (`change` or `new`), constraints, and touched high-risk surfaces: auth, billing, payments, credits, migration, data deletion, secrets, tokens, crypto, permissions, security.
- A repeat feature may inherit Goal, User / actor, Non-goals, Constraints, Chosen approach, or Rejected approaches as `Unchanged — <prior spec> §<section>`; verify current behavior from code and write behavior, criteria, testing, risk, and open questions fresh.
- Goal spans independent outcomes → `references/scope-splitting.md` (split signals, slicing); no file → one spec per shippable outcome: write slice 1, list the rest as Non-goals, confirm the order with the user.
- Open decisions block listing the slices → `references/chart-work.md` (decision map, question tickets); no file → settle the blocking decisions one at a time in Discovery until the slices can be listed. A mapped, decided question is cited as `Decided — q-<slug>`, never asked again.

Done when: goal, actor, product mode, constraints, risk surfaces, and any needed work split are recorded.

### 2. Discovery

Ask only decisions that change scope, behavior, success, risk, or implementation. If goal, user, or scope is genuinely unclear, resolve it first; otherwise ask all currently unblocked questions in **frontier rounds**, grouped by topic. Do not repeat questions answered by a supplied spec or decided map. Question patterns → `references/question-bank.md`; no file → ask in this order: outcome, actor, permission / risk, data source, error states, rollout.
**Recommend a default per question** — the simplest viable answer; the user confirms or overrides.
Native question UI when the CLI has one; else numbered questions with lettered options, the default marked, compact answers accepted (`1a 3c`, or `defaults`).
A partial reply (`1a 3c`) closes only those questions; the rest stay open next round, never defaulted. `defaults` takes only the recommendations shown that round; silence is not an answer.
"Don't know" → a fact becomes research; a decision stays open, or the user takes the default and Gate 1 lists it as an assumption. No option fits → the user's own words are the answer. The user asks for one question at a time → the same frontier, one question per message.

Facts are researched, never asked: what the codebase or docs can answer, explore.
While a round is out, scouts research the unknowns — one per independent unknown, all in ONE message; only questions downstream of a running scout wait. No subagents → the Lead researches between rounds.
A user answer naming a file, symbol, library or pattern is a claim: check it (the scout, else grep) before recording; a mismatch opens the next round with the code quoted.
Scope, user stories, priorities and cost / ROI come from the user — the product owner.
A domain term with more than one live reading → resolve it in the round (`CONTEXT.md` handling → `references/question-bank.md` Domain term; no file → read `CONTEXT.md` when present, propose one canonical word with a boundary example, ask only what the user must decide).
A layout or state-logic question talking cannot settle → offer `write-prototype` and park it (`references/question-bank.md` Prototype offer); no `write-prototype` → describe the candidate layouts or state flows in words and ask which holds.

A round's answers did not close the ambiguity → name the one unresolved thing and offer two concrete framings. Still unresolved → stop and record what is needed to resume. Never re-ask the same question in a new shape.

Done when: the frontier is empty and no scout is still out.

### 3. Approaches

Present 2-3 approaches, one per **lens** so they differ for real: **minimal** (smallest diff, maximum reuse) · **clean** (the boundary a maintainer would want, more files) · **pragmatic** (the seam between).
Each with trade-offs (complexity, blast radius, reversibility, cost); recommend one — simplest viable wins by default.
The clean lens names what minimal costs later, so Rejected approaches records a real trade-off. If minimal is already the clean boundary, present one design and state what the clean lens checked; never invent an alternative.
The approach adds or changes a DB table / migration, a public API contract, or a module boundary → ONE `system-architect` dispatch drafts the lenses (brief and dispatch → `references/approaches.md`; no file → brief it with the request, the answers so far and the three lens names, one design per lens with its trade-offs). Otherwise, or no subagents, the Lead drafts them.
ADR only when all three hold: hard to reverse · surprising without context · a real trade-off between genuine alternatives (shape → `references/approaches.md`; no file → `docs/adr/NNNN-<slug>.md`, one page: context, decision, consequences). Any one missing → the spec is the record.
The user declines every approach → stop; report the block.

Done when: the user has 2-3 lensed approaches with one recommended, or one design with its converged-lens line.

### 4. Self-review

Fix in the draft:
- placeholders (`[[FILL: …]]`, `TODO`, `tbd`), contradictions between sections, ambiguous wording ("maybe", "should", "if needed");
- a Success criterion without "proven by", provable only at a seam the implementation alone reaches, or naming a not-yet-existing command unflagged — pair each with a real or explicitly-new command / observation a caller can reach;
- Testing decisions missing, a seam lower or newer than an existing one that reaches the behavior, or an edge / error / race case with neither a Success criterion nor an R4 (high-risk) floor behind it — deny path, money math, migration rollback, shared-state race (home: `tdd-flow`; this item is the whole check without it);
- a technical claim behind the approach with no verifiable pointer (file:line, commit, or URL + date);
- a high-risk surface with no security / migration / audit plan — add it, or delegate to `security-engineer` / `system-architect`; no subagents → the Lead writes it;
- untested assumptions about the user's intent, scope creep, over-engineering for hypothetical needs.

Done when: no item above remains.

### 5. Cross-family critique

Runs only when all hold: Full mode, the cross-family pool on (opt-in), the session not wide-effort, and an R4 spec — or the user asks for a second opinion; R3 stays internal. It runs after Self-review, once Discovery has converged with no open question of your own. The same trigger gates `write-plan`'s independent plan review.
- Run → `cross-family` kind critique (a cold reader in another CLI sees gaps your own model misses) with the draft + the Q&A ledger (every question asked so far, numbered, with the user's answer — a gap in it brings back questions already answered); no `cross-family`, or any condition false → skip and record why.
- The status line reads `Cross-family critique: <cli> — N items, K settled from repo, M asked`, `— NO FURTHER QUESTIONS`, or `Cross-family critique: not run — off` (or `— wide-effort session`, `— cross-family absent`, `— not R4`, `— <runner reason>`).
- Triage before the user sees anything: an item the repo or the spec settles → answer it yourself (Read / grep, never guess) and fold it into the draft; the user's decisions → ONE extra Discovery round, numbered, a default per question; new questions its answers reveal continue in normal Discovery. Never forward the critic's list raw.
- A fork the critique surfaces (an approach decision, not a question) goes to Gate 1 as an option pair with a recommendation; the user decides.
- Once per spec: a draft revised after it (the extra round's answers, a Gate 1 edit or reject) never re-runs it. The status line goes under **High-risk surfaces**, never Open questions (which block `write-plan`). Never blocks a spec.

Done when: the critique status line is recorded.

### 6. Gate 1 — file review and approval

The spec lives under the private `docs/rolepod/` directory. Before the first save run:
```bash
grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore
```
A repo that deliberately tracks its working docs skips the command and creates `.rolepod/docs-tracked`.

After the approaches round, write the whole spec to `docs/rolepod/specs/<feature>-YYYY-MM-DD.md` (optional `-vN` / `-draft`), run Self-review and the spec-lint on the file, then point the user to it and list the `assumption` items in chat. Accept → `write-plan`; edit → patch the same file and ask again; reject → stop. One gate, on the file — no inline mode, no Gate 2.
The user reads the file, not the chat: the file shows word drift ("soft delete" in chat, "delete" in the file), an omitted edge case, and second thoughts on the concrete shape.

Run the **spec-lint**: `grep -niE '\[\[FILL:|TODO|TBD' <spec>` must print nothing, and so must the anchor check `for h in 'Non-goals' 'Current behavior' 'Desired behavior' 'Success criteria'; do grep -q "^## $h" <spec> || echo "missing ## $h"; done` (the next repeat-feature spec seeds from these four headings). A printed line or a grep error is a lint failure, never a silent pass.

Fill `templates/spec-template.md`; no template → these `## ` headings in order: Goal, User / actor, Non-goals, Current behavior (`Nothing — new surface` for a new product), Desired behavior, Success criteria, Testing decisions, Constraints, High-risk surfaces, Chosen approach, Rejected approaches, Open questions.
Keep the decision contract complete: goal/scope, desired behavior, checkable acceptance, testing decisions, constraints/risk, chosen contract, and open decisions. For an existing change, record current behavior and affected consumers. Keep obvious actors, absent alternatives, and unchanged history concise. Include conditional template detail only when its condition applies; do not create a second compact schema.
Prose in the user's language; template headings, labels, identifiers, paths and commands verbatim.

**Testing decisions** — pick the highest existing seam that reaches behavior and the fewest seams; state why a new seam is needed. Name the assertion and prior-art tests. Edge / error / race cases need a criterion or an R4 floor.

**Chosen approach** — the direction and its one-line rationale; when step 3's architect trigger fired, also the accepted interface, data shape, compatibility rule and invariants `write-plan` must keep.

A new decision (criterion, Non-goal, or interface choice) requires the user's answer before hand-off; never write it as approved while unresolved.

Spec shapes, good and bad → `examples/spec-examples.md`; no file → the template and this step are enough.

Done when: the spec-lint prints nothing, the spec is saved to the file, and the user confirms it.

## Guardrails

- An ambiguous goal, scope or success criterion, or a high-risk surface, gets a spec. Never skip it there.
- Implementation starts after the user approves the direction at Gate 1. Never before.
- The spec is always saved to a file and confirmed by the user on the file itself. Never hand it off on verbal agreement alone.

## Next phase

- `write-plan` with the approved spec (a complete user-supplied spec goes there directly).
- If `write-plan` is not available, hand off an implementation outline: files to touch, ordered tasks, test plan, risks, done criteria.
