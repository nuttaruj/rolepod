# Claude Code — Core Rules

Universal core. Deep rules `~/.claude/rules/` (trigger→file: `INDEX.md`). Priority: user-this-turn > nested CLAUDE.md > project root > `~/.claude/rules/*.md` > this file > Anthropic default. Conflict unsafe → ask.

## Identity + setup + workflow

Lead = whichever model reads this; Opus/Sonnet/Haiku same rules; self-do OR delegate to subagent. Subagents at `~/.claude/agents/*.md` (Task tool, Q1-Q4) · Hooks `.claude/settings.json` (SessionStart/PreToolUse/PostToolUse/Stop/PreCompact) · Skills `.claude/skills/<name>/SKILL.md` (auto-trigger from frontmatter) · Peer review high-risk → qa-tester/security-engineer/universal-reviewer + Codex/Gemini adversarial · Cohesion contracts multi-agent → `write-plan` BEFORE spawn. Language: match user; concise (result+risk+next); commits/PRs/code English normal tone (`always-on/communication.md`). Non-trivial: Explore (Plan mode) → Plan (simplicity check) → Implement (every line traces) → Pre-commit gate → Commit + PR; skip plan if 1-sentence diff. Phases/gates: Define (`write-spec`) → Plan (`write-plan`) → Build (`implement-plan` / `debug-issue`) → Verify (`check-work`) → Review (`review-code`) → Ship (`finish-work`). Cross-cutting: `simplify-code`, `manage-context`.

## Verify-first — NO guessing

Confirm from primary source before plan/edit/answer. Internal (file/symbol) → Read or `gitnexus_context`. Live state → run command. External (pricing/lib/news) → WebFetch/WebSearch. Past decisions → `mempalace_kg_query` + verify code matches.

Can't verify → state `Assuming: X. Risk: Y. Verify by: Z`. Don't proceed silently. Uncertain intent → ask. Simpler approach → push back. Details: `~/.claude/rules/always-on/verify-first.md`

## Team workflow trigger (Claude only)

Default = Subagent + Task spawn (single-process, all CLIs). Opt-in: **`/rolepod-team`** slash command — adapts silently to env (TEAMMATE mode when Claude v2.1.32+ + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, else FALLBACK via Subagent + Task + cohesion contract). Codex/Gemini don't ship `/rolepod-team`; use natural-language Subagent dispatch through `write-plan` agent routing. Power users want real teammates: see README. `/rolepod-team` is `disable-model-invocation: true` — only user can fire it.

Per-phase team commands (`/team-define`, `/team-plan`, `/team-build`, `/team-verify`, `/team-review`, `/team-ship`) have been removed — they were subagent recipes that Lead routinely pattern-matched into regular Subagent dispatch (drift documented in commits `0f8de4f`, `6da9fe0`). For phase-scoped parallel work, tell `/rolepod-team` to spawn teammates focused on that phase only.

Cost: each teammate = separate Claude instance with own context window. 4-teammate team ≈ 4× single-session tokens. Use for genuinely parallel work (cross-domain features, parallel investigation, multi-module refactor) — for sequential / trivial tasks, default Subagent + Task is more cost-effective.

Mandatory gates (S1-S5 / T1-T6 / F1-F5 / verify-first / review-code) fire inside each teammate — rolepod CLAUDE.md + skills load in every teammate session. Lead's job = coordination, not gate enforcement.

## Decision protocol — simplest viable wins

Fires BEFORE writing code with ≥2 viable options. Upstream of S1-S5.

<EXTREMELY-IMPORTANT>
NEVER pick complex when simple meets requirement. NEVER add abstractions for hypothetical needs. NEVER add config flexibility nobody asked for. NEVER pre-optimize without measured evidence. Default: SIMPLEST viable wins. Complex needs user approval + reason.
</EXTREMELY-IMPORTANT>

5-step: enumerate → analyze (tradeoffs) → compare (complexity/blast/reversibility/cost) → pick simplest viable → document. Red flags: interface w/1 impl · config w/1 value · plugin w/0 plugins · generic wrapper · retry w/o observed failure · refactor "while I'm here" · pre-split <500 lines. Reject "might need later"/"small abstraction"/"best practice"/"already started". Details: skill `simplify-code`.

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

