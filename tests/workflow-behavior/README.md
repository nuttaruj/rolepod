# Workflow Behavior Tests

Regression net for Rolepod's workflow routing. Each case sends a prompt to the local Claude CLI (or skips cleanly when absent) and asserts which skills fire vs which forbidden phrases must NOT appear.

These are **behavior tests**, not unit tests. They prove the doc + skill + hook combination routes the way `core/skills/using-rolepod/SKILL.md` says it should.

## Layout

```
tests/workflow-behavior/
  README.md            ← this file
  run.sh               ← runner (skips if `claude` CLI missing)
  cases/               ← 10 .yml cases
    case-01-vague-feature.yml
    case-02-bug-fix.yml
    ...
```

## Case format

```yaml
name: <kebab-case identifier>
prompt: |
  <user prompt — single or multi-line>
expected_skills:
  - <skill-name-1>
  - <skill-name-2>
must_contain:           # optional — positive content assertions (questions, options, etc.)
  - "<required substring 1>"
must_not_contain:
  - "<forbidden phrase 1>"
  - "<forbidden phrase 2>"
why: |
  <one-line rationale for the assertion>
```

- **`expected_skills`**: assertion = the response or any tool-use trace mentions these skill names. Substring match, case-insensitive. Use for **routing** assertions ("did Lead pick the right skill?").
- **`must_contain`** *(optional)*: assertion = every listed substring appears in the response. Substring match, case-insensitive. Use for **behavior** assertions ("did Lead actually ask a question / present options / refuse to code?").
- **`must_not_contain`**: assertion = none of these phrases appears in the response. Substring match, case-insensitive.

`expected_skills` vs `must_contain` are both positive substring checks — the split is semantic, not technical. Routing claims go in `expected_skills`; content/behavior claims go in `must_contain`. A reader scanning a case should know at a glance what's being asserted.

## How to run

```bash
bash tests/workflow-behavior/run.sh                 # all cases
bash tests/workflow-behavior/run.sh case-01-vague-feature   # one case
```

Exit codes:
- `0` — all assertions passed OR runner skipped cleanly (no CLI)
- `1` — at least one assertion failed
- `2` — runner error (case file malformed, etc.)

## Skip behavior

The runner detects required deps and skips cleanly when missing:
- `claude` CLI on PATH — required to send prompts
- `python3` on PATH — required to parse YAML cases

A skip is **not** a failure. CI lanes that exclude `workflow-behavior` from Phase 1 are correct — these tests need a real model call, which CI may not budget.

## Caveats

- Model variance: the runner uses substring assertions, not exact-text, so phrasing drift doesn't cause flakes.
- Multiple valid routes: when more than one skill chain is acceptable (e.g. a refactor task may legitimately route through `code-simplification` OR `code-review-and-quality`), list both in `expected_skills` and update the runner to accept ANY match.
- Logs: each run saves a per-case log under `/tmp/rolepod-workflow-behavior-<timestamp>/` for inspection.

## When to add a case

Add a case whenever:
1. A real-world Lead session showed the wrong skill firing → encode the right behavior.
2. A new Tier 1 skill is added.
3. A hard rule moved from "doctrine" to "structural" (gate becomes a hook).

Cases are cheap. False-negative test = wasted seconds. False-positive failure = bug caught before users see it.
