<!-- Discovery question bank for write-spec. Load when unsure what to ask. -->
<!-- Iron rule: ask ONLY questions whose answer changes the implementation. -->
<!-- If the codebase can answer it, read the codebase — do not spend a question. -->

Ask every ready question in the round together, per SKILL.md §2's frontier-round policy; within a round, resolve the question that gates the others first.

## Question types

### Outcome
What does success look like in one sentence? What breaks if this is not built?

### Domain term
A word the spec depends on ("account", "cancel", "member") with more than one live reading that changes behavior: read the repo's existing glossary / CONTEXT first, propose a definition with a boundary example, check it against the code, and ask only the part the user must decide. A term used by this feature alone gets one line in the spec — no new glossary file.

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

## Cross-family critique — questions only, before Gate 1 (§4b)


The Lead's own discovery finds the questions the Lead's own model can see.
A cold reader from a different family sees different gaps — cheapest at
Define, where an ambiguity costs a question instead of a rewrite.

## Gate

All three: the user's cross-family pool is enabled (`rolepod-cross-family
--pool`; opt-in — off is a choice, skip silently, no limitation note), the
spec is R3+ or touches a high-risk surface (or the user asks), and the
discovery dialogue has converged (the Lead has no open questions of its own).
Never for routine specs.

## Protocol

1. **Brief file** = the draft spec as it stands after §1-§4 + the **Q&A
   ledger**: every question already asked, numbered, with the user's
   answer. The critic is told never to re-ask those; an incomplete ledger
   produces duplicate questions the user has already answered.
2. **Run** `rolepod-cross-family --kind critique --brief spec-draft.md`
   (add `--lead <cli>` outside Claude; 10-minute budget per member, foreground). The runner frames the critic: at
   most 5 items ranked by implementation risk, each `QUESTION` (only the
   user can decide — the answer changes the implementation), `AMBIGUITY`
   (wording two engineers would read differently, quoted), or `MISSING`
   (an acceptance criterion / failure mode / edge case with no "proven
   by"); `NO FURTHER QUESTIONS` when nothing material remains. Read-only,
   the external's own default model, anchored under
   `.rolepod/evidence/external/`, logged `phase: advise`, `kind: critique`.
3. **Triage before the user sees anything.** Items the repo or the spec
   already settle → answer them yourself (Read / `rg`, never guess) and
   fold the answer into the draft. Items that are genuinely the user's
   decision → ONE extra discovery round per §2: numbered, a recommended
   default per question. Never forward the critic's list raw, never run a
   second critique on the same draft — new material questions the answers
   reveal continue in normal discovery.
4. **Record** one line under **Open questions** (the template carries the
   slot): `Cross-family critique: <cli> — N items, K settled from repo, M
   asked` · `Cross-family critique: <cli> — NO FURTHER QUESTIONS` ·
   `Cross-family critique: not run — off` / `— <runner reason>`.

## Degradation

Runner exit 3 (every member failed) / 4 (enabled, nothing usable) / 5 (off)
→ proceed to Gate 1 with the matching line. A spec never waits on an
external. A hard **approach** decision the critique surfaces (a fork, not a
question) is not this channel — it is write-plan's advisory panel
(`--kind advise --all`, same gate as its `advisory-routing` reference).
