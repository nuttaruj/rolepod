<!-- Model-tier routing policy — referenced by using-rolepod router + agent frontmatter. -->

## Model tiers

Rolepod ships a cost-aware policy that maps **role + risk → model tier**. Lead doesn't pick a model; the agent's frontmatter does. The default tier per agent is set in `adapters/claude/agent-frontmatter/<agent>.yml` (and the matching Codex / Gemini configs). Each org can override by editing the YAML.

| Tier | Default model | Use for | Why |
|---|---|---|---|
| **cheap** | `haiku` | docs, PM, business analysis, customer-facing copy, marketing, FAQ, ADR drafting | Repeatable structured output. No deep architectural reasoning required. Most expensive per-token spent here = waste. |
| **balanced** | `sonnet` | normal implementation (backend, frontend, mobile, AI/ML features, data pipelines, perf optimization, UI/UX, devops), QA test writing | The default working tier. Strong reasoning + reasonable cost. |
| **strong** | `opus` | architecture decisions, billing/payments code, security implementation, migrations, anything where wrong code costs real money or blocks recovery | Cost/risk trade flips here — pay opus rates because the cost of a wrong sonnet output is higher. |
| **adversarial** | `opus` | final code review, security review of high-risk paths, doubt-driven review | Reviewer must be at least as smart as the implementer or the review is theater. |

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
| `business-analyst` | cheap | Pricing models + ROI analysis |
| `tech-writer` | cheap | Internal docs + ADRs + READMEs |
| `customer-success` | cheap | FAQ + onboarding + user-facing copy |
| `growth-marketer` | cheap | SEO + conversion copy |

## Override path

Per-org override: edit `~/.claude/agents/<agent-name>.md` frontmatter `model:` field. The rolepod default is whatever the rendered template specifies; user override takes precedence (Claude Code precedence: user > project > plugin defaults).

Per-task override: explicit user instruction always wins. If the user says "use opus for this," that overrides the tier policy for the turn.

## When to escalate tier

Auto-escalate to **adversarial** tier (regardless of agent default) when:

- Touching auth / authn / authz / billing / payment / migration / credit / permission / secret / crypto / token / oauth / jwt / sso / saml / webhook / stripe / paypal / charge / invoice paths.
- About to ship to production (final `pre-merge-gate` review).
- 3rd agent attempt on same surface (per CLAUDE.md hard stops).
- User explicit "use careful mode" or `/rolepod` invocation.

The `gate-reminder.sh` and `precommit-gate.sh` hooks already block edits on high-risk paths without a reviewer agent dispatched. The tier policy makes the *which* reviewer explicit.
