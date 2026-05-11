---
name: reviewer-flow
description: Route code review across Codex, Gemini, and qa-tester. Use when spawning a reviewer, "code review cascade", "adversarial review", "Codex review", "Gemini review", high-risk surface review.
---

# Reviewer Flow — Codex + Gemini + qa-tester

Read BEFORE spawning reviewer. Tier values read live from `~/.claude/agents/<name>.md`.

General review: skill `code-review-and-quality`. This file = AI-reviewer routing.

## Three reviewers

| Reviewer | Strength | Tooling |
|----------|----------|---------|
| **Codex** | Correctness + security + adversarial | Plugin Skill OR Bash companion |
| **Gemini** | Repo breadth + cross-file + smell + naming | Lead-direct CLI |
| **qa-tester** | Business logic + integration + races + tests + Write | Subagent |

**qa-tester = universal floor + fallback.**
- Always runs (every gate).
- Absorbs Codex/Gemini scope when they fail.
- Itself can't fail-over → Lead does manual review via Read/Grep.

## Invocation

| Reviewer | How |
|----------|-----|
| **Codex** | Plugin Skill: `codex:review` or `codex:adversarial-review`. On `disable-model-invocation` block → Bash to `codex-companion.mjs` |
| **Gemini** | `gemini -m pro -o text -p "<prompt>" > /tmp/gemini-$TS.txt 2> /tmp/gemini-$TS.err` |
| **qa-tester** | Agent tool |

### Gemini flag rules

- Pin `-m pro` (default `auto` may downgrade to flash)
- `-o text` for prose; `-o json` for `jq -r .response` + cache tracking
- **Don't `2>&1`** — Gemini emits 20-40 lines stderr noise. Separate to `.err` or `2>/dev/null`.

### 3 valid Gemini patterns

- **A** — PR-diff pipe: `git diff base..HEAD | gemini -p "..."`
- **B** — whole-repo: `cd /repo && gemini -p "..."` (cwd = workspace, NO flag)
- **C** — exploration: B without findings format

NOT a multi-step investigator — that's qa-tester.

### Codex routing

- Bounded diff/commit/PR review = direct diff. Don't require GitNexus.
- GitNexus-first only for architecture / blast-radius / user-requested "audit whole system".
- Don't trigger `gitnexus analyze` during review unless asked.

## Gemini security — read-only

NOT sandboxed like Codex. Treat as untrusted:

- Never `--yolo` / `--auto-approve`
- Always `-p "..."` non-interactive
- Never let Gemini write project files. Output → `/tmp/gemini-*.txt` only
- Never pipe credentials (`.env`, secrets, tokens, keys) into prompt
- Never let Gemini commit/push/run git mutating commands
- Run from repo root with `git diff` piped via stdin

## Allowed / banned

- **Allowed**: `/codex:review`, `/codex:adversarial-review`, `/codex:status`, `/codex:result`
- **Hard ban**: `/codex:rescue`, `codex-rescue` agent, any Codex command that edits files
- Plugin v1.0.4+ blocks Skill-tool via `disable-model-invocation: true`. Try plugin first; fall back to Bash companion.
- Lead-direct Gemini = default. Context hot? Wrap Bash call in general-purpose subagent.

## Routing by PR profile

| Profile | Reviewers |
|---------|-----------|
| **<5 files** (hotfix) | qa-tester solo |
| **5-30 files** (feature) | Gemini → qa-tester |
| **>30 files** (refactor/epic) | Gemini all + qa-tester core + Codex risky |
| **High-risk surface** | Codex adversarial → qa-tester |
| **Frontend / UI** | Gemini + qa-tester |

### Skip rule

Drop reviewer if strength doesn't match. Don't trigger Codex on UI-only. Don't trigger Gemini on tiny hotfix.

### Roles within profile

- Gemini = breadth (smell, cross-file, naming)
- Codex = depth + adversarial (correctness, security, race)
- qa-tester = business logic + integration + tests + Write tool

## High-risk surface — Codex `adversarial-review`

Bug here = irreversible / hard-to-detect:

- Auth / permissions / tenant isolation
- Money / billing / payments / credits
- DB migrations / schema
- Distributed locks / concurrency / queue handlers
- External integrations w/ side effects
- File / storage ops on user data (delete / encrypt / move)
- Crypto / signing / token issuance
- Legal / compliance
- Irreversible business state (orders shipped, emails sent, payments captured)

**Litmus**: "cheap to roll back?" NO → high-risk → Codex adversarial.

## Cascade — 3 phases, cap 3 rounds per external

| Phase | Reviewer | Cap |
|-------|----------|-----|
| 1 initial | Codex ≤2 + Gemini ≤2 | findings → fix → verify with qa-tester |
| 2 cleanup | qa-tester unlimited | When external at budget |
| 3 final-gate (ONCE) | Codex 1 + Gemini 1 | Clean → ship. Findings → fix → qa-tester → ship (no re-trigger) |

**Hard cap per batch**: Codex 3, Gemini 3, qa-tester unlimited.

## Rules (all reviewers)

- Round-level gate, NOT per-edit/per-commit/per-file
- Batch findings before re-running
- Verify each finding in code; review = input, not orders
- Don't hide unresolved → invalid/deferred = explain with file:line
- Lead interprets, reviewers don't
- CLI output → `/tmp` → chunked Read; never spam main transcript

## Fallback — qa-tester absorbs scope

External fails (rate-limit / Skill block / 10min hang / empty / error) → qa-tester takes same scope + role.

Example: >30 files refactor, Gemini dies → qa-tester runs ALL files (breadth) + core; Codex unchanged.

### Model escalation when fallback

`qa-tester` / `universal-reviewer` default = Sonnet high. **Override to Opus high** via `model` param when:

| Condition | Why |
|-----------|-----|
| Codex unavailable + high-risk surface | qa-tester absorbs adversarial scope |
| Gemini unavailable + PR >30 files | qa-tester absorbs breadth scope |
| Both unavailable + non-trivial PR | sole reviewer |
| No external plugins installed | Opus floor preserves quality |
| User asks "deep review" / "ultrareview" | Explicit |

Detection: `which gemini`, Codex Skill availability, installed plugins.

Spawn template (fallback):
```
Agent({
  subagent_type: "qa-tester",
  model: "opus",
  prompt: "Context: Codex unavailable. Absorb adversarial scope.\n[brief]"
})
```

Normal context: use defaults.

### qa-tester adversarial (absorbing Codex)

1. Read `~/.claude/plugins/marketplaces/openai-codex/plugins/codex/prompts/adversarial-review.md`
2. Fallback if missing:
   - Skepticism by default
   - Hunt: invariants / missing-guards / race / rollback / empty-state
   - Bug classes: auth bypass / data loss / corruption / race / migration hazard / observability gap
   - Format: (what fails) + (why) + (impact) + (concrete fix)
   - Ship-blocker if material risk

User-invoked `/codex:review` = independent, NOT part of per-round flow.

## Common mistakes — DO NOT

- Re-trigger Codex/Gemini per fix → batch
- Skip qa-tester because Codex passed
- Codex on UI-only PR
- Gemini interactive or `--yolo`
- Pipe credentials into Gemini
- Let Gemini commit/push/edit
