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
    bug-fix-workflow.sh       ← systematic-debugging → TDD → post-change-verify wiring
    feature-from-spec.sh      ← spec-driven → planning → TDD → verify wiring
    subagent-review-order.sh  ← implementer → spec-compliance → code-quality review order
    high-risk-gates.sh        ← auth/billing/migration → security-engineer + reviewer-flow
    multi-agent-contract.sh   ← cohesion-contract gate before 2nd parallel agent spawn
    ship-gate.sh              ← pre-merge-gate as final Ship phase + S+T+F+P gates
```

Current state: **7 cases, all pass structurally** (no live `claude -p` calls — fast, deterministic, run in ~3-5s).

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

| Case | Required CLIs | Notes |
|---|---|---|
| `install-parity` | none (uses local `./install.sh`) | `codex` + `gemini` only needed for adapter coverage; otherwise self-skips that segment |
| `bug-fix-workflow` | none | Structural grep over skill bodies — no CLI |
| `feature-from-spec` | none | Structural grep over skill bodies — no CLI |
| `subagent-review-order` | none | Structural grep — skill body + template prompts |
| `high-risk-gates` | none | Structural grep over `team-routing` + `reviewer-flow` |
| `multi-agent-contract` | none | Structural grep + hook script presence check |
| `ship-gate` | none | Structural grep over `pre-merge-gate` skill body |

All cases run without live CLIs by design — they assert **wiring** (skill bodies say the right thing, router rows exist, hook scripts present). Live-behavior assertions (does Lead actually reproduce-before-patching, does Phase 0 dialogue actually ask before drafting) live in `tests/workflow-behavior/` and are gated by `ROLEPOD_RUN_LIVE=1` + an installed Claude CLI.

## Why structural (and not live)

Live invocations are slow (~10-30s each), nondeterministic (model variance), and depend on a working `claude -p` install. Structural tests catch ~80% of doctrine drift in <5 seconds: if a skill body stops saying "reproduce first" or the router stops pointing `fix bug` at `systematic-debugging`, the wiring test fails. Live tests then cover the remaining 20% (the agent actually behaves the way the skill body says).

## Workflow

When adding a new integration case:

1. Decide: structural (grep skill bodies / file presence) or live (Claude CLI invocation).
2. Structural → add `tests/integration/cases/<name>.sh`; runner picks it up automatically.
3. Live → add to `tests/workflow-behavior/cases/<name>.yml`; gate via `ROLEPOD_RUN_LIVE=1`.
4. Document expected behavior in the script header.
5. Run locally; commit script (and fixture, if any) together.
