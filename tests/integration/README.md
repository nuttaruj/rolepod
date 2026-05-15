# Integration Tests

Slow, local-only tests that prove end-to-end Rolepod behavior on real fixtures.

These are **NOT** required for CI Phase 1. Run locally before release or when changing installer / hook / multi-CLI surface.

## Layout

```
tests/integration/
  README.md            ← this file
  run.sh               ← runner (skips per-case if deps missing)
  cases/
    install-parity.sh         ← Claude/Codex/Gemini × global/project install behavior
    bug-fix-workflow.sh       ← stub: small failing-test fixture + systematic-debugging
    feature-from-spec.sh      ← stub: spec → plan → TDD → verify
    subagent-review-order.sh  ← stub: implementer → spec-review → code-quality-review
```

## How to run

```bash
bash tests/integration/run.sh                # all cases
bash tests/integration/run.sh install-parity # one case
```

Exit codes:
- `0` — all cases passed or skipped cleanly
- `1` — at least one case failed
- `2` — runner error

## Required deps (per case)

| Case | Required CLIs | Optional |
|---|---|---|
| `install-parity` | none (uses local `./install.sh`) | `codex`, `gemini` for full coverage |
| `bug-fix-workflow` | `claude` + Node or Python toolchain | — |
| `feature-from-spec` | `claude` | — |
| `subagent-review-order` | `claude` | — |

Cases self-skip when their required deps are absent.

## Why "stub" cases

`bug-fix-workflow`, `feature-from-spec`, `subagent-review-order` need real Claude CLI invocations against fixture projects. The runner provides structure; fixtures + scripts are ready for implementation when:

1. The behavior-test runner (`tests/workflow-behavior/`) proves routing works.
2. A clear pass/fail metric exists for each integration case (not just "Claude responded").

Until then, the stubs print a clear "not implemented yet — describe expected behavior" message and exit 0 (skip).

## Workflow

When integrating a new fixture:

1. Write the fixture project under `tests/integration/fixtures/<case-name>/`.
2. Replace the stub script with the real assertion script.
3. Document expected behavior in the script header.
4. Run locally; commit fixture + script together.
