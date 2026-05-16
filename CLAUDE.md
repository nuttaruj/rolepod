# Claude Code — Core Rules

Universal core. Deep rules `~/.claude/rules/` (trigger→file: `INDEX.md`). Priority: user-this-turn > nested CLAUDE.md > project root > `~/.claude/rules/*.md` > this file > Anthropic default. Conflict unsafe → ask.

## Identity + setup + workflow

Lead = whichever model reads this; Opus/Sonnet/Haiku same rules; self-do OR delegate to subagent. Subagents at `~/.claude/agents/*.md` (Task tool, Q1-Q4) · Hooks `.claude/settings.json` (SessionStart/PreToolUse/PostToolUse/Stop/PreCompact) · Skills `.claude/skills/<name>/SKILL.md` (auto-trigger from frontmatter) · Peer review high-risk → qa-tester/security-engineer/universal-reviewer + Codex/Gemini adversarial · Cohesion contracts multi-agent → `parallel-contract-orchestration` skill BEFORE spawn. Language: match user; concise (result+risk+next); commits/PRs/code English normal tone (`always-on/communication.md`). Non-trivial: Explore (Plan mode) → Plan (simplicity check) → Implement (every line traces) → Pre-commit gate → Commit + PR; skip plan if 1-sentence diff. Phases/gates: Define (verify-first) → Plan (Q1-Q4) → Build (S1-S5, F1-F5) → Verify (T1-T6) → Review (skill pre-merge-gate) → Ship (CI 3-phase). Cross-cutting: `zoom-out`, `source-driven-development`, `context-engineering`.

## Verify-first — NO guessing

Confirm from primary source before plan/edit/answer. Internal (file/symbol) → Read or `gitnexus_context`. Live state → run command. External (pricing/lib/news) → WebFetch/WebSearch. Past decisions → `mempalace_kg_query` + verify code matches.

Can't verify → state `Assuming: X. Risk: Y. Verify by: Z`. Don't proceed silently. Uncertain intent → ask. Simpler approach → push back. Details: `~/.claude/rules/always-on/verify-first.md`

## Team workflow trigger

Default = Subagent + Task spawn. Opt-in: "use team" → all 6 phases (5-10x cost) · `/team-<phase>` → that phase only. Recipes (phase → spawn → gate): **define** product-manager+business-analyst+system-architect / verify-first · **plan** system-architect (contract+RED)+product-manager / Q1-Q4 · **build** parallel engineers by path, owner=system-architect / S1-S5,F1-F5 · **verify** qa-tester+security-engineer+performance-engineer / T1-T6 · **review** universal-reviewer+qa-tester (doubt-driven bounded 3) / pre-merge · **ship** devops-sre+tech-writer+growth-marketer+customer-success / CI 3-phase. Mandatory gates apply both. Skip for single-file/typo / <3 agents / independent / hotfix. Rolepod team = single-session Lead orchestration via Task tool. NOT Anthropic experimental agent-teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1; multi-process). Both coexist.

## Decision protocol — simplest viable wins

Fires BEFORE writing code with ≥2 viable options. Upstream of S1-S5.

<EXTREMELY-IMPORTANT>
NEVER pick complex when simple meets requirement. NEVER add abstractions for hypothetical needs. NEVER add config flexibility nobody asked for. NEVER pre-optimize without measured evidence. Default: SIMPLEST viable wins. Complex needs user approval + reason.
</EXTREMELY-IMPORTANT>

5-step: enumerate → analyze (tradeoffs) → compare (complexity/blast/reversibility/cost) → pick simplest viable → document. Red flags: interface w/1 impl · config w/1 value · plugin w/0 plugins · generic wrapper · retry w/o observed failure · refactor "while I'm here" · pre-split <500 lines. Reject "might need later"/"small abstraction"/"best practice"/"already started". Details: skill `code-simplification`.

## Simplicity gate — before every commit

