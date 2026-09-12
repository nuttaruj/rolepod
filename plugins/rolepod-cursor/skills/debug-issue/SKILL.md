---
name: debug-issue
description: Use when something is broken — error appears, test fails, build breaks, output is wrong, regression returns. Reproduce, trace upstream to root cause, write a failing test, ship a minimal fix. Phase = Build / Debug.
---

# Debug Issue

Replace guess-and-check with disciplined narrowing: reproduce → trace upstream to root → failing test → minimal fix → verify regression-clean.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER fix before reproducing with a deterministic command. No repro = guess.
2. NEVER stop at the first symptom fix. Trace upstream to a legitimate stopping point (external input, system boundary, "designed this way"), then fix at root.
3. ALWAYS roll back your last action first (your own diff, reversible undos only) when the error appeared right after your change.
4. ALWAYS write the failing test you wish had existed before shipping the fix.
5. After 2 failed fix attempts on the same surface, STOP fixing — get one cross-model opinion (§9). Its correction is the outside review that permits exactly ONE more attempt; fix #3 without it = thrashing.
</EXTREMELY-IMPORTANT>

## When to use

- Green → red · unrecognized error · wrong output with no exception · build broke after a change · works locally, fails in CI (or the reverse) · two fixes did not stick · the symptom returns at a different surface · about to add a defensive `?.` / null-check / try-catch without knowing why.

## Boundary

Owns: unknown-failure triage — reproduce, trace upstream, root cause, failing regression test, minimal fix.

Does not own: planned feature work · broad refactor · the shipping decision.

Hand off:
- Requirements unclear → `write-spec`. Fix spans files / needs sequencing → `write-plan`.
- **Report-only (QA hand-off)** — the user wants the bug documented, not fixed → stop after §2; trace §5 only when cheap. Fill the debug report with repro + severity + evidence, leave Failing test / Fix empty, hand to the owning dev.
- Minimal fix applied → `check-work`.
- 2 failed attempts → §9 consult first, then `manage-context` (escalate) with the opinion attached.

## Workflow

Inputs: the exact error (literal quote) · throw site (file:line) + stack · when it started failing (last green commit, deploy, data event) · repro steps or the failing test command · the diff since last green.

### 1. Stop and read

Capture the exact error, the throw site, and the stack before editing. The real cause is often mid-stack, not at the top.

### 2. Reproduce reliably

One command, same failure every time — `pytest path/test_x.py::name -v`, the exact failing `curl`, or UI steps + browser + console. Intermittent → raise the rate first (loop the trigger, add stress, inject sleeps) until you have a 50%+ signal; a 1% flake is not yet debuggable (`references/flake-triage.md`). Cannot repro locally → reproduce in CI / staging. Do not fix what you cannot see fail.

**UI / browser bugs — backend order:** (1) `rolepod-uiproof` when installed: `/check-errors` returns console + network failures during the flow, `/verify-ui` returns minimized repro steps + artifacts — reuse those steps in §6; (2) Playwright MCP when connected — atomic `browser_*` calls, minimize the sequence yourself; (3) Chrome DevTools MCP when connected (Chromium only) for bugs whose cause sits below the rendered DOM; (4) manual — describe the candidate repro and ask the user to confirm it.

**WordPress runtime / plugin / theme bugs:** `rolepod-wplab` `/wp-diagnose` when installed (error log, hook trace, query log — WP findings only; the debug flow stays here); otherwise `wp-cli` or `wp-content/debug.log`.

The marker `<git-root>/.rolepod/parent-active` confirms the protocol is live; with it, children write evidence under `<git-root>/.rolepod/evidence/` → reference those artifacts in the hypothesis ledger and the fix. No marker → evidence in that directory is stale or from another task; verify before trusting it.

### 3. Rollback reflex

Bug appeared right after your change → undo first, confirm green, re-apply piece by piece. Bug predates your changes and the last-good commit is unknown → `git bisect run <test>`.

### 4. One hypothesis at a time

2+ plausible causes → list 2-3 candidates with the cheapest falsifier per row and run the top one yourself — a falsifier is a reversible act, not a user call. State the chosen hypothesis as `<variable / state / condition> is <value> because <upstream cause>`. Cheapest falsifier first: log, breakpoint, read the called function, check the fixture. Don't spray fixes. Tag debug logs with a unique prefix (`[DBG-a4f2]`) so cleanup is one grep.

**Find a working analog.** Locate code in the same codebase that does the similar thing successfully (adjacent feature, sibling endpoint, parallel module) and list every difference from the broken surface, however small. Cheap signal for which difference matters.

Track experiments in `templates/hypothesis-ledger.md` — one row each; a new hypothesis must hold against every prior row.

### 5. Trace upstream

Symptom → caller → caller's caller, until: external input (user, API, env, file, DB row) · system boundary (network, OS, third-party lib) · "designed this way" (intentional invariant). Stop there, not at the first place the value looks wrong (`references/root-cause-tracing.md`).

