## Team workflow trigger

Default Lead pattern = Subagent + Task spawn (covers 80%+ tasks).

### Two opt-in patterns

| Pattern | Trigger | Scope | Cost |
|---------|---------|-------|------|
| **Full-lifecycle** | "use team" / "team workflow" / "with team" / "use teams" / "as a team" | ALL 6 phases use team recipes; auto-progress | High (5-10x) |
| **Surgical** | `/team-<phase>` slash command | ONLY that phase uses team; rest = default Subagent | Medium |

Mix slash commands per task (e.g. `/team-build` + `/team-review`) — only those phases switch.

### 6 lifecycle recipes

| Recipe | Spawn | Output / Gate |
|--------|-------|---------------|
| **team-define** | product-manager + business-analyst + system-architect | `SPEC.md` / verify-first |
| **team-plan** | system-architect (contract + RED tests) + product-manager (+ billing/ai-ml/security by path) | `contract.md` + RED tests + tasks / Q1-Q4 |
| **team-build** | parallel engineers by path (backend/frontend/mobile/billing/ai-ml/data); owner = system-architect (contract enforcer); RED→GREEN→REFACTOR | S1-S5, F1-F5 |
| **team-verify** | qa-tester (floor) + security-engineer (auth/billing) + performance-engineer (perf) | T1-T6, verify-first |
| **team-review** | universal-reviewer + qa-tester (review-mode); doubt-driven-development bounded 3 | pre-merge-gate |
| **team-ship** | devops-sre + tech-writer + growth-marketer + customer-success | CI 3-phase |

### Mandatory gates (both patterns)

T1-T6 / S1-S5 / F1-F5 / pre-merge-gate / CI 3-phase. Team or Subagent = orchestration, NOT gate skip.

### Lead behavior on trigger

1. Acknowledge mode + which phase(s)
2. Detect scope: vague → `/team-define`; specific phase → that team; multi-phase → orchestrate
3. Run recipe + cohesion contract where applicable
4. Persist context across phases
5. CEO reviews output

### When NOT to use team

- Single-file fix / typo / quick refactor
- <3 agents needed
- Independent investigation (qa OR security OR perf alone)
- Q1-Q4 routing handles it
- Time-sensitive hotfix

Reference: https://code.claude.com/docs/en/agent-teams (Lead-orchestrated; YAML team configs are runtime-managed by Anthropic — rolepod ships recipes only).
