# Reviewer Flow — Codex + Gemini + qa-tester

Read BEFORE spawning any reviewer. Tier values read live from `~/.claude/agents/<name>.md` — don't hardcode model versions.

General review principles: skill `code-review-and-quality`. This file = AI-reviewer routing specifics.

## Three reviewers, three roles

| Reviewer | Strength | Tooling |
|----------|----------|---------|
| **Codex** | Correctness + security depth + adversarial mindset | Plugin Skill OR Bash companion |
| **Gemini** | Repo-wide breadth + cross-file consistency + code smell + naming | Lead-direct CLI (`gemini -m pro -o text -p "..."`) |
| **qa-tester** | Business logic + integration + races + multi-step + tests + Write tool | Subagent (Agent tool) |

**qa-tester = universal floor + universal fallback.**
- Always runs as minimum (every gate).
- Auto-takes over Codex/Gemini scope when external reviewer fails (rate-limit, 10min hang, empty output, CLI error, Skill block).
- qa-tester itself can't fail-over (it IS the internal subagent). If blocked → Lead does manual review via Read/Grep.

## Invocation

| Reviewer | How |
|----------|-----|
| **Codex** | Try plugin Skill first: `Skill({skill: "codex:review"})` or `codex:adversarial-review`. On `disable-model-invocation` block → Bash background to `codex-companion.mjs` |
| **Gemini** | Lead-direct sync: `gemini -m pro -o text -p "<prompt>" > /tmp/gemini-$TS.txt 2> /tmp/gemini-$TS.err` |
| **qa-tester** | Subagent via Agent tool |

### Gemini flag rules

- Pin `-m pro` (default `auto` may downgrade to flash)
- `-o text` for prose review; `-o json` if Lead wants `jq -r .response` + cache-hit tracking
- **Don't `2>&1`** — Gemini emits 20-40 lines stderr noise (terminal-color / ripgrep fallback / classifier 500 / DEP0190). Always separate stderr to `.err` or `2>/dev/null`.

### 3 valid Gemini patterns

- **A** — PR-diff pipe: `git diff base..HEAD | gemini -p "..."`
- **B** — whole-repo: `cd /repo && gemini -p "..."` (workspace = cwd, NO flag)
- **C** — exploration: B without findings format

NOT a multi-step investigator — that's qa-tester's job.

### Codex routing

- Bounded diff/commit/PR review = direct diff (`git diff`, `gh pr diff`, source files). Don't require GitNexus.
- Reserve GitNexus-first for architecture / blast-radius / flow audits or user-requested "audit whole system".
- Don't trigger `gitnexus analyze` during review unless user asks.

## Gemini security — read-only, hard constraints

Gemini CLI NOT sandboxed like Codex. Treat as untrusted code execution:

- Never `--yolo` / `--auto-approve`
- Never interactive for review — always `-p "..."` non-interactive
- Never let Gemini write project files. Output → `/tmp/gemini-*.txt` only. Lead applies edits via Edit/Write or delegates.
- Never pipe credentials (`.env`, `.pgpass`, secrets, tokens, keys) into prompt
- Never let Gemini commit/push/run git mutating commands
- Run from repo root with `git diff` piped via stdin

## Allowed / banned

- **Allowed**: `/codex:review`, `/codex:adversarial-review`, `/codex:status`, `/codex:result`
- **Hard ban**: `/codex:rescue`, `codex-rescue` agent, any Codex command that edits files
- Plugin v1.0.4+ blocks Skill-tool via `disable-model-invocation: true`. Try plugin first; fall back to Bash companion on block.
- Lead-direct Gemini CLI = default. Context too hot? Spawn general-purpose subagent to wrap the Bash call.

## Routing — pick reviewers by VALUE per profile

