---
name: debug-issue
description: Use when something is broken — error appears, test fails, build breaks, output is wrong, regression returns. Reproduce, trace upstream to root cause, write a failing test, ship a minimal fix. Phase = Build / Debug.
when_to_use: when an error appears, a test that was green is red, a build broke, output is wrong, something worked before and stopped, the same bug keeps recurring, or a fix made one error vanish while a similar one appeared nearby
---

# Debug Issue

Turns an unknown failure into a root-cause fix by narrowing, not guessing: reproduce → trace upstream to the root → failing test → minimal fix → regression-clean.

## Skip when

- Requirements are unclear → `write-spec`.
- The work is a planned feature or a broad refactor → `implement-plan` / `simplify-code`.
- The fix spans several files or needs sequencing → `write-plan` once the root cause is known.

**Who runs the loop.** Iteration is the costliest work to run in the Lead's context; delegate it:
- the role that owns the path (`backend-developer` / `frontend-developer` / …) writes the reproducing failing test, then the fix; `qa-tester` only for a user-visible (E2E / UI) repro;
- `security-engineer` — auth / token / injection symptoms;
- `performance-engineer` — latency / memory regressions;
- `devops-sre` — infra / deploy / CI failures.

Brief: the exact error, stack, repro command, hypothesis, files touched since last green.
No subagents → the Lead does it.

### 1. Read the error

- Gather: the exact error (literal quote), the throw site (file:line) and stack, when it started failing (last green commit, deploy, data event), the repro steps or failing test command, the diff since last green.
- The real cause often sits mid-stack, not at the top.
- Redact every secret in the commands, output and artifacts you show (`<REDACTED>` in its place). Build the loop on env vars so a credential never lands in the transcript.

Done when: the literal error, throw site and stack are captured, before any edit.

### 2. Reproduce

