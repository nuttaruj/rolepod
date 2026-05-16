---
name: team-routing
description: Pick the right agent and route parallel multi-agent work.
when_to_use: '"choose agent", "multi-agent parallel", "team layout", "agent picker", "unclear ownership", "cohesion contract"'
---

# Team Organization — agent picker + parallel pattern

Read when: choosing agent / planning multi-agent work / unclear ownership.

## Team layout (18 agents, 7 layers)

```
Layer 1 Strategy (4, parallel)    product-manager · business-analyst · growth-marketer · customer-success
Layer 2 Architecture (1, gate)    system-architect
Layer 3 Engineering (6, by path)  backend · frontend · mobile · billing · ai-ml · data-scientist
Layer 4 Quality (3, by concern)   qa-tester · security-engineer · performance-engineer
Layer 5 Operations (1)            devops-sre
Layer 6 Design + Docs (2)         ui-ux-designer · tech-writer
Layer 7 Review (1, parallel)      universal-reviewer (+ Gemini CLI fallback)
```

## Agent picker

### Strategy

| Task | Agent |
|------|-------|
| Feature spec / roadmap / user story | `product-manager` |
| Pricing / ROI / financial model | `business-analyst` |
| SEO / marketing copy / conversion | `growth-marketer` |
| Onboarding / FAQ / support / user comms | `customer-success` |

### Architecture / design

| Task | Agent |
|------|-------|
| System design / API contract / data model | `system-architect` |
| Visual design / Tailwind / a11y / micro-interactions | `ui-ux-designer` |

### Engineering (by path)

| Path | Agent |
|------|-------|
| `**/billing/**`, `**/payments/**`, `**/credits/**` | `billing-engineer` |
| `**/ai/**`, `**/ml/**`, `**/llm/**`, `**/agents/**`, `**/prompts/**` | `ai-ml-engineer` |
| `**/analytics/**`, `**/etl/**`, stats models | `data-scientist` |
| `**/ios/**`, `**/android/**`, RN, Flutter | `mobile-developer` |
| Frontend (state/API/routing logic, NOT visuals) | `frontend-developer` |
| Backend (everything else) | `backend-developer` |

### Quality (by concern)

| Concern | Agent |
|---------|-------|
| Test correctness / business logic / races | `qa-tester` |
| Security / compliance / vuln audit | `security-engineer` |
| Performance / load / p95 | `performance-engineer` |
| Code quality / DRY / smell / structure | `universal-reviewer` |

### Operations

| Task | Agent |
|------|-------|
| Infra / CI/CD / deploy / monitoring / release | `devops-sre` |

### Docs

| Task | Agent |
|------|-------|
| Code docs / API docs / READMEs / ADRs | `tech-writer` |
| User-facing help / FAQ / change announcements | `customer-success` |
| Marketing copy / SEO content | `growth-marketer` |

## Parallel execution

### Phase 1 — Strategy (parallel)
1-4 agents based on task: `product-manager` (spec) / `business-analyst` (cost) / `growth-marketer` (GTM) / `customer-success` (rollout). Different artifacts → no conflict.

### Phase 2 — Architecture (gate)
`system-architect` produces SPEC.md + API contract + data model + service map. Engineers wait.

### Phase 3 — Engineering + Design + Docs (parallel)
Engineers by path + `ui-ux-designer` + `tech-writer` in parallel. Path-scoping prevents collision.

### Phase 4 — Quality (parallel by concern)
`qa-tester` + `security-engineer` + `performance-engineer`. Independent reports.

### Phase 5 — Review
`universal-reviewer` + Codex (high-risk) + Gemini CLI (breadth). Per skill `reviewer-flow`.

### Phase 6 — Operations
`devops-sre`.

## Boundary rules

1. Path-based — engineers don't touch other agents' paths
2. Concern-based — quality agents own different concerns
3. Artifact-based — strategy/design/docs own different artifacts
4. Overlap → STOP, ask Lead

## Escalation hierarchy

```
Engineer stuck →
  ├─ Specialist same domain
  ├─ Quality agent (qa/security/perf)
  ├─ Architect
  ├─ Lead (Sonnet/Haiku) → Advisor (Opus) per skill advisor-escalation
  └─ Lead → ask user
```

Final authority:
- Correctness → `qa-tester`
- Security → `security-engineer`
- Code quality → `universal-reviewer`
- Architecture → `system-architect`
- Product priority → user

## Parallel safety

1. Path filter — unique glob per agent
2. Concern filter — unique concern
3. Artifact filter — different output files
4. Cap each — ≤12 tool_uses, ≤5 files
5. Brief: Path + Lines + Criteria + Caps

## Cohesion contract (parallel orchestration)

Phase 3 spawns ≥2 agents sharing types/invariants/integration → written contract **required**.

Workflow (skill `parallel-contract-orchestration`):
1. Lead writes `.claude/orchestration/<topic>-contract.md` with shared types, invariants, integration touchpoints, named integration tests
2. Lead writes integration tests RED BEFORE spawning
3. Spawn each agent with contract path; agents may NOT mutate contract
4. RED-checkpoint: verify tests fail for right reason (missing impl, not contract drift)
5. Agents implement; merge via integration test suite

Skip only when agents produce fully independent artifacts.

## Optional add-ons (user-installed, not bundled)

See README → "Recommended add-ons" for the catalog (Token Optimize / Self-improvement / Design / QA Multi-opinion). When present, the framework auto-routes to them; when absent, default agents handle the work (e.g. `growth-marketer` does content + on-page SEO inline; deep technical SEO is out of scope unless user installs a dedicated plugin).

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "I'll pick the agent later" | Picking late = wrong path bias. Specialist decision before edit, not mid-implementation. |
| "qa-tester can handle everything" | qa-tester is the universal floor, not the universal answer. Security needs `security-engineer`; perf needs `performance-engineer`. |
| "Backend dev can do the frontend too" | Cross-domain agents skip domain-specific gates. Hand off at the path boundary. |
| "No conflict — both agents on different files" | Files don't conflict; shared types and API contracts do. Cohesion contract first. |
| "Just one extra agent, contract is overkill" | Two agents touching shared invariants without a contract drift silently. Contract takes 2 min, drift wastes hours. |
| "I'll route inside the agent prompt" | Routing inside the prompt fragments the decision. Pick agent first, brief specifically second. |