| PR profile | Reviewers | Why this set |
|------------|-----------|--------------|
| **<5 files** (hotfix) | qa-tester solo | Surgical; deep context check enough |
| **5-30 files** (feature) | Gemini → qa-tester (skip Codex) | Breadth scan + business logic verify |
| **>30 files** (refactor/epic) | Gemini (all) + qa-tester (core) + Codex (risky subsys) | Big context window + integration + race |
| **High-risk surface** | Codex adversarial → qa-tester (skip Gemini) | Attacker mindset + integrity |
| **Frontend / UI** | Gemini + qa-tester (skip Codex) | Perf + best practice + state |

### Skip rule

Drop reviewer if their strength doesn't match profile.
Don't trigger Codex on UI-only PR. Don't trigger Gemini on tiny hotfix.

### Roles within profile (always)

- **Gemini** = breadth (code smell, cross-file consistency, naming)
- **Codex** = depth + adversarial (correctness, security, race)
- **qa-tester** = business logic + integration + tests + Write tool (acts on findings)

## High-risk surface — escalate to Codex `adversarial-review`

Project-agnostic. Bug here = irreversible / hard-to-detect damage:

- Auth / permissions / tenant isolation
- Money / billing / payments / credits
- DB migrations / schema changes
- Distributed locks / concurrency / queue handlers
- External integrations w/ side effects (third-party state mutations)
- File / storage ops on user data (delete / encrypt / move)
- Crypto / signing / token issuance
- Legal / compliance / regulatory
- Irreversible business state (orders shipped, emails sent, payments captured)

**Litmus**: "would a bug here be cheap to roll back?" If NO → high-risk → Codex adversarial.

## Cascade — 3 phases, hard cap 3 rounds per external reviewer

| Phase | Reviewer | Cap |
|-------|----------|-----|
| **1** initial review | Codex ≤2 + Gemini ≤2 per routing | findings → fix → verify with **qa-tester** (NOT re-Codex/Gemini) |
| **2** cleanup | qa-tester unlimited | When external reviewers at budget. Bash + unit-test scripts + Write tool. |
| **3** final-gate (ONCE) | Codex 1 + Gemini 1 | Clean → ship. Findings → fix → qa-tester follow-up → ship (no re-trigger). |

**Hard cap per feature batch**: Codex 3 rounds, Gemini 3 rounds, qa-tester unlimited.

## Rules (all reviewers)

- Round-level gate, NOT per-edit/per-commit/per-file
- Batch all findings before re-running
- Verify each finding in code; review = input, not orders
- Don't hide unresolved findings — invalid/deferred = explain with file:line
- Lead interprets, reviewers don't (CLIs → /tmp; subagents → raw/structured)
- Lead-direct CLI output → `/tmp` → chunked Read; never spam main transcript

## Fallback — qa-tester absorbs failed reviewer's SCOPE

External reviewer fails (rate-limit / Skill block / 10min hang / empty / error)
→ qa-tester takes **same scope + role**.

Example: >30 files refactor, Gemini dies → qa-tester runs ALL files (breadth) + core; Codex unchanged.
Both die → qa-tester runs all + core + risky in Phase 2 unlimited.

### qa-tester adversarial-style (absorbing Codex)

1. Read `~/.claude/plugins/marketplaces/openai-codex/plugins/codex/prompts/adversarial-review.md`
2. Fallback if file missing:
   - Skepticism by default
   - Hunt: invariants / missing-guards / race / rollback / empty-state
   - Bug classes: auth bypass / data loss / corruption / race / migration hazard / observability gap
   - Finding format: (what fails) + (why) + (impact) + (concrete fix)
   - Ship-blocker if material risk

User-invoked `/codex:review` = independent, NOT part of AI's per-round flow.

## Common mistakes — DO NOT

- Re-trigger Codex/Gemini per individual fix → batch findings
- Skip qa-tester because Codex passed — qa-tester always runs
- Trigger Codex on UI-only PR — wastes budget
- Trigger Gemini interactively or with `--yolo`
- Pipe credentials into Gemini prompt
- Let Gemini commit/push/edit files
