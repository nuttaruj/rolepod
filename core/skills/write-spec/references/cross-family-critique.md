<!-- Load at write-spec §4b when the cross-family pool is enabled and the spec is R3+ / high-risk. -->

# Cross-family critique — questions only, before Gate 1

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
   (add `--lead <cli>` outside Claude). The runner frames the critic: at
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
   default per question, cap 5. Never forward the critic's list raw, never
   run a second critique on the same draft.
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
