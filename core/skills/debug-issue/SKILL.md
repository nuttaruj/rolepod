---
name: debug-issue
description: The owner's debug loop (the Lead: report-only). Use when an error appears; a green test is red; a build broke; output is wrong; something worked before and stopped; a bug keeps recurring; a fix moved an error nearby.
---

# Debug Issue

The owner's debug loop: an unknown failure → a root-cause fix by narrowing, not guessing — reproduce → trace upstream to the root → failing test → minimal fix → regression-clean.
You never stop to ask: a question only the user can answer → return `BLOCKED` to your caller with the attempts and evidence; run alone (no caller) → ask the user.

Brief (the symptom, not a repro): the exact error and stack (or actual vs expected), where it shows, when it started, the diff since the last green, and — from `implement-plan` / `check-work` — `Attempts: <n> used` with each failed fix and why it stayed red.
Two repros come from another role first; each is your failing test:
- auth / token / injection symptoms → `security-engineer` writes the exploit repro test;
- a user-visible (E2E / UI) repro → `qa-tester` writes its red test or report.

### 1. Read the error

- Gather the exact error (literal quote), its throw site (file:line) and stack — no exception: actual vs expected and where it is observed — when it started failing (last green commit, deploy, data event), the failing command and the diff since last green. The real cause often sits mid-stack.
- Redact every secret you show (`<REDACTED>`); build the loop on env vars so a credential never lands in the transcript.

Done when: the literal error, throw site and stack (or actual vs expected) are captured, before any edit.

### 2. Reproduce

