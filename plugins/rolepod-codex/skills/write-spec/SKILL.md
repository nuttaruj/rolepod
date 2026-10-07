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
- Record one-sentence goal, actor, product mode (`change` or `new`), constraints, and the touched surfaces on the high-risk list (`using-rolepod` Stop conditions).
- A repeat feature may inherit Goal, User / actor, Non-goals, Constraints, Chosen approach, or Rejected approaches as `Unchanged — <prior spec> §<section>`; verify current behavior from code and write behavior, criteria, testing, risk, and open questions fresh.
- Goal spans independent outcomes → `references/scope-splitting.md` (split signals, slicing); no file → one spec per shippable outcome, every slice written now, approved as one set; one that waits on what an earlier slice's build finds stays a Non-goal; confirm the build order in Discovery.
- Open decisions block listing the slices → `references/chart-work.md` (decision map, question tickets); no file → settle the blocking decisions one at a time in Discovery until the slices can be listed. A mapped, decided question is cited as `Decided — q-<slug>`, never asked again.

Done when: goal, actor, product mode, constraints, risk surfaces, and any needed work split are recorded.

### 2. Discovery

Ask only decisions that change scope, behavior, success, risk, or implementation. If goal, user, or scope is genuinely unclear, resolve it first; otherwise ask all currently unblocked questions in **frontier rounds**, grouped by topic. Do not repeat questions answered by a supplied spec or decided map. Question patterns → `references/question-bank.md`; no file → ask in this order: outcome, actor, permission / risk, data source, error states, rollout.
**Recommend a default per question** — the simplest viable answer; the user confirms or overrides.
Native question UI when the CLI has one; else numbered questions with lettered options, the default marked, compact answers accepted (`1a 3c`, or `defaults`).
A partial reply (`1a 3c`) closes only those questions; the rest stay open next round, never defaulted. `defaults` takes only the recommendations shown that round; silence is not an answer.
"Don't know" → a fact becomes research; a decision stays open, or the user takes the default and the spec ends that line `(assumed)`. No option fits → the user's own words are the answer. The user asks for one question at a time → the same frontier, one question per message.

Facts are researched, never asked: what the codebase or docs can answer, explore.
While a round is out, scouts research the unknowns — one per independent unknown, all in ONE message; only questions downstream of a running scout wait. No subagents → the Lead researches between rounds.
A user answer naming a file, symbol, library or pattern is a claim: check it (the scout, else grep) before recording; a mismatch opens the next round with the code quoted.
Scope, user stories, priorities and cost / ROI come from the user — the product owner.
A domain term with more than one live reading → resolve it in the round (`CONTEXT.md` handling → `references/question-bank.md` Domain term; no file → read `CONTEXT.md` when present, propose one canonical word with a boundary example, ask only what the user must decide).
A layout or state-logic question talking cannot settle → offer `write-prototype` and park it (`references/question-bank.md` Prototype offer); no `write-prototype` → describe the candidate layouts or state flows in words and ask which holds.

A round's answers did not close the ambiguity → name the one unresolved thing and offer two concrete framings. Still unresolved → stop and record what is needed to resume. Never re-ask the same question in a new shape.

Done when: the frontier is empty and no scout is still out.

### 3. Approaches

A real design choice → 2-3 approaches, one per **lens** so they differ for real: **minimal** (smallest diff, maximum reuse) · **clean** (the boundary a maintainer would want, more files) · **pragmatic** (the seam between).
Each with trade-offs (complexity, blast radius, reversibility, cost); recommend one.
The clean lens names what minimal costs later (Rejected approaches records it); minimal already the clean boundary → one design and what the clean lens checked; never invent an alternative.
The approach adds or changes a DB table / migration, a public API contract, or a module boundary → ONE `system-architect` dispatch drafts the lenses, its brief naming the absolute path of `references/approaches.md`; no file → the Lead drafts them. An ADR → `references/approaches.md`; no file → only when it is hard to reverse, surprising without context and a real trade-off.
The user declines every approach → stop; report the block.

Done when: the user has 2-3 lensed approaches with one recommended, or one design with what the clean lens checked.

### 4. Self-review