**Multi-component → instrument boundaries first.** Failure crosses layers (CI → build → signing; API → service → DB; worker → queue → store) → add boundary logging at every layer in one pass (what enters, what exits, what env / config / state is visible), run once, read which layer fails, investigate inside it. Guessing the layer without boundary evidence wastes hypotheses.

### 6. Write the failing test

The test you wish had existed. Fails before the fix, passes after. Tighten until a one-character regression would break it.

### 7. Minimal fix

Smallest change that turns the failing test green without breaking the suite. No "while I'm here" refactor.

Same root cause across many call sites → fix the first 2 inline, then using-rolepod's **2-strike convergence**: enumerate the rest with grep, dispatch ONE batch at the mechanical tier (cheap-class — the learned fix applied N times) with the 2 fixed instances as the brief's examples. Don't ride the fix → check loop across the repo at Lead tier.

### 8. Verify regression-clean

Run the module suite (full suite on high-risk surfaces). No new red → re-run the §2 repro itself.

**The fix fails → new evidence, not a prompt to adjust the patch.** Feed it back into §5 before any second attempt — the root may be wrong or partial; a re-fix without a re-trace is a blind retry. A second failure, same signature or new → §9: two misses from the same mind mean the mental model is wrong.

### 9. Second failed attempt — one cross-model opinion, then the user

1. Write ONE self-contained ledger file — the advisor is cold and sees only this: symptom, repro command, each failed fix and why it failed, the suspect code inline (never a pointer to the session).
2. `rolepod-cross-family --kind consult --brief <ledger>` (plugin tree: `scripts/cross-family.sh`; add `--lead <cli>` outside Claude).
   - The pool is the user's opt-in (`.rolepod/cross-family` → `~/.rolepod/cross-family`; no file or `none` = off — never enable it unasked).
   - Consult is a FOREGROUND call with a short per-member budget — a stuck loop needs the answer now, so a `consult: <fast cli> <deep cli>` order line in the config puts the fast member first and leaves the slow deep one as fallback.
   - The runner takes the first usable member that is not the Lead's own CLI, read-only, on that CLI's default model, clean room (`ROLEPOD_BRAIN_SILENT=1`), and anchors the reply under `.rolepod/evidence/external/`; a failed member is logged and the next runs.
   - Pool off (`none`, or no file) or no usable member → **vertical fallback**: the Lead's own CLI at its strongest model. A native advisor mode, when the CLI has one, IS this channel. Otherwise ask the CLI which models it exposes (its own `--help`), pick the top tier by name, and run that CLI headless on the same ledger file (`<cli> -p --model <name>` / `<cli> exec -m <name>`). Valid only when that model differs from the one now running; already on it, or cannot tell → step 4.
3. Read the reply as **correction** (new hypothesis → exactly ONE advisor-informed attempt against the same repro — the outside review Iron Rule 5 requires), **confirmation** ("approach right, check X"), or **stop** ("wrong path").
4. Still failing, or no usable advisor → `manage-context` (escalate): ledger + the opinion (or "no usable advisor — <reason>") attached. No further fix attempts.

## If a matching Rolepod agent is available

Delegate the loop — iteration is the costliest work to run in the Lead's context:
- `qa-tester` — default for any bug without a specialist match
- `security-engineer` — auth / token / injection symptoms
- `performance-engineer` — latency / memory regressions
- `devops-sre` — infra / deploy / CI failures

Brief: exact error, stack, repro command, hypothesis, files touched since last green.

## If no matching agent is available

Execute as Lead: capture error + stack → one deterministic repro → roll back if the timing matches → one hypothesis at a time → trace upstream to a stopping point → failing test → smallest fix → full touched suite green.

## Output

The debug report is the canonical artifact: `templates/debug-report.md` — error, repro, root cause, failing test, fix, verification.

## References

Load only when needed:
- `references/root-cause-tracing.md` — the upstream walk: trace a bad value to where it is born.
- `references/flake-triage.md` — diagnose an intermittent test instead of retrying it.
- `examples/debug-examples.md` — symptom-vs-root fix and retry-hack-vs-triaged flake, good/bad pairs.

## Hard stops

- Cannot reproduce after 30 minutes → escalate or expand the repro environment.
- Two upstream traces lead to contradictory causes → re-read; you missed an interaction.
- Fix passes the test but the symptom returns → root cause is wrong, trace further.
- Defensive null-check without a known cause → not a fix; remove and trace again.
- Fix attempt #3 about to start without a §9 correction in hand → stop; Iron Rule 5.
- Multi-component failure being guessed at without boundary instrumentation → instrument first (§5).

## Next phase

- `check-work` verifies the fix with evidence.
- If `check-work` is not available, attach the test output, the diff, and any UI / log evidence to the user response.
