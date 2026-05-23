# Integration Tests

Slow, local-only tests that prove end-to-end Rolepod behavior on real fixtures.

These are **NOT** required for CI Phase 1. Run locally before release or when changing installer / hook / multi-CLI surface.

## Layout

```
tests/integration/
  README.md            ← this file
  run.sh               ← runner (skips per-case if deps missing)
  cases/
    install-parity.sh         ← Claude/Codex/Gemini/Cursor × global/project install behavior
    bug-fix-workflow.sh       ← debug-issue → check-work wiring
    feature-from-spec.sh      ← write-spec → write-plan → implement-plan → check-work wiring
    subagent-review-order.sh  ← implementer → spec-compliance → code-quality review order
    high-risk-gates.sh        ← auth/billing/migration → review-code + security-engineer
    multi-agent-contract.sh   ← cohesion-contract gate before 2nd parallel agent spawn
    ship-gate.sh              ← finish-work as final Ship phase + S+T+F+P gates
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
| `high-risk-gates` | none | Structural grep over `review-code` + high-risk hooks |
| `multi-agent-contract` | none | Structural grep + hook script presence check |
| `ship-gate` | none | Structural grep over `finish-work` skill body |

All cases run without live CLIs by design — they assert **wiring** (skill bodies say the right thing, router rows exist, hook scripts present).

## Why structural (and not live `claude -p`)

Rolepod targets interactive Claude Code sessions (Define → Plan → Build → Verify → Review → Ship multi-turn). `claude -p` is headless single-turn — used for Q&A and one-shot scripts, not workflow sessions. Testing routing through `-p` is testing the wrong shape: it cannot exercise phase progression, hook firing, or agent escalation.

Structural tests catch the relevant doctrine drift cheaply: if a skill body stops saying "reproduce first" or the router stops pointing `fix bug` at `debug-issue`, the wiring test fails. Real-world workflow behavior is verified by using Rolepod for actual work, not by `-p` smoke runs.

Live invocations also slow (~10-30s each), nondeterministic (model variance), and depend on a working `claude -p` install — and prove nothing the static + integration gate cannot already prove.

## Workflow

When adding a new integration case:

1. Add `tests/integration/cases/<name>.sh`; runner picks it up automatically.
2. Assert wiring with `grep` over skill bodies, router, hook scripts, or installer output.
3. Document expected behavior in the script header.
4. Run locally; commit the script.
