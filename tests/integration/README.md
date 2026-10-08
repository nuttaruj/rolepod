# Integration Tests

Slow, local-only tests that prove end-to-end Rolepod behavior on real fixtures — real hooks, real renders, real repos, never a mock of the thing under test.

These are **NOT** required for CI Phase 1. Run locally before release or when changing installer / hook / multi-CLI surface.

## Layout

```
tests/integration/
  README.md            ← this file
  run.sh               ← runner (skips per-case if deps missing)
  cases/
    antigravity-adapter.sh      ← agy plugin hook contract, structural + behavioral
    bootstrap.sh                ← curl-bash front door: DEST, reuse, no rm -rf
    codex-agent-sync.sh         ← Codex SessionStart agent sync (fresh / upgrade / off / locks)
    contract-snapshot.sh        ← scripts/contract-snapshot.sh verdict contract
    doctor-codex.sh             ← scripts/doctor_codex.py report lines from a throwaway HOME
    cross-family-runner.sh      ← the runner against stub CLIs: pool, config, timeout, stall, jobs
    cursor-adapter.sh           ← Cursor plugin hook contract, structural + behavioral
    evidence-tools.sh           ← stats.sh, context-bloat note
    hook-behavior.sh            ← every Claude hook's stdin → stdout/exit behavior, 35 sections
    install-parity.sh           ← install.sh per CLI × scope into temp targets
    opencode-adapter.sh         ← opencode plugin render + gate behavior (v1 + v2)
    parent-active-marker.sh     ← .rolepod/parent-active write (child-plugin protocol)
    plan-lint.sh                ← scripts/plan-lint.sh: dirty/clean plans, Blocked-by graph, --brief
    test-diff-lint.sh           ← hooks/test-diff-lint.sh detectors on a synthetic staged diff
    ticket.sh                   ← implement-plan's scripts/ticket.sh: start / integrate / finish / log / status
```

## How to run

```bash
bash tests/integration/run.sh                 # all cases
bash tests/integration/run.sh install-parity  # one case
```

For a slow case file (`hook-behavior.sh`, `cross-family-runner.sh`) that groups its checks under `── banner ──` section markers (each printed by the file's own `section()` helper), `ROLEPOD_CASE=<regex>` runs only the sections whose banner matches — seconds instead of minutes while editing the hook or script the section covers; without the variable every section runs — the same checks, plus one tally line (`N of M sections ran`):

```bash
ROLEPOD_CASE='cross-family: config' bash tests/integration/cases/cross-family-runner.sh
```

A filter that matches no section banner (a typo'd regex) makes the file fail with a `✗` line naming the filter, instead of silently exiting 0 with "0 of N sections ran".

Exit codes:
- `0` — all cases passed or skipped cleanly
- `1` — at least one case failed
- `2` — runner error

## Required deps (per case)

| Case | Required CLIs | Notes |
|---|---|---|
| `antigravity-adapter` | none (`agy` optional) | Renders the target and runs the hooks against agy-shaped stdin; `agy plugin validate` runs live only if `agy` is on PATH |
| `bootstrap` | none | Hermetic — runs against temp targets only |
| `codex-agent-sync` | none | Sandboxed HOME/CODEX_HOME; the real `~/.codex` is never touched |
| `contract-snapshot` | none | Fixture-driven, no installed CLI needed |
| `doctor-codex` | `python3` >= 3.11 (tomllib; self-skips below) | Throwaway HOME + stub `codex` binaries; the real `~/.codex` is never touched |
| `cross-family-runner` | none (stub CLIs on PATH) | Exercises the runner against scripted stub members |
| `cursor-adapter` | none | Renders the Cursor plugin and runs its hooks against Cursor-shaped stdin |
| `evidence-tools` | none | Fixture transcripts; no live CLI |
| `hook-behavior` | none | Runs every hook directly against synthetic stdin in a throwaway repo |
| `install-parity` | none (`codex` optional) | Uses local `./install.sh` into temp targets; missing CLIs self-skip that segment |
| `opencode-adapter` | `node` optional | Structural checks run without it; gate-behavior checks need `node` |
| `parent-active-marker` | none | Fresh repo + session-lifecycle.sh --lock (the loader writes no lock/marker) |
| `plan-lint` | none | Fixture plans against write-plan's `scripts/plan-lint.sh` |
| `test-diff-lint` | none | Fixture diffs against `hooks/test-diff-lint.sh` |
| `ticket` | none | Fixture repos against implement-plan's `scripts/ticket.sh` |

## What a case proves (the seam rule)

Every case runs the real script or hook — never a copy of its logic pasted into the test — against its real stdin/argv/env shape, and asserts on its real exit code, stdout, or file output. A case that greps the hook's *source* for a string, or re-implements the hook's logic to check it against itself, proves nothing about behavior; if the source changes wording without changing behavior, that kind of check goes red for no reason (or worse, stays green through a real regression). When a rule already has a behavioral owner elsewhere (the hook that runs it, the static test that owns the classifier), a case defers to that owner instead of re-asserting the same fact as a source grep.

## Workflow

When adding a new integration case:

1. Add `tests/integration/cases/<name>.sh`; runner picks it up automatically.
2. Assert behavior: run the real script/hook against real stdin/argv, assert its exit code / stdout / file output — never a grep of its source or a re-implementation of its logic.
3. Document the locked contract in the script header (what was measured, on what version, when).
4. Run locally; the file stays untracked (`tests/` is gitignored) — this is a local dev suite, never shipped to installed users.
