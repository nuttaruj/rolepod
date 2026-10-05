---
name: debug-issue
description: Use when an error appears; a test that was green is red; a build broke; output is wrong; something worked before and stopped; the same bug keeps recurring; a fix made one error vanish while a similar one appeared nearby.
---

# Debug Issue

Phase = Build / Debug: turns an unknown failure into a root-cause fix by narrowing, not guessing — reproduce → trace upstream to the root → failing test → minimal fix → regression-clean.

## Skip when

- Never skip for a concrete bug, regression or failing test — those route here first at every tier. After root cause, `write-spec` only when the desired behavior / design is unresolved; `write-plan` only when sequencing or ownership needs it.
- A planned feature or a broad refactor → `implement-plan` / `simplify-code`.
- An approved plan in progress → continue `implement-plan`; never restart Define or Plan because this skill was invoked.

**Who runs the loop.** The Lead / owner contract → `using-rolepod` step 3; without it: the Lead routes, briefs from the symptom, spot-checks and commits, and the path owner runs this skill. Role map:
- the role that owns the path (`backend-developer` / `frontend-developer` / `billing-engineer` / …) reproduces, writes the failing test, then the fix, for every symptom class, auth / token / injection included;
- auth / token / injection symptoms → `security-engineer` writes the exploit repro test first — test evidence (`check-work`'s Security row), not a review; it returns to the Lead, who briefs the path owner to make it pass (that test is the owner's failing test). The owner's R4 review follows `review-code` by `workflow.mode` (Lite two lenses; Standard security + lenses; Full those plus adversarial) — never a second security review on top;
- `qa-tester` only for a user-visible (E2E / UI) repro; its red test or report returns to the Lead, who briefs the path owner to make it pass;
- `performance-engineer` — latency / memory regressions;
- `devops-sre` — infra / deploy / CI failures.

Brief (the symptom, not a repro): the exact error and stack (or actual vs expected), where it shows, when it started, the diff since the last green, and — from `implement-plan` / `check-work` — `Attempts: <n> used` with each failed fix and why it stayed red; the owner reproduces and hypothesises.
No subagents → the Lead does it.

### 1. Read the error

- Gather: the exact error (literal quote) with its throw site (file:line) and stack — a wrong output with no exception: actual vs expected and the file:line where it is observed — when it started failing (last green commit, deploy, data event), the repro steps or failing test command, the diff since last green.
- The real cause often sits mid-stack, not at the top.
- Redact every secret in the commands, output and artifacts you show (`<REDACTED>` in its place). Build the loop on env vars so a credential never lands in the transcript.

Done when: the literal error, throw site and stack (a wrong output: actual vs expected and where it is observed) are captured, before any edit.

### 2. Reproduce

