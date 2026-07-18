<!-- Worked routing transcripts for using-rolepod. -->
<!-- Load when a request does not obviously match a Quick-router row. -->
<!-- Each transcript: user message → routing decision → next step. -->

# Routing Transcripts

The router picks the FIRST phase + skill; the skill itself decides what
comes next. These are worked examples — the reasoning, not just the answer.
A weak model should be able to route any common case by matching these.

---

## 1. Vague feature → Define / write-spec

User: "build me a notifications system"

Routing: Define → write-spec
Reason: a feature with no spec — target, scope, and success are unstated.
Skipping: none.
Next step: discovery dialogue, one question at a time (start with outcome).

---

## 2. Clear one-file edit → Build / implement-plan

User: "the footer copyright year is hardcoded to 2024 — make it dynamic"

Routing: Build → implement-plan
Reason: exact target, obvious change, one file, no design choice.
Skipping: Define + Plan — the diff is clear. Lightweight Verify still runs.
Next step: read the file, make the edit, confirm it renders.

---

## 3. Bug / failing test → Build / debug-issue

User: "the checkout test was green yesterday, it's red now"

Routing: Build (bug) → debug-issue
Reason: a regression — root cause unknown. Not a feature, not a plan.
Skipping: Define + Plan.
Next step: reproduce with one command, then trace upstream — do not patch.

---

## 4. "Is this done?" → Ship finish ritual

User: "ok I think the export feature is finished"

Routing: Ship → finish ritual (check-work → review-code → finish-work)
Reason: a completion claim — needs evidence, review, then a branch decision.
Skipping: none — the ritual runs in order.
Next step: check-work first — produce fresh evidence the feature works.

---

## 5. Repo-wide sweep → ONE scout, then act on its report

User: "find every place we build a SQL query by string concatenation"

Routing: wide sweep (unknown locations, several naming conventions) →
dispatch ONE read-only `scout` (always-on Code search rule). Do not sweep
yourself and do not fan one agent per file.

The brief the Lead sends (the four inputs from the scout agent):
```
Question: where do we build SQL by string concatenation (injection risk)?
Scope: whole repo, focus on db / models / queries / repositories.
Useful answer: a list of file:line sites + the concat pattern each uses.
Budget: ~12 tool uses.
```

The report the scout returns (conclusion → pointers → gaps):
```
Conclusion: 3 concat sites, all in the legacy reporting module; the ORM is
used everywhere else.
Findings:
- f-string SQL in the CSV export — `app/reports/export.py:88`
- % -formatted WHERE clause — `app/reports/filters.py:41`
- string-concat ORDER BY — `app/reports/sort.py:23`
Gaps: raw SQL behind the `LEGACY_SQL` flag not exercised — flag was off.
```
Next step: the Lead reads only those three files and routes the fix to
`security-engineer` — it never re-swept the repo itself.

✗ Anti-pattern: spawn one agent per file across 300 files, or sweep all 300
  yourself and dump the matches.
✓ Correct: ONE scout returns a short report; the Lead acts on its pointers.

---

## 6. /rolepod-full → force-full lifecycle

User: "/rolepod-full add CSV export to the orders report"

Routing: Force full lifecycle via /rolepod-full
Reason: explicit force-full trigger — the user opted out of skip rules.
Skipping: none — Define → Plan → Build → Verify → Review → Ship, all phases.
Next step: announce the execution backend, enter Define / Phase 0 discovery.

---

## 7. Refactor request → Build / simplify-code

User: "this OrdersService file is a mess, clean it up"

Routing: Build (refactor) → simplify-code → check-work
Reason: cleanup with no behavior change — behavior-preserving simplification.
Skipping: Define + Plan.
Next step: confirm the test suite is green first — no simplifying on red.

---

## 8. Pattern-matched into Build → corrected

User: "add rate limiting"

✗ Wrong: Build → implement-plan. "add" matched the Build verb, so start
  coding. But rate limiting is unspecified — per-user or per-IP? what limit?
  what happens at the limit? Coding now drifts.

✓ Right: Define → write-spec.
  Reason: "rate limiting" hides several decisions that change the diff.
  Next step: ask scope (per-IP vs per-user), the limit, the over-limit
  behavior — one question at a time.

The verb is not the router. A vague target routes to Define even when the
verb sounds like Build.