One command, the same failure every time: `pytest path/test_x.py::name -v`, the exact failing `curl`, or UI steps + browser + console.
- The loop is ready when that ONE named command has run once and is red-capable (asserts the user's exact symptom, not "didn't crash"), deterministic, fast (seconds) and unattended.
- Red → minimise: cut inputs, callers, config and steps one at a time, re-running after each cut, until every remaining element is load-bearing. That repro becomes step 6's test.
- Intermittent → raise the failure rate first (loop the trigger, add stress, inject sleeps) to a 50%+ signal; a 1% flake is not yet debuggable (`references/flake-triage.md`).
- Fails in CI but not locally, or cannot repro locally → reproduce in CI / staging.
- Fails locally but green in CI → diff the two environments (env vars, locale, services, versions).
- No repro after 30 minutes → expand the repro environment once; still none → `manage-context` (escalate), or, if it is not available, hand the user what you tried and stop.

A UI / browser bug, a WordPress bug, or sibling-plugin evidence under `.rolepod/evidence/` → `references/repro-backends.md`.

**Report-only** (the user wants the bug documented, not fixed; a QA hand-off) → stop here; trace step 5 only when cheap. Fill the debug report with Error, Repro, Severity and evidence, leave Failing test and Fix empty, and hand it to the owning dev.

Done when: one command reproduces the user's exact symptom on every run.

### 3. Roll back first

- The bug appeared right after your change → undo your own diff (reversible undos only), confirm green, re-apply piece by piece.
- The bug predates your changes and the last-good commit is unknown → `git bisect run <test>`.

Done when: your own last change is ruled in or out.

### 4. One hypothesis at a time

- 2+ plausible causes → list 2-3 candidates with the cheapest falsifier per row, and run the top one yourself. A falsifier is a reversible act, not a user call.
- State the chosen hypothesis as `<variable / state / condition> is <value> because <upstream cause>`.
- Cheapest falsifier first: a log, a breakpoint, reading the called function, checking the fixture. One change per experiment; no spray of fixes.
- Tag debug logs with a unique prefix (`[DBG-a4f2]`) so cleanup is one grep.
- Find a working analog: code in the same codebase that does the similar thing successfully (adjacent feature, sibling endpoint, parallel module). List every difference from the broken surface, however small.

Track experiments in `templates/hypothesis-ledger.md` — Symptom, Repro, Experiments (one row each), Root cause. A new hypothesis must hold against every prior row.

Done when: one hypothesis survives its falsifier and every prior ledger row.

### 5. Trace upstream

Symptom → caller → caller's caller, until a legitimate stopping point: external input (user, API, env, file, DB row) · a system boundary (network, OS, third-party lib) · "designed this way" (an intentional invariant). Stop there, not at the first place the value looks wrong.
- Multi-component failure (CI → build → signing; API → service → DB; worker → queue → store) → instrument every boundary in one pass (what enters, what exits, what env / config / state is visible), run once, read which layer fails, investigate inside it. Never guess the layer without boundary evidence.
- Two traces lead to contradictory causes → re-read; you missed an interaction.

The upstream walk step by step, or a trace that forks → `references/root-cause-tracing.md`.

Done when: the trace ends at a named stopping point, with its file:line.

### 6. Write the failing test

The test you wish had existed: red before the fix, green after. Tighten it until a one-character regression breaks it. The loop → `tdd-flow`.
No seam reaches the real bug pattern (only a shallow single-caller test fits) → that is the finding. Record it in the debug report and point the user at `/deepen-codebase`; a test at a too-shallow seam is false confidence.

Done when: the test is red on the unfixed code, or the report records why no seam can hold it.

### 7. Minimal fix

The smallest change that turns the failing test green without breaking the suite, at the root the trace found. No "while I'm here" refactor.
Same root cause across many call sites → fix the first 2 inline, then enumerate the rest with grep and dispatch ONE batch at the mechanical tier (cheap-class; the learned fix applied N times) with the 2 fixed instances as the brief's examples. Never ride the fix → check loop across the repo at Lead tier.

Done when: the failing test is green.

### 8. Verify regression-clean

- Run the module suite (the full suite on high-risk surfaces). No new red → re-run the step 2 repro itself.
- The `[DBG-]` tags grep to zero; the commit message names the hypothesis that held.
- The fix fails, or the test passes but the symptom returns → that is new evidence, not a prompt to adjust the patch. Feed it back into step 5 before any second attempt; a re-fix without a re-trace is a blind retry.
- A second failed attempt on the same surface, same signature or new → Second opinion.

Artifact: `templates/debug-report.md` — Error, Severity, Repro, Root cause, Failing test, Fix, Verification, Status.

Done when: the suite is green, the repro passes, and zero `[DBG-]` tags remain.

### 9. Second opinion

Two failed fix attempts on the same surface → stop fixing; two misses from the same mind mean the mental model is wrong.
1. Write ONE self-contained ledger file. The advisor is cold and sees only this: the symptom, the repro command, each failed fix and why it failed, the suspect code inline (never a pointer to the session).
2. Pool on → `cross-family` kind consult with the ledger — a FOREGROUND call. Pool off, no usable member, or `cross-family` absent → the Lead's own CLI at its strongest model, valid only when that model differs from the one now running. The fallback run → `references/second-opinion.md`.
3. Read the reply as a **correction** (a new hypothesis → exactly ONE advisor-informed attempt against the same repro), a **confirmation** ("approach right, check X"), or a **stop** ("wrong path").
4. Still failing, or no usable advisor → `manage-context` (escalate) with the ledger and the opinion (or "no usable advisor — <reason>") attached. The Second opinion has then run: it is never re-entered for this bug. No `manage-context` → hand the user the ledger, the opinion and 2-3 options, and stop. No further fix attempts.

Done when: the advisor-informed attempt passed, or the escalation is handed to `manage-context`.

## Guardrails

- Reproduce before you fix. Never fix what you cannot see fail.
- Fix where the bad value is born. Never add a defensive `?.` / null-check / try-catch without a known cause; one already added that way comes out, and the trace resumes.
- Get the Second opinion after two failed attempts. Never start fix #3 without its correction in hand.

Symptom-vs-root and retry-hack-vs-triaged-flake pairs → `examples/debug-examples.md`.

## Next phase

- `check-work` verifies the fix with evidence.
- If `check-work` is not available, attach the test output, the diff, and any UI / log evidence to the user response.
