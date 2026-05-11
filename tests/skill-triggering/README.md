# Skill Triggering Harness

TDD for skills. Each test case is a prompt + expected skill activation. The runner sends the prompt through the local `claude` CLI (in non-interactive `--print` mode, no preloaded skill context) and asserts that the expected skill name appears in the output — i.e. the model surfaced or invoked the skill when it should have.

## Why this exists

Skills are useless if the model doesn't reach for them at the right time. The frontmatter `description:` field is the trigger — it has to be precise enough that the model recognizes the situation. This harness gives us a regression net: if a description rewrite degrades trigger sensitivity, we catch it before merging.

Inspired by obra/superpowers `tests/skill-triggering/` + `writing-skills/testing-skills-with-subagents.md`.

## Layout

```
tests/skill-triggering/
├── README.md          (this file)
├── run.sh             (runner — bash, no Python deps)
└── cases/             (one .yml file per test case)
    ├── tdd-on-bug-fix.yml
    ├── anti-spaghetti-on-3rd-pattern.yml
    ├── doubt-on-confident-claim.yml
    ├── spec-on-new-feature.yml
    └── parallel-contract-on-two-agents.yml
```

## Case format

```yaml
name: short-slug
skill: skill-name-as-it-appears-in-frontmatter
prompt: |
  multi-line prompt that the model should react to by reaching for the skill
must_trigger: true
why: |
  one-sentence rationale — why this prompt should trigger this skill
must_not_skip_excuse: |
  the rationalization the model might use to skip (mirrors the skill's
  Common Rationalizations table); the runner asserts the output does NOT
  validate this excuse
```

## Running

```bash
bash tests/skill-triggering/run.sh
```

The runner:

1. For each `cases/*.yml` file:
   - Parses `name`, `skill`, `prompt`, `must_trigger`, `must_not_skip_excuse`
   - If `claude` CLI is unavailable on PATH → skips the case with a notice (CI does the same)
   - Sends the prompt to `claude --print` (no skill preload)
   - Captures stdout
2. Asserts on each output:
   - The skill name appears (skill was invoked or mentioned)
   - The `must_not_skip_excuse` text does NOT appear verbatim as the model's reasoning (i.e. model did not parrot the excuse to justify skipping)
3. Prints PASS/FAIL per case + a summary at the end
4. Exit code: 0 = all pass, 1 = any fail, 2 = runner error

## CI integration

`.github/workflows/installer.yml` adds a step `Skill triggering harness` that runs `bash tests/skill-triggering/run.sh` when `claude` is available. CI runners without the CLI installed will see the step skip with a notice (exit 0); this is intentional — the harness is a regression net for local development, not a hard gate.

## Adding cases

1. Pick a skill that should reliably trigger on a class of prompts
2. Write a `cases/<slug>.yml` file capturing one representative prompt
3. Run `bash run.sh` locally; if it fails, either the prompt is wrong or the skill's `description:` is not specific enough — fix one
4. Commit when green

Keep cases narrow: one skill per case, one trigger pattern per case. Broad cases hide which skill / which trigger broke.

## Caveats

- Model output is non-deterministic. The runner uses substring assertions, not full-text equality. False negatives are possible on rare phrasing variations — when one fires, re-run before declaring a regression.
- The harness only verifies **mention** of the skill, not that the model executed the skill's full procedure. Procedure correctness is verified by the skill's own use-cases and by `code-review-and-quality` review of the output.
- This is TDD-for-skills, not TDD-for-code. It catches description drift, not implementation bugs.
