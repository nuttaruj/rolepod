<!-- Model-tier routing policy — referenced by using-rolepod router + agent frontmatter. -->

## Model tiers

Rolepod ships a cost-aware policy that maps **role + risk → model tier**. Lead doesn't pick a model; the agent's per-CLI frontmatter overlay does — `adapters/claude/agent-frontmatter/<agent>.yml`, `adapters/codex/agent-frontmatter/<agent>.yml`, `adapters/gemini/agent-frontmatter/<agent>.yml`. Each org can override by editing those.

| Tier | Claude | Codex | Gemini | Use for |
|---|---|---|---|---|
| **cheap** | `haiku` | `gpt-5.6-luna` | `gemini-3-flash-preview` | docs, PM (feature + commercial), customer-facing copy, marketing, FAQ, ADR drafting, read-only scout sweeps — repeatable structured output, no deep architectural reasoning |
| **balanced** | `sonnet` | `gpt-5.6-terra` | `gemini-3-pro-preview` | normal implementation (backend, frontend, mobile, AI/ML features, data pipelines, perf, UI/UX, devops), QA test writing — the default working tier |
| **strong** | `opus` | `gpt-5.6-sol` | `gemini-3-pro-preview` | architecture, billing/payments, security implementation, migrations, adversarial code review — wrong code costs real money or blocks recovery; reviewer must match implementer depth |

**Effort** layers on top of the model. Claude uses `effort`, Codex uses `model_reasoning_effort` (`xhigh` / `high` / `medium`); Gemini has no effort field.

- `xhigh` — security-engineer only (breach blast radius).
- `high` — strong tier (system-architect, billing-engineer, universal-reviewer) + balanced-tier roles where reasoning depth pays off (ai-ml-engineer, performance-engineer, qa-tester).
- `medium` — everything else.

**Codex** runs the GPT-5.6 line — `luna` (fast/cheap), `terra` (balanced workhorse), `sol` (deepest). All three verified against the local `codex exec -m`.

**Gemini / Antigravity.** Google retired the standalone Gemini CLI for individual accounts on 2026-06-18; the live path is now Antigravity (`agy`), which **auto-selects** the model per task and does not consume a per-agent API model id. The `gemini-3-*-preview` values above are frozen artifacts of the retired Gemini-CLI adapter (kept only so the frozen adapter stays internally consistent; the ids still resolve as aliases). On `agy` the tier is advisory, not enforced. Do not treat these ids as an active knob until an agy-native per-agent model field is verified — pinning an unverified id there would silently break dispatch.

## Default agent → tier mapping

| Agent | Tier | Rationale |
|---|---|---|
| `backend-developer` | balanced | Normal API/business-logic work |
| `frontend-developer` | balanced | Component + state + routing work |
| `mobile-developer` | balanced | Native + cross-platform |
| `ai-ml-engineer` | balanced | LLM/RAG features in production code |
| `data-scientist` | balanced | Analytics + pipelines |
| `qa-tester` | balanced | Test authoring, business-logic verify |
| `performance-engineer` | balanced | Profiling + optimization with measured evidence |
| `ui-ux-designer` | balanced | Visual polish + a11y |
| `devops-sre` | balanced | Infra + CI/CD + release |
| `billing-engineer` | **strong** | Money flows; wrong code = revenue/audit risk |
| `security-engineer` | **strong** | Auth + secrets + crypto; wrong code = breach |
| `system-architect` | **strong** | Architecture decisions are load-bearing across the codebase |
| `universal-reviewer` | **strong** | Adversarial code review; must match implementer's depth |
| `product-manager` | cheap | Spec writing + prioritization |
| `scout` | cheap | Read-only wide sweeps — research report only, never edits |
| `content-strategist` | cheap | All human-readable written output — internal docs / ADRs / READMEs (`audience: dev`), FAQ / onboarding / user-facing copy (`audience: user`), SEO / conversion copy (`audience: prospect`) |

## Override path

Per-org override: edit `~/.claude/agents/<agent-name>.md` frontmatter `model:` field. The rolepod default is whatever the rendered template specifies; user override takes precedence (Claude Code precedence: user > project > plugin defaults).

Per-task override: explicit user instruction always wins. If the user says "use opus for this," that overrides the tier policy for the turn.

## When to escalate tier

Auto-escalate to the **strong** tier for adversarial review (regardless of agent default) when:

- Touching auth / authn / authz / billing / payment / migration / credit / permission / secret / crypto / token / oauth / jwt / sso / saml / webhook / stripe / paypal / charge / invoice paths.
- About to ship to production (final `finish-work` review).
- 3rd agent attempt on same surface (per CLAUDE.md hard stops).
- User explicit "use careful mode" or `/rolepod` invocation.

The `gate-reminder.sh` and `precommit-gate.sh` hooks already block edits on high-risk paths without a reviewer agent dispatched. The tier policy makes the *which* reviewer explicit.