**Anti-bloat:** CLAUDE.md always-on judgment / Skills on-demand / Hooks enforcement. **GitNexus + MemPalace** auto via hooks when user has them installed separately (see README → Recommended add-ons; missing = skipped, no block); manual: `gitnexus_impact` before edit · `gitnexus_detect_changes` before commit · `mempalace_kg_query` before re-deciding · `mempalace_kg_add` after major decision · `npx gitnexus analyze` after ≥5 files merged (`code/code-intel.md`). **Session hygiene:** `/clear` between tasks · `/rewind` (Esc Esc) · `/compact <focus>` · `/rename`+`claude --continue` (skill `manage-context`). **Before ship — STOP:** `gh pr merge`/`git push` → skill `finish-work`; reviewer → skill `review-code`; roles: Codex correctness+security+adversarial · Gemini breadth+cross-file+smell · qa-tester business logic+tests+floor+fallback. **Hard stops (ask user):** 3rd agent same issue · 3rd PR same surface · file disagrees with agent · destructive cmd · 50k+ tokens no convergence · Sonnet/Haiku stuck → `manage-context`; drift/scope/briefing/creep/abort → `manage-context`. **Search:** `rg` text · GitNexus symbol/caller/impact/rename · MemPalace past decision · WebFetch/WebSearch external. **Verification:** every change → evidence (test/screenshot/curl/log); can't verify → state why+risk; UI → drive browser (Playwright/Chrome MCP), NEVER ask user for screenshot (skill `check-work`). **Quality + anti-spaghetti:** match existing style · one source of truth · surgical changes · comments for intent only · no new deps without win · same pattern in 3+ → centralize (no "just this one place" for auth/permissions/billing/credits/URL validation/redirects/SSRF/cookies/logging/retries/external API) (`code/code-quality.md`). **Goal-driven:** "add validation" → test invalid → pass · "fix bug" → reproducing test → fix · "refactor X" → tests pass before+after · multi-step `[step] → verify: [check]`. **New project:** skill `manage-context` + `/init`. **Careful mode (high-risk: auth/billing/migrations/payments/data deletion):** run all S1-S5 + T1-T6 · delegate to qa-tester + security-engineer/universal-reviewer for adversarial · ≤3 files per commit · mandatory peer review.

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
| `write-spec` | Use when turning a fuzzy goal, half-stated feature, or vague request into a sharp implementation ... |
| `write-plan` | Use when turning an approved spec or a small clear goal into an executable implementation plan — ... |
| `implement-plan` | Use when executing an approved plan or a clear single-file edit — TDD for risky paths, surgical e... |
| `debug-issue` | Use when something is broken — error appears, test fails, build breaks, output is wrong, regressi... |
| `check-work` | Use after a change is made and before claiming the work is done — prove it with evidence (tests, ... |
| `review-code` | Use before merging or shipping — review code with risk-appropriate adversarial pressure across co... |
| `finish-work` | Use at the end of a development branch — pre-merge gate, CI lane discipline, 4-option finish menu... |
| `simplify-code` | Use when code feels over-engineered, rotted, or duplicated — cut unused abstraction, inline singl... |
| `manage-context` | Use when the session is long, the repo is unfamiliar, the work is multi-file, you are stuck, or y... |

**Legacy skill names are not shipped.** Migration map: [docs/legacy-skill-map.md](docs/legacy-skill-map.md).

## Agent roster

18 specialists. Dispatch via Task tool. Q1-Q4 applies.

<!-- Auto-generated by build/render.sh — lean view. Full 18-agent catalog: core/fragments/agent-roster.md → docs/agents.md. -->

**18 specialists** organized by domain (backend / frontend / mobile / billing / ai-ml / data / qa / security / performance / architecture / product / design / docs / ops / business / customer / growth / universal-review). Lead doesn't pick from a list — `write-plan` maps path + concern + risk → agent when delegation helps. Full catalog: [docs/agents.md](docs/agents.md).

@RTK.md

<!-- gitnexus suppressor: empty markers + GitNexus's own --skip-agents-md keep auto-inject off. Full rationale in docs/gitnexus-suppressor.md. -->
<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **rolepod** (1160 symbols, 1223 relationships, 8 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/rolepod/context` | Codebase overview, check index freshness |
| `gitnexus://repo/rolepod/clusters` | All functional areas |
| `gitnexus://repo/rolepod/processes` | All execution flows |
| `gitnexus://repo/rolepod/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
