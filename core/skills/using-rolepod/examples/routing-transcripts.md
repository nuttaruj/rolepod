<!-- Worked routing transcripts for using-rolepod. -->
<!-- Load when no router row matches the request. -->
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
Next step: discovery dialogue in frontier rounds — every ready question together (start with outcome).

---

## 2. Clear one-file edit → Build / orchestrating-plans

User: "the footer copyright year is hardcoded to 2024 — make it dynamic"

Route: R2 (one file + test) → orchestrating-plans · Owner frontend-developer · exact target, one file, logic-bearing, no design choice
Skipping: Define + Plan — the 3-5 line checklist is the plan. Its verify command still runs.
Next step: write the checklist (goal, done-when, verify command); a task owner builds it on main.

---

## 2a. Approved spec with a complete three-task sequence → Build / orchestrating-plans

User: "Implement the approved spec."

Route: R3 spec-as-plan (the R3 row's eligibility met) → orchestrating-plans
Skipping: Define + Plan — the approved spec already supplies the task boundaries and commands.
Next step: the spec's ordered tasks become the owner's inline checklist; no plan artifact. Any eligibility condition missing → the plan artifact.

---

## 3. Bug / failing test → Build / debug-issue

User: "the checkout test was green yesterday, it's red now"

Routing: Build (bug) → debug-issue
Reason: a regression — root cause unknown. Not a feature, not a plan.
Skipping: Define + Plan.
Next step: brief the path owner from the symptom (the red test, its error, the diff since yesterday's green); it reproduces with one command and traces upstream — no patch before the trace.

---

## 4. "Is this done?" → check-work, then Review and Ship

User: "ok I think the export feature is finished"

Routing: check-work (done-claim helper) → Review: `convening-code-review` if no review covers the diff → Ship: `finish-work`
Reason: a completion claim needs fresh evidence; review and the branch decision follow in their own phases, and `finish-work` runs the QA pass.
Skipping: none.
Next step: check-work first — produce fresh evidence the feature works.

---

## 5. Repo-wide sweep → ONE scout, then act on its report

User: "find every place we build a SQL query by string concatenation"

Routing: wide sweep → ONE read-only `scout` (the Code search rule; `references/scope-then-spawn.md`).

The brief the Lead sends (the four inputs from the scout agent):
```
Question: where do we build SQL by string concatenation (injection risk)?
Scope: whole repo, focus on db / models / queries / repositories.
Useful answer: a list of file:line sites + the concat pattern each uses.
Budget: ~12 tool uses.
```

Next step: the Lead reads only the files the scout points at and routes the fix by tier like any commission; a fix on a high-risk path is R4: the full spine and the review set the carried mode names.

---

## 6. Refactor request → Build / orchestrating-plans

User: "this OrdersService file is a mess, clean it up"

Routing: Build (refactor) → `orchestrating-plans`, Owner <path role>; the owner loads `simplify-code`
Reason: cleanup with no behavior change — behavior-preserving simplification.
Skipping: Define + Plan.
Next step: the owner confirms the suite is green first; no simplifying on red.

---

## 7. Pattern-matched into Build → corrected

User: "add rate limiting"

✗ Wrong: Build → orchestrating-plans. "add" matched the Build verb, so start
  coding. But rate limiting is unspecified — per-user or per-IP? what limit?
  what happens at the limit? Coding now drifts.

✓ Right: Define → write-spec.
  Reason: "rate limiting" hides several decisions that change the diff.
  Next step: ask scope (per-IP vs per-user), the limit, the over-limit
  behavior — together, in one frontier round.

The verb is not the router. A vague target routes to Define even when the
verb sounds like Build.
