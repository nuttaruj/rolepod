---
name: deepen-codebase
description: Scan a codebase for deepening opportunities — shallow modules, leaking seams, interfaces a test cannot cross — present them as a visual report, then offer a write-spec on the card the user picks. Use only when the user explicitly invokes /deepen-codebase or $deepen-codebase.
---

# Deepen Codebase — where a module should get deeper

Surface architectural friction and propose **deepening**: a refactor that turns a shallow module into a deep one, for testability and navigability. A report and an offer — never an autonomous refactor.

## Boundary

Owns: scoping, the friction walk, the report, the hand-off question.

Does not own: the design of the deepened module, the spec, the plan, the code — `write-spec` → `write-plan` → `implement-plan` own those. Cutting dead code is `simplify-code`.

## Iron rules

<EXTREMELY-IMPORTANT>
1. NEVER edit product code from this skill — it reads and reports.
2. NEVER propose the new interface here — that is the spec's job.
3. Every candidate passes the deletion test before it is listed.
4. Use the codebase's own words: `CONTEXT.md` terms for the domain, module / interface / seam / depth for the shape.
5. An ADR in `docs/adr/` is a decision already made — surface a conflict only when the friction is worth reopening it, marked as such.
</EXTREMELY-IMPORTANT>

## Step 1 — scope

Three entries, in this order of precedence:
1. The user points at an upcoming change — a spec, a ticket, "how can we make this change easy?" → the walk starts from the paths that change will touch; deepening there pays before the build.
2. The user names an area, a module, a pain point → start there.
3. Nothing named → `git log --oneline --name-only` over a good stretch: the paths that keep recurring pull attention FIRST — they order the walk, they never fence it. Scattered history or a brownfield audit → the whole tree.

Read `CONTEXT.md` and `docs/adr/` for the area before walking. YAGNI: a deepening in code nobody touches is a refactor never cashed in.

## Step 2 — explore

Dispatch ONE `scout` — cheap, read-only — to walk the codebase organically: hot spots first, everything reachable after, no rigid heuristics — it notes where IT experiences friction. What friction looks like (a lens, not a filter):

- understanding one concept means bouncing between many small modules
- a module is shallow, its interface nearly as complex as its implementation
- pure functions were extracted for testability but the real bugs hide in how they are called, no locality
- tightly-coupled modules leak across their seams
- a part is untested or cannot be tested through its current interface

Apply the deletion test to every suspect — complexity concentrates behind a smaller interface when deleted = the signal; spreads across callers = drop it. The scout returns candidates only, never edits. No scout support on this CLI → the Lead walks the same way, one area per run on a large legacy tree so the walk does not circle.

## Step 3 — report

Write ONE self-contained HTML file to the OS temp dir — `$TMPDIR`, else `/tmp`, `%TEMP%` on Windows — named `deepen-codebase-<timestamp>.html`. Open it (`open` on macOS, `xdg-open` on Linux, `start` on Windows) and print the absolute path.

One card per candidate, exactly these fields: **Files** · **Problem** (the friction, in the domain's words) · **Solution** (plain words, no interface yet) · **Benefits** (locality and leverage, how tests change) · **Before / After** (a side-by-side drawing of the shallow shape and the deepened shape) · **Strength** — `Strong`: the deletion test passes clearly and the friction is real; `Worth exploring`: plausible, the payoff depends on where the code is heading; `Speculative`: surfaced for completeness, safe to ignore.

An ADR conflict is a marked callout on the card. The report ends with **Top recommendation** — which card first and why. The report is the only new file — no code changes during the run. Scaffold and drawing patterns: `references/html-report.md` — absent, a plain page with the six fields per card is the report.

## Step 4 — hand-off

Stop after the report and ask, in one message: which card, and whether to open a `write-spec` on it now. "Just the report" → stop, the path is the deliverable.

Yes → `write-spec` with the card as the Source spec — its §2 questions settle the domain terms (into `CONTEXT.md` as they resolve) in frontier rounds, never one question at a time; its §3 presents the approaches with the one-shot `system-architect`; then `write-plan` → `implement-plan`. ONE card per session — a second card is a new spec in a fresh session, never stacked into this one.

The user rejects a card for a load-bearing reason → offer the ADR under write-spec's three tests so a later run does not re-suggest it.

## When it pays

- Routine upkeep — run it unprompted every few days; it scans the hot spots.
- Before a big build — point it at the spec: "how can we make this change easy?" The most effective use.
- Brownfield audit — an unstructured codebase, the whole tree.
- Legacy test work — find the missing seams before testing code that cannot be tested through its interface.

## Sanity check

A trivial or tiny repo, or a request that is really a bug or a feature → say so and route normally instead of a report. One pre-chosen module to redesign → that is a write-spec architecture decision, not a scan.

## References

Load only when needed:
- `references/html-report.md` — scaffold, diagram patterns, styling.