Fix in the draft:
- placeholders (the spec-lint's list, step 6), contradictions between sections, ambiguous wording ("maybe", "should", "if needed");
- a Success criterion without "proven by", provable only at a seam the implementation alone reaches, or naming a not-yet-existing command unflagged — pair each with a real or explicitly-new command / observation a caller can reach;
- a Success criterion that is not behavior (the template's Success criteria);
- a technical claim behind the approach with no verifiable pointer (file:line, commit, or URL + date);
- a high-risk surface with no security / migration / audit plan — add it, or delegate to `security-engineer` / `system-architect`; no subagents → the Lead writes it;
- untested assumptions about the user's intent, scope creep, over-engineering for hypothetical needs.
- Testing decisions: the template's Testing decisions (apply the seam rule; `tdd-flow` owns edge / error / race criterion or R4 floor).
- Chosen approach: the template's Chosen approach (capture interface, data shape, compatibility rule, invariants when a DB / API / boundary changes).
- Each line the user did not answer in Discovery ends `(assumed)`.

Done when: no item above remains.

### 5. Cross-family critique

Runs only when all hold: Full mode, the cross-family pool on (opt-in), the session not wide-effort, and an R4 spec — or the user asks for a second opinion; R3 stays internal. It runs after Self-review, once Discovery has converged with no open question of your own. The same trigger gates `write-plan`'s independent plan review.
- Run → `cross-family` kind critique with the draft + Q&A ledger; no `cross-family`, or any condition false → skip; no status line.
- The status line, ran: `Cross-family critique: <cli> — N items, K settled from repo, M asked` (or `<cli> — NO FURTHER QUESTIONS`).
- Triage before the user sees anything: an item the repo or the spec settles → answer it yourself and fold it in; user decisions → one extra Discovery round; new questions continue normally. Never forward the critic's list raw.
- A fork the critique surfaces goes to Gate 1 as an option pair with a recommendation; the user decides.
- Once per spec: a draft revised after it never re-runs it. The status line goes under **High-risk surfaces**. Never blocks a spec.

Done when: the critique ran with its status line recorded, or was skipped.

### 6. Gate 1 — file review and approval

The spec lives under the private `docs/rolepod/` directory. Before the first save run:
```bash
grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore
```
A repo that deliberately tracks its working docs skips the command and creates `.rolepod/docs-tracked`.

After the approaches round, read back to the user: the goal, the scope, and each assumption (an `(assumed)` line) from the draft. Then write the whole spec to `docs/rolepod/specs/<feature>-YYYY-MM-DD.md` (optional `-vN` / `-draft`). Run Self-review and the spec-lint on the file, then point the user to it. Accept → `write-plan`; edit → patch and ask again; reject → stop. One gate, on the file; a spec set: all files and its map at once.

**Spec-lint**: `grep -niE '\[\[FILL:|TODO|TBD' <spec>` must print nothing; so must the anchor check `for h in 'Non-goals' 'Current behavior' 'Desired behavior' 'Success criteria'; do grep -q "^## $h" <spec> || echo "missing ## $h"; done` (the next repeat-feature spec seeds from these four headings). A printed line or a grep error is a lint failure.

Fill `templates/spec-template.md`. Keep the decision contract: goal, desired behavior, acceptance, testing, risk, chosen contract, open decisions. Write the spec in the user's language; headings, labels, file paths and commands stay verbatim.

A new decision requires the user's answer before hand-off; never write it as approved while unresolved. After Gate 1 a decision edits the section it changes, never an appended decision log; ask only where `write-plan` step 4 would, or when approved scope or criteria change.

Spec shapes, good and bad → `examples/spec-examples.md`; no file → the template and this step are enough.

Done when: spec-lint prints nothing, spec is saved and confirmed.

## Guardrails

- An ambiguous goal, scope or success criterion, or a high-risk surface, gets a spec. Never skip it.
- Implementation starts after Gate 1 approval. Never before.

## Next phase

- `write-plan` with the approved spec; a spec set → its first phase in the map's build order.
- `write-plan` absent → keep the implementation outline (files to touch, ordered tasks, test plan, risks, done criteria).
- No other skill → stop and give the spec path, Open questions and each `(assumed)` line.