One command that fails on every run: `pytest path/test_x.py::name -v`, the exact failing `curl`, or UI steps + browser + console.
- Ready when that ONE command has run once and is red-capable (asserts the user's exact symptom, not "didn't crash"), deterministic, fast and unattended.
- Red → minimise: cut inputs, callers, config and steps one at a time, re-running after each, until every element left is load-bearing. That repro becomes step 6's test.
- Intermittent → raise the per-run failure rate to 50%+ first (loop the trigger, add stress, inject sleeps); a 1% flake is not yet debuggable. The repro is then ONE command running the trigger N times (N ≥ 10), red when any run fails; record N, the rate and the conditions (order, load, seed, clock) in the ledger's Repro. Green = that same loop, all N runs passing. Likely causes → `references/flake-triage.md`; no `references/flake-triage.md` → this loop is the whole recipe.
- Red only in CI, or no local repro → reproduce in CI / staging; red only locally → diff the two environments (env vars, locale, services, versions).
- No repro after 30 minutes → expand the repro environment once; still none → return `BLOCKED` with what you tried and its evidence (run alone → hand the user what you tried and stop).

A UI / browser bug, a WordPress bug, or sibling-plugin evidence under `.rolepod/evidence/` → `references/repro-backends.md`; no `references/repro-backends.md` → the first browser tool connected (none → describe the candidate repro for the user to confirm), or `wp-content/debug.log` for WordPress.

**Report-only** (the user only asked why it fails) → stop here; trace step 5 only when cheap; answer with the cause and evidence, no file changes. A debug report or QA hand-off only on request: Error, Repro, Severity and evidence filled, Failing test and Fix empty, Root cause only if cheap, handed to the owning dev.

Done when: one command reproduces the user's exact symptom on every run — an intermittent bug: the N-run loop, its rate and conditions recorded.

### 3. Roll back first

- Appeared right after your change → undo your own diff (reversible undos only), confirm green, re-apply piece by piece.
- Predates your changes, last-good commit unknown → `git bisect run <test>`.

Done when: your own last change is ruled in or out.

### 4. One hypothesis at a time

- 2+ plausible causes → list 2-3 candidates with the cheapest falsifier each, and run the top one yourself. A falsifier is a reversible act, not a user call.
- State it as `<variable / state / condition> is <value> because <upstream cause>`.
- Cheapest falsifier first: a log, a breakpoint, reading the called function, the fixture. One change per experiment; no spray of fixes.
- Tag debug logs with a unique prefix (`[DBG-a4f2]`) so cleanup is one grep.
- Find a working analog in the same codebase and list every difference on the path the symptom travels (input, config, call order, versions); a difference off that path is noise.

Track experiments in `templates/hypothesis-ledger.md` — Symptom, Repro, Experiments (one row each), Fix attempts, Root cause; no `templates/hypothesis-ledger.md` → a plain list under those five headings. A new hypothesis must hold against every prior row.

Done when: one hypothesis survives its falsifier and every prior ledger row.

### 5. Trace upstream

Symptom → caller → caller's caller, until a legitimate stopping point: external input (user, API, env, file, DB row) · a system boundary (network, OS, third-party lib) · an intentional invariant. Stop there, not where the value first looks wrong.
- Multi-component failure (CI → build → signing; API → service → DB) → instrument every boundary in one pass (what enters, what exits, what state is visible), run once, read which layer fails, investigate inside it; never guess the layer.
- Two traces lead to contradictory causes → two bugs or one shared upstream cause: trace each on its own before concluding.

The walk question by question, and symptom fix vs root fix → `references/root-cause-tracing.md`; no `references/root-cause-tracing.md` → walk caller by caller as above and log each fork as a ledger row.

Done when: the trace ends at a named stopping point, with its file:line.

### 6. Write the failing test

The test you wish had existed: red before the fix, green after, tight enough that a one-character regression breaks it. The loop → `tdd-flow`; no `tdd-flow` → one behavior, one failing test at the agreed seam, the smallest change to green; edge / error / race only with a criterion or an R4 floor; mock only external boundaries.
No seam reaches the real bug pattern (only a shallow single-caller test fits) → that is the finding: record it in the debug report and point the user at `/deepen-codebase`; a too-shallow test is false confidence.

Done when: the test is red on the unfixed code, or the report records why no seam can hold it.

### 7. Minimal fix

The smallest change that turns the failing test green without breaking the suite, at the root the trace found. No "while I'm here" refactor.
Same root cause across many call sites → fix the first two inline, grep the rest, and name the remaining call sites in your return with the two fixed instances as examples; the Lead dispatches one batch. Never ride the fix → check loop across the repo yourself.

Done when: the failing test is green.

### 8. Verify regression-clean

- Run the module suite (the full suite on high-risk surfaces). No new red → re-run the step 2 repro itself. A red the base tree also shows (just those tests, run at the base sha) is pre-existing: record it as a limitation, not this fix's.
- The `[DBG-]` tags grep to zero; your return names the hypothesis that held.
- The fix fails, or the test passes but the symptom returns → new evidence, not a prompt to adjust the patch: back to step 5 before another attempt; a re-fix without a re-trace is a blind retry.
- A failed fix attempt = a change meant to turn the same unresolved repro or criterion green that left it red; a falsifier, diagnostic, review rejection, verification-only rerun or revert is not one. Log each in the ledger's Fix attempts, carrying the count from the brief's `Attempts:` line — carry that count across owners and phases. At most four failed fixes count toward that same issue; unrelated criteria have separate counts.
- Review rounds and failed fixes count apart: a review rejection is no failed fix, and a new owner resets neither.

When the user requests a saved artifact: `templates/debug-report.md` — Error, Severity, Repro, Root cause, Failing test, Fix, Verification, Status; no `templates/debug-report.md` → a Markdown file with those eight headings.

Done when: the suite is green (or red only where the base tree is), the repro passes, and zero `[DBG-]` tags remain.

### 9. Second opinion

After two failed fixes for the same unresolved repro or criterion, including carried-in attempts → run Second opinion once before another fix. Arriving with 2 already used → reproduce (steps 1-2), then consult here before another hypothesis or fix.
1. Write ONE self-contained ledger file. The advisor is cold and sees only this: the symptom, the repro command, each failed fix and why it failed, the suspect code inline (never a pointer to the session).
2. Pool on → `cross-family` kind consult with the ledger — a FOREGROUND call. Pool off, wide-effort session, no usable member, or `cross-family` absent → the vertical fallback: the Lead's own CLI at its strongest model — its native advisor mode when it has one; else read the CLI's `--help` for its models, pick the top tier by name, and run it headless on the same ledger file (`<cli> -p --model <name>` / `<cli> exec -m <name>`). Valid only when that model differs from the one now running; already on it, or cannot tell → no usable advisor (item 4).
3. Read the reply as a **correction** (a new hypothesis), a **confirmation** ("approach right, check X"), or a **stop** ("wrong path"). Retrace the failure and use the advice and new repro evidence for each remaining attempt, up to four failed fixes total.
4. No usable advisor → stop before another fix: return `BLOCKED` with the ledger and attempts (run alone → ask the user). After a failed third or fourth fix, retrace before continuing; after the fourth failure, stop the same way. Record the opinion or why none was usable in the ledger. Never consult twice for the same issue or reset its count when ownership changes.

Dispatched, and item 2 is out of your reach → return `BLOCKED` naming the ledger path; the Lead consults and briefs the advice back.

Done when: the issue is fixed, or the fourth failed fix / unavailable advisor is returned `BLOCKED` with the ledger and options (run alone → handed to the user).

## Guardrails

- Reproduce first and fix at the traced source; a defensive guard without a demonstrated cause is not a fix.

## Next phase

- Fixed and green → back to your caller with the ledger, the red and green lines of the failing test and repro, and the diff stat.
- Run alone → `convening-code-review` on the fix.
- Not available → `review-code` on the diff. The report-only exit is exempt: its answer ends the loop.
- No other skill → stop and tell the user what changed, what was verified and what is still unverified or unreviewed, with each failing command tail quoted.