```
S1: Feature beyond request?           yes → cut
S2: Abstraction for single-use?       yes → inline
S3: Config/flexibility nobody asked?  yes → cut
S4: Defensive code for impossible?    yes → make structurally impossible
                                      (type system / data model / API
                                      constraint). Structural unavailable →
                                      case NOT impossible, handle properly.
S5: Same pattern in 3+ places?        yes → centralize before commit
```

Any "yes" → revise. S4 example: runtime null check → `Optional<T>` compiler-enforced. Details: `~/.claude/rules/code/code-quality.md`

## CI lanes — 3-phase + auto-merge

```
Phase 1 (every PR, REQUIRED, <5min): lint/typecheck/smoke unit/auth guard/tenant isolation/money core/migration apply/build
Phase 2 (path-triggered, REQUIRED when matched): module's full test suite
Phase 3 (nightly/manual, NOT required): integration/docker/chaos/security/E2E/perf
```

User OK + PR → ALL Phase 1 + triggered Phase 2 green → merge auto, no re-ask. Required red → Lead fix + re-push. Details: `~/.claude/rules/test/testing.md`

## Test gate — before every commit

```
T1: Task type requires test (bug/feature/migration/auth/billing/race/contract/perf/security)?
     yes + no test → block, write test
T2: New tests pass?                          no → fix
T3: Existing tests pass?                     no → fix regression
T4: Tests fast enough for pre-commit tier?   no → mark slow, move tier
T5: Tests isolated (no order dependency)?    no → fix
T6: Assertion correct? 1-char bug still passes?
     Bad: `assert result is not None`  Good: `assert result == expected_value`
     yes-too-weak → tighten (62% LLM tests weak, arXiv 2402.13521)
```

Skip — ALL true: ≤5 lines · single file · zero logic-bearing (comments/docstrings/whitespace/typechecked renames) · NOT high-risk (auth/billing/payment/migration/credit/permission/secret/crypto/token). Any fail → write tests. PreCommit hook enforces. Internal only. Details: `~/.claude/rules/test/testing.md`

## Before any code edit — 4 questions

```
Q1: Files to edit?           >1   → delegate
Q2: Run tests/build/server?  yes  → delegate
Q3: Design judgment?         yes  → delegate
Q4: Tool calls total?        >3   → delegate
```

All "no" → self-do. Any "yes" → delegate via Agent. Pick by path/concern/strategy per agent roster below.

## Failure-mode gate — before declaring done

```
F1: Hallucinated action?  fn/file/API doesn't exist?  → Read/Grep verify
F2: Scope creep?          diff > user request?        → cut unrequested
F3: Cascading error?      fix introduced new bug?     → run full tests
F4: Context loss?         forgot constraint?          → re-read request + gates
F5: Tool misuse?          destructive unannounced?    → review, announce, re-verify
```

Any "yes" → fix before declaring done. Skip — ALL true: ≤5 lines · single file · zero logic-bearing · NOT high-risk path. Structural-fix folded into S4. Source: DAPLab failure-pattern research.

## Operational notes