One command that fails on every run: `pytest path/test_x.py::name -v`, the exact failing `curl`, or UI steps + browser + console; an intermittent bug → the loop below.
- The loop is ready when that ONE named command has run once and is red-capable (asserts the user's exact symptom, not "didn't crash"), deterministic, fast (seconds) and unattended.
- Red → minimise: cut inputs, callers, config and steps one at a time, re-running after each cut, until every remaining element is load-bearing. That repro becomes step 6's test.
- Intermittent → raise the per-run failure rate to 50%+ first (loop the trigger, add stress, inject sleeps); a 1% flake is not yet debuggable (`references/flake-triage.md`; no `references/flake-triage.md` → the loop below is the whole recipe). The repro is then ONE command running the trigger N times (N ≥ 10) that exits red when any run fails; record N, the rate and the conditions (order, load, seed, clock) in the ledger's Repro. After the fix, green = that same loop with all N runs passing.
- Fails in CI but not locally, or cannot repro locally → reproduce in CI / staging.
- Fails locally but green in CI → diff the two environments (env vars, locale, services, versions).
- No repro after 30 minutes → expand the repro environment once; still none → `manage-context` (escalate), or, if it is not available, hand the user what you tried and stop.

A UI / browser bug, a WordPress bug, or sibling-plugin evidence under `.rolepod/evidence/` → `references/repro-backends.md`; no `references/repro-backends.md` → the first browser tool connected (none → describe the repro and ask the user to confirm it), or `wp-content/debug.log` for WordPress.

**Report-only** (the user only asked why it fails) → stop here; trace step 5 only when cheap; answer with the cause and evidence, no file changes. A debug report or QA hand-off only when the user asked for one: Error, Repro, Severity and evidence filled, Failing test and Fix empty, handed to the owning dev.

Done when: one command reproduces the user's exact symptom on every run — an intermittent bug: the N-run loop, its rate and conditions recorded.

### 3. Roll back first

- The bug appeared right after your change → undo your own diff (reversible undos only), confirm green, re-apply piece by piece.
- The bug predates your changes and the last-good commit is unknown → `git bisect run <test>`.

Done when: your own last change is ruled in or out.

### 4. One hypothesis at a time

- 2+ plausible causes → list 2-3 candidates with the cheapest falsifier per row, and run the top one yourself. A falsifier is a reversible act, not a user call.
- State the chosen hypothesis as `<variable / state / condition> is <value> because <upstream cause>`.
- Cheapest falsifier first: a log, a breakpoint, reading the called function, checking the fixture. One change per experiment; no spray of fixes.
- Tag debug logs with a unique prefix (`[DBG-a4f2]`) so cleanup is one grep.
- Find a working analog in the same codebase (adjacent feature, sibling endpoint, parallel module). List every difference on the path the symptom travels — input, config, call order, versions — however small; a difference off that path is noise.

Track experiments in `templates/hypothesis-ledger.md` — Symptom, Repro, Experiments (one row each), Root cause; no `templates/hypothesis-ledger.md` → a plain list under those four headings. A new hypothesis must hold against every prior row.

Done when: one hypothesis survives its falsifier and every prior ledger row.

### 5. Trace upstream

Symptom → caller → caller's caller, until a legitimate stopping point: external input (user, API, env, file, DB row) · a system boundary (network, OS, third-party lib) · "designed this way" (an intentional invariant). Stop there, not at the first place the value looks wrong.
- Multi-component failure (CI → build → signing; API → service → DB; worker → queue → store) → instrument every boundary in one pass (what enters, what exits, what env / config / state is visible), run once, read which layer fails, investigate inside it. Never guess the layer without boundary evidence.
- Two traces lead to contradictory causes → re-read; you missed an interaction.

The upstream walk step by step, or a trace that forks → `references/root-cause-tracing.md`; no `references/root-cause-tracing.md` → walk caller by caller as above and log each fork as a ledger row.

Done when: the trace ends at a named stopping point, with its file:line.

### 6. Write the failing test

The test you wish had existed: red before the fix, green after. Tighten it until a one-character regression breaks it. The loop → `tdd-flow`. No `tdd-flow` → one behavior, one failing test at the agreed seam, the smallest change to green; edge / error / race only with a criterion or an R4 floor; mock only external boundaries.
No seam reaches the real bug pattern (only a shallow single-caller test fits) → that is the finding. Record it in the debug report and point the user at `/deepen-codebase`; a test at a too-shallow seam is false confidence.

Done when: the test is red on the unfixed code, or the report records why no seam can hold it.

### 7. Minimal fix

The smallest change that turns the failing test green without breaking the suite, at the root the trace found. No "while I'm here" refactor.
Same root cause across many call sites → fix the first 2 inline, grep the rest, and dispatch ONE cheap-class batch (the learned fix applied N times) with the 2 fixed instances as the brief's examples. Never ride the fix → check loop across the repo at Lead tier.

Done when: the failing test is green.

### 8. Verify regression-clean

- Run the module suite (the full suite on high-risk surfaces). No new red → re-run the step 2 repro itself.
- The `[DBG-]` tags grep to zero; the commit message names the hypothesis that held.
- The fix fails, or the test passes but the symptom returns → that is new evidence, not a prompt to adjust the patch. Feed it back into step 5 before any second attempt; a re-fix without a re-trace is a blind retry.
- A failed fix attempt = a change meant to turn the same unresolved repro or criterion green that left it red; a falsifier, diagnostic, review rejection, verification-only rerun or revert is not one. Log each in the ledger's Fix attempts, carrying the count from the brief's `Attempts:` line across owners and phases. At most four failed fixes count toward that same issue; unrelated criteria have separate counts.

When the user requests a saved artifact: `templates/debug-report.md` — Error, Severity, Repro, Root cause, Failing test, Fix, Verification, Status; no `templates/debug-report.md` → a Markdown file with those eight headings.

Done when: the suite is green, the repro passes, and zero `[DBG-]` tags remain.

### 9. Second opinion

After two failed fixes for the same unresolved repro or criterion, including carried-in attempts → run Second opinion once before another fix. Arriving with 2 already used → reproduce (steps 1-2), then consult here before another hypothesis or fix. Carry the count across owners and phases.
1. Write ONE self-contained ledger file. The advisor is cold and sees only this: the symptom, the repro command, each failed fix and why it failed, the suspect code inline (never a pointer to the session).
2. Pool on → `cross-family` kind consult with the ledger — a FOREGROUND call. Pool off, wide-effort session, no usable member, or `cross-family` absent → the vertical fallback: the Lead's own CLI at its strongest model — its native advisor mode when it has one; else read the CLI's `--help` for the models it exposes, pick the top tier by name, and run it headless on the same ledger file (`<cli> -p --model <name>` / `<cli> exec -m <name>`). Valid only when that model differs from the one now running; already on it, or cannot tell → no usable advisor (item 4).
3. Read the reply as a **correction** (a new hypothesis), a **confirmation** ("approach right, check X"), or a **stop** ("wrong path"). Retrace the failure and use the advice and new repro evidence for each remaining attempt, up to four failed fixes total.
4. No usable advisor → stop and ask the user before another fix. After a failed third or fourth fix, retrace before continuing; after the fourth failure, stop and ask. Record the opinion or why none was usable in the ledger. Never consult twice for the same issue or reset its count when ownership changes.

Done when: the issue is fixed, or the fourth failed fix / unavailable advisor is handed to the user with the ledger and options.

## Guardrails

- Reproduce first and fix at the traced source; a defensive guard without a demonstrated cause is not a fix.
- The Second opinion and four-failure stop follow step 9; carry that count across owners and phases.

Symptom-vs-root and retry-hack-vs-triaged-flake pairs → `examples/debug-examples.md`; no `examples/debug-examples.md` → skip, the steps above stand alone.

## Next phase

- `check-work` verifies the fix with evidence.
- If `check-work` is not available, attach the test output, the diff, and any UI / log evidence to the user response.
