# Report-response plan — 2026-07-30

Source: 3 external analysis reports (dev-qa-effectiveness, fit-analysis, improvement-report).
Scope decided with user: fix everything verified real; ignore browser/e2e gaps (rolepod-uiproof covers), Jira/TestRail (out of scope), router-shrink (reports rank last).
Naming decision: rigor tiers use **R0-R4** — "T" prefix already taken by T1-T6 test gates.

## Phase A — v2.10.4 (P0 hygiene)

- [x] A1. Quote `description` in `core/agents/product-manager.md` (YAML parse error, line 3 — breaks agent load on Claude validate + Gemini).
      Command: `python3 -c "import yaml,glob; [yaml.safe_load(open(f).read().split('---')[1]) for f in glob.glob('core/agents/*.md')]" && echo OK`
- [x] A2. CI Thai scan binary-safe: strict UTF-8 decode, skip `UnicodeDecodeError` files (`.github/workflows/installer.yml:70-92`).
      Command: run scan block locally → exit 0.
- [x] A3. Untrack `.rolepod-mcp/` artifacts (6 files, incl. 3 PNGs that break the scan) + add to `.gitignore`.
      Command: `git ls-files .rolepod-mcp/ | wc -l` → 0.
- [x] A4. README: five → six CLIs, add opencode install section.
      Command: `grep -c opencode README.md` ≥ 3.
- [x] A5. docs/cli-support.md: opencode column (capability matrix + install destinations + runtime verification); codex `plugin_hooks` fix — flag now `removed`, hooks fire natively (verified `codex features list` 2026-07-30, Codex 0.144.1); refresh last-verified note.
      Command: `grep -c opencode docs/cli-support.md` ≥ 4; no instruction to enable `plugin_hooks` remains.
- [x] A6. GitHub About: 18 → 16 agents, Claude-only → six CLIs (`gh repo edit --description`).
- [x] A7. Bump 2.10.4 (8 manifests) → render → test → commit.

## Phase B — v2.11.0 (P1 — small/medium task token efficiency; the reports' central complaint)

- [x] B1. Router `using-rolepod` (234/240 → cut 3 inline examples, 23 lines, redundant with `examples/routing-transcripts.md`):
      replace binary Skip rule with **Rigor ladder R0-R4** (R0 answer-only / R1 trivial ≤5-line / R2 single-file clear-logic inline-plan lane / R3 full spine / R4 high-risk never-downgrade);
      Output pattern: R0/R1 no block, R2 one-liner, R3/R4 + surprise = full block;
      align state machine Define/Plan exit evidence + Common Rationalizations row.
- [x] B2. `write-plan`: R2 lane — 3-5 line inline checklist + verify command replaces plan artifact (175/190).
- [x] B3. `implement-plan`: same-line R2 mention (189/190 — 1 line free).
- [x] B4. `check-work` Iron Rule 2 — evidence cache: fresh = run after LAST tree change; unchanged tree + recorded pass this session → cite cached command+output+hash, no re-run; any edit invalidates (186/190).
- [x] B5. `review-code`: map R2 → existing risk-ladder level (single reviewer), 1 line (171/190).
- [x] B6. Grep fragments/adapters for duplicated "≤5 lines" skip rule; sync if found.
- [x] B7. Bump 2.11.0 → render → test → commit.

## Phase C — v2.12.0 (P2 — trust / enforcement honesty)

- [x] C1. Enforcement tier banner: hook-live CLIs (Claude/Gemini/Codex) print tier at SessionStart; doctrine-only CLIs (opencode/Cursor/Antigravity) carry explicit "Enforcement: doctrine-only" line + rule: never report a hook gate as mechanically enforced there.
- [x] C2. Bypass accountability: any `ROLEPOD_GATES_SOFT` / `ROLEPOD_NO_CONTRACT` / `ROLEPOD_ALLOW_SHARED_WORKTREE` bypass appends `{ts, hook, var, reason|unreasoned}` to `.rolepod/evidence/bypass.log` (reason via `ROLEPOD_BYPASS_REASON`); never blocks.
- [x] C3. Risk-path per-repo override: `.rolepod/risk-paths` (one pattern per line) read by precommit-gate + gate-reminder + session_state.py; fallback = built-in list; router/doctrine same-line mention.
- [x] C4. `scripts/doctor.sh` + `make doctor`: fire every Claude hook with synthetic payloads, assert deny/context actually emitted; report installed versions + enforcement tier per CLI. Integration test.
- [x] C5. Phase evidence log `.rolepod/evidence/phase-log.jsonl`: router tier decision, check-work verdict, review verdict, finish-work ship action (answers the "does it work" measurement gap all 3 reports name).
- [x] C6. Bump 2.12.0 → render → test → commit.

## Phase D — v2.13.0 (P3 — QA depth)

- [x] D1. `qa-tester.md`: stable `TC-###` ID column in test-case table; every P1 row maps to an automated test whose name carries the ID.
- [x] D2. `check-work`: when a QA test-case table exists in evidence, assert every P1 ID has a passing test.
- [x] D3. `hooks/test-diff-lint.sh` (warn-only, from precommit-gate): added `.only`/`.skip`, deleted test cases, snapshot bulk-update, DB mock in integration path; spec-derived-expected marked HUMAN-ONLY. Integration test.
- [x] D4. Bump 2.13.0 → render → test → commit.

## Failure policy

Any `make test` failure → fix before proceeding to next phase. Line-cap overflow → compress in-place or move detail to references/, never raise the cap.

## Explicitly not doing (with reasons)

- Browser/e2e/a11y in core — `rolepod-uiproof` owns it; README pointer already exists via plugin-family section.
- Jira/TestRail/device farm — personal-use scope.
- Move all gates to CI — harness hooks are the product for this repo's use case; `doctor` (C4) addresses the reliability concern instead.
- Router shrink <100 lines — reports rank it last; caching makes resident cost cheap.
- Persona session modes (Dev/QA switch) — router already has QA rows; D1/D2 close the actual gap (traceability).
