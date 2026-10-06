---
name: deepen-codebase
description: Use when the user explicitly types /deepen-codebase or $deepen-codebase to scan for shallow modules; never for a normal request, even one about module design or testability.
disable-model-invocation: true
---

# Deepen Codebase — where a module should get deeper

Turns architectural friction into a visual report of **deepening** candidates — refactors that make a shallow module deep, for testability and navigability — then offers a `write-spec` on the card the user picks.

## Skip when

- A trivial or tiny repo, or a request that is really a bug or a feature → say so and route normally.
- One pre-chosen module to redesign → that is a `write-spec` architecture decision, not a scan.
- Dead code to cut → `simplify-code`.

### 1. Scope

Three entries, in this order of precedence:
1. The user points at an upcoming change — a spec, a ticket, "how can we make this change easy?" → the walk starts from the paths that change will touch; deepening there pays before the build. The most effective use.
2. The user names an area, a module, a pain point → start there. Legacy test work → look for the missing seams before testing code its interface cannot reach.
3. Nothing named → `git log --oneline --name-only` over a good stretch: the paths that keep recurring pull attention FIRST — they order the walk, they never fence it. Scattered history or a brownfield audit → the whole tree. Routine upkeep every few days lands here too — it scans the hot spots.

Read `CONTEXT.md` and `docs/adr/` for the area before walking, when present. An ADR is a decision already made.
YAGNI: a deepening in code nobody touches is a refactor never cashed in.

Done when: the scope and its entry are named, and the area's `CONTEXT.md` and ADRs are read when present.

### 2. Explore

Dispatch ONE general sub-agent at full strength — the CLI's general-purpose agent, shell access, NO model override so it inherits the Lead's model; a Lead below the strong class passes the strong class on this ONE call instead (no per-call model on the CLI → the report names the explorer's class as a limitation). Never the cheap `scout`: the walk is judgment, not a sweep, and its worth is the claims it reproduces.

Its brief:
- the scope from Scope;
- the **deletion test**: imagine deleting the module and inlining it into its callers — complexity reappearing across N callers means it earns its keep; complexity that just vanishes marks a shallow pass-through; N hand-kept copies of one rule = a candidate, and a candidate that fails the test is dropped, not softened;
- read `references/explorer-lens.md` first when present — vocabulary, friction signals, drift check (optional depth);
- use the codebase's own words: `CONTEXT.md` terms for the domain, `references/explorer-lens.md` Vocabulary for the shape (no file → module, interface, depth, seam, adapter, leverage, locality);
- walk organically in ONE pass over the scope — hot spots first, the rest of the scope after — noting where IT struggles; never a second lap: an area it did not reach is named in the return;
- any command that writes nothing in the repo (grep, `git log`, an existing test, a scratch script in the temp dir) may reproduce a claim;
- return candidates (files with `path:line`, the friction, the deletion-test result), every bug met on the way (`path:line` + the reproducing command, or `read only, not reproduced`) and the areas not reached — never an edit, never an interface.

No subagents → the Lead walks the same way (the deletion test above, the lens when present), one area per run on a large legacy tree so the walk does not circle.

Done when: the explorer returned its candidates and bugs.

### 3. Verify

Before writing, the Lead checks what came back:
- open every `path:line` a kept candidate cites;
- re-run each claimed bug's reproduction (fails or cannot run → `read only`);
- re-apply the deletion test — every listed candidate passes it;
- merge duplicates and drop what fails.

Done when: every kept candidate passed the deletion test, and `Strong` stands only where the evidence still holds after this check.

### 4. Report

Write ONE HTML file to the OS temp dir — `$TMPDIR`, else `/tmp`, `%TEMP%` on Windows — named `deepen-codebase-<timestamp>.html`. Open it (`open` on macOS, `xdg-open` on Linux, `start` on Windows) and print the absolute path.

One card per candidate, exactly these fields:
- **Files**;
- **Problem** — the friction, in the domain's words;
- **Solution** — plain words, no interface yet;
- **Benefits** — locality and leverage, how tests change;
- **Before / After** — a side-by-side drawing of the shallow shape and the deepened shape;
- **Strength** — `Strong`: the deletion test passes clearly and the friction is real; `Worth exploring`: plausible, the payoff depends on where the code is heading; `Speculative`: surfaced for completeness, safe to ignore.

A conflict with an ADR is a marked callout on the card, raised only when the friction is worth reopening that decision.
After the cards, **Bugs found on the way** — one row each: `path:line` · what breaks · reproduced / read only · → `debug-issue`. A bug is never a card.
The report ends with **Top recommendation** — which card first and why; only a `Strong` or `Worth exploring` card qualifies.
No such card → the report states `No deepening worth doing in <scope>` with the areas walked and not reached, and has no Top recommendation. That is a complete result; never promote a `Speculative` card to fill the slot.
Scaffold and drawing patterns → `references/html-report.md`; absent, a plain page with the six fields per card is the report.

Done when: the file is written, opened, and its path printed.

### 5. Hand-off

Stop after the report and ask, in one message: which card, and whether to open a `write-spec` on it now.
- No Top recommendation → no card question: give the path, and offer only the listed bugs (`debug-issue`), if any.
- "Just the report" → stop; the path is the deliverable.
- A listed bug → `debug-issue` on its own, or into the picked card's spec when it sits inside that card's files.
- Reject → offer the ADR per `write-spec/references/approaches.md`; no re-suggest.

Done when: the user picked a card, chose the report only, rejected with the ADR offered, or the no-deepening report was handed over.

## Guardrails

- This skill reads and reports; the report is the only new file. Never edit product code from it.
- The spec designs the deepened interface. Never propose the new interface here.

## Next phase

- `write-spec` with the picked card as the Source spec: its Discovery settles the domain terms (into `CONTEXT.md` as they resolve) in frontier rounds, never one question at a time, and its Approaches presents the options with the one-shot `system-architect`; then `write-plan` → `implement-plan`. ONE card per session — a second card is a new spec in a fresh session.
- If `write-spec` is not available, the report path and the picked card are the deliverable; the user takes it from there.
- No other skill to move to → stop and give the user the report path, the cards by Strength (Strong, Worth exploring, Speculative), and the areas of the scope not reached.
