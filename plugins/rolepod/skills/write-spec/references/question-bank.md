<!-- Discovery question bank for write-spec. Load when unsure what to ask. -->
<!-- Rule: ask ONLY questions whose answer changes the implementation. -->
<!-- If the codebase can answer it, read the codebase — do not spend a question. -->

Ask every ready question in the round together, per the frontier-round policy in `write-spec` Discovery; within a round, resolve the question that gates the others first.

## Question types

### Outcome
What does success look like in one sentence? What breaks if this is not built?

### Domain term
A word the spec depends on ("account", "cancel", "member") with more than one live reading that changes behavior: read the repo's existing `CONTEXT.md` first (a `CONTEXT-MAP.md` at the root lists several contexts and where each `CONTEXT.md` lives — pick the one the topic belongs to, ask when unclear), propose a definition with a boundary example, check it against the code, and ask only the part the user must decide. A term used by this feature alone gets one line in the spec — no new glossary file.

Moves that sharpen the model — each at the moment it applies, never batched at the end:
- Challenge: the user's word conflicts with the glossary → say so and ask which reading holds.
- Sharpen: an overloaded word ("account": the Customer or the User?) → propose the precise canonical term.
- Scenario: a relationship between concepts → invent the edge case that forces the boundary (a partial cancellation, a member of two accounts).
- Cross-reference: the user states how it works → check the code; a contradiction is quoted back ("the code cancels whole orders; you said partial — which is right?"), never assumed away.

Resolve the term in the round it comes up and propose ONE canonical word. Settled and used beyond this feature → write it into `CONTEXT.md` at that moment (create the file then, never at the end).

Glossary entry in `CONTEXT.md` (repo root, or the mapped context; create the file when the first term is resolved):
```
**Order**:
A customer's request to buy, from placement until fulfilment or cancellation.
_Avoid_: purchase, transaction
```
One or two sentences of what the term IS, not what it does; be opinionated — one word wins, the rest go under `_Avoid_`; only concepts specific to this project (a timeout or an error type is not a domain term); subheadings only when clusters emerge. The file is a glossary and nothing else — no specs, no implementation decisions: those are the spec, or an ADR (`docs/adr/NNNN-<slug>.md`, title + 1-3 sentences) when the three ADR tests in `write-spec` Approaches hold.

### User / actor
Who triggers this? Who sees the result? Is it self-service or admin-only?

### Data source
Where does the data come from — existing table, new table, external API? Is it already populated?

### Permission / auth
Who is allowed to do this? Does it create or change a credential or permission?

### Error states
What happens on invalid input, expired state, missing record, or concurrent action?

### Migration / backfill
Does existing data need to change shape? Does old data need a default or a backfill?

### UI state
Empty state, loading state, partial-failure state — which exist and what do they show?

### Success metric
How do we know it worked after ship — a number, a log line, a user-visible change?

### Rollout / rollback
Feature flag? Staged rollout? How is it turned off if it misbehaves?

## Selection order

When several question types apply, ask in this order — each answer narrows the next:

1. **Outcome** — what are we even building? Settles every question downstream.
2. **User / actor** — who it serves; changes UI, permissions, and error handling.
3. **Permission / risk** — does it touch a high-risk surface? Pulls in security / migration questions.
4. **Data source** — where the data lives; settles schema and migration scope.
5. **Error states** — only meaningful once data and actor are known.
6. **Rollout / rollback** — last; how a now-defined change ships safely.

Stop early: if an answer makes a later question irrelevant, skip it.

## Skip a question when
- The codebase or repo docs already answer it.
- The answer does not change a single line of the implementation.
- It is a styling / naming detail the user already delegated.
- The user already answered it this session or in a prior spec revision —
  re-ask only when new evidence changes it, and say what changed.

## Answering the round
- A partial reply (`1a 3c`) closes only those questions; the rest stay open
  next round, never defaulted.
- `defaults` takes only the recommendations shown that round; silence or
  elapsed time is not an answer.

## Prototype offer

A layout or state-logic question that talking cannot settle → offer `write-prototype` in one line (yes / skip) and park that question.
- Yes → it builds once the rest of the frontier is settled — a spec with open questions builds the wrong demo — and before Gate 1; its verdict settles the parked question.
- Skip → carry on; Gate 1 and `write-plan` as usual.

## Cross-family critique — questions only, before Gate 1

The Lead's own discovery finds the questions the Lead's own model can see.
A cold reader in a different CLI (its own model, none of your context) sees different gaps — cheapest at
Define, where an ambiguity costs a question instead of a rewrite.

## Gate

All three: the user's cross-family pool is enabled (opt-in — off is a
choice, skip silently, no limitation note), the spec is R4 / touches a
high-risk surface (or the user asks; R3 stays internal), and the
discovery dialogue has converged (the Lead has no open questions of its own).
Never for routine specs.

## Protocol

1. **Brief file** = the draft spec as it stands after Self-review + the **Q&A
   ledger**: every question already asked, numbered, with the user's
   answer. An incomplete ledger produces duplicate questions the user has
   already answered.
2. **Run** — pool on → `cross-family` kind critique with that file; it
   returns every material item, no cap, ranked by implementation risk
   (`QUESTION` / `AMBIGUITY` / `MISSING`, or `NO FURTHER QUESTIONS`). Pool
   off or `cross-family` absent → skip to step 4.
3. **Triage before the user sees anything.** Items the repo or the spec
   already settle → answer them yourself (Read / grep, never guess) and
   fold the answer into the draft. Items that are genuinely the user's
   decision → ONE extra round per Discovery: numbered, a recommended
   default per question. Never forward the critic's list raw, never run a
   second critique on the same draft — new material questions the answers
   reveal continue in normal discovery.
4. **Record** one line under **Open questions** (the template carries the
   slot): `Cross-family critique: <cli> — N items, K settled from repo, M
   asked` · `Cross-family critique: <cli> — NO FURTHER QUESTIONS` ·
   `Cross-family critique: not run — off` / `— cross-family absent` /
   `— <runner reason>`.

## Degradation

No usable member, or the pool off → proceed to Gate 1 with the matching line. A spec never waits on an
external. A hard **approach** decision the critique surfaces (a fork, not a
question) goes to Gate 1 as an option pair with a recommendation — the
user decides; never a second external.
