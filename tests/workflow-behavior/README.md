# Workflow Behavior Tests

Regression net for Rolepod's workflow routing. Each case sends a prompt to the local Claude CLI (or skips cleanly when absent) and asserts which skills fire vs which forbidden phrases must NOT appear.

These are **behavior tests**, not unit tests. They prove the doc + skill + hook combination routes the way `core/skills/using-rolepod/SKILL.md` says it should.

## Two execution modes

### Contract mode (release gate)

Prepends a routing-test harness to every case prompt:

```
You are responding to a Rolepod routing test.

STRICT RULES — do not violate any:
- Do NOT edit any file.
- Do NOT create any file.
- Do NOT run shell commands, Bash, Edit, Write, MultiEdit, Read, or any tool.
- Do NOT spawn subagents.
- Do NOT ask clarifying questions.

Your only task: identify which Rolepod skill should fire for the user prompt
below, and answer in exactly this format (four lines, no extra prose):

Routing: <phase> -> <skill-name>
Reason: <one sentence on why this skill fires>
Skipping: <one sentence — name any skipped phase + why, or none>
Next step: <one sentence — which skill or hand-off comes next>

---USER-PROMPT-START---
<raw case prompt>
---USER-PROMPT-END---
```

Contract mode asserts only the routing decision (`expected_skills` appear in the response). `must_contain` / `must_not_contain` are skipped — under the harness the model never produces dialogue or implementation prose. **Failure exits non-zero — release gate.**

### Organic mode (advisory)

Sends the raw user prompt as-is, no harness. Asserts the full case (`expected_skills` + `must_contain` + `must_not_contain`). Records whether Lead naturally follows Rolepod without coaching. **Failure does NOT fail `make test` — exit always 0.**

Use organic failures to decide whether to strengthen always-on entry instructions in `CLAUDE.md` / `AGENTS.md` / `GEMINI.md`.

## Layout

```
tests/workflow-behavior/
  README.md            ← this file
  run.sh               ← runner (2 modes, skips if `claude` CLI missing)
  parse_case.py        ← YAML parser + assertion helper
  cases/               ← 14 .yml cases
    case-01-vague-feature.yml
    case-02-bug-fix.yml
    ...
    case-14-review-request.yml
```

## Case format

```yaml
name: <kebab-case identifier>
prompt: |
  <user prompt — single or multi-line>
expected_skills:
  - <skill-name-1>
  - <skill-name-2>
must_contain:           # optional — positive content assertions (organic mode only)
  - "<required substring 1>"
must_not_contain:
  - "<forbidden phrase 1>"
  - "<forbidden phrase 2>"
why: |
  <one-line rationale for the assertion>
```

- **`expected_skills`** — substring match, case-insensitive. Used in BOTH modes. Routing assertion: "did Lead pick the right skill?"
- **`must_contain`** — substring match, case-insensitive. ORGANIC mode only. Behavior assertion: "did Lead ask a question / present options / refuse to code?" Contract mode skips because the harness response never produces dialogue.
- **`must_not_contain`** — substring match, case-insensitive. ORGANIC mode only. Blocks rubber-stamping / premature code / skipped gate phrases.

## How to run

```bash
# Skip-clean (no live model calls — default in `make test`):
bash tests/workflow-behavior/run.sh
make test-workflow

# Contract mode — release gate (required green for merge):
ROLEPOD_RUN_LIVE=1 bash tests/workflow-behavior/run.sh --mode=contract
make test-workflow-contract

# Organic mode — advisory (failures don't fail the gate):
ROLEPOD_RUN_LIVE=1 bash tests/workflow-behavior/run.sh --mode=organic
make test-workflow-organic

# Both modes — contract first (gates merge), organic second (reports drift):
ROLEPOD_RUN_LIVE=1 bash tests/workflow-behavior/run.sh --mode=both
make test-workflow-live

# Single case:
ROLEPOD_RUN_LIVE=1 bash tests/workflow-behavior/run.sh --mode=contract case-02-bug-fix
```

Exit codes:
- `0` — contract green (organic advisory may still report drift) OR runner skipped cleanly
- `1` — contract failed (release gate)
- `2` — runner error (case file malformed, missing dep, bad flag)

## Skip behavior

The runner detects required deps and skips cleanly when missing:
- `ROLEPOD_RUN_LIVE=1` opt-in flag — without it, the runner reports case count and exits 0
- `claude` CLI on PATH — required to send prompts
- `python3` on PATH — required to parse YAML cases

A skip is **not** a failure. CI lanes that exclude `workflow-behavior` from Phase 1 are correct — these tests need a real model call, which CI may not budget.

## Per-case timeout

Default 60s per case. Override with `ROLEPOD_CASE_TIMEOUT=N`. Uses `timeout` / `gtimeout` / `perl` (whichever is on PATH); falls back to no-timeout when none available (Claude CLI's `--max-turns 2` cap still applies).

## Logs

Per-run log directory: `/tmp/rolepod-workflow-behavior-<timestamp>/`. Each case produces:

```
<case>.<mode>.prompt.txt     — exact prompt sent (harness-wrapped in contract mode)
<case>.<mode>.response.txt   — claude CLI output
<case>.<mode>.assert.err     — assertion helper stderr (if any)
<case>.<mode>.parse.err      — parser stderr (if any)
```

## Caveats

- Model variance: the runner uses substring assertions, not exact-text, so phrasing drift doesn't cause flakes.
- Contract mode is the authoritative regression net for routing. Organic mode is the early-warning that always-on instructions need tightening.
- Multiple valid routes: when more than one skill chain is acceptable, list all candidates in `expected_skills` — substring match means any-of passes.

## When to add a case

Add a case whenever:
1. A real-world Lead session showed the wrong skill firing → encode the right behavior.
2. A new Tier 1 skill is added.
3. A hard rule moved from "doctrine" to "structural" (gate becomes a hook).

Cases are cheap. False-negative test = wasted seconds. False-positive failure = bug caught before users see it.