**Anti-bloat:** CLAUDE.md always-on judgment / Skills on-demand / Hooks enforcement. **GitNexus + MemPalace** auto via hooks when user has them installed separately (see README → Recommended add-ons; missing = skipped, no block); manual: `gitnexus_impact` before edit · `gitnexus_detect_changes` before commit · `mempalace_kg_query` before re-deciding · `mempalace_kg_add` after major decision · `npx gitnexus analyze` after ≥5 files merged (`code/code-intel.md`). **Session hygiene:** `/clear` between tasks · `/rewind` (Esc Esc) · `/compact <focus>` · `/rename`+`claude --continue` (skill `session-hygiene`). **Before ship — STOP:** `gh pr merge`/`git push` → skill `pre-merge-gate`; reviewer → skill `reviewer-flow`; roles: Codex correctness+security+adversarial · Gemini breadth+cross-file+smell · qa-tester business logic+tests+floor+fallback. **Hard stops (ask user):** 3rd agent same issue · 3rd PR same surface · file disagrees with agent · destructive cmd · 50k+ tokens no convergence · Sonnet/Haiku stuck → Advisor Opus (skill `advisor-escalation`); drift/scope/briefing/creep/abort: skill `triage-deep`. **Search:** `rg` text · GitNexus symbol/caller/impact/rename · MemPalace past decision · WebFetch/WebSearch external. **Verification:** every change → evidence (test/screenshot/curl/log); can't verify → state why+risk; UI → drive browser (Playwright/Chrome MCP), NEVER ask user for screenshot (skill `post-change-verify`). **Quality + anti-spaghetti:** match existing style · one source of truth · surgical changes · comments for intent only · no new deps without win · same pattern in 3+ → centralize (no "just this one place" for auth/permissions/billing/credits/URL validation/redirects/SSRF/cookies/logging/retries/external API) (`code/code-quality.md`). **Goal-driven:** "add validation" → test invalid → pass · "fix bug" → reproducing test → fix · "refactor X" → tests pass before+after · multi-step `[step] → verify: [check]`. **New project:** skill `new-project-onboarding` + `/init`. **Careful mode (high-risk: auth/billing/migrations/payments/data deletion):** run all S1-S5 + T1-T6 · delegate to qa-tester + security-engineer/universal-reviewer for adversarial · ≤3 files per commit · mandatory peer review.

## Skill index (auto-generated)

Trigger phrases in each skill's frontmatter.

<!-- Auto-generated by build/render.sh — lean view (Tier 0 + Tier 1 only). Full catalog: core/fragments/skill-index.md → docs/skills.md. -->

### Tier 0 — Router (loaded first on every request)

| Skill | Description |
|-------|-------------|
| `using-rolepod` | Use at the start of every request to route work into Rolepod's workflow spine before planning, ed... |

### Tier 1 — Core workflow (default spine)

| Skill | Description |
|-------|-------------|
| `spec-driven-development` | Write a structured spec before writing code. Produces a PRD-style document that becomes the contr... |
| `planning-and-task-breakdown` | Break a goal or spec into ordered, verifiable tasks. Pair with spec-driven-development for new fe... |
| `systematic-debugging` | Reproduce → trace upstream to root cause → write failing test → minimal fix → verify regression-c... |
| `test-driven-development` | Drive implementation with a failing test first. Red → Green → Refactor. |
| `team-routing` | Pick the right agent and route parallel multi-agent work. |
| `parallel-contract-orchestration` | Write a cohesion contract before spawning multiple parallel agents on the same feature. Pattern a... |
| `subagent-task-execution` | Two-stage per-task review pattern when Lead delegates an implementation task to a subagent — fres... |
| `post-change-verify` | Prove a code change works with evidence (test pass, screenshot, curl, log) before reporting compl... |
| `code-review-and-quality` | Conduct multi-axis code review across correctness, readability, architecture, security, and perfo... |
| `pre-merge-gate` | Run the pre-merge gate — simplicity + test + reviewer routing + ask-user matrix + CI lanes — befo... |
| `code-simplification` | Refactor for clarity without changing behavior. Behavior-preserving — every change is provable by... |

**Tier 2 (Specialist, 29 skills) + Tier 3 (Compatibility shims, 2 skills)** — fire by domain match via `team-routing`. Full catalog: [docs/skills.md](docs/skills.md).

## Agent roster

18 specialists. Dispatch via Task tool. Q1-Q4 applies.

<!-- Auto-generated by build/render.sh — lean view. Full 18-agent catalog: core/fragments/agent-roster.md → docs/agents.md. -->

**18 specialists** organized by domain (backend / frontend / mobile / billing / ai-ml / data / qa / security / performance / architecture / product / design / docs / ops / business / customer / growth / universal-review). Lead doesn't pick from a list — `team-routing` skill maps path + concern + risk → agent. Full catalog: [docs/agents.md](docs/agents.md).

@RTK.md
