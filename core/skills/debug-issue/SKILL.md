---
name: debug-issue
description: Use when something is broken — error appears, test fails, build breaks, output is wrong, regression returns. Reproduce, trace upstream to root cause, write a failing test, ship a minimal fix. Phase = Build / Debug.
when_to_use: when an error appears, a test that was green is red, a build broke, output is wrong, something worked before and stopped, the same bug keeps recurring, or a fix made one error vanish while a similar one appeared nearby
tier: 1
phase: build
---

# Debug Issue

Canonical debug workflow. Replace guess-and-check with disciplined narrowing: reproduce → trace upstream to root → write failing test → minimal fix → verify regression-clean.

## Iron Rule

<EXTREMELY-IMPORTANT>
1. NEVER fix before reproducing locally with a deterministic command. No repro = guess.
2. NEVER stop at the first symptom fix. Trace upstream to a legitimate stopping point (external input, system boundary, "designed this way"), then fix at root.
3. ALWAYS roll back your last action first when the error appeared right after your change.
4. ALWAYS write the failing test you wish had existed before shipping the fix.
5. After 3 failed fix attempts on the same surface, STOP fixing — get one cross-model opinion (§9). Its correction is the outside review that permits exactly ONE more attempt; fix #4 without it = thrashing.
</EXTREMELY-IMPORTANT>

## When to use

- Test was green, now red
- Unrecognized error / unfamiliar stack
- Wrong output, no exception thrown
- Build broke after a change
- Works locally, fails in CI (or the reverse)
- Two fix attempts did not stick
- Symptom keeps returning at a different surface
- About to add defensive `?.` / null-check / try-catch without knowing why

## Boundary

Owns:
- Unknown failure triage: reproduce, trace upstream, identify root cause, write a failing regression test, minimal fix.

Does not own:
- Planned feature work with known requirements.
- Broad refactor / simplification.
- Shipping decision.

Return / hand off:
- Requirements unclear → `write-spec`.
- Fix spans multiple files / needs sequencing → `write-plan`.
- Minimal fix applied → `check-work`.
- Stuck — 3 failed fix attempts on the same target → §9 cross-model consult first, then `manage-context` (escalate mode) with the opinion attached.

## Inputs to gather

- Exact error message (literal quote)
- Throw site (file:line) and stack trace
- When it started failing (last green commit, deploy, data event)
- Steps to reproduce or the failing test command
- The diff since last green

## Workflow

### 1. Stop and read

Capture the exact error, the throw site, and the stack trace before editing. The real cause is often mid-stack, not at the top.

### 2. Reproduce reliably

One command, same failure every time. Pytest: `pytest path/test_x.py::name -v`. API: exact failing `curl`. UI: steps + browser + console. Intermittent: raise the rate first — loop the trigger, add stress, inject sleeps — until you have a 50%+ signal. A 1% flake is not yet debuggable. For the flake cause decision tree, see `references/flake-triage.md`.

If you cannot repro locally, reproduce in CI / staging. Do not fix what you cannot see fail.

**For UI / browser bugs, pick a backend (preferred → fallback):**

1. **rolepod-uiproof** — if the `/verify-ui` or `/check-errors` skill is available, invoke it with the candidate steps and the bug-surface assertions. `/check-errors` returns console + network failures during the flow; `/verify-ui` returns minimized repro steps + artifacts (screenshots, HAR, console). Use those steps in your failing test (step 6).
2. **Playwright MCP** — orchestrate atomic `browser_*` calls to reproduce; minimize the step sequence yourself.
3. **Chrome DevTools MCP** — if the `chrome-devtools-mcp` server is registered, orchestrate atomic calls (Chromium only); CDP-level access gives sharper console / network / perf signal for UI bugs whose cause sits below the rendered DOM. https://github.com/ChromeDevTools/chrome-devtools-mcp
4. **Manual** — describe the candidate repro to the user and ask them to confirm. Capture the steps they confirm.

**For WordPress runtime / plugin / theme bugs:**

- **rolepod-wplab** — if the `/wp-diagnose` skill is available, invoke it for WP-specific tracing (error log, hook trace, query log). It returns WP-runtime findings only; the surrounding debug flow (reproduce → root cause → failing test → fix) stays in this skill. Without `rolepod-wplab`, fall back to `wp-cli` directly or read `wp-content/debug.log`.

When children write evidence under `<git-root>/.rolepod/evidence/` (Extension Protocol v1), reference those artifacts in your hypothesis-ledger and final fix. The marker `<git-root>/.rolepod/parent-active` confirms the protocol is active.

### 3. Rollback reflex

If the bug appeared right after your change, undo first. Confirm green. Re-apply piece by piece.

If the bug predates your changes and the last-good commit is unknown, `git bisect run <test>` finds the breaking commit automatically.

### 4. One hypothesis at a time

When 2+ plausible causes exist, list 2-3 candidates with the cheapest falsifier per row, recommend which to test first, and let the user pick if the choice is non-obvious. Then state the chosen hypothesis: `<variable / state / condition> is <value> because <upstream cause>`. Test the cheapest falsifier first — log, breakpoint, read the called function, check the fixture. Don't spray fixes. Tag every debug log with a unique prefix (`[DBG-a4f2]`) so cleanup is one grep.

**Find a working analog.** Before testing hypotheses, locate code in the same codebase that does the similar thing successfully — adjacent feature, sibling endpoint, parallel module. List every difference between the working analog and the broken surface, however small. Cheap signal for which difference matters; expensive to skip when "that can't possibly matter" turns out to matter.

