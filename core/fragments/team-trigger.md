## Team workflow trigger

Default Lead pattern = Subagent + Task spawn (current behavior, covers 80%+ tasks).

Switch to Team workflow when user prompt contains trigger phrases:
- "use team" / "team workflow" / "with team" / "as a team"
- "big feature, team" / "use teams"
- `/team-define` / `/team-plan` / `/team-build` / `/team-verify` / `/team-review` / `/team-ship`

### How Team workflow works

Lead orchestrates multi-phase Task-spawn dispatch following lifecycle recipes. Same 18 subagents, different orchestration pattern.

### 6 lifecycle recipes

**team-define** — frame intent → spec
- Spawn: `product-manager` (user stories) + `business-analyst` (ROI) + `system-architect` (feasibility)
- Output: `SPEC.md`
- Gate focus: verify-first (intent verification)

**team-plan** — spec → ordered tasks + cohesion contract
- Spawn: `system-architect` (writes contract + RED tests) + `product-manager` (task breakdown)
- Specialists joined by path: `billing-engineer` / `ai-ml-engineer` / `security-engineer` when relevant
- Output: `contract.md` + RED tests + task list
- Gate focus: Q1-Q4 delegation

**team-build** — tasks → code (parallel-safe by path)
- Spawn parallel: engineers by path (backend / frontend / mobile / billing / ai-ml / data) via cohesion contract
- Owner: `system-architect` (contract enforcer)
- Cycle: RED → GREEN → REFACTOR per task
- Gate focus: S1-S5 simplicity, F1-F6 failure-mode

**team-verify** — code → evidence
- Spawn: `qa-tester` (universal floor) + `security-engineer` (auth/billing) + `performance-engineer` (perf-sensitive)
- Gate focus: T1-T6 testing, verify-first

**team-review** — evidence → adversarial pass
- Spawn: `universal-reviewer` + `qa-tester` (review-mode)
- Adversarial: doubt-driven-development cycle (bounded 3)
- Gate focus: pre-merge-gate

**team-ship** — approved → deploy + announce
- Spawn: `devops-sre` (deploy) + `tech-writer` (release notes) + `growth-marketer` (announce) + `customer-success` (FAQ)
- Gate focus: CI 3-phase

### Lead behavior

When team trigger fires:
1. Acknowledge team mode active to user
2. Detect scope: vague feature → start `/team-define`; specific phase → that team; multi-phase → orchestrate sequence
3. Run phase recipe — spawn agents per recipe + cohesion contract where applicable
4. Persist context across phases (Lead's own session context carries forward)
5. CEO reviews output (same as default)

### When NOT to use Team

Default Subagent pattern is right when:
- Single-file fix / typo / quick refactor
- Tasks needing <3 agents
- Independent investigations (qa OR security OR perf alone)
- Lead's Q1-Q4 already routes correctly

Team trigger = opt-in for big / multi-phase / high-coordination work.

Reference: https://code.claude.com/docs/en/agent-teams (Lead-orchestrated; YAML team configs are runtime-managed by Anthropic — rolepod ships recipes only, no pre-authored team schemas).
