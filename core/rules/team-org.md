# Team Organization — agent picker + parallel pattern

**Scope:** which agent owns what, how to delegate, parallel execution pattern.

Read when: choosing agent for task / planning multi-agent work / unclear ownership.

## Team layout (18 agents, 7 layers)

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1 — Strategy (4, all parallel)                    │
│   product-manager · business-analyst · growth-marketer  │
│   · customer-success                                    │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ Layer 2 — Architecture (1, sequential gate)             │
│   system-architect                                      │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ Layer 3 — Engineering (6, parallel by PATH)             │
│   backend-developer · frontend-developer                │
│   · mobile-developer · billing-engineer                 │
│   · ai-ml-engineer · data-scientist                     │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ Layer 4 — Quality (3, parallel by CONCERN)              │
│   qa-tester · security-engineer · performance-engineer  │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ Layer 5 — Operations (1)                                │
│   devops-sre                                            │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ Layer 6 — Design + Docs (2, parallel)                   │
│   ui-ux-designer · tech-writer                          │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ Layer 7 — Code review (1, parallel with engineering)    │
│   universal-reviewer (+ Gemini CLI fallback)            │
└─────────────────────────────────────────────────────────┘
```

## Agent picker — task → agent

### Strategy / planning

| Task | Agent |
|------|-------|
| Feature spec / roadmap / user story | `product-manager` |
| Pricing / ROI / financial model / competitor research | `business-analyst` |
| SEO content / marketing copy / conversion | `growth-marketer` |
| Onboarding / FAQ / support content / user comms | `customer-success` |

### Architecture / design

| Task | Agent |
|------|-------|
| System design / API contract / data model / tech decision | `system-architect` |
| Visual design / Tailwind / a11y / micro-interactions | `ui-ux-designer` |

### Engineering (path-based)

| Path / domain | Agent |
|--------------|-------|
| `**/billing/**`, `**/payments/**`, `**/credits/**` | `billing-engineer` |
| `**/ai/**`, `**/ml/**`, `**/llm/**`, `**/agents/**`, `**/prompts/**` | `ai-ml-engineer` |
| `**/analytics/**`, `**/etl/**`, statistical models | `data-scientist` |
| `**/ios/**`, `**/android/**`, RN, Flutter | `mobile-developer` |
| Frontend (state/API/routing logic, NOT visuals) | `frontend-developer` |
| Backend (everything else) | `backend-developer` |

### Quality (concern-based)

| Concern | Agent |
|---------|-------|
| Test correctness / business logic / races | `qa-tester` |
| Security / compliance / vuln audit | `security-engineer` |
| Performance / load / profiling / p95 | `performance-engineer` |
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

## Parallel execution pattern

### Phase 1 — Strategy (parallel)
Spawn 1-4 agents in parallel based on task needs:
- `product-manager` (spec)
- `business-analyst` (cost / pricing)
- `growth-marketer` (positioning / GTM)
- `customer-success` (rollout comms)

Different artifacts → no conflict.

### Phase 2 — Architecture (sequential gate)
`system-architect` produces:
- SPEC.md
- API contract
- Data model
- Service map (which agent owns which path)

Engineers wait for this gate before starting.

### Phase 3 — Engineering + Design + Docs (massively parallel)
Spawn in parallel by path/concern:
- 1+ engineering agents (different paths)
- `ui-ux-designer` (visual artifacts)
- `tech-writer` (code docs in parallel with engineers)

Path-based scoping prevents file collision.

### Phase 4 — Quality (parallel by concern)
After engineering:
- `qa-tester` (correctness)
- `security-engineer` (security)
- `performance-engineer` (speed)

Different concerns → independent reports.

### Phase 5 — Review
- `universal-reviewer` (code quality)
- Codex (high-risk surface, via plugin)
- Gemini CLI (breadth scan, Lead-direct)

Per `reviewer-flow.md` routing matrix.

### Phase 6 — Operations
`devops-sre` for deploy + release.

## Agent boundary rules

1. **Path-based ownership** — engineers DO NOT touch other agents' paths
2. **Concern-based ownership** — quality agents own different concerns
3. **Artifact-based ownership** — strategy/design/docs own different artifacts
4. **No overlap escalate** — same path/concern conflict → STOP, ask Lead

## Escalation hierarchy

```
Engineer stuck →
  ├─ Specialist same domain (e.g. another backend dev)
  ├─ Quality agent (qa-tester / security / performance)
  ├─ Architect (system-architect)
  ├─ Lead (Sonnet/Haiku) → Advisor (Opus) per advisor.md
  └─ Lead → ask user
```

Final authority by domain:
- **Correctness** → `qa-tester` (final judge)
- **Security** → `security-engineer` (final judge)
- **Code quality** → `universal-reviewer` (final judge)
- **Architecture** → `system-architect` (final judge)
- **Product priority** → user (commercial decision)

## Parallel safety rules

For Lead orchestrating multiple agents:
1. **Path filter** — assign each agent unique path glob (no overlap)
2. **Concern filter** — assign each agent unique concern
3. **Artifact filter** — different output files
4. **Cap each agent** — ≤12 tool_uses, ≤5 files (per triage-deep.md)
5. **Briefing** — Path + Lines + Criteria + Caps for every spawn

## Optional: install plugin sub-agents

For specialized domains, install plugins that add sub-agents:

| Plugin | Adds | When |
|--------|------|------|
| [claude-seo](https://github.com/AgriciDaniel/claude-seo) | `seo-technical`, `seo-schema`, `seo-google` (+15 more) | Deep technical SEO needs |
| [openai-codex](https://...) | Codex review commands | Code review depth |

`growth-marketer` delegates to claude-seo sub-agents for deep technical SEO.