Track experiments in `templates/hypothesis-ledger.md` — one row each. A new hypothesis must hold against every prior row, not just the last run.

### 5. Trace upstream

Symptom → caller → caller's caller, until one of:
- External input (user, API, env, file, DB row)
- System boundary (network, OS, third-party lib)
- "Designed this way" (intentional invariant)

Stop at one of those, not at the first place the value looks wrong. For the upstream-walk technique and the symptom-vs-root distinction, see `references/root-cause-tracing.md`.

**Multi-component? Instrument boundaries first.** When the failure crosses layers (CI → build → signing, or API → service → DB, or worker → queue → store), add boundary logging at every layer in one pass — what data enters, what exits, what env / config / state is visible. Run once. The log reveals **which layer fails**. Pick the failing layer; investigate inside it. Guessing which layer without boundary evidence wastes hypotheses.

### 6. Write the failing test

The test you wish had existed. It must fail before your fix and pass after. Tighten until a one-character regression would break it.

### 7. Minimal fix

Smallest change that turns the failing test green without breaking the rest of the suite. No "while I'm here" refactor.

### 8. Verify regression-clean

Run the full module suite (or full suite for high-risk surfaces). Confirm no new red.

### 9. Third failed attempt — one cross-model opinion, then the user

Three failed fixes = proven hard-to-resolve. Get ONE outside opinion automatically (no opt-in needed) before escalating. Do these steps in order:

1. List the installed externals NOT in the Lead's model family — detect with `command -v codex`, `command -v claude`, `command -v gemini`, `command -v agy` — in this order: `codex exec` / `claude -p` / `gemini -m pro -p` (or `agy -p` when only agy exists; gemini ≡ agy — same family as a Gemini/agy Lead). Take the first. Empty list (single-family machine) → **vertical fallback**: the advisor is the Lead's own CLI at its strongest model — ask the CLI which models it exposes (`claude --help` / `codex --help`; pick the top tier by name), then invoke `claude -p --model <that name>` / `codex exec -m <that name>` / `gemini -m pro -p`. Only valid when that model differs from the one now running; already on it, or cannot tell which model is running → step 4.
2. Write ONE self-contained prompt to a file — the advisor is cold; it sees only this: the symptom, the repro command, the 3 failed fix attempts with why each failed, and the suspect code inline. Invoke by substituting the file — never hand-type code into the argument: `codex exec "$(cat /tmp/consult.md)"` (same pattern for `claude -p` / `gemini -m pro -p`).
3. Read the reply as one of: **correction** (new hypothesis → run exactly ONE advisor-informed fix attempt against the same repro — this consult is the outside review Iron Rule 5 requires), **confirmation** ("approach right, check X"), or **stop** ("wrong path"). Invoke failed (auth / quota / empty output)? Retry once; still failing → cross that CLI off and take the NEXT one from step 1's list; list exhausted → step 1's vertical fallback, reading its reply per this step (a vertical correction unlocks the same single attempt); vertical unavailable or failed too → step 4.
4. Still failing, or no usable advisor → escalate via `manage-context` (escalate mode): hypothesis ledger + the advisor's opinion (or "no usable advisor — <reason>") attached. Start no further fix attempts.

## If a matching Rolepod agent is available

Delegate to the closest specialist:

- `qa-tester` for failing-test design and flake analysis
- `security-engineer` if the symptom is auth / token / injection
- `performance-engineer` for latency / memory regressions
- `devops-sre` for infra / deploy / CI failures

Brief: exact error, stack, repro command, hypothesis, files touched since last green.

## If no matching agent is available

Execute as Lead with this minimum viable checklist:

1. Capture the exact error and stack
2. Reproduce with one deterministic command
3. Roll back the last change if the timing matches
4. State one hypothesis at a time
5. Trace upstream until a legitimate stopping point
6. Write a failing test that captures the bug
7. Make the smallest fix that turns it green
8. Run the full touched suite to confirm no regression

## Output

The debug report is the canonical artifact: `templates/debug-report.md`. It carries the error, repro, root cause, the failing test, the fix, and verification. Do not restate the report shape here; the template is the single source.

## Examples

Non-blocking — read only when unsure whether a fix reaches the root:
- `examples/debug-examples.md` — a symptom-vs-root fix and a retry-hack-vs-triaged flake fix, each a good/bad pair with a "why good wins" table. Read the whole file; the contrast is the lesson.

## References

Load only when the task needs it:
- `references/root-cause-tracing.md` — the upstream walk: trace a bad value to where it is born
- `references/flake-triage.md` — diagnose an intermittent test instead of retrying it

## Hard stops

- Cannot reproduce after 30 minutes → escalate or expand repro environment
- Two upstream traces lead to contradictory causes → re-read; you missed an interaction
- Fix passes the test but the symptom returns → root cause is wrong, trace further
- Defensive null-check without a known cause → not a fix; remove and trace again
- Fix attempt #4 about to start without a §9 cross-model correction in hand → stop; Iron Rule 5
- Multi-component failure being guessed at without boundary instrumentation → stop, instrument first (§5)

## Full Rolepod enhancement

Full Rolepod improves this phase by adding the qa-tester floor for test depth, hooks that flag silenced exceptions, and the adversarial reviewer pattern for fixes on high-risk surfaces.

## Next phase

- If `check-work` is available, continue there to verify the fix with evidence.
- If `check-work` is not available, attach the test command output, the diff, and any UI / log evidence directly to the user response.
